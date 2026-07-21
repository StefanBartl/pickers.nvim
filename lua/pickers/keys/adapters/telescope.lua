---@module 'pickers.keys.adapters.telescope'
---@brief Translate resolved in-picker keys into telescope mappings.
---@description
--- pickers.nvim's engine-neutral actions map onto telescope's action functions:
---   preview_scroll_down  → actions.preview_scrolling_down
---   preview_scroll_up    → actions.preview_scrolling_up
---   preview_scroll_left  → actions.preview_scrolling_left
---   preview_scroll_right → actions.preview_scrolling_right
---   history_back         → actions.cycle_history_prev
---   history_forward      → actions.cycle_history_next
---
--- `mappings()` builds a `defaults.mappings` table (`{ i = {...}, n = {...} }`);
--- `patch()` installs it via `telescope.setup()`. Telescope deep-merges
--- `defaults.mappings`, so a later user `setup()` keeps ours as long as it does
--- not rebind the same lhs.

local M = {}

--- action name → telescope.actions field name.
local ACTION_TO_TS = {
  preview_scroll_down = "preview_scrolling_down",
  preview_scroll_up = "preview_scrolling_up",
  preview_scroll_left = "preview_scrolling_left",
  preview_scroll_right = "preview_scrolling_right",
  history_back = "cycle_history_prev",
  history_forward = "cycle_history_next",
}

--- Build telescope `defaults.mappings` (`{ i = {...}, n = {...} }`).
--- Values are the resolved `telescope.actions` functions; when telescope is not
--- installed the actions table is unavailable and this returns `{ i = {}, n = {} }`.
---@param resolved table<string, { lhs: string[], modes: string[] }>
---@return { i: table<string, function>, n: table<string, function> }
function M.mappings(resolved)
  local out = { i = {}, n = {} }

  local ok, actions = pcall(require, "telescope.actions")
  if not ok then return out end

  for action, spec in pairs(resolved) do
    local ts_name = ACTION_TO_TS[action]
    local ts_action = ts_name and actions[ts_name]
    if ts_action then
      for _, lhs in ipairs(spec.lhs) do
        for _, mode in ipairs(spec.modes) do
          if out[mode] then out[mode][lhs] = ts_action end
        end
      end
    end
  end

  return out
end

--- Install the mappings globally via `telescope.setup()`. No-op when telescope
--- is not installed.
---@param resolved table<string, { lhs: string[], modes: string[] }>
function M.patch(resolved)
  local ok = pcall(require, "telescope")
  if not ok then return end

  pcall(function()
    require("telescope").setup({ defaults = { mappings = M.mappings(resolved) } })
  end)
end

return M
