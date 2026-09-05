# Installation

## Requirements

**Hard required:**
- Neovim **0.10+** — `vim.uv` and `vim.system` are used unguarded (directory
  navigation, the collection and repo sources, and the `smart` action's `rg`/
  `fd` calls all depend on them)
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
    "PickersRepeat", "PickersScopes", "PickersResume",
  },
  keys = {
    { "<leader>dp", desc = "[pickers] Dir navigation" },
    { "<leader>.",  desc = "[pickers] File explorer" },
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

Both lists cover the built-in defaults only. A collection's generated
`:{PascalName}Files`/`Grep`/`Smart` commands and any keymap you bind yourself
have to be added to `cmd`/`keys` as well, or they will not exist until
something else has already loaded the plugin.

## Optional: engine ownership + auto-install

By default pickers.nvim only *detects* whichever engine you already declared
and configured yourself (the spec above) — it never calls
`Snacks.setup()`/`telescope.setup()`/`fzf-lua.setup()` for you, so your own
engine config (dashboard, extensions, winopts, …) is never fought over by a
second competing `setup()` call.

If you'd rather have pickers.nvim install **and** configure the engine too —
zero engine config of your own — use `require("pickers").plugin_spec()` in
your own plugin list, at spec-build time:

```lua
require("lazy").setup({
  require("pickers").plugin_spec({
    engine      = "snacks",       -- "telescope" | "fzf" | "snacks" ("auto" not supported here)
    own_engine  = true,           -- opt-in; false/unset is the default (unchanged) behaviour
    engine_opts = {},             -- passed to Snacks.setup() / telescope.setup() / fzf-lua's setup()
    picker_opts = {                -- passed to require("pickers").setup() (engine= is filled in for you)
      repos_dir = vim.env.REPOS_DIR,
    },
  }),
  -- ...your other plugins
})
```

`plugin_spec()` returns a list of ready lazy.nvim spec entries (splat it
into your own list as shown) — a plain `setup({ own_engine = true })` call
alone can't install a missing engine, since lazy.nvim resolves a plugin's
`dependencies` *before* `config()` runs, so the engine choice has to be
known at spec-build time instead. `own_engine = true` requires an explicit
`engine` — there's no single engine to install for `"auto"`.

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

Verifies: lib.nvim · telescope/fzf-lua/snacks.nvim · rg · fd/fdfind ·
repos_dir · registered aliases · whether image previews are active and whether
PDF pages can be rasterized · each collection directory · the tools declared in
[`install.json`](install.json) · the `:Pickers` command tree.
