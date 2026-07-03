---@module 'pickers.command'
---@brief :Pickers command handler and tab-completion logic.
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

local notify = require("lib.nvim.notify").create("[pickers.command]")
local perr   = require("pickers.error")

local M = {}

-- ── Constants ─────────────────────────────────────────────────────────────────

local BASE_SCOPES = { "cwd", "config", "folder", "repos", "wkdbooks", "system", "drives", "dir" }
local ACTIONS     = { "files", "grep" }

local BASE_SCOPES_SET = {}
for _, s in ipairs(BASE_SCOPES) do BASE_SCOPES_SET[s] = true end
local ACTIONS_SET = {}
for _, a in ipairs(ACTIONS) do ACTIONS_SET[a] = true end

-- ── Helpers ───────────────────────────────────────────────────────────────────

---Return collection names from the active config.
---@return string[]
local function get_collection_names()
  local ok, cfg_mod = pcall(require, "pickers.config")
  if not ok then return {} end
  local cfg   = cfg_mod.get()
  local names = {}
  for _, coll in ipairs(cfg.collections or {}) do
    if type(coll.name) == "string" then names[#names + 1] = coll.name end
  end
  return names
end

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
  if action == "grep" then
    require("pickers.actions.grep").run(source, engine_mod)
  else
    require("pickers.actions.files").run(source, engine_mod)
  end
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
  local cfg         = require("pickers.config").get()
  local ok, src_mod = pcall(require, "pickers.sources." .. scope)
  if not ok or not src_mod then
    notify.error(perr.tostring(perr.new("SourceError", "no source module for scope '" .. scope .. "'")))
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
  local arg2  = fargs[2]
  local arg3  = fargs[3]

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
      if coll then run_collection_scope(coll, nil, engine_mod); return end
      notify.error("Unknown scope from picker: '" .. chosen .. "'")
    end)
    return
  end

  -- dir scope — special: arg2 can be nav OR action
  if scope == "dir" then
    local nav_arg = arg2
    local action  = arg3
    if arg2 and ACTIONS_SET[arg2] then nav_arg = nil; action = arg2 end
    require("pickers.actions.dir").run(nav_arg, action, engine_mod)
    return
  end

  -- Built-in scopes
  if BASE_SCOPES_SET[scope] then
    local action = arg2
    if action and not ACTIONS_SET[action] then
      notify.warn("Unknown action '" .. action .. "'. Valid: files, grep. Showing action picker.")
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
      notify.warn("Unknown action '" .. action .. "'. Valid: files, grep. Showing action picker.")
      action = nil
    end
    run_collection_scope(coll, action, engine_mod)
    return
  end

  notify.error(perr.tostring(perr.new(
    "UnknownScopeError",
    "Unknown scope '" .. scope .. "'. "
    .. "Built-in: " .. table.concat(BASE_SCOPES, ", ") .. ". "
    .. "Run :checkhealth pickers to see your collections."
  )))
end

-- ── Public: complete ──────────────────────────────────────────────────────────

---Tab-completion for :Pickers.
---@param arglead  string
---@param cmdline  string
---@return string[]
function M.complete(arglead, cmdline, _)
  local after_cmd = cmdline:match("^%s*Pickers%s+(.-)%s*$") or ""
  local tokens    = {}
  for t in after_cmd:gmatch("%S+") do tokens[#tokens + 1] = t end

  local n_finished = #tokens
  if arglead ~= "" and tokens[#tokens] == arglead then n_finished = n_finished - 1 end

  local function filter(candidates)
    if arglead == "" then return candidates end
    local lead = arglead:lower()
    local out  = {}
    for _, c in ipairs(candidates) do
      if c:lower():sub(1, #lead) == lead then out[#out + 1] = c end
    end
    return out
  end

  -- Position 0: completing scope → built-ins + collection names
  if n_finished == 0 then
    local all_scopes = vim.list_extend(vim.list_extend({}, BASE_SCOPES), get_collection_names())
    return filter(all_scopes)
  end

  local scope = tokens[1]
  if scope == "dir" then
    if n_finished == 1 then
      local aliases    = require("pickers.actions.dir").alias_names()
      local candidates = vim.list_extend({}, ACTIONS)
      vim.list_extend(candidates, aliases)
      for i = 1, 9 do candidates[#candidates + 1] = tostring(i) end
      candidates[#candidates + 1] = "path="
      return filter(candidates)
    elseif n_finished == 2 then
      return filter(ACTIONS)
    end
  else
    if n_finished == 1 then return filter(ACTIONS) end
  end

  return {}
end

return M
