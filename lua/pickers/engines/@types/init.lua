---@module 'pickers.engines.types'
---@brief Engine-related type definitions (adapter interface + call options).

-- ###########################################################################
-- Engine identifier

---@alias Pickers.Engine
---| '"auto"'       # Detect: telescope → fzf → snacks
---| '"telescope"'
---| '"fzf"'
---| '"snacks"'

-- ###########################################################################
-- Engine call-options (passed from action → engine)

---@class Pickers.EngineOpts
---@field roots           string[]
---@field prompt          string
---@field query           string|nil
---@field find_command    string[]|nil
---@field additional_args string[]|nil
---@field find            Pickers.FindOpts|nil   File-listing flags (ignored when find_command is set)

return {}
