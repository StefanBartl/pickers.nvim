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
| 5 | `@types` folder | ⚠️ | Central `lua/pickers/@types/init.lua` (all types). Rule prefers a `/types` folder **per subdirectory**; central is acceptable (the rule's own demo uses a central types file) but deviates from the per-subdir ideal. Low value to split. |
| 6 | Testbarkeit & Lesbarkeit (SRP, pure functions, test entry) | ✅ | `to_pascal`, `normalise_collection`, `command.complete` are pure/near-pure and unit-tested under `docs/TESTS/`. |
| 7 | Structured error wrapping (`safe_call`) | ⚠️ | Engines have a local `safe_call` that notifies on error. No structured error **types** (`InvalidStateError`, …) — not needed at this size; the flows fail soft with a notify. |
| 8–11 | Performance / weak tables / memoisation / GC / hot-path table+string tricks | N/A | No hot paths, no large tables, no string building in loops. Micro-optimisation rules don't apply to a thin command→engine dispatcher. |
| MISC | Cross-platform (POSIX + Windows) | ✅ | Windows-tested this session; `drives` uses `lib.nvim.cross`; the `system` fd-pattern bug was fixed. |
| lib | Use `lib.nvim` wrappers (notify/map/cross/hover_select/usercmd/autocmd) | ⚠️ | notify ✅, map ✅, cross ✅, hover_select ✅. **Gap:** raw `vim.api.nvim_create_user_command` (`plugin/pickers.lua`, `bindings/util.lua`) and raw `nvim_create_autocmd` (`bindings/autocmds.lua`) instead of `lib.nvim.usercmd` / `lib.nvim.autocmd`. → ROADMAP. |
| Import order | System → Debug/Notify → Config/Utils → State → UI → Controller → Keymaps | ✅ | `notify` is required near the top; lazy requires inside callbacks. |

## Open items (→ ROADMAP)
- Replace raw `nvim_create_user_command` with `lib.nvim.usercmd` (2 call sites).
- Replace raw `nvim_create_autocmd` with `lib.nvim.autocmd` + a named augroup.
- (Optional) structured error types if flows grow.
- (Optional) per-subdirectory `@types` split.
