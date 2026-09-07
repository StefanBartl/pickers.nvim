> **Beta stage — active development.** This repository is past its first shape and in
> active use, but the surface is not frozen: breaking changes are still possible. Pin a
> commit or tag if you depend on it.

# pickers.nvim

```
██████╗ ██╗ ██████╗██╗  ██╗███████╗██████╗ ███████╗
██╔══██╗██║██╔════╝██║ ██╔╝██╔════╝██╔══██╗██╔════╝
██████╔╝██║██║     █████╔╝ █████╗  ██████╔╝███████╗
██╔═══╝ ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗╚════██║
██║     ██║╚██████╗██║  ██╗███████╗██║  ██║███████║
╚═╝     ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝
                                        · n v i m ·
```

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.10%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%2FLuaJIT-2C2D72?logo=lua&logoColor=white)](https://www.lua.org)
![Status](https://img.shields.io/badge/status-beta-orange)
[![CI](https://github.com/StefanBartl/pickers.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/StefanBartl/pickers.nvim/actions/workflows/ci.yml)

One `:Pickers` command over telescope.nvim, fzf-lua and snacks.nvim.

Seven separate picker modules consolidated into one grammar —
`:Pickers <scope> <action>` — with the engine auto-detected and every scope,
action and native picker completing with `<Tab>`.

---

## Table of contents

- [Documentation](#documentation)
- [What it does](#what-it-does)
- [Around it](#around-it)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quickstart](#quickstart)
- [What you get with the defaults](#what-you-get-with-the-defaults)
- [The smart action](#the-smart-action)
- [Image and PDF previews](#image-and-pdf-previews)
- [Health check](#health-check)
- [Contributing](#contributing)
- [Feedback](#feedback)
- [License](#license)

---

## Documentation

Start at [docs/README.md](docs/README.md), which says what is where and which
question each page answers.

- [Cheatsheet](docs/cheatsheet.md) — the command syntax, the scopes and the keys on one screen.
- [Features](docs/FEATURES/README.md) — one page per area: [engines](docs/FEATURES/ENGINES.md), [scopes](docs/FEATURES/SCOPES.md), [actions](docs/FEATURES/ACTIONS.md), [native pickers](docs/FEATURES/BUILTINS.md), [keys](docs/FEATURES/KEYS.md), [UI](docs/FEATURES/UI.md), [persistence](docs/FEATURES/PERSISTENCE.md), [refine](docs/FEATURES/REFINE.md), [images](docs/FEATURES/IMAGES.md).
- [Installation](docs/installation.md) — requirements, the recommended spec and the lazy-loading variant, per plugin manager.
- [Configuration](docs/configuration.md) — every `setup()` option and its default. All of them are optional, so it doubles as the list of what happens if you set nothing.
- [Command reference](docs/commands.md) — `:Pickers` argument by argument, the scopes, and the compat aliases.
- [Built-in pickers](docs/builtins.md) — every `:Pickers builtin <name>`, and the per-engine parity matrix.
- [Collections](docs/collections.md) — user-defined named scopes: what a collection is, and how to define one.
- [Keymaps](docs/keymaps.md) — every key, where it is registered, and how to change it.
- [Bindings cheatsheet](docs/BINDINGS.md) — keymaps, user commands and autocommands as one reference.
- [Workflow](docs/WORKFLOW.md) — how scopes, collections and engines combine into a way of working, and the traps table worth reading before you hit one.
- [Changelog](docs/CHANGELOG.md) — what changed, in the order it happened.
- [Contributing](docs/CONTRIBUTING.md) — ground rules, project layout, and how to add a scope, an action or an engine.

`:help pickers` is the same reference inside the editor.

---

## What it does

Picker configurations sprawl. Every source you want — files here, grep there,
the repo list, the git branches — ends up as its own function, its own keymap
and its own idea of what "hidden files" means, and none of it survives swapping
the engine underneath. This plugin makes it one grammar instead.

| Area | Does |
| --- | --- |
| **One command** | `:Pickers <scope> <action>` — pick either half interactively, or name both. Every argument completes with `<Tab>` |
| **Scopes** | Where to look: `cwd`, `config`, `folder`, `repos`, `wkdbooks`, `system`, `drives`, and `dir` with its own navigation forms — a depth, a git root, an alias, or an explicit path |
| **Actions** | What to do there: `files`, `grep`, and `smart`, plus per-call flags (`hidden`, `follow`, `all`) that apply to that call only |
| **Native pickers** | `:Pickers builtin <name>` reaches the engine's own pickers — git branches, log, status and diff, every LSP list, diagnostics, help, marks, buffers, registers — dispatching straight into the resolved engine |
| **Engines** | telescope.nvim, fzf-lua or snacks.nvim, auto-detected. The grammar does not change when the engine does |
| **Collections** | Your own named scopes, so a set of directories you work in becomes one word |

---

## Around it

> **[insights.nvim](https://github.com/StefanBartl/insights.nvim)** — the next
> question after the jump: pickers gets you into a repository, insights tells
> you how it is put together.
>
> **[images.nvim](https://github.com/StefanBartl/images.nvim)** — draws an
> image entry in the preview window as a picture instead of as bytes.
>
> **[pdfport.nvim](https://github.com/StefanBartl/pdfport.nvim)** — the same
> for a `.pdf` entry, previewed as its first page.
>
> All of the above are soft: without them everything else works unchanged.
> [lib.nvim](https://github.com/StefanBartl/lib.nvim) and one picker engine are
> the real dependencies — see [Requirements](#requirements).

---

## Requirements

| | |
| --- | --- |
| Neovim | **0.10+** |
| [lib.nvim](https://github.com/StefanBartl/lib.nvim) | required — the `:Pickers` command layer and the shared helpers |
| One engine | telescope.nvim, fzf-lua or snacks.nvim, auto-detected |

Optional, each detected at runtime and degrading to nothing when absent:

| | |
| --- | --- |
| `rg` (ripgrep) | Live grep, and the content half of `smart` |
| `fd` | The file and directory source, and the `system` scope |
| `fzf` | The fzf engine itself |
| [images.nvim](https://github.com/StefanBartl/images.nvim) | Image entries drawn in the preview window |
| [pdfport.nvim](https://github.com/StefanBartl/pdfport.nvim) | A PDF entry previewed as its first page |

`rg`, `fd` and `fzf` are declared in [docs/install.json](docs/install.json) and
read by lib.nvim's
[deps module](https://github.com/StefanBartl/lib.nvim/blob/main/lua/lib/nvim/deps/README.md).
A popup explains what is missing the first time `setup()` runs after
installing; `:Lib deps show pickers.nvim` repeats it any time, and it is folded
into `:checkhealth pickers`. Turn the popup off in this plugin's own spec with
`require("pickers").setup({ deps_popup = false })`, or globally with
`vim.g.lib_nvim_deps_disable_first_run = true`.

---

## Installation

```lua
-- lazy.nvim
{
  "StefanBartl/pickers.nvim",
  lazy = false,                      -- required: the keymaps have to exist at startup
  dependencies = { "StefanBartl/lib.nvim" },
  opts = {
    -- engine defaults to "auto" (telescope | fzf | snacks, whichever is there)
    -- repos_dir already defaults to $REPOS_DIR when set (via lib.nvim), and is
    -- needed only for the "repos"/"wkdbooks" scopes — set it here to override
  },
}
```

`lazy = false` is not a default worth changing: the keymaps are the point, and
a key that only works after the plugin has been triggered some other way is
worse than no key. [docs/installation.md](docs/installation.md) has the
lazy-loading variant for anyone who binds `:Pickers` themselves, and the other
plugin managers.

---

## Quickstart

Open the picker with no arguments and pick your way through — scope first, then
action:

```vim
:Pickers
```

Then, once you know the words:

```vim
:Pickers cwd files            " find files below the working directory
:Pickers config grep          " live grep in your Neovim config
:Pickers repos                " pick a git repo, then pick what to do in it
:Pickers dir 2 files          " two directories up
:Pickers dir path=~/notes     " an explicit path
:Pickers builtin git_branches " the engine's own native picker, by name
```

Flags apply to a single call, alone or joined with `+`:

```vim
:Pickers cwd files hidden+follow
:Pickers cwd files all        " hidden + no_ignore + follow, just this once
```

Verify your setup any time with:

```vim
:checkhealth pickers
```

---

## What you get with the defaults

| Scope | Looks in |
| --- | --- |
| `cwd` | The current working directory |
| `config` | `stdpath("config")` |
| `folder` | A folder you pick interactively |
| `repos` | A git repository under `repos_dir` |
| `wkdbooks` | A `wkdbook-*` subdirectory under `repos_dir/WKDBooks` |
| `system` | Systemwide via `fd`, prompting for the query |
| `drives` | Every mount point or drive letter |
| `dir <nav>` | `1`…`N` levels up, `git`, `home`, `cwd`, `root`, an alias, or `path=<dir>` |

| Key | Does |
| --- | --- |
| `<leader>dp` | `:Pickers dir` — a count is the depth, so `2<leader>dp` goes two up |
| `<leader>.` | `:Pickers builtin explorer` |

Every scope takes `files`, `grep` or `smart`, and every one of them completes
with `<Tab>`. The full set of keys is [docs/keymaps.md](docs/keymaps.md); the
full command grammar is [docs/commands.md](docs/commands.md).

---

## The smart action

`:Pickers <scope> smart` runs grep over the content and find-files over the
names for the same live query, and merges both into one list **ranked by
relevance** — hits interleave by score regardless of which source produced
them, rather than appearing as two blocks with the good filename match buried
under fifty content hits.

It is the action for the case where you do not know which half you remember:
part of a filename, or a line inside it. See
[docs/commands.md](docs/commands.md#the-smart-action).

---

## Image and PDF previews

With [images.nvim](https://github.com/StefanBartl/images.nvim) installed, an
image entry in the results — `.png`, `.jpg`, and the rest — is **drawn as a
picture** in the preview window instead of previewed as bytes. Snacks and
telescope, no configuration, and nothing changes without it.

Add [pdfport.nvim](https://github.com/StefanBartl/pdfport.nvim) and a `.pdf`
entry previews as its **first page** the same way. Neither is a dependency;
both are detected. The detail is
[docs/FEATURES/IMAGES.md](docs/FEATURES/IMAGES.md).

---

## Health check

```vim
:checkhealth pickers
```

Seven sections: the dependencies, which picker engines resolved, the CLI tools,
the configuration as it was merged, the image-preview wiring, your collections,
and the declared tools. When something does not behave the way the config says
it should, that check and
[WORKFLOW.md §8](docs/WORKFLOW.md#8-traps-worth-knowing-before-you-hit-them) are
the two addresses — there is no separate troubleshooting page on purpose.

---

## Contributing

Clone the repository and either symlink it or add it to your runtime path.
[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) has the ground rules and the
project layout, including where a new scope, action or engine plugs in.

Pull requests very welcome.

---

## Feedback

Your feedback is very welcome. Use the
[issue tracker](https://github.com/StefanBartl/pickers.nvim/issues) to report
bugs, suggest features or ask usage questions; anything more open-ended fits a
[discussion](https://github.com/StefanBartl/pickers.nvim/discussions).

If you find this plugin useful, a ⭐ on GitHub supports its development.

---

## License

MIT — see [LICENSE](LICENSE).
