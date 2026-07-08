# pickers.nvim Binding Cheatsheet

A single, machine-readable reference of every keymap, user-command and autocommand that `pickers.nvim` registers. Kept as data (not prose) so it can double as a cheatsheet source and be consumed programmatically (e.g., by `which-key`).

---

## Table of content

  - [1. Keymaps (`keymaps`)](#1-keymaps-keymaps)
  - [2. User Commands (`usercmds`)](#2-user-commands-usercmds)
  - [3. Collection-Generated Commands (`collection_commands`)](#3-collection-generated-commands-collection_commands)
  - [4. Autocommands (`autocmds`)](#4-autocommands-autocmds)

---

## 1. Keymaps (`keymaps`)

> **Note:** Registered when `keymaps.enable = true`. You can disable an individual keymap by setting its configuration key to `nil` in your setup, or disable all of them via `keymaps = { enable = false }`.

| Default Key (`default`) | Config Key (`config`) | Triggers Command (`maps_to`) | Description |
| --- | --- | --- | --- |
| `<leader>dp` | `"dir_pick"` | `:Pickers dir` | Dir navigation picker (alias / depth / path) |
| `<leader>fb` | `"folder_files"` | `:Pickers folder files` | Find files in an interactively picked folder |
| `<leader>fc` | `"config_files"` | `:Pickers config files` | Find files in the Neovim config dir |
| `<leader>gc` | `"config_grep"` | `:Pickers config grep` | Live grep in the Neovim config dir |
| `<leader>li` | `"cwd_grep"` | `:Pickers cwd grep` | Live grep in the current working directory |
| *None* (`nil`) | `"cwd_files"` | `:Pickers cwd files` | Find files in the current working directory *(disabled by default)* |

---

## 2. User Commands (`usercmds`)

> **Note:** The core `:Pickers` dispatcher is always registered by `plugin/pickers.lua`. The additional compatibility commands listed below are registered if `usercmds.enable = true`.

| Command Name (`name`) | Equivalent Invocation (`maps_to`) | Arguments (`nargs`) | Description |
| --- | --- | --- | --- |
| `:Pickers` | `:Pickers [scope] [nav|action] [action]` | `*` | Unified entry point *(always registered)* |
| `:DirPicker` | `:Pickers dir [nav]` | `*` | Dir navigation picker |
| `:FindConfig` | `:Pickers config files` | `?` | Find files in nvim config |
| `:GrepConfig` | `:Pickers config grep` | `?` | Live grep in nvim config |
| `:FindInFolder` | `:Pickers folder files` | `*` | Pick a folder, then find files |
| `:LiveGrep` | `:Pickers cwd grep` | `?` | Live grep in CWD |
| `:AllDrives` | `:Pickers drives files` | `?` | Find files across all drives |
| `:AllDrivesGrep` | `:Pickers drives grep` | `?` | Live grep across all drives |
| `:FindOnSystem` | `:Pickers system files` | `?` | Systemwide fd search (prompts) |
| `:RepoFiles [repo]` | `:Pickers repos files` | `?` | Pick a repo, then find files. With `[repo]` (tab-completed from `REPOS_DIR`), jumps straight into files for that repo |
| `:RepoGrep [repo]` | `:Pickers repos grep` | `?` | Pick a repo, then live grep. With `[repo]` (tab-completed from `REPOS_DIR`), jumps straight into grep for that repo |
| `:WkdBookFiles` | `:Pickers wkdbooks files` | `?` | Pick a wkdbook, then find files |
| `:WkdBookGrep` | `:Pickers wkdbooks grep` | `?` | Pick a wkdbook, then live grep |

---

## 3. Collection-Generated Commands (`collection_commands`)

For every user-configured entry in the `collections` table, two compatibility commands are dynamically generated from the **PascalCase** version of the collection's name (e.g., `notes_lua` generates the commands below).

Additionally, optional `keys.files` / `keys.grep` keymaps are bound if they are explicitly configured.

| Type | Dynamic Pattern (`pattern`) | Maps To (`maps_to`) | Example (`notes_lua`) |
| --- | --- | --- | --- |
| **Files** | `:{PascalName}Files` | `:Pickers {name} files` | `:NotesLuaFiles` $\rightarrow$ `:Pickers notes_lua files` |
| **Grep** | `:{PascalName}Grep` | `:Pickers {name} grep` | `:NotesLuaGrep` $\rightarrow$ `:Pickers notes_lua grep` |

---

## 4. Autocommands (`autocmds`)

| Event | Source File | Description |
| --- | --- | --- |
| `VimEnter` | `plugin/pickers.lua` | Register default keymaps/usercmds at startup when the user did *not* call `setup()` (guarded by `vim.g.pickers_nvim_setup_called`). |

---

