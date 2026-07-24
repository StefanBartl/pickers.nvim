---@module 'pickers.command.types'
---@brief Command-layer type definitions (actions dispatched by :Pickers).

-- ###########################################################################
-- Action identifier

---@alias Pickers.Action
---| '"files"'
---| '"grep"'
---| '"smart"'   # Combined grep + find-files, merged and ranked (pickers.smart)

return {}
