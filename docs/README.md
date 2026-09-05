# pickers.nvim documentation

What is here, and which question each page answers. [The README](../README.md)
is the short version of all of it.

## Getting it running

| Page | Answers |
| --- | --- |
| [installation.md](installation.md) | What has to be there first, and a spec per plugin manager |
| [configuration.md](configuration.md) | Every key — all of them optional, so this is also the list of what happens if you set nothing |

## Using it

| Page | Answers |
| --- | --- |
| [cheatsheet.md](cheatsheet.md) | The command syntax and the keys on one screen |
| [commands.md](commands.md) | `:Pickers` in full, argument by argument |
| [keymaps.md](keymaps.md) | Every key, where it is registered, and how to change it |
| [BINDINGS.md](BINDINGS.md) | The same ground as one machine-readable reference of every keymap, user command and autocommand |
| [builtins.md](builtins.md) | `:Pickers builtin <name>` — the engines' own native pickers (git, LSP, help, …), every registered name, and which engine can do which |
| [collections.md](collections.md) | User-defined named scopes: what a collection is and how to define one |
| [WORKFLOW.md](WORKFLOW.md) | The different question: not what each picker does, but how scopes, collections and engines combine into a way of working |

When something does not behave the way the config says it should, start at
[WORKFLOW.md §8](WORKFLOW.md#8-traps-worth-knowing-before-you-hit-them) — the
traps table names each symptom, what is actually happening, and the page that
explains it — and then run `:checkhealth pickers`. There is no separate
troubleshooting page; those two are it.

## Why it is the way it is

| Page | Answers |
| --- | --- |
| [FEATURES/](FEATURES/README.md) | One page per area — actions, builtins, engines, images, keys, persistence, scopes, and the UI |

## History

| Page | Answers |
| --- | --- |
| [CHANGELOG.md](CHANGELOG.md) | What changed, in the order it happened |

## Here, but not prose

[**`install.json`**](install.json) declares the external tools this plugin can
use (`rg`, `fd`, `fzf`) with a reason and a package name per manager,
machine-readably, for `:Lib deps show pickers.nvim` and the one-time
`deps_popup` after install.

`doc/pickers.txt`, one directory up, is the same material as Vim help —
`:help pickers`.

## Not here, on purpose

Neither `architecture.md` nor `troubleshooting.md` exists, and both are
deliberate. The shape of the plugin is described per area under
[`FEATURES/`](FEATURES/README.md), each page naming the modules it is about; a
separate page would restate them. The symptom material has the two addresses
named above the fold — WORKFLOW.md §8 and `:checkhealth pickers`.
