---@module 'pickers.engines.types'
---@brief Engine-related type definitions (adapter interface + call options).

-- ###########################################################################
-- Engine identifier

---@alias Pickers.Engine
---| '"auto"'       # Detect: telescope → fzf → snacks
---| '"telescope"'
---| '"fzf"'
---| '"snacks"'

-- ###########################################################################
-- Engine call-options (passed from action → engine)

---@class Pickers.EngineOpts
---@field roots           string[]
---@field prompt          string
---@field query           string|nil
---@field find_command    string[]|nil
---@field additional_args string[]|nil
---@field find            Pickers.FindOpts|nil   pick_files: full flags (ignored when find_command is set). live_grep: only `.exclude` is honoured (hidden/no_ignore/follow are hardcoded there already)

-- ###########################################################################
-- pick_item

---A richer alternative to a plain string for `pick_item`'s `items`. Only
---`text` is required — everything else (a `file` to preview, or any extra
---field a caller wants to carry through, e.g. filetree.nvim's template
---picker stashing the original template descriptor) rides along untouched:
---`on_select` is always called with the EXACT entry that was in `items`
---(string in, string out; table in, that same table out), never a re-parsed
---copy — so a caller never needs to search its own list back by label.
---@class Pickers.Item
---@field text string   Display text — what's shown and fuzzy-matched against.
---@field file string?  Absolute path to preview. When at least one item in a
---                      `pick_item` call carries this, every engine attaches
---                      its own native file previewer (telescope's
---                      `file_previewer`, snacks' default `preview.file`, or
---                      — since fzf is a separate process with no Lua object
---                      passthrough — a hidden per-line field fzf previews via
---                      a pure-Lua callback). Items without `file` still show
---                      (with no/blank preview) alongside ones that have it.

return {}
