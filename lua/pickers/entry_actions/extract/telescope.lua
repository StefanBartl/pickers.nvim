---@module 'pickers.entry_actions.extract.telescope'
---@brief Extract a path from a Telescope entry (from action_state.get_selected_entry()).

---@param entry table|nil
---@return string|nil path
return function(entry)
  if not entry then
    return nil
  end

  local path = entry.path or entry.filename
  if not path and type(entry.value) == "string" then
    path = entry.value
  end

  if not path or path == "" then
    return nil
  end

  return path
end
