---@module 'pickers.engines'
---@brief Engine loader: detects availability and returns the right adapter.
---@description
--- Priority order for "auto": telescope → fzf.
--- The resolved engine module exposes:
---   pick_files(opts)   pick_item(opts)
---   live_grep(opts)    pick_dir(opts)

local notify = require("lib.nvim.notify").create("[pickers.engines]")

local M = {}

---Try to load and verify an engine module.
---@param name string  "telescope"|"fzf"
---@return table|nil
local function try_load(name)
  local ok, mod = pcall(require, "pickers.engines." .. name)
  if not ok or not mod then return nil end
  if type(mod.available) ~= "function" or not mod.available() then return nil end
  return mod
end

---Load the best available engine, respecting the config default.
---@param requested Pickers.Engine|nil  Override; nil → use config default.
---@return table|nil  Engine module, or nil when nothing is available.
function M.load(requested)
  local cfg  = require("pickers.config").get()
  local want = (type(requested) == "string" and requested) or cfg.engine

  if want ~= "auto" then
    local mod = try_load(want)
    if mod then return mod end
    notify.warn("Engine '" .. want .. "' not available — falling back to auto-detect")
  end

  for _, name in ipairs({ "telescope", "fzf" }) do
    local mod = try_load(name)
    if mod then return mod end
  end

  notify.error("No picker engine found. Install telescope.nvim or fzf-lua.")
  return nil
end

return M
