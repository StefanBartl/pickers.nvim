-- Auto-loaded by Neovim when the plugin is on the runtimepath.
-- Registers the :Pickers command eagerly; all heavy requires are deferred.
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
