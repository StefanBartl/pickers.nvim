# Schnell-Check & PR-Review — applied to pickers.nvim

## Schnell-Check (10 points)

| Status | Check | pickers.nvim |
|---|---|---|
| ✅ | Fehlerbehandlung | `pcall`/`safe_call` around engine + require calls; failures notify, never silent. |
| ✅ | Type Guards | `type(...)`/nil checks before use (config, command routing, sources). |
| ✅ | Buffer/Window validieren | No raw windows; the one `nvim_win_close` is `pcall`-guarded. |
| ⚠️ | Keine globalen States | No `_G.*`; two `vim.g.*` load-guards (intentional/idiomatic). |
| ✅ | Single Responsibility | Modules each own one concern. |
| ✅ | UI-Cleanup | UI delegated to hover_select/telescope/fzf, which own their cleanup. |
| ✅ | Performance-Hotspots | None; dispatcher only. |
| ✅ | Annotationen vollständig | `@module`/`@brief`/`@param`/`@return` + central `@types`. |
| ✅ | Testbarkeit | Pure helpers unit-tested (`docs/TESTS`). |
| ✅ | Import-Reihenfolge | Followed. |

## PR-Review detail

| § | Item | Status |
|---|---|---|
| 1 | pcall/xpcall, structured errors, explicit returns, guards before API | ✅ / ⚠️ (no structured error *types* — see arch-coding.md §7) |
| 2 | SRP, no globals, pure functions, local helpers, registry, `/config/DEFAULTS.lua` | ✅ (DEFAULTS.lua added; sources act as a de-facto registry via `require("pickers.sources."..scope)`) |
| 3 | Buffer/window bind→validate, valid-checks, unified API, cleanup, race conditions | ✅ (no raw windows; guarded close) |
| 4 | UI-State: central getter/setter, snapshot/restore | N/A (no persistent UI state) |
| 5 | Doc head-tags, function tags, aliases/types, comment convention | ✅ |
| 6 | DI over hard-wiring, pure functions, test entry | ✅ (engine passed in as `engine_mod`; config injectable via `setup()`) |
| 7 | **Tooling: Lua LS settings; formatter/linter (stylua, luacheck) in CI** | ✅ `.luarc.json` ✅; `stylua.toml` + `.luacheckrc` + GitHub Actions CI added (linters advisory, test suite gating) |

## Coding checklist (A–F)

| Group | Status |
|---|---|
| A Strings/Tables | N/A (no loops building strings/large tables) |
| B Performance-Quickwins | N/A (no hot loops) |
| C Neovim-API sicher | ✅ (guarded) |
| D State-/Datenmodelle | N/A |
| E GC bewusst steuern | N/A |
| F Lazy-Loading / On-Demand config | ✅ (lazy requires; memoised config) |

## N/A sections
Sorting algorithms · insert/delete/update/search data structures · complexity
notation · bit tricks — pickers.nvim implements none of these.

## Open items (→ ROADMAP)
- ✅ Added `stylua.toml` + `.luacheckrc` + GitHub Actions (`.github/workflows/ci.yml`).
- ✅ Linters are now **gating**: repo is stylua-formatted and luacheck-clean
  (0 warnings). `docs/BINDINGS.md` is excluded from stylua (`.styluaignore`).
