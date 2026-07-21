# `pickers.preview_toggle`

Telescope-only, opt-in. **fzf-lua ships a preview-toggle keymap natively on
`<F4>`, snacks.nvim on `<A-p>`** — neither needs pickers.nvim to provide
one. Telescope ships the underlying action
(`telescope.actions.layout.toggle_preview`) but binds no key to it by
default, so this fills that one gap.

Same model as `pickers.entry_actions`: pickers.nvim builds the mapping
table, you merge it into your own `telescope.setup()` — it isn't registered
automatically.

## Usage

```lua
local preview_toggle = require("pickers.preview_toggle")
require("telescope").setup({
  defaults = { mappings = preview_toggle.get_mappings() },
})
```

Combining with `pickers.entry_actions`' telescope adapter (both return
`{i={...}, n={...}}` tables — merge with `vim.tbl_deep_extend`):

```lua
local entry_actions = require("pickers.entry_actions.adapters.telescope")
local preview_toggle = require("pickers.preview_toggle")
require("telescope").setup({
  defaults = {
    mappings = vim.tbl_deep_extend("force",
      entry_actions.get_mappings(),
      preview_toggle.get_mappings()
    ),
  },
})
```

## Configuration

```lua
require("pickers").setup({
  keys = {
    preview_toggle = {
      key = "<M-p>", -- nil (default): disabled, get_mappings() returns {i={}, n={}}
    },
  },
})
```
