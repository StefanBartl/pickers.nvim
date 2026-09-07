# Contributing to pickers.nvim

Thank you for your interest! Bugs, ideas and questions are welcome in the
[issue tracker](https://github.com/StefanBartl/pickers.nvim/issues); pull
requests very welcome.

## Getting the repository into a session

Clone it and either symlink the checkout into your plugin directory or add it
to the runtime path directly:

```lua
vim.opt.rtp:prepend("/path/to/pickers.nvim")
require("pickers").setup({})
```

[lib.nvim](https://github.com/StefanBartl/lib.nvim) has to be on the runtime
path too, and at least one engine — telescope.nvim, fzf-lua or snacks.nvim.
Test against more than one where you can: most of the interesting bugs in this
plugin are an engine disagreeing with the other two about what a picker option
means.

## Ground rules

- Lua only, idiomatic Neovim Lua. 2-space indentation, `stylua.toml` decides
  the rest.
- **The grammar does not change when the engine does.** `<scope> <action>` is
  the contract; the engine is an implementation detail behind
  `lua/pickers/engines/`. A feature that only exists on one engine is either
  adapted for the others or degrades visibly, never silently.
- **A scope answers "where", an action answers "what".** Anything that mixes
  the two belongs in one of them, not in a new third concept. New scopes go in
  `sources/`, new actions in `actions/`, and neither knows about the other.
- **Flags are per call.** `hidden`, `follow`, `all` apply to the invocation
  that named them and never write back to the configuration. A flag that leaks
  into the next call is a bug, however convenient.
- **An engine is required lazily.** `engines/when_loaded.lua` exists so that
  nothing pulls telescope, fzf-lua or snacks into startup. Resolve at call
  time, not at `setup()`.
- **A missing CLI tool costs one source.** `rg`, `fd` and `fzf` are detected at
  runtime; without them the sources that need them say so and the rest keeps
  working. Declare a new one in [`install.json`](install.json) and report it in
  `health.lua`.
- **`smart` ranks, it does not concatenate.** The whole point of that action is
  that a filename hit and a content hit interleave by score. A change that
  makes it emit two blocks has removed the feature.
- **No troubleshooting page.** Symptom material goes into the traps table in
  [`WORKFLOW.md` §8](WORKFLOW.md#8-traps-worth-knowing-before-you-hit-them) or
  into `:checkhealth pickers`. Those two are the addresses, deliberately.
- Commands are registered through `lib.nvim.bindings.usercmd.composer`, with
  completion over every closed argument set.
- Descriptive commit messages.

## Project layout

| Path | Contains |
| --- | --- |
| `lua/pickers/sources/` | One file per scope: cwd, config, folder, repos, wkdbooks, system, drives, collection |
| `lua/pickers/actions/` | `files`, `grep`, `smart`, and `dir` navigation |
| `lua/pickers/builtins/` | The `:Pickers builtin <name>` registry over the engines' own pickers |
| `lua/pickers/engines/` | `telescope.lua`, `fzf.lua`, `snacks.lua`, and `when_loaded.lua` — the lazy resolution |
| `lua/pickers/entry_actions/`, `mappings/`, `keys/` | What a key does to an entry, and where the keys are registered |
| `lua/pickers/refine/`, `smart/`, `result_count/` | Narrowing a result set, the ranked merge, and the count in the prompt |
| `lua/pickers/history/` | Persistence across sessions |
| `lua/pickers/integrations/images/` | Image and PDF previews, via images.nvim and pdfport.nvim |
| `lua/pickers/ui/` | Shared rendering |
| `lua/pickers/command/`, `bindings/` | The `:Pickers` grammar, completion, and the keymaps |
| `lua/pickers/config/` | Defaults and validation |
| `doc/`, `docs/` | The vimdoc, and everything the README links to |
| `TESTS/` | The spec suite |

## Adding a scope

1. Add the module under `lua/pickers/sources/`, returning a resolved root or a
   picker over candidate roots. It does not know which action will run in it.
2. Make it complete: the scope name has to appear in `<Tab>` completion from
   the registry, not from a second hand-written list.
3. If it needs a CLI tool, declare it in [`install.json`](install.json), report
   it in `health.lua`, and let its absence cost that scope only.
4. Add a spec.
5. Document it in [`cheatsheet.md`](cheatsheet.md),
   [`commands.md`](commands.md) and
   [`FEATURES/SCOPES.md`](FEATURES/SCOPES.md).

A scope that is just "these directories, under one name" does not need code at
all — that is what collections are for, see [`collections.md`](collections.md).

## Adding an action

1. Add the module under `lua/pickers/actions/`, taking an already-resolved
   scope root. It never resolves a scope itself.
2. Implement it for every engine, through `lua/pickers/engines/`. If one engine
   cannot do it, say so at call time rather than failing quietly.
3. Honour the per-call flags, and do not persist them.
4. Add a spec, and document it in [`commands.md`](commands.md) and
   [`FEATURES/ACTIONS.md`](FEATURES/ACTIONS.md).

## Adding an engine

1. Add the adapter under `lua/pickers/engines/`, implementing the same surface
   as the three existing ones.
2. Require the plugin lazily, through `when_loaded.lua`.
3. Fill in the parity matrix in [`builtins.md`](builtins.md) — an engine that
   cannot dispatch a given native picker is a documented gap, not a crash.
4. Report it in `health.lua` under the engines section.

## Tests

`TESTS/` is a headless spec suite.

```
nvim -l TESTS/pickers_spec.lua
```

Exit 0 is a pass. [GitHub Actions](../.github/workflows/ci.yml) runs it plus
stylua and luacheck on every push and pull request to `main`.

Specs assert on resolution and composition — which scope resolved to which
root, which options an action composed — not on opening a picker window.

## Workflow

1. Fork the repository.
2. Branch as `feature/<name>`.
3. Make the change, add a spec, update the affected pages under `docs/` and the
   [changelog](CHANGELOG.md).
4. Open a PR with a clear description of what changed and why — and say which
   engines you tested against.
