---@module 'pickers.cheatsheet'
---@brief `?`-style in-picker keymap cheatsheet — a read-only floating panel
---listing every currently-active `pickers.keys` binding.
---@description
--- Reads back `pickers.keys.resolve()` -- the single source of truth for
--- in-picker keys, already engine-agnostic -- rather than a separate catalog,
--- so a remapped or disabled key shows up as what it actually is, not what
--- DEFAULTS.lua says it should be.
---
--- A raw `?` cannot be the trigger: every picker prompt starts in insert
--- mode, where `?` is just a character to search for. `pickers.keys.cheatsheet`
--- defaults to `<C-/>` instead -- see its @description for why `<C-?>` (the
--- literal Ctrl-Shift-/ chord some terminals send) was rejected: Neovim
--- resolves it to the same byte (0x7F / DEL) that Backspace sends in many
--- terminal+font setups, which would fire the cheatsheet on every backspace.
---
--- fzf-lua is a partial exception, same class as create_file/open_background
--- (see `pickers.entry_actions`): its action-table keys are fzf's own bind
--- syntax, not Neovim's, so the fzf-lua adapter passes a fixed `overrides`
--- entry here instead of trusting `resolve()`'s Neovim-notation lhs.

local M = {}

---Human-readable description per `pickers.keys` action. Exported (not just
---`local`) so `pickers.entry_actions.adapters.snacks` can reuse the same
---strings as the `desc` on its own named actions -- Snacks' native
---`?` → `toggle_help_*` panel (see @description) reads those straight off
---real buffer keymaps, and duplicating the text here and there would only
---give the two a chance to drift.
---@type table<string, string>
M.DESCRIPTIONS = {
  preview_scroll_down = "Scroll preview down",
  preview_scroll_up = "Scroll preview up",
  preview_scroll_left = "Scroll preview left",
  preview_scroll_right = "Scroll preview right",
  history_back = "Previous query in history",
  history_forward = "Next query in history",
  create_file = "Create file/folder",
  open_background = "Open entry in background window",
  preview_toggle = "Toggle preview",
  split = "Open entry in a horizontal split",
  vsplit = "Open entry in a vertical split",
  tab = "Open entry in a new tab",
  mouse_confirm = "Double-click a result to open it",
  cheatsheet = "Show this cheatsheet",
}

---Build the display lines: one row per action that is actually bound right
---now, widest-lhs-aligned.
---@param overrides table<string, string>|nil Engine-fixed lhs display text
---(fzf-lua bind syntax) that wins over `keys.resolve()`'s Neovim-notation lhs
---for that action, keyed by action name.
---@return string[]
function M.lines(overrides)
  overrides = overrides or {}
  local keys = require("pickers.keys")
  local resolved = keys.resolve()

  ---@type { lhs: string, desc: string }[]
  local rows = {}
  local widest = 0

  for _, action in ipairs(keys.ORDER) do
    local lhs_display = overrides[action]
    if not lhs_display then
      local spec = resolved[action]
      if spec and #spec.lhs > 0 then lhs_display = table.concat(spec.lhs, " / ") end
    end
    if lhs_display then
      rows[#rows + 1] = { lhs = lhs_display, desc = M.DESCRIPTIONS[action] or action }
      widest = math.max(widest, #lhs_display)
    end
  end

  local lines = { "" }
  for _, row in ipairs(rows) do
    lines[#lines + 1] = string.format("  %-" .. widest .. "s  %s", row.lhs, row.desc)
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  :Pickers command syntax — see docs/cheatsheet.md"
  lines[#lines + 1] = "  q / <Esc>  close"

  return lines
end

---Short hint text for a picker's own title/header area (telescope
---`results_title`, fzf-lua `--header`) — `""` when the cheatsheet action is
---disabled or unbound, so a caller can skip setting the option entirely
---rather than showing an empty hint. Snacks has no equivalent static-text
---slot without pickers.nvim owning the user's layout config (its title only
---composes from a template + the live `{flags}` toggle badges — see
---`pickers.keys.adapters.snacks` for what those actually are); snacks users
---reach the same information through its OWN native `?` → `toggle_help_*`
---panel instead, which `pickers.entry_actions.adapters.snacks` feeds proper
---`desc` strings for.
---@param engine "telescope"|"fzf-lua"
---@return string
function M.hint(engine)
  if require("pickers.config").get().keys.enable == false then return "" end

  if engine == "fzf-lua" then return "f1 cheatsheet" end

  local spec = require("pickers.keys").resolve().cheatsheet
  if not spec or #spec.lhs == 0 then return "" end
  return spec.lhs[1] .. " cheatsheet"
end

---Open the cheatsheet panel. No-op (silently) when ui.nvim is not installed
----- same soft-dependency posture as `pickers.ui.action_picker`/`dir_nav_picker`
----- falling back to a single `vim.notify` dump so the keys are still visible.
---@param opts { overrides?: table<string, string>, on_close?: fun() }|nil
function M.show(opts)
  opts = opts or {}
  local lines = M.lines(opts.overrides)

  local kit_ok, kit = pcall(require, "ui.kit")
  if not (kit_ok and kit and type(kit.viewer) == "function") then
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "pickers.nvim keymaps" })
    if opts.on_close then opts.on_close() end
    return
  end

  local surf = kit.viewer({
    lines = lines,
    title = "pickers.nvim keymaps",
    filetype = "pickers_cheatsheet",
  })
  if surf and opts.on_close then surf:on_close(opts.on_close) end
end

return M
