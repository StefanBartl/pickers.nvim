---@module 'pickers.entry_actions.adapters.fzf'
---@brief fzf-lua entry-action registrations: create_file + open_background.
---@description
--- fzf-lua action-table keys are fzf's own bind syntax ("ctrl-a", not
--- Neovim's "<C-a>"), so unlike the telescope/snacks adapters this one does
--- not read `entry_actions.keys` — there is no general, safe way to
--- translate Neovim keymap syntax to fzf bind syntax. Only
--- `entry_actions.enable` is honoured; the ctrl-a/ctrl-o/shift-enter
--- bindings themselves are fixed (matching the previous nvim-config
--- behavior exactly).

local notify = require("lib.nvim.notify").create("[pickers.entry_actions.adapters.fzf]")
local extract = require("pickers.entry_actions.extract.fzf")
local create_file = require("pickers.entry_actions.create_file")
local open_background = require("pickers.entry_actions.open_background")

local M = {}

---@param selected table|string
local function do_open_background(selected)
  local path = extract(selected)
  if not path then
    notify.warn("No valid path found")
    return
  end
  open_background.run(path)
  vim.defer_fn(function()
    require("fzf-lua").resume()
  end, 50)
end

---@param selected table|string
local function do_create_file(selected)
  local path = extract(selected)
  if not path then
    notify.warn("No valid path found")
    return
  end
  -- fzf-lua's picker runs in a terminal buffer; give it time to close
  -- before showing vim.ui.input (create_file.run schedules on top of this).
  vim.defer_fn(function()
    create_file.run(path)
  end, 150)
end

---Build the fzf-lua `actions` table fragment for create_file/open_background.
---@return table<string, function> actions
function M.get_actions()
  if not require("pickers.config").get().entry_actions.enable then
    return {}
  end

  return {
    ["ctrl-a"] = do_create_file,
    ["ctrl-o"] = do_open_background,
    ["shift-enter"] = do_open_background,
  }
end

return M
