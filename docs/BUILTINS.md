# Builtins (`:Pickers builtin <name>`)

Registry of native picker-engine builtins — buffers, help/man, marks,
jumps, registers, git, LSP, diagnostics, and a handful of engine-exclusive
extras — dispatched to whichever engine `pickers.engines.load()` resolves.

Complements the `:Pickers <scope> <action>` layer, which only knows plain
files/grep. `explorer`/`dashboard` are deliberately excluded (not pickers).
`notifications` (snacks' own notification history) *is* included even
though it's snacks-only — see the registry entry.

Source of truth: `lua/pickers/builtins/init.lua`'s `M.REGISTRY`. Every
mapping below was verified against the actually installed plugin sources
(`telescope.builtin`, `require("fzf-lua")`, `snacks.picker`) — not guessed
from docs — by checking each function actually exists on that module. See
the `false`/`—` entries for genuine gaps, each with an inline comment in the
registry explaining why.

## Usage

```
:Pickers builtin <name>
```

`<name>` tab-completes against the registry. Example: `:Pickers builtin
git_status`, `:Pickers builtin lsp_references`.

```lua
require("pickers.builtins").run("marks")
```

If the current engine has no equivalent for a given name, `run()` reports
`notify.warn` and returns — it does not error or silently no-op.

## Parity matrix

| Name | telescope | fzf-lua | snacks.nvim |
|---|---|---|---|
| `autocmds` | `autocommands` | `autocmds` | `autocmds` |
| `buffers` | `buffers` | `buffers` | `buffers` |
| `colorschemes` | `colorscheme` | `colorschemes` | `colorschemes` |
| `command_history` | `command_history` | `command_history` | `command_history` |
| `commands` | `commands` | `commands` | `commands` |
| `diagnostics` | `diagnostics` | `diagnostics_workspace` | `diagnostics` |
| `diagnostics_buffer` | `diagnostics` | `diagnostics_document` | `diagnostics_buffer` |
| `filetypes` | `filetypes` | `filetypes` | — |
| `gh_issue` | — | — | `gh_issue` |
| `gh_pr` | — | — | `gh_pr` |
| `git_bcommits` | `git_bcommits` | `git_bcommits` | `git_log_file` |
| `git_branches` | `git_branches` | `git_branches` | `git_branches` |
| `git_commits` | `git_commits` | `git_commits` | `git_log` |
| `git_diff` | — | `git_diff` | `git_diff` |
| `git_files` | `git_files` | `git_files` | `git_files` |
| `git_log_line` | — | — | `git_log_line` |
| `git_stash` | `git_stash` | `git_stash` | `git_stash` |
| `git_status` | `git_status` | `git_status` | `git_status` |
| `grep_buffers` | — | — | `grep_buffers` |
| `grep_word` | `grep_string` | `grep_cword` | `grep_word` |
| `help` | `help_tags` | `helptags` | `help` |
| `highlights` | `highlights` | `highlights` | `highlights` |
| `icons` | — | — | `icons` |
| `jumps` | `jumplist` | `jumps` | `jumps` |
| `keymaps` | `keymaps` | `keymaps` | `keymaps` |
| `lazy_specs` | — | — | `lazy` |
| `lines` | `current_buffer_fuzzy_find` | `blines` | `lines` |
| `loclist` | `loclist` | `loclist` | `loclist` |
| `lsp_declarations` | — | `lsp_declarations` | `lsp_declarations` |
| `lsp_definitions` | `lsp_definitions` | `lsp_definitions` | `lsp_definitions` |
| `lsp_document_symbols` | `lsp_document_symbols` | `lsp_document_symbols` | `lsp_symbols` |
| `lsp_implementations` | `lsp_implementations` | `lsp_implementations` | `lsp_implementations` |
| `lsp_incoming_calls` | `lsp_incoming_calls` | `lsp_incoming_calls` | `lsp_incoming_calls` |
| `lsp_outgoing_calls` | `lsp_outgoing_calls` | `lsp_outgoing_calls` | `lsp_outgoing_calls` |
| `lsp_references` | `lsp_references` | `lsp_references` | `lsp_references` |
| `lsp_type_definitions` | `lsp_type_definitions` | `lsp_typedefs` | `lsp_type_definitions` |
| `lsp_workspace_symbols` | `lsp_workspace_symbols` | `lsp_workspace_symbols` | `lsp_symbols` |
| `man_pages` | `man_pages` | `manpages` | `man` |
| `marks` | `marks` | `marks` | `marks` |
| `notifications` | — | — | `notifications` |
| `oldfiles` | `oldfiles` | `oldfiles` | `recent` |
| `projects` | — | — | `projects` |
| `quickfix` | `quickfix` | `quickfix` | `qflist` |
| `registers` | `registers` | `registers` | `registers` |
| `resume` | `resume` | — | `resume` |
| `search_history` | `search_history` | `search_history` | `search_history` |
| `spell_suggest` | `spell_suggest` | `spell_suggest` | — |
| `treesitter` | `treesitter` | `treesitter` | `treesitter` |
| `undo` | — | `undotree` | `undo` |

Notable naming disagreements between engines (same feature, different name):

- **Recent files**: telescope/fzf-lua call it `oldfiles`; snacks calls it `recent`.
- **Commit log**: telescope/fzf-lua call it `git_commits`; snacks calls it `git_log`.
- **Symbols**: telescope/fzf-lua split document vs. workspace symbols;
  snacks folds both into one `lsp_symbols` source.
- **Diagnostics scope**: telescope reuses one `diagnostics` function for
  both scopes (toggled via `bufnr = 0`); fzf-lua and snacks have separate
  document/workspace (or buffer/global) names.
- **Type definitions**: fzf-lua's name is `lsp_typedefs`, not
  `lsp_type_definitions` like the other two engines.
- **Per-file commit log**: telescope/fzf-lua call it `git_bcommits`
  ("buffer commits"); snacks calls it `git_log_file`.
- **Current-buffer fuzzy lines**: telescope's `current_buffer_fuzzy_find`
  and snacks' `lines` both mean "fuzzy search this buffer's lines" — but
  fzf-lua's `lines` (no qualifier) means *all* open buffers; the
  current-buffer-only equivalent there is `blines`. Don't confuse `lines`
  and `blines` on fzf-lua — this registry's `lines` entry maps to `blines`.

Genuine gaps (no equivalent on that engine, not a naming difference):

- **telescope**: no `git_diff`, `lsp_declarations`, `undo`(-tree) picker.
- **fzf-lua**: no `resume` (fzf-lua has no picker-session resume concept);
  no dedicated "grep across open buffers" picker (its closest, `grep_curbuf`,
  is current-buffer-only, a different scope than snacks' `grep_buffers`).
- **snacks**: no `filetypes`, `spell_suggest` picker.
- **snacks-only extras**: `icons`, `lazy_specs` (lazy.nvim plugin specs),
  `gh_issue`, `gh_pr`, `projects`, `git_log_line` (per-line git blame/log),
  `grep_buffers` (grep across open/listed buffers), `notifications`
  (snacks' own notification history) — none of the other two engines ship
  an equivalent.

## Adding an entry

Add a `name = { telescope = ..., fzf = ..., snacks = ... }` row to
`M.REGISTRY` in `lua/pickers/builtins/init.lua`, using `false` for any
engine with no equivalent. Verify each function name actually exists on the
target module before adding it (don't guess from a changelog or docs page —
plugin APIs drift) — e.g.:

```lua
:lua print(type(require("telescope.builtin").your_name))
:lua print(type(require("fzf-lua").your_name))
:lua require("snacks"); print(type(require("snacks.picker").your_name))
```
