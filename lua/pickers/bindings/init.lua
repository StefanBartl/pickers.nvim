---@module 'pickers.bindings'
---@brief Aggregator: registers all keymaps, user-commands and collection bindings.
---@see pickers.bindings.keymaps
---@see pickers.bindings.usrcmds
---@see pickers.bindings.collections
---@see pickers.bindings.autocmds
---@description
--- A structured, human-readable reference of every binding lives in
--- `docs/BINDINGS.md`. Keep it in sync when changing registrations here.

local M = {}

---@param cfg Pickers.Config
function M.setup(cfg)
  -- Re-register :Pickers so its route tree (and <Tab> completion) picks up
  -- cfg.collections — the plugin/pickers.lua registration only knows the
  -- built-in scopes since it fires before setup() has run.
  require("pickers.command.composer").register(cfg)

  if cfg.keymaps and cfg.keymaps.enable then
    require("pickers.bindings.keymaps").register(cfg.keymaps)
    require("pickers.bindings.whichkey").register(cfg.keymaps)
  end
  if cfg.usercmds and cfg.usercmds.enable then require("pickers.bindings.usrcmds").register() end
  for _, coll in ipairs(cfg.collections or {}) do
    require("pickers.bindings.collections").register(coll)
  end
end

return M
