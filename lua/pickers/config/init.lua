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
  -- Via lib.nvim's env snapshot, not a direct vim.env.REPOS_DIR read: it's the
  -- one sanctioned place this env var is read, and `repo_base` is `nil` when
  -- unset -- same behavior as before, single source of truth now. Resolved
  -- here rather than in DEFAULTS.lua so requiring that module alone stays
  -- pure data (LUA-06).
  _cfg.repos_dir = require("lib.nvim.system.env").get().repo_base
  return _cfg
end

---Discard the active configuration, so the next `M.get()`/`M.apply()` call
---starts from a fresh `DEFAULTS` copy again. `pickers.setup()` calls this
---before `M.apply(opts)`, so a second real `setup()` call in the same Lua
---state replaces the first cleanly instead of composing on top of whatever
---it left behind (LUA-87). `M.apply()` on its own keeps mutating the live
---table in place -- that is what lets it be called repeatedly to build up
---one configuration (e.g. incrementally, or across several lazy.nvim specs
---for this plugin), which is a different, still-supported use.
function M.reset()
  _cfg = nil
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
  -- `raw.name` also becomes a compat command (":{Pascal}Files"/"Grep"/"Smart",
  -- see bindings.collections), and nvim_create_user_command rejects anything
  -- outside `^%u%w*$` with no pcall on that call site -- reject it here
  -- instead, so one bad collection name degrades to "this collection is
  -- skipped" rather than aborting registration for every collection after it
  -- (ERR-22).
  if not require("pickers.bindings.util").to_pascal(raw.name):match("^%u%w*$") then return nil end
  return {
    name = raw.name,
    dir = expand_path(raw.dir),
    prefix = (type(raw.prefix) == "string") and raw.prefix or nil,
    keys = (type(raw.keys) == "table") and raw.keys or nil,
    only_git = raw.only_git == true,
    exclude = (type(raw.exclude) == "table") and raw.exclude or nil,
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

-- ── ERR-50: unknown-key validation, before the merge below ──────────────────
-- DEFAULTS.lua cannot double as this list of known keys: several of its own
-- fields default to `nil` (repos_dir, find.exclude, history.dir, ...), and a
-- Lua table never stores a nil-valued key -- `pairs(DEFAULTS)` silently omits
-- exactly the fields most likely to be set by a caller. Explicit key sets
-- side-step that trap entirely.

local TOP_LEVEL_OPTS = {
  "engine",
  "repos_dir",
  "deps_popup",
  "collections",
  "depth_aliases",
  "keymaps",
  "mappings",
  "find",
  "usercmds",
  "keys",
  "history",
  "result_count",
  "smart",
  "display",
  "images",
  "tabs",
  "quickfix",
  -- Removed keys: kept "known" here so opts.selected_index/experimental reach
  -- their own dedicated warning further below instead of this generic one.
  "selected_index",
  "experimental",
}

-- Sub-tables merged wholesale via `vim.tbl_deep_extend` below (find, keymaps,
-- usercmds, smart(+weights/frecency), quickfix(+preview/keys), tabs) would
-- otherwise absorb a typo'd key silently -- no per-field validation catches
-- it the way normalise_history/normalise_keys/the inline display/images
-- checks already do for their own tables.
---@type table<string, string[]>
local NESTED_OPTS = {
  find = { "hidden", "no_ignore", "follow", "exclude" },
  keymaps = {
    "enable",
    "cwd_files",
    "cwd_grep",
    "config_files",
    "config_grep",
    "folder_files",
    "dir_pick",
    "explorer",
    "repos_files",
    "repos_grep",
    "system_files",
    "cwd_smart",
    "config_smart",
    "folder_smart",
    "cwd_find_all",
  },
  usercmds = { "enable" },
  keys = {
    "enable",
    "preview_scroll_down",
    "preview_scroll_up",
    "preview_scroll_left",
    "preview_scroll_right",
    "history_back",
    "history_forward",
    "create_file",
    "open_background",
    "open_background_show",
    "preview_toggle",
    "split",
    "vsplit",
    "tab",
    "mouse_confirm",
    "cheatsheet",
    -- Opt-in tab-group switch actions (pickers.keys.ACTIONS.tab_next/tab_prev);
    -- absent from DEFAULTS.keys because their default is `false`, not nil.
    "tab_next",
    "tab_prev",
  },
  history = { "enabled", "fzf_scope", "dir", "limit" },
  result_count = { "enabled", "interval_ms" },
  smart = { "weights", "limit", "timeout", "frecency", "dedup_grep_rows" },
  ["smart.weights"] = { "filename", "content", "both" },
  ["smart.frecency"] = { "enabled", "weight", "dir" },
  display = { "path_shorten" },
  images = { "enabled" },
  tabs = { "groups" }, -- "groups"' own keys are user-named group names, not validated
  quickfix = { "enabled", "preview", "keys" },
  ["quickfix.preview"] = { "enabled", "height", "context", "border", "delay_ms" },
  ["quickfix.keys"] = { "filter", "restore", "toggle_preview" },
}

---@internal
---Nearest allowed key within edit distance 3, as a " (did you mean %q?)" hint.
---@param name string
---@param allowed string[]
---@return string
local function did_you_mean(name, allowed)
  local levenshtein = require("lib.lua.strings.distance").levenshtein
  local best, best_distance = nil, nil
  for _, known in ipairs(allowed) do
    local d = levenshtein(name, known)
    if d <= 3 and (best_distance == nil or d < best_distance) then
      best, best_distance = known, d
    end
  end
  return best and (" (did you mean %q?)"):format(best) or ""
end

---@internal
---Drop (and warn about) every key not in `allowed`, recursing into the
---sub-tables named in NESTED_OPTS so a typo cannot hide behind
---`vim.tbl_deep_extend` either. Returns a shallow-ish copy; kept leaf values
---are the original references, not deep-copied.
---@param raw table
---@param allowed string[]
---@param path string  dotted prefix for a nested warning, e.g. "smart."
---@return table
local function sanitize_level(raw, allowed, path)
  local known = {}
  for _, k in ipairs(allowed) do
    known[k] = true
  end

  local out = {}
  for key, value in pairs(raw) do
    if type(key) ~= "string" then
      out[key] = value -- not a named option (e.g. a list); nothing to validate
    elseif not known[key] then
      notify.warn(
        string.format("Unknown config key %q%s -- ignored", path .. key, did_you_mean(key, allowed))
      )
    elseif type(value) == "table" and NESTED_OPTS[path .. key] then
      out[key] = sanitize_level(value, NESTED_OPTS[path .. key], path .. key .. ".")
    else
      out[key] = value
    end
  end
  return out
end

---Merge user-provided options into the active configuration.
---@param opts Pickers.Config|nil
function M.apply(opts)
  local cfg = M.get()
  if type(opts) ~= "table" then return end

  -- ERR-50: validated (and unknown keys dropped) before anything below reads
  -- from it, so a typo cannot vanish silently into either the top-level
  -- default or a deep-merged sub-table that would otherwise absorb it.
  local sanitized = sanitize_level(opts, TOP_LEVEL_OPTS, "")

  if type(sanitized.engine) == "string" then cfg.engine = sanitized.engine end
  if type(sanitized.repos_dir) == "string" then cfg.repos_dir = expand_path(sanitized.repos_dir) end
  if type(sanitized.deps_popup) == "boolean" then cfg.deps_popup = sanitized.deps_popup end

  if type(sanitized.collections) == "table" then
    cfg.collections = {}
    for _, raw in ipairs(sanitized.collections) do
      local coll = normalise_collection(raw)
      if coll then
        cfg.collections[#cfg.collections + 1] = coll
      else
        notify.warn(
          string.format(
            "Invalid collection entry (name+dir required, and name must "
              .. "produce a legal :{Name}Files command): %s",
            vim.inspect(raw)
          )
        )
      end
    end
  end

  if type(sanitized.depth_aliases) == "table" then
    for k, v in pairs(sanitized.depth_aliases) do
      if type(k) == "string" and type(v) == "function" then cfg.depth_aliases[k] = v end
    end
  end

  if type(sanitized.find) == "table" then
    cfg.find = vim.tbl_deep_extend("force", cfg.find, sanitized.find)
  end

  if type(sanitized.keymaps) == "table" then
    cfg.keymaps = vim.tbl_deep_extend("force", cfg.keymaps, sanitized.keymaps)
  end
  -- Plain replace, not merged -- each entry is independent and there is no
  -- meaningful "default" to merge a user's mappings table against (unlike
  -- keymaps/find/smart, DEFAULTS.mappings is always empty).
  if type(sanitized.mappings) == "table" then cfg.mappings = sanitized.mappings end
  if type(sanitized.usercmds) == "table" then
    cfg.usercmds = vim.tbl_deep_extend("force", cfg.usercmds, sanitized.usercmds)
  end

  if type(sanitized.keys) == "table" then cfg.keys = normalise_keys(sanitized.keys, cfg.keys) end

  if type(sanitized.history) == "table" then
    cfg.history = normalise_history(sanitized.history, cfg.history)
  end

  -- Both keys were removed and are read here for one purpose: to say so. They
  -- are deliberately absent from `Pickers.Opts` -- naming them there would
  -- claim they are supported.
  ---@diagnostic disable-next-line: undefined-field
  if type(sanitized.selected_index) == "table" or type(sanitized.experimental) == "table" then
    notify.warn(
      "selected_index has been removed (it never worked reliably) -- "
        .. "this opts.selected_index/opts.experimental was ignored."
    )
  end

  if type(sanitized.result_count) == "table" then
    if type(sanitized.result_count.enabled) == "boolean" then
      cfg.result_count.enabled = sanitized.result_count.enabled
    end
    if
      type(sanitized.result_count.interval_ms) == "number"
      and sanitized.result_count.interval_ms > 0
    then
      cfg.result_count.interval_ms = math.floor(sanitized.result_count.interval_ms)
    end
  end

  -- Deep-merge smart over defaults (weights/limit/timeout); same leniency as
  -- cfg.find -- not validated field-by-field.
  if type(sanitized.smart) == "table" then
    cfg.smart = vim.tbl_deep_extend("force", cfg.smart, sanitized.smart)
  end

  if type(sanitized.display) == "table" then
    if type(sanitized.display.path_shorten) == "boolean" then
      cfg.display.path_shorten = sanitized.display.path_shorten
    end
  end

  if type(sanitized.images) == "table" then
    if type(sanitized.images.enabled) == "boolean" then
      cfg.images.enabled = sanitized.images.enabled
    end
  end

  -- A group list replaces the default group of the same name wholesale (a
  -- list is not something to merge element by element); other groups stay.
  if type(sanitized.tabs) == "table" and type(sanitized.tabs.groups) == "table" then
    for name, targets in pairs(sanitized.tabs.groups) do
      if type(name) == "string" and (type(targets) == "table" or targets == false) then
        cfg.tabs.groups[name] = targets or nil
      end
    end
  end

  -- Deep-merge quickfix over defaults; a key set to `false` unbinds it, so
  -- `false` has to survive the merge (tbl_deep_extend keeps it).
  if type(sanitized.quickfix) == "table" then
    cfg.quickfix = vim.tbl_deep_extend("force", cfg.quickfix, sanitized.quickfix)
  end
end

return M
