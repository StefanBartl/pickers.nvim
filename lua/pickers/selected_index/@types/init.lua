---@module 'pickers.selected_index.types'
---@brief Type definitions for the selected-index overlay feature.

---@alias Pickers.SelectedIndex.VirtTextPos "overlay" | "right_align" | "eol"
---@alias Pickers.SelectedIndex.VirtLinePos "top" | "down"
---@alias Pickers.SelectedIndex.Position Pickers.SelectedIndex.VirtTextPos | Pickers.SelectedIndex.VirtLinePos

---@class Pickers.SelectedIndex.HighlightSpec
---@field fg string? Foreground color (hex "#RRGGBB" or color name)
---@field bg string? Background color (hex "#RRGGBB" or color name)
---@field bold boolean?
---@field italic boolean?
---@field underline boolean?
---@field undercurl boolean?
---@field strikethrough boolean?
---@field blend integer? Blend level (0-100)

---@alias Pickers.SelectedIndex.HighlightPreset
---| "default"  # Inherits TelescopeResultsFunction
---| "subtle"   # Muted gray, low contrast
---| "bold"     # Bold white on dark background
---| "accent"   # Bright accent color (cyan)
---| "minimal"  # Minimal styling
---| "error"    # Red/warning style
---| "success"  # Green/success style
---| "custom"   # User-provided complete HighlightSpec

---@class Pickers.SelectedIndex.HighlightConfig
---@field preset Pickers.SelectedIndex.HighlightPreset? (default: "default")
---@field custom Pickers.SelectedIndex.HighlightSpec? Used when preset = "custom"

---@class Pickers.SelectedIndexConfig
---@field enabled boolean Toggle for the whole feature (default: false)
---@field position Pickers.SelectedIndex.Position Where to render the index (default: "right_align")
---@field highlight Pickers.SelectedIndex.HighlightConfig

return {}
