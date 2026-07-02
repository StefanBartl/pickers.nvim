# Roadmap — pickers.nvim

Planned and potential features, commands, keymaps and autocmds. Nothing here is
a promise; it is a backlog of ideas ordered roughly by usefulness.

## Features

- [ ] **Per-source ignore/hidden control.** Let the user opt into
  `--hidden` / `--no-ignore` / custom exclude globs per scope (config, cwd,
  folder). Motivated by config-file pickers drowning in generated data dirs.
- [ ] **Exclude globs in config.** A `exclude` option (list of glob patterns)
  merged into the engine command for every scope.
- [ ] **Result-count / preview toggles** surfaced through `setup()`.
- [ ] **Remember last scope/action** for a `:Pickers` repeat command.

## Commands

- [ ] `:PickersResume` — reopen the last picker with the last query.
- [ ] `:PickersScopes` — list all resolvable scopes (built-ins + collections).

## Keymaps

- [ ] Optional default keymap for the `system` scope (currently command-only).
- [ ] Optional default keymap for `repos` files/grep.

## Autocmds

- [ ] None planned beyond the existing `VimEnter` default-binding fallback.

## Quality / infrastructure

- [x] which-key labels for pickers keymaps (guarded, no hard dep) — see `bindings/whichkey.lua`.
- [ ] Cross-platform audit of path handling / `shellescape` across sources and engines.
- [x] Fix `system` source passing the search path as fd's first positional
  (interpreted as a pattern instead of a path on Windows).
- [x] `docs/TESTS/**` for command parsing, collection normalisation and PascalCase conversion.
