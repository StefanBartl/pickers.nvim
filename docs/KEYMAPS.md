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
[docs/COMMANDS.md](COMMANDS.md#pickers)), which works for every scope/
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
any [builtin](BUILTINS.md) by name, each with an lhs and an **optional
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

**Name resolution:**

| Name shape | Dispatches to |
|---|---|
| a [`:Pickers builtin <name>`](BUILTINS.md) name | `pickers.builtins.run(name)` |
| `<scope>_files` / `<scope>_grep` / `<scope>_smart` | `:Pickers <scope> <action>` |
| `<scope>_find_all` | `:Pickers <scope> files all` (see the escape hatch above) |

`<scope>` is any built-in scope (`cwd`/`config`/`folder`/`repos`/`wkdbooks`/
`system`/`drives`) or a user-defined collection name — `notes_lua_grep`
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

fzf-lua is the capability gap: its builtin previewer has no horizontal preview
scroll, its history is fzf's own `--history` bound to `ctrl-p`/`ctrl-n`
natively, its entry-action bindings are fixed to `ctrl-a`/`ctrl-o`/
`shift-enter` (fzf's own bind syntax, not translatable from Neovim keymap
syntax), and mouse clicks are handled by the fzf binary itself, outside
`keymap.builtin` — none of these five are remappable there. Unmappable
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
(`get_mappings()`/`get_actions()`/`get_keys()`).

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

**`preview_toggle` is opt-in** (off/unbound by default, unlike the other six)
and **telescope-only**: fzf-lua already binds toggle-preview on `<F4>`, snacks
on `<A-p>`, both natively — neither needs pickers.nvim to provide one.
Telescope ships the underlying action (`actions.layout.toggle_preview`) but
binds no key to it by default, so this fills that one gap. It IS patched
globally like preview-scroll/history (it's a plain built-in telescope action):
```lua
require("pickers").setup({
  keys = { preview_toggle = "<M-p>" },
})
```

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

`setup()` patches telescope and fzf-lua globally (`defaults.mappings` /
`keymap.builtin`), so every picker they open — pickers.nvim's own and native
builtins alike — inherits the keys. snacks cannot be self-patched (pickers.nvim
does not own `Snacks.setup()`), so merge the exported `win` table into your own
snacks setup:

```lua
require("snacks").setup({
  picker = { win = require("pickers.keys").snacks_win() },
})
```

`keys.telescope_mappings()` and `keys.fzf_keymap()` are exported too, for wiring
into your own engine `setup()` calls manually instead of relying on the patch.
