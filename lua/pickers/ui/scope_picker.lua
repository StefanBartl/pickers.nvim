---@module 'pickers.ui.scope_picker'
---@brief Interactive scope selection via hover_select (with vim.ui.select fallback).

local M = {}

local SCOPES = {
  "cwd", "config", "folder",
  "repos", "wkdbooks",
  "system", "drives",
  "dir",
}

---Open the scope picker and call callback with the chosen scope (or nil on cancel).
---@param callback fun(Pickers.Scope|nil)
function M.open(callback)
  local ok, hover = pcall(require, "lib.nvim.ui.hover_select")
  if ok and hover and type(hover.open) == "function" then
    hover.open({
      title     = "Pickers — Scope",
      items     = SCOPES,
      on_select = callback,
    })
  else
    vim.ui.select(SCOPES, { prompt = "Scope:" }, callback)
  end
end

return M
