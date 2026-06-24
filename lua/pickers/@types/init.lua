---@module 'pickers.types'
---@brief Type definitions for pickers.nvim.
---@description
--- All @alias, @class and @field annotations are centralised here so that
--- source files stay free of annotation noise.  Every subdir under pickers/
--- requires this file once to pull types into the LuaLS workspace.

-- ###########################################################################
-- Primitive aliases

---@alias Pickers.Engine
---| '"auto"'       # Detect: telescope → fzf → vim.ui.select
---| '"telescope"'
---| '"fzf"'

---@alias Pickers.Scope
---| '"cwd"'        # Current working directory
---| '"config"'     # Neovim config directory (stdpath "config")
---| '"folder"'     # Interactively picked folder via engine dir-picker
---| '"repos"'      # One repo selected from REPOS_DIR
---| '"wkdbooks"'   # One wkdbook selected from wkdbooks_dir
---| '"system"'     # Systemwide fd search (interactive query)
---| '"drives"'     # All mount points / drive letters
---| '"dir"'        # Depth / alias / explicit-path navigation

---@alias Pickers.Action
---| '"files"'
---| '"grep"'

-- ###########################################################################
-- Source (result of a source module's get())

---@class Pickers.Source
---@field roots          string[]      Absolute search-root directories
---@field prompt         string        Prompt prefix shown in the picker
---@field find_command   string[]|nil  Custom fd/find command (system scope)
---@field additional_args string[]|nil Extra rg/fzf-lua args (drives scope)

-- ###########################################################################
-- Engine call-options (passed from action → engine)

---@class Pickers.EngineOpts
---@field roots           string[]
---@field prompt          string
---@field query           string|nil
---@field find_command    string[]|nil
---@field additional_args string[]|nil

-- ###########################################################################
-- Configuration

---@class Pickers.Keymaps
---@field enable       boolean
---@field cwd_files    string|nil   Find files in cwd (default: nil)
---@field cwd_grep     string|nil   Live grep in cwd   (default: "<leader>li")
---@field config_files string|nil   Find files in nvim config (default: "<leader>fc")
---@field config_grep  string|nil   Grep in nvim config       (default: "<leader>gc")
---@field folder_files string|nil   Find files in picked folder (default: "<leader>fb")
---@field dir_pick     string|nil   Dir navigation picker (default: "<leader>dp")

---@class Pickers.Usercmds
---@field enable boolean

---@class Pickers.Collection
---@field name     string                               Unique scope name (e.g. "notes")
---@field dir      string                               Root directory
---@field prefix   string|nil                           nil=direct root, ""=all subdirs, "xyz-"=filtered
---@field keys     { files?: string, grep?: string }|nil  Optional keymaps
---@field only_git boolean|nil                          Only show subdirs that contain .git

---@class Pickers.Config
---@field engine         Pickers.Engine
---@field repos_dir      string|nil
---@field collections    Pickers.Collection[]
---@field depth_aliases  table<string, fun():string>
---@field keymaps        Pickers.Keymaps
---@field usercmds       Pickers.Usercmds

return {}
