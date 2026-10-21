---@module 'pickers.config'
---@brief The active configuration: `DEFAULTS` plus what `apply()` was given, through `lib.lua.config.new`.
---@see pickers.config.DEFAULTS
---@description
--- `M.apply(opts)` can be called more than once (several lazy.nvim specs for this plugin, or incrementally):
--- every call is checked against the schema inferred from `DEFAULTS`, the part that passes is merged into
--- `applied` (the options of all calls so far), and `lib.lua.config` computes the config from the defaults and
--- `applied` from scratch, then runs `resolve`. `pickers.setup()` calls `M.reset()` first, so a second real
--- `setup()` replaces the first (LUA-87).
---
--- What a call is allowed to say:
---  * an unknown key is reported with a did-you-mean hint and left out (ERR-50);
---  * a value of the wrong type, outside its bounds or not in its list of values is reported and left out, so
---    the value of an earlier call (or the default) stays (ERR-22);
---  * `keymaps` / `usercmds` may be `false` (`{ enable = false }`) or `true` (`{ enable = true }`) (REL-20);
---  * `collections` is replaced whole by each call, `mappings` too; `tabs.groups` and `depth_aliases` merge entry
---    by entry (a group set to `false` removes the default one); every other table merges key by key and a list
---    replaces.
---
--- `resolve` derives what no layer can say: `repos_dir` from lib.nvim's env snapshot when unset (LUA-06), the
--- `~` / `$VAR` of the paths, the collections in their final shape, the fold of `find.ignore_list` into
--- `find.exclude`, whole numbers where a count is meant.

local expand_path = require("lib.nvim.cross.fs.expand_path")
local notify = require("lib.nvim.notify").create("[pickers]")
local lib_config = require("lib.lua.config")
local schema = require("lib.lua.config.schema")

local DEFAULTS = require("pickers.config.DEFAULTS")

local M = {}

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

-- ── What the schema cannot infer from DEFAULTS ───────────────────────────────
-- DEFAULTS.lua cannot say it all: several of its fields default to `nil` (repos_dir, find.exclude, history.dir,
-- the opt-in keymaps, ...) and a Lua table never stores a nil-valued key, a few take a second type (a key that is
-- `false` by default also takes a string), and some have bounds or a closed set of values.

---Every action of `keymaps` that takes a key: a string, a list of strings, or `false` (unbound).
local KEYMAP_ACTIONS = {
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
  "cwd_filegrep",
  "cwd_find_all",
}

---Every action of `keys` that takes a key (`enable` and `open_background_show` are switches).
local KEYS_ACTIONS = {
  "preview_scroll_down",
  "preview_scroll_up",
  "preview_scroll_left",
  "preview_scroll_right",
  "history_back",
  "history_forward",
  "create_file",
  "open_background",
  "preview_toggle",
  "split",
  "vsplit",
  "tab",
  "mouse_confirm",
  "cheatsheet",
  "copy_absolute",
  "copy_dirname",
  "copy_env_rooted",
  "copy_project_root",
  "copy_project_relative",
  "copy_buffer_relative",
  "markdown_link",
  "markdown_link_insert",
  "open_system",
  "reveal_in_manager",
  -- Opt-in tab-group switch actions (pickers.keys.ACTIONS.tab_next/tab_prev).
  "tab_next",
  "tab_prev",
}

---@type table<string, any>
local EXCEPTIONS = {
  repos_dir = "string",
  depth_aliases = { "table" }, -- the user picks the names; the entries are checked in `resolve`
  ["find.exclude"] = "table",
  ["history.dir"] = "string",
  ["history.fzf_scope"] = { "string", enum = { "plugin", "global", "patch" } },
  ["history.limit"] = { "number", min = 1 },
  ["result_count.interval_ms"] = { "number", min = 1 },
  ["smart.limit"] = { "number", min = 1 },
  ["smart.timeout"] = { "number", min = 1 },
  ["smart.frecency.dir"] = "string",
  -- Opt-in switches, nil = the engine keeps its own default (pickers.display_native).
  ["display.path_adaptive"] = "boolean",
  ["display.cycle"] = "boolean",
  ["display.prompt_top"] = "boolean",
  ["display.preview_wrap"] = "boolean",
  ["link_insert.path"] = { "string", enum = { "buffer", "cwd", "absolute", "env" } },
  ["link_insert.cursor.path_cursor"] = { "string", enum = { "end", "start" } },
  ["quickfix.preview.height"] = { "number", min = 1 },
  ["quickfix.preview.context"] = { "number", min = 0 },
  ["quickfix.preview.delay_ms"] = { "number", min = 0 },
  ["quickfix.keys.filter"] = "string|false",
  ["quickfix.keys.restore"] = "string|false",
  ["quickfix.keys.toggle_preview"] = "string|false",
}
for _, name in ipairs(KEYMAP_ACTIONS) do
  EXCEPTIONS["keymaps." .. name] = "keymap"
end
for _, name in ipairs(KEYS_ACTIONS) do
  EXCEPTIONS["keys." .. name] = "keymap"
end

---Merge rules of the store: `tabs.groups` and `depth_aliases` are maps of independent entries (a group set to
---`false` removes the default one), `mappings` has no default to merge against.
local STORE_MERGE = {
  ["tabs.groups"] = "entries",
  depth_aliases = "entries",
  mappings = "replace",
}

---Merge rules of the options collected from the calls of `apply()`: a `false` entry must survive until the store
---merges it over the defaults, so `entries` would drop it here.
local APPLIED_MERGE = { mappings = "replace" }

---The schema every call is checked against: the one the store checks its layer with (an `entries` section is an
---open table there, so it is one here).
local CALL_SCHEMA = (function()
  local all = { ["tabs.groups"] = { "table" } }
  for path, s in pairs(EXCEPTIONS) do
    all[path] = s
  end
  return schema.infer(DEFAULTS, all)
end)()

---The options all calls of `apply()` have contributed (already checked), the input of the store.
---@type table
local applied = {}

---@param message string
local function warn(message)
  notify.warn(message)
end

local store = lib_config.new(DEFAULTS, {
  name = "pickers",
  layers = { "setup" },
  schema = EXCEPTIONS,
  merge = STORE_MERGE,
  -- The module that took `config.get().keys` once keeps seeing the current values.
  stable = true,
  notify = warn,
  resolve = function(cfg, issues)
    -- `repos_dir`: via lib.nvim's env snapshot, not a direct vim.env read -- it is the one sanctioned place this
    -- env var is read, and `repo_base` is nil when unset. Resolved here rather than in DEFAULTS.lua so requiring
    -- that module alone stays pure data (LUA-06).
    if type(cfg.repos_dir) == "string" then
      cfg.repos_dir = expand_path(cfg.repos_dir)
    else
      cfg.repos_dir = require("lib.nvim.system.env").get().repo_base
    end

    local collections = {}
    for _, raw in ipairs(cfg.collections or {}) do
      local coll = normalise_collection(raw)
      if coll then
        collections[#collections + 1] = coll
      else
        issues[#issues + 1] = "invalid collection entry (name+dir required, and name must "
          .. "produce a legal :{Name}Files command): "
          .. vim.inspect(raw, { newline = " ", indent = "" })
      end
    end
    cfg.collections = collections

    -- The names are the user's; only a function under a string name is an alias.
    for name, fn in pairs(cfg.depth_aliases) do
      if type(name) ~= "string" or type(fn) ~= "function" then
        issues[#issues + 1] = ("depth_aliases.%s must be a function"):format(tostring(name))
        cfg.depth_aliases[name] = nil
      end
    end

    -- A group list replaces the default group of the same name wholesale (a list is not something to merge
    -- element by element); other groups stay.
    for name, targets in pairs(cfg.tabs.groups) do
      if type(name) ~= "string" or type(targets) ~= "table" then
        issues[#issues + 1] = ("tabs.groups.%s must be a list of :Pickers arguments"):format(
          tostring(name)
        )
        cfg.tabs.groups[name] = nil
      end
    end

    -- `find.ignore_list`: fold lib.nvim's shared ignore list into the excludes, so every consumer of
    -- cfg.find.exclude sees it.
    if cfg.find.ignore_list == true then
      cfg.find.exclude = require("pickers.find_native").with_ignore_list(cfg.find.exclude)
    end

    if cfg.history.dir == "" then
      cfg.history.dir = nil
    elseif type(cfg.history.dir) == "string" then
      cfg.history.dir = expand_path(cfg.history.dir)
    end

    -- counts are whole numbers
    cfg.smart.limit = math.floor(cfg.smart.limit)
    cfg.result_count.interval_ms = math.floor(cfg.result_count.interval_ms)
    local preview = cfg.quickfix.preview
    preview.height = math.floor(preview.height)
    preview.context = math.floor(preview.context)
    preview.delay_ms = math.floor(preview.delay_ms)
    if preview.border == "" then
      preview.border = DEFAULTS.quickfix.preview.border
      issues[#issues + 1] = "quickfix.preview.border must not be empty"
    end
  end,
})

---Return the active configuration (the defaults until `M.apply()` was called).
---@return Pickers.Config
function M.get()
  return store.get()
end

---Discard everything `M.apply()` was given, so the next `M.get()`/`M.apply()` call starts from `DEFAULTS` again.
---`pickers.setup()` calls this before `M.apply(opts)`, so a second real `setup()` call in the same Lua state
---replaces the first cleanly instead of composing on top of whatever it left behind (LUA-87). `M.apply()` on its
---own builds up one configuration -- that is what lets it be called repeatedly (e.g. incrementally, or across
---several lazy.nvim specs for this plugin), which is a different, still-supported use.
function M.reset()
  applied = {}
  store.reset()
end

---What was dropped or degraded since the last `M.reset()`, for `:checkhealth`.
---@return string[]
function M.issues()
  return store.issues()
end

---The `switch group` shape of `keymaps` / `usercmds`: `false` is `{ enable = false }`, `true` is
---`{ enable = true }` (a later `true` must switch the group back on).
---@internal
---@param value any
---@return table|nil
local function switch(value)
  if value == true then return { enable = true } end
  return require("lib.nvim.normalize").normalize_switch_group(value)
end

---Merge user-provided options into the active configuration.
---@param opts Pickers.Config|nil
function M.apply(opts)
  if type(opts) ~= "table" then return end

  local copy = lib_config.copy(opts)
  copy.keymaps = switch(copy.keymaps)
  copy.usercmds = switch(copy.usercmds)

  -- Both keys were removed and are read here for one purpose: to say so. They are deliberately absent from
  -- `Pickers.Opts` -- naming them there would claim they are supported.
  if type(copy.selected_index) == "table" or type(copy.experimental) == "table" then
    warn(
      "selected_index has been removed (it never worked reliably) -- "
        .. "this opts.selected_index/opts.experimental was ignored."
    )
  end
  copy.selected_index, copy.experimental = nil, nil

  -- ERR-50 / ERR-22: what this call says is checked before it joins the rest, so a typo or a wrong value costs
  -- this call that option and nothing else: an earlier call's value stays.
  local problems = {}
  local clean = schema.check_record(copy, CALL_SCHEMA.fields, "", problems)
  for _, problem in ipairs(problems) do
    warn(problem)
  end

  applied = lib_config.deep_merge(applied, clean, APPLIED_MERGE)
  store.setup(applied)
end

return M
