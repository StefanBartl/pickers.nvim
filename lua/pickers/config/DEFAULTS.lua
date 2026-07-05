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

  -- Overlay showing the index of the currently selected entry in the results
  -- buffer. Telescope-only, disabled by default. See pickers.selected_index.
  selected_index = {
    enabled = false,
    position = "right_align",
    highlight = {
      preset = "default",
    },
  },
}

return M
