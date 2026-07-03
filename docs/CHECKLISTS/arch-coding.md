# Arch & Coding-Regeln — applied to pickers.nvim

| § | Rule | Status | Notes |
|---|---|---|---|
| 1 | pcall / type guards / explicit returns / no notify in low-level | ✅ | Engines wrap calls in `pcall`/`safe_call`; `config.normalise_collection` type-checks; sources validate dirs before use. Notifications only via `lib.nvim.notify`. |
| 1 | Private helpers stay local | ✅ | Helpers in engines/sources/bindings are file-local; only the module API is returned. |
| 2 | Modul = eine Verantwortung | ✅ | Clear split: `sources/*`, `actions/*`, `engines/*`, `ui/*`, `bindings/*`, `config/*`, `command/`. |
| 2 | Keine globalen States | ⚠️ | No `_G.*`. Uses `vim.g.pickers_nvim_loaded` / `vim.g.pickers_nvim_setup_called` as intentional plugin-load guards (idiomatic, acceptable). Config state is a module-local singleton. |
| 3 | Buffer-/Window-Management (bind → validate → use) | ✅ | pickers opens no raw windows; UI is delegated to `lib.nvim.ui.hover_select` / telescope / fzf. The one `nvim_win_close` (fzf double-esc) is `pcall`-guarded. |
| 4 | Metatables / Getter-Setter | N/A | No custom data models needing metatables; config is a plain table behind `get()`/`apply()`. |
| 5 | Doku & Annotationen (`@module`/`@brief`/`@description`, `@param`/`@return`) | ✅ | Every file has header tags; public functions annotated. English throughout. |
| 5 | README (de) + `/doc/*.txt` (en) | ⚠️ | Has English README + `doc/pickers.txt`. The rule wants a **German** README for `nvim/config` modules — but that rule targets config modules, not standalone published plugins. Kept English by design (checklist item 1 of CHECKLIST.md: "README should be English"). |
| 5 | `@types` folder | ✅ | Per-subdirectory `@types` folders: `engines/@types` (Engine/EngineOpts), `sources/@types` (Scope/Source/Collection), `command/@types` (Action), `config/@types` (Keymaps/Usercmds/FindOpts/Config). Root `@types` is an index. |
| 6 | Testbarkeit & Lesbarkeit (SRP, pure functions, test entry) | ✅ | `to_pascal`, `normalise_collection`, `command.complete` are pure/near-pure and unit-tested under `docs/TESTS/`. |
| 7 | Structured error wrapping (`safe_call`) | ✅ | `lua/pickers/error.lua` defines `Pickers.Error`/`Pickers.ErrorKind` + `safe_call() → { ok, result, err }`, adopted in the command dispatcher. Engines keep their local notify-on-error `safe_call`. |
| 8–11 | Performance / weak tables / memoisation / GC / hot-path table+string tricks | N/A | No hot paths, no large tables, no string building in loops. Micro-optimisation rules don't apply to a thin command→engine dispatcher. |
| MISC | Cross-platform (POSIX + Windows) | ✅ | Windows-tested this session; `drives` uses `lib.nvim.cross`; the `system` fd-pattern bug was fixed. |
| lib | Use `lib.nvim` wrappers (notify/map/cross/hover_select/usercmd/autocmd) | ✅ | notify ✅, map ✅, cross ✅, hover_select ✅, usercmd ✅ (`lib.nvim.usercmd`, raw fallback), autocmd ✅ (`lib.nvim.autocmd` + `pickers.nvim` augroup, raw fallback). |
| Import order | System → Debug/Notify → Config/Utils → State → UI → Controller → Keymaps | ✅ | `notify` is required near the top; lazy requires inside callbacks. |

## Open items (→ ROADMAP)
- ✅ Replaced raw `nvim_create_user_command` with `lib.nvim.usercmd` (2 call sites).
- ✅ Replaced raw `nvim_create_autocmd` with `lib.nvim.autocmd` + `pickers.nvim` augroup.
- ✅ Structured error types (`lua/pickers/error.lua`), adopted in the dispatcher.
- ✅ Per-subdirectory `@types` split (engines/sources/command/config).
