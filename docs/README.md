# pickers.nvim documentation

What is here, and which question each page answers. [The README](../README.md)
is the short version of all of it.

## Getting it running

| Page | Answers |
| --- | --- |
| [INSTALLATION.md](INSTALLATION.md) | What has to be there first, and a spec per plugin manager |
| [CONFIGURATION.md](CONFIGURATION.md) | Every key — all of them optional, so this is also the list of what happens if you set nothing |

## Using it

| Page | Answers |
| --- | --- |
| [CHEATSHEET.md](CHEATSHEET.md) | The command syntax and the keys on one screen |
| [COMMANDS.md](COMMANDS.md) | `:Pickers` in full, argument by argument |
| [KEYMAPS.md](KEYMAPS.md) | Every key, where it is registered, and how to change it |
| [BINDINGS.md](BINDINGS.md) | The same ground as one machine-readable reference of every keymap, user command and autocommand |
| [BUILTINS.md](BUILTINS.md) | The pickers that ship with the plugin |
| [COLLECTIONS.md](COLLECTIONS.md) | User-defined named scopes: what a collection is and how to define one |
| [WORKFLOW.md](WORKFLOW.md) | The different question: not what each picker does, but how scopes, collections and engines combine into a way of working |

## Why it is the way it is

| Page | Answers |
| --- | --- |
| [FEATURES/](FEATURES/README.md) | One page per area — actions, builtins, engines, images, keys, persistence, scopes, and the UI |

## History

| Page | Answers |
| --- | --- |
| [CHANGELOG.md](CHANGELOG.md) | What changed, in the order it happened |

## Here, but not prose

**`install.json`** declares the external tools this plugin can use,
machine-readably, for `:Lib deps show pickers.nvim`.
