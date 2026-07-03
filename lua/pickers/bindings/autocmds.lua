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
  local callback = function()
    if not vim.g.pickers_nvim_setup_called then
      local ok, cfg_mod = pcall(require, "pickers.config")
      if ok then
        local ok2, bindings = pcall(require, "pickers.bindings")
        if ok2 then
          bindings.setup(cfg_mod.get())
        end
      end
    end
  end

  -- Prefer lib.nvim.autocmd (named augroup + pcall-wrapped callback); fall back
  -- to the raw API so the fallback still fires without lib.nvim.
  local ok, lib_autocmd = pcall(require, "lib.nvim.autocmd")
  if ok and type(lib_autocmd) == "table" and type(lib_autocmd.create) == "function" then
    lib_autocmd.create("VimEnter", callback, {
      group = "pickers.nvim",
      once  = true,
      desc  = "pickers.nvim: register default bindings when setup() was not called",
    })
  else
    vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = callback })
  end
end

return M
