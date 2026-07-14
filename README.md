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
![Contributions](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)

**Unified fuzzy-picker plugin for Neovim.**  
Consolidates seven separate picker modules into one plugin with a single `:Pickers` command, backed by telescope.nvim, fzf-lua, or snacks.nvim.

> 💡 Pairs well with [project-insight.nvim](https://github.com/StefanBartl/project-insight.nvim):
> use `pickers.nvim` to jump into any repo, then get an instant structural
> overview of it with `project-insight.nvim`.

---

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Command](#command)
- [Scopes](#scopes)
- [Collections](#collections)
- [Keymaps](#keymaps)
- [Compat commands](#compat-commands)
- [Configuration](#configuration)
- [Selected index display](#selected-index-display)
- [Health check](#health-check)

---

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

## Installation

### lazy.nvim — recommended spec

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

### packer.nvim

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

## Command

```
:Pickers [scope] [action]
:Pickers dir [nav] [action]
```

When an argument is omitted an interactive picker appears (`hover_select` or
`vim.ui.select`).

| Scope | Nav (dir only) | Action | Result |
|---|---|---|---|
| _(none)_ | — | — | scope picker (built-ins + collections) |
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
| `notes` _(collection)_ | — | `files` | find files in collection root |
| `wkdbooks` _(collection)_ | — | `grep` | pick subdir → live grep |

Tab-completion is supported for all arguments, including collection names.

---

## Scopes

### Built-in scopes

| Scope | Search root |
|---|---|
| `cwd` | `vim.uv.cwd()` |
| `config` | `vim.fn.stdpath("config")` |
| `folder` | Interactively picked directory |
| `repos` | One git repo selected from `repos_dir` |
| `wkdbooks` | One wkdbook selected from `repos_dir/WKDBooks` |
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

## Collections

Collections are user-defined named scopes. Each collection becomes a first-class
`:Pickers` scope, gets auto-generated compat commands (`{PascalName}Files` /
`{PascalName}Grep`), and optional keymaps.

### Collection config

```lua
collections = {
  -- Direct root — dir is used as-is
  { name = "notes",       dir = vim.env.REPOS_DIR .. "/Notes",
    keys = { files = "<leader>mnf", grep = "<leader>mng" } },

  -- Prefix-filtered subdirs — pick one, then search inside it
  { name = "wkdbooks",    dir = vim.env.REPOS_DIR .. "/WKDBooks",
    prefix = "wkdbook-",
    keys = { files = "<leader>wkf", grep = "<leader>wkg" } },

  -- All subdirs (empty prefix string) — pick one, then search inside it
  { name = "projects",    dir = "/home/user/projects", prefix = "" },

  -- Only subdirs that contain .git/
  { name = "myrepos",     dir = "/home/user/src", prefix = "", only_git = true },
}
```

### prefix field behaviour

| `prefix` value | Behaviour |
|---|---|
| `nil` (not set) | `dir` is used directly as the search root |
| `""` (empty string) | All immediate subdirs of `dir` are listed; pick one |
| `"xyz-"` | Only subdirs whose name starts with `"xyz-"` are listed |

### Auto-generated compat commands

For a collection named `"notes_lua"`:

| Command | Equivalent |
|---|---|
| `:NotesLuaFiles` | `:Pickers notes_lua files` |
| `:NotesLuaGrep` | `:Pickers notes_lua grep` |

---

## Keymaps

All keymaps are registered in `lua/pickers/bindings/` (see also `docs/BINDINGS.md`).  
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
| `:RepoFiles [repo]` | `:Pickers repos files` (or jump straight to `[repo]`, tab-completed) |
| `:RepoGrep [repo]` | `:Pickers repos grep` (or jump straight to `[repo]`, tab-completed) |
| `:WkdBookFiles` | `:Pickers wkdbooks files` |
| `:WkdBookGrep` | `:Pickers wkdbooks grep` |

---

## Configuration

All keys are optional. Unset keys keep their default values.

```lua
require("pickers").setup({
  -- "auto" detects telescope first, then fzf-lua, then snacks.nvim
  engine = "auto",                      -- "auto" | "telescope" | "fzf" | "snacks"

  -- Root directory that contains git repositories (default: $REPOS_DIR)
  repos_dir = vim.env.REPOS_DIR,

  -- User-defined named scopes (see Collections section above)
  collections = {
    { name = "notes",    dir = vim.env.REPOS_DIR .. "/Notes",
      keys = { files = "<leader>mnf", grep = "<leader>mng" } },
    { name = "wkdbooks", dir = vim.env.REPOS_DIR .. "/WKDBooks",
      prefix = "wkdbook-",
      keys = { files = "<leader>wkf", grep = "<leader>wkg" } },
  },

  -- Add or override named dir aliases (merged with built-ins: cwd/home/root/git)
  depth_aliases = {
    work = function() return "/home/user/work" end,
    dots = function() return vim.fn.expand("~/.config") end,
  },

  -- File-listing behaviour for the built-in file pickers (config/cwd/folder/
  -- repos/collections). The `system` scope builds its own fd command and is
  -- unaffected. Telescope and fzf-lua both honour these.
  find = {
    hidden    = true,   -- show dotfiles (.github/, .luarc.json, …)
    no_ignore = false,  -- respect .gitignore/.ignore; set true to list ignored files too
    follow    = true,   -- follow symlinks
    exclude   = nil,    -- optional list of extra globs to skip, e.g. { "node_modules", "*.min.js" }
    -- Honoured by telescope, fzf-lua, and snacks.nvim.
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

  -- Native picker history, disabled by default. See "History" below.
  history = {
    enabled = false,
    fzf_scope = "plugin",  -- "plugin" | "global" | "patch" — fzf-lua only
    dir = nil,             -- default: stdpath("data") .. "/pickers.nvim/history"
    limit = 200,
  },

  -- Overlay showing the index of the currently selected entry. Telescope-only,
  -- disabled by default. See "Selected index display" below.
  selected_index = {
    enabled = false,
    position = "right_align",         -- "overlay" | "right_align" | "eol" | "top" | "down"
    highlight = { preset = "default" }, -- see presets below
    toggle_key = nil,                 -- e.g. "<M-i>" to toggle live in an open picker
  },

  -- In-picker "create file/folder" and "open in background" entry actions,
  -- shared across telescope/fzf-lua/snacks.nvim. See lua/pickers/entry_actions/README.md.
  entry_actions = {
    enable = true,
    keys = {
      create_file     = "<C-a>",
      open_background = { "<S-CR>", "<C-o>" },
    },
    -- fzf-lua's ctrl-a/ctrl-o/shift-enter bindings are fixed; not affected
    -- by `keys` (fzf's own bind syntax, not Neovim keymap syntax).
  },
})
```

---

## History

File-based picker history, disabled by default. Files live under
`stdpath("data")/pickers.nvim/history` (override with `history.dir`).

```lua
require("pickers").setup({
  history = {
    enabled = true,
    fzf_scope = "plugin", -- "plugin" | "global" | "patch"
    limit = 200,
  },
})
```

**Telescope has no scope knob.** Telescope's history is a process-wide
singleton (one `History` object, created on first use and reused for the rest
of the session by *every* telescope picker, not just pickers.nvim's — see
`:h telescope.defaults.history`). There's no per-call override, so enabling
history for telescope always behaves like a global default regardless of
`fzf_scope` — this is a Telescope architecture limitation, not a choice made
here. If you already use `telescope-smart-history` (sqlite-backed, scoped by
picker+cwd), keep managing that yourself instead of enabling history here for
telescope — this feature is plain file-based, with no sqlite involvement.

**`fzf_scope` only affects fzf-lua**, where each provider call *can* carry
its own `--history` file:

| `fzf_scope` | Effect |
|---|---|
| `"plugin"` (default) | Separate history files per provider (files/grep/item), set only on pickers.nvim's own fzf-lua calls. Doesn't touch your own `fzf-lua.setup()`. |
| `"global"` | pickers.nvim doesn't set its own `fzf_opts`; use `require("pickers.history").fzf_opts()` / `.telescope_opts()` yourself in your own `fzf-lua.setup()` / `telescope.setup({defaults={history=...}})` calls. One shared history file, same as `"patch"`. |
| `"patch"` | pickers.nvim calls `fzf-lua`'s `setup()` itself (deferred via `vim.schedule`, merged non-destructively) so your own direct `:FzfLua` usage also gets the shared history file — no config change needed on your end. |

---

## Selected index display

An optional overlay that shows the index (e.g. `12. `) of the currently
selected entry directly in the results buffer, updated as you move the
selection. **Telescope-only** — fzf-lua already shows a position/total
counter natively, so the overlay has no effect there and is skipped.
**Disabled by default.**

```lua
require("pickers").setup({
  selected_index = {
    enabled = true,
    position = "right_align",   -- "overlay" | "right_align" | "eol" | "top" | "down"
    highlight = { preset = "accent" },
  },
})
```

Positions:

| Position | Effect |
|---|---|
| `overlay` | Drawn over the start of the line |
| `right_align` | Right-aligned virtual text (default) |
| `eol` | Appended at end of line |
| `top` | Virtual line above the entry |
| `down` | Virtual line below the entry |

Highlight presets (`highlight.preset`): `default` (inherits Telescope's
result-function color) · `subtle` · `bold` · `accent` · `minimal` · `error` ·
`success` · `custom` (provide your own spec via `highlight.custom`):

```lua
highlight = {
  preset = "custom",
  custom = { fg = "#89dceb", bold = true }, -- fg/bg/bold/italic/underline/undercurl/strikethrough/blend
},
```

The highlight group is named `PickersSelectedIndex` if you want to link or
override it yourself via `vim.api.nvim_set_hl`.

**Live toggle.** Set `toggle_key` to an in-picker keymap (insert + normal
mode) that switches the overlay on/off for the *currently open* results list
— useful when `enabled = false` by default but you still want it available
on demand:

```lua
require("pickers").setup({
  selected_index = {
    enabled = false,     -- starts hidden
    toggle_key = "<M-i>", -- press inside any Telescope picker to show/hide it
  },
})
```

`toggle_key` works independently of `enabled`: with `enabled = true` the
overlay starts visible and `toggle_key` can hide it; with `enabled = false`
it starts hidden and `toggle_key` can show it. Leaving `toggle_key` unset
(the default) registers no extra keymap at all, so `enabled = false` alone
stays fully inert.

---

## Health check

```
:checkhealth pickers
```

Verifies: lib.nvim · telescope/fzf-lua/snacks.nvim · rg · fd/fdfind · repos_dir · registered aliases · selected_index status · each collection directory.
