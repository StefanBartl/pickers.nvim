---@module 'pickers.filegrep'
---@brief Core of the `filegrep` action: "files whose PATH matches X and whose
---@brief CONTENT matches Y", driven by a single prompt string.
---@description
--- The prompt is a plain file-find query, optionally extended with one or more
--- `grep=<pattern>` tokens:
---
---   akronyms                  -> files with "akronyms" in the path   (like a files picker)
---   akronyms grep=NWBC        -> ... that also contain "NWBC"
---   grep=NWBC grep=TODO       -> files containing BOTH patterns
---   grep="foo bar" cfg        -> quote a value to put spaces in it
---
--- Without a usable `grep=` token it behaves exactly like a files picker, so it
--- can serve as the everyday "main" picker. Every engine adapter drives
--- `M.query` from its own per-keystroke callback (same contract as
--- `pickers.smart.query`), so behaviour is identical on telescope / fzf-lua /
--- snacks.
---
--- Strategy: the FIRST grep pattern runs as `rg --vimgrep --max-count 1` (one
--- row per file, positioned on the first hit); every further pattern runs as
--- `rg --files-with-matches` and is intersected. The path part is then scored
--- in Lua (`pickers.smart.score.match`: substring first, weak subsequence
--- fallback). Filtering by path in Lua rather than handing fd/rg a file list
--- keeps the argument vector short -- Windows caps the command line length.
---
--- Process output is memoised for a few seconds, so typing in the path part
--- (the common case once a `grep=` is set) re-scores in Lua without spawning
--- anything.

local M = {}

local uv = vim.uv or vim.loop
local search = require("pickers.smart.search")
local spawn_env = require("lib.nvim.cross.run.env")

---A `grep=` value shorter than this is ignored: a 1-char pattern matches nearly
---every file and would only make rg thrash while the user is still typing.
M.MIN_GREP_LEN = 2

---How long a process result stays reusable, in ms.
local CACHE_TTL_MS = 5000
local CACHE_MAX = 16

---@type table<string, { at: number, value: any }>
local cache = {}
---@type string[]
local cache_keys = {}

---@internal
---@param key string
---@param fn fun(): any
---@return any
local function cached(key, fn)
  local now = uv.now()
  local hit = cache[key]
  if hit and now - hit.at < CACHE_TTL_MS then return hit.value end
  local value = fn()
  if not cache[key] then
    cache_keys[#cache_keys + 1] = key
    if #cache_keys > CACHE_MAX then cache[table.remove(cache_keys, 1)] = nil end
  end
  cache[key] = { at = now, value = value }
  return value
end

---Drop every memoised process result (tests, and a manual "refresh").
function M.clear_cache()
  cache = {}
  cache_keys = {}
end

---Split a prompt into whitespace-separated words; double quotes group words and
---are dropped, so `grep="a b"` yields the single word `grep=a b`. An unclosed
---quote (user still typing) runs to the end of the prompt.
---@internal
---@param s string
---@return string[]
local function words(s)
  local out, cur, in_quote = {}, {}, false
  local function flush()
    if #cur > 0 then
      out[#out + 1] = table.concat(cur)
      cur = {}
    end
  end
  for i = 1, #s do
    local c = s:sub(i, i)
    if c == '"' then
      in_quote = not in_quote
    elseif c:match("%s") and not in_quote then
      flush()
    else
      cur[#cur + 1] = c
    end
  end
  flush()
  return out
end

---@class Pickers.FileGrep.Parsed
---@field path    string[]  Path-filter words (all must match)
---@field grep    string[]  Content patterns long enough to run (all must match)
---@field pending boolean   True when a `grep=` token exists but is still too short to run

---Parse a prompt into path words and `grep=` patterns. Pure.
---@param query string|nil
---@return Pickers.FileGrep.Parsed
function M.parse(query)
  local parsed = { path = {}, grep = {}, pending = false } ---@type Pickers.FileGrep.Parsed
  for _, w in ipairs(words(query or "")) do
    if w:sub(1, 5) == "grep=" then
      local value = w:sub(6)
      if #value >= M.MIN_GREP_LEN then
        parsed.grep[#parsed.grep + 1] = value
      else
        parsed.pending = true
      end
    else
      parsed.path[#parsed.path + 1] = w
    end
  end
  return parsed
end

---Run one process and return its stdout lines plus a problem string (or nil).
---@internal
---@param cmd string[]
---@param root string
---@param timeout integer
---@param tool string
---@param benign_code integer|nil
---@return string[] lines
---@return string|nil problem
local function run(cmd, root, timeout, tool, benign_code)
  local ok, res = pcall(function()
    return vim.system(cmd, spawn_env.apply({ cwd = root, text = true })):wait(timeout)
  end)
  local problem = search.classify_run(tool, root, ok, res, benign_code)
  local lines = {}
  if ok and res and res.stdout then
    for line in res.stdout:gmatch("[^\r\n]+") do
      lines[#lines + 1] = line
    end
  end
  return lines, problem
end

---@internal
---@param name string
---@return string|nil
local function exe(name)
  if name == "fd" then
    for _, n in ipairs({ "fd", "fdfind" }) do
      if vim.fn.executable(n) == 1 then return n end
    end
    return nil
  end
  return vim.fn.executable(name) == 1 and name or nil
end

---@class Pickers.FileGrep.Candidate
---@field path    string
---@field root    string
---@field abspath string
---@field lnum?   integer
---@field col?    integer
---@field text?   string

---All files below `root` (fd), memoised.
---@internal
---@return Pickers.FileGrep.Candidate[] cands
---@return string[] problems
local function list_files(root, find, timeout)
  local fd = exe("fd")
  if not fd then return {}, { "fd not found on PATH" } end
  local key = table.concat({ "fd", root, vim.inspect(find or {}) }, "\0")
  return unpack(cached(key, function()
    local cmd = { fd }
    vim.list_extend(cmd, search.fd_args(find or {}, ""))
    local lines, problem = run(cmd, root, timeout, "fd")
    local cands = {}
    for i, line in ipairs(lines) do
      local rel = vim.fs.normalize(line)
      cands[i] = { path = rel, root = root, abspath = vim.fs.normalize(root .. "/" .. rel) }
    end
    return { cands, problem and { problem } or {} }
  end))
end

---Files below `root` matching every pattern in `patterns`; the first pattern
---also supplies the position/text of its first hit. Memoised per pattern set.
---@internal
---@return Pickers.FileGrep.Candidate[] cands
---@return string[] problems
local function grep_files(root, find, extra, patterns, timeout)
  local rg = exe("rg")
  if not rg then return {}, { "rg not found on PATH" } end
  local key = table.concat({
    "rg",
    root,
    vim.inspect(find or {}),
    vim.inspect(extra or {}),
    table.concat(patterns, "\0"),
  }, "\1")
  return unpack(cached(key, function()
    local problems = {}

    local first_extra = vim.list_extend({ "--max-count", "1" }, extra or {})
    local cmd = { rg }
    vim.list_extend(cmd, search.rg_args(find or {}, first_extra, patterns[1]))
    local lines, problem = run(cmd, root, timeout, "rg", 1)
    if problem then problems[#problems + 1] = problem end

    local cands = {} ---@type Pickers.FileGrep.Candidate[]
    for _, line in ipairs(lines) do
      local file, l, c, text = line:match("^(.-):(%d+):(%d+):(.*)$")
      if file then
        local rel = vim.fs.normalize(file)
        cands[#cands + 1] = {
          path = rel,
          root = root,
          abspath = vim.fs.normalize(root .. "/" .. rel),
          lnum = tonumber(l) --[[@as integer]],
          col = tonumber(c) --[[@as integer]],
          text = text,
        }
      end
    end

    -- Every further pattern narrows the set to files that contain it too.
    for i = 2, #patterns do
      if #cands == 0 then break end
      local rcmd = { rg }
      vim.list_extend(rcmd, search.rg_files_args(find or {}, extra, patterns[i]))
      local hits, p = run(rcmd, root, timeout, "rg", 1)
      if p then problems[#problems + 1] = p end
      local set = {}
      for _, h in ipairs(hits) do
        set[vim.fs.normalize(h)] = true
      end
      local kept = {}
      for _, cand in ipairs(cands) do
        if set[cand.path] then kept[#kept + 1] = cand end
      end
      cands = kept
    end
    return { cands, problems }
  end))
end

---Score `path` against every path word (all must match). Pure.
---@param words_ string[]
---@param path string
---@param w Pickers.Smart.Weights
---@return number|nil
function M.score_path(words_, path, w)
  local total = 0
  for _, word in ipairs(words_) do
    local s = require("pickers.smart.score").score_file(word, path, w)
    if not s then return nil end
    total = total + s
  end
  return total
end

---Picker row text: `path:lnum: text` for a content hit, the bare path otherwise.
---@internal
---@param cand Pickers.FileGrep.Candidate
---@return string
local function display(cand)
  if not cand.lnum then return cand.path end
  local text = (cand.text or ""):gsub("^%s+", "")
  return string.format("%s:%d: %s", cand.path, cand.lnum, text)
end

---Run the file+content search for one prompt and return ranked items.
---@param query string
---@param opts  { roots: string[], find: Pickers.FindOpts, additional_args?: string[] }
---@return Pickers.Smart.Item[] items
---@return string[] problems
function M.query(query, opts)
  local sm = require("pickers.smart").config()
  local parsed = M.parse(query)
  local roots = opts.roots or { uv.cwd() or "." }
  local timeout = sm.timeout or 3000
  local weights = sm.weights or {}

  local items = {} ---@type Pickers.Smart.Item[]
  local problems = {} ---@type string[]
  local has_grep = #parsed.grep > 0

  for _, root in ipairs(roots) do
    root = vim.fs.normalize(root)
    local cands, probs
    if has_grep then
      cands, probs = grep_files(root, opts.find, opts.additional_args, parsed.grep, timeout)
    else
      cands, probs = list_files(root, opts.find, timeout)
    end
    vim.list_extend(problems, probs)

    for _, cand in ipairs(cands) do
      local s = M.score_path(parsed.path, cand.path, weights)
      if s then
        local item = {
          kind = cand.lnum and "grep" or "file",
          path = cand.path,
          root = cand.root,
          abspath = cand.abspath,
          lnum = cand.lnum,
          col = cand.col,
          text = cand.text,
          score = s,
          display = display(cand),
        }
        items[#items + 1] = item
      end
    end
  end

  table.sort(items, function(a, b)
    if a.score == b.score then return a.path < b.path end
    return a.score > b.score
  end)

  local limit = sm.limit
  if limit and #items > limit then
    for i = #items, limit + 1, -1 do
      items[i] = nil
    end
  end
  for i, it in ipairs(items) do
    it._rank = i
  end
  return items, problems
end

return M
