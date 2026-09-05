# Features

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
