---@module 'pickers.entry_actions.extract.snacks'
---@brief Extract a path from a snacks.nvim picker Item.
---@description
--- Prefers snacks' own canonical, cached path helper
--- (Snacks.picker.util.path) when `item.file` is set — the documented,
--- forward-compatible way to resolve a file-bearing Item. Falls back to a
--- manual field chain for shapes that helper doesn't cover, notably generic
--- `Snacks.picker.select()` items (`{ item = <original>, text = ... }`).

---@param item table|nil
---@return string|nil path
return function(item)
  if not item then return nil end

  if item.file then
    local ok, util = pcall(require, "snacks.picker.util")
    if ok then
      local path = util.path(item)
      if path then return path end
    end
  end

  ---@diagnostic disable-next-line: undefined-field
  local path = item.file or item.path or item.filename
  ---@diagnostic disable-next-line: undefined-field
  if not path and type(item.item) == "table" then
    -- `.file` first, same precedence as the top-level chain two lines up:
    -- it is the one field `Pickers.Item` documents as guaranteed-absolute
    -- (see pickers.engines.@types), while `.path` is informal and may be
    -- relative (e.g. pickers.git_status_marks' repo-root-relative `.path`
    -- alongside its absolute `.file`) -- preferring it here would silently
    -- hand back a path relative to the wrong base once resolved.
    ---@diagnostic disable-next-line: undefined-field
    path = item.item.file or item.item.path or item.item.filename
  end
  ---@diagnostic disable-next-line: undefined-field
  if not path and type(item.text) == "string" then
    ---@diagnostic disable-next-line: undefined-field
    path = item.text
  end

  return path
end
