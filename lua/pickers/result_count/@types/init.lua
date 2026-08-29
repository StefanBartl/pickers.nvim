---@module 'pickers.result_count.types'
---@brief Type definitions for the live result-count title feature.

---@class Pickers.ResultCountConfig
---@field enabled? boolean  Toggle for the whole feature (default: false)
---@field interval_ms? integer  How often the count is re-read while a picker is open, in ms (default: 150). A poll, because telescope has no hook that fires when the match count changes.

return {}
