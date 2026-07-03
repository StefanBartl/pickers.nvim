# Filetree feature audit → `filetree.nvim`

Inventory of the custom filetree features implemented in the Neovim config
(`~/AppData/Local/nvim`). The goal (per `FINISH.md`) is to migrate these into a
standalone **`filetree.nvim`** that is **cross-platform** and
**filetree-manager-agnostic** (Neo-tree today, but the logic should not depend
on it).

- **Primary manager:** Neo-tree — heavily customised under `lua/config/neotree/`.
- **nvim-tree / netrw:** not actively customised. netrw appears only incidentally
  (`lua/autocmds/auto-center-fexplorer.lua`, disabled in `lua/config/lazy/init.lua`,
  referenced in `lua/bindings/usrcmds/init.lua`). Nothing to migrate from them.

Origin paths are relative to the config's `lua/config/neotree/`. Each module
(`init.lua` in its folder) is one migratable unit.

Legend — **Portability**: 🟢 already cross-platform / manager-agnostic ·
🟡 partly (some Neo-tree/OS coupling) · 🔴 tightly coupled to Neo-tree state/API.

---

## 1. Node actions (`actions/`)

The reusable "do something with the node under the cursor" logic. Prime
migration targets — most are close to manager-agnostic already.

| Feature | Origin | Keymap (filesystem) | Portability | Notes |
|---|---|---|---|---|
| Bi-directional tree navigation (into dir → set root / up one level) | `actions/traverse/` | `+` / `-` (`keymaps/filesystem/navigation.lua`) | 🟡 | Uses Neo-tree state; navigation concept is generic. |
| Node info hover (file/dir info, line count) | `actions/info/node/` | `keymaps/filesystem/info.lua` | 🟡 | Toggleable float; reads node path — portable once path is abstracted. |
| Open with OS-default app | `actions/open_system_app/` + `open/system_app/` | `keymaps/filesystem/info.lua`, `images.lua` | 🟢 | Already a cross-platform opener. |
| Open in system file manager | `open/filemanager/` | `keymaps/filesystem/info.lua` | 🟢 | Cross-platform dispatcher. |
| Copy Lua `require()` string(s) from node | `actions/path/to_require/`, `actions/rel_path_to_require/` | `keymaps/filesystem/info.lua`, `path.lua` | 🟢 | Pure path→string transform. |
| Copy path (abs/rel, file/dir, recursive lists) to `+` | `actions/copy/to_clipboard/`, `copy/entries/`, `copy/folders/` | `keymaps/filesystem/path.lua` | 🟢 | Path formatting + clipboard; OS-agnostic via `lib.nvim`. |
| Grep in node directory (telescope / fzf-lua unified) | `actions/grep_picker/` | `keymaps/filesystem/search.lua` | 🟢 | Already picker-agnostic — overlaps with `pickers.nvim`. |
| Open PDF via pdfport | `actions/pdfport/` | `keymaps/filesystem/pdfport.lua` | 🟡 | External tool dependency. |
| Resolve project root (LazyVim-style, no dep) | `actions/project_root/` | — | 🟢 | Generic root resolver; candidate for `lib.nvim`. |
| Save adjacent / node buffer (force `w!`) | `actions/save/adjacent_buffer/`, `save/node_buffer/` | `keymaps/filesystem/save.lua` | 🟡 | Maps a node to its buffer. |
| Open node & replace current buffer | `actions/node_replace_buf/` | `keymaps/filesystem/replace.lua` | 🟡 | Buffer/window handling. |
| Node information dump | `actions/node_informations/` | — | 🟡 | Debug/inspection helper. |

## 2. Commands (`commands/`)

| Feature | Origin | Keymap | Portability | Notes |
|---|---|---|---|---|
| Enhanced clipboard (cut/copy/paste/clear, mark-aware) | `commands/clipboard/` | `keymaps/filesystem/clipboard.lua` | 🟡 | Works with the mark set below. |
| Mark / unmark nodes (single, dir, all) + show marks | `commands/mark/` (+ `mark/show.lua`) | `keymaps/filesystem/mark.lua` | 🟡 | Multi-select primitive; reusable concept. |
| Diff two marked files | `commands/diff_files/` | `keymaps/filesystem/create.lua` | 🟢 | `vimdiff` on two paths. |
| Add file/dir (typed template) | `commands/add/` (+ `types_template.lua`) | `keymaps/filesystem/create.lua` | 🟡 | Creation with scaffolding. |
| Telescope opts builder | `commands/get_telescope_opts/` | — | 🟡 | Telescope-specific; generalise for picker-agnostic. |
| Source command | `commands/source/` | — | 🔴 | Neo-tree source concept. |

## 3. Safe file operations (`safety/`) — 🟢 strong migration candidate

A robust, largely manager-independent safety layer around destructive ops.

| Feature | Origin | Notes |
|---|---|---|
| Aggregated safety facade | `safety/` | Single entry point. |
| Automatic backup before destructive ops | `safety/backup/` | Snapshot before delete/move. |
| Dry-run mode | `safety/dry_run/` | Test ops without executing. |
| File-operation wrapper + quarantine | `safety/file_operatiuon_wrapper/` (note: filename typo `operatiuon`) | Auto-quarantine management. |
| Sequential operation queue | `safety/operation_queue/` | Serialises file ops. |
| Automatic recovery from failures | `safety/recovery/` | Rollback on failure. |
| Input validation | `safety/validation/` | Guards inputs. |

## 4. Trash (`trash/`) — 🟢 cross-platform

| Feature | Origin | Keymap | Notes |
|---|---|---|---|
| Trash orchestrator | `trash/` | `keymaps/filesystem/trash.lua` | Delete marked / node under cursor. |
| Cross-platform trash backend | `trash/platform/` | — | 🟢 OS-specific trash. |
| Confirmation dialogs | `trash/confirmation/` | — | User prompts. |
| Execute without re-confirm | `trash/operations/` | — | Batch. |
| Undo last trash / history | `trash/` | `keymaps/filesystem/trash.lua` | Restore + history view. |

## 5. Window / layout / view

| Feature | Origin | Keymap | Portability | Notes |
|---|---|---|---|---|
| Reveal current file in tree | `window/open/keymaps/reveal_current_file.lua`, `reveal/` | — | 🟡 | `:e #`-style reveal. |
| Constrained window open (only-lhs keymaps) | `window/open/keymaps/only_lhs.lua` | — | 🟡 | Restricts keymaps in tree window. |
| Layout guard | `layout_guard/` | — | 🟡 | Protects window layout from tree churn. |
| Floating preview toggle | — | `keymaps/filesystem/preview.lua` | 🟡 | Preview window. |
| Current-line highlight | `current_hl/` | — | 🟡 | Highlight active node. |
| Custom renderer components | `components/` | — | 🔴 | Neo-tree component API. |
| Window resize | — | `keymaps/init.lua` | 🟢 | Generic. |

## 6. State sync & lifecycle

| Feature | Origin | Portability | Notes |
|---|---|---|---|
| CWD ↔ tree sync | `cwd_sync/` | 🟡 | Keeps tree root and `:cd` aligned. |
| Autocmds / event handlers | `autocmds/`, `event_handlers/` | 🔴 | Wired to Neo-tree events. |
| Refresh adapter | `refresh_adapter/` | 🟡 | Abstracts refresh — good agnostic seed. |
| Watcher quarantine | `watcher_quarantine/` | 🟡 | Suppresses fs-watcher noise during ops. |
| State / undo / utils | `state/`, `undo/`, `utils/` | 🟡 | Support layer. |
| Sources + switcher | `sources/`, `sources/switcher` | 🔴 | `<leader>ns` switch source (`keymaps/global.lua`). |

## 7. Diagnostics / integration keymaps

| Area | Origin | Notes |
|---|---|---|
| Buffers / diagnostics / document symbols / git status sources | `keymaps/{buffers,diagnostics,document_symbols,git_status}.lua` | Neo-tree source integrations (built-in commands). |
| Test keymaps | `keymaps/tests.lua` | Dev/testing bindings. |
| Health checks | `checkhealth/` (`core`, `actions`, `features`, `utils`) | Reusable pattern — mirror in `filetree.nvim`. |
| `usercmds/` | `usercmds/` | User commands surface. |

---

## Migration guidance for `filetree.nvim`

**Tier 1 — lift almost as-is (manager-agnostic, cross-platform):**
`open/system_app`, `open/filemanager`, `trash/platform`, `safety/*`,
`actions/path/to_require` + `rel_path_to_require`, `actions/copy/*`,
`actions/project_root`, `actions/grep_picker`, `commands/diff_files`.

**Tier 2 — needs a thin node/state abstraction** (define a
`FiletreeNode { path, type, bufnr? }` + `reveal/select/refresh` interface so the
logic stops touching Neo-tree state directly): `traverse`, `info/node`,
`save/*`, `node_replace_buf`, `mark`, `clipboard`, `cwd_sync`,
`refresh_adapter`, `layout_guard`, `watcher_quarantine`, window reveal.

**Tier 3 — Neo-tree-specific, reimplement per manager:** `components/`,
`event_handlers/`, `autocmds/`, `sources/` + source keymaps.

**Cross-cutting:** route all OS calls through `lib.nvim.cross`; fix the
`safety/file_operatiuon_wrapper` folder-name typo during extraction;
`actions/grep_picker` overlaps `pickers.nvim` — consider sharing.

> Origins are given at module (folder) granularity — the practical migration
> unit. Drill into each folder's `init.lua` for exact line references.
