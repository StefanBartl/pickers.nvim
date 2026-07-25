---@module 'pickers.actions.files'
---@brief Action: open a file picker for a resolved source.

local M = {}

---@param source     Pickers.Source
---@param engine_mod table
---@param override   Pickers.FindOpts|nil  Forced on top of cfg.find/source.find (e.g. the
---                                        "find all" escape hatch). Ignored when
---                                        source.find_command is set (system source
---                                        carries its own flags already).
function M.run(source, engine_mod, override)
  local find = require("pickers.config").get().find
  if type(source.find) == "table" then
    find = vim.tbl_deep_extend("force", find, source.find)
  end
  if type(override) == "table" then
    find = vim.tbl_deep_extend("force", find, override)
  end

  engine_mod.pick_files({
    roots = source.roots,
    prompt = source.prompt,
    find_command = source.find_command,
    find = find,
  })
end

return M
