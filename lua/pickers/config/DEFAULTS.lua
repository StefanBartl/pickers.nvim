---@module 'pickers.config.DEFAULTS'
---@brief Default configuration values.
---@see pickers.types

---@type Pickers.Config
local M = {
  engine = "auto",
  repos_dir = vim.env.REPOS_DIR or nil,
  collections = {},

  depth_aliases = {
    cwd = function()
      return vim.uv.cwd() or vim.fn.getcwd()
    end,
    home = function()
      return vim.uv.os_homedir() or vim.fn.expand("~")
    end,
    root = function()
      local path = vim.uv.cwd() or vim.fn.getcwd()
      while true do
        local parent = vim.fs.dirname(path)
        if parent == path then return path end
        path = parent
      end
    end,
    git = function()
      local found = vim.fs.find(".git", {
        upward = true,
        type = "directory",
        path = vim.uv.cwd() or vim.fn.getcwd(),
      })
      if found and found[1] then return vim.fs.dirname(found[1]) end
      return vim.uv.cwd() or vim.fn.getcwd()
    end,
  },

  keymaps = {
    enable = true,
    cwd_files = nil,
    cwd_grep = "<leader>li",
    config_files = "<leader>fc",
    config_grep = "<leader>gc",
    folder_files = "<leader>fb",
    dir_pick = "<leader>dp",
    -- File explorer / browser on the active engine (snacks' tree explorer,
    -- telescope-file-browser, ...). See pickers.builtins "explorer".
    explorer = "<leader>.",
    -- Opt-in, nil (disabled) by default -- same as cwd_files.
    repos_files = nil,
    repos_grep = nil,
    system_files = nil,
    -- Smart action (combined grep + find files). Opt-in, nil by default -- the
    -- key is unopinionated like cwd_files; pick one in your own setup().
    cwd_smart = nil,
    config_smart = nil,
    folder_smart = nil,
    -- "Find all" escape hatch: forces hidden+no_ignore+follow for this one
    -- search only, regardless of configured find.* defaults. Opt-in, nil by
    -- default -- same as cwd_files. Equivalent to `:Pickers cwd files all`.
    cwd_find_all = nil,
  },

  -- Declarative mappings: one flat surface listing every picker action by
  -- name (<scope>_<files|grep|smart|find_all>, or any pickers.builtins
  -- name), each with an lhs and an optional per-entry engine override.
  -- Empty by default -- a second, more flexible surface alongside the fixed
  -- `keymaps` fields above, not a replacement for them. See pickers.mappings.
  mappings = {},

  -- File-listing behaviour for the built-in file pickers (config/cwd/folder/
  -- repos/collections). Ignored for the `system` scope, which builds its own fd
  -- command. no_ignore stays false so per-repo .gitignore rules keep working
  -- (e.g. generated data dirs); flip it to true to also list ignored files.
  find = {
    hidden = true,
    no_ignore = false,
    follow = true,
    exclude = nil,
  },

  usercmds = {
    enable = true,
  },

  -- Unified in-picker keys namespace: preview scroll + native history
  -- navigation (patched globally into telescope/fzf-lua/snacks) plus the
  -- create_file/open_background entry actions (merged manually into your own
  -- engine setup() -- see pickers.entry_actions). See pickers.keys.
  --   Each action takes a single lhs, a list of lhs, or `false` to unbind it.
  --   fzf-lua only binds the vertical preview scroll and the fixed ctrl-a/
  --   ctrl-o/shift-enter entry actions (horizontal scroll, history, and
  --   remapping the entry-action keys are all fzf-native/fixed) — a
  --   documented capability gap.
  keys = {
    enable = true,
    preview_scroll_down = "<PageDown>",
    preview_scroll_up = "<PageUp>",
    preview_scroll_left = "<C-Left>",
    preview_scroll_right = "<C-Right>",
    history_back = "<C-p>",
    history_forward = "<C-n>",
    create_file = "<C-a>",
    open_background = { "<S-CR>", "<C-o>" },
    -- Opt-in, false by default: open_background only preloads the buffer
    -- (bufadd+bufload, matching the old per-engine behaviour exactly). Flip
    -- to true to also display -- not focus -- the selected entry in the
    -- window behind the picker, so it's already showing there once you
    -- close or switch away from the picker. Focus always stays in the
    -- picker; see pickers.entry_actions.open_background.
    open_background_show = false,
    -- Opt-in, false (unbound) by default -- fzf-lua ships this natively on
    -- <F4>, snacks on <A-p>; only telescope has no default key for its
    -- existing toggle_preview action.
    preview_toggle = false,
    -- Open the selected entry in a split/vsplit/new tab. All three engines
    -- already ship the primitive natively; unified here for a consistent
    -- lhs across engines (fzf-lua's ctrl-s/ctrl-v/ctrl-t are fixed/native
    -- and not remapped, same class as its history keys).
    split = "<C-s>",
    vsplit = "<C-v>",
    tab = "<C-t>",
  },

  -- Native picker-history file(s) under stdpath("data")/pickers.nvim/history.
  -- Disabled by default. See pickers.history.
  --   fzf_scope only affects fzf-lua (telescope's history is a process-wide
  --   singleton with no per-call scoping — see pickers.history for details):
  --     "plugin" - per-provider files (files/grep/item), pickers.nvim's own
  --                calls only, no external setup() call.
  --     "global" - pickers.nvim exports history.fzf_opts()/telescope_opts()
  --                for you to merge into your own setup() calls yourself.
  --     "patch"  - pickers.nvim calls fzf-lua's/telescope's setup() itself so
  --                your own (and any other) fzf-lua/telescope usage inherits it.
  history = {
    enabled = false,
    fzf_scope = "plugin",
    dir = nil,
    limit = 200,
  },

  -- Not-yet-stable features, namespaced separately so their config surface
  -- can keep changing shape without touching the stable top-level options.
  experimental = {
    -- Overlay showing the index of the currently selected entry in the
    -- results buffer. Telescope-only, disabled by default. See
    -- pickers.selected_index.
    selected_index = {
      enabled = false,
      position = "right_align",
      highlight = {
        preset = "default",
      },
      -- In-picker keymap (insert + normal mode) that toggles the overlay
      -- live for the currently open results list. nil (default) registers
      -- no keymap at all, keeping enabled=false fully inert.
      toggle_key = nil,
    },
  },

  -- Live result count shown in the prompt title (e.g. "Find Files (128)").
  -- Telescope-only, disabled by default -- fzf-lua and snacks.nvim both
  -- already show a position/total counter natively. See pickers.result_count.
  result_count = {
    enabled = false,
  },

  -- Smart action: runs rg (content) and fd (filenames) for the same live query
  -- and merges both into ONE list ranked by a shared scorer, so hits interleave
  -- by relevance regardless of source. See pickers.smart.
  --   weights.filename - multiplier for the filename-match component
  --   weights.content  - multiplier for the grep content-match component
  --   weights.both     - flat bonus for a file that ALSO has grep hits
  --   limit            - max merged results kept after ranking
  --   timeout          - per-command (rg/fd) wait timeout in ms
  --   frecency         - opt-in recency/frequency ranking boost, off by default
  --   dedup_grep_rows  - collapse multiple grep hits per file to the best
  --                      line, off by default
  smart = {
    weights = {
      filename = 1.0,
      content = 1.0,
      both = 25,
    },
    limit = 2000,
    timeout = 3000,
    frecency = {
      enabled = false,
      weight = 1.0,
      dir = nil, -- default: stdpath("data") .. "/pickers.nvim"
    },
    dedup_grep_rows = false,
  },

  -- Long-path display shortening. Cosmetic only, off by default -- pure
  -- pass-through to each engine's own native mechanism (telescope
  -- path_display={"shorten"}, fzf-lua path_shorten=true). snacks already
  -- truncates to fit the available column width by default, no toggle needed.
  display = {
    path_shorten = false,
  },
}

return M
