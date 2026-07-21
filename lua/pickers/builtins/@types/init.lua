---@module 'pickers.builtins.types'
---@brief Type definitions for the native-picker registry.

--- One engine's implementation of a builtin: the function name on that
--- engine's own API (`Snacks.picker.<fn>` / `telescope.builtin.<fn>` /
--- `require("fzf-lua").<fn>`), plus optional default opts merged underneath
--- whatever opts the caller passes (caller opts win).
---@class Pickers.Builtins.Impl
---@field fn   string
---@field opts table|nil

--- `false` marks a documented gap: this engine has no native equivalent.
---@alias Pickers.Builtins.EngineImpl Pickers.Builtins.Impl|false

---@class Pickers.Builtins.Entry
---@field desc      string
---@field snacks    Pickers.Builtins.EngineImpl
---@field telescope Pickers.Builtins.EngineImpl
---@field fzf       Pickers.Builtins.EngineImpl

return {}
