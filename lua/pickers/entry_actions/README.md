# `pickers.entry_actions`

In-picker "create file/folder" and "open in background" actions, shared
across telescope.nvim, fzf-lua, and snacks.nvim — the picker-specific
counterpart to `pickers.engines.*` (which handles *finding* files, not
keybindings inside an already-open results list).

Not part of `pickers.actions` (that's the `:Pickers` command's scope-dispatch
layer — `dir`/`files`/`grep` — a different concern).

## Structure

```
create_file.lua          Engine-agnostic: notify + vim.ui.input + lib.nvim.fs.create_entry
open_background.lua      Engine-agnostic: notify + lib.nvim.buffer.open_background
extract/
  telescope.lua           entry -> path
  fzf.lua                 selected -> path (ANSI/icon-strip included)
  snacks.lua               item -> path (prefers Snacks.picker.util.path())
adapters/
  telescope.lua            get_mappings() -> {i={...}, n={...}}
  fzf.lua                  get_actions()  -> {["ctrl-a"]=fn, ["ctrl-o"]=fn, ["shift-enter"]=fn}
  snacks.lua                get_actions() -> {create_file=fn, open_background=fn}
                            get_keys()    -> {["<C-a>"]="create_file", ...}
```

## Usage

Each adapter is meant to be merged into the consuming plugin's own picker
setup — `pickers.nvim` does not register these itself:

```lua
-- Telescope: merge into defaults.mappings
local entry_actions = require("pickers.entry_actions.adapters.telescope")
require("telescope").setup({
  defaults = { mappings = entry_actions.get_mappings() },
})

-- fzf-lua: merge into actions
local entry_actions = require("pickers.entry_actions.adapters.fzf")
require("fzf-lua").setup({
  actions = vim.tbl_extend("force", { ["default"] = ... }, entry_actions.get_actions()),
})

-- snacks.nvim: merge both actions and keys
local entry_actions = require("pickers.entry_actions.adapters.snacks")
require("snacks").setup({
  picker = {
    actions = entry_actions.get_actions(),
    win = { list = { keys = entry_actions.get_keys() } },
  },
})
```

## Configuration

Via `require("pickers").setup({ keys = { entry_actions = { ... } } })` — part
of the unified `keys` namespace for in-picker key bindings:

```lua
keys = {
  entry_actions = {
    enable = true,
    keys = {
      create_file     = "<C-a>",
      open_background = { "<S-CR>", "<C-o>" },
    },
  },
}
```

`keys.entry_actions.keys` uses Neovim keymap syntax and is honoured by the
**telescope and snacks** adapters directly. **fzf-lua's
`ctrl-a`/`ctrl-o`/`shift-enter` bindings are fixed** — fzf-lua's action-table
keys are fzf's own bind syntax ("ctrl-a"), not Neovim keymap syntax ("<C-a>"),
and there is no general, safe way to translate one to the other — only
`keys.entry_actions.enable` is honoured by the fzf adapter.
