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

> 💡 Pairs well with [insights.nvim](https://github.com/StefanBartl/insights.nvim):
> use `pickers.nvim` to jump into any repo, then get an instant structural
> overview of it with `insights.nvim`.

---

## Quickstart

Requires [lib.nvim](https://github.com/StefanBartl/lib.nvim) and one of telescope.nvim / fzf-lua / snacks.nvim (auto-detected).

```lua
{
  "StefanBartl/pickers.nvim",
  lazy = false,                      -- required: must load at startup for keymaps
  dependencies = { "StefanBartl/lib.nvim" },
  config = function()
    require("pickers").setup({
      engine    = "auto",            -- "auto" | "telescope" | "fzf" | "snacks"
      repos_dir = vim.env.REPOS_DIR,
    })
  end,
}
```

Then open the picker with:

```
:Pickers
```

---

## Documentation

- [Installation](docs/INSTALLATION.md) — requirements, lazy.nvim (recommended + lazy-loading variant), packer.nvim, and health check.
- [Commands](docs/COMMANDS.md) — the `:Pickers` command syntax, scopes, and compat command aliases.
- [Collections](docs/COLLECTIONS.md) — defining user scopes over your own directories.
- [Keymaps](docs/KEYMAPS.md) — default keymaps and how to change or disable them.
- [Configuration](docs/CONFIGURATION.md) — full `setup()` reference, picker history, and the selected-index overlay.
- [Bindings cheatsheet](docs/BINDINGS.md) — machine-readable reference of every keymap, user command, and autocommand.
- [Cheatsheet](docs/CHEATSHEET.md) — condensed single-page command/scope/keymap reference.
- [Roadmap](docs/ROADMAP.md) — planned and potential features.
