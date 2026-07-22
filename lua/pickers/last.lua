---@module 'pickers.last'
---@brief Remembers the most recently dispatched {action, source} pair so
---`:PickersRepeat` can reopen it without re-resolving through any
---interactive sub-picker (folder/repo/collection subdir) in between.
---@description
--- In-memory only, current session, not persisted to disk -- a different
--- concern from `pickers.history` (which persists actual search queries).
--- Recorded by `pickers.command`'s dispatch, the single choke point every
--- fully-resolved :Pickers action passes through regardless of scope.

local notify = require("lib.nvim.notify").create("[pickers]")

local M = {}

---@type { action: Pickers.Action, source: Pickers.Source }|nil
local _last = nil

---@param action Pickers.Action
---@param source Pickers.Source
function M.set(action, source)
  _last = { action = action, source = source }
end

---@return { action: Pickers.Action, source: Pickers.Source }|nil
function M.get()
  return _last
end

---Replay the last recorded dispatch on the currently resolved engine.
---Reports and returns early if nothing has been dispatched yet this session.
function M.run()
  if not _last then
    notify.warn("No previous :Pickers action to repeat yet")
    return
  end

  local engine_mod = require("pickers.engines").load()
  if not engine_mod then return end

  require("pickers.command").dispatch(_last.action, _last.source, engine_mod)
end

return M
