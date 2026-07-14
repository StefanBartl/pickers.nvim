---@module 'pickers.entry_actions.adapters.telescope'
---@brief Telescope entry-action mappings: create_file + open_background.
---@description
--- Single canonical source for these mappings — collapses the pre-existing
--- duplicate config.telescope.actions.open_badd / config.telescope.open_background
--- pair from the nvim config (both bound <S-CR>/<C-o> to the same effect and
--- silently collided via merge order).

local notify = require("lib.nvim.notify").create("[pickers.entry_actions.adapters.telescope]")
local extract = require("pickers.entry_actions.extract.telescope")
local create_file = require("pickers.entry_actions.create_file")
local open_background = require("pickers.entry_actions.open_background")

local M = {}

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

---@diagnostic disable-next-line: unused-local
local function do_open_background(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local path = extract(action_state.get_selected_entry())
  if not path then
    notify.warn("No valid path found")
    return
  end
  open_background.run(path)
end

---Build the {i={...}, n={...}} mapping table for telescope.setup()'s
---defaults.mappings, honouring `entry_actions.enable`/`entry_actions.keys`.
---@return table mappings
function M.get_mappings()
  local cfg = require("pickers.config").get().entry_actions
  if not cfg.enable then
    return { i = {}, n = {} }
  end

  local mappings = { i = {}, n = {} }

  if cfg.keys.create_file then
    mappings.i[cfg.keys.create_file] = do_create_file
    mappings.n[cfg.keys.create_file] = do_create_file
  end

  local bg_keys = type(cfg.keys.open_background) == "table" and cfg.keys.open_background
    or { cfg.keys.open_background }
  for _, key in ipairs(bg_keys) do
    if key then
      mappings.i[key] = do_open_background
      mappings.n[key] = do_open_background
    end
  end

  return mappings
end

return M
