# `pickers.entry_actions`

In-picker "create file/folder", "open in background", "keymap cheatsheet",
and "copy the selected entry's path" actions, shared across telescope.nvim,
fzf-lua, and snacks.nvim — the picker-specific counterpart to
`pickers.engines.*` (which handles *finding* files, not keybindings inside
an already-open results list).

Not part of `pickers.actions` (that's the `:Pickers` command's scope-dispatch
layer — `dir`/`files`/`grep` — a different concern).

## Structure

```
create_file.lua          Engine-agnostic: notify + vim.ui.input + lib.nvim.fs.create_entry
open_background.lua      Engine-agnostic: notify + lib.nvim.buffer.open_background
path_copy.lua            Engine-agnostic: notify + setreg("+"/'"') -- absolute/dirname/
                          env_rooted/markdown_link formats for the selected entry's path
extract/
  telescope.lua           entry -> path
  fzf.lua                 selected -> path (ANSI/icon-strip included)
  snacks.lua               item -> path (prefers Snacks.picker.util.path())
adapters/
  telescope.lua            get_mappings() -> {i={...}, n={...}}
  fzf.lua                  get_actions()  -> {["ctrl-a"]=fn, ["ctrl-o"]=fn, ["shift-enter"]=fn, ["f1"]=fn,
                                               ["ctrl-y"]=fn, ["alt-y"]=fn, ["alt-r"]=fn, ["alt-m"]=fn}
  snacks.lua                get_actions()     -> {create_file={action=fn,desc="Create file/folder"}, ...}
                            get_keys()        -> {["<C-a>"]="create_file", ...}   (win.list.keys, normal mode)
                            get_input_keys()  -> {["<C-a>"]={"create_file", mode={"i","n"}}, ...}  (win.input.keys)
```

## Path-copy actions (`copy_absolute`/`copy_dirname`/`copy_env_rooted`/`markdown_link`)

The curated subset of filetree.nvim's `[a`/`]a`/`[e`/`ML` path-copy family
that still makes sense on a picker RESULT ROW — a plain path string, not a
`FiletreeNode`. Deliberately NOT ported: marks/trash keymaps, and the
recursive/from-marked Markdown-link variants (`MR`/`MM` — a result row is
one file, not a directory subtree, and pickers.nvim has no multi-select-
aware "marks" concept). filetree.nvim's `gb` ("add to buffer list, no focus
switch") is likewise not duplicated — `open_background` (above) already IS
that action here.

Each writes to both the `"+"` (system) and unnamed `"` registers, exactly
like filetree.nvim, and — unlike `create_file`/`open_background` — does
**not** close the picker: filetree.nvim's own path-copy features are
non-disruptive (copy and stay in the tree), and telescope/snacks preserve
that here directly. fzf-lua's action table always closes the running
process first (not optional, see @description in
`entry_actions/adapters/fzf.lua`); its adapter resumes the picker right
after, approximating the same "stay in place" effect.

**Results-window/normal-mode ONLY, never insert mode** (`pickers.keys`
resolves `modes = { "n" }` for all four). Their default lhs (`[a`, `]a`,
`[e`, `ML`) are plain printable characters, unlike every other in-picker
key here (`<C-a>`, `<S-CR>`, `<C-/>`, arrows, …) — binding them in the
prompt's insert mode would swallow those characters out of any typed query
that happens to contain them (e.g. searching for a file with "ML" in its
name). On snacks, "normal mode" means both `get_keys()` (list window) AND
`get_input_keys()` (input window, mode `"n"` only) — pressing `<Esc>` in
the input window does not move focus to the list, it just drops that same
buffer into its own normal mode (snacks' own default
`win.input.keys["<Esc>"] = "cancel"` carries no `mode` field, so it fires
there, not in insert), so a list-only registration would be unreachable
from that state. telescope needs only one registration (`mappings.n`)
since its single prompt buffer's normal mode already covers both cases.

fzf's own `--bind` syntax has no concept of a multi-keystroke chord like
`[a` (it binds a single logical key, not a pending-key state machine), so
its adapter uses four fixed physical keys instead, unrelated to
`pickers.keys.resolve()`'s Neovim-notation lhs — same class as its
`ctrl-a`/`ctrl-o`/`shift-enter`/`f1`:

| Action | telescope/snacks default | fzf-lua (fixed) |
|---|---|---|
| `copy_absolute` | `[a` | `ctrl-y` |
| `copy_dirname` | `]a` | `alt-y` |
| `copy_env_rooted` | `[e` | `alt-r` |
| `markdown_link` | `ML` | `alt-m` |

`copy_env_rooted` folds `$REPOS_DIR` back into the path (e.g.
`$REPOS_DIR/foo.nvim/x.lua`) when the entry lives under it — reading
`pickers.config`'s already-resolved `repos_dir`, not `vim.env.REPOS_DIR`
directly — and falls back to the plain absolute path otherwise (unset,
empty, or the entry is outside it), same posture as filetree.nvim's own
`env_rooted`.

The snacks adapter's `get_actions()` values carry `desc` (not bare functions) so
Snacks' own **native** `?` → `toggle_help_input`/`toggle_help_list` help panel
(bound by default, `Snacks.win:toggle_help()` — reads real buffer keymaps and
shows each one's `desc`) labels every one of these entry actions (path_copy
included) the same way `pickers.cheatsheet` does, instead of falling back to
the raw action name ("create file"). One extra, no-effort way the cheatsheet
key itself is discoverable on snacks: press `?` in the picker's list or input
window (normal mode) to see everything that is actually bound there,
pickers.nvim's own keys included.

`cheatsheet` (`pickers.cheatsheet`) is a fourth entry action alongside the two
above: a read-only floating panel listing every currently-bound `pickers.keys`
action (create_file/open_background included), built from
`pickers.keys.resolve()` so it always reflects what is actually bound, not
just DEFAULTS.lua. Unlike create_file/open_background it does not touch the
selected entry and does not close the picker on telescope/snacks (both are
plain Neovim floats — the panel just opens on top). fzf-lua is the exception:
its action table always closes the running fzf process first, so its
`do_cheatsheet` reopens fzf (`fzf.resume()`) once the panel closes.

## Usage

`pickers.entry_actions.patch` installs all of this automatically (once each
engine is loaded; your own bindings win on conflict), called from
`pickers.keys.patch`. Merging by hand is only needed to bypass that:

```lua
-- Telescope: merge into defaults.mappings
local entry_actions = require("pickers.entry_actions.adapters.telescope")
require("telescope").setup({
  defaults = { mappings = entry_actions.get_mappings() },
})

-- fzf-lua: merge into actions
local entry_actions = require("pickers.entry_actions.adapters.fzf")
require("fzf-lua").setup({
  actions = vim.tbl_extend("force", { ["default"] = ... }, entry_actions.get_actions()),
})

-- snacks.nvim: merge actions plus BOTH window key tables. A snacks picker
-- opens with focus in the input window, so a list-only binding is unreachable
-- while the query is being typed — get_input_keys() covers that window.
local entry_actions = require("pickers.entry_actions.adapters.snacks")
require("snacks").setup({
  picker = {
    actions = entry_actions.get_actions(),
    win = {
      list = { keys = entry_actions.get_keys() },
      input = { keys = entry_actions.get_input_keys() },
    },
  },
})
```

Once wired, each engine's cheatsheet key (`keys.cheatsheet`, default
`<C-/>`; fixed to `f1` on fzf-lua — see below) opens the panel from inside
any open picker.

## Configuration

Part of the unified `pickers.keys` namespace (see `lua/pickers/keys/`) —
`create_file`/`open_background`/`cheatsheet`/`copy_absolute`/`copy_dirname`/
`copy_env_rooted`/`markdown_link` are seven of its actions, alongside preview
scroll and history navigation, sharing one config surface and one master
`enable` switch:

```lua
require("pickers").setup({
  keys = {
    enable = true,
    create_file     = "<C-a>",
    open_background = { "<S-CR>", "<C-o>" },
    cheatsheet      = "<C-/>",
    copy_absolute   = "[a",
    copy_dirname    = "]a",
    copy_env_rooted = "[e",
    markdown_link   = "ML",
    -- ...preview_scroll_*/history_* also live here, see docs/keymaps.md
  },
})
```

The adapters above call `require("pickers.keys").resolve()` to read these —
they don't read `pickers.config` directly. `create_file`/`open_background`/
`cheatsheet`/path_copy use Neovim keymap syntax and are honoured by the
**telescope and snacks** adapters directly. **fzf-lua's bindings are fixed**
(`ctrl-a`/`ctrl-o`/`shift-enter`/`f1`/`ctrl-y`/`alt-y`/`alt-r`/`alt-m`) —
fzf-lua's action-table keys are fzf's own bind syntax ("ctrl-a"), not Neovim
keymap syntax ("<C-a>"), and there is no general, safe way to translate one
to the other (path_copy's chords like `[a` have no fzf equivalent at all —
see the table above) — only `keys.enable` is honoured by the fzf adapter.
`<C-?>` was considered and rejected for the cheatsheet's default lhs: Neovim
resolves it to the same byte (0x7F/DEL) that Backspace sends in many
terminals, which would fire the cheatsheet on every backspace.

### `open_background_show`

`open_background` (`lua/pickers/entry_actions/open_background.lua`) always
`bufadd`+`bufload`s the selected entry silently. Set
`keys.open_background_show = true` (off by default) to additionally point
the window *behind* the picker at that buffer — never focusing it, focus
stays in the picker. Each adapter resolves "the window behind the picker"
its own way and passes it as `opts.win` to `open_background.run(path, opts)`:

- telescope: `action_state.get_current_picker(prompt_bufnr).original_win_id`
- snacks: `picker.main`
- fzf-lua: `require("fzf-lua.utils").__CTX().winid` (the cached invocation
  context) — best-effort, no cursor positioning (would need to parse the raw
  grep-formatted selected line for a line number)

telescope also passes `opts.pos` (`{lnum, col}`) when the entry carries one
(e.g. grep results), so the background window lands on the matched line, not
just the top of the file.
