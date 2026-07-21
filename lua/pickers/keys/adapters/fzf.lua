---@module 'pickers.keys.adapters.fzf'
---@brief Translate resolved in-picker keys into an fzf-lua `keymap.builtin` table.
---@description
--- fzf-lua is the documented capability gap (see `pickers.keys` @brief). Its
--- builtin previewer supports vertical preview scroll but has no horizontal
--- preview scroll action, and its history is fzf's own `--history` bound to
--- ctrl-p / ctrl-n natively — not remappable through `keymap.builtin`.
---
--- So only these two actions translate:
---   preview_scroll_down → "preview-page-down"
---   preview_scroll_up   → "preview-page-up"
---
--- Everything else (horizontal scroll, history) is silently skipped here — it's
--- a static, unconditional fzf-lua limitation, not a runtime problem, so it does
--- not belong in a startup notification (that would repeat on every launch with
--- nothing the user can act on). It is surfaced instead in `:checkhealth
--- pickers` (`M.skipped()`, consumed by `pickers.health`), which is pull-based.
--- fzf-lua's `keymap.builtin` keys use Neovim-style notation (`<PageDown>`,
--- `<C-d>`), so the resolved lhs pass through unchanged.

local M = {}

--- action name → fzf-lua builtin previewer action, or false when unsupported.
local ACTION_TO_FZF = {
  preview_scroll_down = "preview-page-down",
  preview_scroll_up = "preview-page-up",
  preview_scroll_left = false,
  preview_scroll_right = false,
  history_back = false,
  history_forward = false,
}

--- Build the `keymap.builtin` table.
---@param resolved table<string, { lhs: string[], modes: string[] }>
---@return table<string, string>
function M.keymap(resolved)
  local builtin = {}

  for action, spec in pairs(resolved) do
    local fzf_action = ACTION_TO_FZF[action]
    if fzf_action then
      for _, lhs in ipairs(spec.lhs) do
        builtin[lhs] = fzf_action
      end
    end
  end

  return builtin
end

--- Actions the user has bound (non-empty lhs) that fzf-lua cannot remap, given
--- the currently resolved config. Used by `:checkhealth pickers` — see
--- `pickers.health`.
---@param resolved table<string, { lhs: string[], modes: string[] }>
---@return string[]
function M.skipped(resolved)
  local out = {}
  for action, spec in pairs(resolved) do
    if ACTION_TO_FZF[action] == false and #spec.lhs > 0 then out[#out + 1] = action end
  end
  table.sort(out)
  return out
end

--- Install the builtin keys globally via `fzf-lua.setup(..., true)`. The second
--- arg keeps fzf-lua's existing defaults (it otherwise resets from scratch).
--- No-op when fzf-lua is not installed.
---@param resolved table<string, { lhs: string[], modes: string[] }>
function M.patch(resolved)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then return end

  local builtin = M.keymap(resolved)
  if vim.tbl_isempty(builtin) then return end

  pcall(function()
    fzf.setup({ keymap = { builtin = builtin } }, true)
  end)
end

return M
