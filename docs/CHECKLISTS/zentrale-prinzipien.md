# Zentrale Prinzipien — applied to pickers.nvim

The source is a *mental* audit (questions, not checkboxes). Answered for this repo.

| # | Principle | Answer for pickers.nvim |
|---|---|---|
| 1 | Events bündeln, Logik entkoppeln | ✅ Exactly **one** autocmd (`VimEnter` fallback in `bindings/autocmds.lua`). No duplicated event wiring. |
| 2 | Eigene Logik lazy laden | ✅ Command/source/engine modules are `require`d lazily inside callbacks; `plugin/pickers.lua` only registers `:Pickers` + one autocmd. Nothing heavy at startup. |
| 3 | Kontext statt Mehrfach-API-Zugriffe | ✅ Config is fetched once via `pickers.config.get()` (memoised singleton). Sources build a single `Pickers.Source`. |
| 4 | Autocommand-Gruppen sauber nutzen | ✅ The `VimEnter` autocmd now lives in the named `pickers.nvim` augroup via `lib.nvim.autocmd` (reload-safe), `once=true`. |
| 5 | Event oder Command? | ✅ Everything is command/keymap-driven; the only autocmd is a one-shot startup fallback, not per-buffer logic. |
| 6 | Treesitter notwendig? | N/A — no Treesitter use. |
| 7 | Cache vorhanden und explizit? | ✅ `drives` source caches discovered mounts per session (documented). Config is memoised. No hidden runtime caches. |
| 8 | Allokationen im Hot-Path | ✅ No hot paths (no `CursorMoved`/`TextChanged` handlers). Listing is delegated to fd/rg via the engine. |
| 9 | Debugbarkeit | ✅ All modules notify via `lib.nvim.notify` with a `[pickers.*]` tag; `:checkhealth pickers` covers deps/engines/config. |
| 10 | Laufzeit wichtiger als Startup? | ✅ No frequent-event code. Startup cost is minimal. |

**Verdict:** structurally sound. All 10 principles satisfied (point 4 addressed via the `pickers.nvim` augroup).
