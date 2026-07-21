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

  -- Unified in-picker keys namespace. Bundles keybinding-shaped features that
  -- act *inside* an open picker (as opposed to `keymaps`, which launches a
  -- scope in the first place).
  keys = {
    -- In-picker "create file/folder" and "open in background" entry actions,
    -- shared across telescope/fzf-lua/snacks.nvim. See pickers.entry_actions.
    --   fzf-lua's ctrl-a/ctrl-o/shift-enter bindings are fixed (fzf's own bind
    --   syntax, not remappable via `keys` — see entry_actions.adapters.fzf).
    entry_actions = {
      enable = true,
      keys = {
        create_file = "<C-a>",
        open_background = { "<S-CR>", "<C-o>" },
      },
    },

    -- Telescope-only opt-in preview-toggle keymap. fzf-lua ships this
    -- natively on <F4>, snacks on <A-p> -- neither needs pickers.nvim to
    -- provide it. See pickers.preview_toggle.
    preview_toggle = {
      key = nil,
    },
  },
}

return M
