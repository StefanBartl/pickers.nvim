---@module 'pickers.config.types'
---@brief Configuration type definitions (setup options and defaults).

-- ###########################################################################
-- Keymaps

---@class Pickers.Keymaps
---@field enable       boolean
---@field cwd_files    string|nil   Find files in cwd (default: nil)
---@field cwd_grep     string|nil   Live grep in cwd   (default: "<leader>li")
---@field config_files string|nil   Find files in nvim config (default: "<leader>fc")
---@field config_grep  string|nil   Grep in nvim config       (default: "<leader>gc")
---@field folder_files string|nil   Find files in picked folder (default: "<leader>fb")
---@field dir_pick     string|nil   Dir navigation picker (default: "<leader>dp")

-- ###########################################################################
-- User-commands

---@class Pickers.Usercmds
---@field enable boolean

-- ###########################################################################
-- File-listing flags

---@class Pickers.FindOpts
---@field hidden    boolean       Show dotfiles / hidden entries (default: true)
---@field no_ignore boolean       Ignore .gitignore / .ignore rules (default: false)
---@field follow    boolean       Follow symlinks (default: true)
---@field exclude   string[]|nil  Extra glob patterns to exclude (default: nil)

-- ###########################################################################
-- Entry actions (in-picker create_file / open_background)

---@class Pickers.EntryActionsKeys
---@field create_file      string|nil          Default: "<C-a>"
---@field open_background  string|string[]|nil Default: { "<S-CR>", "<C-o>" }

---@class Pickers.EntryActionsConfig
---@field enable boolean
---@field keys   Pickers.EntryActionsKeys

-- ###########################################################################
-- Top-level configuration

---@class Pickers.Config
---@field engine         Pickers.Engine
---@field repos_dir      string|nil
---@field collections    Pickers.Collection[]
---@field depth_aliases  table<string, fun():string>
---@field find           Pickers.FindOpts
---@field keymaps        Pickers.Keymaps
---@field usercmds       Pickers.Usercmds
---@field keys           Pickers.KeysConfig
---@field history        Pickers.HistoryConfig
---@field selected_index Pickers.SelectedIndexConfig
---@field entry_actions  Pickers.EntryActionsConfig

return {}
