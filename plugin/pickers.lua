-- Auto-loaded by Neovim when the plugin is on the runtimepath.
-- Registers :Pickers immediately (built-in scopes only — collections are not
-- known yet); auto-applies default bindings at VimEnter unless the user has
-- already called setup() via their config function. setup() (or the VimEnter
-- fallback) re-registers :Pickers with live collections, see
-- pickers.bindings.setup.
if vim.g.pickers_nvim_loaded then return end
vim.g.pickers_nvim_loaded = true

-- Passed directly instead of require("pickers.config").get(): composer.register
-- only reads cfg.collections, which is always {} before setup() runs anyway --
-- no reason to materialize the full DEFAULTS table (deepcopy + lib.nvim reads)
-- just for this early, collections-less registration.
require("pickers.command.composer").register({ collections = {} })

-- If the user did NOT call setup() in their config (e.g. no config = function()
-- block, or the plugin loaded after VimEnter), register default bindings via the
-- VimEnter fallback autocmd. See pickers.bindings.autocmds for details.
require("pickers.bindings.autocmds").register()
