---@module 'pickers.entry_actions.extract.fzf'
---@brief Extract an absolute file path from an fzf-lua selected entry.

local strip_ansi = require("lib.lua.strings").strip_ansi

---@param selected table|string|nil
---@return string|nil path
return function(selected)
  local path
  -- Only the raw display-line fallback (selected[1]/a bare string) can carry
  -- fzf's own formatting (ANSI colors, a leading icon column) -- .path/
  -- .filename are already-clean fields fzf-lua populates itself. Stripping
  -- unconditionally corrupted any clean path containing a space (e.g.
  -- Windows' "C:\Program Files\..." or "C:\Users\John Doe\..."): the
  -- icon-token regex would eat the first space-separated segment of the
  -- path itself, having no real icon prefix to remove.
  local needs_strip = false

  if type(selected) == "string" then
    path = selected
    needs_strip = true
  elseif type(selected) == "table" then
    if selected.path or selected.filename then
      path = selected.path or selected.filename
    else
      path = selected[1]
      needs_strip = true
    end
  end

  if not path or path == "" then
    return nil
  end

  if needs_strip then
    -- Remove fzf formatting (ANSI colors, leading icon/prefix).
    path = path:gsub("^%s*\27%[[%d;]*m*", "")
    path = path:gsub("^%s*[^ ]*%s+", "")
    path = strip_ansi(path)
    path = path:gsub("^%s+", ""):gsub("%s+$", "")
  end

  return vim.fn.fnamemodify(path, ":p")
end
