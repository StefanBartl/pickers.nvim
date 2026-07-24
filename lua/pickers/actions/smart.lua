---@module 'pickers.actions.smart'
---@brief Action: open a combined grep + find-files picker for a resolved source.
---@description
--- The third action alongside `files` and `grep`. It reuses the same resolved
--- source (roots/prompt/find override/additional_args) and hands the engine a
--- single live picker whose results interleave filename hits and content hits by
--- relevance — see pickers.smart for the shared, engine-agnostic core.

local M = {}

---@param source     Pickers.Source
---@param engine_mod table
function M.run(source, engine_mod)
  if type(engine_mod.smart) ~= "function" then
    require("lib.nvim.notify")
      .create("[pickers.actions.smart]")
      .error("The active engine has no smart adapter")
    return
  end

  -- Same find-flag resolution as pickers.actions.files: the files half of the
  -- smart search honours cfg.find plus any per-collection override.
  local find = require("pickers.config").get().find
  if type(source.find) == "table" then find = vim.tbl_deep_extend("force", find, source.find) end

  engine_mod.smart({
    roots = source.roots,
    prompt = source.prompt,
    find = find,
    additional_args = source.additional_args,
  })
end

return M
