---@module 'pickers.actions.dir'
---@brief Dir-navigation action: resolve path from nav arg, then dispatch files or grep.
---@description
--- nav_arg forms (all case-insensitive for keyword matching):
---   nil          → interactive: show dir_nav_picker, then action_picker
---   "1" … "N"   → go N directories up from cwd
---   "git"        → git repo root of cwd
---   "home"       → os home directory
---   "cwd"        → current working directory
---   "root"       → filesystem root above cwd
---   "<alias>"    → any user-defined alias in config.depth_aliases
---   "path=<dir>" → explicit path (~ / %VAR% / $VAR expanded)

local notify = require("lib.nvim.notify").create("[pickers.actions.dir]")

local M = {}

-- ── Path resolution helpers ───────────────────────────────────────────────────

---Expand ~ / %WINVAR% / $POSIXVAR in an explicit path string.
---@param raw string
---@return string
local function expand_vars(raw)
  local home = vim.uv.os_homedir() or vim.fn.expand("~")
  local s = raw:gsub("^~", home)
  s = s:gsub("%%([^%%]+)%%", function(v) return os.getenv(v) or ("%" .. v .. "%") end)
  s = s:gsub("%$([%w_]+)",   function(v) return os.getenv(v) or ("$" .. v) end)
  return vim.fs.normalize(s)
end

---Walk up `depth` directory levels from cwd.
---@param depth integer
---@return string
local function by_depth(depth)
  local cwd = vim.uv.cwd() or vim.fn.getcwd()
  if depth <= 0 then return vim.fs.normalize(cwd) end
  return vim.fs.normalize(cwd .. string.rep("/..", depth))
end

---Resolve a nav arg to an absolute directory path.
---Returns nil when the arg is invalid or the resolver fails.
---@param arg string|nil
---@param cfg Pickers.Config
---@return string|nil
local function resolve(arg, cfg)
  -- nil / empty → cwd
  if not arg or arg:match("^%s*$") then
    return vim.fs.normalize(vim.uv.cwd() or vim.fn.getcwd())
  end

  -- Explicit path= prefix
  local path_val = arg:match("^[Pp][Aa][Tt][Hh]=(.+)$")
  if path_val then
    path_val = path_val:match('^"(.*)"$') or path_val:match("^'(.*)'$") or path_val
    return path_val ~= "" and expand_vars(path_val) or nil
  end

  -- Named alias (case-insensitive key lookup)
  local lower = arg:lower():match("^%s*(.-)%s*$")
  local resolver = cfg.depth_aliases[lower]
  if resolver then
    local ok, result = pcall(resolver)
    if ok and type(result) == "string" then
      return vim.fs.normalize(result)
    end
    notify.error("Alias '" .. lower .. "' resolver failed")
    return nil
  end

  -- Numeric depth
  local depth = tonumber(arg)
  if depth then
    return by_depth(math.max(0, math.floor(depth)))
  end

  -- Treat raw arg as an explicit path
  return expand_vars(arg)
end

-- ── Dispatch ─────────────────────────────────────────────────────────────────

---@param path       string
---@param action     Pickers.Action
---@param engine_mod table
local function dispatch(path, action, engine_mod)
  local tail   = vim.fn.fnamemodify(path, ":t")
  local source = {
    roots  = { path },
    prompt = (tail ~= "" and tail or path) .. "> ",
  }
  if action == "grep" then
    require("pickers.actions.grep").run(source, engine_mod)
  else
    require("pickers.actions.files").run(source, engine_mod)
  end
end

-- ── Public API ────────────────────────────────────────────────────────────────

---@param nav_arg    string|nil        nil → interactive dir-nav picker
---@param action     Pickers.Action|nil  nil → interactive action picker
---@param engine_mod table
function M.run(nav_arg, action, engine_mod)
  local cfg = require("pickers.config").get()

  local function after_path(path)
    if not path or vim.fn.isdirectory(path) == 0 then
      notify.error("Not a directory: " .. tostring(path))
      return
    end
    if action then
      dispatch(path, action, engine_mod)
    else
      require("pickers.ui.action_picker").open(function(chosen)
        if chosen then dispatch(path, chosen, engine_mod) end
      end)
    end
  end

  if nav_arg then
    after_path(resolve(nav_arg, cfg))
  else
    -- Interactive dir-nav picker first
    require("pickers.ui.dir_nav_picker").open(cfg, function(chosen_nav)
      if not chosen_nav then return end
      after_path(resolve(chosen_nav, cfg))
    end)
  end
end

---Return sorted alias names (used for :Pickers tab-completion).
---@return string[]
function M.alias_names()
  local cfg   = require("pickers.config").get()
  local names = {}
  local i     = 0
  for k in pairs(cfg.depth_aliases) do
    i        = i + 1
    names[i] = k
  end
  table.sort(names)
  return names
end

return M
