---@module 'pickers.entry_actions.open_background'
---@brief Engine-agnostic open-in-background-buffer wrapper.
---@description
--- Shared core behind every picker's "open in background" entry action:
--- notify + lib.nvim.buffer.open_background. Picker-library specifics
--- (entry-path extraction, whether the picker stays open) live in the
--- sibling extract/*.lua and adapters/*.lua modules.
---
--- `keys.open_background_show` (off by default) additionally displays the
--- buffer in the window behind the picker -- `opts.win`, supplied by the
--- caller -- without ever moving focus there; focus stays in the picker the
--- whole time. Off, the action behaves exactly as before: bufadd+bufload
--- only, nothing visible changes.

local notify = require("lib.nvim.notify").create("[pickers.entry_actions.open_background]")
local open_background_core = require("lib.nvim.buffer.open_background")

local fn = vim.fn

local M = {}

---Open `path` as a background buffer (bufadd+bufload) and notify. When
---`opts.win` is a valid window and `keys.open_background_show` is enabled,
---also point that window at the buffer (and `opts.pos`, if given) -- without
---focusing it.
---@param path string Selected entry's path
---@param opts? { win?: integer, pos?: [integer, integer] }
---@return boolean ok
function M.run(path, opts)
  opts = opts or {}

  if not path or path == "" then
    notify.warn("No valid path found")
    return false
  end

  local ok, bufnr_or_err = open_background_core(path)
  if not ok then
    notify.error(bufnr_or_err)
    return false
  end

  local shown = false
  local show_enabled = require("pickers.config").get().keys.open_background_show
  if opts.win and show_enabled and vim.api.nvim_win_is_valid(opts.win) then
    vim.api.nvim_win_set_buf(opts.win, bufnr_or_err)
    if opts.pos and opts.pos[1] and opts.pos[1] > 0 then
      pcall(vim.api.nvim_win_set_cursor, opts.win, opts.pos)
    end
    shown = true
  end

  notify.info((shown and "Shown in background: " or "Buffered: ") .. fn.fnamemodify(path, ":t"))
  return true
end

return M
