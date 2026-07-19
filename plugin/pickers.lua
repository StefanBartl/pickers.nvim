-- Auto-loaded by Neovim when the plugin is on the runtimepath.
-- Registers :Pickers immediately (built-in scopes only — collections are not
-- known yet); auto-applies default bindings at VimEnter unless the user has
-- already called setup() via their config function. setup() (or the VimEnter
-- fallback) re-registers :Pickers with live collections, see
-- pickers.bindings.setup.
if vim.g.pickers_nvim_loaded then return end
vim.g.pickers_nvim_loaded = true

require("pickers.command.composer").register(require("pickers.config").get())

-- If the user did NOT call setup() in their config (e.g. no config = function()
-- block, or the plugin loaded after VimEnter), register default bindings via the
-- VimEnter fallback autocmd. See pickers.bindings.autocmds for details.
require("pickers.bindings.autocmds").register()
