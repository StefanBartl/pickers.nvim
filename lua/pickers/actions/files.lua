---@module 'pickers.actions.files'
---@brief Action: open a file picker for a resolved source.

local M = {}

---@param source     Pickers.Source
---@param engine_mod table
function M.run(source, engine_mod)
  local find = require("pickers.config").get().find
  if type(source.find) == "table" then
    find = vim.tbl_deep_extend("force", find, source.find)
  end

  engine_mod.pick_files({
    roots = source.roots,
    prompt = source.prompt,
    find_command = source.find_command,
    find = find,
  })
end

return M
