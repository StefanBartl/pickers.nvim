---@module 'pickers.bindings.whichkey'
---@brief Best-effort which-key labels for pickers.nvim keymaps.
---@description
--- No hard dependency: if which-key is not installed every function here is a
--- no-op. Keymap descriptions already live on the mappings themselves (which
--- which-key reads automatically), so this module only *ensures* labels via the
--- which-key spec API for users who rely on it — and is safe to call always.

local M = {}

---@return table|nil which-key module if available and new enough (has `add`)
local function get_wk()
  local ok, wk = pcall(require, "which-key")
  if ok and type(wk) == "table" and type(wk.add) == "function" then return wk end
  return nil
end

---Register labels for the built-in keymaps.
---@param km Pickers.Keymaps
function M.register(km)
  local wk = get_wk()
  if not wk then return end

  local spec = {}
  local function add(lhs, desc)
    if lhs then spec[#spec + 1] = { lhs, desc = desc } end
  end

  add(km.dir_pick, "Pickers: dir navigation")
  add(km.explorer, "Pickers: file explorer")
  add(km.folder_files, "Pickers: find in folder")
  add(km.config_files, "Pickers: find in config")
  add(km.config_grep, "Pickers: grep in config")
  add(km.cwd_grep, "Pickers: live grep (cwd)")
  add(km.cwd_files, "Pickers: find files (cwd)")
  add(km.repos_files, "Pickers: pick repo, find files")
  add(km.repos_grep, "Pickers: pick repo, live grep")
  add(km.system_files, "Pickers: systemwide fd search")
  add(km.cwd_smart, "Pickers: smart grep+find (cwd)")
  add(km.config_smart, "Pickers: smart grep+find (config)")
  add(km.folder_smart, "Pickers: smart grep+find (folder)")

  if #spec > 0 then pcall(wk.add, spec) end
end

---Register labels for one collection's optional keymaps.
---@param coll Pickers.Collection
function M.register_collection(coll)
  local wk = get_wk()
  if not wk or type(coll.keys) ~= "table" then return end

  local spec = {}
  if coll.keys.files then
    spec[#spec + 1] = { coll.keys.files, desc = "Pickers[" .. coll.name .. "]: files" }
  end
  if coll.keys.grep then
    spec[#spec + 1] = { coll.keys.grep, desc = "Pickers[" .. coll.name .. "]: grep" }
  end
  if coll.keys.smart then
    spec[#spec + 1] = { coll.keys.smart, desc = "Pickers[" .. coll.name .. "]: smart" }
  end

  if #spec > 0 then pcall(wk.add, spec) end
end

return M
