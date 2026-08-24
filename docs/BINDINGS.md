# pickers.nvim Binding Cheatsheet

A single, machine-readable reference of every keymap, user-command and autocommand that `pickers.nvim` registers. Kept as data (not prose) so it can double as a cheatsheet source and be consumed programmatically (e.g., by `which-key`).

---

## Table of content

  - [1. Keymaps (`keymaps`)](#1-keymaps-keymaps)
  - [2. User Commands (`usercmds`)](#2-user-commands-usercmds)
  - [3. Collection-Generated Commands (`collection_commands`)](#3-collection-generated-commands-collection_commands)
  - [4. Autocommands (`autocmds`)](#4-autocommands-autocmds)
  - [5. In-picker keys (`keys`)](#5-in-picker-keys-keys)

---

## 1. Keymaps (`keymaps`)

> **Note:** Registered when `keymaps.enable = true`. You can disable an individual keymap by setting its configuration key to `nil` in your setup, or disable all of them via `keymaps = { enable = false }`.

| Default Key (`default`) | Config Key (`config`) | Triggers Command (`maps_to`) | Description |
| --- | --- | --- | --- |
| `<leader>dp` | `"dir_pick"` | `:Pickers dir` | Dir navigation picker (alias / depth / path). A count is the depth: `2<leader>dp` = `:Pickers dir 2` |
| `<leader>.` | `"explorer"` | `:Pickers builtin explorer` | File explorer / browser on the active engine |
| `<leader>fb` | `"folder_files"` | `:Pickers folder files` | Find files in an interactively picked folder |
| `<leader>fc` | `"config_files"` | `:Pickers config files` | Find files in the Neovim config dir |
| `<leader>gc` | `"config_grep"` | `:Pickers config grep` | Live grep in the Neovim config dir |
| `<leader>li` | `"cwd_grep"` | `:Pickers cwd grep` | Live grep in the current working directory |
| *None* (`nil`) | `"cwd_files"` | `:Pickers cwd files` | Find files in the current working directory *(disabled by default)* |
| *None* (`nil`) | `"repos_files"` | `:Pickers repos files` | Pick a repo, then find files *(disabled by default)* |
| *None* (`nil`) | `"repos_grep"` | `:Pickers repos grep` | Pick a repo, then live grep *(disabled by default)* |
| *None* (`nil`) | `"system_files"` | `:Pickers system files` | Systemwide fd search, prompts for query *(disabled by default)* |
| *None* (`nil`) | `"cwd_smart"` | `:Pickers cwd smart` | Combined grep + find in CWD, merged & ranked *(disabled by default)* |
| *None* (`nil`) | `"config_smart"` | `:Pickers config smart` | Combined grep + find in nvim config *(disabled by default)* |
| *None* (`nil`) | `"folder_smart"` | `:Pickers folder smart` | Pick a folder, then combined grep + find *(disabled by default)* |

---

## 2. User Commands (`usercmds`)

> **Note:** The core `:Pickers` dispatcher (built via `lib.nvim.usercmd.composer`) is registered immediately by `plugin/pickers.lua` with the built-in scopes; `setup()` (or the `VimEnter` fallback below) re-registers it with the current `collections`, so collection names only appear in `:Pickers <Tab>` once one of those has run. The additional compatibility commands listed below are registered if `usercmds.enable = true`.

| Command Name (`name`) | Equivalent Invocation (`maps_to`) | Arguments (`nargs`) | Description |
| --- | --- | --- | --- |
| `:Pickers` | `:Pickers [scope] [nav|action] [action]` | `*` | Unified entry point *(always registered; `action` ∈ `files`/`grep`/`smart`)* |
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
| `:PickersRepeat` | `pickers.last.run()` | `?` | Reopen the most recently dispatched `:Pickers` action (same resolved scope/root/action), without re-resolving any interactive sub-picker |
| `:PickersScopes` | `pickers.ui.scope_picker.list()` | `?` | List every scope `:Pickers` can resolve — built-in scopes plus every user-defined collection — via `notify.info`, without opening the interactive scope picker |
| `:PickersResume` | `:Pickers builtin resume` | `?` | Reopen the last picker with its last query (the engine's own native resume/history-of-open-pickers feature); fzf-lua has no resume concept |

---

## 3. Collection-Generated Commands (`collection_commands`)

For every user-configured entry in the `collections` table, three compatibility commands are dynamically generated from the **PascalCase** version of the collection's name (e.g., `notes_lua` generates the commands below).

Additionally, optional `keys.files` / `keys.grep` / `keys.smart` keymaps are bound if they are explicitly configured.

| Type | Dynamic Pattern (`pattern`) | Maps To (`maps_to`) | Example (`notes_lua`) |
| --- | --- | --- | --- |
| **Files** | `:{PascalName}Files` | `:Pickers {name} files` | `:NotesLuaFiles` $\rightarrow$ `:Pickers notes_lua files` |
| **Grep** | `:{PascalName}Grep` | `:Pickers {name} grep` | `:NotesLuaGrep` $\rightarrow$ `:Pickers notes_lua grep` |
| **Smart** | `:{PascalName}Smart` | `:Pickers {name} smart` | `:NotesLuaSmart` $\rightarrow$ `:Pickers notes_lua smart` |

---

## 4. Autocommands (`autocmds`)

| Event | Source File | Description |
| --- | --- | --- |
| `VimEnter` | `plugin/pickers.lua` | Register default keymaps/usercmds at startup when the user did *not* call `setup()` (guarded by `vim.g.pickers_nvim_setup_called`). |

**`smart.frecency`** (opt-in, only registered when `cfg.smart.frecency.enabled == true`; augroup `"pickers.nvim"`, shared with the `VimEnter` fallback above):

| Event(s) | Buffer (pattern) | Source File | Description |
| --- | --- | --- | --- |
| `BufReadPost` | any real, listed file buffer (`buftype == ""`, readable path) | `lua/pickers/smart/frecency.lua` | Records a visit — increments count + updates last-visited timestamp for that abspath |
| `VimLeavePre` | none | `lua/pickers/smart/frecency.lua` | Flushes the in-memory frecency store to `stdpath("data")/pickers.nvim/frecency.json` |

---

## 5. In-picker keys (`keys`)

> **Note:** Registered when `keys.enable = true` (default on). Separate from the normal-mode keymaps in §1 — these act **inside** an already-open picker, translated per engine. See [docs/KEYMAPS.md](KEYMAPS.md#in-picker-keys-preview-scroll--history--entry-actions) for the full writeup (capability gaps, `open_background_show`, etc.).

| Action (`config`) | Default | telescope | fzf-lua | snacks |
| --- | --- | --- | --- | --- |
| `preview_scroll_down` | `<PageDown>` | patched | patched | export only¹ |
| `preview_scroll_up` | `<PageUp>` | patched | patched | export only¹ |
| `preview_scroll_left` | `<C-Left>` | patched | — (fzf gap) | export only¹ |
| `preview_scroll_right` | `<C-Right>` | patched | — (fzf gap) | export only¹ |
| `history_back` | `<C-p>` | patched | — (fzf-native, fixed) | export only¹ |
| `history_forward` | `<C-n>` | patched | — (fzf-native, fixed) | export only¹ |
| `create_file` | `<C-a>` | patched | fixed (`ctrl-a`) | export only¹ |
| `open_background` | `<S-CR>`, `<C-o>` | patched | fixed (`ctrl-o`/`shift-enter`) | export only¹ |
| `preview_toggle` | *(off, opt-in)* | patched | native `<F4>`, not ours | native `<A-p>`, not ours |
| `split` | `<C-s>` | patched | native `ctrl-s`, not ours | export only¹ |
| `vsplit` | `<C-v>` | patched | native `ctrl-v`, not ours | export only¹ |
| `tab` | `<C-t>` | patched | native `ctrl-t`, not ours | export only¹ |
| `mouse_confirm` | `<2-LeftMouse>` | patched (telescope's only gap) | native (fzf's own mouse handling) | export only¹ (native default too) |

¹ snacks: pickers.nvim doesn't own `Snacks.setup()`, so nothing is auto-registered there — merge `require("pickers.keys").snacks_win()` into your own `snacks.setup({ picker = { win = ... } })`.

`create_file`/`open_background` run pickers.nvim-specific logic (`lua/pickers/entry_actions/`), not a built-in engine action — merge them into your own engine `setup()` manually via `entry_actions/adapters/{telescope,fzf,snacks}.lua`'s `get_mappings()`/`get_actions()`/`get_keys()`.

---

