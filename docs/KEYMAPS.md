# Keymaps

All keymaps are registered in `lua/pickers/bindings/` (see also
[docs/BINDINGS.md](BINDINGS.md) for the full machine-readable reference).
They mirror the keymaps from the original individual modules exactly:

| Keymap | Action | Was |
|---|---|---|
| `<leader>dp` | `:Pickers dir` — navigation picker | `custom.dir_picker` |
| `<leader>fb` | `:Pickers folder files` — pick folder | `custom.find_in_folder` |
| `<leader>fc` | `:Pickers config files` — find in config | `custom.find_config` |
| `<leader>gc` | `:Pickers config grep` — grep in config | `custom.find_config` |
| `<leader>li` | `:Pickers cwd grep` — live grep | `custom.grep` |

Disable all keymaps:
```lua
require("pickers").setup({ keymaps = { enable = false } })
```

Change a keymap:
```lua
require("pickers").setup({ keymaps = { cwd_grep = "<leader>sg" } })
```

All keymaps carry a `desc` and are labelled through [which-key](https://github.com/folke/which-key.nvim)
automatically when it is installed — no configuration required, and no hard
dependency if it is not.

## In-picker keys (preview scroll + history)

Separate from the normal-mode keymaps above, `keys` controls the bindings that
act **inside** an open picker. They are defined once and translated per engine,
so preview scrolling and history navigation behave the same on telescope,
fzf-lua and snacks. See `lua/pickers/keys/`.

| Action | Default | telescope | fzf-lua | snacks |
|---|---|---|---|---|
| `preview_scroll_down` | `<PageDown>` | ✓ | ✓ | ✓ |
| `preview_scroll_up` | `<PageUp>` | ✓ | ✓ | ✓ |
| `preview_scroll_left` | `<C-Left>` | ✓ | — | ✓ |
| `preview_scroll_right` | `<C-Right>` | ✓ | — | ✓ |
| `history_back` | `<C-p>` | ✓ | — | ✓ |
| `history_forward` | `<C-n>` | ✓ | — | ✓ |

fzf-lua is the capability gap: its builtin previewer has no horizontal preview
scroll, and its history is fzf's own `--history` bound to `ctrl-p`/`ctrl-n`
natively (not remappable here). Unmappable actions are skipped and reported once
via `notify.debug`.

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
