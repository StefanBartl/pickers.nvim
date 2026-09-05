---@meta
---@module 'pickers.refine.types'
---@brief Type definitions for the refine namespace (filter stack + UI).

--- One filter clause. `field` is a logical name resolved by the caller's
--- `fields` table to a string extracted from an item; `mode` decides how
--- `term` is matched against it; `negate` inverts the result.
---@class Pickers.Refine.Clause
---@field field string
---@field mode "substr"|"regex"
---@field term string
---@field negate boolean

---@alias Pickers.Refine.Stack Pickers.Refine.Clause[]

--- Maps a logical field name to a function that pulls the string to match
--- from one item. A clause whose `field` has no entry here is ignored.
---@alias Pickers.Refine.Fields table<string, fun(item: any): string|nil>

---@class Pickers.Refine.Opts
---@field fields Pickers.Refine.Fields

---@class Pickers.Refine.Handle
---@field stack Pickers.Refine.Stack
---@field fields Pickers.Refine.Fields

return {}
