---@module 'pickers.command.composer'
---@brief Registers :Pickers via lib.nvim.usercmd.composer.
---@description
--- Every route only supplies typed-arg schema for tab-completion + docgen;
--- dispatch itself is always delegated to pickers.command.handle (unchanged),
--- so :Pickers behaves byte-for-byte like before this migration — the same
--- dir nav/action ambiguity resolution, the same collection lookup, the same
--- "unknown scope" error text.
---
--- Called twice by design: once immediately at plugin load (no collections
--- known yet — matches the pre-setup() guarantee that :Pickers already
--- works for built-in scopes), and again from pickers.bindings.setup(cfg)
--- once real collections exist, so :Pickers <Tab> can offer them.

local composer = require("lib.nvim.usercmd.composer")

local M = {}

local BASE_SCOPES = { "cwd", "config", "folder", "repos", "wkdbooks", "system", "drives" }
local ACTION_VALUES = { "files", "grep", "smart" }

---Prefix-filter a candidate list (case-sensitive, matches composer's own convention).
---@param cands string[]
---@param lead string
---@return string[]
local function prefix(cands, lead)
  if lead == "" then return cands end
  local out = {}
  for _, c in ipairs(cands) do
    if c:sub(1, #lead) == lead then out[#out + 1] = c end
  end
  return out
end

-- dir's nav slot accepts aliases, numeric depth, "path=...", or (when the nav
-- is omitted) an action word — smarter than any built-in type, see
-- docs/ROADMAP/personal/lib_nvim/usrcmd_composer.md step 2.
composer.register_type("PICKERS_DIR_NAV", {
  validate = function(raw)
    return true, raw, nil
  end,
  complete = function(arg_lead)
    local candidates = vim.list_extend({}, ACTION_VALUES)
    vim.list_extend(candidates, require("pickers.actions.dir").alias_names())
    for i = 1, 9 do
      candidates[#candidates + 1] = tostring(i)
    end
    candidates[#candidates + 1] = "path="
    return prefix(candidates, arg_lead)
  end,
})

-- Registered builtin name — see pickers.builtins. Static list (the registry
-- doesn't depend on cfg), so a plain type (not cfg-driven like collections) is
-- enough; a custom type (not `enum`) because the candidate list is queried
-- from the registry rather than declared inline per-route.
composer.register_type("PICKERS_BUILTIN_NAME", {
  validate = function(raw)
    return true, raw, nil
  end,
  complete = function(arg_lead)
    return prefix(require("pickers.builtins").names(), arg_lead)
  end,
})

---@return Lib.UserCmd.Composer.ArgSpec
local function action_arg()
  return { name = "action", type = "STRING", values = ACTION_VALUES, optional = true }
end

---@param scope string
local function scope_route(scope)
  return {
    path = { scope },
    args = { action_arg() },
    desc = "Scope: " .. scope,
    run = function(ctx)
      require("pickers.command").handle({ fargs = { scope, ctx.pos[1] } })
    end,
  }
end

local function dir_route()
  return {
    path = { "dir" },
    args = { { name = "nav", type = "PICKERS_DIR_NAV", optional = true }, action_arg() },
    desc = "Directory navigation (depth / alias / explicit path)",
    run = function(ctx)
      require("pickers.command").handle({ fargs = { "dir", ctx.pos[1], ctx.pos[2] } })
    end,
  }
end

-- Native pickers (git/lsp/search/…) — not a scope×action, so it does not
-- delegate to pickers.command.handle; it dispatches straight to
-- pickers.builtins.run, which resolves the engine itself.
local function builtin_route()
  return {
    path = { "builtin" },
    args = { { name = "name", type = "PICKERS_BUILTIN_NAME" } },
    desc = "Native picker (git/lsp/search/…) — see docs/BUILTINS.md",
    run = function(ctx)
      require("pickers.builtins").run(ctx.pos[1])
    end,
  }
end

---@param name string
local function collection_route(name)
  return {
    path = { name },
    args = { action_arg() },
    desc = "User-defined collection: " .. name,
    run = function(ctx)
      require("pickers.command").handle({ fargs = { name, ctx.pos[1] } })
    end,
  }
end

---Register (or re-register) :Pickers, including one route per collection in cfg.
---A collection whose name collides with a built-in scope (or an earlier
---collection, duplicate names) is skipped — first-match-wins, mirroring the
---pre-composer `find_collection` lookup order.
---@param cfg Pickers.Config
function M.register(cfg)
  local routes = {}
  local used = {}

  for _, scope in ipairs(BASE_SCOPES) do
    routes[#routes + 1] = scope_route(scope)
    used[scope] = true
  end
  routes[#routes + 1] = dir_route()
  used.dir = true
  routes[#routes + 1] = builtin_route()
  used.builtin = true

  for _, coll in ipairs(cfg.collections or {}) do
    local name = coll.name
    if type(name) == "string" and name ~= "" and not used[name] then
      routes[#routes + 1] = collection_route(name)
      used[name] = true
    end
  end

  composer.verb("Pickers", {
    desc = "[pickers.nvim] :Pickers [scope] [nav|action] [action]",
    default = function(_)
      require("pickers.command").handle({ fargs = {} })
    end,
    routes = routes,
  })
end

return M
