---@module 'pickers.sources.system'
---@brief Source: systemwide fd-based file search.
---@description
--- Opens a lib.nvim.ui.kit.input prompt for the user to specify a search.
--- Input format (whitespace-separated tokens, any order):
---   name        – substring filename match (first bare word)
---   .ext        – file extension (token starting with ".")
---   /path or C:\path  – search root(s) (absolute path tokens)
---
--- Example: ".lua /home/user" or "init .lua"
---
--- After collecting input this module calls engine_mod.pick_files() directly
--- with a pre-built fd command, bypassing the normal source → action flow.

local notify = require("lib.nvim.notify").create("[pickers.sources.system]")

local M = {}

-- ── Helpers ──────────────────────────────────────────────────────────────────

---@internal
---@return string|nil  "fd" | "fdfind" | nil
local function find_fd()
  if vim.fn.executable("fd") == 1 then return "fd" end
  if vim.fn.executable("fdfind") == 1 then return "fdfind" end
  return nil
end

---Parse user input into an fd argv table.
---@internal
---@param input     string
---@param fd        string     fd executable name
---@param fallback  string[]   Roots to search when the input names no path
---@return string[] cmd
---@return string[] paths  The roots actually searched, for the engine's `roots`
local function build_fd_cmd(input, fd, fallback)
  local name = nil
  local ext = nil
  local paths = {}

  for token in input:gmatch("%S+") do
    if token:match("^%.[%w]+$") then
      ext = token:sub(2)
    elseif token:match("^[/\\]") or token:match("^%a:[/\\]") then
      paths[#paths + 1] = token
    elseif not name then
      name = token
    end
  end

  if #paths == 0 then paths = fallback end

  -- fd argv is: fd [OPTIONS] <pattern> <path...>. The pattern must always be the
  -- first positional — an empty string matches everything. Without it fd would
  -- misread the first path as the search pattern (cross-platform bug; on Windows
  -- an absolute path like "C:\..." is silently treated as a regex).
  local cmd = { fd, name or "" }
  for _, p in ipairs(paths) do
    cmd[#cmd + 1] = p
  end
  if ext then
    cmd[#cmd + 1] = "--extension"
    cmd[#cmd + 1] = ext
  end
  cmd[#cmd + 1] = "--hidden"
  cmd[#cmd + 1] = "--follow"

  return cmd, paths
end

---Whether the input already names at least one path to search.
---@internal
---@param input string
---@return boolean
local function has_path_token(input)
  for token in input:gmatch("%S+") do
    if token:match("^[/]") or token:match("^%a:[/]") then return true end
  end
  return false
end

---The roots to search when the user names no path at all.
---
---`"/"` is right on POSIX and inside WSL, and wrong on native Windows, where it
---resolves to the *current drive's* root -- so "systemwide search" silently
---became "search whatever drive Neovim happens to be on". There, every drive
---letter is the honest answer, and `pickers.sources.drives` already knows how
---to enumerate them.
---@internal
---@param cb fun(roots: string[])
local function default_roots(cb)
  local drives = require("pickers.sources.drives")
  if not drives.is_windows() then
    cb({ "/" })
    return
  end
  drives.roots(function(roots)
    cb((roots and #roots > 0) and roots or { "/" })
  end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

---Interactive fd search.  Calls engine_mod.pick_files() directly after user input.
---@param _cfg       Pickers.Config
---@param callback   fun(source: Pickers.Source|nil)   Called with nil on cancel, source on success.
function M.get(_cfg, callback)
  local fd = find_fd()
  if not fd then
    notify.error("Neither 'fd' nor 'fdfind' found in PATH. Install fd-find.")
    callback(nil)
    return
  end

  require("lib.nvim.ui.kit").input({
    title = "System search (name .ext /path ...): ",
    on_submit = function(input)
      if not input or input:match("^%s*$") then
        callback(nil)
        return
      end

      local function emit(fallback)
        -- `roots` used to be hard-coded to `{ "/" }` even when the input did
        -- name real paths, so the engine's cwd fallback pointed at a root that
        -- need not exist. Report what is actually searched.
        local cmd, paths = build_fd_cmd(input, fd, fallback)
        callback({
          roots = paths,
          prompt = "System> ",
          find_command = cmd,
        })
      end

      -- Only ask for the default roots when the input names none: on Windows
      -- that lookup spawns PowerShell, and an input like "foo /etc" has no use
      -- for it.
      if has_path_token(input) then
        emit({})
      else
        default_roots(emit)
      end
    end,
    on_cancel = function()
      callback(nil)
    end,
  })
end

return M
