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
--- (passed as `./<path>` arguments, split over a few command lines to stay under
--- the OS limit; a single full-tree scan when they would need too many, or when
--- `rg` is a .cmd/.bat shim). The path part is scored in Lua
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
local is_windows = require("lib.nvim.cross.platform.is_windows")

---A `grep=` value shorter than this (in characters) is ignored: a 1-char pattern
---matches nearly every file and would only make rg thrash while the user is
---still typing.
M.MIN_GREP_LEN = 2

---At most this many distinct `grep=` tokens run per query (each one is a
---process spawn on the main thread); further ones are ignored.
M.MAX_GREP_TOKENS = 4

---How long a process result stays reusable, in seconds.
local CACHE_TTL_S = 5
---Memoised results kept at most (least recently used dropped first). One slot
---per root and per pattern step; entries also expire by TTL and are swept, so
---this only bounds a pathological many-root scope.
local CACHE_MAX = 128
---Command-line budget (chars) for ONE rg spawn that narrows a later pattern to
---the survivors. Windows caps a command line at 32767 chars; POSIX allows far
---more (ARG_MAX of 256 KiB and up), so a big first result stays narrowable there.
local ARGV_BUDGET = is_windows() and 24000 or 100000
---Survivors that need more command lines than this are not narrowed with
---explicit paths: one whole-tree scan is cheaper than that many spawns.
local MAX_CHUNKS = 8
---Characters of rg's stderr kept in a problem message.
local STDERR_MAX_CHARS = 160

local ns =
  require("lib.nvim.cache.memory").namespace("pickers.nvim.filegrep", { ttl = CACHE_TTL_S })
---@type string[]
local cache_keys = {}
local sweep_armed = false
---Bumped by clear_cache(): a timer armed before it belongs to a previous cache
---generation and ends instead of re-arming (no second sweep chain).
local generation = 0

---@class Pickers.FileGrep.Entry
---@field paths    string[]                 Paths relative to the root, sorted
---@field hits?    { lnum: integer, col: integer, text: string }[]  Parallel to `paths` (grep runs only)
---@field lcs?     string[]                 Lowercased `paths`, built on the first path-word query
---@field problems string[]
---@field failed?  boolean                  The process could not be spawned: never memoised (a timeout IS: retrying would block again)

---Move `key` to the most-recently-used end of `cache_keys`.
---@internal
---@param key string
local function touch(key)
  for i, k in ipairs(cache_keys) do
    if k == key then
      table.remove(cache_keys, i)
      break
    end
  end
  cache_keys[#cache_keys + 1] = key
end

---Release expired entries shortly after they lapse, so a big result does not
---stay resident after the picker is closed (the TTL alone only evicts on a
---lookup of the same key). Re-arms itself while anything is still live.
---@internal
local function arm_sweep()
  if sweep_armed then return end
  sweep_armed = true
  local armed_in = generation
  vim.defer_fn(function()
    if armed_in ~= generation then return end -- stale: clear_cache() re-arms its own
    sweep_armed = false
    local live = {}
    for _, k in ipairs(cache_keys) do
      if ns.get(k) then live[#live + 1] = k end -- get() drops an expired entry
    end
    cache_keys = live
    if #live > 0 then arm_sweep() end
  end, (CACHE_TTL_S + 1) * 1000)
end

---Memoise one process run. Only a run that could not be spawned at all
---(`entry.failed`) is NOT stored, so the next keystroke retries it; everything
---else is, including a clean "nothing matched", a regex error and a run killed at
---the timeout (its partial result plus the problem): re-running a scan that was
---too slow would block the main thread for the whole timeout again on every
---keystroke of the path part.
---@internal
---@param key string
---@param fn fun(): Pickers.FileGrep.Entry
---@return Pickers.FileGrep.Entry
local function cached(key, fn)
  local hit = ns.get(key)
  if hit then
    touch(key)
    return hit
  end
  local entry = fn()
  if entry.failed then return entry end
  touch(key)
  if #cache_keys > CACHE_MAX then ns.invalidate(table.remove(cache_keys, 1)) end
  ns.set(key, entry)
  arm_sweep()
  return entry
end

---Drop every memoised process result, the notification throttle and the tool
---re-lookup stamps (tests, and a manual "refresh").
function M.clear_cache()
  ns.clear()
  cache_keys = {}
  search.reset_report()
  generation = generation + 1
  sweep_armed = false
  search.reset_tool_retry()
end

---Split a prompt into whitespace-separated words. Double quotes group words and
---are dropped, so `grep="a b"` yields the single word `grep=a b`; `\"` and `\ `
---are a literal quote / space; `\\` (a regex-escaped backslash) stays two
---backslashes and cannot escape what follows it; any other backslash is kept as
---typed, so regex escapes like `\b` or `\(` pass through. An unclosed quote (user
---still typing) runs to the end of the prompt.
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
    if c == "\\" and nxt == "\\" then
      -- A regex-escaped backslash stays as typed, and its second backslash can
      -- no longer escape the quote or space that follows it.
      cur[#cur + 1] = "\\\\"
      i = i + 1
    elseif c == "\\" and (nxt == '"' or nxt == " ") then
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

---The reason out of rg's stderr, for a problem message: its first line, plus the
---`error:` line that carries the actual cause of a regex error (rg prints
---"regex parse error:" first and the reason last). ASCII and C1 control
---characters are replaced and the cut is made on a character boundary.
---@internal
---@param stderr string
---@return string|nil
local function stderr_reason(stderr)
  local first, err
  for line in stderr:gmatch("[^\r\n]+") do
    if line:match("%S") then
      first = first or line
      if not err and line:match("^error:") then err = line end
    end
  end
  if not first then return nil end
  local text = (err and err ~= first) and (first .. " " .. err) or first
  text = text:gsub("%c", " "):gsub("\194[\128-\159]", " ")
  return vim.fn.strcharpart(text, 0, STDERR_MAX_CHARS)
end

---Run one process and return its stdout lines, a problem string (or nil),
---whether it could not be spawned at all, and whether to stop issuing more
---processes of the same kind.
---
--- * `spawn_failed` -- nothing ran: not memoised, retried on the next keystroke.
---   A `:wait()` that came back empty after the kill is NOT a spawn failure (the
---   process did run): it counts as killed.
--- * rg exit 2 WITH hits is a partial success (an unreadable file, a dangling
---   symlink): the hits stand and there is no problem to report.
--- * a run killed at the timeout keeps its partial hits AND its problem.
--- * any other non-zero exit keeps its problem, extended by rg's stderr reason
---   so a regex error says why.
--- * `abort` -- `"killed"`, or `"pattern"` for exit 2 with no hits and no
---   "(os error N)" in stderr (a pattern/flag error reads the same for every
---   file list): the caller should not spawn more of them. A missing/unreadable
---   file in one chunk is not an abort.
---@internal
---@param cmd string[]
---@param root string
---@param timeout integer
---@param tool string
---@param benign_code integer|nil
---@return string[] lines
---@return string|nil problem
---@return boolean spawn_failed
---@return "killed"|"pattern"|false abort
local function run(cmd, root, timeout, tool, benign_code)
  local ok, res = pcall(function()
    return vim.system(cmd, spawn_env.apply({ cwd = root, text = true })):wait(timeout)
  end)
  local problem = search.classify_run(tool, root, ok, res, benign_code)
  local spawn_failed = not ok
  local killed = (ok and not res) or (res ~= nil and res.signal ~= nil and res.signal ~= 0)
  local lines = {}
  if ok and res and res.stdout then
    for line in res.stdout:gmatch("[^\r\n]+") do
      lines[#lines + 1] = line
    end
  end
  if problem and res and not killed then
    if res.code == 2 and #lines > 0 then
      problem = nil
    elseif type(res.stderr) == "string" then
      local reason = stderr_reason(res.stderr)
      if reason then problem = problem .. ": " .. reason end
    end
  end
  -- Exit 2 without hits is either a pattern/flag error, which reads the same for
  -- every file list, or a missing/unreadable file, which is specific to its
  -- chunk. rg ends every I/O error with "(os error N)" (also in a localised
  -- message), so that suffix -- not a word that a file NAME could contain --
  -- tells the chunk-specific kind: it must not stop the other chunks.
  local abort = false ---@type string|false
  if killed then
    abort = "killed"
  elseif res ~= nil and res.code == 2 and #lines == 0 and type(res.stderr) == "string" then
    if not res.stderr:find("%(os error %d+%)") then abort = "pattern" end
  end
  return lines, problem, spawn_failed, abort
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
    local lines, problem, hard = run(cmd, root, timeout, "fd")
    local paths = {}
    for i, line in ipairs(lines) do
      paths[i] = search.unify_path(line)
    end
    table.sort(paths)
    return { paths = paths, problems = problem and { problem } or {}, failed = hard }
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

---Files among `paths` that also contain `pattern`, as a set. rg is pointed at
---exactly those files (so it opens only them), over as many command lines as
---ARGV_BUDGET requires; when that would be more than MAX_CHUNKS spawns, or when
---`rg` is a .cmd/.bat shim, it scans the whole tree once instead.
---
---Each survivor is passed as `./<path>`: a bare `-` would be read as stdin even
---after `--`. rg echoes `./<path>` back and `search.unify_path` strips it.
---@internal
---@param explicit_ok boolean  false when `rg` is a .cmd/.bat shim (cmd.exe would interpret file names)
---@return table<string, boolean> set
---@return string|nil problem  first problem of any spawn
---@return boolean spawn_failed  any spawn could not run
---@return boolean aborted  stopped early (killed, pattern error, spawn failure)
local function narrow(rg, root, find, extra, pattern, paths, timeout, explicit_ok)
  local base = { rg }
  vim.list_extend(base, search.rg_files_args(find or {}, rg_extra(find, extra), pattern))

  local cmds ---@type string[][]|nil
  if explicit_ok then
    local base_len = 0
    for _, a in ipairs(base) do
      base_len = base_len + #a + 1
    end
    local chunks, chunk, size = {}, {}, base_len
    for _, p in ipairs(paths) do
      local len = #p + 3 -- "./" and the separator
      if #chunk > 0 and size + len > ARGV_BUDGET then
        chunks[#chunks + 1] = chunk
        chunk, size = {}, base_len
      end
      chunk[#chunk + 1] = "./" .. p
      size = size + len
    end
    if #chunk > 0 then chunks[#chunks + 1] = chunk end
    if #chunks <= MAX_CHUNKS then
      cmds = {}
      for i, c in ipairs(chunks) do
        cmds[i] = vim.list_extend(vim.list_slice(base), c)
      end
    end
  end
  cmds = cmds or { base }

  local set, first_problem, any_failed, aborted = {}, nil, false, false
  for i, cmd in ipairs(cmds) do
    local lines, problem, spawn_failed, abort = run(cmd, root, timeout, "rg", 1)
    for _, line in ipairs(lines) do
      set[search.unify_path(line)] = true
    end
    if spawn_failed or abort then
      -- Do not multiply a failure (every chunk would time out, or hit the same
      -- regex error) by the number of chunks. A pattern error is a definitive
      -- (empty) answer and a kill usually says "may be truncated"; anything that
      -- left later chunks unsearched without saying so is flagged.
      local unsearched = i < #cmds and (spawn_failed or abort == "killed")
      local says_so = problem ~= nil and problem:find("truncated", 1, true) ~= nil
      local incomplete = (unsearched and not says_so) and " -- results incomplete" or ""
      first_problem = (problem or "rg did not finish") .. incomplete
      any_failed = spawn_failed
      aborted = true
      break
    end
    first_problem = first_problem or problem
  end
  return set, first_problem, any_failed, aborted
end

---The first pattern's run for `root`, memoised under its own key so editing a
---LATER `grep=` token (or a path word) never repeats this full-tree scan.
---@internal
---@return Pickers.FileGrep.Entry
local function first_run(rg, root, find, extra, pattern, timeout)
  local key = table.concat({
    "rg1",
    root,
    vim.inspect(find or {}),
    vim.inspect(extra or {}),
    pattern,
  }, "\1")
  return cached(key, function()
    local first_extra = vim.list_extend({ "--max-count", "1" }, rg_extra(find, extra))
    local cmd = { rg }
    vim.list_extend(cmd, search.rg_args(find or {}, first_extra, pattern))
    local lines, problem, hard = run(cmd, root, timeout, "rg", 1)

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

    local paths, hits = {}, {}
    for i, r in ipairs(rows) do
      paths[i] = r.path
      hits[i] = { lnum = r.lnum, col = r.col, text = r.text }
    end
    return { paths = paths, hits = hits, problems = problem and { problem } or {}, failed = hard }
  end)
end

---Files below `root` matching every pattern in `patterns`; the first pattern
---also supplies the position/text of its first hit. Every further pattern
---narrows the survivors (memoised per pattern set on top of the first run).
---@internal
---@return Pickers.FileGrep.Entry
local function grep_files(root, find, extra, patterns, timeout, rg, explicit_ok)
  if not rg then return { paths = {}, problems = { "rg not found on PATH" } } end
  if #patterns == 1 then return first_run(rg, root, find, extra, patterns[1], timeout) end

  -- The narrowed result is looked up FIRST: first_run()'s own memo may have
  -- expired while this one is still live, and re-running the full-tree scan
  -- only to throw its result away would be the most expensive step.
  local key = table.concat({
    "rgN",
    root,
    vim.inspect(find or {}),
    vim.inspect(extra or {}),
    table.concat(patterns, "\0"),
  }, "\1")
  return cached(key, function()
    local base = first_run(rg, root, find, extra, patterns[1], timeout)
    if #base.paths == 0 or base.failed then return base end
    local problems = vim.list_extend({}, base.problems)
    local paths, hits, failed = base.paths, base.hits, false
    for i = 2, #patterns do
      if #paths == 0 then break end
      local set, problem, hard, aborted =
        narrow(rg, root, find, extra, patterns[i], paths, timeout, explicit_ok)
      if problem then problems[#problems + 1] = problem end
      if hard then failed = true end
      local kept_paths, kept_hits = {}, {}
      for j, p in ipairs(paths) do
        if set[p] then
          kept_paths[#kept_paths + 1] = p
          kept_hits[#kept_hits + 1] = hits[j]
        end
      end
      paths, hits = kept_paths, kept_hits
      -- A killed run or a pattern error would only repeat for the next token:
      -- stop here instead of multiplying it by the number of tokens. The rows
      -- left over were not checked against the remaining tokens -- say so.
      if aborted then
        if i < #patterns and #paths > 0 and problem then
          problems[#problems] = problems[#problems] .. " -- later patterns not applied"
        end
        break
      end
    end
    return { paths = paths, hits = hits, problems = problems, failed = failed }
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

  -- Resolve the tool once per query (memoised by lib.nvim, with a throttled
  -- re-check of a miss -- see search.find_tool).
  local fd = (not has_grep) and search.find_tool({ "fd", "fdfind" }) or nil
  local rg = has_grep and search.find_tool("rg") or nil
  -- A .cmd/.bat shim goes through cmd.exe, which interprets `& | < > ^ % !` and
  -- quotes in ANY argument: file names are never put on its command line
  -- (narrow() scans the tree instead) and a pattern containing one is refused.
  local explicit_ok = true
  if has_grep and rg then
    explicit_ok = not search.is_cmd_shim(rg)
    if not explicit_ok then
      for _, pattern in ipairs(parsed.grep) do
        local refusal = search.shim_refusal(rg, pattern)
        if refusal then
          local problems = { refusal }
          search.report(problems)
          return {}, problems
        end
      end
    end
  end
  local multi = #roots > 1

  -- Parallel arrays instead of a table per candidate: ents[k] = cache entry,
  -- idxs[k] = row in it, scs[k] = score, roots_of[k] = its root.
  local ents, idxs, scs, roots_of = {}, {}, {}, {}
  local n = 0
  local problems = {} ---@type string[]

  for _, root in ipairs(roots) do
    root = vim.fs.normalize(root)
    local entry
    if has_grep then
      entry =
        grep_files(root, opts.find, opts.additional_args, parsed.grep, timeout, rg, explicit_ok)
    else
      entry = list_files(root, opts.find, timeout, fd)
    end
    vim.list_extend(problems, entry.problems)
    local paths = entry.paths

    if #needles == 0 then
      -- Nothing to score: every row ties, so each root's (already sorted)
      -- listing is its ranking and only its first `limit` rows can ever make
      -- the cut. Several roots are merged by path below.
      local take = #paths
      if limit and take > limit then take = limit end
      for i = 1, take do
        n = n + 1
        ents[n], idxs[n], scs[n], roots_of[n] = entry, i, 0, root
      end
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
    if multi then
      table.sort(order, function(a, b)
        local pa, pb = ents[a].paths[idxs[a]], ents[b].paths[idxs[b]]
        if pa == pb then return a < b end
        return pa < pb
      end)
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
      abspath = search.join_root(root, path),
      lnum = hit and hit.lnum or nil,
      col = hit and hit.col or nil,
      text = hit and hit.text or nil,
      score = scs[k],
      display = display(path, hit),
      _rank = r,
    }
  end

  search.report(problems)
  return items, problems
end

return M
