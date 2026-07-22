---@module 'pickers.ui.scope_picker'
---@brief Interactive scope selection via lib.nvim.ui.kit (with vim.ui.select fallback).

local M = {}

local BASE_SCOPES = {
  "cwd",
  "config",
  "folder",
  "repos",
  "wkdbooks",
  "system",
  "drives",
  "dir",
}

---Build the complete scope list: built-in scopes + collection names from config.
---Exported (not just module-local) so `:PickersScopes` can list the same set
---without opening an interactive picker -- see pickers.bindings.usrcmds.
---@return string[]
function M.list()
  local scopes = vim.list_extend({}, BASE_SCOPES)
  local ok, cfg_mod = pcall(require, "pickers.config")
  if ok then
    local cfg = cfg_mod.get()
    for _, coll in ipairs(cfg.collections or {}) do
      if type(coll.name) == "string" then scopes[#scopes + 1] = coll.name end
    end
  end
  return scopes
end

---Open the scope picker and call callback with the chosen scope (or nil on cancel).
---@param callback fun(string|nil)
function M.open(callback)
  local scopes = M.list()
  local ok, kit = pcall(require, "lib.nvim.ui.kit")
  if ok and kit and type(kit.select) == "function" then
    kit.select({
      title = "Pickers — Scope",
      items = scopes,
      on_select = callback,
    })
  else
    vim.ui.select(scopes, { prompt = "Scope:" }, callback)
  end
end

return M
