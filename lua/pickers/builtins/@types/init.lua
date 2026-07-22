---@module 'pickers.builtins.types'
---@brief Type definitions for the native-picker registry.

--- One engine's implementation of a builtin. Usually the function name on that
--- engine's own API (`Snacks.picker.<fn>` / `telescope.builtin.<fn>` /
--- `require("fzf-lua").<fn>`), plus optional default opts merged underneath
--- whatever opts the caller passes (caller opts win).
---
--- For pickers that don't fit the flat `mod[fn]` dispatch — e.g. telescope's
--- file browser, which is an *extension* (`telescope.extensions.file_browser`)
--- rather than a `telescope.builtin.*` function — supply `run` instead: a
--- self-contained invoker that receives the caller opts and handles loading /
--- dispatch itself. Exactly one of `fn` or `run` must be present.
---@class Pickers.Builtins.Impl
---@field fn   string|nil
---@field opts table|nil
---@field run  fun(opts: table)|nil

--- `false` marks a documented gap: this engine has no native equivalent.
---@alias Pickers.Builtins.EngineImpl Pickers.Builtins.Impl|false

---@class Pickers.Builtins.Entry
---@field desc      string
---@field snacks    Pickers.Builtins.EngineImpl
---@field telescope Pickers.Builtins.EngineImpl
---@field fzf       Pickers.Builtins.EngineImpl

return {}
