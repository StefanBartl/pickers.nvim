---@module 'pickers.selected_index.actions'
---@brief Movement keymaps that keep the selected-index overlay in sync.
---@description
--- `map` is the picker-local mapping helper Telescope passes into
--- `attach_mappings`. `update_fn` is the zero-argument function that
--- refreshes the index overlay; it is scheduled after each move so it runs
--- once Telescope's own selection state has settled.

local M = {}

---@param map function
---@param key string
---@param mode string
---@param action_fn function
---@param update_fn fun():nil
local function wrap_move(map, key, mode, action_fn, update_fn)
  map(mode, key, function(prompt_bufnr)
    action_fn(prompt_bufnr)
    vim.schedule(update_fn)
    return true
  end)
end

---Attach the movement mappings that keep `update_fn` in sync.
---@param map function
---@param update_fn fun():nil
---@return nil
function M.attach(map, update_fn)
  local actions = require("telescope.actions")

  wrap_move(map, "<Down>", "i", actions.move_selection_next, update_fn)
  wrap_move(map, "<Up>", "i", actions.move_selection_previous, update_fn)
  wrap_move(map, "<C-n>", "i", actions.move_selection_next, update_fn)
  wrap_move(map, "<C-p>", "i", actions.move_selection_previous, update_fn)

  wrap_move(map, "j", "n", actions.move_selection_next, update_fn)
  wrap_move(map, "k", "n", actions.move_selection_previous, update_fn)
  wrap_move(map, "<Down>", "n", actions.move_selection_next, update_fn)
  wrap_move(map, "<Up>", "n", actions.move_selection_previous, update_fn)
end

return M
