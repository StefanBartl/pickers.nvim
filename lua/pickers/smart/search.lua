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
---     pickers.actions.files.
---   * grep  half → always --hidden --no-ignore-vcs --smart-case (+ any
---     source.additional_args), exactly like pickers.engines.*.live_grep.

local M = {}

local uv = vim.uv or vim.loop

---First executable found among `names`, or nil.
---@param names string[]
---@return string|nil
local function first_exe(names)
  for _, n in ipairs(names) do
    if vim.fn.executable(n) == 1 then return n end
  end
  return nil
end

---Build the fd argument list from find flags.
---@param find Pickers.FindOpts
---@param query string
---@return string[]
local function fd_args(find, query)
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
---@param extra string[]|nil  source.additional_args
---@param query string
---@return string[]
local function rg_args(extra, query)
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
  vim.list_extend(args, extra or {})
  args[#args + 1] = "--"
  args[#args + 1] = query
  return args
end

---Run fd + rg across every root and return the merged raw candidates.
---@param opts { roots: string[], query: string, find: Pickers.FindOpts, additional_args?: string[], timeout?: integer }
---@return Pickers.Smart.File[] files, Pickers.Smart.Grep[] greps
function M.collect(opts)
  local roots = opts.roots or { uv.cwd() or "." }
  local query = opts.query or ""
  local find = opts.find or {}
  local timeout = opts.timeout or 3000

  local fd = first_exe({ "fd", "fdfind" })
  local rg = first_exe({ "rg" })

  local files = {} ---@type Pickers.Smart.File[]
  local greps = {} ---@type Pickers.Smart.Grep[]

  for _, root in ipairs(roots) do
    root = vim.fs.normalize(root)

    -- ── files (fd) ──────────────────────────────────────────────────────────
    if fd then
      local cmd = { fd }
      vim.list_extend(cmd, fd_args(find, query))
      local ok, res = pcall(function()
        return vim.system(cmd, { cwd = root, text = true }):wait(timeout)
      end)
      if ok and res and res.stdout then
        for line in res.stdout:gmatch("[^\r\n]+") do
          local rel = vim.fs.normalize(line) -- forward slashes on every OS
          files[#files + 1] = {
            path = rel,
            root = root,
            abspath = vim.fs.normalize(root .. "/" .. rel),
          }
        end
      end
    end

    -- ── grep (rg) ───────────────────────────────────────────────────────────
    -- Skip on an empty query: rg needs a pattern, and an empty prompt should
    -- behave like a file picker (files only), filling in once the user types.
    if rg and query ~= "" then
      local cmd = { rg }
      vim.list_extend(cmd, rg_args(opts.additional_args, query))
      local ok, res = pcall(function()
        return vim.system(cmd, { cwd = root, text = true }):wait(timeout)
      end)
      if ok and res and res.stdout then
        for line in res.stdout:gmatch("[^\r\n]+") do
          -- vimgrep: file:line:col:text
          local file, l, c, text = line:match("^(.-):(%d+):(%d+):(.*)$")
          if file then
            local rel = vim.fs.normalize(file) -- forward slashes on every OS
            greps[#greps + 1] = {
              path = rel,
              root = root,
              abspath = vim.fs.normalize(root .. "/" .. rel),
              lnum = tonumber(l),
              col = tonumber(c),
              text = text,
            }
          end
        end
      end
    end
  end

  return files, greps
end

return M
