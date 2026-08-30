> **Active development.** This repository is in its development phase — breaking changes are to be expected at any time. Pin a commit or tag if you depend on it.

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

![status](https://img.shields.io/badge/status-beta-orange.svg)
![Lazy.nvim compatible](https://img.shields.io/badge/lazy.nvim-supported-success)
![Neovim](https://img.shields.io/badge/Neovim-0.9+-success.svg)
![Lua](https://img.shields.io/badge/language-Lua-yellow.svg)
![Contributions](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)

**Unified fuzzy-picker plugin for Neovim.**
Consolidates seven separate picker modules into one plugin with a single `:Pickers` command, backed by telescope.nvim, fzf-lua, or snacks.nvim.

Includes a **`smart`** action — `:Pickers <scope> smart` runs grep (content) and
find-files (filenames) for the same live query and merges both into one list
**ranked by relevance**, so hits interleave by score regardless of source
instead of showing as two separate blocks. See [docs/COMMANDS.md](docs/COMMANDS.md#the-smart-action).

`:Pickers builtin <name>` also gives tab-completed, engine-agnostic access to
~40 native pickers that aren't a scope×action — git branches/log/status/diff,
every LSP list, diagnostics, help, marks, buffers, registers, and more —
dispatching straight into the resolved engine's own picker function. See
[docs/BUILTINS.md](docs/BUILTINS.md) for the full name list and per-engine parity matrix.

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

- [Features](docs/FEATURES/README.md) — the catalogue, by theme: engines, scopes, actions, native pickers, keys, UI, persistence.
- [Installation](docs/INSTALLATION.md) — requirements, lazy.nvim (recommended + lazy-loading variant), packer.nvim, and health check.
- [Commands](docs/COMMANDS.md) — the `:Pickers` command syntax, scopes, and compat command aliases.
- [Native pickers](docs/BUILTINS.md) — `:Pickers builtin <name>`, the full name list, and the per-engine parity matrix.
- [Collections](docs/COLLECTIONS.md) — defining user scopes over your own directories.
- [Keymaps](docs/KEYMAPS.md) — default keymaps and how to change or disable them.
- [Configuration](docs/CONFIGURATION.md) — full `setup()` reference and picker history.
- [Bindings cheatsheet](docs/BINDINGS.md) — machine-readable reference of every keymap, user command, and autocommand.
- [Cheatsheet](docs/CHEATSHEET.md) — condensed single-page command/scope/keymap reference.
- [Feature log](docs/CHANGELOG.md) — what changed and when, in the order it happened.

## License

MIT — see [LICENSE](LICENSE).
