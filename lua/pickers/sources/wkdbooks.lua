---@module 'pickers.sources.wkdbooks'
---@brief Source: pick one wkdbook from the wkdbooks collection.
---@description
--- Thin wrapper around pickers.sources.collection.
--- Resolves the wkdbooks directory from cfg.collections (name "wkdbooks"),
--- falling back to cfg.repos_dir .. "/WKDBooks" for backward compatibility.

local notify = require("lib.nvim.notify").create("[pickers.sources.wkdbooks]")

local M = {}

---@param cfg        Pickers.Config
---@param callback   fun(Pickers.Source|nil)
---@param engine_mod table   Engine providing pick_item()
function M.get(cfg, callback, engine_mod)
  -- Prefer the "wkdbooks" entry from cfg.collections
  for _, c in ipairs(cfg.collections or {}) do
    if c.name == "wkdbooks" then
      require("pickers.sources.collection").get(c, cfg, callback, engine_mod)
      return
    end
  end

  -- Fallback for configs that haven't migrated to collections yet
  local dir = cfg.repos_dir and (cfg.repos_dir .. "/WKDBooks")
  if not dir then
    notify.error(
      "wkdbooks not configured. Add { name='wkdbooks', dir=..., prefix='wkdbook-' } "
      .. "to collections in setup(), or set repos_dir."
    )
    callback(nil)
    return
  end

  require("pickers.sources.collection").get({
    name   = "wkdbooks",
    dir    = dir,
    prefix = "wkdbook-",
  }, cfg, callback, engine_mod)
end

return M
