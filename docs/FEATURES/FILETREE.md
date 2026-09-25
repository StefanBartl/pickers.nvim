# filetree.nvim

`f` (find files) and `gr` (grep) on a node of the
[filetree.nvim](https://github.com/StefanBartl/filetree.nvim) tree, run through
this plugin — with your engine, your `find.*` flags and your entry actions.

## What it does

filetree.nvim has its own picker keys: `f` finds files under the directory of the
node under the cursor, `gr` greps there. With pickers.nvim installed it hands that
directory over instead of driving a picker of its own, so the picker that opens is
the one everything else in your setup opens: the engine you configured (telescope,
fzf-lua or snacks), the hidden/ignore/follow flags from `find`, the entry actions
(`[a`, `]a`, …), the history. `tf` and `tg` in the tree force it explicitly.

```
tree: f on lua/       → Files lua>   [your engine, your flags]
tree: gr on docs/     → Grep docs>   [live grep, your engine]
```

Nothing needs wiring on either side, and it is **on by default**.

## Picking a file reveals it in the tree

Picking a file opens it, and filetree reveals it in the tree (its `reveal_on_open`).
That needs a hook the engines did not have: `on_select(path)` is called with the
absolute path of the file that was picked, **after** the engine's own default action
opened it. It is a single-pick hook — a multi-selection (several files, or the
quickfix list) is not reported, because there is no "the" picked file.

| Engine | How it hooks in |
| --- | --- |
| telescope | `select_default` is *enhanced* (`pre` reads the entry before the picker closes, `post` reports), not replaced — multi-select and the split/tab variants stay telescope's |
| snacks | `confirm` runs snacks' own `jump` and then reports; the report is scheduled, since `jump` re-schedules itself when confirmed from insert mode |
| fzf-lua | your configured `<CR>` action (`actions.files.enter`) — or fzf-lua's `file_edit_or_qf` — is wrapped, and the entry is resolved by fzf-lua's own `entry_to_file` |

A callback that throws is reported as a notification, not raised from inside the
picker.

## Switching it off

Either end can opt out (both default to on). filetree then falls back to its own
backends: telescope, fzf-lua, mini.pick, or a built-in fallback.

```lua
require("pickers").setup({
  filetree = { enabled = false },   -- do not let filetree.nvim drive pickers.nvim
})
require("filetree").setup({
  integrations = { pickers = false },   -- and the same from filetree's side
})
```

`:checkhealth filetree` says which of the two holds. An older pickers.nvim without
`pickers.integrations.filetree` counts as absent on filetree's side.

## For other plugins

`require("pickers.integrations.filetree")` is a small public entry point — nothing
in it is specific to filetree.nvim:

```lua
local pk = require("pickers.integrations.filetree")
pk.available()                                        -- switch on and an engine installed
pk.files("/some/dir", { query = "foo", on_select = function(path) end })
pk.grep("/some/dir",  { query = "foo", extra_args = { "--glob=!*.min.js" } })
```

Both return `false` — and run nothing — when the switch is off, no engine is
installed, or `dir` is not a directory, so a caller can fall back without asking
first. A "no engine" answer is quiet: it does not raise pickers.nvim's
"no picker engine" error, since asking is the normal case for a caller that has a
fallback.

Reference: [`configuration.md`](../configuration.md#filetreenvim-integration) for
the option, [`CHANGELOG.md`](../CHANGELOG.md) for when it started.
