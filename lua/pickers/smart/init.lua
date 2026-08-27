---@module 'pickers.smart'
---@brief Public core of the smart action: query → ranked, merged items.
---@description
--- One call, `M.query(query, opts)`, is the single entry point every engine
--- adapter drives. It runs fd + rg for `query` (pickers.smart.search), then
--- merges and ranks both result sets on one scale (pickers.smart.score) so the
--- ranking is identical no matter which engine renders it.

local M = {}

---Default smart config, used when cfg.smart (or a field of it) is absent.
---
---Read out of `config.DEFAULTS` rather than restated here. It used to be a
---second copy of the same six values, which is one edit away from the two
---disagreeing with nobody noticing -- and the copy was the one that lost,
---since `M.config()` merges the *config* over it.
---
---`DEFAULTS` is plain data with no side effects, so requiring it is safe even
---on the path this function exists for: the one where `config.get()` itself
---is unavailable.
---@return Pickers.SmartConfig
function M.defaults()
  local ok, defaults = pcall(require, "pickers.config.DEFAULTS")
  local smart = ok and type(defaults) == "table" and defaults.smart or nil
  if type(smart) == "table" then return vim.deepcopy(smart) end
  -- Last resort: DEFAULTS itself could not be loaded. Keeping the search
  -- runnable beats returning nothing, and these are the two values it cannot
  -- work without.
  return { limit = 2000, timeout = 3000 }
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

  local frecency
  if sm.frecency and sm.frecency.enabled then
    local abspaths = {}
    for _, f in ipairs(files) do
      abspaths[#abspaths + 1] = f.abspath
    end
    for _, g in ipairs(greps) do
      abspaths[#abspaths + 1] = g.abspath
    end
    local cfg = require("pickers.config").get()
    frecency = require("pickers.smart.frecency").lookup(cfg, abspaths)
  end

  return require("pickers.smart.score").rank(
    query or "",
    files,
    greps,
    sm.weights,
    sm.limit,
    frecency,
    sm.dedup_grep_rows
  )
end

return M
