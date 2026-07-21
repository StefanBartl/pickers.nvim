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
