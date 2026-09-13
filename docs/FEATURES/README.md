# Features

Picker configurations sprawl. Every source you want — files here, grep there,
the repo list, the git branches — ends up as its own function, its own keymap
and its own idea of what "hidden files" means, and none of it survives swapping
the engine underneath. This plugin makes it one grammar instead.

| Area | Does |
| --- | --- |
| **One command** | `:Pickers <scope> <action>` — pick either half interactively, or name both. Every argument completes with `<Tab>` |
| **Scopes** | Where to look: `cwd`, `config`, `folder`, `repos`, `wkdbooks`, `system`, `drives`, and `dir` with its own navigation forms — a depth, a git root, an alias, or an explicit path |
| **Actions** | What to do there: `files`, `grep`, and `smart`, plus per-call flags (`hidden`, `follow`, `all`) that apply to that call only |
| **Native pickers** | `:Pickers builtin <name>` reaches the engine's own pickers — git branches, log, status and diff, every LSP list, diagnostics, help, marks, buffers, registers — dispatching straight into the resolved engine |
| **Engines** | telescope.nvim, fzf-lua or snacks.nvim, auto-detected. The grammar does not change when the engine does |
| **Collections** | Your own named scopes, so a set of directories you work in becomes one word |

pickers.nvim consolidates what used to be seven separate picker modules into
one plugin: a single `:Pickers` command over three interchangeable engines
(telescope.nvim, fzf-lua, snacks.nvim), plus everything that has to be
translated per engine so the same key does the same thing in all three.

This folder is the reader-facing catalogue. It is grouped by theme rather than
by the source layout — a feature that spans `actions/`, `engines/` and `keys/`
appears once, where a reader would look for it.

- **[ENGINES](ENGINES.md)** — which backend runs a picker, how it is resolved,
  and the per-call override.
- **[SCOPES](SCOPES.md)** — *where* a picker searches: the eight built-in
  scopes, `dir`'s navigation forms, and user-defined collections.
- **[ACTIONS](ACTIONS.md)** — *what* it searches for: `files`, `grep`, and the
  merged-and-ranked `smart`, plus the search-flag escalation.
- **[BUILTINS](BUILTINS.md)** — the native pickers (git, LSP, help, …) that
  are not a scope × action.
- **[KEYS](KEYS.md)** — launching a picker, and the keys that act *inside* one.
- **[REFINE](REFINE.md)** — `pickers.refine`, the engine-agnostic filter-stack
  building block for narrowing a big result list by stacked clauses.
- **[UI](UI.md)** — the pickers that pick a picker, the result count, path
  shortening.
- **[PERSISTENCE](PERSISTENCE.md)** — history, frecency, and reopening what you
  just had.
- **[IMAGES](IMAGES.md)** — png/jpg entries drawn as pictures in the preview
  window, and PDFs as their first page, via images.nvim.

Reference documentation lives one level up and is not repeated here:
[`commands.md`](../commands.md) for the full argument grammar,
[`configuration.md`](../configuration.md) for every option,
[`builtins.md`](../builtins.md) for the per-engine parity matrix,
[`keymaps.md`](../keymaps.md) for the key tables,
[`collections.md`](../collections.md) for collection config, and
[`BINDINGS.md`](../BINDINGS.md) for the binding cheatsheet.

> The per-feature development log this catalogue was written from is kept at
> [`../CHANGELOG.md`](../CHANGELOG.md) — what changed and when, in the order it
> happened. This folder answers "what does it do"; that file answers "when did
> it start doing that".
