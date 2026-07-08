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
    name = "repos",
    dir = cfg.repos_dir,
    prefix = "",
    only_git = true,
  }, cfg, callback, engine_mod)
end

---List repo names (basenames of git dirs) directly under cfg.repos_dir.
---@param cfg Pickers.Config
---@return string[]
function M.list_names(cfg)
  if not cfg.repos_dir then return {} end
  local paths = require("pickers.sources.collection").list_subdirs(cfg.repos_dir, "", true)
  local names = {}
  for i, path in ipairs(paths) do
    names[i] = vim.fn.fnamemodify(path, ":t")
  end
  table.sort(names)
  return names
end

---Resolve a repo name to its absolute path. Requires an existing directory
---containing a .git entry directly under cfg.repos_dir.
---@param cfg  Pickers.Config
---@param name string
---@return string|nil
function M.resolve(cfg, name)
  if not cfg.repos_dir or not name or name == "" then return nil end
  local path = cfg.repos_dir .. "/" .. name
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= "directory" then return nil end
  if not vim.uv.fs_stat(path .. "/.git") then return nil end
  return vim.fs.normalize(path)
end

---Command-line completion candidates for a repo-name argument.
---@param arglead string
---@return string[]
function M.complete(arglead)
  local cfg = require("pickers.config").get()
  local names = M.list_names(cfg)
  if arglead == "" then return names end
  local lead = arglead:lower()
  local out = {}
  for _, name in ipairs(names) do
    if name:lower():sub(1, #lead) == lead then out[#out + 1] = name end
  end
  return out
end

return M
