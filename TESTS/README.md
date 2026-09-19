# Tests

Lightweight, framework-free unit tests for pickers.nvim. No network, no plugins
beyond `lib.nvim` (auto-detected as a sibling repo or via `$REPOS_DIR`).

## Run

```sh
nvim -l TESTS/pickers_spec.lua
```

The script bootstraps its own `runtimepath` from its file location, so it works
from any working directory. It exits non-zero on the first failing suite, making
it CI-friendly.

## Coverage

Everything lives in `pickers_spec.lua`, one commented suite per area. The
suites read top to bottom as a tour of the plugin: config normalisation
(collections, keymaps, `history`, `result_count`, `display`, and the removed
`selected_index` shape being ignored rather than applied), command dispatch and
the "find all" escape hatch, `:PickersRepeat`'s recorded state, the `mappings`
name classifier, `plugin_spec()`'s engine-ownership builder, the builtin
registry, the in-picker keys and their three per-engine adapters, the entry
actions, the `smart` scorer and its frecency boost, the `repos`/`system`
sources, the quickfix window's preview float and refine filter (against a
real `:copen` over a temp file), the `gh` source's argv and JSON parsing, the
directory browser's listing and flow on a fake engine, the tab groups'
switching and query carry-over, and `:Pickers` tab-completion.

Two of them exist because the failure they pin is invisible at runtime rather
than because the code looked risky:

- **The per-engine roots option** — `search_dirs` on telescope, `search_paths`
  on fzf-lua, `dirs` on snacks. A wrong name is dropped in silence and the
  search runs over the CWD instead, returning plausible results from the wrong
  place. One library stub per engine, one assertion each.
- **Prompt routing** — every place that asks the user for a string (the
  `system` source, `create_file`, `dir`'s `path=…` entry) has to go through
  `lib.nvim`'s input kit rather than `vim.fn.input`, which is only observable
  by stubbing it.

The `:Pickers` completion tests register the real composer-backed command and
drive it through `getcompletion()`, so they are skipped automatically when
`lib.nvim` is not on the runtimepath (`pickers.command.composer` hard-requires
`lib.nvim.bindings.usercmd.composer`). That same suite now also asserts the
`dir` route's nav-slot completion (aliases, numeric depths, `path=`) and that
a collection named `cwd` loses to the built-in scope of the same name instead
of registering a second, silently-shadowed route.

A later pass filled in the leaf logic the first round of suites had left
alone: `pickers.error`'s typed-Result wrapper; the `depth_aliases` resolvers
behind `dir`'s `git`/`root` lookups (walked from a real temp `.git`, not
mocked); `actions.grep` and `actions.smart`'s find-override merge, the same
contract `actions.files` already pinned, plus `smart`'s missing-adapter
guard; `actions.dir.run()` end to end — numeric depth, `path=`, a named
alias, an alias resolver that errors, an unresolvable raw path, and the
nil/nil interactive fallback through stubbed nav/action pickers;
`engines.when_loaded`'s three load-timing branches (already-loaded, no
lazy.nvim → `vim.schedule`, lazy.nvim → one-shot `User LazyLoad`); the
telescope/snacks entry-path extractors (mirroring the existing fzf one);
`open_background`'s empty-path guard and its opt-in `open_background_show`
window switch (a real scratch buffer, not a fake bufnr, since the window API
does not tolerate one); the `folder`/`plugins_book`/`wkdbooks` sources;
`ui.action_picker`'s `ui.kit`/`vim.ui.select` fallback; `pickers.smart`'s own
`defaults()`/`config()` merge and its frecency-gated `query()` orchestration
over stubbed `search`/`score`/`frecency`; and the binding layer's compat
commands — `bindings.collections`' skip-if-registered guard and optional
per-collection keymaps, `bindings.usrcmds`' direct-dispatch-vs-fallback split
for `:RepoFiles`/`:PluginsBookFiles`, `bindings.autocmds`' `setup()`-was-
already-called guard — down to `bindings.setup()`'s and the top-level
`setup()`'s own enable-flag gating of every sub-registrar.

Deliberately left untested: `sources.config`/`sources.cwd`, which are one
line each with no branch to exercise. The `keys.adapters.*` modules have no
suite of their own because `pickers.keys`' own suite already drives
`fzf_keymap`/`telescope_mappings`/`snacks_win` straight through to them.

## Re-audit (round 2)

A second pass re-checked every file under `lua/pickers` against the list
above and re-verified each stated skip reason still holds. Most of it does:
`telescope.nvim`/`fzf-lua`/`snacks.nvim` are still absent as CI/dev siblings
(only `lib.nvim` and `ui.nvim` are), `sources.config`/`sources.cwd` are still
one-liners, and no new source files have appeared since round 1. Two
skip reasons, however, no longer held up:

- **`pickers.health`** — round 1's reasoning ("nothing it returns to assert
  on") is true for the bulk of the function, but `M.check()` is one
  unbroken function body: if it raises partway through, the WHOLE report
  never finishes, and `pcall` can see that even with no return value to
  check. That turned up a real bug (below), so the file now has two checks:
  a smoke test that the full report runs to completion when `lib.nvim` is
  actually present (the normal case), and a pinned regression for the crash.
- **`sources.drives`** — round 1's reasoning ("shells real `Get-PSDrive`/`df`
  via `vim.system`, no stable mock surface without replacing the whole
  process layer") missed that `vim.system` is a plain global, not a
  `require()`-time upvalue — it can be monkey-patched directly around the
  call and restored right after, the same technique `open.nvim`'s
  `keywords_spec` already uses for its own subprocess calls, with no real
  PowerShell/`df` ever spawned. The suite branches on the REAL command the
  module built (`powershell` vs `df`) rather than assuming a host, so it is
  correct on both the Windows dev box and the Ubuntu CI runner. Covered:
  `is_windows()`, `roots()`'s trim + dedup parsing of both platforms' output
  and its session cache (a second call does not shell out again), and
  `get()`'s `Pickers.Source` wrapping (prompt, `.git`/`node_modules`/etc.
  exclusion globs). Not covered: `wsl_roots()` (only reachable on real WSL,
  not exercisable from either CI or this Windows dev box) and the "truly
  zero roots" branch of `get()` — both `windows_roots`' A-Z brute-force
  fallback and `posix_roots`' fixed candidate list probe REAL directories
  with `vim.fn.isdirectory()`, so reaching an empty list needs every one of
  those checks to fail on a live filesystem, which no host this suite runs
  on can simulate without also breaking the fallback logic itself.

**Two real bugs found, both pinned as `BUG:`-marked regression assertions
in `pickers_spec.lua` rather than fixed** (neither blocks writing its own
test, so per the campaign's convention they are left for a decision on how
to fix rather than changed here):

1. `pickers.health`'s dependency section reports
   `lib.nvim.bindings.usercmd.composer` missing via an ordinary
   `vim.health.error()` when absent — the same graceful pattern every other
   missing-dependency check in the function uses. But the very last line of
   `M.check()` unconditionally does
   `require("lib.nvim.bindings.usercmd.composer").checkhealth("Pickers")`,
   outside any `pcall`, straight into the exact module the section above
   just reported as absent. On a real "not found" that `require` throws
   again — this time uncaught — so `:checkhealth pickers` crashes outright
   instead of finishing the report, in precisely the situation where the
   user most needs a coherent one.
2. `pickers.smart.frecency`'s `M.patch()` has no idempotency guard of its
   own, and the shared `"pickers.nvim"` augroup it registers `BufReadPost`/
   `VimLeavePre` into is resolved by name through
   `lib.nvim.bindings.autocmd.group()`, which memoizes the augroup id and
   hands it back without clearing unless the caller explicitly passes
   `clear=true` — which `frecency.lua` never does. Calling `pickers.setup()`
   a second time with `smart.frecency.enabled=true` both times (a config
   reload, or a plugin manager re-running `config()`) does not replace the
   handler, it adds a second one: every buffer read gets recorded twice and
   `VimLeavePre` flushes twice, permanently, for the rest of the session.
   Verified directly against real autocmd counts via `nvim_get_autocmds`,
   not simulated.

Test count: 575 → 592 checks (0 fails), stable across repeated runs.
`luacheck lua plugin TESTS` and `stylua --check lua plugin TESTS` both green
(`.luacheckrc` gained `vim.system` alongside the existing `vim.g`/`vim.ui`
allowance, for the same reason: the spec monkeypatches it around a handful
of cases and restores it right after).
