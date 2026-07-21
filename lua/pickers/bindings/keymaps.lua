---@module 'pickers.bindings.keymaps'
---@brief Built-in normal-mode keymaps (registered when keymaps.enable = true).
---@description
---   <leader>dp     Dir navigation picker
---   <leader>fb     Find files in picked folder
---   <leader>fc     Find files in nvim config
---   <leader>gc     Grep in nvim config
---   <leader>li     Live grep in CWD
---   (cwd_files)    Find files in CWD              (nil by default)
---   (repos_files)  Pick a repo, then find files    (nil by default)
---   (repos_grep)   Pick a repo, then live grep     (nil by default)
---   (system_files) Systemwide fd search (prompts)  (nil by default)

local map = require("pickers.bindings.util").map

local M = {}

---@param km Pickers.Keymaps
function M.register(km)
  map(km.dir_pick, function()
    require("pickers.command").handle({ fargs = { "dir" } })
  end, "[pickers] Dir: navigate (alias / depth / path)")

  map(km.folder_files, function()
    require("pickers.command").handle({ fargs = { "folder", "files" } })
  end, "[pickers] Find files in interactively picked folder")

  map(km.config_files, function()
    require("pickers.command").handle({ fargs = { "config", "files" } })
  end, "[pickers] Find files in nvim config")

  map(km.config_grep, function()
    require("pickers.command").handle({ fargs = { "config", "grep" } })
  end, "[pickers] Grep in nvim config")

  map(km.cwd_grep, function()
    require("pickers.command").handle({ fargs = { "cwd", "grep" } })
  end, "[pickers] Live grep in CWD")

  map(km.cwd_files, function()
    require("pickers.command").handle({ fargs = { "cwd", "files" } })
  end, "[pickers] Find files in CWD")

  map(km.repos_files, function()
    require("pickers.command").handle({ fargs = { "repos", "files" } })
  end, "[pickers] Pick a repo, then find files")

  map(km.repos_grep, function()
    require("pickers.command").handle({ fargs = { "repos", "grep" } })
  end, "[pickers] Pick a repo, then live grep")

  map(km.system_files, function()
    require("pickers.command").handle({ fargs = { "system", "files" } })
  end, "[pickers] Systemwide fd search (prompts for query)")
end

return M
