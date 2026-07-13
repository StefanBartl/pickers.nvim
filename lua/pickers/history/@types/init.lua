---@module 'pickers.history.types'
---@brief Type definitions for the native picker-history feature.

---@alias Pickers.History.FzfScope "plugin" | "global" | "patch"

---@class Pickers.HistoryConfig
---@field enabled   boolean               Toggle for the whole feature (default: false)
---@field fzf_scope Pickers.History.FzfScope  fzf-lua only; telescope has no scope knob (default: "plugin")
---@field dir       string|nil            Override history dir (default: stdpath("data")/pickers.nvim/history)
---@field limit     integer               Max entries kept per history file (default: 200)

return {}
