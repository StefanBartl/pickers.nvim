---@module 'pickers.actions.grep'
---@brief Action: open a live-grep picker for a resolved source.

local M = {}

---@param source          Pickers.Source
---@param engine_mod      table
---@param extra_args      string[]|nil   Additional rg flags (merged with source.additional_args)
function M.run(source, engine_mod, extra_args)
  local args = vim.list_extend({}, source.additional_args or {})
  if extra_args then
    vim.list_extend(args, extra_args)
  end

  engine_mod.live_grep({
    roots           = source.roots,
    prompt          = source.prompt,
    additional_args = args,
  })
end

return M
