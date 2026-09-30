# `pickers.entry_actions`

In-picker "create file/folder", "open in background", "keymap cheatsheet",
"copy the selected entries' paths" and "open with the OS" actions, shared across telescope.nvim,
fzf-lua, and snacks.nvim — the picker-specific counterpart to
`pickers.engines.*` (which handles *finding* files, not keybindings inside
an already-open results list).

Not part of `pickers.actions` (that's the `:Pickers` command's scope-dispatch
layer — `dir`/`files`/`grep` — a different concern).

## Structure

```
create_file.lua          Engine-agnostic: notify + vim.ui.input + lib.nvim.fs.create_entry
open_background.lua      Engine-agnostic: notify + lib.nvim.buffer.open_background
path_copy.lua            Engine-agnostic: notify + setreg("+"/'"') -- absolute/dirname/env_rooted/
                          project_root/project_relative/buffer_relative/markdown_link formats for
                          the selected entries' paths
system.lua               Engine-agnostic: notify + lib.nvim.cross.open_default / reveal_in_fm
extract/
  telescope.lua           entry -> path
  fzf.lua                 selected -> path (ANSI/icon-strip included)
  snacks.lua               item -> path (prefers Snacks.picker.util.path())
adapters/
  telescope.lua            get_mappings() -> {i={...}, n={...}}   (modes per lhs: keys.modes_for)
  fzf.lua                  get_actions()  -> {["ctrl-a"]=fn, ["ctrl-o"]=fn, ["shift-enter"]=fn, ["f1"]=fn,
                                               ["ctrl-y"]=fn, ["alt-y"]=fn, ["alt-v"]=fn, ["alt-t"]=fn,
                                               ["alt-e"]=fn, ["alt-j"]=fn, ["alt-l"]=fn, ["alt-o"]=fn,
                                               ["alt-x"]=fn}
  snacks.lua                get_actions()     -> {create_file={action=fn,desc="Create file/folder"}, ...}
                            get_keys()        -> {["<C-a>"]="create_file", ...}   (win.list.keys, normal mode)
                            get_input_keys()  -> {["<C-a>"]={"create_file", mode={"i","n"}}, ...}  (win.input.keys)
```

## Path-copy and system actions

The curated subset of filetree.nvim's path-copy, markdown-link, copy-file-list
and system features that still makes sense on a picker RESULT ROW — a plain
path string, not a `FiletreeNode`:

| Action | Default lhs (direct · chords) | Copies / does | fzf-lua (fixed) |
|---|---|---|---|
| `copy_absolute` | `<C-y>` · `[a`, `[f` | absolute path (several selected → the file list) | `ctrl-y` |
| `copy_dirname` | `<M-y>` · `]a` | absolute parent directory | `alt-y` |
| `copy_env_rooted` | `<M-v>` · `[e` | `$REPOS_DIR/…` form | `alt-v` |
| `copy_project_root` | `<M-t>` · `[R` | absolute project root (nearest `.git`, else cwd) | `alt-t` |
| `copy_project_relative` | `<M-e>` · `]R` | path relative to that root | `alt-e` |
| `copy_buffer_relative` | `<M-j>` · `]b` | path relative to the buffer behind the picker | `alt-j` |
| `markdown_link` | `<M-l>` · `ML`, `MM` | `[name](relative/path)` | `alt-l` |
| `open_system` | `<M-o>` · `<leader>sm` | open with the OS default application | `alt-o` |
| `reveal_in_manager` | `<M-x>` · `<leader>fm` | reveal in the system file manager | `alt-x` |

**Marks = multi-selection.** filetree.nvim copies "the marked nodes if any,
else the node under the cursor"; here every copy takes all `<Tab>`-selected
entries (one line each, duplicates dropped — ten files in one repo give one
`project_root` line), else the current entry. That is what `[f` (file list) and
`MM` (links from the marked entries) mean in a picker, so there is no separate
marks concept. Each engine hands the selection over its own way: telescope
`picker:get_multi_selection()`, snacks `picker:selected({ fallback = true })`,
fzf-lua the `selected` list itself. The system actions use the current entry
only (one application/window per marked entry would be a surprise).

`buffer_relative` needs the window behind the picker (its buffer's directory is
the base a link written into that buffer resolves against — cwd is the wrong
base): telescope `picker.original_win_id`, snacks `picker.main`, fzf-lua
`utils.__CTX().winid`; then the alternate file, then the cwd.

Deliberately NOT ported: trash, and the recursive Markdown-link variant (`MR` —
a result row is one file, not a directory subtree). filetree.nvim's `gb` ("add
to buffer list, no focus switch") is likewise not duplicated — `open_background`
(above) already IS that action here.

Each copy writes to both the `"+"` (system) and unnamed `"` registers, exactly
like filetree.nvim, and — unlike `create_file`/`open_background` — does
**not** close the picker: filetree.nvim's own path-copy features are
non-disruptive (copy and stay in the tree), and telescope/snacks preserve
that here directly. fzf-lua's action table always closes the running
process first (not optional, see @description in
`entry_actions/adapters/fzf.lua`); its adapter resumes the picker right
after, approximating the same "stay in place" effect. The same holds for the
system actions.

**Direct keys and chords.** Every picker prompt starts in INSERT mode, where
plain printable keys are just characters of the query — filetree.nvim's chords
(`[a`, `ML`, `<leader>sm`, …) can never fire there, which is why they used to
do nothing. So each action carries two kinds of lhs, and `pickers.keys.modes_for`
resolves the modes **per lhs**:

- a **direct key** — one non-printing key press: Ctrl/Alt (`<C-y>`, `<M-l>`, …)
  — is bound in insert **and** normal mode, so it works while typing;
- a **chord** — anything else (`[a`, `ML`, `<leader>sm`, `<Space>`) — is bound in
  **normal mode only** (`chord_modes`), so it never swallows typed characters.

On snacks "normal mode" means both `get_keys()` (list window) AND
`get_input_keys()` (input window, chords with mode `"n"` only) — pressing
`<Esc>` in the input window does not move focus to the list, it just drops that
same buffer into its own normal mode (snacks' own default
`win.input.keys["<Esc>"] = "cancel"` carries no `mode` field, so it fires
there, not in insert), so a list-only registration would be unreachable from
that state. telescope needs only one registration (`mappings.n`) since its
single prompt buffer's normal mode already covers both cases.

fzf's own `--bind` syntax has no concept of a multi-keystroke chord (it binds a
single logical key, not a pending-key state machine), so its adapter uses fixed
physical keys — the same ones the direct lhs above resolve to, unrelated to
`pickers.keys.resolve()`'s Neovim-notation lhs (same class as its
`ctrl-a`/`ctrl-o`/`shift-enter`/`f1`). The Alt keys are picked to stay clear of
the engines' own defaults: snacks `<A-d>/<A-f>/<A-h>/<A-i>/<A-m>/<A-p>/<A-r>/<A-w>`,
telescope `<M-f>/<M-k>/<M-q>`, fzf-lua `alt-a/alt-g/alt-q/alt-i/alt-h/alt-f`, fzf's
`alt-b/alt-f/alt-d` (a test in `TESTS/` guards this). `ctrl-y` shadows fzf-lua's git-picker-only
`git_yank_commit` the way `ctrl-a` already shadows those pickers' own overrides.

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

`cheatsheet` (`pickers.cheatsheet`) is another entry action alongside those
above: a read-only floating panel listing every currently-bound `pickers.keys`
action (create_file/open_background included), built from
`pickers.keys.resolve()` so it always reflects what is actually bound, not
just DEFAULTS.lua — grouped, with "Essentials" (the cheatsheet key itself and
`open_background`) first. The same two keys form the picker **legend**
(`pickers.cheatsheet.hint`): telescope `results_title`, fzf-lua `--header` and
the snacks `title` read "`<C-/> cheatsheet, <S-CR> add to buffers`".

Unlike create_file/open_background it does not touch the
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
`create_file`/`open_background`/`cheatsheet`, the seven path-copy actions and
the two system actions are entry actions of it, alongside preview scroll and
history navigation, sharing one config surface and one master `enable` switch:

```lua
require("pickers").setup({
  keys = {
    enable = true,
    create_file     = "<C-a>",
    open_background = { "<S-CR>", "<C-o>" },
    cheatsheet      = { "<C-/>", "<M-?>" },
    copy_absolute         = { "<C-y>", "[a", "[f" },
    copy_dirname          = { "<M-y>", "]a" },
    copy_env_rooted       = { "<M-v>", "[e" },
    copy_project_root     = { "<M-t>", "[R" },
    copy_project_relative = { "<M-e>", "]R" },
    copy_buffer_relative  = { "<M-j>", "]b" },
    markdown_link         = { "<M-l>", "ML", "MM" },
    open_system           = { "<M-o>", "<leader>sm" },
    reveal_in_manager     = { "<M-x>", "<leader>fm" },
    -- ...preview_scroll_*/history_* also live here, see docs/keymaps.md
  },
})
```

The adapters above call `require("pickers.keys").resolve()` to read these —
they don't read `pickers.config` directly. They use Neovim keymap syntax and
are honoured by the **telescope and snacks** adapters directly. **fzf-lua's
bindings are fixed** (`ctrl-a`/`ctrl-o`/`shift-enter`/`f1`/`ctrl-y`/`alt-y`/
`alt-v`/`alt-t`/`alt-e`/`alt-j`/`alt-l`/`alt-o`/`alt-x`) — fzf-lua's
action-table keys are fzf's own bind syntax ("ctrl-a"), not Neovim keymap
syntax ("<C-a>"), and there is no general, safe way to translate one to the
other (the chords like `[a` have no fzf equivalent at all — see the table
above) — only `keys.enable` is honoured by the fzf adapter.
`<C-?>` was considered and rejected for the cheatsheet's default lhs: Neovim
resolves it to the same byte (0x7F/DEL) that Backspace sends in many
terminals, which would fire the cheatsheet on every backspace (`<M-?>` has no
such problem and is bound as a second lhs).

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
