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
---
--- `create_file`/`open_background`/`cheatsheet` are deliberately excluded
--- here — unlike the built-in preview-scroll/history actions, they run
--- pickers.nvim-specific logic and are not auto-patched anywhere (same as the
--- telescope/fzf adapters, which simply don't have them in their lookup
--- tables). Without this exclusion `cheatsheet` would fall through to the
--- default branch below and get bound to a Snacks action literally named
--- `"cheatsheet"`, which does not exist. See
--- `pickers.entry_actions.adapters.snacks` for their own `get_actions()`/
--- `get_keys()`/`get_input_keys()` (matching Snacks.picker's own convention).
---
--- `preview_toggle` is also excluded — snacks' own native action for this is
--- named "toggle_preview" (reversed word order from pickers.nvim's
--- engine-neutral name), and snacks already binds it by default
--- (`<A-p>`), so this action is telescope-only; see
--- `pickers.keys.adapters.telescope`.
---
--- `split`/`vsplit`/`tab` are NOT excluded: snacks' own action names are
--- exactly `"split"`/`"vsplit"`/`"tab"`, matching pickers.nvim's
--- engine-neutral names 1:1 (same trick as preview-scroll/history), so they
--- fall through the default branch below and get bound on input+list+preview
--- with no dedicated handling needed.
---
--- `mouse_confirm` → snacks' own `"confirm"` action, list window only (a
--- click always focuses that buffer first, which is never in insert mode).
--- Snacks already ships `<2-LeftMouse>` = "confirm" as its own default, so
--- this is mostly a no-op at the default lhs -- it exists so a user's
--- `cfg.keys.mouse_confirm` override (custom lhs, or `false` to unbind) is
--- still honored by `keys.snacks_win()`.

local M = {}

--- Snacks treats these as history navigation → input window, insert mode only.
local HISTORY = { history_back = true, history_forward = true }

--- action name → snacks action name, list window (normal mode) only.
local CONFIRM = { mouse_confirm = "confirm" }

--- Handled elsewhere (pickers.entry_actions, or not applicable to snacks) --
--- see @description. The path-copy and system actions are entry_actions
--- concerns like create_file/open_background, and their filetree chords
--- (`[a`, `ML`, `<leader>sm`, ...) must never reach the default branch below:
--- it binds every window INCLUDING `input` in insert mode, which would swallow
--- those plain-printable lhs out of any typed query. See
--- pickers.entry_actions.adapters.snacks' own get_keys() (list window) and
--- get_input_keys() (input window, modes resolved per lhs) for where they
--- actually get bound.
local SKIP = {
  create_file = true,
  open_background = true,
  preview_toggle = true,
  cheatsheet = true,
  copy_absolute = true,
  copy_dirname = true,
  copy_env_rooted = true,
  copy_project_root = true,
  copy_project_relative = true,
  copy_buffer_relative = true,
  markdown_link = true,
  markdown_link_insert = true,
  open_system = true,
  reveal_in_manager = true,
}

--- The pickers.nvim-side actions snacks resolves by name from the `win`
--- keys: `tab_next`/`tab_prev` close the picker and reopen the next target
--- of the active pickers.tabs group with the typed pattern as its query.
---
--- Without an active tab group they do not close anything (`tabs.switch`
--- just says there is no group). `tab_next_select`/`tab_prev_select` are the
--- variants `win()` uses for snacks' own `<Tab>`/`<S-Tab>`: outside a tab group
--- they fall back to snacks' `select_and_next`/`select_and_prev`, so
--- multi-select keeps working in every picker that was not opened as a tab.
---@return table<string, fun(picker: table)>
function M.actions()
  ---@param delta integer
  ---@param native string|nil  # snacks action to run when no tab group is active
  local function switch(delta, native)
    return function(picker)
      local tabs = require("pickers.tabs")
      if not tabs.current() then
        if native then
          picker:action(native)
        else
          tabs.switch(delta)
        end
        return
      end
      local query = ""
      pcall(function()
        query = picker.input and picker.input.filter and picker.input.filter.pattern or ""
      end)
      pcall(function()
        picker:close()
      end)
      tabs.switch(delta, query)
    end
  end
  return {
    tab_next = switch(1),
    tab_prev = switch(-1),
    tab_next_select = switch(1, "select_and_next"),
    tab_prev_select = switch(-1, "select_and_prev"),
  }
end

--- The snacks action name for `action` bound on `lhs`: the tab switches use
--- their select-and-step fallback variant on snacks' own `<Tab>`/`<S-Tab>`.
---@param action string
---@param lhs string
---@return string
local function action_name(action, lhs)
  if action == "tab_next" or action == "tab_prev" then
    local l = lhs:lower()
    if l == "<tab>" or l == "<s-tab>" then return action .. "_select" end
  end
  return action
end

---@param resolved table<string, { lhs: string[], modes: string[] }>
---@return { input: { keys: table }, list: { keys: table }, preview: { keys: table } }
function M.win(resolved)
  local input, list, preview = {}, {}, {}

  for action, spec in pairs(resolved) do
    if not SKIP[action] then
      for _, lhs in ipairs(spec.lhs) do
        if HISTORY[action] then
          input[lhs] = { action, mode = { "i" } }
        elseif CONFIRM[action] then
          list[lhs] = CONFIRM[action]
        else
          -- Preview scroll: reachable from every window.
          local name = action_name(action, lhs)
          input[lhs] = { name, mode = { "i", "n" } }
          list[lhs] = name
          preview[lhs] = name
        end
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
