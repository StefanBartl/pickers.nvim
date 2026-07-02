-- Auto-loaded by Neovim when the plugin is on the runtimepath.
-- Registers :Pickers immediately; auto-applies default bindings at VimEnter
-- unless the user has already called setup() via their config function.
if vim.g.pickers_nvim_loaded then return end
vim.g.pickers_nvim_loaded = true

vim.api.nvim_create_user_command("Pickers", function(opts)
  require("pickers.command").handle(opts)
end, {
  nargs    = "*",
  desc     = "[pickers.nvim] :Pickers [scope] [nav|action] [action]",
  complete = function(arglead, cmdline, cursorpos)
    return require("pickers.command").complete(arglead, cmdline, cursorpos)
  end,
})

-- If the user did NOT call setup() in their config (e.g. no config = function()
-- block, or the plugin loaded after VimEnter), register default bindings via the
-- VimEnter fallback autocmd. See pickers.bindings.autocmds for details.
require("pickers.bindings.autocmds").register()
