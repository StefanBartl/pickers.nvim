---@module 'pickers.keys.types'
---@brief Type definitions for the in-picker keys layer.

-- ###########################################################################
-- In-picker keys config

--- Each action value is a single lhs, a list of lhs, or `false` to unbind it.
---@alias Pickers.KeyBinding string|string[]|false

---@class Pickers.KeysConfig
---@field enable?               boolean            Master switch (default: true)
---@field preview_scroll_down?  Pickers.KeyBinding Default: "<PageDown>"
---@field preview_scroll_up?    Pickers.KeyBinding Default: "<PageUp>"
---@field preview_scroll_left?  Pickers.KeyBinding Default: "<C-Left>"
---@field preview_scroll_right? Pickers.KeyBinding Default: "<C-Right>"
---@field history_back?         Pickers.KeyBinding Default: "<C-p>"
---@field history_forward?      Pickers.KeyBinding Default: "<C-n>"
---@field create_file?          Pickers.KeyBinding Default: "<C-a>"
---@field open_background?      Pickers.KeyBinding Default: { "<S-CR>", "<C-o>" }
---@field open_background_show? boolean            Also display (not focus) the entry in the background window. Default: false
---@field preview_toggle?       Pickers.KeyBinding Default: false (opt-in, telescope-only)
---@field split?                Pickers.KeyBinding Open selected entry in a horizontal split. Default: "<C-s>"
---@field vsplit?               Pickers.KeyBinding Open selected entry in a vertical split. Default: "<C-v>"
---@field tab?                  Pickers.KeyBinding Open selected entry in a new tab. Default: "<C-t>"
---@field mouse_confirm?        Pickers.KeyBinding Double-click a result to open it. Default: "<2-LeftMouse>"

return {}
