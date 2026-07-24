# Command reference

## `:Pickers`

```
:Pickers [scope] [action]
:Pickers dir [nav] [action]
```

`action` is one of `files`, `grep`, or `smart`. When an argument is omitted an
interactive picker appears (`hover_select` or `vim.ui.select`).

| Scope | Nav (dir only) | Action | Result |
|---|---|---|---|
| _(none)_ | — | — | scope picker (built-ins + collections) |
| `cwd` | — | _(none)_ | action picker for CWD |
| `cwd` | — | `files` | find files in CWD |
| `cwd` | — | `smart` | combined grep + find in CWD (merged & ranked) |
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

## `:Pickers builtin <name>`

Native pickers (git/LSP/help/…) that aren't a scope×action — dispatches
straight into the resolved engine's own picker function. Tab-completes over
the registry. See [docs/BUILTINS.md](BUILTINS.md) for the full name list and
the per-engine parity matrix (some names have no telescope or fzf-lua
equivalent — documented gaps, not bugs).

```
:Pickers builtin git_branches
:Pickers builtin lsp_definitions
```

---

## The `smart` action

`:Pickers <scope> smart` opens ONE live picker that runs `rg` (content) **and**
`fd` (filenames) for the same query and merges both result sets into a single
list **ranked by relevance** — a filename hit and a content hit interleave by
score instead of appearing as two separate blocks. A file matched by name that
*also* contains matches floats to the top (see `smart.weights.both`).

Works with every scope and collection, exactly like `files`/`grep`:

```
:Pickers cwd smart
:Pickers config smart
:Pickers dir git smart
:Pickers notes smart          " collection
```

An empty prompt behaves like a file picker (files only, no grep); results fill
in once you type. Selecting a grep row opens the file at the matched line;
selecting a file row opens it at the top. Ranking is identical across
telescope/fzf-lua/snacks because all three drive the same core
(`lua/pickers/smart/`). Tune the weighting via `smart.weights` — see
[docs/CONFIGURATION.md](CONFIGURATION.md#smart-combined-grep--find).

> fzf-lua note: the smart action uses fzf-lua's Lua-function live mode, which
> needs fzf ≥ 0.45. On older fzf, use the telescope or snacks engine for it.

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

Each user-defined collection also gets a `:{PascalName}Smart` command
(alongside `:{PascalName}Files` / `:{PascalName}Grep`) → `:Pickers {name} smart`.

---

## `:PickersRepeat`

Reopens the most recently dispatched `:Pickers` action — same resolved
scope/root, same action (`files`/`grep`/`smart`) — without re-resolving through any
interactive sub-picker (folder/repo/collection subdir) in between. Covers
every scope, including `dir`. In-memory only, current session; warns if
nothing has been dispatched yet. See `lua/pickers/last.lua`.

---

## `:PickersScopes`

Lists every scope `:Pickers` can resolve — built-in scopes (with a one-line
description) plus every user-defined collection (with its root directory) —
via `notify.info`, without opening the interactive scope picker. Useful as a
quick "what have I got configured" check, especially for collections defined
across multiple `setup()` merges.

---

## `:PickersResume`

Reopens the last picker with its last query — the engine's own native
resume/history-of-open-pickers feature, via `:Pickers builtin resume`. Not
the same thing as `:PickersRepeat`: this resumes the *engine's* last picker
session (including whatever you'd typed into the prompt); `:PickersRepeat`
replays pickers.nvim's own last resolved scope/action from scratch, with an
empty prompt. fzf-lua has no resume concept, so this is a documented no-op
`notify.warn` there — see [docs/BUILTINS.md](BUILTINS.md).

See also [docs/CHEATSHEET.md](CHEATSHEET.md) for a condensed, single-page version of this reference.
