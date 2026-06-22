---@module 'pickers'
---@brief pickers.nvim — unified fuzzy-picker plugin.
---@description
--- Consolidates find_config, find_in_folder, dir_picker, repo_pickers,
--- grep, search_all_drives and system_find into one plugin backed by a
--- single telescope or fzf-lua engine (auto-detected from what is installed).
---
--- Minimal setup (lazy.nvim example):
---   {
---     "StefanBartl/pickers.nvim",
---     dependencies = { "StefanBartl/lib.nvim" },
---     config = function()
---       require("pickers").setup({
---         engine    = "auto",          -- "telescope" | "fzf" | "auto"
---         repos_dir = vim.env.REPOS_DIR,
---       })
---     end,
---   }
---
--- After setup the following are active (if not disabled):
---   :Pickers [scope] [nav|action] [action]  — unified command
---   All compat commands (:FindConfig, :GrepConfig, :DirPicker, …)
---   All preserved keymaps (<leader>dp, <leader>fb, <leader>fc, <leader>gc, <leader>li)

local M = {}

---Configure and activate pickers.nvim.
---
--- Calling setup() is required only when you want to change defaults or
--- disable keymaps/usercmds.  The :Pickers command is always registered by
--- plugin/pickers.lua regardless.
---
---@param opts Pickers.Config|nil
function M.setup(opts)
  require("pickers.config").apply(opts)
  local cfg = require("pickers.config").get()
  require("pickers.bindings").setup(cfg)
end

return M
