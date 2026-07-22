# Roadmap — pickers.nvim

Planned and potential features, commands, keymaps and autocmds. Nothing here is
a promise; it is a backlog of ideas ordered roughly by usefulness.

## Features

- [ ] _(low priority, needs a design decision)_ **Optional engine ownership +
  auto-install.** `require("pickers").setup({ engine = "snacks", own_engine =
  true })` (opt-in, default `false` — today's behaviour, unchanged) would make
  pickers.nvim install *and* configure the chosen engine itself instead of the
  user declaring/configuring it in their own lazy spec.
  - **Why this is harder than "just add a dependency":** lazy.nvim reads a
    plugin's static `dependencies` field *before* any `config()` function
    runs — so pickers.nvim's own spec can't conditionally depend on
    `folke/snacks.nvim` based on the `engine=` value passed into `setup()`,
    since that value isn't known until `config()` runs, which is *after*
    lazy has already resolved/installed dependencies. A `require("pickers")
    .plugin_spec({ engine = "snacks", own_engine = true })` helper — called
    from the *user's own* plugin list, at spec-build time, so the engine
    choice is known early enough — is the shape that could actually work:
    it returns a ready lazy spec entry (or entries) with the right
    `dependencies` and a `config()` that also calls `Snacks.setup()` /
    `telescope.setup()` / `fzf-lua.setup()` on the user's behalf.
  - **Why `own_engine` must default to off:** `docs/KEYMAPS.md` and
    `pickers.keys` already document, deliberately, that "pickers.nvim does
    not own `Snacks.setup()`" — so users keep full control over
    engine-specific config that has nothing to do with picking (snacks
    dashboard/explorer/notifier, telescope extensions, fzf-lua winopts, …)
    without a second competing `setup()` call fighting theirs. `own_engine =
    true` would be a real, separate mode — self-contained convenience for
    users who want zero engine config of their own — not a replacement for
    today's "you own the engine, pickers.nvim just detects it" model, which
    stays the default.
  - `engine = "auto"` + `own_engine = true` is probably out of scope (which
    engine would it even install?) — `own_engine` most likely only makes
    sense paired with an explicit `engine`.

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
- [ ] _(low priority)_ **Declarative `mappings` table with per-entry engine
  override.** One flat config surface listing every picker action by name,
  each pointing at an lhs and, optionally, the engine to run it on — where a
  per-entry engine **overrides** the global default engine just for that
  mapping. An engine named but not installed falls back to the default engine
  (never a dead keymap). Sketch:
  ```lua
  mappings = {
    find_files = { "<leader>ff", "telescope" }, -- always telescope
    grep_cwd   = { "<leader>gr" },               -- active/default engine
    explorer   = { "<leader>.",  "snacks" },     -- always snacks
    some       = { "<leader>sm", "fzf" },        -- always fzf (→ default if fzf absent)
  }
  ```
  Names would resolve against a single action table unifying the scope×action
  dispatch (`find_files`/`grep_cwd`/…) *and* the builtins registry
  (`explorer`/`git_status`/…), so any picker is bindable this way. Would
  eventually supersede the fixed `keymaps.<name>` fields (which are
  engine-agnostic and can't override the engine per-key). Plumbing: the
  scaffolding for per-call engine override already exists at the bottom
  (`pickers.engines.load(requested)` takes an override; `pickers.builtins.run`
  takes an `engine_name`), but `pickers.command.handle`/`.dispatch` currently
  resolve the engine internally with no override arg — threading `requested`
  through those is the main work. The fixed `keymaps` block stays as-is
  until/unless this lands.

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

- [ ] **"Find all" escape hatch.** Old `<leader>fa` force-enabled
  hidden+no_ignore+follow for one search regardless of configured defaults.
  `find.*` is global/setup-time only today — no per-invocation override.
- [ ] **Split/vsplit/tab as a unified `keys` action.** Old fzf-lua config
  bound `ctrl-s`/`ctrl-v`/`ctrl-t` to split/vsplit/tabedit. All three engines
  already ship the underlying primitive natively (telescope
  `actions.select_horizontal`/`select_vertical`/`select_tab`, snacks
  `actions.split`/`vsplit`/`tab`, fzf-lua's builtin `ctrl-s`/`ctrl-v`/
  `ctrl-t`) — this would only need a new unified key name + `keys.patch()`
  wiring, the same shape as `preview_scroll_*`/`history_*`, no new
  pickers.nvim-side logic (unlike `create_file`/`open_background`).
- [ ] **Grep exclude globs.** `find.exclude` only applies to the file
  listing, not live grep — the old fzf-lua/telescope grep configs each had
  their own hand-rolled `--glob '!...'` exclude list. Today this relies on
  `.gitignore` alone; fine for most repos, a documented gap for
  ignored-but-noisy non-git dirs.
- [ ] _(optional, low value)_ Long-path display shortening (old telescope
  `path_display/`old fzf `entry_maker`) — cosmetic only, no functional gap.

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

## Autocmds

- [ ] None planned beyond the existing `VimEnter` default-binding fallback.

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
