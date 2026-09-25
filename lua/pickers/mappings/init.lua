---@module 'pickers.mappings'
---@brief Declarative `mappings` config: one flat surface listing every
---picker action by name, each with an lhs and an optional per-entry engine
---override.
---@description
--- Does NOT supersede the fixed `keymaps.*` fields (`cwd_files`, `cwd_grep`,
--- …) -- those stay as-is, engine-agnostic, no per-key override. `mappings`
--- is a second, more flexible surface: any scope×action combo AND any
--- builtin, all in one table, with an optional engine pinned per entry.
---
--- Name resolution (`<name>` is the `mappings` key):
---   <name> is a `pickers.builtins` name        -> builtin dispatch
---   <scope>_files | <scope>_grep | <scope>_smart -> pickers.command.handle
---   <scope>_find_all                            -> pickers.command.handle
---                                                   with the "all" modifier
--- `<scope>` is any built-in scope (cwd/config/folder/repos/system/drives)
--- or a user-defined collection name. `dir` is deliberately NOT
--- supported here -- same limitation as the "find all" escape hatch (see
--- `pickers.command`'s module @brief) -- its nav argument doesn't fit this
--- flat `<scope>_<action>` shape.
---
--- Per-entry engine override: `{ lhs, engine? }`, e.g.
---   mappings = {
---     find_files = { "<leader>ff", "telescope" }, -- always telescope
---     grep_cwd   = { "<leader>gr" },               -- active/default engine
---     explorer   = { "<leader>.",  "snacks" },     -- always snacks
---   }
--- `lhs` may be a list to bind several keys to one picker, and an entry may
--- carry `desc` (the which-key text) and `nowait`:
---   recent = { { "<leader>fo", "<leader>old" }, desc = "Recent files" }
---   lsp_references = { "GR", nowait = true }
--- An engine named but not installed falls back to the configured default
--- (never a dead keymap): builtins reuse `pickers.engines.load()`'s own
--- fallback-to-auto-detect logic (resolved once here, since
--- `pickers.builtins.run`'s own `engine_name` param does NOT re-verify
--- availability when given one explicitly); scope×action entries get the
--- same fallback for free via `pickers.command.handle`'s new `opts.engine`,
--- which threads straight into `pickers.engines.load(opts.engine)`.

local notify = require("lib.nvim.notify").create("[pickers.mappings]")

local M = {}

local BASE_SCOPES = {
  cwd = true,
  config = true,
  folder = true,
  repos = true,
  system = true,
  drives = true,
}

---Classify a mappings key into a dispatch shape. Exported (pure, no side
---effects) so it is unit-testable directly.
---@param name string
---@return "builtin"|"scope_action"|"find_all"|nil kind
---@return string|nil scope
---@return "files"|"grep"|"smart"|nil action
function M.classify(name)
  if vim.tbl_contains(require("pickers.builtins").names(), name) then return "builtin" end

  for _, action in ipairs({ "files", "grep", "smart" }) do
    local scope = name:match("^(.+)_" .. action .. "$")
    if scope and scope ~= "" then return "scope_action", scope, action end
  end

  local fa_scope = name:match("^(.+)_find_all$")
  if fa_scope and fa_scope ~= "" then return "find_all", fa_scope end

  return nil
end

---@internal
---@param scope string
---@return boolean
local function scope_exists(scope)
  if BASE_SCOPES[scope] then return true end
  local cfg = require("pickers.config").get()
  for _, coll in ipairs(cfg.collections or {}) do
    if coll.name == scope then return true end
  end
  return false
end

---One lhs string, or a non-empty list of them, as a list; nil when malformed.
---@internal
---@param v any
---@return string[]|nil
local function normalise_lhs(v)
  if type(v) == "string" then return v ~= "" and { v } or nil end
  if type(v) ~= "table" or #v == 0 then return nil end
  for _, x in ipairs(v) do
    if type(x) ~= "string" or x == "" then return nil end
  end
  return v
end

---Register every `cfg.mappings` entry as a normal-mode keymap. No-op when
---`cfg.mappings` is unset/empty. Unresolvable names/malformed entries are
---skipped with a warning, never a dead or throwing keymap.
---@param cfg Pickers.Config
function M.apply(cfg)
  local raw = cfg.mappings
  if type(raw) ~= "table" then return end

  for name, spec in pairs(raw) do
    local lhs_list = type(spec) == "table" and normalise_lhs(spec[1]) or nil
    if not lhs_list then
      notify.warn(
        "mappings."
          .. tostring(name)
          .. ": expected { lhs|{lhs...}, engine? }, got "
          .. vim.inspect(spec)
      )
    else
      local engine = type(spec[2]) == "string" and spec[2] or nil
      local kind, scope, action = M.classify(name)
      local map_opts = {
        desc = type(spec.desc) == "string" and spec.desc or ("[pickers] mapping: " .. name),
        nowait = spec.nowait == true or nil,
      }

      if kind == "builtin" then
        for _, lhs in ipairs(lhs_list) do
          vim.keymap.set("n", lhs, function()
            local _, resolved = require("pickers.engines").load(engine)
            require("pickers.builtins").run(name, nil, resolved)
          end, map_opts)
        end
      elseif (kind == "scope_action" or kind == "find_all") and scope and scope_exists(scope) then
        local fargs = (kind == "find_all") and { scope, "files", "all" } or { scope, action }
        for _, lhs in ipairs(lhs_list) do
          vim.keymap.set("n", lhs, function()
            require("pickers.command").handle({ fargs = fargs, engine = engine })
          end, map_opts)
        end
      else
        notify.warn(
          "mappings."
            .. name
            .. ": unresolvable name, skipping. Expected a pickers.builtins "
            .. "name or <scope>_<files|grep|smart|find_all> with a known scope/collection."
        )
      end
    end
  end
end

return M
