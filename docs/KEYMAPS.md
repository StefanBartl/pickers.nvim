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
| _(disabled)_ `cwd_files` | `:Pickers cwd files` — find files in CWD | — |
| _(disabled)_ `repos_files` | `:Pickers repos files` — pick a repo, then find files | — |
| _(disabled)_ `repos_grep` | `:Pickers repos grep` — pick a repo, then live grep | — |
| _(disabled)_ `system_files` | `:Pickers system files` — systemwide fd search (prompts) | — |

`cwd_files`, `repos_files`, `repos_grep`, and `system_files` are opt-in
(`nil` by default) — set a `keymaps.<name>` value to enable one:
```lua
require("pickers").setup({
  keymaps = { repos_files = "<leader>rf", repos_grep = "<leader>rg" },
})
```

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

fzf-lua is the capability gap: its builtin previewer has no horizontal preview
scroll, its history is fzf's own `--history` bound to `ctrl-p`/`ctrl-n`
natively, and its entry-action bindings are fixed to `ctrl-a`/`ctrl-o`/
`shift-enter` (fzf's own bind syntax, not translatable from Neovim keymap
syntax) — none of these four are remappable there. Unmappable actions are
skipped and reported once via `notify.debug` (or surfaced in `:checkhealth
pickers` for the static, always-true gaps).

**`create_file`/`open_background` are not patched globally** like the other
actions — they run pickers.nvim-specific logic (`lua/pickers/entry_actions/`),
not a built-in engine action, so you still merge them into your own engine
`setup()` manually. See `lua/pickers/entry_actions/README.md` for the adapters
(`get_mappings()`/`get_actions()`/`get_keys()`).

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
