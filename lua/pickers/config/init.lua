---@module 'pickers.config'
---@brief Manages the active configuration; merges user options into defaults.
---@see pickers.config.DEFAULTS

local expand_path = require("lib.nvim.cross.fs.expand_path")
local notify = require("lib.nvim.notify").create("[pickers]")

local M = {}

local _cfg = nil ---@type Pickers.Config|nil

---Return the active configuration, initialising from defaults on first call.
---@return Pickers.Config
function M.get()
  if _cfg then return _cfg end
  _cfg = vim.deepcopy(require("pickers.config.DEFAULTS"))
  return _cfg
end

---Validate and normalise a single collection entry.
---Returns nil if the entry is invalid.
---@internal
---@param raw table
---@return Pickers.Collection|nil
local function normalise_collection(raw)
  if type(raw) ~= "table" then return nil end
  if type(raw.name) ~= "string" or raw.name == "" then return nil end
  if type(raw.dir) ~= "string" or raw.dir == "" then return nil end
  return {
    name = raw.name,
    dir = expand_path(raw.dir),
    prefix = (type(raw.prefix) == "string") and raw.prefix or nil,
    keys = (type(raw.keys) == "table") and raw.keys or nil,
    only_git = raw.only_git == true,
    -- Partial override, merged over cfg.find at use-time (pickers.actions.files)
    -- -- not validated field-by-field here, same leniency as cfg.find itself.
    find = (type(raw.find) == "table") and raw.find or nil,
  }
end

---Validate and normalise the `history` sub-config, merging into `current`.
---@internal
---@param raw table
---@param current Pickers.HistoryConfig
---@return Pickers.HistoryConfig
local function normalise_history(raw, current)
  local result = vim.deepcopy(current)

  if type(raw.enabled) == "boolean" then result.enabled = raw.enabled end

  if raw.fzf_scope ~= nil then
    local allowed = { plugin = true, global = true, patch = true }
    if type(raw.fzf_scope) == "string" and allowed[raw.fzf_scope] then
      result.fzf_scope = raw.fzf_scope
    else
      notify.warn(
        string.format(
          "Invalid history.fzf_scope %q, keeping %q",
          tostring(raw.fzf_scope),
          result.fzf_scope
        )
      )
    end
  end

  if type(raw.dir) == "string" and raw.dir ~= "" then result.dir = expand_path(raw.dir) end

  if raw.limit ~= nil then
    if type(raw.limit) == "number" and raw.limit > 0 then
      result.limit = raw.limit
    else
      notify.warn(
        string.format("Invalid history.limit %s, keeping %s", vim.inspect(raw.limit), result.limit)
      )
    end
  end

  return result
end

---Validate and normalise the `keys` sub-config, merging into `current`.
---Each action accepts a single lhs string, a list of lhs strings, or `false`
---to unbind it. Invalid values are rejected with a warning and left unchanged.
---@internal
---@param raw table
---@param current Pickers.KeysConfig
---@return Pickers.KeysConfig
local function normalise_keys(raw, current)
  local result = vim.deepcopy(current)

  if type(raw.enable) == "boolean" then result.enable = raw.enable end
  if type(raw.open_background_show) == "boolean" then
    result.open_background_show = raw.open_background_show
  end

  local actions = require("pickers.keys").ACTIONS
  for name in pairs(actions) do
    local v = raw[name]
    if v ~= nil then
      if v == false or type(v) == "string" or type(v) == "table" then
        result[name] = v
      else
        notify.warn(string.format("Invalid keys.%s %s, keeping previous", name, vim.inspect(v)))
      end
    end
  end

  return result
end

---Merge user-provided options into the active configuration.
---@param opts Pickers.Config|nil
function M.apply(opts)
  local cfg = M.get()
  if type(opts) ~= "table" then return end

  if type(opts.engine) == "string" then cfg.engine = opts.engine end
  if type(opts.repos_dir) == "string" then cfg.repos_dir = expand_path(opts.repos_dir) end
  if type(opts.deps_popup) == "boolean" then cfg.deps_popup = opts.deps_popup end

  if type(opts.collections) == "table" then
    cfg.collections = {}
    for _, raw in ipairs(opts.collections) do
      local coll = normalise_collection(raw)
      if coll then
        cfg.collections[#cfg.collections + 1] = coll
      else
        notify.warn(
          string.format("Invalid collection entry (name+dir required): %s", vim.inspect(raw))
        )
      end
    end
  end

  if type(opts.depth_aliases) == "table" then
    for k, v in pairs(opts.depth_aliases) do
      if type(k) == "string" and type(v) == "function" then cfg.depth_aliases[k] = v end
    end
  end

  if type(opts.find) == "table" then
    cfg.find = vim.tbl_deep_extend("force", cfg.find, opts.find)
  end

  if type(opts.keymaps) == "table" then
    cfg.keymaps = vim.tbl_deep_extend("force", cfg.keymaps, opts.keymaps)
  end
  -- Plain replace, not merged -- each entry is independent and there is no
  -- meaningful "default" to merge a user's mappings table against (unlike
  -- keymaps/find/smart, DEFAULTS.mappings is always empty).
  if type(opts.mappings) == "table" then cfg.mappings = opts.mappings end
  if type(opts.usercmds) == "table" then
    cfg.usercmds = vim.tbl_deep_extend("force", cfg.usercmds, opts.usercmds)
  end

  if type(opts.keys) == "table" then cfg.keys = normalise_keys(opts.keys, cfg.keys) end

  if type(opts.history) == "table" then
    cfg.history = normalise_history(opts.history, cfg.history)
  end

  -- Both keys were removed and are read here for one purpose: to say so. They
  -- are deliberately absent from `Pickers.Opts` -- naming them there would
  -- claim they are supported.
  ---@diagnostic disable-next-line: undefined-field
  if type(opts.selected_index) == "table" or type(opts.experimental) == "table" then
    notify.warn(
      "selected_index has been removed (it never worked reliably) -- "
        .. "this opts.selected_index/opts.experimental was ignored."
    )
  end

  if type(opts.result_count) == "table" then
    if type(opts.result_count.enabled) == "boolean" then
      cfg.result_count.enabled = opts.result_count.enabled
    end
    if type(opts.result_count.interval_ms) == "number" and opts.result_count.interval_ms > 0 then
      cfg.result_count.interval_ms = math.floor(opts.result_count.interval_ms)
    end
  end

  -- Deep-merge smart over defaults (weights/limit/timeout); same leniency as
  -- cfg.find -- not validated field-by-field.
  if type(opts.smart) == "table" then
    cfg.smart = vim.tbl_deep_extend("force", cfg.smart, opts.smart)
  end

  if type(opts.display) == "table" then
    if type(opts.display.path_shorten) == "boolean" then
      cfg.display.path_shorten = opts.display.path_shorten
    end
  end
end

return M
