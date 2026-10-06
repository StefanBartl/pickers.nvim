---@module 'pickers.command.types'
---@brief Command-layer type definitions (actions dispatched by :Pickers).

-- ###########################################################################
-- Action identifier

---@alias Pickers.Action
---| '"files"'
---| '"grep"'
---| '"smart"'   # Combined grep + find-files, merged and ranked (pickers.smart)
---| '"filegrep"' # Files filtered by path AND (via `grep=<pattern>` in the prompt) by content (pickers.filegrep)

return {}
