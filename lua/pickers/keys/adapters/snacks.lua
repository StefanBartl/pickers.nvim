---@module 'pickers.keys.adapters.snacks'
---@brief Translate resolved in-picker keys into a Snacks.picker `win` table.
---@description
--- Snacks action names happen to match pickers.nvim's engine-neutral names
--- 1:1 (`preview_scroll_down`, `history_back`, …), so translation is just
--- routing each action to the right window(s):
---   preview scroll → input + list + preview (works wherever focus is)
---   history        → input only (insert mode)
---
--- Returned shape merges straight into `Snacks.picker` `win`:
---   { input = { keys = {...} }, list = { keys = {...} }, preview = { keys = {...} } }
---
--- Snacks list/preview windows are normal mode only, so those entries use the
--- bare-string binding form; the input window carries the mode-qualified form.

local M = {}

--- Snacks treats these as history navigation → input window, insert mode only.
local HISTORY = { history_back = true, history_forward = true }

---@param resolved table<string, { lhs: string[], modes: string[] }>
---@return { input: { keys: table }, list: { keys: table }, preview: { keys: table } }
function M.win(resolved)
  local input, list, preview = {}, {}, {}

  for action, spec in pairs(resolved) do
    for _, lhs in ipairs(spec.lhs) do
      if HISTORY[action] then
        input[lhs] = { action, mode = { "i" } }
      else
        -- Preview scroll: reachable from every window.
        input[lhs] = { action, mode = { "i", "n" } }
        list[lhs] = action
        preview[lhs] = action
      end
    end
  end

  return {
    input = { keys = input },
    list = { keys = list },
    preview = { keys = preview },
  }
end

return M
