---@module 'pickers.bindings.util'
---@brief Shared helpers for registering keymaps and user-commands.
---@description
--- lib.nvim is a hard dependency of this plugin (plugin/pickers.lua bare-
--- requires lib.nvim.bindings.usercmd.composer at load time, so pickers.nvim
--- cannot load at all without it) -- these two wrappers require it the same
--- way every other binding module here does, with no standalone fallback
--- to hold consistent (LUA-01).

local lib_map = require("lib.nvim.bindings.keymap")
local lib_usercmd = require("lib.nvim.bindings.usercmd")

local M = {}

---Register a single normal-mode keymap via lib.nvim.bindings.keymap.
---@param lhs  string|nil
---@param rhs  function
---@param desc string
function M.map(lhs, rhs, desc)
  if not lhs then return end
  lib_map("n", lhs, rhs, { desc = desc })
end

---Create a user command with consistent defaults via lib.nvim.bindings.usercmd
---(which wraps the callback in pcall + notify).
---@param name     string
---@param fn       fun(opts: table)
---@param desc     string
---@param nargs    string|nil  default "*"
---@param complete? fun(arglead: string, cmdline: string, cursorpos: integer): string[]
function M.usercmd(name, fn, desc, nargs, complete)
  local opts = { desc = desc, nargs = nargs or "*" }
  if complete then opts.complete = complete end
  lib_usercmd.create(name, fn, opts)
end

---Convert snake_case name to PascalCase for compat command names.
---  "notes"     → "Notes"
---  "notes_lua" → "NotesLua"
---@param name string
---@return string
function M.to_pascal(name)
  local r = name:gsub("_(%a)", function(l)
    return l:upper()
  end)
  return r:sub(1, 1):upper() .. r:sub(2)
end

return M
