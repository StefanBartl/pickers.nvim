# Configuration

All keys are optional. Unset keys keep their default values.

```lua
require("pickers").setup({
  -- "auto" detects telescope first, then fzf-lua, then snacks.nvim
  engine = "auto",                      -- "auto" | "telescope" | "fzf" | "snacks"

  -- Root directory that contains git repositories (default: $REPOS_DIR)
  repos_dir = vim.env.REPOS_DIR,

  -- User-defined named scopes (see docs/COLLECTIONS.md)
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
