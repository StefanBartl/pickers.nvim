---@module 'pickers.integrations.filetree'
---@brief Files / live grep scoped to one directory, for filetree.nvim's tree.
---@description
--- [filetree.nvim](https://github.com/StefanBartl/filetree.nvim) has `f` (find
--- files) and `gr` (grep) on a tree node. When this plugin is installed it hands
--- the node's directory here instead of driving a picker of its own, so the
--- engine choice, the `find.*` flags and the entry actions are the ones the rest
--- of the setup already uses.
---
--- pickers.nvim's own scopes (cwd / config / folder / collection) all resolve a
--- root themselves; this is the one entry point that is given one. It builds the
--- same `{ roots, prompt }` source a scope produces and runs the same action.
---
--- **The dependency is one-directional and soft**, like `pickers.integrations.
--- images`: filetree.nvim calls this and nothing here loads filetree. Both ends
--- can switch it off: `filetree = { enabled = false }` here (opt-OUT, default
--- on), `integrations.pickers = false` over there. Off, or no engine installed,
--- every call answers `false` and the caller falls back to its own backends.

local M = {}

---@internal
---@return table|nil engine_mod
local function engine()
  local mod = require("pickers.engines").load()
  return mod
end

---@internal
---Whether any engine is installed, asked without `engines.load`'s error
---notification: filetree.nvim asks on every `f` / `gr` press, and "no engine"
---is a normal answer there (it falls back), not something to report each time.
---@return boolean
local function has_engine()
  for _, name in ipairs({ "telescope", "fzf", "snacks" }) do
    local ok, mod = pcall(require, "pickers.engines." .. name)
    if ok and type(mod) == "table" and type(mod.available) == "function" and mod.available() then
      return true
    end
  end
  return false
end

---True when filetree.nvim may use this plugin: the switch is on and an engine
---(telescope / fzf-lua / snacks) is installed.
---@return boolean
function M.available()
  local cfg = require("pickers.config").get()
  if type(cfg.filetree) == "table" and cfg.filetree.enabled == false then return false end
  return has_engine()
end

---@internal
---A root the engines can search: an existing directory. Anything else is not
---this bridge's to report -- the caller falls back, as for any other refusal.
---@param dir any
---@return boolean
local function usable_dir(dir)
  return type(dir) == "string" and dir ~= "" and vim.fn.isdirectory(dir) == 1
end

---@internal
---@param dir string
---@param what string
---@param query string|nil
---@return Pickers.Source
local function source_for(dir, what, query)
  local name = vim.fn.fnamemodify(dir, ":t")
  return {
    roots = { dir },
    prompt = what .. " " .. (name ~= "" and name or dir) .. "> ",
    query = query,
  }
end

---Find files under `dir`.
---@param dir string
---@param opts? { query?: string, on_select?: fun(path: string) }  # `on_select`: called with the absolute path of the file that was picked, after the engine opened it.
---@return boolean handled  # false when disabled or no engine is installed.
function M.files(dir, opts)
  if not usable_dir(dir) or not M.available() then return false end
  -- `available()` saw an engine, but `load` honours the configured one and can
  -- still come back empty; nothing to run then.
  local eng = engine()
  if not eng then return false end
  opts = opts or {}
  local source = source_for(dir, "Files", opts.query)
  if type(opts.on_select) == "function" then source.on_select = opts.on_select end
  require("pickers.last").set("files", source)
  require("pickers.actions.files").run(source, eng)
  return true
end

---Live grep under `dir`.
---@param dir string
---@param opts? { query?: string, extra_args?: string[] }
---@return boolean handled  # false when disabled or no engine is installed.
function M.grep(dir, opts)
  if not usable_dir(dir) or not M.available() then return false end
  local eng = engine()
  if not eng then return false end
  opts = opts or {}
  local source = source_for(dir, "Grep", opts.query)
  require("pickers.last").set("grep", source)
  require("pickers.actions.grep").run(source, eng, opts.extra_args)
  return true
end

return M
