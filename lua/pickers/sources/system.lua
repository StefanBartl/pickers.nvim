---@module 'pickers.sources.system'
---@brief Source: systemwide fd-based file search.
---@description
--- Opens a vim.ui.input prompt for the user to specify a search.
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

---@return string|nil  "fd" | "fdfind" | nil
local function find_fd()
  if vim.fn.executable("fd") == 1 then return "fd" end
  if vim.fn.executable("fdfind") == 1 then return "fdfind" end
  return nil
end

---Parse user input into an fd argv table.
---@param input  string
---@param fd     string   fd executable name
---@return string[]
local function build_fd_cmd(input, fd)
  local name   = nil
  local ext    = nil
  local paths  = {}

  for token in input:gmatch("%S+") do
    if token:match("^%.[%w]+$") then
      ext = token:sub(2)
    elseif token:match("^[/\\]") or token:match("^%a:[/\\]") then
      paths[#paths + 1] = token
    elseif not name then
      name = token
    end
  end

  if #paths == 0 then
    paths = { "/" }
  end

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

  return cmd
end

-- ── Public API ────────────────────────────────────────────────────────────────

---Interactive fd search.  Calls engine_mod.pick_files() directly after user input.
---@param _cfg       Pickers.Config
---@param callback   fun(Pickers.Source|nil)   Called with nil on cancel, source on success.
function M.get(_cfg, callback)
  local fd = find_fd()
  if not fd then
    notify.error("Neither 'fd' nor 'fdfind' found in PATH. Install fd-find.")
    callback(nil)
    return
  end

  vim.ui.input({ prompt = "System search (name .ext /path ...): " }, function(input)
    if not input or input:match("^%s*$") then
      callback(nil)
      return
    end

    local cmd = build_fd_cmd(input, fd)
    callback({
      roots        = { "/" },
      prompt       = "System> ",
      find_command = cmd,
    })
  end)
end

return M
