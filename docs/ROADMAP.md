# Roadmap — pickers.nvim

Planned and potential features, commands, keymaps and autocmds. Nothing here is
a promise; it is a backlog of ideas ordered roughly by usefulness.

## Features

- [x] **Ignore/hidden/follow control.** `find = { hidden, no_ignore, follow, exclude }`
  in `setup()`, honoured by both engines for the built-in file pickers.
- [x] **Exclude globs.** `find.exclude` (list of glob patterns) is passed to the
  engine command.
- [ ] **Per-scope overrides.** Currently `find` is global; allow per-collection /
  per-scope find overrides.
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

## Checklist audit — open items

Distilled from `docs/CHECKLISTS/` (applied Lua/Neovim checklists). Ordered by value.

- [x] Use `lib.nvim.usercmd` instead of raw `nvim_create_user_command`
  (`plugin/pickers.lua`, `lua/pickers/bindings/util.lua`), with raw fallback.
- [x] Use `lib.nvim.autocmd` + a named augroup (`pickers.nvim`) instead of raw
  `nvim_create_autocmd` (`lua/pickers/bindings/autocmds.lua`), with raw fallback.
- [x] Add `stylua.toml` + `.luacheckrc` and a GitHub Actions CI (advisory lint +
  `nvim -l docs/TESTS/pickers_spec.lua` as the gate).
- [ ] Flip CI linters (stylua/luacheck) from advisory to gating once triaged.
- [x] Structured error types — `lua/pickers/error.lua` (`Pickers.Error`/`ErrorKind`
  + `safe_call`), adopted in the command dispatcher.
- [x] Per-subdirectory `@types` folders (engines/sources/command/config) replacing
  the single central one; root `@types` is now an index.
