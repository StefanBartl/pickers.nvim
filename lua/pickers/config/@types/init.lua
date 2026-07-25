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
---@field explorer     string|nil   File explorer/browser on the active engine (default: "<leader>.")
---@field repos_files  string|nil   Pick a repo, then find files (default: nil)
---@field repos_grep   string|nil   Pick a repo, then live grep  (default: nil)
---@field system_files string|nil   Systemwide fd search (prompts for query) (default: nil)
---@field cwd_smart    string|nil   Smart (grep + find) in cwd    (default: nil)
---@field config_smart string|nil   Smart (grep + find) in nvim config (default: nil)
---@field folder_smart string|nil   Smart (grep + find) in picked folder (default: nil)
---@field cwd_find_all string|nil   Find files in cwd, forcing hidden+no_ignore+follow for this search only (default: nil)

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
-- Display (cosmetic, optional)

--- Long-path display shortening. Cosmetic only, off by default, and purely a
--- pass-through to each engine's own native mechanism -- no pickers.nvim-side
--- logic: telescope gets `path_display = { "shorten" }`, fzf-lua gets
--- `path_shorten = true`. snacks is not listed here on purpose: it already
--- truncates the displayed path to fit the available column width by
--- default, so there is nothing to opt into there.
---@class Pickers.DisplayConfig
---@field path_shorten boolean  Default: false

-- ###########################################################################
-- Experimental (not-yet-stable) features

--- Namespaced separately from the stable top-level options so their config
--- surface can keep changing shape without a compat promise. See
--- docs/CONFIGURATION.md and ROADMAP.md's "Checklist audit" section.
---@class Pickers.ExperimentalConfig
---@field selected_index Pickers.SelectedIndexConfig

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
---@field result_count   Pickers.ResultCountConfig
---@field smart          Pickers.SmartConfig
---@field display        Pickers.DisplayConfig
---@field experimental   Pickers.ExperimentalConfig

return {}
