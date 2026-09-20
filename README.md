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

One `:Pickers` command over telescope.nvim, fzf-lua and snacks.nvim. Seven
separate picker modules consolidated into one grammar —
`:Pickers <scope> <action>` — with the engine auto-detected and every scope,
action and native picker completing with `<Tab>`.

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
> the real dependencies — see [Requirements](docs/installation.md#requirements).

---

## Documentation

Start at [docs/README.md](docs/README.md), which says what is where and which
question each page answers.

### The Basics

- [Requirements](docs/installation.md#requirements) — Neovim version, required plugins and CLI tools.
- [Installation](docs/installation.md) — the recommended spec and the lazy-loading variant, per plugin manager.
- [Quickstart](docs/quickstart.md) — the first thing to run after installing.

### Configuration

- [What you get with the defaults](docs/what-you-get.md) — the scopes and default keys at a glance.
- [All options](docs/configuration.md) — every `setup()` option and its default. All of them are optional, so it doubles as the list of what happens if you set nothing.
- [Command reference](docs/commands.md) — `:Pickers` argument by argument, the scopes, the smart action, and the compat aliases.
- [Cheatsheet](docs/cheatsheet.md) — the command syntax, the scopes and the keys on one screen.
- [Keymaps](docs/keymaps.md) / [Bindings cheatsheet](docs/BINDINGS.md)

### The Rest

- [Features](docs/FEATURES/README.md) — one page per area: [engines](docs/FEATURES/ENGINES.md), [scopes](docs/FEATURES/SCOPES.md), [actions](docs/FEATURES/ACTIONS.md), [native pickers](docs/FEATURES/BUILTINS.md), [keys](docs/FEATURES/KEYS.md), [UI](docs/FEATURES/UI.md), [persistence](docs/FEATURES/PERSISTENCE.md), [refine](docs/FEATURES/REFINE.md), [images and PDFs](docs/FEATURES/IMAGES.md).
- [Built-in pickers](docs/builtins.md) — every `:Pickers builtin <name>`, and the per-engine parity matrix.
- [Collections](docs/collections.md) — user-defined named scopes: what a collection is, and how to define one.
- [Workflow](docs/WORKFLOW.md) — how scopes, collections and engines combine into a way of working, and the traps table worth reading before you hit one.
- [Changelog](docs/CHANGELOG.md) — what changed, in the order it happened.
- [Contributing](docs/CONTRIBUTING.md) — ground rules, project layout, and how to add a scope, an action or an engine.
- [Feedback](https://github.com/StefanBartl/pickers.nvim/issues) — bugs, feature requests and usage questions; broader discussion in [Discussions](https://github.com/StefanBartl/pickers.nvim/discussions).

`:help pickers` is the same reference inside the editor. When something does
not behave the way the config says it should, there is no separate
troubleshooting page on purpose — start at
[WORKFLOW.md §8](docs/WORKFLOW.md#8-traps-worth-knowing-before-you-hit-them)
and `:checkhealth pickers`.

---

## License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

pickers.nvim is released under the [MIT License](https://opensource.org/licenses/MIT).
