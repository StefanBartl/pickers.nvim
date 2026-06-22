---@module 'pickers.ui.action_picker'
---@brief Interactive action selection via hover_select (with vim.ui.select fallback).

local M = {}

local ACTIONS = { "files", "grep" }

---Open the action picker and call callback with the chosen action (or nil on cancel).
---@param callback fun(Pickers.Action|nil)
function M.open(callback)
  local ok, hover = pcall(require, "lib.nvim.ui.hover_select")
  if ok and hover and type(hover.open) == "function" then
    hover.open({
      title     = "Pickers — Action",
      items     = ACTIONS,
      on_select = callback,
    })
  else
    vim.ui.select(ACTIONS, { prompt = "Action:" }, callback)
  end
end

return M
