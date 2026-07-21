# Native pickers (`:Pickers builtin`)

```
:Pickers builtin <name>
```

Dispatches straight into the currently resolved engine's own native picker —
`Snacks.picker.<fn>()` / `telescope.builtin.<fn>()` / `require("fzf-lua").<fn>()`
— for things that aren't a pickers.nvim scope×action (git, LSP, help, …). This
is different from `:Pickers cwd files` / `:Pickers cwd grep` etc.: those go
through pickers.nvim's own roots/find-flags resolution (`lua/pickers/actions/`);
`builtin` bypasses that entirely and just calls the engine's function with
whatever opts you pass, same as calling it yourself.

Tab-completes over every registered name (`:Pickers builtin <Tab>`). See
`lua/pickers/builtins/init.lua` for the registry itself.

## Why some cells are empty

Each row below was verified against the actual installed plugin sources (not
assumed from docs), because the three engines frequently disagree on both
**naming** (snacks `recent` / telescope `oldfiles` / fzf-lua `oldfiles`) and
**capability** (telescope has no dedicated git-diff-hunks picker, no
`lsp_declarations` picker, and neither telescope nor fzf-lua wrap GitHub
issues/PRs or per-line git log). An empty cell is a real gap in that engine,
not an oversight — `:Pickers builtin <name>` warns you which engines *do*
support it when you hit one.

| Name | snacks | telescope | fzf-lua |
|---|---|---|---|
| `command_history` | `command_history` | `command_history` | `command_history` |
| `recent` | `recent` | `oldfiles` | `oldfiles` |
| `projects` | `projects` | — | — |
| `notifications` | `notifications` | — | — |
| `buffers` | `buffers` | `buffers` | `buffers` |
| `git_files` | `git_files` | `git_files` | `git_files` |
| `marks` | `marks` | `marks` | `marks` |
| `jumps` | `jumps` | `jumplist` | `jumps` |
| `registers` | `registers` | `registers` | `registers` |
| `quickfix` | `qflist` | `quickfix` | `quickfix` |
| `loclist` | `loclist` | `loclist` | `loclist` |
| `autocmds` | `autocmds` | `autocommands` | `autocmds` |
| `highlights` | `highlights` | `highlights` | `highlights` |
| `filetypes` | — | `filetypes` | `filetypes` |
| `spell_suggest` | — | `spell_suggest` | `spell_suggest` |
| `search_history` | `search_history` | `search_history` | `search_history` |
| `treesitter` | `treesitter` | `treesitter` | `treesitter` |
| `resume` | `resume` | `resume` | — |
| `undo` | `undo` | — | `undotree` |
| `icons` | `icons` | — | — |
| `lazy_specs` | `lazy` | — | — |
| `grep_word` | `grep_word` | `grep_string` | `grep_cword` |
| `diagnostics` | `diagnostics` | `diagnostics` | `diagnostics_workspace` |
| `diagnostics_buffer` | `diagnostics_buffer` | `diagnostics` (`bufnr=0`) | `diagnostics_document` |
| `git_branches` | `git_branches` | `git_branches` | `git_branches` |
| `git_log` | `git_log` | `git_commits` | `git_commits` |
| `git_log_file` | `git_log_file` | `git_bcommits` | `git_bcommits` |
| `git_log_line` | `git_log_line` | — | — |
| `git_status` | `git_status` | `git_status` | `git_status` |
| `git_stash` | `git_stash` | `git_stash` | `git_stash` |
| `git_diff` | `git_diff` | — | `git_diff` |
| `gh_issue` | `gh_issue` | — | — |
| `gh_issue_all` | `gh_issue` (`state="all"`) | — | — |
| `gh_pr` | `gh_pr` | — | — |
| `gh_pr_all` | `gh_pr` (`state="all"`) | — | — |
| `lines` | `lines` | `current_buffer_fuzzy_find` | `blines` |
| `grep_buffers` | `grep_buffers` | `live_grep` (`grep_open_files=true`) | `lines` |
| `commands` | `commands` | `commands` | `commands` |
| `keymaps` | `keymaps` | `keymaps` | `keymaps` |
| `man` | `man` | `man_pages` | `manpages` |
| `help` | `help` | `help_tags` | `helptags` |
| `colorschemes` | `colorschemes` | `colorscheme` | `colorschemes` |
| `lsp_definitions` | `lsp_definitions` | `lsp_definitions` | `lsp_definitions` |
| `lsp_declarations` | `lsp_declarations` | — | `lsp_declarations` |
| `lsp_references` | `lsp_references` | `lsp_references` | `lsp_references` |
| `lsp_implementations` | `lsp_implementations` | `lsp_implementations` | `lsp_implementations` |
| `lsp_type_definitions` | `lsp_type_definitions` | `lsp_type_definitions` | `lsp_typedefs` |
| `lsp_incoming_calls` | `lsp_incoming_calls` | `lsp_incoming_calls` | `lsp_incoming_calls` |
| `lsp_outgoing_calls` | `lsp_outgoing_calls` | `lsp_outgoing_calls` | `lsp_outgoing_calls` |
| `lsp_symbols` | `lsp_symbols` | `lsp_document_symbols` | `lsp_document_symbols` |
| `lsp_workspace_symbols` | `lsp_workspace_symbols` | `lsp_workspace_symbols` | `lsp_workspace_symbols` |

`lines`/`grep_buffers` deliberately aren't `files`/`grep` — those already exist
as `:Pickers cwd files` / `:Pickers cwd grep` and don't need a builtin entry.

## Notes on specific gaps

- **`projects`**: snacks-only. If you need this across engines, a pickers.nvim
  [collection](COLLECTIONS.md) rooted at `repos_dir` covers most of the same
  need (browse repos, jump to files/grep) without depending on snacks.
- **`gh_issue*` / `gh_pr*`**: no core telescope.builtin or fzf-lua equivalent.
  (A separate `telescope-github.nvim` extension exists if you want GitHub
  pickers on telescope specifically — outside pickers.nvim's scope, since it's
  a third plugin, not part of telescope core.)
- **`git_log_line`**: per-line `git log -L` history. Snacks-only; neither
  telescope nor fzf-lua expose a line-scoped git-log picker.
- **`git_diff`** (hunks): telescope has no dedicated hunks picker — only
  per-commit diff previews on `git_commits`/`git_bcommits`.
- **`lsp_declarations`**: telescope has no picker for `textDocument/declaration`
  (only the non-list `vim.lsp.buf.declaration()`).
- **`resume`**: fzf-lua has no picker-session resume concept.
- **`undo`**: telescope has no undo-tree picker.
- **`filetypes` / `spell_suggest`**: snacks has no equivalent picker for either.
- **`icons` / `lazy_specs`**: snacks-only (icon picker; lazy.nvim plugin specs)
  — neither telescope nor fzf-lua ship anything comparable.
- **`diagnostics_buffer`**: telescope reuses the same `diagnostics` function as
  workspace-wide, scoped via `opts = { bufnr = 0 }` — not a separate function
  name, unlike fzf-lua's `diagnostics_document` / snacks' `diagnostics_buffer`.

## Passing opts

`opts` (when supported by `run()`'s second argument) go straight to the
resolved engine's function, on top of the entry's own defaults (yours win):

```lua
require("pickers.builtins").run("git_log_file", { cwd = "/path/to/repo" })
```
