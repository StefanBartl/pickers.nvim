---@module 'pickers.refine'
---@brief Engine-agnostic result refinement: a stack of filter clauses, the
---@brief predicate built from it, a title string that shows it, and a
---@brief `vim.ui`-driven prompt to edit it.
---@description
--- This module is **pure model + UI**. It does not know about telescope,
--- fzf-lua or snacks, and it never opens, closes or refreshes a picker. A
--- caller owns re-running or refreshing its own picker when the stack
--- changes:
---
---   local h = require("pickers.refine").new({
---     fields = {
---       path    = function(it) return it.path end,
---       content = function(it) return it.line end,
---     },
---   })
---
---   -- bound to a key inside the picker:
---   h:prompt(function()
---     reopen_my_picker(h:apply(all_items))          -- caller's job
---   end)
---
---   -- prompt title:
---   my_prompt_title = h:title("Select matches", #shown, #all_items)
---
--- A `term` entered as `/.../ ` (slash-delimited) is taken as a Lua pattern
--- (`mode = "regex"`); anything else is a case-insensitive substring.

require("pickers.refine.@types")

local M = {}

-- ── pure helpers ─────────────────────────────────────────────────────────────

---@internal
---@param clause Pickers.Refine.Clause
---@param value string|nil
---@return boolean
local function clause_matches(clause, value)
  local hit = false
  if value ~= nil then
    if clause.mode == "regex" then
      local ok, found = pcall(string.find, value, clause.term)
      hit = ok and found ~= nil
    else
      hit = value:lower():find(clause.term:lower(), 1, true) ~= nil
    end
  end
  if clause.negate then return not hit end
  return hit
end

---Build an AND predicate from a stack. A clause whose `field` has no
---resolver in `fields` is skipped (treated as passing), so a stack authored
---for one item shape degrades quietly on another.
---@param stack Pickers.Refine.Stack
---@param fields Pickers.Refine.Fields
---@return fun(item: any): boolean
function M.predicate(stack, fields)
  return function(item)
    for _, clause in ipairs(stack) do
      local resolver = fields[clause.field]
      if resolver and not clause_matches(clause, resolver(item)) then return false end
    end
    return true
  end
end

---Filter `items` through `stack`. Order is preserved; the input is not
---mutated.
---@generic T
---@param items T[]
---@param stack Pickers.Refine.Stack
---@param fields Pickers.Refine.Fields
---@return T[]
function M.apply(items, stack, fields)
  if #stack == 0 then return items end
  local pred = M.predicate(stack, fields)
  local out = {}
  for _, it in ipairs(items) do
    if pred(it) then out[#out + 1] = it end
  end
  return out
end

---A compact one-line summary of the stack, e.g. `path~src · ¬content=~%.test`.
---`""` for an empty stack.
---@param stack Pickers.Refine.Stack
---@return string
function M.summary(stack)
  local parts = {}
  for _, c in ipairs(stack) do
    local op = c.mode == "regex" and "=~" or "~"
    parts[#parts + 1] = (c.negate and "¬" or "") .. c.field .. op .. c.term
  end
  return table.concat(parts, " · ")
end

---`base`, plus the stack summary and (optionally) a count, for a prompt
---title. `shown`/`total` render as `(shown/total)`; `total` alone as
---`(total)`.
---@param base string
---@param stack Pickers.Refine.Stack
---@param shown integer|nil
---@param total integer|nil
---@return string
function M.title(base, stack, shown, total)
  local count = ""
  if shown ~= nil and total ~= nil then
    count = (" (%d/%d)"):format(shown, total)
  elseif total ~= nil then
    count = (" (%d)"):format(total)
  end
  local s = M.summary(stack)
  if s == "" then return base .. count end
  return base .. " — " .. s .. count
end

---@internal
---Split a raw input into (mode, term). `/foo/` → regex `foo`; else substr.
---@param raw string
---@return "substr"|"regex", string
local function parse_term(raw)
  local rx = raw:match("^/(.*)/$")
  if rx and rx ~= "" then return "regex", rx end
  return "substr", raw
end

-- ── stateful handle ──────────────────────────────────────────────────────────

---@class Pickers.Refine.Handle
local Handle = {}
Handle.__index = Handle

---@param opts Pickers.Refine.Opts
---@return Pickers.Refine.Handle
function M.new(opts)
  assert(
    type(opts) == "table" and type(opts.fields) == "table",
    "pickers.refine.new: opts.fields required"
  )
  return setmetatable({ stack = {}, fields = opts.fields }, Handle)
end

---@return boolean
function Handle:is_active()
  return #self.stack > 0
end

---@return fun(item: any): boolean
function Handle:predicate()
  return M.predicate(self.stack, self.fields)
end

---@generic T
---@param items T[]
---@return T[]
function Handle:apply(items)
  return M.apply(items, self.stack, self.fields)
end

---@param base string
---@param shown integer|nil
---@param total integer|nil
---@return string
function Handle:title(base, shown, total)
  return M.title(base, self.stack, shown, total)
end

---Drop the most recent clause.
function Handle:pop()
  self.stack[#self.stack] = nil
end

---Drop every clause.
function Handle:clear()
  self.stack = {}
end

---@internal
---@return string[]  field names, sorted for a stable menu
function Handle:_field_names()
  local names = {}
  for k in pairs(self.fields) do
    names[#names + 1] = k
  end
  table.sort(names)
  return names
end

---Open the edit flow: `vim.ui.select` (pick a field / negate / pop / clear),
---then `vim.ui.input` for the term.
---
---`on_change(stack)` runs once, only when the stack actually changed. `on_done()`
---runs once when the flow ends either way (commit **or** cancel) — a caller
---that closed its picker before prompting uses this to always reopen.
---@param on_change fun(stack: Pickers.Refine.Stack)|nil
---@param on_done fun()|nil
function Handle:prompt(on_change, on_done)
  local function finish(changed)
    if changed and on_change then on_change(self.stack) end
    if on_done then on_done() end
  end

  local choices = {}
  for _, field in ipairs(self:_field_names()) do
    choices[#choices + 1] = { kind = "add", field = field, negate = false }
    choices[#choices + 1] = { kind = "add", field = field, negate = true }
  end
  if #self.stack > 0 then
    choices[#choices + 1] = { kind = "pop" }
    choices[#choices + 1] = { kind = "clear" }
  end

  vim.ui.select(choices, {
    prompt = "Refine results",
    format_item = function(c)
      if c.kind == "pop" then
        return ("Remove last filter  (%s)"):format(M.summary({ self.stack[#self.stack] }))
      elseif c.kind == "clear" then
        return "Clear all filters"
      end
      return ("%s %s…"):format(c.field, c.negate and "excludes" or "contains")
    end,
  }, function(choice)
    if not choice then return finish(false) end

    if choice.kind == "pop" then
      self:pop()
      return finish(true)
    end
    if choice.kind == "clear" then
      self:clear()
      return finish(true)
    end

    vim.ui.input({
      prompt = ("%s %s (/…/ = pattern): "):format(
        choice.field,
        choice.negate and "excludes" or "contains"
      ),
    }, function(raw)
      if not raw or raw == "" then return finish(false) end
      local mode, term = parse_term(raw)
      self.stack[#self.stack + 1] =
        { field = choice.field, mode = mode, term = term, negate = choice.negate }
      finish(true)
    end)
  end)
end

return M
