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
---
--- Engine is always taken from config; it is never exposed in the command.

local notify = require("lib.nvim.notify").create("[pickers.command]")

local M = {}

-- ── Constants ─────────────────────────────────────────────────────────────────

local SCOPES  = { "cwd", "config", "folder", "repos", "wkdbooks", "system", "drives", "dir" }
local ACTIONS = { "files", "grep" }

local SCOPES_SET  = {}
for _, s in ipairs(SCOPES)  do SCOPES_SET[s]  = true end
local ACTIONS_SET = {}
for _, a in ipairs(ACTIONS) do ACTIONS_SET[a] = true end

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

---Run a non-dir scope.
---@param scope      Pickers.Scope
---@param action     Pickers.Action|nil
---@param engine_mod table
local function run_standard_scope(scope, action, engine_mod)
  local cfg         = require("pickers.config").get()
  local ok, src_mod = pcall(require, "pickers.sources." .. scope)
  if not ok or not src_mod then
    notify.error("Unknown scope '" .. scope .. "'")
    return
  end

  -- folder / repos / wkdbooks need the engine for their interactive pickers
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

  -- :Pickers → interactive scope picker
  if not scope or scope == "" then
    require("pickers.ui.scope_picker").open(function(chosen)
      if chosen then
        if chosen == "dir" then
          require("pickers.actions.dir").run(nil, nil, engine_mod)
        else
          run_standard_scope(chosen, nil, engine_mod)
        end
      end
    end)
    return
  end

  if not SCOPES_SET[scope] then
    notify.error("Unknown scope '" .. scope .. "'. Valid: " .. table.concat(SCOPES, ", "))
    return
  end

  -- dir scope — special: arg2 can be nav OR action
  if scope == "dir" then
    local nav_arg = arg2
    local action  = arg3

    -- If arg2 is an action keyword, treat it as the action with nav = nil
    if arg2 and ACTIONS_SET[arg2] then
      nav_arg = nil
      action  = arg2
    end

    require("pickers.actions.dir").run(nav_arg, action, engine_mod)
    return
  end

  -- All other scopes: arg2 is the action
  local action = arg2
  if action and not ACTIONS_SET[action] then
    notify.warn("Unknown action '" .. action .. "'. Valid: files, grep. Showing action picker.")
    action = nil
  end

  run_standard_scope(scope, action, engine_mod)
end

-- ── Public: complete ──────────────────────────────────────────────────────────

---Tab-completion for :Pickers.
---@param arglead  string
---@param cmdline  string
---@return string[]
function M.complete(arglead, cmdline, _)
  -- Count tokens already typed (excluding the "Pickers" command word)
  local after_cmd = cmdline:match("^%s*Pickers%s+(.-)%s*$") or ""

  local tokens = {}
  for t in after_cmd:gmatch("%S+") do
    tokens[#tokens + 1] = t
  end

  -- If arglead is non-empty and matches the last token, that token is the
  -- partial word being completed — it doesn't count as a "finished" token.
  local n_finished = #tokens
  if arglead ~= "" and tokens[#tokens] == arglead then
    n_finished = n_finished - 1
  end

  ---Filter candidates by arglead prefix (case-insensitive).
  local function filter(candidates)
    if arglead == "" then return candidates end
    local lead = arglead:lower()
    local out  = {}
    for _, c in ipairs(candidates) do
      if c:lower():sub(1, #lead) == lead then
        out[#out + 1] = c
      end
    end
    return out
  end

  -- Position 0: completing the scope
  if n_finished == 0 then
    return filter(SCOPES)
  end

  local scope = tokens[1]

  if scope == "dir" then
    if n_finished == 1 then
      -- Completing second arg: can be nav alias | digit | "files" | "grep"
      local aliases     = require("pickers.actions.dir").alias_names()
      local candidates  = vim.list_extend({}, ACTIONS)
      vim.list_extend(candidates, aliases)
      for i = 1, 9 do candidates[#candidates + 1] = tostring(i) end
      candidates[#candidates + 1] = "path="
      return filter(candidates)
    elseif n_finished == 2 then
      -- Completing third arg: action
      return filter(ACTIONS)
    end
  else
    if n_finished == 1 then
      return filter(ACTIONS)
    end
  end

  return {}
end

return M
