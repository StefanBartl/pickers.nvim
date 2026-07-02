# Tests

Lightweight, framework-free unit tests for pickers.nvim. No network, no plugins
beyond `lib.nvim` (auto-detected as a sibling repo or via `$REPOS_DIR`).

## Run

```sh
nvim -l docs/TESTS/pickers_spec.lua
```

The script bootstraps its own `runtimepath` from its file location, so it works
from any working directory. It exits non-zero on the first failing suite, making
it CI-friendly.

## Coverage

| File | What it checks |
|---|---|
| `pickers_spec.lua` | PascalCase conversion, `config.apply` collection normalisation & keymap merging, `:Pickers` tab-completion (scopes, actions, filtering) |

`command.complete` tests are skipped automatically if `lib.nvim` is not on the
runtimepath (the command module hard-requires it).
