# Refine — a filter-stack building block

`pickers.refine` narrows a result list by a **stack of filter clauses** that a
single fuzzy prompt cannot express: *path contains `src`* **and** *content
does not contain `test`*, stacked, each one removable.

It is a **pure model + UI module**. It holds the stack, turns it into a
predicate, renders it into a prompt title, and drives the `vim.ui` flow that
edits it. It never opens, closes or refreshes a picker — the caller does that
in the `on_change` callback. That keeps it engine-agnostic and usable from
outside pickers.nvim (its first consumer, replacer.nvim, wires it into its
own telescope/fzf match picker).

## Model

```lua
---@class Pickers.Refine.Clause
---@field field  string           -- logical name, resolved by `fields`
---@field mode   "substr"|"regex" -- "regex" = Lua pattern
---@field term   string
---@field negate boolean
```

`field` is not fixed. The caller passes a `fields` table mapping each name to
a function that pulls the string to match from one item:

```lua
local refine = require("pickers.refine")

local h = refine.new({
  fields = {
    path    = function(it) return it.path end,
    content = function(it) return it.line end,
  },
})
```

A clause whose `field` has no resolver is ignored, so a stack authored for one
item shape degrades quietly on another.

## Using it in a picker

```lua
-- bound to a key inside the picker (the caller owns the keymap):
local function on_filter_key()
  h:prompt(function()
    reopen_my_picker(h:apply(all_items))   -- or telescope picker:refresh(...)
  end)
end

-- the prompt title, recomputed whenever the list is (re)built:
local title = h:title("Select matches", #shown_items, #all_items)
--            → "Select matches — path~src · ¬content=~test (42/380)"
```

`h:prompt(on_change)` opens `vim.ui.select` (pick a field + contains/excludes,
or *remove last* / *clear all*), then `vim.ui.input` for the term. A term
wrapped in slashes (`/%.lua$/`) is taken as a Lua pattern; anything else is a
case-insensitive substring. `on_change` fires once, only when the stack
actually changed — never on a cancelled prompt.

## API

| Call | Result |
|---|---|
| `refine.new({ fields })` | a handle |
| `h:prompt(on_change, on_done)` | edit the stack via `vim.ui`; `on_change(stack)` only if it changed, `on_done()` always (commit **or** cancel — reopen a closed picker here) |
| `h:apply(items)` | filtered copy (order preserved, input untouched) |
| `h:predicate()` | `fun(item): boolean` |
| `h:title(base, shown?, total?)` | prompt-title string |
| `h:is_active()` | `#stack > 0` |
| `h:pop()` / `h:clear()` | drop the last clause / all clauses |

The same four are also exposed as pure functions taking an explicit
`stack`/`fields`: `refine.predicate`, `refine.apply`, `refine.summary`,
`refine.title`.

## What it does not do

- No keymap. The consumer binds its own (replacer.nvim: `cfg.keymaps.filter`,
  default `<C-f>`).
- No engine refresh. `on_change` is where the consumer rebuilds its finder
  (telescope `picker:refresh`, snacks `picker:find`) or closes and reopens
  (fzf-lua).
- No live-grep integration. For a live picker, "refine" means an extra `rg`
  term, not a post-filter — a separate concern this module does not touch.
