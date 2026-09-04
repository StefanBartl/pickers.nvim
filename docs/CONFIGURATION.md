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
    -- Honoured by telescope, fzf-lua, and snacks.nvim, for BOTH the file
    -- listing and live grep (as rg -g '!<glob>'), and by the smart action's
    -- own fd/rg calls.
  },

  keymaps = {
    enable       = true,
    dir_pick     = "<leader>dp",   -- Dir navigation picker
    explorer     = "<leader>.",    -- File explorer/browser on the active engine
    folder_files = "<leader>fb",   -- Find in interactively picked folder
    config_files = "<leader>fc",   -- Find files in nvim config
    config_grep  = "<leader>gc",   -- Grep in nvim config
    cwd_grep     = "<leader>li",   -- Live grep in CWD
    cwd_files    = nil,            -- Find files in CWD (disabled by default)
    repos_files  = nil,            -- Pick a repo, then find files (disabled by default)
    repos_grep   = nil,            -- Pick a repo, then live grep  (disabled by default)
    system_files = nil,            -- Systemwide fd search, prompts for query (disabled by default)
    cwd_smart    = nil,            -- Smart (grep + find) in CWD           (disabled by default)
    config_smart = nil,            -- Smart (grep + find) in nvim config    (disabled by default)
    folder_smart = nil,            -- Smart (grep + find) in picked folder  (disabled by default)
    cwd_find_all = nil,            -- "Find all" escape hatch: forces hidden+no_ignore+follow
                                    -- for one search in CWD (disabled by default)
  },

  -- Declarative mappings: a second, more flexible keymap surface alongside
  -- keymaps.* above -- any scope×action or builtin name, with an optional
  -- per-entry engine override. Empty by default. See "Declarative mappings"
  -- in docs/KEYMAPS.md.
  mappings = {},

  usercmds = { enable = true },

  -- Smart action: combined grep + find files, merged and ranked. See
  -- "Smart (combined grep + find)" below.
  smart = {
    weights = { filename = 1.0, content = 1.0, both = 25 },
    limit   = 2000,   -- max merged results kept after ranking
    timeout = 3000,   -- per-command (rg/fd) wait timeout in ms
    -- Opt-in recency/frequency ranking boost, disabled by default.
    frecency = {
      enabled = false,
      weight  = 1.0,  -- multiplier applied to the raw frecency score
      dir     = nil,  -- default: stdpath("data") .. "/pickers.nvim"
    },
    -- Collapse multiple grep hits for the same file to its single
    -- best-scoring line, for a denser merged list. Off by default.
    dedup_grep_rows = false,
  },

  -- Native picker history, disabled by default. See "History" below.
  history = {
    enabled = false,
    fzf_scope = "plugin",  -- "plugin" | "global" | "patch" — fzf-lua only
    dir = nil,             -- default: stdpath("data") .. "/pickers.nvim/history"
    limit = 200,
  },

  -- Unified in-picker keys: preview scroll + history navigation (patched
  -- globally into telescope/fzf-lua/snacks), plus the create_file/
  -- open_background entry actions (merged manually into your own engine
  -- setup() -- see lua/pickers/entry_actions/README.md). See docs/KEYMAPS.md.
  keys = {
    enable = true,
    preview_scroll_down  = "<PageDown>",
    preview_scroll_up    = "<PageUp>",
    preview_scroll_left  = "<C-Left>",
    preview_scroll_right = "<C-Right>",
    history_back         = "<C-p>",
    history_forward      = "<C-n>",
    create_file          = "<C-a>",
    open_background      = { "<S-CR>", "<C-o>" },
    open_background_show = false, -- opt-in: also display (not focus) the entry in the background window
    preview_toggle       = false, -- opt-in, telescope-only (fzf-lua/snacks ship this natively)
    split                = "<C-s>", -- open selected entry in a horizontal split
    vsplit               = "<C-v>", -- open selected entry in a vertical split
    tab                  = "<C-t>", -- open selected entry in a new tab
    mouse_confirm        = "<2-LeftMouse>", -- double-click a result to open it
    -- fzf-lua only binds the vertical preview scroll and the fixed ctrl-a/
    -- ctrl-o/shift-enter entry actions -- everything else is fzf-native/fixed.
    -- split/vsplit/tab are fzf-native too (fixed ctrl-s/ctrl-v/ctrl-t), and
    -- mouse clicks are handled by the fzf binary itself.
  },

  -- Image and PDF previews via images.nvim (soft dependency). On by default,
  -- but only ever active when images.nvim is installed AND the terminal can
  -- draw -- otherwise every engine keeps its own previewer. A PDF additionally
  -- needs pdfport.nvim, which images.nvim reaches. See "Image previews".
  images = {
    enabled = true,
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

**This `history` config has no effect on snacks.nvim.** Unlike telescope/fzf-lua
(no history unless you opt in), snacks.picker's history is a built-in, always-on
feature of the picker core itself — every `Snacks.picker.*` call gets its own
per-source history file at `stdpath("data")/snacks/picker_<source>.history`,
with no `enabled`/`dir`/`limit` knob exposed anywhere in its `opts` schema (see
`snacks/picker/core/picker.lua` — history is created unconditionally in
`Picker.new`, not read from config). Setting `history.enabled = true` while
using the snacks engine is therefore a no-op for snacks specifically; it still
takes effect for telescope/fzf-lua if you have them installed alongside it.
Snacks history navigation (`<C-Up>`/`<C-Down>` by default) is separate from,
and additive with, the `history_back`/`history_forward` keys in
[docs/KEYMAPS.md](KEYMAPS.md#in-picker-keys-preview-scroll--history--entry-actions).

---

## Result count

Shows the live result count in the prompt window's title, e.g. `Find Files
(128)`. **Telescope-only** — fzf-lua and snacks.nvim both already show a
position/total counter natively, so this has no effect there and is
skipped. **Disabled by default.**

```lua
require("pickers").setup({
  result_count = {
    enabled = true,
    interval_ms = 150,   -- how often the count is re-read, in ms
  },
})
```

Updates by polling the entry manager every `interval_ms` (default 150) while
the results buffer is open (not event-driven) — result counts can change asynchronously as a
live finder (e.g. `live_grep`) streams in matches, with no `CursorMoved` or
`TextChanged` event to hang the update off of.

---

## Smart (combined grep + find)

The `smart` action runs `rg` (content) **and** `fd` (filenames) for the same
live query and merges both result sets into **one list ranked by relevance** —
see [docs/COMMANDS.md](COMMANDS.md#the-smart-action) for what it does and how to
open it (`:Pickers <scope> smart`, per-scope/collection `*_smart` keymaps, or
`:{PascalName}Smart`). This section covers only the tuning knobs.

All three engines drive the same core (`lua/pickers/smart/`), so the ranking is
identical regardless of engine. The scorer is deliberately simple and
transparent (a substring/subsequence matcher with prefix/word-boundary/exact
bonuses); these weights only decide the *relative* order between a filename hit
and a content hit.

```lua
require("pickers").setup({
  smart = {
    weights = {
      filename = 1.0,  -- multiplier for the filename-match component (fd hits)
      content  = 1.0,  -- multiplier for the grep content-match component (rg hits)
      both     = 25,   -- flat bonus added to a file that ALSO has grep hits
    },
    limit   = 2000,    -- max merged results kept after ranking
    timeout = 3000,    -- per-command (rg/fd) wait timeout in ms
  },
})
```

Tuning guide:

- **Favour filenames** (typing a name should surface the file itself first):
  raise `weights.filename` or lower `weights.content`.
- **Favour content** (you mostly search inside files): raise `weights.content`.
- **`weights.both`** floats a file that is matched by name *and* contains
  matches above lone hits of either kind — its grep rows still appear on their
  own merits. Set it to `0` to disable that boost.
- **`limit`** caps the merged list after ranking; lower it on huge trees if the
  picker feels heavy.
- **`timeout`** bounds each per-keystroke `rg`/`fd` call. The engines debounce
  input, and the call is synchronous, so keep this modest.

Requirements: `fd` (or `fdfind`) and `rg` on `PATH`. The files half honours
`find` (hidden/no_ignore/follow/exclude); the grep half always searches
`--hidden --no-ignore-vcs --smart-case` plus `find.exclude`, exactly like
`live_grep`. On the
fzf-lua engine the smart action needs fzf ≥ 0.45 (Lua-function live mode); use
telescope or snacks on older fzf.

### Frecency (opt-in ranking boost)

`smart.frecency.enabled = true` adds a recency/frequency bonus to the score
of any file you've opened before, so a file you edit often outranks an
equal-scoring stranger. Visits are recorded on `BufReadPost` (real, listed
file buffers only) and persisted as JSON under
`stdpath("data")/pickers.nvim/frecency.json` (override with
`smart.frecency.dir`). The bonus combines visit frequency (log-dampened, so
one file opened hundreds of times doesn't permanently dominate) with how
recently it was last opened (a visit from the last hour counts far more
than one from a month ago); tune the overall strength with
`smart.frecency.weight`. See `lua/pickers/smart/frecency.lua`.

### Dedup grep rows (opt-in)

`smart.dedup_grep_rows = true` collapses multiple grep hits for the same
file down to its single highest-scoring line, for users who want the merged
list denser (one row per file instead of one row per match). The file's
other matches are dropped entirely, not merged into the kept row — this is
a display-density choice, not a re-scoring. Off by default.

---

## Long-path display shortening

Cosmetic only, **disabled by default**. When on, long paths in the results
list are visually shortened by each engine's own native mechanism — no
pickers.nvim-side logic:

```lua
require("pickers").setup({
  display = {
    path_shorten = true,
  },
})
```

| Engine | Effect |
|---|---|
| telescope | `path_display = { "shorten" }` passed to `find_files`/`live_grep` |
| fzf-lua | `path_shorten = true` passed to `files`/`live_grep` |
| snacks | no-op — snacks already truncates the displayed path to fit the available column width by default, so there's nothing to opt into |

---

## Image previews

An image entry in the results (`.png`, `.jpg`, `.webp`, … — whatever
images.nvim's own `extensions` lists) is drawn as a picture in the preview
window instead of previewed as bytes. Requires
[images.nvim](https://github.com/StefanBartl/images.nvim); **on by default**,
and inert without it.

A `.pdf` entry previews as its first page, on the same switch, when
[pdfport.nvim](https://github.com/StefanBartl/pdfport.nvim) and poppler's
`pdftoppm` are there as well — images.nvim reaches both, pickers.nvim never
does. Which page and at what resolution is images.nvim's own
`pdf = { enabled, page, dpi }`; the switch below turns the whole integration
off, images and pages alike.

```lua
require("pickers").setup({
  images = {
    enabled = true,   -- false keeps the engine's text preview even with images.nvim installed
  },
})
```

| Engine | Effect |
|---|---|
| snacks | `pick_files`, `smart` and `pick_item` draw image and PDF entries; anything else falls through to snacks' own `preview.file` |
| telescope | `pick_files` and `pick_item` draw image and PDF entries; anything else goes to telescope's own buffer previewer. `smart` keeps `grep_previewer`, which has to jump to a matched line |
| fzf-lua | no-op — its builtin previewer has no per-call Lua hook and ships image support of its own (`previewers.builtin.extensions` = chafa/viu/ueberzug) |

Being "enabled" is not the same as being active: images.nvim must be installed
*and* report that the terminal can draw. On a terminal it does not recognise
the answer is no and the text preview stays — deliberately, since an empty
preview window would be worse than the one the engine already had.
images.nvim's `display.assume_supported = true` overrides that detection.
`:checkhealth pickers` names which of the three states applies, and reports
separately whether PDF pages can be rasterized.

Full details, and why each engine draws the line where it does, in
[FEATURES/IMAGES.md](FEATURES/IMAGES.md).
