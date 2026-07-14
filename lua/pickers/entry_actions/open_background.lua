---@module 'pickers.entry_actions.open_background'
---@brief Engine-agnostic open-in-background-buffer wrapper.
---@description
--- Shared core behind every picker's "open in background" entry action:
--- notify + lib.nvim.buffer.open_background. Picker-library specifics
--- (entry-path extraction, whether the picker stays open) live in the
--- sibling extract/*.lua and adapters/*.lua modules.

local notify = require("lib.nvim.notify").create("[pickers.entry_actions.open_background]")
local open_background_core = require("lib.nvim.buffer.open_background")

local fn = vim.fn

local M = {}

---Open `path` as a background buffer (bufadd+bufload, no focus change) and notify.
---@param path string Selected entry's path
---@return boolean ok
function M.run(path)
  if not path or path == "" then
    notify.warn("No valid path found")
    return false
  end

  local ok, bufnr_or_err = open_background_core(path)
  if not ok then
    notify.error(bufnr_or_err)
    return false
  end

  notify.info("Buffered: " .. fn.fnamemodify(path, ":t"))
  return true
end

return M
