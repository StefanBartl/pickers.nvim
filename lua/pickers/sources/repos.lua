---@module 'pickers.sources.repos'
---@brief Source: pick one git repo from REPOS_DIR, then use it as root (async).

local notify = require("lib.nvim.notify").create("[pickers.sources.repos]")

local M = {}

-- ── Helpers ──────────────────────────────────────────────────────────────────

---List immediate subdirectories of dir, optionally filtered to git repos.
---Uses synchronous libuv fs_scandir for session-safe reads.
---@param dir    string
---@param only_git boolean
---@return string[]  Absolute paths, pre-reserved array
local function list_dirs(dir, only_git)
  local stat = vim.uv.fs_stat(dir)
  if not stat or stat.type ~= "directory" then return {} end

  local handle = vim.uv.fs_scandir(dir)
  if not handle then return {} end

  local result = {}
  local i      = 0

  while true do
    local name, etype = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if etype == "directory" then
      local full = dir .. "/" .. name
      if not only_git or vim.uv.fs_stat(full .. "/.git") then
        i          = i + 1
        result[i]  = full
      end
    end
  end

  return result
end

-- ── Public API ────────────────────────────────────────────────────────────────

---@param cfg        Pickers.Config
---@param callback   fun(Pickers.Source|nil)
---@param engine_mod table   Engine providing pick_item()
function M.get(cfg, callback, engine_mod)
  local repos_dir = cfg.repos_dir
  if not repos_dir then
    notify.error("repos_dir not set. Export REPOS_DIR or configure it in setup()")
    callback(nil)
    return
  end

  local repos = list_dirs(repos_dir, true)
  if #repos == 0 then
    notify.warn("No git repos found in: " .. repos_dir)
    callback(nil)
    return
  end

  -- Build display labels (basename only) — pre-reserve array
  local labels = { [#repos] = "" }
  for i = 1, #repos do
    labels[i] = vim.fn.fnamemodify(repos[i], ":t")
  end

  engine_mod.pick_item({
    prompt = "Repos> ",
    items  = labels,
    on_select = function(label)
      for i = 1, #labels do
        if labels[i] == label then
          local path = vim.fs.normalize(repos[i])
          callback({ roots = { path }, prompt = label .. "> " })
          return
        end
      end
      callback(nil)
    end,
  })
end

return M
