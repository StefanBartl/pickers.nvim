```
██████╗ ██╗ ██████╗██╗  ██╗███████╗██████╗ ███████╗
██╔══██╗██║██╔════╝██║ ██╔╝██╔════╝██╔══██╗██╔════╝
██████╔╝██║██║     █████╔╝ █████╗  ██████╔╝███████╗
██╔═══╝ ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗╚════██║
██║     ██║╚██████╗██║  ██╗███████╗██║  ██║███████║
╚═╝     ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝
                                        · n v i m ·
```

![status](https://img.shields.io/badge/status-beta-orange.svg)
![Lazy.nvim compatible](https://img.shields.io/badge/lazy.nvim-supported-success)
![Neovim](https://img.shields.io/badge/Neovim-0.9+-success.svg)
![Lua](https://img.shields.io/badge/language-Lua-yellow.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Contributions](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)

**Unified fuzzy-picker plugin for Neovim.**  
Consolidates seven separate picker modules into one plugin with a single `:Pickers` command, backed by telescope.nvim or fzf-lua.

---

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Command](#command)
- [Scopes](#scopes)
- [Keymaps](#keymaps)
- [Compat commands](#compat-commands)
- [Configuration](#configuration)
- [Health check](#health-check)

---

## Requirements

**Hard required:**
- [lib.nvim](https://github.com/StefanBartl/lib.nvim)

**One of (auto-detected, telescope preferred):**
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [fzf-lua](https://github.com/ibhagwan/fzf-lua)

**Recommended CLI tools:**
- `rg` (ripgrep) — live grep
- `fd` / `fdfind` — system source, dir picker (telescope)

---

## Installation

### lazy.nvim — recommended spec

```lua
{
  "StefanBartl/pickers.nvim",
  lazy = false,                      -- required: must load at startup for keymaps
  dependencies = { "StefanBartl/lib.nvim" },
  config = function()
    require("pickers").setup({
      engine    = "auto",            -- "auto" | "telescope" | "fzf"
      repos_dir = vim.env.REPOS_DIR,
    })
  end,
}
```

> **Why `lazy = false`?**  
> `pickers.nvim` registers keymaps and compat user-commands inside `setup()`.
> Without a load trigger lazy.nvim never executes `config`, so nothing gets
> registered. `lazy = false` guarantees startup loading. Alternatively use
> `event = "VeryLazy"` to defer until after startup completes.

### Alternative — true lazy loading

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

---

## Command

```
:Pickers [scope] [action]
:Pickers dir [nav] [action]
```

When an argument is omitted an interactive picker appears (`hover_select` or
`vim.ui.select`).

| Scope | Nav (dir only) | Action | Result |
|---|---|---|---|
| _(none)_ | — | — | scope picker |
| `cwd` | — | _(none)_ | action picker for CWD |
| `cwd` | — | `files` | find files in CWD |
| `config` | — | `grep` | live grep in nvim config |
| `folder` | — | `files` | pick a folder → find files |
| `repos` | — | `files` | pick a repo → find files |
| `wkdbooks` | — | `grep` | pick a wkdbook → live grep |
| `system` | — | `files` | fd systemwide search (prompt) |
| `drives` | — | `grep` | live grep across all drives |
| `dir` | _(none)_ | _(none)_ | nav picker → action picker |
| `dir` | `2` | _(none)_ | 2 dirs up → action picker |
| `dir` | `git` | `files` | git root → find files |
| `dir` | `path=/tmp` | `grep` | explicit path → live grep |

Tab-completion is supported for all arguments.

---

## Scopes

| Scope | Search root |
|---|---|
| `cwd` | `vim.uv.cwd()` |
| `config` | `vim.fn.stdpath("config")` |
| `folder` | Interactively picked directory |
| `repos` | One git repo selected from `repos_dir` |
| `wkdbooks` | One wkdbook selected from `wkdbooks_dir` |
| `system` | Systemwide `fd` search (prompts for query) |
| `drives` | All mount points / drive letters (session-cached) |
| `dir` | Depth / alias / explicit-path navigation |

### dir — nav arg forms

| Nav arg | Resolves to |
|---|---|
| `1` … `N` | N directories above cwd |
| `git` | Git repository root of cwd |
| `home` | OS home directory |
| `cwd` | Current working directory |
| `root` | Filesystem root above cwd |
| `<alias>` | Any name registered in `depth_aliases` |
| `path=<dir>` | Explicit path (`~` / `%VAR%` / `$VAR` expanded) |

---

## Keymaps

All keymaps are registered in `lua/pickers/bindings.lua`.  
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

---

## Compat commands

All commands from the original modules are preserved as aliases:

| Command | Equivalent |
|---|---|
| `:DirPicker [nav]` | `:Pickers dir [nav]` |
| `:FindConfig` | `:Pickers config files` |
| `:GrepConfig` | `:Pickers config grep` |
| `:FindInFolder` | `:Pickers folder files` |
| `:LiveGrep` | `:Pickers cwd grep` |
| `:AllDrives` | `:Pickers drives files` |
| `:AllDrivesGrep` | `:Pickers drives grep` |
| `:FindOnSystem` | `:Pickers system files` |
| `:RepoFiles` | `:Pickers repos files` |
| `:RepoGrep` | `:Pickers repos grep` |
| `:WkdBookFiles` | `:Pickers wkdbooks files` |
| `:WkdBookGrep` | `:Pickers wkdbooks grep` |

---

## Configuration

All keys are optional. Unset keys keep their default values.

```lua
require("pickers").setup({
  -- "auto" detects telescope first, then fzf-lua
  engine = "auto",                      -- "auto" | "telescope" | "fzf"

  -- Root directory that contains git repositories (default: $REPOS_DIR)
  repos_dir = vim.env.REPOS_DIR,

  -- Root for wkdbook directories (default: repos_dir .. "/WKDBooks")
  wkdbooks_dir = nil,

  -- Only subdirectories starting with this prefix are listed as wkdbooks
  wkdbook_prefix = "wkdbook-",

  -- Add or override named dir aliases (merged with built-ins: cwd/home/root/git)
  depth_aliases = {
    work = function() return "/home/user/work" end,
    dots = function() return vim.fn.expand("~/.config") end,
  },

  keymaps = {
    enable       = true,
    dir_pick     = "<leader>dp",   -- Dir navigation picker
    folder_files = "<leader>fb",   -- Find in interactively picked folder
    config_files = "<leader>fc",   -- Find files in nvim config
    config_grep  = "<leader>gc",   -- Grep in nvim config
    cwd_grep     = "<leader>li",   -- Live grep in CWD
    cwd_files    = nil,            -- Find files in CWD (disabled by default)
  },

  usercmds = { enable = true },
})
```

---

## Health check

```
:checkhealth pickers
```

Verifies: lib.nvim · telescope/fzf-lua · rg · fd/fdfind · repos_dir · wkdbooks_dir · registered aliases.

---

## License

MIT
