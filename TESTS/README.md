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
sources, and `:Pickers` tab-completion.

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

Deliberately left untested: `pickers.health` (a `:checkhealth` report — one
`vim.health.*` call per environment probe, nothing it returns to assert on);
`sources.drives` (shells out to real `Get-PSDrive`/`df`, no stable surface to
mock without replacing `vim.system` wholesale); and `sources.config`/
`sources.cwd`, which are one line each with no branch to exercise. The
`keys.adapters.*` modules have no suite of their own because `pickers.keys`'
own suite already drives `fzf_keymap`/`telescope_mappings`/`snacks_win`
straight through to them.
