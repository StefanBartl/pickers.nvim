# Keys

Two separate surfaces, deliberately not merged: `keymaps`/`mappings` **launch**
a picker from normal mode, `keys` acts **inside** one that is already open.

## Launch keymaps

The fixed set — `cwd_files`, `cwd_grep`, `config_files`, `config_grep`,
`folder_files`, `dir_pick`, `explorer`, and the opt-in `repos_*`, `system_*`,
`*_smart`, `cwd_find_all`. Each is a named config field, so a single key is
remapped or disabled (`nil`) without touching the rest.

Most default to `nil` on purpose. A plugin that claims `<leader>ff` on install
is making a decision that belongs to the user; the ones that are bound by
default are the ones with no plausible alternative owner.

- **Module:** [`bindings/keymaps.lua`](../../lua/pickers/bindings/keymaps.lua)
- **Config:** `keymaps.*`
- **Keymaps:** see [`docs/KEYMAPS.md`](../KEYMAPS.md)

## Declarative mappings

One flat table listing every picker action by name, each with an lhs and an
optional per-entry `engine`. It does **not** supersede the fixed `keymaps.*`
fields — it is the surface for "this one key should always use telescope even
though my default is snacks", which the named fields cannot express.

- **Module:** [`mappings/init.lua`](../../lua/pickers/mappings/init.lua)
- **Config:** `mappings`

## which-key labels

Group labels for the prefixes this plugin occupies, registered when
which-key.nvim is installed and skipped silently otherwise. No hard dependency.

- **Module:** [`bindings/whichkey.lua`](../../lua/pickers/bindings/whichkey.lua)

## In-picker keys

The part that costs the most and shows the least: preview scrolling, history
navigation and the entry actions are defined **once** and translated per
engine, so the same key does the same thing on telescope, fzf-lua and snacks.

Thirteen actions, covering preview scroll (four directions), history back and
forward, `create_file`, `open_background`, `preview_toggle`, `split`, `vsplit`,
`tab`, and `mouse_confirm`.

**fzf-lua is the capability gap, and it is a real one.** Its builtin previewer
has no horizontal preview scroll; its history is fzf's own `--history` bound to
`ctrl-p`/`ctrl-n` natively; its entry-action bindings are fixed to
`ctrl-a`/`ctrl-o`/`shift-enter` in fzf's own bind syntax, which is not
translatable from Neovim keymap notation; and mouse clicks are handled by the
fzf binary itself, outside `keymap.builtin`. Those five are not remappable
there. Unmappable actions are skipped and reported once through `notify.debug`,
or surfaced in `:checkhealth pickers` where the gap is static.

- **Module:** [`keys/`](../../lua/pickers/keys/)
- **Config:** `keys.*`
- **Reference:** the per-engine table in
  [`docs/KEYMAPS.md`](../KEYMAPS.md#in-picker-keys-preview-scroll--history)

### Mouse confirm

A double-click opens the entry, same as `<CR>`. Telescope has no default mouse
mapping at all, which is the actual gap this closes there — patched into
`mappings.n` for the results window only, since a click always focuses that
buffer first and it is never in insert mode. Snacks already ships it; it is
translated there anyway so a custom lhs or `false` in the user's own config is
still honoured.

- **Config:** `keys.mouse_confirm` (default `<2-LeftMouse>`)

### Create file from the picker

Prompt for a name, create the file or folder, open it — driven from inside the
picker with the current entry's path as the starting point. The shared core
does notify + prompt + create; the per-engine parts (extracting the entry path,
closing or deferring the picker) live in sibling adapter modules, so the core
never learns which engine it is running under.

- **Module:** [`entry_actions/create_file.lua`](../../lua/pickers/entry_actions/create_file.lua),
  adapters in `entry_actions/{extract,adapters}/`
- **Config:** `keys.create_file` (default `<C-a>`)

### Open in the background

Loads the selected entry without moving focus — `bufadd` + `bufload`, no
window, no focus change. Opt-in, `keys.open_background_show = true`
additionally points the window *behind* the picker at the entry and its line
where the engine exposes one, still without moving keyboard focus.

- **Module:** [`entry_actions/open_background.lua`](../../lua/pickers/entry_actions/open_background.lua)
- **Config:** `keys.open_background` (default `<S-CR>`, `<C-o>`),
  `keys.open_background_show` (default `false`)

### Split, vsplit, tab

Open the entry in a horizontal split, vertical split or new tab. All three
engines ship the underlying primitive already, so this is pure
translation-table wiring with no logic of its own — the point is a consistent
lhs (`<C-s>`/`<C-v>`/`<C-t>`) across engines rather than three different ones.

- **Config:** `keys.split`, `keys.vsplit`, `keys.tab`
