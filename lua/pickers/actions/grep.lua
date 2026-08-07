---@module 'pickers.actions.grep'
---@brief Action: open a live-grep picker for a resolved source.
---@description
--- `find.exclude` (global `cfg.find.exclude`, overridden per-collection by
--- `source.find.exclude`) is forwarded as `opts.find` alongside the rest of
--- the live-grep opts, same merge pattern as `pickers.actions.files`. Each
--- engine's `live_grep` turns `find.exclude` into its own correctly-escaped
--- `-g '!glob'` rg flags — hidden/no_ignore/follow don't apply here since
--- live grep already hardcodes `--hidden --no-ignore-vcs -S` unconditionally.

local M = {}

---@param source          Pickers.Source
---@param engine_mod      table
---@param extra_args      string[]|nil   Additional rg flags (merged with source.additional_args)
function M.run(source, engine_mod, extra_args)
  local args = vim.list_extend({}, source.additional_args or {})
  if extra_args then vim.list_extend(args, extra_args) end

  local find = require("pickers.config").get().find
  if type(source.find) == "table" then find = vim.tbl_deep_extend("force", find, source.find) end

  engine_mod.live_grep({
    roots = source.roots,
    prompt = source.prompt,
    additional_args = args,
    find = find,
  })
end

return M
