> **Alpha stage — active development.** This repository is in its development phase — breaking changes are to be expected at any time. Pin a commit or tag if you depend on it.

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
![Status](https://img.shields.io/badge/status-alpha-red)

**Unified fuzzy-picker plugin for Neovim.**
Consolidates seven separate picker modules into one plugin with a single `:Pickers` command, backed by telescope.nvim, fzf-lua, or snacks.nvim.

Includes a **`smart`** action — `:Pickers <scope> smart` runs grep (content) and
find-files (filenames) for the same live query and merges both into one list
**ranked by relevance**, so hits interleave by score regardless of source
instead of showing as two separate blocks. See [docs/commands.md](docs/commands.md#the-smart-action).

`:Pickers builtin <name>` also gives tab-completed, engine-agnostic access to
the native pickers that aren't a scope×action — git branches/log/status/diff,
every LSP list, diagnostics, help, marks, buffers, registers, and more —
dispatching straight into the resolved engine's own picker function. See
[docs/builtins.md](docs/builtins.md) for the full name list and per-engine parity matrix.

With [images.nvim](https://github.com/StefanBartl/images.nvim) installed, an
image entry in the results (`.png`, `.jpg`, …) is **drawn as a picture** in the
preview window instead of previewed as bytes — snacks and telescope, no
configuration, and nothing changes without it. Add
[pdfport.nvim](https://github.com/StefanBartl/pdfport.nvim) and a `.pdf` entry
previews as its **first page** the same way. See
[docs/FEATURES/IMAGES.md](docs/FEATURES/IMAGES.md).

> 💡 Pairs well with [insights.nvim](https://github.com/StefanBartl/insights.nvim):
> use `pickers.nvim` to jump into any repo, then get an instant structural
> overview of it with `insights.nvim`.

---

## Table of content

- [Quickstart](#quickstart)
- [Documentation](#documentation)

---

## Quickstart

Requires [lib.nvim](https://github.com/StefanBartl/lib.nvim) and one of telescope.nvim / fzf-lua / snacks.nvim (auto-detected).

```lua
{
  "StefanBartl/pickers.nvim",
  lazy = false,                      -- required: must load at startup for keymaps
  dependencies = { "StefanBartl/lib.nvim" },
  opts = {
    -- engine defaults to "auto" (telescope | fzf | snacks, whichever is there)
    repos_dir = vim.env.REPOS_DIR,
  },
}
```

Then open the picker with:

```
:Pickers
```

`rg`/`fd`/`fzf` are optional CLI tools that unlock specific sources
(live-grep, the file/dir source, the fzf engine) — declared in
[`docs/install.json`](docs/install.json), parsed by lib.nvim's
[`deps` module](https://github.com/StefanBartl/lib.nvim/blob/main/lua/lib/nvim/deps/README.md).
A popup explains what's missing the first time `setup()` runs after
installing pickers.nvim; `:Lib deps show pickers.nvim` repeats it any time,
and it's also folded into `:checkhealth pickers`. Disable it **right in
this plugin's own spec**: `require("pickers").setup({ deps_popup = false })`.
`vim.g.lib_nvim_deps_disable_first_run = true` (every plugin) /
`vim.g.lib_nvim_deps_disabled_plugins = { "pickers.nvim" }` also still
work, for turning it off without touching any plugin's config.

---

## Documentation

- [Documentation index](docs/README.md) — everything below, plus what isn't listed here, with the question each page answers.
- [Features](docs/FEATURES/README.md) — the catalogue, by theme: engines, scopes, actions, native pickers, keys, UI, persistence, image previews.
- [Installation](docs/installation.md) — requirements, lazy.nvim (recommended + lazy-loading variant), packer.nvim, and health check.
- [Configuration](docs/configuration.md) — every `setup()` option and its default.
- [Commands](docs/commands.md) — the `:Pickers` grammar, the scopes, and the compat aliases.
- [Bindings cheatsheet](docs/BINDINGS.md) — every keymap, user command and autocommand at a glance.

`:help pickers` covers the same ground offline.

## License

MIT — see [LICENSE](LICENSE).
