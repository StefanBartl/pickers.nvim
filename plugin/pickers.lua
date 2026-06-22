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
-- block, or the plugin loaded after VimEnter), register default bindings here.
-- setup() sets vim.g.pickers_nvim_setup_called = true before we fire, so this
-- branch is only taken when bindings have not been registered yet.
vim.api.nvim_create_autocmd("VimEnter", {
  once     = true,
  callback = function()
    if not vim.g.pickers_nvim_setup_called then
      local ok, cfg_mod = pcall(require, "pickers.config")
      if ok then
        local ok2, bindings = pcall(require, "pickers.bindings")
        if ok2 then
          bindings.setup(cfg_mod.get())
        end
      end
    end
  end,
})
