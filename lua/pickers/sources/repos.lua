---@module 'pickers.sources.repos'
---@brief Source: pick one git repo from REPOS_DIR.
---@description
--- Thin wrapper around pickers.sources.collection.
--- Lists all immediate subdirectories of cfg.repos_dir that contain a .git folder.

local notify = require("lib.nvim.notify").create("[pickers.sources.repos]")

local M = {}

---@param cfg        Pickers.Config
---@param callback   fun(Pickers.Source|nil)
---@param engine_mod table   Engine providing pick_item()
function M.get(cfg, callback, engine_mod)
  if not cfg.repos_dir then
    notify.error("repos_dir not set. Export REPOS_DIR or configure it in setup()")
    callback(nil)
    return
  end

  require("pickers.sources.collection").get({
    name     = "repos",
    dir      = cfg.repos_dir,
    prefix   = "",
    only_git = true,
  }, cfg, callback, engine_mod)
end

return M
