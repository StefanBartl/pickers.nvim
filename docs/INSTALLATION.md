# Installation

## Requirements

**Hard required:**
- [lib.nvim](https://github.com/StefanBartl/lib.nvim)

**One of (auto-detected, telescope preferred, then fzf-lua, then snacks.nvim):**
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [fzf-lua](https://github.com/ibhagwan/fzf-lua)
- [snacks.nvim](https://github.com/folke/snacks.nvim) (picker module)

**Recommended CLI tools:**
- `rg` (ripgrep) — live grep
- `fd` / `fdfind` — system source, dir picker (telescope, snacks)

---

## lazy.nvim — recommended spec

```lua
{
  "StefanBartl/pickers.nvim",
  lazy = false,                      -- required: must load at startup for keymaps
  dependencies = { "StefanBartl/lib.nvim" },
  config = function()
    require("pickers").setup({
      engine    = "auto",            -- "auto" | "telescope" | "fzf" | "snacks"
      repos_dir = vim.env.REPOS_DIR,
      collections = {
        { name = "notes", dir = vim.env.REPOS_DIR .. "/Notes",
          keys = { files = "<leader>mnf", grep = "<leader>mng" } },
        { name = "wkdbooks", dir = vim.env.REPOS_DIR .. "/WKDBooks",
          prefix = "wkdbook-",
          keys = { files = "<leader>wkf", grep = "<leader>wkg" } },
      },
    })
  end,
}
```

> **Why `lazy = false`?**
> `pickers.nvim` registers keymaps and compat user-commands inside `setup()`.
> Without a load trigger lazy.nvim never executes `config`, so nothing gets
> registered. `lazy = false` guarantees startup loading. Alternatively use
> `event = "VeryLazy"` to defer until after startup completes.

## Alternative — true lazy loading

If startup time matters and you only want the plugin loaded on first use:

```lua
{
  "StefanBartl/pickers.nvim",
  dependencies = { "StefanBartl/lib.nvim" },
  cmd = {
    "Pickers",
    "DirPicker", "FindConfig", "GrepConfig", "FindInFolder",
    "LiveGrep", "AllDrives", "AllDrivesGrep", "FindOnSystem",
    "RepoFiles", "RepoGrep", "WkdBookFiles", "WkdBookGrep",
  },
  keys = {
    { "<leader>dp", desc = "[pickers] Dir navigation" },
    { "<leader>fb", desc = "[pickers] Find in folder" },
    { "<leader>fc", desc = "[pickers] Find in config" },
    { "<leader>gc", desc = "[pickers] Grep in config" },
    { "<leader>li", desc = "[pickers] Live grep" },
  },
  config = function()
    require("pickers").setup({
      engine    = "auto",
      repos_dir = vim.env.REPOS_DIR,
    })
  end,
}
```

lazy.nvim registers stub keymaps / commands that load the plugin on first
use; `setup()` then replaces them with the real ones.

## packer.nvim

```lua
use {
  "StefanBartl/pickers.nvim",
  requires = { "StefanBartl/lib.nvim" },
  config = function()
    require("pickers").setup({
      engine    = "auto",
      repos_dir = vim.env.REPOS_DIR,
    })
  end,
}
```

> With packer the plugin is loaded eagerly by default, so keymaps and compat
> user-commands are registered right away — the `lazy = false` note above does
> not apply here.

---

## Health check

```
:checkhealth pickers
```

Verifies: lib.nvim · telescope/fzf-lua/snacks.nvim · rg · fd/fdfind · repos_dir · registered aliases · selected_index status · each collection directory.
