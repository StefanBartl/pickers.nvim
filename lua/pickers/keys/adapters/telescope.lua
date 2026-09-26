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
---   split                 → actions.select_horizontal
---   vsplit                → actions.select_vertical
---   tab                   → actions.select_tab
---   mouse_confirm         → actions.select_default (telescope has no default
---                           mouse mapping at all)
---
--- `mappings()` builds a `defaults.mappings` table (`{ i = {...}, n = {...} }`);
--- `patch()` installs it via `telescope.setup()`. Telescope's own `setup()`
--- does NOT deep-merge `defaults.mappings` -- unlike `layout_config`/
--- `history`/`cache_picker`/`preview`, it is a plain `first_non_null()` pick
--- (see `telescope.config`'s `get()`), so a second `setup()` call replaces the
--- whole table wholesale. `patch()` therefore reads the CURRENT
--- `telescope.config.values.mappings` (which already reflects whatever the
--- user's own prior `setup()` call configured) and deep-merges its own
--- additions into it itself, before calling `setup()` -- the user's lhs wins
--- on conflict, so their own `defaults.mappings` block is never discarded
--- (LUA-90).

local M = {}

--- action name → telescope.actions field name.
local ACTION_TO_TS = {
  preview_scroll_down = "preview_scrolling_down",
  preview_scroll_up = "preview_scrolling_up",
  preview_scroll_left = "preview_scrolling_left",
  preview_scroll_right = "preview_scrolling_right",
  history_back = "cycle_history_prev",
  history_forward = "cycle_history_next",
  split = "select_horizontal",
  vsplit = "select_vertical",
  tab = "select_tab",
  mouse_confirm = "select_default",
}

--- action name → telescope.actions.layout field name. A separate table
--- because toggle_preview lives on a different sub-module than the rest.
local ACTION_TO_TS_LAYOUT = {
  preview_toggle = "toggle_preview",
}

--- action name → a pickers.nvim function taking the prompt buffer: the
--- tab-group switch closes the picker and reopens the next target with the
--- current line as its query (pickers.tabs).
local ACTION_TO_FN = {
  tab_next = function(prompt_bufnr)
    local state = require("telescope.actions.state")
    local query = state.get_current_line()
    require("telescope.actions").close(prompt_bufnr)
    require("pickers.tabs").next(query)
  end,
  tab_prev = function(prompt_bufnr)
    local state = require("telescope.actions.state")
    local query = state.get_current_line()
    require("telescope.actions").close(prompt_bufnr)
    require("pickers.tabs").prev(query)
  end,
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

  ---@internal
  ---@param action string
  ---@param ts_action function|nil
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
  for action, fn in pairs(ACTION_TO_FN) do
    bind(action, fn)
  end

  return out
end

--- Contribution for `pickers.engines.patcher`: our mappings folded into what
--- the host already has in `defaults.mappings` (the `current` snapshot) --
--- never replacing it wholesale, since telescope's own `setup()` does not
--- deep-merge this key itself (see the module doc above). The user's own lhs
--- wins on conflict: pickers.nvim only fills in additions.
---@param resolved table<string, { lhs: string[], modes: string[] }>
---@return fun(current: table): table
function M.contribute(resolved)
  return function(current)
    local mappings = (current.defaults or {}).mappings or {}
    local ours = M.mappings(resolved)
    return {
      defaults = {
        mappings = {
          i = vim.tbl_extend("keep", mappings.i or {}, ours.i),
          n = vim.tbl_extend("keep", mappings.n or {}, ours.n),
        },
      },
    }
  end
end

--- Install the mappings globally via `telescope.setup()` on their own (the
--- patcher installs every feature together in one call instead). No-op when
--- telescope is not installed.
---@param resolved table<string, { lhs: string[], modes: string[] }>
function M.patch(resolved)
  if not pcall(require, "telescope") then return end
  pcall(function()
    local config = require("telescope.config")
    local part = M.contribute(resolved)({ defaults = config.values or {} })
    require("telescope").setup(part)
  end)
end

return M
