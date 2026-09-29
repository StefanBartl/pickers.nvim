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
--- defaults to `<C-/>` instead (plus `<M-?>`) -- see its @description for why `<C-?>` (the
--- literal Ctrl-Shift-/ chord some terminals send) was rejected: Neovim
--- resolves it to the same byte (0x7F / DEL) that Backspace sends in many
--- terminal+font setups, which would fire the cheatsheet on every backspace.
--- `<M-?>` (Alt-Shift-/) has no such problem and is bound as a second lhs.
---
--- The panel is grouped and leads with "Essentials" -- the cheatsheet key
--- itself and `open_background` (<S-CR>), the two keys worth knowing first --
--- and `M.hint()` turns the same two into the legend every picker shows in its
--- title/header.
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
  open_background = "Add entry to the buffer list (no focus switch)",
  preview_toggle = "Toggle preview",
  split = "Open entry in a horizontal split",
  vsplit = "Open entry in a vertical split",
  tab = "Open entry in a new tab",
  mouse_confirm = "Double-click a result to open it",
  cheatsheet = "Show this cheatsheet",
  copy_absolute = "Copy absolute path(s)",
  copy_dirname = "Copy parent directory (absolute)",
  copy_env_rooted = "Copy path with $REPOS_DIR folded in",
  copy_project_root = "Copy absolute project root",
  copy_project_relative = "Copy path relative to the project root",
  copy_buffer_relative = "Copy path relative to the open buffer",
  markdown_link = "Copy as Markdown link(s)",
  open_system = "Open with the system default application",
  reveal_in_manager = "Reveal in the system file manager",
  tab_next = "Next tab-group target",
  tab_prev = "Previous tab-group target",
}

---Display groups, in order. "Essentials" leads on purpose: the cheatsheet key
---itself and `open_background` are the two keys worth knowing before any other.
---An action missing from every group still shows up, under "Other".
---@type { [1]: string, [2]: string[] }[]
local GROUPS = {
  { "Essentials", { "cheatsheet", "open_background" } },
  {
    "Preview",
    {
      "preview_scroll_down",
      "preview_scroll_up",
      "preview_scroll_left",
      "preview_scroll_right",
      "preview_toggle",
    },
  },
  { "History / tabs", { "history_back", "history_forward", "tab_next", "tab_prev" } },
  { "Open / create", { "create_file", "split", "vsplit", "tab", "mouse_confirm" } },
  {
    "Copy path (Tab-selected entries, else the current one)",
    {
      "copy_absolute",
      "copy_dirname",
      "copy_env_rooted",
      "copy_project_root",
      "copy_project_relative",
      "copy_buffer_relative",
      "markdown_link",
    },
  },
  { "System", { "open_system", "reveal_in_manager" } },
}

---Build the display lines: grouped rows, one per action that is actually
---bound right now, widest-lhs-aligned across all groups.
---@param overrides table<string, string>|nil Engine-fixed lhs display text
---(fzf-lua bind syntax) that wins over `keys.resolve()`'s Neovim-notation lhs
---for that action, keyed by action name.
---@return string[]
function M.lines(overrides)
  overrides = overrides or {}
  local keys = require("pickers.keys")
  local resolved = keys.resolve()

  ---@type table<string, { lhs: string, desc: string }>
  local row_of = {}
  local widest = 0
  for _, action in ipairs(keys.ORDER) do
    local lhs_display = overrides[action]
    if not lhs_display then
      local spec = resolved[action]
      if spec and #spec.lhs > 0 then lhs_display = table.concat(spec.lhs, " / ") end
    end
    if lhs_display then
      row_of[action] = { lhs = lhs_display, desc = M.DESCRIPTIONS[action] or action }
      widest = math.max(widest, #lhs_display)
    end
  end

  local lines = {}
  local placed = {}

  ---@param title string
  ---@param actions string[]
  local function section(title, actions)
    local rows = {}
    for _, action in ipairs(actions) do
      local row = row_of[action]
      if row and not placed[action] then
        placed[action] = true
        rows[#rows + 1] = string.format("  %-" .. widest .. "s  %s", row.lhs, row.desc)
      end
    end
    if #rows == 0 then return end
    lines[#lines + 1] = ""
    lines[#lines + 1] = " " .. title
    vim.list_extend(lines, rows)
  end

  for _, group in ipairs(GROUPS) do
    section(group[1], group[2])
  end
  local rest = {}
  for _, action in ipairs(keys.ORDER) do
    if not placed[action] then rest[#rest + 1] = action end
  end
  section("Other", rest)

  vim.list_extend(lines, {
    "",
    "  The prompt is always in insert mode: Ctrl/Alt keys work there. Chords like",
    "  [a, ML or <leader>sm only fire in normal mode (<Esc> in the prompt).",
    "  Tab selects entries; the copy actions then take all of them.",
    "  :Pickers command syntax — see docs/cheatsheet.md",
    "  q / <Esc>  close",
  })
  return lines
end

---Legend text for a picker's own title/header area (telescope
---`results_title`, fzf-lua `--header`, snacks `title`): the two keys worth
---knowing first -- the cheatsheet and `open_background` ("add to buffer list,
---no focus switch", <S-CR>). Each part is left out when its action is
---unbound; `""` when both are (or the whole feature is off), so a caller can
---skip setting the option entirely rather than showing an empty hint.
---
---fzf-lua's keys are fixed (`f1`, `shift-enter`) regardless of `keys.*` -- see
---`pickers.entry_actions.adapters.fzf` -- so its legend never asks
---`pickers.keys.resolve()`.
---@param engine "telescope"|"fzf-lua"|"snacks"
---@return string
function M.hint(engine)
  if require("pickers.config").get().keys.enable == false then return "" end

  if engine == "fzf-lua" then return "f1 cheatsheet · shift-enter add to buffers" end

  local resolved = require("pickers.keys").resolve()
  local parts = {}
  local sheet, background = resolved.cheatsheet, resolved.open_background
  if sheet and #sheet.lhs > 0 then parts[#parts + 1] = sheet.lhs[1] .. " cheatsheet" end
  if background and #background.lhs > 0 then
    parts[#parts + 1] = background.lhs[1] .. " add to buffers"
  end
  return table.concat(parts, " · ")
end

---Open the cheatsheet panel. Falls back to lib.nvim.output.viewer (lib.nvim
---is a hard dependency, unlike ui.nvim) when ui.nvim's own `ui.kit.viewer`
---is not installed -- same soft-dependency posture as
---`pickers.ui.action_picker`/`dir_nav_picker`, minus the fallback ever being
---a plain `vim.notify` dump.
---@param opts { overrides?: table<string, string>, on_close?: fun() }|nil
function M.show(opts)
  opts = opts or {}
  local lines = M.lines(opts.overrides)

  local kit_ok, kit = pcall(require, "ui.kit")
  if not (kit_ok and kit and type(kit.viewer) == "function") then
    local surf = require("lib.nvim.output.viewer").show_lines("pickers.nvim keymaps", lines)
    if surf then
      if opts.on_close then surf:on_close(opts.on_close) end
    elseif opts.on_close then
      -- The panel itself failed to open (e.g. nvim_open_win rejected the
      -- geometry) -- still call on_close so a caller waiting on it to
      -- resume something (fzf-lua.resume(), see entry_actions/adapters/fzf.lua)
      -- is not left hanging forever.
      opts.on_close()
    end
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
