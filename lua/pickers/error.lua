---@module 'pickers.error'
---@brief Structured error types and a safe-call wrapper for pickers.nvim.
---@description
--- Keeps user-facing failures distinguishable (by `kind`) instead of relying on
--- bare strings. Intentionally small: pickers is a thin dispatcher, so this is a
--- lightweight typed-error helper, not a full error framework.

---@alias Pickers.ErrorKind
---| '"InvalidConfigError"'     # setup() received malformed options
---| '"UnknownScopeError"'      # requested scope/collection does not exist
---| '"UnknownActionError"'     # action is not one of files|grep
---| '"EngineUnavailableError"' # no telescope/fzf engine could be loaded
---| '"SourceError"'            # a source failed to resolve
---| '"InternalError"'          # unexpected pcall failure

---@class Pickers.Error
---@field kind    Pickers.ErrorKind
---@field message string

---@class Pickers.Result
---@field ok     boolean
---@field result any
---@field err    Pickers.Error|nil

local M = {}

---Construct a structured error.
---@param kind    Pickers.ErrorKind
---@param message string
---@return Pickers.Error
function M.new(kind, message)
  return { kind = kind, message = message }
end

---Format an error for display.
---@param err Pickers.Error
---@return string
function M.tostring(err)
  return ("[%s] %s"):format(err.kind or "Error", err.message or "")
end

---Call `fn(...)` under pcall and return a structured Result. Failures are tagged
---with `kind`.
---@param kind Pickers.ErrorKind
---@param fn   function
---@param ...  any
---@return Pickers.Result
function M.safe_call(kind, fn, ...)
  local ok, res = pcall(fn, ...)
  if ok then
    return { ok = true, result = res, err = nil }
  end
  return { ok = false, result = nil, err = M.new(kind, tostring(res)) }
end

return M
