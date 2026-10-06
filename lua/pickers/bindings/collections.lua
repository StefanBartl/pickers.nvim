---@module 'pickers.bindings.collections'
---@brief Per-collection compat-commands and optional keymaps.
---@description
---   :{PascalName}Files  →  :Pickers {name} files
---   :{PascalName}Grep   →  :Pickers {name} grep
---   :{PascalName}Smart  →  :Pickers {name} smart
---   :{PascalName}FileGrep [query]  →  :Pickers {name} filegrep
--- Plus optional keymaps from coll.keys.files / .grep / .smart / .filegrep.

local util = require("pickers.bindings.util")

local M = {}

---Register compat commands and optional keymaps for one collection.
---@param coll Pickers.Collection
function M.register(coll)
  local pascal = util.to_pascal(coll.name)
  local files_cmd = pascal .. "Files"
  local grep_cmd = pascal .. "Grep"
  local smart_cmd = pascal .. "Smart"
  local name = coll.name

  -- Skip if the compat command already exists (e.g. a hardcoded usrcmds alias)
  if vim.fn.exists(":" .. files_cmd) ~= 2 then
    util.usercmd(files_cmd, function(_)
      require("pickers.command").handle({ fargs = { name, "files" } })
    end, "[pickers coll] :" .. files_cmd .. " → :Pickers " .. name .. " files", "?")
  end

  if vim.fn.exists(":" .. grep_cmd) ~= 2 then
    util.usercmd(grep_cmd, function(_)
      require("pickers.command").handle({ fargs = { name, "grep" } })
    end, "[pickers coll] :" .. grep_cmd .. " → :Pickers " .. name .. " grep", "?")
  end

  if vim.fn.exists(":" .. smart_cmd) ~= 2 then
    util.usercmd(smart_cmd, function(_)
      require("pickers.command").handle({ fargs = { name, "smart" } })
    end, "[pickers coll] :" .. smart_cmd .. " → :Pickers " .. name .. " smart", "?")
  end

  local filegrep_cmd = pascal .. "FileGrep"
  if vim.fn.exists(":" .. filegrep_cmd) ~= 2 then
    util.usercmd(filegrep_cmd, function(opts)
      require("pickers.command").handle({
        fargs = { name, "filegrep" },
        query = vim.trim(opts.args or ""),
      })
    end, "[pickers coll] :" .. filegrep_cmd .. " [query] → :Pickers " .. name .. " filegrep", "*")
  end

  -- Optional keymaps from coll.keys
  if type(coll.keys) == "table" then
    if coll.keys.files then
      util.map(coll.keys.files, function()
        require("pickers.command").handle({ fargs = { name, "files" } })
      end, "[pickers] " .. name .. ": find files")
    end
    if coll.keys.grep then
      util.map(coll.keys.grep, function()
        require("pickers.command").handle({ fargs = { name, "grep" } })
      end, "[pickers] " .. name .. ": live grep")
    end
    if coll.keys.smart then
      util.map(coll.keys.smart, function()
        require("pickers.command").handle({ fargs = { name, "smart" } })
      end, "[pickers] " .. name .. ": smart (grep + find)")
    end
    if coll.keys.filegrep then
      util.map(coll.keys.filegrep, function()
        require("pickers.command").handle({ fargs = { name, "filegrep" } })
      end, "[pickers] " .. name .. ": files + grep= content filter")
    end
    -- No which-key registration here: these mappings carry their own `desc`,
    -- which which-key reads by itself. The call that used to sit here
    -- registered a *second*, differently worded label for the same keys
    -- ("Pickers[notes]: files" against this "[pickers] notes: find files"),
    -- so which-key showed whichever arrived last.
  end
end

return M
