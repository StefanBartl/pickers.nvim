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
---
--- In a picker that was not opened by a tab group the key must not close it.
--- On `<Tab>`/`<S-Tab>` it then does what telescope binds there by default --
--- toggle the selection and step -- so multi-select keeps working in every
--- picker that was not opened as a tab; on any other lhs it only says so
--- (`tabs.not_a_tab_picker`). The step direction is chosen from the PHYSICAL
--- `lhs` (`<Tab>` always steps "worse"/forward, `<S-Tab>` always "better"/
--- backward -- whatever that key does everywhere else), independently of
--- `delta` (which direction `action` switches the tab group): a user who
--- binds `tab_next` to `<S-Tab>` and `tab_prev` to `<Tab>` still gets the
--- native step that matches the key they actually pressed.
---@param delta integer  # direction `action` switches the tab group
---@param lhs string     # the physical lhs this closure was bound to
---@return fun(prompt_bufnr: integer)
local function tab_switch(delta, lhs)
  local l = lhs:lower()
  return function(prompt_bufnr)
    local tabs = require("pickers.tabs")
    local actions = require("telescope.actions")
    if not tabs.is_tab_buffer(prompt_bufnr) then
      if l == "<tab>" then
        actions.toggle_selection(prompt_bufnr)
        actions.move_selection_worse(prompt_bufnr)
      elseif l == "<s-tab>" then
        actions.toggle_selection(prompt_bufnr)
        actions.move_selection_better(prompt_bufnr)
      else
        tabs.not_a_tab_picker()
      end
      return
    end
    local query = require("telescope.actions.state").get_current_line()
    actions.close(prompt_bufnr)
    tabs.switch(delta, query)
  end
end

--- action name → delta of the tab-group switch.
local TAB_DELTA = { tab_next = 1, tab_prev = -1 }

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
  -- The tab-group switch is chosen per lhs: `<Tab>`/`<S-Tab>` fall back to
  -- telescope's own select-and-step in a picker that is not a tab picker.
  for action, delta in pairs(TAB_DELTA) do
    local spec = resolved[action]
    if spec then
      for _, lhs in ipairs(spec.lhs) do
        local fn = tab_switch(delta, lhs)
        for _, mode in ipairs(spec.modes) do
          if out[mode] then out[mode][lhs] = fn end
        end
      end
    end
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
