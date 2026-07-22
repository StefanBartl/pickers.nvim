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

---@param picker any
---@param item any
local function do_open_background(picker, item)
  local path = extract(item)
  if not path then
    notify.warn("No valid path found")
    return
  end
  ---@diagnostic disable-next-line: undefined-field
  local pos = item and item.pos
  ---@diagnostic disable-next-line: undefined-field
  open_background.run(path, { win = picker and picker.main, pos = pos })
  -- Do NOT close picker - that's the point of background open
end

---Named actions table for `Snacks.picker` `opts.actions`.
---@return table<string, function> actions
function M.get_actions()
  if require("pickers.config").get().keys.enable == false then
    return {}
  end

  return {
    create_file = do_create_file,
    open_background = do_open_background,
  }
end

---Key -> action-name bindings for `win.list.keys`, honouring `pickers.keys`'
---resolved `create_file`/`open_background` config.
---@return table<string, string> keys
function M.get_keys()
  local resolved = require("pickers.keys").resolve()
  local keys = {}

  for _, key in ipairs((resolved.create_file or {}).lhs or {}) do
    keys[key] = "create_file"
  end

  for _, key in ipairs((resolved.open_background or {}).lhs or {}) do
    keys[key] = "open_background"
  end

  return keys
end

return M
