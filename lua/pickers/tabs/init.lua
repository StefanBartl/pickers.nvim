---@module 'pickers.tabs'
---@brief Tab groups: a named list of `:Pickers` targets you cycle through
---from inside an open picker with `tab_next`/`tab_prev`, the typed query
---travelling along -- search.nvim's tabbed UI over this plugin's grammar.
---@description
--- A group is a list of argument strings exactly as `:Pickers` takes them:
---
---   tabs = {
---     groups = {
---       default = { "cwd files", "cwd grep", "builtin buffers" },
---       git = { "builtin git_branches", "builtin git_commits", "builtin git_stash" },
---     },
---   }
---
--- `tabs.open("default")` runs the first target; the in-picker keys
--- `tab_next`/`tab_prev` (opt-in, `keys.tab_next`/`keys.tab_prev`) close
--- the picker and run the next/previous target with the current query as
--- the new picker's initial query (files/grep/smart targets; a builtin has
--- no query slot and starts empty). The group ends when a picker opened
--- any other way is closed: the state is per launch, not global.
---
--- No tab bar is drawn. The prompt title carries `[2/3 cwd grep]` instead,
--- because every engine already draws a title and none of them offers a
--- second line for free.

local notify = require("lib.nvim.notify").create("[pickers]")

local M = {}

---@class Pickers.TabsConfig
---@field groups table<string, string[]>   # group name -> :Pickers argument strings

---@type Pickers.TabsConfig
M.DEFAULTS = {
  groups = {
    default = { "cwd files", "cwd grep", "builtin buffers" },
    git = { "builtin git_branches", "builtin git_commits", "builtin git_stash" },
  },
}

---@class Pickers.TabsState
---@field group string
---@field index integer
---@field targets string[]

---@type Pickers.TabsState|nil
local state = nil

---@return Pickers.TabsConfig
local function cfg()
  local ok, config = pcall(require, "pickers.config")
  if ok then
    local c = config.get().tabs
    if type(c) == "table" and type(c.groups) == "table" then return c end
  end
  return M.DEFAULTS
end

---The targets of `group`, or nil with a notification.
---@param group string
---@return string[]|nil
function M.targets(group)
  local t = cfg().groups[group]
  if type(t) ~= "table" or #t == 0 then
    notify.warn(
      ("tabs: no group %q (known: %s)"):format(tostring(group), table.concat(M.names(), ", "))
    )
    return nil
  end
  return t
end

---Sorted group names.
---@return string[]
function M.names()
  local out = {}
  for k in pairs(cfg().groups or {}) do
    out[#out + 1] = k
  end
  table.sort(out)
  return out
end

---The live state, or nil when no tab group is active.
---@return Pickers.TabsState|nil
function M.current()
  return state
end

---The `[i/n target]` suffix for the prompt of the active tab, or "".
---@return string
function M.title_suffix()
  if not state then return "" end
  return (" [%d/%d %s]"):format(state.index, #state.targets, state.targets[state.index])
end

---Forget the active group (a picker closed by other means).
function M.reset()
  state = nil
end

---@internal
---Run target `index` of the active group with `query`.
---@param query string|nil
local function run_current(query)
  if not state then return end
  local target = state.targets[state.index]
  local fargs = vim.split(target, "%s+", { trimempty = true })
  require("pickers.command").handle({ fargs = fargs, query = query, from_tabs = true })
end

---Open `group` (default "default") at target `index` (default 1).
---@param group string|nil
---@param index integer|nil
---@param query string|nil
function M.open(group, index, query)
  group = group or "default"
  local targets = M.targets(group)
  if not targets then return end
  index = math.max(1, math.min(index or 1, #targets))
  state = { group = group, index = index, targets = targets }
  run_current(query)
end

---Move `delta` tabs (wrapping) and run that target with `query`. No-op with
---a notification when no group is active.
---@param delta integer
---@param query string|nil
---@return boolean switched
function M.switch(delta, query)
  if not state then
    notify.info("tabs: no tab group active -- open one with :Pickers tabs <group>")
    return false
  end
  local n = #state.targets
  state.index = ((state.index - 1 + delta) % n) + 1
  vim.schedule(function()
    run_current(query)
  end)
  return true
end

---@param query string|nil
---@return boolean
function M.next(query)
  return M.switch(1, query)
end

---@param query string|nil
---@return boolean
function M.prev(query)
  return M.switch(-1, query)
end

return M
