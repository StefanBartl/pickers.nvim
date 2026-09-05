# pickers.nvim — Cheatsheet

## :Pickers command syntax

```
:Pickers                          scope picker → action picker
:Pickers <scope>                  action picker for scope
:Pickers <scope> files            find files in scope
:Pickers <scope> grep             live grep in scope
:Pickers <scope> smart            grep + find merged, ranked by relevance
:Pickers <scope> files all        force hidden+no_ignore+follow, this call only
:Pickers <scope> files hidden+follow
                                  the same three flags, alone or joined by +
:Pickers dir                      dir-nav picker → action picker
:Pickers dir <nav>                resolve nav → action picker
:Pickers dir <nav> <action>       fully specified
:Pickers builtin <name>           the engine's own native picker, by name
```

## Built-in scopes

| Scope | Root / Behaviour |
|---|---|
| `cwd` | `vim.uv.cwd()` |
| `config` | `vim.fn.stdpath("config")` |
| `folder` | Interactive folder pick |
| `repos` | Pick git repo from `repos_dir` |
| `wkdbooks` | Pick `wkdbook-*` subdir from `repos_dir/WKDBooks` |
| `system` | `fd` systemwide (prompts for query) |
| `drives` | All mount points / drive letters |
| `dir` | Depth / alias / explicit path |

## dir nav forms

| Nav arg | Resolves to |
|---|---|
| `1` … `N` | N directories above cwd |
| `git` | Git root of cwd |
| `home` | OS home dir |
| `cwd` | Current working directory |
| `root` | Filesystem root above cwd |
| `<alias>` | Custom alias from `depth_aliases` |
| `path=<dir>` | Explicit path (`~`, `%VAR%`, `$VAR` expanded) |

## Built-in keymaps (defaults)

| Keymap | Action |
|---|---|
| `<leader>dp` | `:Pickers dir` (a count is the depth: `2<leader>dp`) |
| `<leader>.` | `:Pickers builtin explorer` |
| `<leader>fb` | `:Pickers folder files` |
| `<leader>fc` | `:Pickers config files` |
| `<leader>gc` | `:Pickers config grep` |
| `<leader>li` | `:Pickers cwd grep` |

Everything else is opt-in and unbound by default — the full list, with its
config key per entry, is in [BINDINGS.md](BINDINGS.md#1-keymaps-keymaps).

## Built-in compat commands

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
| `:RepoFiles [repo]` | `:Pickers repos files` (`[repo]` tab-completes from `REPOS_DIR` and skips the repo picker) |
| `:RepoGrep [repo]` | `:Pickers repos grep` (`[repo]` tab-completes from `REPOS_DIR` and skips the repo picker) |
| `:WkdBookFiles` | `:Pickers wkdbooks files` |
| `:WkdBookGrep` | `:Pickers wkdbooks grep` |
| `:PickersRepeat` | Replay the last dispatched scope/action, empty prompt |
| `:PickersScopes` | List every resolvable scope as text, without a picker |
| `:PickersResume` | `:Pickers builtin resume` — the engine's own last session, prompt and all |

## Smart action (grep + find, merged & ranked)

```
:Pickers <scope> smart            one live picker: rg (content) + fd (names)
```

Both result sets merge into one list ranked by relevance (not two blocks). A
file matched by name that also has content hits floats to the top. Empty prompt
= files only. Tune `smart.weights = { filename, content, both }`. Opt-in
keymaps: `cwd_smart` / `config_smart` / `folder_smart`; per-collection
`keys.smart`. fzf-lua engine needs fzf ≥ 0.45.

## Collections

Each collection in `setup({ collections = { ... } })` gets:

| Generated | Example (name = `"notes_lua"`) |
|---|---|
| `:Pickers notes_lua files` | scope via command |
| `:Pickers notes_lua grep` | scope via command |
| `:Pickers notes_lua smart` | scope via command |
| `:NotesLuaFiles` | compat command |
| `:NotesLuaGrep` | compat command |
| `:NotesLuaSmart` | compat command |
| `keys.files` keymap | if configured |
| `keys.grep` keymap | if configured |
| `keys.smart` keymap | if configured |

### prefix field

| Value | Behaviour |
|---|---|
| `nil` | use `dir` as direct search root |
| `""` | list all immediate subdirs; user picks one |
| `"xyz-"` | list only subdirs starting with `"xyz-"` |

## Health check

```
:checkhealth pickers
```

Sections: dependencies · picker engines · CLI tools · configuration · image
previews · collections · the tools declared in
[`install.json`](install.json) · the `:Pickers` command tree
