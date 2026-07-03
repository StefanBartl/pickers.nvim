---@module 'pickers.bindings.usrcmds'
---@brief Built-in compat user-commands (registered when usercmds.enable = true).
---@description
---   :DirPicker [nav]  :FindInFolder  :FindConfig  :GrepConfig
---   :LiveGrep  :AllDrives  :AllDrivesGrep  :FindOnSystem
---   :RepoFiles  :RepoGrep  :WkdBookFiles  :WkdBookGrep

local usercmd = require("pickers.bindings.util").usercmd

local M = {}

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

  usercmd("RepoFiles", function(_)
    require("pickers.command").handle({ fargs = { "repos", "files" } })
  end, "[pickers] :RepoFiles — pick repo, then find files", "?")

  usercmd("RepoGrep", function(_)
    require("pickers.command").handle({ fargs = { "repos", "grep" } })
  end, "[pickers] :RepoGrep — pick repo, then live grep", "?")

  usercmd("WkdBookFiles", function(_)
    require("pickers.command").handle({ fargs = { "wkdbooks", "files" } })
  end, "[pickers] :WkdBookFiles — pick wkdbook, then find files", "?")

  usercmd("WkdBookGrep", function(_)
    require("pickers.command").handle({ fargs = { "wkdbooks", "grep" } })
  end, "[pickers] :WkdBookGrep — pick wkdbook, then live grep", "?")
end

return M
