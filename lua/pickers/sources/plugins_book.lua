---@module 'pickers.sources.plugins_book'
---@brief Source: pick one plugin repo from the "plugins_book" collection dir.
---@description
--- Thin wrapper around pickers.sources.collection, analogous to
--- pickers.sources.repos but scoped to the "plugins_book" collection's `dir`/
--- `exclude` (looked up from cfg.collections by name) instead of the whole
--- repos_dir.
---
--- Unlike pickers.sources.repos, this does NOT filter by .git presence: the
--- entries under wkdbook-myplugins are documentation folders mirroring each
--- plugin's name (e.g. "cascade.nvim/ROADMAP/"), not the actual git clones --
--- those live directly under REPOS_DIR. Non-plugin bookkeeping folders (ALL,
--- TEMPLATES, TOOLS, _Telemetry) are hidden via the collection's `exclude`
--- list instead.

local M = {}

---Find the "plugins_book" collection entry.
---@internal
---@param cfg Pickers.Config
---@return Pickers.Collection|nil
local function find_collection(cfg)
  for _, coll in ipairs(cfg.collections or {}) do
    if coll.name == "plugins_book" then return coll end
  end
  return nil
end

---List plugin names (basenames of subdirs, minus `exclude`) under the
---collection's dir.
---@param cfg Pickers.Config
---@return string[]
function M.list_names(cfg)
  local coll = find_collection(cfg)
  if not coll then return {} end
  local paths =
    require("pickers.sources.collection").list_subdirs(coll.dir, "", false, coll.exclude)
  local names = {}
  for i, path in ipairs(paths) do
    names[i] = vim.fn.fnamemodify(path, ":t")
  end
  table.sort(names)
  return names
end

---Resolve a plugin name to its absolute path. Requires an existing,
---non-excluded directory directly under the collection's dir.
---@param cfg  Pickers.Config
---@param name string
---@return string|nil
function M.resolve(cfg, name)
  local coll = find_collection(cfg)
  if not coll or not name or name == "" then return nil end
  for _, excluded in ipairs(coll.exclude or {}) do
    if excluded == name then return nil end
  end
  local path = coll.dir .. "/" .. name
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= "directory" then return nil end
  return vim.fs.normalize(path)
end

---Command-line completion candidates for a plugin-name argument.
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
