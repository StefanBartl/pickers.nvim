# Quickfix

The one picker every engine leaves alone is the one Neovim already ships:
`:copen`. `pickers.quickfix` keeps it — no picker replaces the list, no engine
is involved — and adds the two things a quickfix or location window is
missing. The idea is nvim-bqf's; the parts are this plugin's.

## Preview

While the cursor sits on an entry, a float above the list shows the target
file around the entry's line, that line highlighted, with the file's own
filetype for syntax and the file's own line numbers in the gutter. It follows
`CursorMoved` (debounced, `quickfix.preview.delay_ms`) and disappears when
the list window loses focus or closes. Loaded buffers are read directly;
unloaded files are read from disk up to the needed line, so a thousand-entry
`:grep` list does not load a thousand buffers.

`p` toggles the preview for the session.

## Filter

`zf` opens [`pickers.refine`](REFINE.md)'s prompt over the list's entries,
with the fields `path` and `text`. The list is replaced by the entries the
stack keeps and its title shows the stack — `Grep — text~TODO (12/340)` —
so the same filter grammar that `<C-f>` runs inside a picker runs over the
quickfix list. Filtering is non-destructive: the full list is remembered per
quickfix buffer the first time a clause is added, every later clause filters
*that*, and `zF` puts it back.

bqf's fzf mode is not reproduced. `pickers.refine` is the filter grammar of
this plugin; a fuzzy pass over a quickfix list is what the engines' own
`quickfix` builtin (`:Pickers builtin quickfix`) is for.

## Scope

Everything is buffer-local to the quickfix buffer, installed from a
`FileType qf` autocmd (`pickers.nvim.quickfix`), and applies to location
lists too. `quickfix.enabled = false` switches the whole feature off; each
key can be set to `false` on its own.

- **Module:** [`quickfix/init.lua`](../../lua/pickers/quickfix/init.lua)
  (`preview`, `toggle_preview`, `filter`, `apply`, `restore`, `attach`)
- **Config:** `quickfix.enabled`, `quickfix.preview.{enabled,height,context,border,delay_ms}`,
  `quickfix.keys.{filter,restore,toggle_preview}` — see
  [configuration.md](../configuration.md#quickfix)
- **Keys (in the list):** `zf` refine · `zF` restore · `p` preview on/off
