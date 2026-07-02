---@module 'pickers.bindings.autocmds'
---@brief Autocmds owned by pickers.nvim.
---@description
--- VimEnter fallback: if the user did NOT call setup() in their config (e.g. no
--- `config = function()` block, or the plugin loaded after VimEnter), register
--- the default keymaps and compat user-commands here. setup() sets
--- vim.g.pickers_nvim_setup_called = true before this fires, so the fallback is
--- only taken when bindings have not been registered yet.

local M = {}

---Register the VimEnter default-binding fallback. Called from plugin/pickers.lua.
function M.register()
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
end

return M
