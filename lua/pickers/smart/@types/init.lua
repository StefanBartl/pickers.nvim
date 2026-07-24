---@module 'pickers.smart.types'
---@brief Type definitions for the `smart` action (combined grep + find files).
---@description
--- The smart action runs `rg` (content) and `fd` (filenames) for the same live
--- query, then merges both result sets into ONE list ranked by a shared scorer
--- (`pickers.smart.score`) — so a hit ranks by relevance regardless of whether
--- it came from grep or find. Every engine adapter drives the same core
--- (`pickers.smart.query`), so the ranking is identical across
--- telescope/fzf-lua/snacks.

-- ###########################################################################
-- Scoring weights

---@class Pickers.Smart.Weights
---@field filename number  Multiplier for the filename-match component (default 1.0)
---@field content  number  Multiplier for the grep content-match component (default 1.0)
---@field both     number  Flat bonus added to a file whose path ALSO has grep hits (default 25)

-- ###########################################################################
-- Config (setup surface)

---@class Pickers.SmartConfig
---@field weights Pickers.Smart.Weights  Relative weighting of the score components
---@field limit   integer                Max merged results kept after ranking (default 2000)
---@field timeout integer                Per-command wait timeout in ms (default 3000)

-- ###########################################################################
-- Raw candidates (produced by pickers.smart.search)

---@class Pickers.Smart.File
---@field path    string  Path relative to `root`
---@field root    string  Absolute search root the hit came from
---@field abspath string  Absolute, normalised path

---@class Pickers.Smart.Grep
---@field path    string  Path relative to `root`
---@field root    string  Absolute search root the hit came from
---@field abspath string  Absolute, normalised path
---@field lnum    integer 1-based line number
---@field col     integer 1-based column
---@field text    string  Matched line text

-- ###########################################################################
-- Ranked item (produced by pickers.smart.score.rank / pickers.smart.query)

---@class Pickers.Smart.Item
---@field kind    "file"|"grep"
---@field path    string       Path relative to `root`
---@field root    string       Absolute search root
---@field abspath string       Absolute, normalised path
---@field lnum    integer|nil  grep only
---@field col     integer|nil  grep only
---@field text    string|nil   grep only (matched line)
---@field score   number       Higher = more relevant
---@field display string       Human-readable line for the picker
---@field _rank   integer      1-based position in the ranked list (order key for engines)

return {}
