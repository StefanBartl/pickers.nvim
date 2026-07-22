---@module 'pickers.bindings.usrcmds'
---@brief Built-in compat user-commands (registered when usercmds.enable = true).
---@description
---   :DirPicker [nav]  :FindInFolder  :FindConfig  :GrepConfig
---   :LiveGrep  :AllDrives  :AllDrivesGrep  :FindOnSystem
---   :RepoFiles [repo]  :RepoGrep [repo]  :WkdBookFiles  :WkdBookGrep
---   :PickersRepeat  :PickersScopes
---
--- :RepoFiles/:RepoGrep accept an optional repo-name argument (tab-completed
--- from REPOS_DIR) that jumps straight into files/grep for that repo, skipping
--- the interactive repo picker.
---
--- :PickersRepeat reopens the most recently dispatched :Pickers action (same
--- resolved scope/root, same action) without re-resolving through any
--- interactive sub-picker in between -- see pickers.last.
---
--- :PickersScopes lists every scope :Pickers can resolve -- built-ins (with a
--- one-line description) plus every user-defined collection (with its root
--- dir) -- without opening the interactive scope picker.

local usercmd = require("pickers.bindings.util").usercmd
local notify = require("lib.nvim.notify").create("[pickers]")

local M = {}

---Run :RepoFiles/:RepoGrep, resolving `name` directly when given, falling
---back to the interactive repo picker otherwise.
---@param name   string|nil
---@param action  "files"|"grep"
local function run_repo_action(name, action)
  if not name or name == "" then
    require("pickers.command").handle({ fargs = { "repos", action } })
    return
  end

  local cfg = require("pickers.config").get()
  local path = require("pickers.sources.repos").resolve(cfg, name)
  if not path then
    notify.error("Repo not found under REPOS_DIR: " .. name)
    return
  end

  local engine_mod = require("pickers.engines").load()
  if not engine_mod then return end

  local action_mod = require("pickers.actions." .. action)
  action_mod.run({ roots = { path }, prompt = name .. "> " }, engine_mod)
end

---Completion for the repo-name argument of :RepoFiles / :RepoGrep.
---@param arglead string
---@return string[]
local function complete_repo(arglead)
  return require("pickers.sources.repos").complete(arglead)
end

local BASE_SCOPE_DESC = {
  cwd = "vim.uv.cwd()",
  config = "stdpath('config')",
  folder = "interactively picked directory",
  repos = "one repo picked from repos_dir",
  wkdbooks = "one wkdbook picked from repos_dir/WKDBooks",
  system = "systemwide fd search (prompts for query)",
  drives = "all mount points / drive letters",
  dir = "depth / alias / explicit-path navigation",
}

---Print every scope :Pickers can resolve: built-ins (with a one-line
---description) plus every user-defined collection (with its root dir).
local function list_scopes()
  local cfg = require("pickers.config").get()
  local lines = { "Built-in scopes:" }

  local scope_picker = require("pickers.ui.scope_picker")
  for _, name in ipairs(scope_picker.list()) do
    if BASE_SCOPE_DESC[name] then
      lines[#lines + 1] = string.format("  %-10s %s", name, BASE_SCOPE_DESC[name])
    end
  end

  if #cfg.collections > 0 then
    lines[#lines + 1] = "Collections:"
    for _, coll in ipairs(cfg.collections) do
      lines[#lines + 1] = string.format("  %-10s %s", coll.name, coll.dir)
    end
  end

  notify.info(table.concat(lines, "\n"))
end

function M.register()
  usercmd("DirPicker", function(opts)
    local fargs = { "dir" }
    for _, a in ipairs(opts.fargs) do
      fargs[#fargs + 1] = a
    end
    require("pickers.command").handle({ fargs = fargs })
  end, "[pickers compat] :DirPicker [nav] → :Pickers dir [nav]", "*")

  usercmd("FindConfig", function(_)
    require("pickers.command").handle({ fargs = { "config", "files" } })
  end, "[pickers compat] :FindConfig → :Pickers config files", "?")

  usercmd("GrepConfig", function(_)
    require("pickers.command").handle({ fargs = { "config", "grep" } })
  end, "[pickers compat] :GrepConfig → :Pickers config grep", "?")

  usercmd("FindInFolder", function(_)
    require("pickers.command").handle({ fargs = { "folder", "files" } })
  end, "[pickers compat] :FindInFolder → :Pickers folder files", "*")

  usercmd("LiveGrep", function(_)
    require("pickers.command").handle({ fargs = { "cwd", "grep" } })
  end, "[pickers compat] :LiveGrep → :Pickers cwd grep", "?")

  usercmd("AllDrives", function(_)
    require("pickers.command").handle({ fargs = { "drives", "files" } })
  end, "[pickers compat] :AllDrives → :Pickers drives files", "?")

  usercmd("AllDrivesGrep", function(_)
    require("pickers.command").handle({ fargs = { "drives", "grep" } })
  end, "[pickers compat] :AllDrivesGrep → :Pickers drives grep", "?")

  usercmd("FindOnSystem", function(_)
    require("pickers.command").handle({ fargs = { "system", "files" } })
  end, "[pickers compat] :FindOnSystem → :Pickers system files", "?")

  usercmd("RepoFiles", function(opts)
    run_repo_action(opts.fargs[1], "files")
  end, "[pickers] :RepoFiles [repo] — pick repo (or jump to [repo]), then find files", "?", complete_repo)

  usercmd("RepoGrep", function(opts)
    run_repo_action(opts.fargs[1], "grep")
  end, "[pickers] :RepoGrep [repo] — pick repo (or jump to [repo]), then live grep", "?", complete_repo)

  usercmd("WkdBookFiles", function(_)
    require("pickers.command").handle({ fargs = { "wkdbooks", "files" } })
  end, "[pickers] :WkdBookFiles — pick wkdbook, then find files", "?")

  usercmd("WkdBookGrep", function(_)
    require("pickers.command").handle({ fargs = { "wkdbooks", "grep" } })
  end, "[pickers] :WkdBookGrep — pick wkdbook, then live grep", "?")

  usercmd("PickersRepeat", function(_)
    require("pickers.last").run()
  end, "[pickers] :PickersRepeat — reopen the last :Pickers action", "?")

  usercmd("PickersScopes", function(_)
    list_scopes()
  end, "[pickers] :PickersScopes — list every resolvable scope (built-ins + collections)", "?")
end

return M
