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
---   grep="foo bar" cfg        -> quote a value to put spaces in it (`\"` is a literal quote)
---
--- Without a usable `grep=` token it behaves exactly like a files picker, so it
--- can serve as the everyday "main" picker. Every engine adapter drives
--- `M.query` from its own per-keystroke callback (same contract as
--- `pickers.smart.query`), so behaviour is identical on telescope / fzf-lua /
--- snacks.
---
--- Strategy: the FIRST grep pattern runs as `rg --vimgrep --max-count 1` (one
--- row per file, positioned on the first hit); every further pattern runs as
--- `rg --files-with-matches` restricted to the files that survived so far
--- (chunked to stay under the Windows command-line limit; a full-tree scan
--- when too many survived). The path part is scored in Lua
--- (`pickers.smart.score`: substring first, weak subsequence fallback).
---
--- The rg half honours `find.hidden` / `find.no_ignore` / `find.follow` exactly
--- like the fd half does, so adding a `grep=` only ever narrows the plain
--- listing (it never reveals gitignored or hidden files the listing hides).
---
--- Process output is memoised for a few seconds (compact: path arrays, not one
--- table per file), so typing in the path part -- the common case once a
--- `grep=` is set -- re-scores in Lua without spawning anything.

local M = {}

local uv = vim.uv or vim.loop
local search = require("pickers.smart.search")
local score = require("pickers.smart.score")
local spawn_env = require("lib.nvim.cross.run.env")
local executable = require("lib.nvim.cross.executable")

---A `grep=` value shorter than this (in characters) is ignored: a 1-char pattern
---matches nearly every file and would only make rg thrash while the user is
---still typing.
M.MIN_GREP_LEN = 2

---At most this many distinct `grep=` tokens run per query (each one is a
---process spawn on the main thread); further ones are ignored.
M.MAX_GREP_TOKENS = 4

---How long a process result stays reusable, in seconds.
local CACHE_TTL_S = 5
---Memoised results kept at most (oldest dropped first).
local CACHE_MAX = 8
---Command-line budget (chars) for narrowing a later pattern to the survivors;
---Windows caps a command line at 32767 chars.
local ARGV_BUDGET = 24000
---Above this many survivors a later pattern scans the whole tree instead.
local NARROW_MAX = 3000
---Seconds before the same problem message is shown again.
local REPORT_EVERY_S = 10

local notify = require("lib.nvim.notify").create("[pickers.filegrep]")
local ns =
  require("lib.nvim.cache.memory").namespace("pickers.nvim.filegrep", { ttl = CACHE_TTL_S })
---@type string[]
local cache_keys = {}

---@class Pickers.FileGrep.Entry
---@field paths    string[]                 Paths relative to the root, sorted
---@field hits?    { lnum: integer, col: integer, text: string }[]  Parallel to `paths` (grep runs only)
---@field lcs?     string[]                 Lowercased `paths`, built on the first path-word query
---@field problems string[]

---Memoise one process run. A run that failed outright (a problem and nothing to
---show) is NOT stored, so the next keystroke retries it; a partial success
---(e.g. rg exit 2 on one unreadable file but with hits) is stored, problems kept.
---@internal
---@param key string
---@param fn fun(): Pickers.FileGrep.Entry
---@return Pickers.FileGrep.Entry
local function cached(key, fn)
  local hit = ns.get(key)
  if hit then return hit end
  local entry = fn()
  if #entry.paths == 0 and #entry.problems > 0 then return entry end
  for i, k in ipairs(cache_keys) do
    if k == key then
      table.remove(cache_keys, i)
      break
    end
  end
  cache_keys[#cache_keys + 1] = key
  if #cache_keys > CACHE_MAX then ns.invalidate(table.remove(cache_keys, 1)) end
  ns.set(key, entry)
  return entry
end

---Drop every memoised process result (tests, and a manual "refresh").
function M.clear_cache()
  ns.clear()
  cache_keys = {}
end

---Split a prompt into whitespace-separated words. Double quotes group words and
---are dropped, so `grep="a b"` yields the single word `grep=a b`; `\"` and `\ `
---are a literal quote / space (any other backslash is kept as typed, so regex
---escapes like `\b` or `\(` pass through). An unclosed quote (user still typing)
---runs to the end of the prompt.
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
  local i, n = 1, #s
  while i <= n do
    local c = s:sub(i, i)
    local nxt = s:sub(i + 1, i + 1)
    if c == "\\" and (nxt == '"' or nxt == " ") then
      cur[#cur + 1] = nxt
      i = i + 1
    elseif c == '"' then
      in_quote = not in_quote
    elseif c:match("%s") and not in_quote then
      flush()
    else
      cur[#cur + 1] = c
    end
    i = i + 1
  end
  flush()
  return out
end

---Number of UTF-8 characters in `s` (continuation bytes are not counted).
---@internal
---@param s string
---@return integer
local function char_len(s)
  return select(2, s:gsub("[^\128-\191]", ""))
end

---@class Pickers.FileGrep.Parsed
---@field path    string[]  Path-filter words (all must match)
---@field grep    string[]  Distinct content patterns long enough to run (all must match)
---@field pending boolean   True when a `grep=` token exists but is still too short to run

---Parse a prompt into path words and `grep=` patterns. Pure.
---@param query string|nil
---@return Pickers.FileGrep.Parsed
function M.parse(query)
  local parsed = { path = {}, grep = {}, pending = false } ---@type Pickers.FileGrep.Parsed
  local seen = {}
  for _, w in ipairs(words(query or "")) do
    if w:sub(1, 5) == "grep=" then
      local value = w:sub(6)
      if char_len(value) < M.MIN_GREP_LEN then
        parsed.pending = true
      elseif not seen[value] and #parsed.grep < M.MAX_GREP_TOKENS then
        seen[value] = true
        parsed.grep[#parsed.grep + 1] = value
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

---All files below `root` (fd), memoised.
---@internal
---@param root string
---@param find Pickers.FindOpts|nil
---@param timeout integer
---@param fd string|nil  fd executable name, nil when not installed
---@return Pickers.FileGrep.Entry
local function list_files(root, find, timeout, fd)
  if not fd then return { paths = {}, problems = { "fd not found on PATH" } } end
  local key = table.concat({ "fd", root, vim.inspect(find or {}) }, "\0")
  return cached(key, function()
    local cmd = { fd }
    vim.list_extend(cmd, search.fd_args(find or {}, ""))
    local lines, problem = run(cmd, root, timeout, "fd")
    local paths = {}
    for i, line in ipairs(lines) do
      paths[i] = search.unify_path(line)
    end
    table.sort(paths)
    return { paths = paths, problems = problem and { problem } or {} }
  end)
end

---rg flags that make the content half see the same file set as the fd listing:
---rg_args/rg_files_args hardcode `--hidden --no-ignore-vcs`, and a later flag
---wins, so the find.* settings are appended after them.
---@internal
---@param find Pickers.FindOpts|nil
---@param extra string[]|nil  source.additional_args
---@return string[]
local function rg_extra(find, extra)
  local out = {}
  find = find or {}
  out[#out + 1] = find.no_ignore and "--no-ignore" or "--ignore-vcs"
  if not find.hidden then out[#out + 1] = "--no-hidden" end
  if find.follow then out[#out + 1] = "--follow" end
  vim.list_extend(out, extra or {})
  return out
end

---Files among `paths` that also contain `pattern`, as a set. Runs against the
---explicit survivor list in argv chunks (cheap: rg only opens those files), or
---over the whole tree when there are too many survivors for a command line.
---@internal
---@return table<string, boolean>
local function narrow(rg, root, find, extra, pattern, paths, timeout, problems)
  local base = { rg }
  vim.list_extend(base, search.rg_files_args(find or {}, rg_extra(find, extra), pattern))
  local set = {}

  local function collect(cmd)
    local lines, problem = run(cmd, root, timeout, "rg", 1)
    if problem then problems[#problems + 1] = problem end
    for _, line in ipairs(lines) do
      set[search.unify_path(line)] = true
    end
  end

  if #paths > NARROW_MAX then
    collect(base)
    return set
  end

  local base_len = 0
  for _, a in ipairs(base) do
    base_len = base_len + #a + 1
  end
  local chunk, size = {}, base_len
  local function flush()
    if #chunk == 0 then return end
    collect(vim.list_extend(vim.deepcopy(base), chunk))
    chunk, size = {}, base_len
  end
  for _, p in ipairs(paths) do
    if size + #p + 1 > ARGV_BUDGET then flush() end
    chunk[#chunk + 1] = p
    size = size + #p + 1
  end
  flush()
  return set
end

---Files below `root` matching every pattern in `patterns`; the first pattern
---also supplies the position/text of its first hit. Memoised per pattern set.
---@internal
---@return Pickers.FileGrep.Entry
local function grep_files(root, find, extra, patterns, timeout, rg)
  if not rg then return { paths = {}, problems = { "rg not found on PATH" } } end
  local key = table.concat({
    "rg",
    root,
    vim.inspect(find or {}),
    vim.inspect(extra or {}),
    table.concat(patterns, "\0"),
  }, "\1")
  return cached(key, function()
    local problems = {}
    local opts = rg_extra(find, extra)

    local first_extra = vim.list_extend({ "--max-count", "1" }, opts)
    local cmd = { rg }
    vim.list_extend(cmd, search.rg_args(find or {}, first_extra, patterns[1]))
    local lines, problem = run(cmd, root, timeout, "rg", 1)
    if problem then problems[#problems + 1] = problem end

    -- --max-count caps matching LINES, but --vimgrep still prints one row per
    -- match on that line: keep only the first row of each file.
    local rows, seen = {}, {}
    for _, line in ipairs(lines) do
      local file, l, c, text = line:match("^(.-):(%d+):(%d+):(.*)$")
      local rel = file and search.unify_path(file)
      if rel and not seen[rel] then
        seen[rel] = true
        rows[#rows + 1] = { path = rel, lnum = tonumber(l), col = tonumber(c), text = text }
      end
    end
    table.sort(rows, function(a, b)
      return a.path < b.path
    end)

    -- Every further pattern narrows the set to files that contain it too.
    for i = 2, #patterns do
      if #rows == 0 then break end
      local survivors = {}
      for j, r in ipairs(rows) do
        survivors[j] = r.path
      end
      local set = narrow(rg, root, find, extra, patterns[i], survivors, timeout, problems)
      local kept = {}
      for _, r in ipairs(rows) do
        if set[r.path] then kept[#kept + 1] = r end
      end
      rows = kept
    end

    local paths, hits = {}, {}
    for i, r in ipairs(rows) do
      paths[i] = r.path
      hits[i] = { lnum = r.lnum, col = r.col, text = r.text }
    end
    return { paths = paths, hits = hits, problems = problems }
  end)
end

---Score `path` against every path word (all must match). Pure.
---@param words_ string[]
---@param path string
---@param w Pickers.Smart.Weights
---@return number|nil
function M.score_path(words_, path, w)
  local total = 0
  for _, word in ipairs(words_) do
    local s = score.score_file(word, path, w)
    if not s then return nil end
    total = total + s
  end
  return total
end

---Picker row text: `path:lnum: text` for a content hit, the bare path otherwise.
---@internal
---@param path string
---@param hit { lnum: integer, text: string }|nil
---@return string
local function display(path, hit)
  if not hit then return path end
  local text = (hit.text or ""):gsub("^%s+", "")
  return string.format("%s:%d: %s", path, hit.lnum, text)
end

local last_msg, last_at = nil, 0

---Show the first problem of a run (ERR-11: a broken run must not look like zero
---matches), at most once per REPORT_EVERY_S for the same message so typing does
---not flood the screen.
---@internal
---@param problems string[]
local function report(problems)
  local msg = problems[1]
  if not msg then return end
  local now = uv.hrtime() / 1e9
  if msg == last_msg and now - last_at < REPORT_EVERY_S then return end
  last_msg, last_at = msg, now
  vim.schedule(function()
    notify.warn(msg)
  end)
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
  local limit = sm.limit
  local has_grep = #parsed.grep > 0

  local needles = {}
  for i, w in ipairs(parsed.path) do
    needles[i] = w:lower()
  end

  -- Resolve the tool once per query (lib.nvim memoises the PATH lookup).
  local fd = (not has_grep) and executable.find({ "fd", "fdfind" }) or nil
  local rg = has_grep and executable.find("rg") or nil

  -- Parallel arrays instead of a table per candidate: ents[k] = cache entry,
  -- idxs[k] = row in it, scs[k] = score, roots_of[k] = its root.
  local ents, idxs, scs, roots_of = {}, {}, {}, {}
  local n = 0
  local problems = {} ---@type string[]

  for _, root in ipairs(roots) do
    root = vim.fs.normalize(root)
    local entry
    if has_grep then
      entry = grep_files(root, opts.find, opts.additional_args, parsed.grep, timeout, rg)
    else
      entry = list_files(root, opts.find, timeout, fd)
    end
    vim.list_extend(problems, entry.problems)
    local paths = entry.paths

    if #needles == 0 then
      -- Nothing to score: every row ties, so the (already sorted) listing is
      -- the ranking and only the first `limit` rows are ever looked at.
      local take = #paths
      if limit and n + take > limit then take = limit - n end
      for i = 1, take do
        n = n + 1
        ents[n], idxs[n], scs[n], roots_of[n] = entry, i, 0, root
      end
      if limit and n >= limit then break end
    else
      local lcs = entry.lcs
      if not lcs then
        lcs = {}
        for i = 1, #paths do
          lcs[i] = paths[i]:lower()
        end
        entry.lcs = lcs
      end
      local score_file_lc = score.score_file_lc
      for i = 1, #paths do
        local total, matched = 0, true
        for w = 1, #needles do
          local s = score_file_lc(needles[w], lcs[i], weights)
          if not s then
            matched = false
            break
          end
          total = total + s
        end
        if matched then
          n = n + 1
          ents[n], idxs[n], scs[n], roots_of[n] = entry, i, total, root
        end
      end
    end
  end

  ---@type integer[]
  local order = {}
  if #needles == 0 then
    for k = 1, n do
      order[k] = k
    end
  else
    -- Only the best `limit` rows are needed: find the limit-th best score from a
    -- sorted copy of the numbers (cheap default comparator), keep rows at or
    -- above it, and run the expensive comparator sort on just those.
    local threshold
    if limit and n > limit then
      local tmp = table.move(scs, 1, n, 1, {})
      table.sort(tmp)
      threshold = tmp[n - limit + 1]
    end
    for k = 1, n do
      if not threshold or scs[k] >= threshold then order[#order + 1] = k end
    end
    table.sort(order, function(a, b)
      if scs[a] == scs[b] then return ents[a].paths[idxs[a]] < ents[b].paths[idxs[b]] end
      return scs[a] > scs[b]
    end)
  end

  local count = #order
  if limit and count > limit then count = limit end
  local items = {} ---@type Pickers.Smart.Item[]
  for r = 1, count do
    local k = order[r]
    local entry, i, root = ents[k], idxs[k], roots_of[k]
    local path = entry.paths[i]
    local hit = entry.hits and entry.hits[i] or nil
    items[r] = {
      kind = hit and "grep" or "file",
      path = path,
      root = root,
      abspath = root .. "/" .. path,
      lnum = hit and hit.lnum or nil,
      col = hit and hit.col or nil,
      text = hit and hit.text or nil,
      score = scs[k],
      display = display(path, hit),
      _rank = r,
    }
  end

  report(problems)
  return items, problems
end

return M
