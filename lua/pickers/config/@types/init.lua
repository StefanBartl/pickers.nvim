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
-- Declarative mappings (flat name -> {lhs, engine?})

--- One flat surface listing every picker action by name (any scope×action
--- combo, or any `pickers.builtins` name), each with an lhs and an optional
--- per-entry engine override. See `pickers.mappings` for name resolution
--- rules. Does not supersede `Pickers.Keymaps` -- a second, more flexible
--- surface, not a replacement.
---@alias Pickers.MappingSpec { [1]: string, [2]: Pickers.Engine|nil }
---@alias Pickers.MappingsConfig table<string, Pickers.MappingSpec>

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
-- Top-level configuration

---@class Pickers.Config
---@field engine         Pickers.Engine
---@field repos_dir      string|nil
---@field deps_popup?    boolean  # lib.nvim.deps "declared tools" popup once, ever, on first setup() after install (default true; needs lib.nvim.deps — a no-op without it)
---@field collections    Pickers.Collection[]
---@field depth_aliases  table<string, fun():string>
---@field find           Pickers.FindOpts
---@field keymaps        Pickers.Keymaps
---@field mappings       Pickers.MappingsConfig
---@field usercmds       Pickers.Usercmds
---@field keys           Pickers.KeysConfig
---@field history        Pickers.HistoryConfig
---@field result_count   Pickers.ResultCountConfig
---@field smart          Pickers.SmartConfig
---@field display        Pickers.DisplayConfig

return {}
