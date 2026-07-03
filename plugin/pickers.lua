-- Auto-loaded by Neovim when the plugin is on the runtimepath.
-- Registers :Pickers immediately; auto-applies default bindings at VimEnter
-- unless the user has already called setup() via their config function.
if vim.g.pickers_nvim_loaded then return end
vim.g.pickers_nvim_loaded = true

local pickers_cmd_opts = {
  nargs = "*",
  desc = "[pickers.nvim] :Pickers [scope] [nav|action] [action]",
  complete = function(arglead, cmdline, cursorpos)
    return require("pickers.command").complete(arglead, cmdline, cursorpos)
  end,
}
local function pickers_cmd(opts)
  require("pickers.command").handle(opts)
end

-- Prefer lib.nvim.usercmd (pcall-wrapped callback); fall back to the raw API so
-- :Pickers is always registered even if lib.nvim is not installed.
local ok_usercmd, lib_usercmd = pcall(require, "lib.nvim.usercmd")
if ok_usercmd and type(lib_usercmd) == "table" and type(lib_usercmd.create) == "function" then
  lib_usercmd.create("Pickers", pickers_cmd, pickers_cmd_opts)
else
  vim.api.nvim_create_user_command("Pickers", pickers_cmd, pickers_cmd_opts)
end

-- If the user did NOT call setup() in their config (e.g. no config = function()
-- block, or the plugin loaded after VimEnter), register default bindings via the
-- VimEnter fallback autocmd. See pickers.bindings.autocmds for details.
require("pickers.bindings.autocmds").register()
