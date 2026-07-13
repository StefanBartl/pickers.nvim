---@module 'pickers'
---@brief pickers.nvim — unified fuzzy-picker plugin.
---@description
--- Consolidates find_config, find_in_folder, dir_picker, repo_pickers,
--- grep, search_all_drives and system_find into one plugin backed by a
--- single telescope or fzf-lua engine (auto-detected from what is installed).
---
--- Minimal setup (lazy.nvim):
---   {
---     "StefanBartl/pickers.nvim",
---     lazy = false,                       -- required: load at startup
---     dependencies = { "StefanBartl/lib.nvim" },
---     config = function()
---       require("pickers").setup({
---         engine    = "auto",
---         repos_dir = vim.env.REPOS_DIR,
---       })
---     end,
---   }
---
--- Without setup() the plugin still works — default keymaps and compat
--- user-commands are registered automatically at VimEnter by plugin/pickers.lua.

local M = {}

---Configure and activate pickers.nvim.
---
--- This sets vim.g.pickers_nvim_setup_called so that plugin/pickers.lua
--- does not redundantly re-register bindings at VimEnter.
---
---@param opts Pickers.Config|nil
function M.setup(opts)
  -- Mark as setup so the VimEnter fallback in plugin/pickers.lua is skipped.
  vim.g.pickers_nvim_setup_called = true

  require("pickers.config").apply(opts)
  local cfg = require("pickers.config").get()
  require("pickers.bindings").setup(cfg)

  if cfg.history.enabled then require("pickers.history").patch(cfg) end
end

return M
