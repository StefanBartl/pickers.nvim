---@module 'pickers.actions.files'
---@brief Action: open a file picker for a resolved source.

local M = {}

---@param source     Pickers.Source
---@param engine_mod table
function M.run(source, engine_mod)
  engine_mod.pick_files({
    roots        = source.roots,
    prompt       = source.prompt,
    find_command = source.find_command,
  })
end

return M
