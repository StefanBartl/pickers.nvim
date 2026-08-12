# feature Log

[x] **`pick_item()` preview support.** Items passed to `engine_mod.pick_item()`
  may now be `Pickers.Item` tables `{ text, file? }` instead of plain strings —
  when at least one item in a call carries `file`, every engine attaches its
  own native file preview (telescope's `file_previewer`, snacks' existing
  default `preview.file` — already worked via its `select()` metatable
  passthrough, nothing to change there — and, since fzf is a separate process
  with no Lua object passthrough, a hidden per-line field previewed through a
  pure-Lua `opts.preview` callback rather than shelling out to `cat`/`bat`).
  `on_select` always receives back the exact original entry, string or table,
  never a re-parsed copy. Fully backward compatible: plain `string[]` callers
  (`sources/collection.lua`, `repos.lua`, `wkdbooks.lua`) are unaffected. First
  external consumer: filetree.nvim's `create_from_template` template picker.
  See `lua/pickers/engines/@types/init.lua` (`Pickers.Item`) and
  `docs/TESTS/pickers_spec.lua`'s `pick_item/*` checks.

- [x] **Smart action (combined grep + find files).** A third action alongside
  `files`/`grep`: `:Pickers <scope> smart` runs `rg` (content) and `fd`
  (filenames) for the same live query and merges both into ONE list ranked by a
  shared, engine-agnostic scorer (`lua/pickers/smart/`), so a filename hit and a
  content hit interleave by relevance instead of appearing as two blocks; a file
  matched by name that also contains matches floats to the top
  (`smart.weights.both`). Works with every scope and collection (per-collection
  `keys.smart`, `:{PascalName}Smart`), plus opt-in `cwd_smart`/`config_smart`/
  `folder_smart` keymaps. All three engines drive the same core: snacks via a
  sync live finder (order preserved under `sort_empty=false`), telescope via
  `new_dynamic` + `sorters.empty()`, fzf-lua via Lua-function live mode
  (`fzf ≥ 0.45`). Tunable via `smart = { weights, limit, timeout }`. See
  [docs/COMMANDS.md](COMMANDS.md#the-smart-action) and
  [docs/CONFIGURATION.md](CONFIGURATION.md#smart-combined-grep--find).
  - [x] **Frecency / recently-opened boost.** `smart.frecency = { enabled,
    weight, dir }`, opt-in and off by default. A new `pickers.smart.frecency`
    module records visits on `BufReadPost` (real, listed file buffers only),
    persisted as JSON under `stdpath("data")/pickers.nvim/frecency.json`
    (override via `dir`, same convention as `pickers.history`'s `dir`).
    `M.score()` combines log-dampened visit frequency with a bucketed
    recency weight (the same shape of heuristic telescope-frecency/browsers
    use) into a plain number; `pickers.smart.query` builds a per-query
    `abspath -> bonus` lookup table and threads it into `score.rank`'s new
    optional `frecency` param, keeping the scorer itself pure/side-effect-
    free (the lookup is computed once by the caller, not read from disk
    inside the scorer). See [docs/CONFIGURATION.md](CONFIGURATION.md#frecency-opt-in-ranking-boost).
  - [x] **Dedup grep rows down to one-per-file (best line).** `smart.
    dedup_grep_rows = false` (opt-in). `score.rank`'s new optional 7th
    param collapses multiple grep hits sharing an `abspath` down to the
    single highest-scoring line; a file's other matches are dropped
    entirely (a display-density choice, not a re-scoring). See
    [docs/CONFIGURATION.md](CONFIGURATION.md#dedup-grep-rows-opt-in).

- [x] **Optional engine ownership + auto-install.** `require("pickers")
  .plugin_spec({ engine = "snacks", own_engine = true })` — the shape the
  earlier design note below concluded "could actually work" — returns a
  ready lazy.nvim spec list (1 entry when `own_engine` is off/default, 2
  when on): the engine's own spec (`config()` calls `Snacks.setup()`/
  `telescope.setup()`/`fzf-lua`'s `setup()` with `opts.engine_opts`) plus
  pickers.nvim's own spec (depending on both `lib.nvim` and the engine,
  `config()` calls `pickers.setup(opts.picker_opts)` with `engine=` filled
  in). Called from the *user's own* plugin list at spec-BUILD time (not
  from `setup()`), since lazy.nvim resolves `dependencies` before any
  `config()` runs — `setup({ own_engine = true })` alone genuinely cannot
  install a missing engine, only configure one already present. No new
  `Pickers.Config` runtime field needed: the engine's own `config()` (which
  lazy.nvim runs before the dependent pickers.nvim's `config()`) already
  calls its `setup()`, so `pickers.setup()` itself needs nothing beyond the
  `engine=` it already supported. `own_engine` defaults to off (unchanged
  behaviour — pickers.nvim still never calls the engine's `setup()` on its
  own by default); `engine = "auto"` + `own_engine = true` errors
  immediately (at spec-build time) since there's no single engine to
  install. See `lua/pickers/plugin_spec.lua` and
  [docs/INSTALLATION.md](INSTALLATION.md#optional-engine-ownership--auto-install).
  - **Why this is harder than "just add a dependency":** lazy.nvim reads a
    plugin's static `dependencies` field *before* any `config()` function
    runs — so pickers.nvim's own spec can't conditionally depend on
    `folke/snacks.nvim` based on the `engine=` value passed into `setup()`,
    since that value isn't known until `config()` runs, which is *after*
    lazy has already resolved/installed dependencies.
  - **Why `own_engine` must default to off:** `docs/KEYMAPS.md` and
    `pickers.keys` already document, deliberately, that "pickers.nvim does
    not own `Snacks.setup()`" — so users keep full control over
    engine-specific config that has nothing to do with picking (snacks
    dashboard/explorer/notifier, telescope extensions, fzf-lua winopts, …)
    without a second competing `setup()` call fighting theirs. `own_engine =
    true` is a real, separate mode — self-contained convenience for users
    who want zero engine config of their own — not a replacement for
    today's "you own the engine, pickers.nvim just detects it" model, which
    stays the default.

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
- [x] **Native builtin pickers.** `:Pickers builtin <name>` — a registry of 52
  native pickers (git/LSP/help/vim-intrinsics/diagnostics/explorer/…)
  dispatched straight to the resolved engine's own function, name/capability-
  verified against the actual installed telescope/fzf-lua/snacks sources (not
  guessed from docs). See `lua/pickers/builtins/` and
  [docs/BUILTINS.md](BUILTINS.md) for the full parity matrix and documented
  per-engine gaps (e.g. `git_diff`/`lsp_declarations` have no telescope
  picker; `gh_issue`/`gh_pr`/`projects`/`git_log_line`/`notifications` are
  snacks-only).
  - [x] **File explorer / browser** (`explorer`, bound `<leader>.` by
    default). Reverses the earlier Phase-4 "explorer is out of scope, not a
    picker" call — the user explicitly wants one file-explorer keymap that
    follows the active engine like everything else. snacks: its native tree
    explorer picker source (`Snacks.picker.explorer`); telescope: the
    `telescope-file-browser.nvim` *extension* (dispatched via a new custom
    `run`-invoker on the registry Impl, since extensions aren't
    `telescope.builtin.*` functions — loaded on demand, warns if the
    extension isn't installed); fzf-lua: documented gap (no explorer picker).
  - [x] **Bug fix: snacks builtins never worked.** `ENGINE_MODULE.snacks` was
    `"snacks"`, so every `:Pickers builtin <name>` on the snacks engine (the
    user's default!) crashed — snacks picker functions live on `snacks.picker`,
    and the top-level `Snacks` metatable turns `Snacks.command_history` into a
    failing `require("snacks.command_history")`. Fixed to `"snacks.picker"`;
    guarded by `builtins.engine_module()` + a stubbed-dispatch regression test.
    (Never caught before because the run-path tests only exercised gap/missing-
    module branches, never a real snacks call.)
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
- [x] ~~**Selected-index overlay.**~~ **Removed.** The `experimental.selected_index`
  overlay (telescope-only) never worked reliably even after the row↔index
  fix, so the whole feature was pulled — code, config surface (`experimental`
  namespace and all), health check, docs, and tests. Passing
  `selected_index`/`experimental.selected_index` to `setup()` is now silently
  ignored (with a one-time `notify.warn`) rather than erroring.
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

- [x] Optional default keymap for the `system`/`repos` scopes. Three new
  opt-in (`nil` by default, same convention as the existing `cwd_files`)
  `keymaps.<name>` entries: `repos_files`, `repos_grep`, `system_files`. See
  `bindings/keymaps.lua`/`bindings/whichkey.lua` and
  [docs/KEYMAPS.md](KEYMAPS.md).
- [x] **`keys.open_background_show`.** Opt-in (off by default) addition to
  `open_background` (`<S-CR>`/`<C-o>`): on top of the existing silent
  `bufadd`+`bufload`, also point the window *behind* the picker at the
  selected entry — never focusing it, focus always stays in the picker.
  telescope/snacks resolve that window from the picker instance
  (`original_win_id`/`picker.main`); fzf-lua from its cached invocation
  context (`fzf-lua.utils.__CTX().winid`), best-effort, no line positioning.
  See `lua/pickers/entry_actions/open_background.lua` and
  [docs/KEYMAPS.md](KEYMAPS.md#in-picker-keys-preview-scroll--history--entry-actions).
- [x] **Declarative `mappings` table with per-entry engine override.**
  `mappings = { [name] = { lhs, engine? } }` (empty by default) — a new
  `lua/pickers/mappings/` module resolves `name` against a single unified
  table: `pickers.builtins.names()` for builtins, and `<scope>_files` /
  `<scope>_grep` / `<scope>_smart` / `<scope>_find_all` for scope×action
  (any built-in scope or collection; `dir` unsupported, same limitation as
  the "find all" escape hatch). Threaded `pickers.command.handle`'s
  `opts.engine` straight into `pickers.engines.load(opts.engine)` (already
  had the fallback-to-auto-detect scaffolding) — a one-line change, since
  every internal routing helper already took an already-resolved
  `engine_mod`, not a name. Builtins pre-resolve the requested engine via
  `engines.load(requested)` too (rather than passing the raw name straight
  to `builtins.run`'s `engine_name` param, which does NOT itself re-verify
  availability). An engine named but not installed falls back to the
  default (never a dead keymap); an unresolvable name or malformed entry is
  skipped with a warning, never a throw. Does **not** supersede the fixed
  `keymaps.*` fields — both stay, `mappings` is a second, more flexible
  surface. See [docs/KEYMAPS.md](KEYMAPS.md#declarative-mappings-per-entry-engine-override).

## Feature-parity audit vs. the pre-pickers.nvim config

2026-07-22: compared the old standalone config (before pickers.nvim existed —
plain fzf-lua + telescope.nvim + snacks.nvim, each configured/keymapped
separately) against the current scope/builtin/keys registries, to find
anything that quietly never got ported plus anything from the earlier
migration ([[pickers-config-migration]] phases 1-4, see git history) worth
re-confirming.

**Already covered, no action needed** — `custom.find_config` → `config`
scope; `custom.find_in_folder` → `folder` scope (plus `dir path=<dir>` for a
non-interactive explicit path, which the old command also supported);
`custom.repo_pickers` (+ WkdBooks) → `repos` scope + `collections` (WkdBooks
is the doc's own example collection); `custom.picker_fd_depth` → `dir` scope
numeric nav (`:Pickers dir 2 files`); `usrcmds.search_all_drives` → `drives`
scope, and more correct than the original (works on native Windows; the old
one only handled WSL/POSIX via `df`/mount-letter probing); the old config's
blocking `vim.fn.input()` prompt *before* opening a grep picker doesn't
recur here since `:Pickers … grep` always opens a live picker directly; the
old config resolved "auto" engine (fzf → telescope, snacks never considered)
separately in each of 5 custom utilities, all replaced by pickers.nvim's one
`engine="auto"` resolution.

- [x] **"Find all" escape hatch.** `:Pickers <scope|collection> files all`
  forces `hidden`+`no_ignore`+`follow` for that one search only, regardless
  of configured `find.*` defaults — matching the old `<leader>fa` behaviour,
  now generalised to every scope/collection (not just cwd). Threaded as an
  optional 3rd arg through `pickers.actions.files.run` (merged force on top
  of `cfg.find`/`source.find`) and an optional `force_find_all` flag through
  `pickers.command`'s internal routing helpers; `pickers.command.dispatch`
  (the public entry point used by `pickers.last`/`dir` scope) and `dir`
  scope itself are unaffected — the escape hatch is one-off by design, so
  `:PickersRepeat` replaying a recorded {action, source} without it is
  correct, not a gap. New opt-in `keymaps.cwd_find_all` (nil by default,
  same convention as `cwd_files`). See `lua/pickers/command/init.lua`,
  `lua/pickers/actions/files.lua`.
- [x] **Split/vsplit/tab as a unified `keys` action.** `keys = { split,
  vsplit, tab }`, default `<C-s>`/`<C-v>`/`<C-t>` across all three engines
  (matching the old fzf-lua config). Wired the same shape as
  `preview_scroll_*`/`history_*`/`preview_toggle`: telescope via
  `actions.select_horizontal`/`select_vertical`/`select_tab`, snacks via its
  own matching action names (`split`/`vsplit`/`tab`, passthrough like
  preview-scroll/history), fzf-lua left unpatched since `ctrl-s`/`ctrl-v`/
  `ctrl-t` are fixed/native there already (not a capability gap). No new
  pickers.nvim-side logic. See `lua/pickers/keys/` and
  [docs/KEYMAPS.md](KEYMAPS.md#in-picker-keys-preview-scroll--history--entry-actions).
- [x] **Grep exclude globs.** `find.exclude` now also applies to live grep
  (`pickers.actions.grep` merges `source.find`/`cfg.find` and forwards it as
  `opts.find`, same pattern as `pickers.actions.files`), each engine turning
  it into its own correctly-escaped `-g '!glob'` rg flags: raw/unescaped for
  telescope and snacks (argv lists, no shell), `vim.fn.shellescape`d for
  fzf-lua (`rg_opts` is a shell string there). The `smart` action's own rg
  call (`smart/search.lua`'s `M.rg_args`, exported for unit testing) got the
  same fix. See `lua/pickers/actions/grep.lua`,
  `lua/pickers/engines/{telescope,fzf,snacks}.lua`.
- [x] _(optional, low value)_ **Long-path display shortening.** `display =
  { path_shorten = false }`, opt-in, purely cosmetic. Pass-through to each
  engine's own native mechanism: telescope gets `path_display = {
  "shorten" }`, fzf-lua gets `path_shorten = true` (verified against both
  plugins' installed sources — `telescope/utils.lua`'s `path_display`
  handling, `fzf-lua/make_entry.lua`'s `opts.path_shorten`). snacks is
  intentionally left unwired: it already truncates the displayed path to
  fit the available column width by default
  (`Snacks.picker.util.truncpath`), so there's nothing to opt into there.
  See [docs/CONFIGURATION.md](CONFIGURATION.md#long-path-display-shortening).

**Explicit non-goals** (recommend documenting rather than building):
file-browser/explorer parity — telescope-file-browser and fzf-lua's explorer
mode have no pickers.nvim equivalent, but snacks' own `explorer()` was
already ruled out of scope in Phase 4 ("not a picker"); the consistent call
is the same for the other two, not building a partial file manager just for
telescope/fzf. `custom.open` (`:Open <url/path>` → external apps) isn't a
picker feature at all. `usrcmds.system_find`'s `.ext`/`/path` mini query
language isn't worth porting as-is — the old implementation was itself
broken (its keymap called a non-existent function) and hardcoded a personal
POSIX path; today's plain-prompt `system` scope is simpler and isn't broken.


## Quality / infrastructure

- [x] which-key labels for pickers keymaps (guarded, no hard dep) — see `bindings/whichkey.lua`.
- [x] Cross-platform audit of path handling / `shellescape` across sources and
  engines. Two passes: (1) sources/engines as they stood before `pickers.keys`/
  `builtins`/`last`/`result_count`/entry_actions find-overrides existed — found
  `pickers.sources.system`'s "/" fallback breaking "systemwide search" on
  native Windows (fixed via `pickers.sources.drives.get_roots()`/
  `is_windows()`), and `engines/{telescope,snacks}.lua`'s `pick_dir` hardcoding
  `fd` with no `fdfind` fallback (fixed). (2) A follow-up pass specifically
  covering everything added since — found `entry_actions/extract/fzf.lua`
  icon-stripping already-clean `.path`/`.filename` fields, truncating any path
  with a space near the start (not Windows-exclusive, but far more common
  there — `Program Files`, `Users\<Full Name>`); fixed.
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



