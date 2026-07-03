---@module 'pickers.types'
---@brief Type-definition index for pickers.nvim.
---@description
--- Types are split into per-subdirectory `@types` folders so each layer owns
--- its own definitions (LuaLS resolves them workspace-wide). This root file is
--- only a map; it defines nothing itself.
---
---   engines/@types  → Pickers.Engine, Pickers.EngineOpts
---   sources/@types  → Pickers.Scope, Pickers.Source, Pickers.Collection
---   command/@types  → Pickers.Action
---   config/@types   → Pickers.Keymaps, Pickers.Usercmds, Pickers.FindOpts, Pickers.Config
---
--- Runtime error types live in `pickers.error` (Pickers.Error / Pickers.ErrorKind).

return {}
