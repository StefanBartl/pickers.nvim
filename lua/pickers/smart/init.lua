---@module 'pickers.smart'
---@brief Public core of the smart action: query → ranked, merged items.
---@description
--- One call, `M.query(query, opts)`, is the single entry point every engine
--- adapter drives. It runs fd + rg for `query` (pickers.smart.search), then
--- merges and ranks both result sets on one scale (pickers.smart.score) so the
--- ranking is identical no matter which engine renders it.

local M = {}

---Default smart config, used when cfg.smart (or a field of it) is absent.
---@return Pickers.SmartConfig
function M.defaults()
  return {
    weights = { filename = 1.0, content = 1.0, both = 25 },
    limit = 2000,
    timeout = 3000,
  }
end

---Resolve the active smart config, merged over defaults.
---@return Pickers.SmartConfig
function M.config()
  local ok, cfg = pcall(function()
    return require("pickers.config").get()
  end)
  local user = (ok and type(cfg) == "table" and cfg.smart) or {}
  return vim.tbl_deep_extend("force", M.defaults(), user)
end

---Run a combined grep + find search for `query` and return the ranked items.
---@param query string
---@param opts  { roots: string[], find: Pickers.FindOpts, additional_args?: string[] }
---@return Pickers.Smart.Item[]
function M.query(query, opts)
  local sm = M.config()
  local files, greps = require("pickers.smart.search").collect({
    roots = opts.roots,
    query = query or "",
    find = opts.find,
    additional_args = opts.additional_args,
    timeout = sm.timeout,
  })
  return require("pickers.smart.score").rank(query or "", files, greps, sm.weights, sm.limit)
end

return M
