---@module 'pickers.selected_index.debounce'
---@brief Debounce with proper libuv timer cleanup (falls back to vim.defer_fn).

local M = {}

---Create a debounced version of `fn` with an explicit cleanup handle.
---@param fn function
---@param delay_ms integer
---@return function debounced
---@return function cleanup
function M.debounce(fn, delay_ms)
  local timer = nil

  local debounced = function(...)
    local args = { ... }
    local argc = select("#", ...)

    if timer then
      timer:stop()
      if not timer:is_closing() then timer:close() end
      timer = nil
    end

    timer = vim.uv.new_timer()
    if not timer then
      vim.defer_fn(function()
        fn(unpack(args, 1, argc))
      end, delay_ms)
      return
    end

    timer:start(
      delay_ms,
      0,
      vim.schedule_wrap(function()
        fn(unpack(args, 1, argc))
        if timer then
          timer:close()
          timer = nil
        end
      end)
    )
  end

  local cleanup = function()
    if timer then
      timer:stop()
      if not timer:is_closing() then timer:close() end
      timer = nil
    end
  end

  return debounced, cleanup
end

return M
