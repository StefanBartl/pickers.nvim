# Scopes

A scope answers *where*. It resolves to one or more roots, which the actions in
[ACTIONS.md](ACTIONS.md) then search. Every scope works with every action, and
every scope tab-completes.

## Built-in scopes

Eight, each a module under `sources/` that returns roots. Two of them
(`folder`, `repos`) are two-step: they open a picker to choose the root first,
then run the action inside it.

| Scope | Root |
| --- | --- |
| `cwd` | the current working directory |
| `config` | the Neovim config directory |
| `folder` | pick a folder interactively, then search in it |
| `repos` | pick a repository under `repos_dir`, then search in it |
| `wkdbooks` | pick a prefixed subdirectory, then search in it |
| `system` | a systemwide `fd` search, prompting for the query |
| `drives` | every mounted drive, discovered once per session and cached |
| `dir` | a directory reached by navigation — see below |

- **Module:** [`sources/`](../../lua/pickers/sources/) — one file per scope
- **Config:** `repos_dir` (defaults to `$REPOS_DIR`)
- **Usercmds:** `:Pickers <scope> <action>`, `:PickersScopes` lists every scope
  that resolves

## `dir` — navigation instead of a name

`dir` is the scope for "somewhere near here", and takes a navigation argument
rather than a fixed root:

| Form | Resolves to |
| --- | --- |
| _(none)_ | a navigation picker, then an action picker |
| `2` | two directories up from the current one |
| `git` | the enclosing git root |
| `path=/tmp` | that path, explicitly |

A count on the `dir` keymap is read as the depth, so `3<leader>dp` is three
levels up without typing the number as an argument.

- **Module:** [`sources/folder.lua`](../../lua/pickers/sources/folder.lua),
  [`ui/dir_nav_picker.lua`](../../lua/pickers/ui/dir_nav_picker.lua)
- **Config:** `depth_aliases` — named starting points (`cwd`, `home`, …), each
  a function, so an alias can resolve at call time rather than at setup

## Collections — user-defined scopes

A collection is a named root the user adds, and it becomes a first-class scope:
it appears in the scope picker, tab-completes on `:Pickers`, gets generated
compat commands (`:{PascalName}Files` / `Grep` / `Smart`), and can carry its own
keymaps.

Three shapes, from the same config field:

- **A direct root** — `{ name = "notes", dir = "…" }` searches that directory.
- **Prefix-filtered subdirectories** — adding `prefix = "wkdbook-"` turns it
  into a two-step scope: pick one matching subdirectory, then search inside it.
  An empty prefix means all subdirectories.
- **Git-only subdirectories** — `only_git = true` narrows that list to the ones
  that actually contain a `.git/`.

- **Module:** [`sources/collection.lua`](../../lua/pickers/sources/collection.lua),
  registered by [`bindings/collections.lua`](../../lua/pickers/bindings/collections.lua)
- **Config:** `collections` — see [collections.md](../collections.md)
- **Keymaps:** per collection, `keys = { files, grep, smart }`

## Per-collection find overrides

A collection can carry its own partial `find` table, which is merged over the
global one for searches in that collection only. A notes directory that should
always include dotfiles does not have to make every other scope include them
too.

- **Module:** [`config/init.lua`](../../lua/pickers/config/init.lua) (merge),
  [`actions/files.lua`](../../lua/pickers/actions/files.lua) (use)
- **Config:** `collections[].find`
