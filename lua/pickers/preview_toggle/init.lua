---@module 'pickers.preview_toggle'
---@brief In-picker keymap to toggle the preview pane. Telescope-only:
---fzf-lua ships this natively on `<F4>`, snacks.nvim on `<A-p>` -- neither
---needs pickers.nvim to provide it, so only a telescope adapter exists.
---@description
--- Same "user merges into their own setup()" model as pickers.entry_actions
--- -- pickers.nvim does not register this itself.
---@see Pickers.PreviewToggleConfig

local M = {}

---Build the {i={...}, n={...}} mapping table for telescope.setup()'s
---defaults.mappings, honouring `keys.preview_toggle.key`. Empty tables when
---unset (the default), keeping it fully inert.
---@return table mappings
function M.get_mappings()
  local cfg = require("pickers.config").get().keys.preview_toggle
  local mappings = { i = {}, n = {} }

  if not cfg.key then return mappings end

  local toggle_preview = require("telescope.actions.layout").toggle_preview
  mappings.i[cfg.key] = toggle_preview
  mappings.n[cfg.key] = toggle_preview

  return mappings
end

return M
