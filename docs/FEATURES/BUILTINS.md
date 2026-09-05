# Native pickers

Not everything worth picking is a scope × action. Git branches, every LSP list,
diagnostics, help tags, marks, buffers, registers — all of those already exist
inside each engine, under three different names and with three different
capability gaps.

## The registry

`:Pickers builtin <name>` dispatches straight into the resolved engine's own
picker function. Every registered name is tab-completed and engine-agnostic
at the call site:
one name maps to `Snacks.picker.<fn>()`, `telescope.builtin.<fn>()` or
`require("fzf-lua").<fn>()` depending on which engine is live.

This deliberately **bypasses** pickers.nvim's own roots and find-flag
resolution. `:Pickers cwd files` goes through `actions/`; `:Pickers builtin
files` calls the engine's function with whatever opts you pass, exactly as if
you had called it yourself. Two different jobs, kept visibly separate.

- **Module:** [`builtins/init.lua`](../../lua/pickers/builtins/init.lua)
- **Usercmds:** `:Pickers builtin <name>`
- **Keymaps:** `explorer` (`<leader>.` by default) opens the active engine's
  file explorer — snacks' tree explorer, telescope-file-browser, …

## Gaps are answers, not omissions

The three engines disagree on **naming** (snacks `recent`, telescope
`oldfiles`, fzf-lua `oldfiles`) and on **capability** — telescope has no
dedicated git-diff-hunks picker and no `lsp_declarations`, neither telescope
nor fzf-lua wraps GitHub issues/PRs or per-line git log.

Every cell in the parity matrix was verified against the installed plugin
sources rather than their documentation. An empty cell is a real gap in that
engine, and hitting one tells you which engines *do* support that name instead
of failing silently.

- **Module:** [`builtins/init.lua`](../../lua/pickers/builtins/init.lua)
- **Reference:** the full name list and per-engine matrix in
  [`docs/builtins.md`](../builtins.md)
