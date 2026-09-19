---@module 'pickers.bindings.autocmds'
---@brief Autocmds owned by pickers.nvim.
---@description
--- VimEnter fallback: if the user did NOT call setup() in their config (e.g. no
--- `config = function()` block, or the plugin loaded after VimEnter), register
--- the default keymaps and compat user-commands here. setup() sets
--- vim.g.pickers_nvim_setup_called = true before this fires, so the fallback is
--- only taken when bindings have not been registered yet.
---
--- lib.nvim is a hard dependency (see pickers.bindings.util); this requires
--- lib.nvim.bindings.autocmd the same way, with no standalone fallback (LUA-01).

local lib_autocmd = require("lib.nvim.bindings.autocmd")

local M = {}

---Register the VimEnter default-binding fallback. Called from plugin/pickers.lua.
function M.register()
  local callback = function()
    if not vim.g.pickers_nvim_setup_called then
      local ok, cfg_mod = pcall(require, "pickers.config")
      if ok then
        local ok2, bindings = pcall(require, "pickers.bindings")
        if ok2 then bindings.setup(cfg_mod.get()) end
      end
    end
  end

  lib_autocmd.create("VimEnter", callback, {
    group = "pickers.nvim",
    once = true,
    desc = "pickers.nvim: register default bindings when setup() was not called",
  })
end

return M
