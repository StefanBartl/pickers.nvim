# Workflow — getting real use out of pickers.nvim day to day

Every feature here is documented on its own elsewhere ([commands.md](commands.md),
[configuration.md](configuration.md), [keymaps.md](keymaps.md),
[collections.md](collections.md), [builtins.md](builtins.md)). This is the
different question: once several of them exist at once, *how do they actually
combine* into something worth reaching for daily, rather than something you
configured once and mostly forgot.

## 1. Picking an entry point without thinking about it

Four ways to start a search, in the order you'll actually reach for them:

- **A bound keymap** (`<leader>li` for cwd grep, `<leader>fc`/`<leader>gc` for
  config, `<leader>.` for the explorer) — fastest, zero prompts, but only
  covers what you or the defaults bound.
- **`:Pickers <scope> <action>`** — when you know exactly what you want and
  it's not bound. `:Pickers notes grep`, `:Pickers dir git files`.
- **`:Pickers` with no args** — the scope picker, when you can't remember
  whether something is a built-in scope or a collection. Cheaper than
  checking docs; `:PickersScopes` gives you the same list as plain text if
  you just want to read it rather than pick from it.
- **`:PickersRepeat` / `:PickersResume`** — once a session is warmed up,
  these two beat re-typing the scope. They are *not* interchangeable:
  `:PickersRepeat` replays pickers.nvim's own last resolved
  {scope, root, action} from an empty prompt (useful after you dismissed a
  picker by accident, or want the same search with a fresh query);
  `:PickersResume` reopens the engine's own last picker session, prompt text
  and all (useful mid-search, after you fat-fingered `<Esc>`). They do not
  even share a code path: `:PickersRepeat` replays through
  `pickers.command.dispatch`, the one choke point every fully resolved
  `:Pickers` action passes — so anything that goes through a scope or
  collection is `:PickersRepeat`-able, `dir` included — while
  `:PickersResume` hands straight to the engine's own resume picker and knows
  nothing about scopes at all.

`:PickersResume` is a thin wrapper over `:Pickers builtin resume`, which is
fzf-lua's one real gap in the [builtin registry](builtins.md#notes-on-specific-gaps) —
on fzf-lua it's a `notify.warn` no-op, not silently broken.

## 2. `files`/`grep` vs `smart`: pick the action, not just the scope

`smart` isn't a fourth thing to remember separately from files/grep — it's
what you reach for the moment you're not sure whether what you're looking for
is a *filename* or a *line of content*. `:Pickers cwd smart` runs `rg` and
`fd` for the same live query and merges them into one ranked list instead of
making you commit up front to "this is a find" or "this is a grep":

- Typing a symbol or an error string → the grep half surfaces it, ranked
  by `smart.weights.content`.
- Typing part of a filename → the fd half surfaces it, ranked by
  `smart.weights.filename`.
- A file that matches *both* (the filename contains your query **and** the
  file's content does too) floats to the top via the flat `smart.weights.both`
  bonus (default `25`) — this is the case `smart` earns its keep over
  running `files` then `grep` separately, since neither one alone would show
  you that it's a double hit.

Cost you pay for that convenience: two subprocess calls per keystroke instead
of one (bounded by `smart.timeout`, default 3000ms each), and a `limit`
(default 2000) on the merged list — lower it on huge trees if typing starts
to feel laggy. On fzf-lua specifically, `smart` needs fzf ≥ 0.45 (Lua-function
live mode); fall back to telescope/snacks on older fzf rather than fighting it.

**Reach for plain `files`/`grep` instead of `smart` when:** you already know
which half you want (e.g. you're grepping a symbol you know isn't a
filename) — `smart`'s dual subprocess cost buys you nothing there, and a
lone `grep`/`files` picker is one process instead of two.

`smart.dedup_grep_rows = true` is worth turning on the moment a file with
many matching lines starts pushing everything else off-screen in the merged
list — it collapses that file's grep hits down to its single best-scoring
line. It's a display-density choice, not a re-score: the file's other match
lines are simply dropped from the list, not folded into the kept row.

## 3. Frecency and history are two different signals — don't conflate them

Both are opt-in and both are about "things I did before," but they answer
different questions and don't share any code path:

| | `smart.frecency` | `history` |
|---|---|---|
| Scores | individual **files**, by open-frequency + recency | entire **picker sessions** (prompt text + which picker) |
| Feeds into | `smart`'s per-file ranking only | the engine's native history navigation (`history_back`/`history_forward`, or fzf's `ctrl-p`/`ctrl-n`) |
| Applies to | only the `smart` action | any picker, `smart` included, but as a separate "reopen a past query" mechanism |
| Storage | `stdpath("data")/pickers.nvim/frecency.json` | `stdpath("data")/pickers.nvim/history/*` |
| Per-engine behaviour | identical on all three (pure scorer, `lua/pickers/smart/frecency.lua`) | telescope: global singleton, ignores `fzf_scope`; fzf-lua: `fzf_scope` controls per-provider vs. shared file; snacks: config has **no effect**, snacks always has its own built-in history regardless |

In practice: turn on `smart.frecency` if you want files you touch a lot to
naturally rank higher in `smart` results without you doing anything. Turn on
`history` separately if you want `<C-p>`/`<C-n>` inside a picker to walk back
through previous *prompts* you typed. They compose fine together — a
frecency-boosted file ranking and a query-history you can scroll through are
solving unrelated problems — but enabling one does not get you the other,
and neither retroactively improves engine-native behavior you haven't
enabled (snacks history is always on regardless of what you set here; it
just isn't *this* history).

## 4. File explorer vs. a files/find picker

`<leader>.` (`:Pickers builtin explorer`) and `:Pickers cwd files` overlap in
what they can ultimately get you to (a file), but solve different tasks:

- **Explorer**: you don't know the filename, only roughly *where* — you want
  to walk a tree, see directory structure, maybe create/rename/delete along
  the way. snacks gives you a real native tree picker; telescope gets you
  there via the separate `telescope-file-browser.nvim` extension (loaded on
  demand — install it, or you'll get a warning instead of a picker); fzf-lua
  has no explorer at all — use its file picker's own parent-dir navigation
  as the substitute.
- **files/find**: you know roughly what the filename looks like, or can
  fuzzy-type toward it — you want fuzzy match speed, not tree structure.

The explorer is engine-availability-dependent in a way files/grep never are
(files/grep work identically on all three engines). If you're on fzf-lua as
your primary engine, don't wire a keymap expecting the explorer to work —
either accept the gap or use `mappings` (see §6) to pin just that one entry
to telescope or snacks while everything else stays on fzf-lua.

## 5. The builtin registry: three engines, one name each

`:Pickers builtin <name>` is a flat namespace covering
git/LSP/help/vim-intrinsics/diagnostics/GitHub/etc — deliberately *not*
scope×action, so it bypasses pickers.nvim's own roots/find-flags resolution
entirely and just calls straight into the engine's native function.

Three gotchas worth internalizing before you reach for it reflexively:

- **Naming is per-registry-entry, not per-engine-function.** The three
  engines frequently disagree on what they call the same thing
  (`recent` → snacks `recent` / telescope `oldfiles` / fzf-lua `oldfiles`;
  `man` → snacks `man` / telescope `man_pages` / fzf-lua `manpages`). The
  registry name is the stable one you type and bind — you never need to
  remember the underlying per-engine function name, that's the entire point
  of going through `builtin` instead of calling `Snacks.picker.recent()`
  yourself.
- **Discovery is tab-completion, not memorization.** `:Pickers builtin <Tab>`
  cycles the full registry. Given the number of entries, across categories you
  don't use daily (GitHub issues/PRs, LSP declarations, lazy.nvim specs), tab-complete
  first, don't guess a name and get a "not found."
- **Empty cells are real, not bugs.** `git_diff`/`lsp_declarations` have no
  telescope picker; `gh_issue`/`gh_pr`/`projects`/`git_log_line`/
  `notifications`/`icons`/`lazy_specs` are snacks-only; `resume` doesn't
  exist on fzf-lua; `undo` doesn't exist on telescope. `:Pickers builtin`
  warns you which engines *do* support a name when you hit a gap on your
  current one — read the warning rather than assuming you mistyped. Full
  matrix: [builtins.md](builtins.md).

If you only use two or three of them regularly, that's the case for
`mappings` (next section) over trying to keymap the whole registry.

## 6. Composing `mappings` with per-collection `find` overrides

These two features live in unrelated config surfaces (`mappings` is
top-level; `find` overrides live per-`collections[]` entry) but they compose
naturally once you have more than one or two collections with different
`find` needs.

Say you keep a `vendored` collection with `find = { no_ignore = true,
exclude = { "*.lock" } }` (see [collections.md](collections.md#find-override))
because you actually want `.gitignore`d vendor files listed. You can then
give it its own binding *and* pin the engine, independent of your global
default:

```lua
require("pickers").setup({
  collections = {
    { name = "vendored", dir = "/home/user/vendor",
      find = { no_ignore = true, exclude = { "*.lock" } } },
  },
  mappings = {
    vendored_files = { "<leader>vf", "telescope" }, -- always telescope, always the override find opts
  },
})
```

The `find` override and the engine pin are fully independent axes — the
override applies no matter which engine ends up running the search (it's
resolved in `pickers.actions.files`, above the engine layer), and the engine
pin applies no matter what `find` opts are in play. Nothing about them
conflicts, but you do need to set both if you want both — enabling one does
not imply the other.

**The shared blind spot**: `dir` scope supports neither. It has no
per-collection `find` override surface (built-in scopes are global-only —
see [CHANGELOG.md](CHANGELOG.md)) and `mappings` explicitly doesn't resolve
`dir_*` names (its nav argument doesn't fit the flat `<scope>_<action>`
shape). If you find yourself wanting a bound, engine-pinned, custom-`find`
search on an ad hoc directory, `dir` is the one scope that won't get you
there — reach for a collection instead, even a throwaway one.

## 7. Collections as your actual daily namespace

Built-in scopes (`cwd`/`config`/`folder`/`system`/`drives`) cover the
generic cases; collections are where the plugin becomes *yours*. Once you
have a few defined, the daily pattern is almost never `:Pickers <name>
<action>` typed out — it's the auto-generated PascalCase compat commands
(`:NotesFiles`, `:NotesLuaGrep`, `:NotesLuaSmart`) or a bound `keys.files` /
`keys.grep` / `keys.smart`, because those are what tab-completes fastest and
what you'd actually bind a key to.

The `prefix` field is what turns one collection definition into a
picker-of-pickers: `prefix = "wkdbook-"` (or `prefix = ""` for "every
immediate subdir") means the collection scope itself opens a subdir picker
first, *then* runs files/grep/smart inside whatever you picked — one
collection definition covering an unbounded number of actual directories,
rather than one entry per repo.

## 8. Traps worth knowing before you hit them

| Trap | What actually happens | Where documented |
|---|---|---|
| Enabling `history` expecting it to affect snacks | No-op for snacks — snacks' picker history is unconditional and built-in, `history.*` config simply doesn't reach it | [configuration.md](configuration.md#history) |
| Setting `history.fzf_scope` expecting it to affect telescope | No-op for telescope — telescope's history is one process-wide singleton, no per-call scope knob exists | [configuration.md](configuration.md#history) |
| `:Pickers <scope> files all` on `grep`/`smart` | Silently ignored — live grep already searches `--hidden --no-ignore-vcs` unconditionally, so "find all" has nothing to force there | [commands.md](commands.md#pickers) |
| Passing `selected_index` / `experimental.selected_index` to `setup()` | Silently ignored with a one-time warning — this overlay was built, found unreliable, and fully removed (code, config surface, docs, tests) | [CHANGELOG.md](CHANGELOG.md) |
| Expecting `mappings` to bind a `dir` nav | Not supported — `dir`'s nav argument doesn't fit the flat `<scope>_<action>` name shape `mappings` resolves against | [keymaps.md](keymaps.md#declarative-mappings-per-entry-engine-override) |
| Naming a `mappings` entry with an engine that isn't installed | Falls back to your configured default engine — never becomes a dead keymap | [keymaps.md](keymaps.md#declarative-mappings-per-entry-engine-override) |
| Assuming `result_count` shows up on fzf-lua/snacks | Telescope-only; the other two already show a native position/total counter, so it's skipped there, not broken | [configuration.md](configuration.md#result-count) |
| Expecting `create_file`/`open_background` to "just work" like the other `keys.*` | They're pickers.nvim-specific logic, not a patched built-in engine action — still require merging the exported adapters into your own engine `setup()` manually | [keymaps.md](keymaps.md#in-picker-keys-preview-scroll--history--entry-actions) |
| Running `smart` on fzf-lua with an old fzf binary | Needs fzf ≥ 0.45 for Lua-function live mode — use telescope or snacks instead of debugging a "broken" smart action | [commands.md](commands.md#the-smart-action) |

## 9. When something feels wrong: `:checkhealth pickers`

Before assuming a bug, `:checkhealth pickers` covers dependencies, engine
detection, CLI tools (`rg`/`fd`), configuration, image previews, collections
and the declared external tools in one
pass — including the exact "config has no effect for this engine" cases from
§8 (e.g. it says outright that `history.*` doesn't apply under snacks, rather
than leaving you to rediscover that from behavior). Cheaper than re-reading
five docs files when a picker just isn't doing what the config says it
should.
