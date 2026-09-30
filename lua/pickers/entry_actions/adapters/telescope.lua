---@module 'pickers.entry_actions.adapters.telescope'
---@brief Telescope entry-action mappings: create_file + open_background +
---cheatsheet + path_copy (copy_absolute/copy_dirname/copy_env_rooted/
---copy_project_root/copy_project_relative/copy_buffer_relative/markdown_link)
---+ system (open_system/reveal_in_manager).
---@description
--- Single canonical source for these mappings — collapses the pre-existing
--- duplicate config.telescope.actions.open_badd / config.telescope.open_background
--- pair from the nvim config (both bound <S-CR>/<C-o> to the same effect and
--- silently collided via merge order).
---
--- Each lhs is bound in the modes `pickers.keys.modes_for` allows: direct
--- Ctrl/Alt keys in insert AND normal mode (the prompt is always in insert
--- mode), filetree-style chords (`[a`, `ML`, `<leader>sm`) in normal mode only.

local notify = require("lib.nvim.notify").create("[pickers.entry_actions.adapters.telescope]")
local extract = require("pickers.entry_actions.extract.telescope")
local create_file = require("pickers.entry_actions.create_file")
local open_background = require("pickers.entry_actions.open_background")
local path_copy = require("pickers.entry_actions.path_copy")
local link_insert = require("pickers.entry_actions.link_insert")
local system = require("pickers.entry_actions.system")

local M = {}

---@internal
---Open the keymap cheatsheet. Unlike create_file/open_background, this does
---NOT close the picker -- telescope's floating window and the cheatsheet's
---are both plain Neovim floats, so the panel simply opens on top and hands
---focus back on close.
local function do_cheatsheet()
  require("pickers.cheatsheet").show()
end

---@internal
---@param prompt_bufnr integer
local function do_create_file(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local path = extract(action_state.get_selected_entry())
  if not path then
    notify.warn("No valid path found")
    return
  end
  require("telescope.actions").close(prompt_bufnr)
  create_file.run(path)
end

---@internal
---The paths a copy action works on: every multi-selected (Tab) entry when
---there are any, else the current one -- filetree.nvim's "marks if any, else
---the node under the cursor" idiom -- and the window behind the picker (the
---base of `buffer_relative`).
---@param prompt_bufnr integer
---@return string[] paths
---@return integer|nil win
local function selected_paths(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local picker = action_state.get_current_picker(prompt_bufnr)
  local entries = picker and picker:get_multi_selection() or {}
  if #entries == 0 then entries = { action_state.get_selected_entry() } end

  local paths = {}
  for _, entry in ipairs(entries) do
    local path = extract(entry)
    if path then paths[#paths + 1] = path end
  end
  return paths, picker and picker.original_win_id or nil
end

---@internal
---Path-copy entry action (see pickers.entry_actions.path_copy): copy the
---selected entries' paths in `fmt`, without closing or otherwise disturbing
---the picker -- same non-disruptive "stay in place" behavior as
---filetree.nvim's own path_copy/markdown_links features.
---@param fmt string
---@return fun(prompt_bufnr: integer)
local function do_copy(fmt)
  return function(prompt_bufnr)
    local paths, win = selected_paths(prompt_bufnr)
    path_copy.run(fmt, paths, { win = win })
  end
end

---@internal
---Insert the selected entries as Markdown links into the window behind the
---picker (see pickers.entry_actions.link_insert). CLOSES the picker first --
---the text goes into the window behind it and insert mode must end up there.
---@param prompt_bufnr integer
local function do_link_insert(prompt_bufnr)
  local paths, win = selected_paths(prompt_bufnr)
  require("telescope.actions").close(prompt_bufnr)
  vim.schedule(function()
    link_insert.run(paths, { win = win })
  end)
end

---@internal
---System entry action (see pickers.entry_actions.system) on the CURRENT entry
---only; the picker stays open.
---@param action "open"|"reveal"
---@return fun()
local function do_system(action)
  return function()
    local action_state = require("telescope.actions.state")
    system.run(action, extract(action_state.get_selected_entry()))
  end
end

---@internal
---Entry-action: open the selected entry in the background window (see
---pickers.entry_actions.open_background), preserving cursor position when the
---entry carries a line/col.
---@param prompt_bufnr integer
local function do_open_background(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local entry = action_state.get_selected_entry()
  local path = extract(entry)
  if not path then
    notify.warn("No valid path found")
    return
  end
  local picker = action_state.get_current_picker(prompt_bufnr)
  local pos = entry and entry.lnum and { entry.lnum, math.max((entry.col or 1) - 1, 0) } or nil
  open_background.run(path, { win = picker and picker.original_win_id, pos = pos })
end

---Build the {i={...}, n={...}} mapping table for telescope.setup()'s
---defaults.mappings, honouring `keys.enable` and every entry-action lhs (via
---`pickers.keys.resolve()`, the single source of truth for in-picker keys).
---@return table mappings
function M.get_mappings()
  local keys = require("pickers.keys")
  local resolved = keys.resolve()
  local mappings = { i = {}, n = {} }

  ---@param action string
  ---@param handler function
  local function bind(action, handler)
    local spec = resolved[action]
    if not spec then return end
    for _, lhs in ipairs(spec.lhs) do
      for _, mode in ipairs(keys.modes_for(spec, lhs)) do
        if mappings[mode] then mappings[mode][lhs] = handler end
      end
    end
  end

  bind("create_file", do_create_file)
  bind("open_background", do_open_background)
  bind("cheatsheet", do_cheatsheet)
  bind(link_insert.ACTION, do_link_insert)

  for _, fmt in ipairs(path_copy.FORMAT_ORDER) do
    bind(path_copy.ACTION_FOR[fmt], do_copy(fmt))
  end
  for action, key_action in pairs(system.ACTION_FOR) do
    bind(key_action, do_system(action))
  end

  return mappings
end

return M
