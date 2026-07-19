# Command reference

## `:Pickers`

```
:Pickers [scope] [action]
:Pickers dir [nav] [action]
```

When an argument is omitted an interactive picker appears (`hover_select` or
`vim.ui.select`).

| Scope | Nav (dir only) | Action | Result |
|---|---|---|---|
| _(none)_ | — | — | scope picker (built-ins + collections) |
| `cwd` | — | _(none)_ | action picker for CWD |
| `cwd` | — | `files` | find files in CWD |
| `config` | — | `grep` | live grep in nvim config |
| `folder` | — | `files` | pick a folder → find files |
| `repos` | — | `files` | pick a repo → find files |
| `wkdbooks` | — | `grep` | pick a wkdbook → live grep |
| `system` | — | `files` | fd systemwide search (prompt) |
| `drives` | — | `grep` | live grep across all drives |
| `dir` | _(none)_ | _(none)_ | nav picker → action picker |
| `dir` | `2` | _(none)_ | 2 dirs up → action picker |
| `dir` | `git` | `files` | git root → find files |
| `dir` | `path=/tmp` | `grep` | explicit path → live grep |
| `notes` _(collection)_ | — | `files` | find files in collection root |
| `wkdbooks` _(collection)_ | — | `grep` | pick subdir → live grep |

Tab-completion is supported for all arguments, including collection names
(once `setup()` — or the `VimEnter` fallback — has registered them; see
[docs/BINDINGS.md](BINDINGS.md)).

Built via `lib.nvim.usercmd.composer`: the route tree in
`lua/pickers/command/composer.lua` drives dispatch and `<Tab>` completion
from one source, delegating actual dispatch to the unchanged
`pickers.command.handle`. An unknown scope now reports composer's own
"unknown subcommand" usage block instead of a plain error string.

---

## Scopes

### Built-in scopes

| Scope | Search root |
|---|---|
| `cwd` | `vim.uv.cwd()` |
| `config` | `vim.fn.stdpath("config")` |
| `folder` | Interactively picked directory |
| `repos` | One git repo selected from `repos_dir` |
| `wkdbooks` | One wkdbook selected from `repos_dir/WKDBooks` |
| `system` | Systemwide `fd` search (prompts for query) |
| `drives` | All mount points / drive letters (session-cached) |
| `dir` | Depth / alias / explicit-path navigation |

### dir — nav arg forms

| Nav arg | Resolves to |
|---|---|
| `1` … `N` | N directories above cwd |
| `git` | Git repository root of cwd |
| `home` | OS home directory |
| `cwd` | Current working directory |
| `root` | Filesystem root above cwd |
| `<alias>` | Any name registered in `depth_aliases` |
| `path=<dir>` | Explicit path (`~` / `%VAR%` / `$VAR` expanded) |

---

## Compat commands

All commands from the original modules are preserved as aliases:

| Command | Equivalent |
|---|---|
| `:DirPicker [nav]` | `:Pickers dir [nav]` |
| `:FindConfig` | `:Pickers config files` |
| `:GrepConfig` | `:Pickers config grep` |
| `:FindInFolder` | `:Pickers folder files` |
| `:LiveGrep` | `:Pickers cwd grep` |
| `:AllDrives` | `:Pickers drives files` |
| `:AllDrivesGrep` | `:Pickers drives grep` |
| `:FindOnSystem` | `:Pickers system files` |
| `:RepoFiles [repo]` | `:Pickers repos files` (or jump straight to `[repo]`, tab-completed) |
| `:RepoGrep [repo]` | `:Pickers repos grep` (or jump straight to `[repo]`, tab-completed) |
| `:WkdBookFiles` | `:Pickers wkdbooks files` |
| `:WkdBookGrep` | `:Pickers wkdbooks grep` |

See also [docs/CHEATSHEET.md](CHEATSHEET.md) for a condensed, single-page version of this reference.
