---@module 'pickers.entry_actions.adapters.snacks'
---@brief snacks.nvim entry-action registrations: create_file + open_background + cheatsheet.
---@description
--- Two-part registration, matching Snacks.picker's own convention: named
--- actions via `get_actions()` (merged into `opts.actions`), plus separate
--- key -> action-name bindings via `get_keys()` (merged into `win.list.keys`)
--- and `get_input_keys()` (merged into `win.input.keys`).
---
--- Both windows are required, not just the list: a snacks picker opens with
--- focus in the INPUT window (insert mode), so a list-only binding is
--- unreachable while typing a query -- the key falls through to whatever the
--- input window has bound, i.e. plain `confirm`. Snacks' own defaults bind
--- `<CR>` in both windows for exactly this reason (`snacks.picker.config
--- .defaults`: input `{ "confirm", mode = { "n", "i" } }` + list `"confirm"`),
--- so entry actions must mirror that.
---
--- The two getters differ in binding FORM, not just target: snacks' list
--- window is normal-mode only and takes the bare-string form, while the input
--- window needs the mode-qualified table form -- same split as
--- `pickers.keys.adapters.snacks`.

local notify = require("lib.nvim.notify").create("[pickers.entry_actions.adapters.snacks]")
local extract = require("pickers.entry_actions.extract.snacks")
local create_file = require("pickers.entry_actions.create_file")
local open_background = require("pickers.entry_actions.open_background")

local M = {}

---@internal
---Open the keymap cheatsheet. Does NOT close the picker -- a snacks picker
---is a plain Neovim float same as the cheatsheet panel, so it opens on top
---and hands focus back on close (same reasoning as open_background).
local function do_cheatsheet()
  require("pickers.cheatsheet").show()
end

---@internal
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

---@internal
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

---Named actions table for `Snacks.picker` `opts.actions`, `desc` included.
---Snacks' own `?` → `toggle_help_input`/`toggle_help_list` (native, bound by
---default -- see `Snacks.win:toggle_help()`) reads real buffer keymaps and
---shows each one's `desc`; a plain function here would still work but the
---panel would fall back to the raw action name with underscores turned to
---spaces ("create file") instead of `pickers.cheatsheet.DESCRIPTIONS`' fuller
---text ("Create file/folder") -- reused here, not retyped, so the two panels
---(this native one and `pickers.cheatsheet`'s own) never drift apart.
---@return table<string, { action: function, desc: string }> actions
function M.get_actions()
  if require("pickers.config").get().keys.enable == false then return {} end

  local desc = require("pickers.cheatsheet").DESCRIPTIONS

  return {
    create_file = { action = do_create_file, desc = desc.create_file },
    open_background = { action = do_open_background, desc = desc.open_background },
    cheatsheet = { action = do_cheatsheet, desc = desc.cheatsheet },
  }
end

---Key -> action-name bindings for `win.list.keys` (bare-string form; the
---snacks list window is normal-mode only), honouring `pickers.keys`' resolved
---`create_file`/`open_background`/`cheatsheet` config.
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

  for _, key in ipairs((resolved.cheatsheet or {}).lhs or {}) do
    keys[key] = "cheatsheet"
  end

  return keys
end

---Key -> action-name bindings for `win.input.keys`, in snacks'
---mode-qualified form so the actions are reachable while the prompt has focus
---(which is where every picker starts). Modes come from `pickers.keys.ACTIONS`.
---@return table<string, { [1]: string, mode: string[] }> keys
function M.get_input_keys()
  local resolved = require("pickers.keys").resolve()
  local keys = {}

  for _, action in ipairs({ "create_file", "open_background", "cheatsheet" }) do
    local spec = resolved[action]
    if spec then
      for _, key in ipairs(spec.lhs or {}) do
        keys[key] = { action, mode = spec.modes }
      end
    end
  end

  return keys
end

return M
