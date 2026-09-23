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
--- see @description. copy_absolute/copy_dirname/copy_env_rooted/
--- markdown_link are entry_actions concerns like create_file/
--- open_background -- and, unlike those, results-window/normal-mode ONLY
--- (see pickers.keys' @description), so they must not fall through to the
--- default branch below either: that branch binds every window INCLUDING
--- `input` in insert mode, which would swallow their plain-printable lhs
--- (`[`, `]`, `a`, `e`, `M`, `L`) out of any typed query containing them.
--- See pickers.entry_actions.adapters.snacks' own get_keys() (list window,
--- normal mode only) for where they actually get bound.
local SKIP = {
  create_file = true,
  open_background = true,
  preview_toggle = true,
  cheatsheet = true,
  copy_absolute = true,
  copy_dirname = true,
  copy_env_rooted = true,
  markdown_link = true,
}

--- The pickers.nvim-side actions snacks resolves by name from the `win`
--- keys: `tab_next`/`tab_prev` close the picker and reopen the next target
--- of the active pickers.tabs group with the typed pattern as its query.
---@return table<string, fun(picker: table)>
function M.actions()
  local function switch(delta)
    return function(picker)
      local query = ""
      pcall(function()
        query = picker.input and picker.input.filter and picker.input.filter.pattern or ""
      end)
      pcall(function()
        picker:close()
      end)
      require("pickers.tabs").switch(delta, query)
    end
  end
  return { tab_next = switch(1), tab_prev = switch(-1) }
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
          input[lhs] = { action, mode = { "i", "n" } }
          list[lhs] = action
          preview[lhs] = action
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
