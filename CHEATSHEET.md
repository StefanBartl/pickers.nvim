# pickers.nvim — Cheatsheet

## :Pickers command syntax

```
:Pickers                          scope picker → action picker
:Pickers <scope>                  action picker for scope
:Pickers <scope> files            find files in scope
:Pickers <scope> grep             live grep in scope
:Pickers dir                      dir-nav picker → action picker
:Pickers dir <nav>                resolve nav → action picker
:Pickers dir <nav> <action>       fully specified
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
| `<leader>dp` | `:Pickers dir` |
| `<leader>fb` | `:Pickers folder files` |
| `<leader>fc` | `:Pickers config files` |
| `<leader>gc` | `:Pickers config grep` |
| `<leader>li` | `:Pickers cwd grep` |

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
| `:RepoFiles` | `:Pickers repos files` |
| `:RepoGrep` | `:Pickers repos grep` |
| `:WkdBookFiles` | `:Pickers wkdbooks files` |
| `:WkdBookGrep` | `:Pickers wkdbooks grep` |

## Collections

Each collection in `setup({ collections = { ... } })` gets:

| Generated | Example (name = `"notes_lua"`) |
|---|---|
| `:Pickers notes_lua files` | scope via command |
| `:Pickers notes_lua grep` | scope via command |
| `:NotesLuaFiles` | compat command |
| `:NotesLuaGrep` | compat command |
| `keys.files` keymap | if configured |
| `keys.grep` keymap | if configured |

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

Sections: dependencies · engines · CLI tools · configuration · collections
