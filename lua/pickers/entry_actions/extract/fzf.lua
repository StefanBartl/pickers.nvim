---@module 'pickers.entry_actions.extract.fzf'
---@brief Extract an absolute file path from an fzf-lua selected entry.

local strip_ansi = require("lib.lua.strings").strip_ansi

---@param selected table|string|nil
---@return string|nil path
return function(selected)
  local path

  if type(selected) == "string" then
    path = selected
  elseif type(selected) == "table" then
    path = selected.path or selected.filename or selected[1]
  end

  if not path or path == "" then
    return nil
  end

  -- Remove fzf formatting (ANSI colors, leading icon/prefix).
  path = path:gsub("^%s*\27%[[%d;]*m*", "")
  path = path:gsub("^%s*[^ ]*%s+", "")
  path = strip_ansi(path)
  path = path:gsub("^%s+", ""):gsub("%s+$", "")

  return vim.fn.fnamemodify(path, ":p")
end
