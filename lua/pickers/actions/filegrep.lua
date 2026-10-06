---@module 'pickers.actions.filegrep'
---@brief Action: open the file picker whose prompt also accepts `grep=<pattern>`.
---@description
--- Fourth action alongside `files`, `grep` and `smart`. It reuses the engines'
--- `smart` live-picker adapters (a live picker fed by a per-keystroke core), only
--- swapping the core for `pickers.filegrep` via `core = "filegrep"`. See
--- pickers.filegrep for the prompt syntax.

local M = {}

---@param source     Pickers.Source
---@param engine_mod table
function M.run(source, engine_mod)
  if type(engine_mod.smart) ~= "function" then
    require("lib.nvim.notify")
      .create("[pickers.actions.filegrep]")
      .error("The active engine has no live-picker adapter")
    return
  end

  -- Same find-flag resolution as pickers.actions.files / .smart.
  local find = require("pickers.config").get().find
  if type(source.find) == "table" then find = vim.tbl_deep_extend("force", find, source.find) end

  engine_mod.smart({
    core = "filegrep",
    roots = source.roots,
    prompt = "Files grep=> ",
    query = source.query,
    find = find,
    additional_args = source.additional_args,
  })
end

return M
