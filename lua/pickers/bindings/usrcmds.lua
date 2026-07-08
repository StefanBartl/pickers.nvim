---@module 'pickers.bindings.usrcmds'
---@brief Built-in compat user-commands (registered when usercmds.enable = true).
---@description
---   :DirPicker [nav]  :FindInFolder  :FindConfig  :GrepConfig
---   :LiveGrep  :AllDrives  :AllDrivesGrep  :FindOnSystem
---   :RepoFiles [repo]  :RepoGrep [repo]  :WkdBookFiles  :WkdBookGrep
---
--- :RepoFiles/:RepoGrep accept an optional repo-name argument (tab-completed
--- from REPOS_DIR) that jumps straight into files/grep for that repo, skipping
--- the interactive repo picker.

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
end

return M
