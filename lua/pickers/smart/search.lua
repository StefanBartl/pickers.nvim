---@module 'pickers.smart.search'
---@brief Runs fd (files) + rg (grep) for one query and returns raw candidates.
---@description
--- Synchronous by design: every engine adapter calls this from inside its own
--- per-keystroke callback (snacks finder / telescope dynamic fn / fzf-lua live
--- fn), each of which expects a finished result set to hand back. rg and fd are
--- fast and the engines debounce input, so a short blocking `vim.system():wait()`
--- keeps the shared core trivially portable across all three engines instead of
--- reinventing three different async result-streaming integrations.
---
--- The two halves deliberately mirror the existing single-purpose actions so
--- "smart" covers the same ground as running them separately:
---   * files half → honours cfg.find (hidden/no_ignore/follow/exclude), like
---     pickers.actions.files. See `M.fd_args`.
---   * grep  half → always --hidden --no-ignore-vcs --smart-case (+ any
---     source.additional_args), exactly like pickers.engines.*.live_grep;
---     `find.exclude` is honoured too (the other find.* flags don't apply,
---     same as live_grep). See `M.rg_args`.
---
--- `fd_args`/`rg_args` are exported (rather than kept local) purely so they
--- are unit-testable as pure functions -- both run through `vim.system`
--- with an argv list (no shell), so exclude globs are passed raw/unescaped
--- here, unlike `pickers.engines.fzf`'s shell-string `rg_opts`.

local M = {}

local uv = vim.uv or vim.loop
local spawn_env = require("lib.nvim.cross.run.env")

---Seconds before a tool that was not found is looked up on PATH again.
local TOOL_RETRY_S = 30
---@type table<string, number>  lookup key -> hrtime (s) of its last from-scratch retry
local tool_retry_at = {}

---First executable found among `names` (a name or a list), or nil. Through
---lib.nvim's memoised lookup: a PATH walk costs milliseconds on Windows and this
---runs on every keystroke. That memo also remembers "not installed" for the
---whole session, so a miss is re-checked from scratch at most once per
---TOOL_RETRY_S (per lookup key, not shared between tools): a tool installed
---while nvim runs is picked up without a restart, and a really missing one
---costs one PATH walk per window, not one per keystroke.
---@param names string|string[]
---@return string|nil
function M.find_tool(names)
  local exe = require("lib.nvim.cross.executable")
  local found = exe.find(names)
  if found then return found end
  local key = type(names) == "table" and table.concat(names, "|") or names
  local now = uv.hrtime() / 1e9
  local last = tool_retry_at[key]
  if last and now - last < TOOL_RETRY_S then return nil end
  tool_retry_at[key] = now
  for _, name in ipairs(type(names) == "table" and names or { names }) do
    exe.clear(name)
  end
  return exe.find(names)
end

---Forget the retry stamps, so the next miss looks the tool up again at once
---(tests, and a manual refresh).
function M.reset_tool_retry()
  tool_retry_at = {}
end

---@internal
---@param names string[]
---@return string|nil
local function first_exe(names)
  return M.find_tool(names)
end

---Seconds before the same problem message is shown again.
local REPORT_EVERY_S = 10
local last_msg, last_at = nil, 0

---Show the first problem of a run (ERR-11: a broken fd/rg run, or a prompt that
---was refused, must not look like zero matches), at most once per
---REPORT_EVERY_S for the same message so typing does not flood the screen. The
---engine adapters only read a core's items, so the cores call this themselves.
---@param problems string[]|nil
function M.report(problems)
  local msg = problems and problems[1]
  if not msg then return end
  local now = uv.hrtime() / 1e9
  if msg == last_msg and now - last_at < REPORT_EVERY_S then return end
  last_msg, last_at = msg, now
  vim.schedule(function()
    require("lib.nvim.notify").create("[pickers.search]").warn(msg)
  end)
end

---Forget the notification throttle (tests, and a manual refresh).
function M.reset_report()
  last_msg, last_at = nil, 0
end

---Characters cmd.exe interprets inside an argument.
M.CMD_META = '[&|<>%^%%!"]'

---True when `name` resolves to a `.cmd`/`.bat` shim: its command line then goes
---through cmd.exe, which interprets `& | < > ^ % !` and quotes in ANY argument.
---@param name string
---@return boolean
function M.is_cmd_shim(name)
  local path = require("lib.nvim.cross.executable").path(name)
  if not path then return false end
  local lower = path:lower()
  return lower:match("%.cmd$") ~= nil or lower:match("%.bat$") ~= nil
end

---A problem message when `text` would be interpreted by cmd.exe on its way to
---`tool` (a .cmd/.bat shim), else nil. Such a prompt is refused, not passed on.
---@param tool string
---@param text string
---@return string|nil
function M.shim_refusal(tool, text)
  if text:find(M.CMD_META) and M.is_cmd_shim(tool) then
    local binary = tool == "fdfind" and "fd" or tool -- the Debian alias has no .exe
    return tool
      .. ' is a .cmd/.bat shim: a pattern containing & | < > ^ % ! or " cannot be '
      .. "passed to it safely (install "
      .. binary
      .. ".exe)"
  end
  return nil
end

---Forward-slash form of a path printed by fd/rg, without the `./` prefix some
---versions emit. A pure string transform on purpose: `vim.fs.normalize` also
---expands a leading `~` and `$VAR`, which would rewrite real file names such as
---`~$report.docx` (Office lock files) into a different, non-existent path.
---Backslashes are only separators on Windows; on POSIX they are legal file-name
---characters and are left alone.
---@param p string
---@return string
function M.unify_path(p)
  local s = p
  if require("lib.nvim.cross.platform.is_windows")() then
    s = require("lib.nvim.cross.fs.separators.unify_slashes")(p)
  end
  s = s:gsub("^%./", "")
  return s
end

---Join a (normalised) search root and a relative path without doubling the
---separator: a drive root arrives as `C:/`, which `root .. "/" .. rel` would turn
---into `C://rel`.
---@param root string
---@param rel string
---@return string
function M.join_root(root, rel)
  return (root:gsub("/+$", "")) .. "/" .. rel
end

---Build the fd argument list from find flags.
---@param find Pickers.FindOpts
---@param query string
---@return string[]
function M.fd_args(find, query)
  local args = { "--type", "f", "--color", "never", "--exclude", ".git" }
  if find.hidden then args[#args + 1] = "--hidden" end
  if find.no_ignore then args[#args + 1] = "--no-ignore" end
  if find.follow then args[#args + 1] = "--follow" end
  for _, e in ipairs(find.exclude or {}) do
    args[#args + 1] = "--exclude"
    args[#args + 1] = e
  end
  -- fd treats a bare positional as a regex matched against the path; an empty
  -- query lists everything (file-picker feel on an empty prompt).
  if query ~= "" then args[#args + 1] = query end
  return args
end

---Build the rg argument list (vimgrep format). Mirrors live_grep's flags.
---@param find Pickers.FindOpts  only `.exclude` is honoured (rest is hardcoded below)
---@param extra string[]|nil  source.additional_args
---@param query string
---@return string[]
function M.rg_args(find, extra, query)
  local args = {
    "--vimgrep",
    "--color",
    "never",
    "--smart-case",
    "--hidden",
    "--no-ignore-vcs",
    "--max-columns",
    "500",
    "-g",
    "!.git",
  }
  for _, e in ipairs((find or {}).exclude or {}) do
    args[#args + 1] = "-g"
    args[#args + 1] = "!" .. e
  end
  vim.list_extend(args, extra or {})
  args[#args + 1] = "--"
  args[#args + 1] = query
  return args
end

---Build the rg argument list for "which files contain `pattern`" (one path per
---line, no line numbers). Same flags as `rg_args`; used by pickers.filegrep to
---AND several `grep=` patterns together.
---@param find Pickers.FindOpts  only `.exclude` is honoured
---@param extra string[]|nil  source.additional_args
---@param pattern string
---@return string[]
function M.rg_files_args(find, extra, pattern)
  local args = {
    "--files-with-matches",
    "--color",
    "never",
    "--smart-case",
    "--hidden",
    "--no-ignore-vcs",
    "-g",
    "!.git",
  }
  for _, e in ipairs((find or {}).exclude or {}) do
    args[#args + 1] = "-g"
    args[#args + 1] = "!" .. e
  end
  vim.list_extend(args, extra or {})
  args[#args + 1] = "--"
  args[#args + 1] = pattern
  return args
end

---Classify a finished (or failed) `vim.system` run as a problem string, or
---nil for a normal outcome -- including a tool's own "no matches" exit code,
---which is not an error. Lets `M.collect` tell "empty because nothing
---matched" apart from "empty (or truncated) because the run itself broke"
---(ERR-11): a killed-at-timeout or non-zero run currently looks identical to
---a real zero-match query to every caller above this function.
---@internal
---@param tool string
---@param root string
---@param ok boolean               pcall status around the spawn+wait
---@param res vim.SystemCompleted|nil
---@param benign_code integer|nil  an extra exit code that is not an error (rg: 1 = no matches)
---@return string|nil
function M.classify_run(tool, root, ok, res, benign_code)
  if not ok then return tool .. " failed to run in " .. root .. ": " .. tostring(res) end
  if not res then return tool .. " produced no result in " .. root end
  if res.signal and res.signal ~= 0 then
    return tool
      .. " was killed (signal "
      .. res.signal
      .. ") in "
      .. root
      .. " -- results may be truncated"
  end
  if res.code ~= 0 and res.code ~= benign_code then
    return tool .. " exited " .. res.code .. " in " .. root
  end
  return nil
end

---Run fd + rg across every root and return the merged raw candidates.
---@param opts { roots: string[], query: string, find: Pickers.FindOpts, additional_args?: string[], timeout?: integer }
---@return Pickers.Smart.File[] files, Pickers.Smart.Grep[] greps, string[] problems  Empty `problems` means every run finished cleanly (an empty `files`/`greps` is then a real "no matches", not a broken run) -- see `classify_run`.
function M.collect(opts)
  local roots = opts.roots or { uv.cwd() or "." }
  local query = opts.query or ""
  local find = opts.find or {}
  local timeout = opts.timeout or 3000

  local fd = first_exe({ "fd", "fdfind" })
  local rg = first_exe({ "rg" })

  local files = {} ---@type Pickers.Smart.File[]
  local greps = {} ---@type Pickers.Smart.Grep[]
  local problems = {} ---@type string[]

  for _, root in ipairs(roots) do
    root = vim.fs.normalize(root)

    -- ── files (fd) ──────────────────────────────────────────────────────────
    local fd_refusal = fd and M.shim_refusal(fd, query)
    if fd_refusal then
      problems[#problems + 1] = fd_refusal
      fd = nil -- not for the remaining roots either: same prompt, same shim
    end
    if fd then
      local cmd = { fd }
      vim.list_extend(cmd, M.fd_args(find, query))
      local ok, res = pcall(function()
        return vim.system(cmd, spawn_env.apply({ cwd = root, text = true })):wait(timeout)
      end)
      local problem = M.classify_run("fd", root, ok, res)
      if problem then problems[#problems + 1] = problem end
      if ok and res and res.stdout then
        for line in res.stdout:gmatch("[^\r\n]+") do
          local rel = M.unify_path(line) -- forward slashes on every OS
          files[#files + 1] = {
            path = rel,
            root = root,
            abspath = M.join_root(root, rel),
          }
        end
      end
    end

    -- ── grep (rg) ───────────────────────────────────────────────────────────
    -- Skip on an empty query: rg needs a pattern, and an empty prompt should
    -- behave like a file picker (files only), filling in once the user types.
    local rg_refusal = rg and query ~= "" and M.shim_refusal(rg, query)
    if rg_refusal then
      problems[#problems + 1] = rg_refusal
      rg = nil
    end
    if rg and query ~= "" then
      local cmd = { rg }
      vim.list_extend(cmd, M.rg_args(find, opts.additional_args, query))
      local ok, res = pcall(function()
        return vim.system(cmd, spawn_env.apply({ cwd = root, text = true })):wait(timeout)
      end)
      -- rg's own exit code 1 means "ran fine, matched nothing" -- benign.
      local problem = M.classify_run("rg", root, ok, res, 1)
      -- Exit 2 WITH hits is a partial success (one unreadable file or dangling
      -- symlink in the tree): the hits stand, there is nothing to warn about.
      if
        problem
        and ok
        and res
        and res.code == 2
        and (res.signal == nil or res.signal == 0)
        and type(res.stdout) == "string"
        and res.stdout ~= ""
      then
        problem = nil
      end
      if problem then problems[#problems + 1] = problem end
      if ok and res and res.stdout then
        for line in res.stdout:gmatch("[^\r\n]+") do
          -- vimgrep: file:line:col:text
          local file, l, c, text = line:match("^(.-):(%d+):(%d+):(.*)$")
          if file then
            local rel = M.unify_path(file) -- forward slashes on every OS
            greps[#greps + 1] = {
              path = rel,
              root = root,
              abspath = M.join_root(root, rel),
              -- `(%d+)` guarantees digits, so neither conversion can fail and
              -- neither result is fractional.
              lnum = tonumber(l) --[[@as integer]],
              col = tonumber(c) --[[@as integer]],
              text = text,
            }
          end
        end
      end
    end
  end

  return files, greps, problems
end

return M
