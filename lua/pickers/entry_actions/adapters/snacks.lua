---@module 'pickers.entry_actions.adapters.snacks'
---@brief snacks.nvim entry-action registrations: create_file + open_background.
---@description
--- Two-part registration, matching Snacks.picker's own convention: named
--- actions via `get_actions()` (merged into `opts.actions`), plus a separate
--- key -> action-name binding via `get_keys()` (merged into `win.list.keys`).

local notify = require("lib.nvim.notify").create("[pickers.entry_actions.adapters.snacks]")
local extract = require("pickers.entry_actions.extract.snacks")
local create_file = require("pickers.entry_actions.create_file")
local open_background = require("pickers.entry_actions.open_background")

local M = {}

---@param picker any
---@param item any
local function do_create_file(picker, item)
  local path = extract(item)
  if not path then
    notify.warn("No valid path found")
    return
  end
  ---@diagnostic disable-next-line: undefined-field
  picker:close()
  create_file.run(path)
end

---@param _picker any
---@param item any
---@diagnostic disable-next-line: unused-local
local function do_open_background(_picker, item)
  local path = extract(item)
  if not path then
    notify.warn("No valid path found")
    return
  end
  open_background.run(path)
  -- Do NOT close picker - that's the point of background open
end

---Named actions table for `Snacks.picker` `opts.actions`.
---@return table<string, function> actions
function M.get_actions()
  if not require("pickers.config").get().keys.entry_actions.enable then
    return {}
  end

  return {
    create_file = do_create_file,
    open_background = do_open_background,
  }
end

---Key -> action-name bindings for `win.list.keys`, honouring configured keys.
---@return table<string, string> keys
function M.get_keys()
  local cfg = require("pickers.config").get().keys.entry_actions
  if not cfg.enable then
    return {}
  end

  local keys = {}

  if cfg.keys.create_file then
    keys[cfg.keys.create_file] = "create_file"
  end

  local bg_keys = type(cfg.keys.open_background) == "table" and cfg.keys.open_background
    or { cfg.keys.open_background }
  for _, key in ipairs(bg_keys) do
    if key then
      keys[key] = "open_background"
    end
  end

  return keys
end

return M
