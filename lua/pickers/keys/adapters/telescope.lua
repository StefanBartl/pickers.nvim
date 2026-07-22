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
---   preview_toggle        → actions.layout.toggle_preview
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

--- action name → telescope.actions.layout field name. A separate table
--- because toggle_preview lives on a different sub-module than the rest.
local ACTION_TO_TS_LAYOUT = {
  preview_toggle = "toggle_preview",
}

--- Build telescope `defaults.mappings` (`{ i = {...}, n = {...} }`).
--- Values are the resolved `telescope.actions`/`telescope.actions.layout`
--- functions; when telescope is not installed this returns `{ i = {}, n = {} }`.
---@param resolved table<string, { lhs: string[], modes: string[] }>
---@return { i: table<string, function>, n: table<string, function> }
function M.mappings(resolved)
  local out = { i = {}, n = {} }

  local ok, actions = pcall(require, "telescope.actions")
  if not ok then return out end
  local ok_layout, layout = pcall(require, "telescope.actions.layout")

  local function bind(action, ts_action)
    local spec = resolved[action]
    if not spec or not ts_action then return end
    for _, lhs in ipairs(spec.lhs) do
      for _, mode in ipairs(spec.modes) do
        if out[mode] then out[mode][lhs] = ts_action end
      end
    end
  end

  for action, ts_name in pairs(ACTION_TO_TS) do
    bind(action, actions[ts_name])
  end
  if ok_layout then
    for action, ts_name in pairs(ACTION_TO_TS_LAYOUT) do
      bind(action, layout[ts_name])
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
