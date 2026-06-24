---@module 'pickers.ui.scope_picker'
---@brief Interactive scope selection via hover_select (with vim.ui.select fallback).

local M = {}

local BASE_SCOPES = {
  "cwd", "config", "folder",
  "repos", "wkdbooks",
  "system", "drives",
  "dir",
}

---Build the complete scope list: built-in scopes + collection names from config.
---@return string[]
local function build_scope_list()
  local scopes = vim.list_extend({}, BASE_SCOPES)
  local ok, cfg_mod = pcall(require, "pickers.config")
  if ok then
    local cfg = cfg_mod.get()
    for _, coll in ipairs(cfg.collections or {}) do
      if type(coll.name) == "string" then
        scopes[#scopes + 1] = coll.name
      end
    end
  end
  return scopes
end

---Open the scope picker and call callback with the chosen scope (or nil on cancel).
---@param callback fun(string|nil)
function M.open(callback)
  local scopes = build_scope_list()
  local ok, hover = pcall(require, "lib.nvim.ui.hover_select")
  if ok and hover and type(hover.open) == "function" then
    hover.open({
      title     = "Pickers — Scope",
      items     = scopes,
      on_select = callback,
    })
  else
    vim.ui.select(scopes, { prompt = "Scope:" }, callback)
  end
end

return M
