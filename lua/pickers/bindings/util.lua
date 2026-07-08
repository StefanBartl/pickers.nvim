---@module 'pickers.bindings.util'
---@brief Shared helpers for registering keymaps and user-commands.

local M = {}

---Register a single normal-mode keymap, preferring lib.nvim.map if available.
---@param lhs  string|nil
---@param rhs  function
---@param desc string
function M.map(lhs, rhs, desc)
  if not lhs then return end
  local ok, lib_map = pcall(require, "lib.nvim.map")
  if ok and type(lib_map) == "function" then
    lib_map("n", lhs, rhs, { desc = desc })
  else
    vim.keymap.set("n", lhs, rhs, { desc = desc, silent = true })
  end
end

---Create a user command with consistent defaults, preferring lib.nvim.usercmd
---(which wraps the callback in pcall + notify). Falls back to the raw API when
---lib.nvim is unavailable so pickers still works standalone.
---@param name     string
---@param fn       fun(opts: table)
---@param desc     string
---@param nargs    string|nil  default "*"
---@param complete? fun(arglead: string, cmdline: string, cursorpos: integer): string[]
function M.usercmd(name, fn, desc, nargs, complete)
  local opts = { desc = desc, nargs = nargs or "*" }
  if complete then opts.complete = complete end
  local ok, lib_usercmd = pcall(require, "lib.nvim.usercmd")
  if ok and type(lib_usercmd) == "table" and type(lib_usercmd.create) == "function" then
    lib_usercmd.create(name, fn, opts)
  else
    vim.api.nvim_create_user_command(name, fn, opts)
  end
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
