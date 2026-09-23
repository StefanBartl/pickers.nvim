---@module 'pickers.entry_actions.adapters.telescope'
---@brief Telescope entry-action mappings: create_file + open_background +
---cheatsheet + path_copy (copy_absolute/copy_dirname/copy_env_rooted/
---markdown_link).
---@description
--- Single canonical source for these mappings — collapses the pre-existing
--- duplicate config.telescope.actions.open_badd / config.telescope.open_background
--- pair from the nvim config (both bound <S-CR>/<C-o> to the same effect and
--- silently collided via merge order).

local notify = require("lib.nvim.notify").create("[pickers.entry_actions.adapters.telescope]")
local extract = require("pickers.entry_actions.extract.telescope")
local create_file = require("pickers.entry_actions.create_file")
local open_background = require("pickers.entry_actions.open_background")
local path_copy = require("pickers.entry_actions.path_copy")

---@internal
---path_copy format name -> pickers.keys action name.
local FMT_TO_ACTION = {
  absolute = "copy_absolute",
  dirname = "copy_dirname",
  env_rooted = "copy_env_rooted",
  markdown_link = "markdown_link",
}

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
---Path-copy entry action (see pickers.entry_actions.path_copy): copy the
---selected entry's path in `fmt`, without closing or otherwise disturbing
---the picker -- same non-disruptive "stay in place" behavior as
---filetree.nvim's own path_copy/markdown_links features.
---@param fmt string
---@return fun(prompt_bufnr: integer)
local function do_copy(fmt)
  return function()
    local action_state = require("telescope.actions.state")
    local path = extract(action_state.get_selected_entry())
    path_copy.run(fmt, path)
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
---defaults.mappings, honouring `keys.enable`/`keys.create_file`/
---`keys.open_background`/`keys.cheatsheet` (via `pickers.keys.resolve()`, the
---single source of truth for in-picker keys).
---@return table mappings
function M.get_mappings()
  local resolved = require("pickers.keys").resolve()
  local mappings = { i = {}, n = {} }

  for _, key in ipairs((resolved.create_file or {}).lhs or {}) do
    mappings.i[key] = do_create_file
    mappings.n[key] = do_create_file
  end

  for _, key in ipairs((resolved.open_background or {}).lhs or {}) do
    mappings.i[key] = do_open_background
    mappings.n[key] = do_open_background
  end

  for _, key in ipairs((resolved.cheatsheet or {}).lhs or {}) do
    mappings.i[key] = do_cheatsheet
    mappings.n[key] = do_cheatsheet
  end

  -- Path-copy entry actions: results-window/normal-mode ONLY (`n`, never
  -- `i`) -- their default lhs are plain printable characters (`[`, `]`,
  -- `a`, `e`, `M`, `L`), not control/special keys, so binding them in the
  -- prompt's insert mode would swallow those characters out of any typed
  -- query containing them. See pickers.keys' @description.
  for _, fmt in ipairs(path_copy.FORMAT_ORDER) do
    local action = FMT_TO_ACTION[fmt]
    for _, key in ipairs((resolved[action] or {}).lhs or {}) do
      mappings.n[key] = do_copy(fmt)
    end
  end

  return mappings
end

return M
