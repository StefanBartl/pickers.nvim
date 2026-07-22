# Roadmap — pickers.nvim

Planned and potential features, commands, keymaps and autocmds. Nothing here is
a promise; it is a backlog of ideas ordered roughly by usefulness.

## Features

- [x] **Ignore/hidden/follow control.** `find = { hidden, no_ignore, follow, exclude }`
  in `setup()`, honoured by both engines for the built-in file pickers.
- [x] **Exclude globs.** `find.exclude` (list of glob patterns) is passed to the
  engine command.
- [x] **Unified in-picker keys.** `keys = { enable, preview_scroll_*, history_*,
  create_file, open_background, preview_toggle }` in `setup()` — preview
  scrolling, native history navigation, the create_file/open_background entry
  actions, and a preview-toggle keymap all share one config surface. Preview
  scroll/history/preview_toggle are patched globally into telescope/fzf-lua
  (snacks via the exported `keys.snacks_win()`); create_file/open_background
  stay merge-it-yourself, like before, since they run pickers.nvim logic
  rather than a built-in engine action. fzf-lua is a documented capability
  gap for most of these (no horizontal preview scroll, fixed fzf-native
  history, fixed ctrl-a/ctrl-o/shift-enter entry actions) — `preview_toggle`
  is the one exception where fzf-lua/snacks are *already covered natively*
  (`<F4>`/`<A-p>`) and don't need pickers.nvim at all; it's opt-in and
  telescope-only, filling the one real gap (telescope ships the action,
  `actions.layout.toggle_preview`, but binds no default key to it). See
  `lua/pickers/keys/`, `lua/pickers/entry_actions/`, and
  [docs/KEYMAPS.md](KEYMAPS.md#in-picker-keys-preview-scroll--history--entry-actions).
- [x] **Native builtin pickers.** `:Pickers builtin <name>` — a registry of 51
  native pickers (git/LSP/help/vim-intrinsics/diagnostics/…) dispatched
  straight to the resolved engine's own function, name/capability-verified
  against the actual installed telescope/fzf-lua/snacks sources (not guessed
  from docs). See `lua/pickers/builtins/` and [docs/BUILTINS.md](BUILTINS.md)
  for the full parity matrix and documented per-engine gaps (e.g. `git_diff`/
  `lsp_declarations` have no telescope picker; `gh_issue`/`gh_pr`/`projects`/
  `git_log_line`/`notifications` are snacks-only).
  - [x] A user config's own snacks-only picker keymaps (git/LSP/search/…, ~31
    active bindings) migrated to call through `pickers.command.handle`
    (files/grep) / `pickers.builtins.run` (everything else) instead of
    `snacks.picker.*` directly — same keys, engine-agnostic now.
  - [x] A user config's `:SnacksXxx` usercommands (~20 additional pickers with
    no active keymap — buffers/git_files/marks/jumps/registers/quickfix/
    loclist/autocmds/highlights/filetypes/spell_suggest/search_history/
    treesitter/resume/undo/icons/lazy_specs/grep_word/diagnostics/
    diagnostics_buffer) are now covered by the registry (51 entries total, up
    from the initial 31). The `:SnacksXxx`/`:Snacks <cat> <sub>` usercommand
    layer itself (`config/snacks/usrcmds/` in the user's config) was deleted
    as a result — every command it exposed has an engine-agnostic
    `:Pickers builtin <name>` equivalent now.
- [x] **Per-collection find overrides.** `collections[].find` (partial
  `Pickers.FindOpts`) overrides the global `find` defaults for that
  collection's `files` action — merged, not replaced, so unset fields keep
  the global value. Grep is unaffected (no `find` flags there). Built-in
  scopes (cwd/config/folder/repos/wkdbooks/system/drives) stay global-only —
  they aren't user-configurable objects the way collections are, so there's
  no natural per-scope config surface to attach an override to. See
  `pickers.actions.files`, `pickers.sources.collection`, and
  [docs/COLLECTIONS.md](COLLECTIONS.md#find-override).
- [x] **Result count.** `result_count = { enabled }` in `setup()` — live match
  count in the prompt title (e.g. "Find Files (128)"). Telescope-only,
  disabled by default; fzf-lua/snacks already show a position/total counter
  natively. Polls the entry manager every 150ms (result counts can change
  asynchronously as a live finder streams in matches, with no CursorMoved/
  TextChanged to hang an update off of). See `lua/pickers/result_count/` and
  [docs/CONFIGURATION.md](CONFIGURATION.md#result-count). Preview toggle is
  also done — see `keys.preview_toggle` above.
- [x] **Remember last scope/action.** `:PickersRepeat` reopens the most
  recently dispatched {action, source} pair, in-memory only for the current
  session. `pickers.command.dispatch` is the single choke point every scope
  (standard, collection, `dir`) routes through, so `pickers.last.set()` is
  called there once rather than duplicated per-scope — `pickers.actions.dir`
  used to bypass it with its own inline files/grep branch, now delegates to
  `pickers.command.dispatch` instead. See `lua/pickers/last.lua` and
  [docs/COMMANDS.md](COMMANDS.md#pickersrepeat).
- [x] **Selected-index overlay.** `selected_index = { enabled, position, highlight, toggle_key }`
  in `setup()` — shows the index of the selected entry in the results buffer.
  Telescope-only, disabled by default. Native port of the (now retired)
  `telescope-selected-index.nvim` companion plugin — see `lua/pickers/selected_index/`.
  `toggle_key` registers an in-picker keymap to switch it on/off live for an
  already-open results list, independent of the `enabled` default.
  - [ ] Move config under an `experimental = { selected_index = {...} }` namespace
    (opt-in, signals it's not yet stable).
  - [ ] Indexing is wrong both on initial open and after prompt updates. Investigate
    re-numbering the overlay after the results list actually finishes updating
    (e.g. debounced, triggered off a results-changed event) instead of the current
    approach — or another mechanism if a better one exists.
- [x] **Native picker history.** `history = { enabled, fzf_scope, dir, limit }` in
  `setup()` — file-based history under `stdpath("data")/pickers.nvim/history`,
  disabled by default. See `lua/pickers/history/`. `fzf_scope` (`"plugin"` |
  `"global"` | `"patch"`) only affects fzf-lua, where each provider call can carry
  its own `--history` file. Telescope's history is a process-wide singleton with no
  per-call override, so enabling it always behaves like a global default there
  regardless of `fzf_scope` — a Telescope architecture limitation, not a choice
  made here.
  - [x] ~~Snacks history~~ — investigated and closed as N/A, not a gap. Snacks'
    picker history is built-in and unconditional (created in `Picker.new`, fixed
    path under `stdpath("data")/snacks/`, no `enabled`/`dir`/`limit` field
    anywhere in its opts schema) — there is nothing to opt into or patch.
    `cfg.history.*` simply doesn't apply to snacks; `:checkhealth pickers` now
    says so explicitly. Documented in docs/CONFIGURATION.md and the
    `pickers.history` module @brief.

## Commands

- [x] `:PickersRepeat` — reopen the most recently dispatched action (same
  resolved scope/root/action). See "Remember last scope/action" above.
- [x] `:PickersResume` — reopen the last picker with the last query, i.e. the
  engine's own native resume/history-of-open-pickers feature. A thin wrapper
  over `pickers.builtins.run("resume")` (the registry already had a `resume`
  entry: telescope + snacks, fzf-lua has no resume concept). Distinct from
  `:PickersRepeat`, which replays pickers.nvim's own last resolved
  scope/action from scratch (empty prompt) rather than the engine's session
  history (prompt text included).
- [x] `:PickersScopes` — lists every scope :Pickers can resolve (built-in
  scopes with a one-line description, plus every collection with its root
  dir) via `notify.info`. See `pickers.ui.scope_picker.list()` (exported,
  the same list the interactive scope picker uses) and
  [docs/COMMANDS.md](COMMANDS.md#pickersscopes).

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

Distilled from `docs/ROADMAP/` audit files (applied Lua/Neovim checklists). Ordered by value.

- [x] Use `lib.nvim.usercmd` instead of raw `nvim_create_user_command`
  (`plugin/pickers.lua`, `lua/pickers/bindings/util.lua`), with raw fallback.
- [x] Use `lib.nvim.autocmd` + a named augroup (`pickers.nvim`) instead of raw
  `nvim_create_autocmd` (`lua/pickers/bindings/autocmds.lua`), with raw fallback.
- [x] Add `stylua.toml` + `.luacheckrc` and a GitHub Actions CI (advisory lint +
  `nvim -l docs/TESTS/pickers_spec.lua` as the gate).
- [x] Flip CI linters (stylua/luacheck) from advisory to gating — repo is
  stylua-formatted and luacheck-clean (0 warnings).
- [x] Structured error types — `lua/pickers/error.lua` (`Pickers.Error`/`ErrorKind`
  + `safe_call`), adopted in the command dispatcher.
- [x] Per-subdirectory `@types` folders (engines/sources/command/config) replacing
  the single central one; root `@types` is now an index.
