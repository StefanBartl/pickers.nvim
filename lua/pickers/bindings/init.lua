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
  end
  if cfg.usercmds and cfg.usercmds.enable then require("pickers.bindings.usrcmds").register() end
  for _, coll in ipairs(cfg.collections or {}) do
    require("pickers.bindings.collections").register(coll)
  end

  -- Declarative mappings: a second, more flexible keymap surface alongside
  -- the fixed keymaps.* fields above (any scope×action or builtin name,
  -- optional per-entry engine override). No-op when cfg.mappings is unset.
  require("pickers.mappings").apply(cfg)

  -- Everything pickers.nvim puts onto the engines' GLOBAL config, so it holds
  -- for every picker they open (native ones included): in-picker keys and
  -- entry actions, history, find.exclude, the display.* switches, the PDF text
  -- preview. One call per engine, once it is loaded -- see
  -- pickers.engines.patcher. Placed here (not in pickers.setup) so it also
  -- fires on the VimEnter fallback when the user never called setup(): the
  -- keys default to enabled, and should apply either way.
  require("pickers.engines.patcher").install(cfg)

  -- The quickfix window's preview + filter: a FileType qf trigger, so it
  -- applies to every list however it was filled (:grep, :make, an LSP
  -- reference list, a picker's send-to-qf).
  require("pickers.quickfix").setup(cfg)
end

return M
