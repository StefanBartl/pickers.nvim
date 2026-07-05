---@module 'pickers.selected_index.highlight'
---@brief Manages the `PickersSelectedIndex` highlight group and its presets.

local M = {}

---@type table<Pickers.SelectedIndex.HighlightPreset, Pickers.SelectedIndex.HighlightSpec>
local PRESETS = {
  default = {
    -- Inherits from TelescopeResultsFunction — no explicit colors set.
  },
  subtle = {
    fg = "#6c7086",
    italic = true,
  },
  bold = {
    fg = "#ffffff",
    bg = "#1e1e2e",
    bold = true,
  },
  accent = {
    fg = "#89dceb",
    bold = true,
  },
  minimal = {
    fg = "#cdd6f4",
  },
  error = {
    fg = "#f38ba8",
    bold = true,
  },
  success = {
    fg = "#a6e3a1",
    bold = true,
  },
  custom = {
    -- Overridden by user config.
  },
}

---@type string
local HL_GROUP = "PickersSelectedIndex"

---@type boolean
local _applied = false

---Apply a highlight configuration to the `PickersSelectedIndex` group.
---@param config Pickers.SelectedIndex.HighlightConfig?
---@return nil
function M.apply(config)
  config = config or {}

  local preset = config.preset or "default"
  local spec

  if preset == "custom" and config.custom then
    spec = vim.tbl_extend("force", {}, config.custom)
  elseif PRESETS[preset] then
    spec = vim.tbl_extend("force", {}, PRESETS[preset])
  else
    spec = vim.tbl_extend("force", {}, PRESETS.default)
  end

  if preset == "default" and not next(spec) then
    vim.api.nvim_set_hl(0, HL_GROUP, { link = "TelescopeResultsFunction" })
  else
    vim.api.nvim_set_hl(0, HL_GROUP, spec)
  end

  _applied = true
end

---Get the highlight group name, applying the default preset lazily if needed.
---@return string
function M.get_group()
  if not _applied then M.apply() end
  return HL_GROUP
end

---Reset to the default (linked) highlight.
---@return nil
function M.reset()
  vim.api.nvim_set_hl(0, HL_GROUP, { link = "TelescopeResultsFunction" })
  _applied = false
end

return M
