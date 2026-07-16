---@module 'pickers.selected_index.debounce'
---@brief Debounce with proper libuv timer cleanup. Thin adapter over
---`lib.nvim.debounce`, kept as its own module so call sites don't need to
---know about the `{call, cancel}` handle shape.

local lib_debounce = require("lib.nvim.debounce")

local M = {}

---Create a debounced version of `fn` with an explicit cleanup handle.
---@param fn function
---@param delay_ms integer
---@return function debounced
---@return function cleanup
function M.debounce(fn, delay_ms)
  local handle = lib_debounce.new(fn, delay_ms)
  return handle.call, handle.cancel
end

return M
