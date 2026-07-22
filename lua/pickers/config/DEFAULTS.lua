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
  },

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
    -- Opt-in, false (unbound) by default -- fzf-lua ships this natively on
    -- <F4>, snacks on <A-p>; only telescope has no default key for its
    -- existing toggle_preview action.
    preview_toggle = false,
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

  -- Overlay showing the index of the currently selected entry in the results
  -- buffer. Telescope-only, disabled by default. See pickers.selected_index.
  selected_index = {
    enabled = false,
    position = "right_align",
    highlight = {
      preset = "default",
    },
    -- In-picker keymap (insert + normal mode) that toggles the overlay live
    -- for the currently open results list. nil (default) registers no
    -- keymap at all, keeping enabled=false fully inert.
    toggle_key = nil,
  },

  -- Live result count shown in the prompt title (e.g. "Find Files (128)").
  -- Telescope-only, disabled by default -- fzf-lua and snacks.nvim both
  -- already show a position/total counter natively. See pickers.result_count.
  result_count = {
    enabled = false,
  },
}

return M
