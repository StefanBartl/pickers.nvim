---@module 'pickers.ui.action_picker'
---@brief Interactive action selection via lib.nvim.ui.kit (with vim.ui.select fallback).

local M = {}

local ACTIONS = { "files", "grep", "smart" }

---Open the action picker and call callback with the chosen action (or nil on cancel).
---@param callback fun(Pickers.Action|nil)
function M.open(callback)
  local ok, kit = pcall(require, "lib.nvim.ui.kit")
  if ok and kit and type(kit.select) == "function" then
    kit.select({
      title = "Pickers — Action",
      items = ACTIONS,
      on_select = callback,
    })
  else
    vim.ui.select(ACTIONS, { prompt = "Action:" }, callback)
  end
end

return M
