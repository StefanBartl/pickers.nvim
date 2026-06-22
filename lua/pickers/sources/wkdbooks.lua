---@module 'pickers.sources.wkdbooks'
---@brief Source: pick one wkdbook from wkdbooks_dir, then use it as root (async).

local notify = require("lib.nvim.notify").create("[pickers.sources.wkdbooks]")

local M = {}

-- ── Helpers ──────────────────────────────────────────────────────────────────

---List immediate subdirectories whose name starts with prefix.
---@param dir    string
---@param prefix string
---@return string[]
local function list_wkdbooks(dir, prefix)
  local stat = vim.uv.fs_stat(dir)
  if not stat or stat.type ~= "directory" then return {} end

  local handle = vim.uv.fs_scandir(dir)
  if not handle then return {} end

  local result = {}
  local i      = 0
  local plen   = #prefix

  while true do
    local name, etype = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if etype == "directory" and name:sub(1, plen) == prefix then
      i          = i + 1
      result[i]  = dir .. "/" .. name
    end
  end

  return result
end

-- ── Public API ────────────────────────────────────────────────────────────────

---@param cfg        Pickers.Config
---@param callback   fun(Pickers.Source|nil)
---@param engine_mod table   Engine providing pick_item()
function M.get(cfg, callback, engine_mod)
  local wkdbooks_dir = cfg.wkdbooks_dir
    or (cfg.repos_dir and cfg.repos_dir .. "/WKDBooks")

  if not wkdbooks_dir then
    notify.error("wkdbooks_dir not set. Configure repos_dir or wkdbooks_dir in setup()")
    callback(nil)
    return
  end

  local prefix = cfg.wkdbook_prefix or "wkdbook-"
  local books  = list_wkdbooks(wkdbooks_dir, prefix)

  if #books == 0 then
    notify.warn("No wkdbooks found in: " .. wkdbooks_dir .. "  (prefix: " .. prefix .. ")")
    callback(nil)
    return
  end

  -- Strip the prefix from display labels so the picker is less noisy
  local plen   = #prefix
  local labels = { [#books] = "" }
  for i = 1, #books do
    local name = vim.fn.fnamemodify(books[i], ":t")
    labels[i]  = name:sub(plen + 1)
  end

  engine_mod.pick_item({
    prompt = "WkdBooks> ",
    items  = labels,
    on_select = function(label)
      for i = 1, #labels do
        if labels[i] == label then
          local path = vim.fs.normalize(books[i])
          callback({ roots = { path }, prompt = label .. "> " })
          return
        end
      end
      callback(nil)
    end,
  })
end

return M
