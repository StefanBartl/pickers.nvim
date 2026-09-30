# Keymaps

All keymaps are registered in `lua/pickers/bindings/` (see also
[docs/BINDINGS.md](BINDINGS.md) for the full machine-readable reference).
They mirror the keymaps from the original individual modules exactly:

| Keymap | Action | Was |
|---|---|---|
| `<leader>dp` | `:Pickers dir` — navigation picker; **a count is the depth** (`2<leader>dp` = two levels up) | `custom.dir_picker` |
| `<leader>.` | `:Pickers builtin explorer` — file explorer/browser (active engine) | `telescope file_browser` / `Snacks.explorer` |
| `<leader>fb` | `:Pickers folder files` — pick folder | `custom.find_in_folder` |
| `<leader>fc` | `:Pickers config files` — find in config | `custom.find_config` |
| `<leader>gc` | `:Pickers config grep` — grep in config | `custom.find_config` |
| `<leader>li` | `:Pickers cwd grep` — live grep | `custom.grep` |
| _(disabled)_ `cwd_files` | `:Pickers cwd files` — find files in CWD | — |
| _(disabled)_ `repos_files` | `:Pickers repos files` — pick a repo, then find files | — |
| _(disabled)_ `repos_grep` | `:Pickers repos grep` — pick a repo, then live grep | — |
| _(disabled)_ `system_files` | `:Pickers system files` — systemwide fd search (prompts) | — |
| _(disabled)_ `cwd_smart` | `:Pickers cwd smart` — combined grep + find in CWD | — |
| _(disabled)_ `config_smart` | `:Pickers config smart` — combined grep + find in nvim config | — |
| _(disabled)_ `folder_smart` | `:Pickers folder smart` — pick folder, then combined grep + find | — |
| _(disabled)_ `cwd_find_all` | `:Pickers cwd files all` — find files in CWD, forcing hidden+no_ignore+follow | `<leader>fa` |

`cwd_files`, `repos_files`, `repos_grep`, `system_files`, `cwd_smart`,
`config_smart`, `folder_smart`, and `cwd_find_all` are opt-in (`nil` by
default) — set a `keymaps.<name>` value to enable one:
```lua
require("pickers").setup({
  keymaps = {
    repos_files = "<leader>rf",
    repos_grep  = "<leader>rg",
    cwd_smart   = "<leader>ss", -- combined grep + find in CWD
    cwd_find_all = "<leader>fa", -- find all files in CWD (forces hidden+no_ignore+follow)
  },
})
```

`cwd_find_all` is the **"find all" escape hatch**: it force-enables
`hidden`+`no_ignore`+`follow` for this one search only, regardless of
configured `find.*` defaults — the old `<leader>fa` behaviour. It's a thin
wrapper over `:Pickers cwd files all` (see
[docs/commands.md](commands.md#pickers)), which works for every scope/
collection, not just `cwd`.

Collections can carry a `smart` key too, alongside `files`/`grep`:
```lua
require("pickers").setup({
  collections = {
    { name = "notes", dir = vim.env.REPOS_DIR .. "/Notes",
      keys = { files = "<leader>mnf", grep = "<leader>mng", smart = "<leader>mns" } },
  },
})
```

Disable all keymaps:
```lua
require("pickers").setup({ keymaps = { enable = false } })
```

## Declarative mappings (per-entry engine override)

`mappings` is a second, more flexible keymap surface alongside the fixed
`keymaps.*` fields above — one flat table listing any scope×action combo or
any [builtin](builtins.md) by name, each with an lhs and an **optional
per-entry engine override**. It does not replace `keymaps.*`; use whichever
fits — `keymaps.*` for the common cases with a stable field name, `mappings`
when you want a name-per-picker table or a per-key engine pin.

```lua
require("pickers").setup({
  mappings = {
    cwd_files    = { "<leader>ff", "telescope" }, -- always telescope
    cwd_grep     = { "<leader>gr" },               -- active/default engine
    explorer     = { "<leader>.",  "snacks" },     -- always snacks
    notes_smart  = { "<leader>ns", "fzf" },        -- "notes" collection, always fzf
  },
})
```

The lhs may be a list, and an entry may carry `desc` (the which-key text) and
`nowait`:

```lua
mappings = {
  recent         = { { "<leader>fo", "<leader>old" }, desc = "Recent files" },
  lsp_references = { "GR", nowait = true },
}
```

### Name resolution

| Name shape | Dispatches to |
|---|---|
| a [`:Pickers builtin <name>`](builtins.md) name | `pickers.builtins.run(name)` |
| `<scope>_files` / `<scope>_grep` / `<scope>_smart` | `:Pickers <scope> <action>` |
| `<scope>_find_all` | `:Pickers <scope> files all` (see the escape hatch above) |

`<scope>` is any built-in scope (`cwd`/`config`/`folder`/`repos`/`system`/
`drives`) or a user-defined collection name — `notes_lua_grep`
resolves to collection `notes_lua`, action `grep` (the LAST `_files`/
`_grep`/`_smart`/`_find_all` suffix is stripped, so scope names may contain
underscores). `dir` is **not** supported — its nav argument doesn't fit this
flat shape (same limitation as the "find all" escape hatch).

**Engine override.** The optional 2nd element pins that one entry to a
specific engine — `"telescope"` | `"fzf"` | `"snacks"` — regardless of the
configured default. An engine named but not installed **falls back to the
default engine, never a dead keymap** (reuses `pickers.engines.load()`'s own
fallback-to-auto-detect logic).

An unresolvable name or malformed entry (`{ lhs, engine? }` expected) is
skipped with a `notify.warn`, never a throw.

Change a keymap:
```lua
require("pickers").setup({ keymaps = { cwd_grep = "<leader>sg" } })
```

All keymaps carry a `desc` and are labelled through [which-key](https://github.com/folke/which-key.nvim)
automatically when it is installed — no configuration required, and no hard
dependency if it is not.

## In-picker keys (preview scroll + history + entry actions)

Separate from the normal-mode keymaps above, `keys` controls the bindings that
act **inside** an open picker — one config surface for everything in this
category. They are defined once and translated per engine, so preview
scrolling and history navigation behave the same on telescope, fzf-lua and
snacks. See `lua/pickers/keys/`.

| Action | Default | telescope | fzf-lua | snacks |
|---|---|---|---|---|
| `preview_scroll_down` | `<PageDown>` | ✓ | ✓ | ✓ |
| `preview_scroll_up` | `<PageUp>` | ✓ | ✓ | ✓ |
| `preview_scroll_left` | `<C-Left>` | ✓ | — | ✓ |
| `preview_scroll_right` | `<C-Right>` | ✓ | — | ✓ |
| `history_back` | `<C-p>` | ✓ | — | ✓ |
| `history_forward` | `<C-n>` | ✓ | — | ✓ |
| `create_file` | `<C-a>` | ✓ | fixed (`ctrl-a`) | ✓ |
| `open_background` | `<S-CR>`, `<C-o>` | ✓ | fixed (`ctrl-o`/`shift-enter`) | ✓ |
| `preview_toggle` | _(off, opt-in)_ | ✓ | native (`<F4>`) | native (`<A-p>`) |
| `split` | `<C-s>` | ✓ | native (`ctrl-s`) | ✓ |
| `vsplit` | `<C-v>` | ✓ | native (`ctrl-v`) | ✓ |
| `tab` | `<C-t>` | ✓ | native (`ctrl-t`) | ✓ |
| `mouse_confirm` | `<2-LeftMouse>` | ✓ | native (fzf's own mouse handling) | native + patched |
| `cheatsheet` | `<C-/>`, `<M-?>` | ✓ | fixed (`f1`) | ✓ |
| `copy_absolute` | `<C-y>` · `[a`, `[f` | ✓ | fixed (`ctrl-y`) | ✓ |
| `copy_dirname` | `<M-y>` · `]a` | ✓ | fixed (`alt-y`) | ✓ |
| `copy_env_rooted` | `<M-v>` · `[e` | ✓ | fixed (`alt-v`) | ✓ |
| `copy_project_root` | `<M-t>` · `[R` | ✓ | fixed (`alt-t`) | ✓ |
| `copy_project_relative` | `<M-e>` · `]R` | ✓ | fixed (`alt-e`) | ✓ |
| `copy_buffer_relative` | `<M-j>` · `]b` | ✓ | fixed (`alt-j`) | ✓ |
| `markdown_link` | `<M-l>` · `ML`, `MM` | ✓ | fixed (`alt-l`) | ✓ |
| `markdown_link_insert` | `<M-n>` · `MI` | ✓ | fixed (`alt-n`) | ✓ |
| `open_system` | `<M-o>` · `<leader>sm` | ✓ | fixed (`alt-o`) | ✓ |
| `reveal_in_manager` | `<M-x>` · `<leader>fm` | ✓ | fixed (`alt-x`) | ✓ |

For the path/system actions the first lhs is a **direct key** (Ctrl/Alt — works
in the prompt, insert *and* normal mode); everything after the `·` is a
**chord** taken from filetree.nvim, bound in normal mode only (see below).

fzf-lua is the capability gap: its builtin previewer has no horizontal preview
scroll, its history is fzf's own `--history` bound to `ctrl-p`/`ctrl-n`
natively, its entry-action bindings are fixed to `ctrl-a`/`ctrl-o`/
`shift-enter`/`f1` (fzf's own bind syntax, not translatable from Neovim keymap
syntax), and mouse clicks are handled by the fzf binary itself, outside
`keymap.builtin` — none of these are remappable there. Unmappable
actions are skipped and reported once via `notify.debug` (or surfaced in
`:checkhealth pickers` for the static, always-true gaps).

**`mouse_confirm`** double-clicks a result open, same as `<CR>`. Telescope has
no default mouse mapping at all — this is the actual gap it closes there
(`actions.select_default`, patched into `mappings.n`, results-window/normal
mode only — a click always focuses that buffer first, which is never in
insert mode). Snacks already ships `<2-LeftMouse>` = `"confirm"` as its own
default; it's translated here too so a custom lhs or `false` (unbind) in your
own config is still honored by `keys.snacks_win()`.

**`split`/`vsplit`/`tab`** open the selected entry in a horizontal/vertical
split or a new tab instead of the current window. All three engines already
ship the underlying primitive natively (telescope
`actions.select_horizontal`/`select_vertical`/`select_tab`, snacks
`actions.split`/`vsplit`/`tab`, fzf-lua's fixed `ctrl-s`/`ctrl-v`/`ctrl-t`), so
— like `preview_toggle` on fzf-lua/snacks — this is pure translation-table
wiring, no pickers.nvim-side logic. They default to `<C-s>`/`<C-v>`/`<C-t>`
(matching the pre-pickers.nvim fzf-lua config) for a consistent lhs across
engines; fzf-lua's keys are fixed/unremappable and simply left unpatched
there (not a capability gap — fzf already ships them).

**`create_file`/`open_background` are not patched globally** like the other
actions — they run pickers.nvim-specific logic (`lua/pickers/entry_actions/`),
not a built-in engine action, so you still merge them into your own engine
`setup()` manually. See `lua/pickers/entry_actions/README.md` for the adapters
(`get_mappings()` on telescope; `get_actions()` on fzf-lua; `get_actions()` +
`get_keys()` + `get_input_keys()` on snacks).

**`open_background` only preloads by default** — `bufadd`+`bufload`, no
window, no focus change, matching the old per-engine behaviour exactly.
Setting `keys.open_background_show = true` additionally points the window
*behind* the picker at the selected entry (and its line, where the engine
exposes one) — without ever moving keyboard focus there; focus always stays
in the picker's prompt/results list. This is opt-in and off by default. All
three engines support it: telescope via the picker's `original_win_id`,
snacks via `picker.main`, fzf-lua via its cached invocation context
(`fzf-lua.utils.__CTX().winid`) — fzf-lua is best-effort and doesn't position
the cursor to a specific line (would require parsing the raw grep-formatted
entry).

```lua
require("pickers").setup({
  keys = { open_background_show = true },
})
```

**`preview_toggle` is opt-in** (off/unbound by default, unlike the other
in-picker actions) and **telescope-only**: fzf-lua already binds toggle-preview
on `<F4>`, snacks on `<A-p>`, both natively — neither needs pickers.nvim to
provide one.
Telescope ships the underlying action (`actions.layout.toggle_preview`) but
binds no key to it by default, so this fills that one gap. It IS patched
globally like preview-scroll/history (it's a plain built-in telescope action):
```lua
require("pickers").setup({
  keys = { preview_toggle = "<M-p>" },
})
```

**`cheatsheet`** opens a read-only panel listing every currently-bound key
from this table, grouped, with the two keys worth knowing first — the
cheatsheet itself and `open_background` (`<S-CR>`, "add to the buffer list, no
focus switch") — under "Essentials". Source-of-truth is
`pickers.keys.resolve()`, so a remapped or unbound key shows up as what it
actually is. Default `<C-/>` and `<M-?>` — **not** `<C-?>`: every picker prompt
starts in insert mode, where a raw `?` just searches for a literal question
mark, and Neovim resolves `<C-?>` to the same byte (`0x7F`/`DEL`) that
Backspace sends in many terminals, so binding it would open the cheatsheet on
every backspace instead. `<M-?>` (Alt-Shift-/) has no such problem. Like
`create_file`/`open_background`, this runs pickers.nvim-specific logic
(`pickers.cheatsheet`), so it is patched into the engine the same
way as the other entry actions — see `lua/pickers/entry_actions/README.md`. fzf-lua's binding is fixed to
`f1`, same class as its `ctrl-a`/`ctrl-o`/`shift-enter`.

Those two keys are also the **legend**, visible without pressing anything:
telescope's `results_title`, fzf-lua's `--header` and the snacks picker
`title` show "`<C-/> cheatsheet, <S-CR> add to buffers`" (fzf-lua:
"`f1 cheatsheet, shift-enter add to buffers`") as soon as a picker opens. Each
half drops out when its action is unbound. On snacks the legend is appended to
the title, next to the live `{flags}` toggle badges (see
[FEATURES/KEYS.md#cheatsheet](FEATURES/KEYS.md#cheatsheet) for what those badges
actually are, e.g. the "f"/"h" you may have seen in a `cwd files` picker's
title — that's `follow`/`hidden` being on by default, not a typed query).
Snacks' own **native** keymap help is still on `?` in the picker's input or
list window (normal mode).

**Path copy and system actions** —
`copy_absolute`/`copy_dirname`/`copy_env_rooted`/`copy_project_root`/
`copy_project_relative`/`copy_buffer_relative`/`markdown_link` and
`open_system`/`reveal_in_manager` — are the curated subset of filetree.nvim's
path-copy, markdown-link and system features that still make sense on a
picker result row (a plain path string, not a `FiletreeNode`):

| Action | Copies | filetree chord |
|---|---|---|
| `copy_absolute` | `/repo/src/a.lua` (several selected → one line each, i.e. the file list) | `[a`, `[f` |
| `copy_dirname` | `/repo/src` | `]a` |
| `copy_env_rooted` | `$REPOS_DIR/repo/src/a.lua` | `[e` |
| `copy_project_root` | `/repo` (nearest `.git` ancestor, else the cwd) | `[R` |
| `copy_project_relative` | `src/a.lua` | `]R` |
| `copy_buffer_relative` | `./a.lua` / `../src/a.lua` — relative to the buffer *behind* the picker | `]b` |
| `markdown_link` | `[a.lua](src/a.lua)` | `ML`, `MM` |
| `markdown_link_insert` | inserts `[a.lua](../src/a.lua)` (relative to the buffer behind the picker) and closes the picker — cursor into the link, insert mode | `MI` |
| `open_system` | opens the entry with the OS default application | `<leader>sm` |
| `reveal_in_manager` | shows the entry in Explorer/Finder/… | `<leader>fm` |

filetree.nvim's "marks if any, else the node under the cursor" idiom maps onto
the picker's own multi-selection: press `<Tab>` to select entries and every
copy action then takes **all** of them (one line each — that is `[f` and
`MM`), otherwise just the current entry. The system actions use the current
entry only. Every copy writes to both the `"+"` and unnamed `"` registers and
does **not** close the picker (fzf-lua's action table has to close+resume
regardless, approximating the same effect). Deliberately not ported: trash,
and the recursive Markdown-link variant (`MR` — a result row is one file, not a
directory subtree). filetree.nvim's `gb` ("add to buffer list") is not
duplicated either — `open_background` above already is that action here.

**Why direct keys *and* chords.** A picker prompt is always in insert mode,
where `[`, `a`, `M`, `L` are just characters of the query — filetree.nvim's
chords can never fire there. So each action carries a direct Ctrl/Alt key
(bound in insert *and* normal mode, so it works while typing) plus the
filetree chord, which is bound in **normal mode only** so it never swallows
typed characters (`<Esc>` in the prompt to get there). The rule is per lhs:
a single non-printing key press (`<C-y>`, `<M-l>`, `<S-CR>`) is direct;
anything else (`[a`, `ML`, `<leader>sm`, `<Space>`) is a chord. On snacks
normal mode means both the list window's *and* the input window's own normal
mode; telescope only needs the latter since it has a single prompt buffer
whose normal mode already covers both (`mappings.n`). fzf-lua's own `--bind`
syntax has no concept of a multi-keystroke chord (it binds a single logical
key, not a pending-key state machine), so its bindings are fixed to the same
single physical keys the direct lhs resolve to (`ctrl-y`/`alt-y`/`alt-v`/
`alt-t`/`alt-e`/`alt-j`/`alt-l`/`alt-o`/`alt-x`) — same class as its
`ctrl-a`/`ctrl-o`/`shift-enter`/`f1`. The Alt keys are chosen to stay clear of
the engines' own defaults (snacks `<A-d>`/`<A-f>`/`<A-h>`/`<A-i>`/`<A-m>`/
`<A-p>`/`<A-r>`/`<A-w>`, fzf-lua `alt-a`/`alt-g`/`alt-q`/`alt-i`/`alt-h`/`alt-f`,
fzf's `alt-b`/`alt-f`/`alt-d`; a test in `TESTS/` guards this). See
[`lua/pickers/entry_actions/README.md`](../lua/pickers/entry_actions/README.md#path-copy-and-system-actions)
for the `$REPOS_DIR` fallback rules for `copy_env_rooted`.

Each action takes a single lhs, a list of lhs, or `false` to unbind it:
```lua
require("pickers").setup({
  keys = {
    preview_scroll_down = { "<PageDown>", "<C-d>" },  -- two bindings
    history_back        = false,                       -- unbind
  },
})
```

Disable the whole layer:
```lua
require("pickers").setup({ keys = { enable = false } })
```

### Installation across engines

`setup()` patches telescope, fzf-lua and snacks globally (`defaults.mappings` /
`keymap.builtin` / `Snacks.config.picker`), so every picker they open —
pickers.nvim's own and native builtins alike — inherits the keys and the entry
actions (`create_file`, `open_background`, cheatsheet, path copy). Each engine is
patched once it is loaded, and a key or action you already bound is never
overwritten. pickers.nvim does not own `Snacks.setup()`, but snacks reads
`Snacks.config.picker` each time a picker opens, so patching it works before or
after your own setup.

`keys.snacks_win()`, `keys.telescope_mappings()` and `keys.fzf_keymap()` (and the
entry-action adapters' `get_*()`) stay exported, for wiring into your own engine
`setup()` calls manually instead of relying on the patch.
