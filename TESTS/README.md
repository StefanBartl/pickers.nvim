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
`lib.nvim.bindings.usercmd.composer`).
