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
---@param override   Pickers.FindOpts|nil  Forced on top of cfg.find/source.find (the "find all"
---                                        escape hatch), like pickers.actions.files.
function M.run(source, engine_mod, override)
  local notify = require("lib.nvim.notify").create("[pickers.actions.filegrep]")
  if type(engine_mod.smart) ~= "function" then
    notify.error("The active engine has no live-picker adapter")
    return
  end
  if source.find_command then
    notify.warn("filegrep ignores the scope's custom find command and lists files with fd")
  end

  -- Same find-flag resolution as pickers.actions.files / .smart.
  local find = require("pickers.config").get().find
  if type(source.find) == "table" then find = vim.tbl_deep_extend("force", find, source.find) end
  if type(override) == "table" then find = vim.tbl_deep_extend("force", find, override) end

  -- Keep the scope label ("CWD> " -> "CWD grep=> ") and the tab-group suffix.
  local label = (source.prompt or ""):gsub("%s*>?%s*$", "")
  local prompt = (label ~= "" and (label .. " ") or "") .. "grep=> "

  engine_mod.smart({
    core = "filegrep",
    roots = source.roots,
    prompt = prompt .. require("pickers.tabs").title_suffix(),
    query = source.query,
    find = find,
    additional_args = source.additional_args,
  })
end

return M
