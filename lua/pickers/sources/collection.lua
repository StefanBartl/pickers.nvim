---@module 'pickers.sources.collection'
---@brief Generic directory-collection source for :Pickers.
---@description
--- Behaviour depends on the collection spec's `prefix` field:
---   prefix = nil    → use `dir` directly as the picker root (no subdir-picker)
---   prefix = ""     → list ALL immediate subdirectories of `dir` via engine subpicker
---   prefix = "xyz-" → list only subdirs whose name starts with that prefix

local notify = require("lib.nvim.notify").create("[pickers.sources.collection]")

local M = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

---List immediate subdirectories, optionally filtered by prefix and/or .git presence.
---@param dir      string
---@param prefix   string|nil   nil or "" = all dirs, "xyz-" = prefix match
---@param only_git boolean
---@return string[]  absolute paths
local function list_subdirs(dir, prefix, only_git)
  local stat = vim.uv.fs_stat(dir)
  if not stat or stat.type ~= "directory" then return {} end

  local handle = vim.uv.fs_scandir(dir)
  if not handle then return {} end

  local result = {}
  local plen = prefix and #prefix or 0

  while true do
    local name, etype = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if etype == "directory" then
      local full = dir .. "/" .. name
      local ok_prefix = (not prefix or prefix == "") or name:sub(1, plen) == prefix
      local ok_git = (not only_git) or (vim.uv.fs_stat(full .. "/.git") ~= nil)
      if ok_prefix and ok_git then result[#result + 1] = full end
    end
  end

  return result
end

-- ── Public API ────────────────────────────────────────────────────────────────

---List immediate subdirectories, optionally filtered by prefix and/or .git presence.
---Exposed for callers that need the raw path list without going through the
---engine sub-picker (e.g. command-line completion).
---@param dir      string
---@param prefix   string|nil   nil or "" = all dirs, "xyz-" = prefix match
---@param only_git boolean
---@return string[]  absolute paths
function M.list_subdirs(dir, prefix, only_git)
  return list_subdirs(dir, prefix, only_git)
end

---Resolve a collection to a Pickers.Source and call `callback`.
---
--- For prefix=nil collections the callback fires synchronously.
--- For prefix collections the engine subpicker fires asynchronously.
---
---@param coll       Pickers.Collection
---@param _cfg       Pickers.Config   (reserved for future use)
---@param callback   fun(Pickers.Source|nil)
---@param engine_mod table   Engine with pick_item()
function M.get(coll, _cfg, callback, engine_mod)
  local dir = coll.dir
  if not dir or dir == "" then
    notify.error("[" .. (coll.name or "?") .. "] dir not set")
    callback(nil)
    return
  end

  local stat = vim.uv.fs_stat(dir)
  if not stat or stat.type ~= "directory" then
    notify.error("[" .. tostring(coll.name) .. "] directory not found: " .. dir)
    callback(nil)
    return
  end

  -- Direct-root collection (no subdir picker)
  if coll.prefix == nil then
    callback({
      roots = { vim.fs.normalize(dir) },
      prompt = coll.name .. "> ",
    })
    return
  end

  -- Subdir-picker collection
  local prefix = coll.prefix
  local plen = #prefix
  local only_git = coll.only_git == true
  local subdirs = list_subdirs(dir, prefix, only_git)

  if #subdirs == 0 then
    local info = (prefix == "") and "no subdirs found"
      or ("no subdirs with prefix '" .. prefix .. "' found")
    notify.warn("[" .. coll.name .. "] " .. info .. " in: " .. dir)
    callback(nil)
    return
  end

  -- Build display labels (strip prefix from basename)
  local labels = {}
  for i, path in ipairs(subdirs) do
    local basename = vim.fn.fnamemodify(path, ":t")
    labels[i] = (plen > 0) and basename:sub(plen + 1) or basename
  end

  engine_mod.pick_item({
    prompt = coll.name .. "> ",
    items = labels,
    on_select = function(label)
      for i, l in ipairs(labels) do
        if l == label then
          callback({
            roots = { vim.fs.normalize(subdirs[i]) },
            prompt = label .. "> ",
          })
          return
        end
      end
      callback(nil)
    end,
  })
end

return M
