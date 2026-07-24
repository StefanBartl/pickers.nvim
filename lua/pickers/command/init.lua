---@module 'pickers.command'
---@brief :Pickers command handler.
---@see pickers.command.composer for :Pickers registration + tab-completion
---@description
--- Command syntax:
---   :Pickers                              → interactive scope picker
---   :Pickers <scope>                      → interactive action picker
---   :Pickers <scope> <action>             → direct
---   :Pickers dir                          → interactive nav → action
---   :Pickers dir <nav>                    → nav resolved → interactive action
---   :Pickers dir <action>                 → nav=cwd, action direct   (files|grep)
---   :Pickers dir <nav> <action>           → fully specified
---   :Pickers <collection>                 → collection as root → action picker
---   :Pickers <collection> <action>        → collection root + direct action
---
--- Engine is always taken from config; it is never exposed in the command.
--- M.handle is the dispatch engine called both by the composer-registered
--- :Pickers command and every compat alias (usrcmds.lua, collections.lua,
--- keymaps.lua) via `{ fargs = {...} }`.
---
--- Every fully-resolved dispatch (concrete action + source, the point where
--- an engine picker actually opens) is recorded in `pickers.last`, so
--- `:PickersRepeat` can reopen the exact same scope/root/action without
--- re-resolving through any interactive sub-picker (folder/repo/collection
--- subdir) in between.

local notify = require("lib.nvim.notify").create("[pickers.command]")
local perr = require("pickers.error")

local M = {}

-- ── Constants ─────────────────────────────────────────────────────────────────

local BASE_SCOPES = { "cwd", "config", "folder", "repos", "wkdbooks", "system", "drives", "dir" }

local BASE_SCOPES_SET = {}
for _, s in ipairs(BASE_SCOPES) do
  BASE_SCOPES_SET[s] = true
end
local ACTIONS_SET = { files = true, grep = true, smart = true }

-- ── Helpers ───────────────────────────────────────────────────────────────────

---Find a collection by name in the active config.
---@param name string
---@return Pickers.Collection|nil
local function find_collection(name)
  local ok, cfg_mod = pcall(require, "pickers.config")
  if not ok then return nil end
  local cfg = cfg_mod.get()
  for _, coll in ipairs(cfg.collections or {}) do
    if coll.name == name then return coll end
  end
  return nil
end

-- ── Routing helpers ───────────────────────────────────────────────────────────

---@param action     Pickers.Action
---@param source     Pickers.Source
---@param engine_mod table
local function dispatch_action(action, source, engine_mod)
  require("pickers.last").set(action, source)
  if action == "grep" then
    require("pickers.actions.grep").run(source, engine_mod)
  elseif action == "smart" then
    require("pickers.actions.smart").run(source, engine_mod)
  else
    require("pickers.actions.files").run(source, engine_mod)
  end
end

---Public entry point for `pickers.last.run()` to replay a previously
---recorded {action, source} pair without going through M.handle.
---@param action     Pickers.Action
---@param source     Pickers.Source
---@param engine_mod table
function M.dispatch(action, source, engine_mod)
  dispatch_action(action, source, engine_mod)
end

---@param source     Pickers.Source|nil
---@param action     Pickers.Action|nil
---@param engine_mod table
local function after_source(source, action, engine_mod)
  if not source then return end
  if action then
    dispatch_action(action, source, engine_mod)
  else
    require("pickers.ui.action_picker").open(function(chosen)
      if chosen then dispatch_action(chosen, source, engine_mod) end
    end)
  end
end

---Run a built-in (non-dir) scope.
---@param scope      string
---@param action     Pickers.Action|nil
---@param engine_mod table
local function run_standard_scope(scope, action, engine_mod)
  local cfg = require("pickers.config").get()
  local ok, src_mod = pcall(require, "pickers.sources." .. scope)
  if not ok or not src_mod then
    notify.error(
      perr.tostring(perr.new("SourceError", "no source module for scope '" .. scope .. "'"))
    )
    return
  end
  -- folder / repos / wkdbooks need engine_mod for their sub-pickers
  if scope == "folder" or scope == "repos" or scope == "wkdbooks" then
    src_mod.get(cfg, function(source)
      after_source(source, action, engine_mod)
    end, engine_mod)
  else
    src_mod.get(cfg, function(source)
      after_source(source, action, engine_mod)
    end)
  end
end

---Run a user-defined collection as a scope.
---@param coll       Pickers.Collection
---@param action     Pickers.Action|nil
---@param engine_mod table
local function run_collection_scope(coll, action, engine_mod)
  local cfg = require("pickers.config").get()
  require("pickers.sources.collection").get(coll, cfg, function(source)
    after_source(source, action, engine_mod)
  end, engine_mod)
end

-- ── Public: handle ────────────────────────────────────────────────────────────

---Entry point called by the :Pickers user command.
---@param opts { fargs: string[] }
function M.handle(opts)
  local engine_mod = require("pickers.engines").load()
  if not engine_mod then return end

  local fargs = opts.fargs or {}
  local scope = fargs[1]
  local arg2 = fargs[2]
  local arg3 = fargs[3]

  -- :Pickers → interactive scope picker (built-ins + collections)
  if not scope or scope == "" then
    require("pickers.ui.scope_picker").open(function(chosen)
      if not chosen then return end
      if chosen == "dir" then
        require("pickers.actions.dir").run(nil, nil, engine_mod)
        return
      end
      if BASE_SCOPES_SET[chosen] then
        run_standard_scope(chosen, nil, engine_mod)
        return
      end
      local coll = find_collection(chosen)
      if coll then
        run_collection_scope(coll, nil, engine_mod)
        return
      end
      notify.error("Unknown scope from picker: '" .. chosen .. "'")
    end)
    return
  end

  -- dir scope — special: arg2 can be nav OR action
  if scope == "dir" then
    local nav_arg = arg2
    local action = arg3
    if arg2 and ACTIONS_SET[arg2] then
      nav_arg = nil
      action = arg2
    end
    require("pickers.actions.dir").run(nav_arg, action, engine_mod)
    return
  end

  -- Built-in scopes
  if BASE_SCOPES_SET[scope] then
    local action = arg2
    if action and not ACTIONS_SET[action] then
      notify.warn(
        "Unknown action '" .. action .. "'. Valid: files, grep, smart. Showing action picker."
      )
      action = nil
    end
    run_standard_scope(scope, action, engine_mod)
    return
  end

  -- Collection scopes (user-defined)
  local coll = find_collection(scope)
  if coll then
    local action = arg2
    if action and not ACTIONS_SET[action] then
      notify.warn(
        "Unknown action '" .. action .. "'. Valid: files, grep, smart. Showing action picker."
      )
      action = nil
    end
    run_collection_scope(coll, action, engine_mod)
    return
  end

  notify.error(
    perr.tostring(
      perr.new(
        "UnknownScopeError",
        "Unknown scope '"
          .. scope
          .. "'. "
          .. "Built-in: "
          .. table.concat(BASE_SCOPES, ", ")
          .. ". "
          .. "Run :checkhealth pickers to see your collections."
      )
    )
  )
end

return M
