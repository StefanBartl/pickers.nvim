---@module 'pickers.engines.when_loaded'
---@brief Run a patch against a picker engine only once that engine is actually loaded.
---@description
--- pickers.nvim patches its in-picker keys (and, opt-in, its history) onto
--- telescope's and fzf-lua's global config, so they apply to every picker
--- those engines open. The obvious way to do that -- call
--- `require("telescope").setup(..)` during pickers.nvim's own `setup()` -- has
--- a cost that is easy to miss: `require("telescope")` pulls in the engine's
--- full module tree, which defeats its `cmd = "Telescope"` lazy-loading and
--- puts it back into every startup, for a picker the user may never open.
---
--- `vim.schedule` does NOT fix that. It only moves the call to the end of the
--- current event-loop iteration -- still during startup. It is the right tool
--- for "land after the user's own setup() in the same batch", which is why it
--- was used here, but it never addressed the load cost.
---
--- So: patch immediately when the engine is already loaded, otherwise wait for
--- it. Under lazy.nvim that means its `User LazyLoad` event, which fires after
--- the plugin's own `config`/`opts` ran (the host's `setup()` is done by then).
---
--- Without lazy.nvim nothing reports loads, so the wait is a one-shot hook on
--- `require` itself (`on_require`): the patch runs, scheduled, right after the
--- first `require` of the engine returns -- i.e. after the host's own
--- `setup()` call in the same chunk -- and an engine the user never loads is
--- never loaded by this plugin either. (An earlier fallback was a plain
--- `vim.schedule`, which `require`d the engine at startup and put back the
--- exact load cost this module exists to avoid.)
---
--- Call order stays irrelevant for correctness -- each contribution is folded
--- into what the host already configured (see `pickers.engines.patcher`).
---
--- lib.nvim is a hard dependency (see pickers.bindings.util); this requires
--- lib.nvim.bindings.autocmd the same way, with no standalone fallback
--- (LUA-01).

local lib_autocmd = require("lib.nvim.bindings.autocmd")

local M = {}

--- lazy.nvim plugin names, keyed by the Lua module the patch requires.
---@type table<string, string>
local PLUGIN_NAMES = {
  telescope = "telescope.nvim",
  ["fzf-lua"] = "fzf-lua",
  snacks = "snacks.nvim",
}

---@return table  # `package.searchers` (5.2 name) or `package.loaders` (LuaJIT)
local function searcher_list()
  return rawget(package, "searchers") or package.loaders
end

---Run `fn`, scheduled, right after the first `require(module)` returns.
---
---Implemented as a one-shot searcher at the front of the searcher list. It
---must NOT simply call `require(module)` from its loader: LuaJIT parks a
---sentinel in `package.loaded[module]` while a loader runs, so a nested
---`require` of the same name raises "loop or previous error loading module".
---It resolves the real loader itself, through the other searchers, and hands
---that back wrapped -- `require` then caches exactly what the real loader
---returned. Several waiters on the same module stack and all fire.
---@param module string
---@param fn fun()
local function on_require(module, fn)
  local searchers = searcher_list()

  ---@type function
  local searcher
  searcher = function(name)
    if name ~= module then return nil end
    -- One-shot, and before the chain below runs: it must not find us again.
    for i, s in ipairs(searchers) do
      if s == searcher then
        table.remove(searchers, i)
        break
      end
    end
    for _, other in ipairs(searchers) do
      local loader, extra = other(name)
      if type(loader) == "function" then
        return function(...)
          local result = loader(...)
          vim.schedule(fn)
          return result
        end,
          extra
      end
    end
    return nil
  end

  table.insert(searchers, 1, searcher)
end

---Run `fn` once `module` is loaded (or right away if it already is).
---@param module string  # the Lua module the patch will require, e.g. "telescope"
---@param fn fun()
---@return nil
function M.run(module, fn)
  if package.loaded[module] then
    fn()
    return
  end

  local ok_lazy = pcall(require, "lazy.core.config")
  if not ok_lazy then
    -- No lazy.nvim: nothing announces a load, so hook `require` itself.
    on_require(module, fn)
    return
  end

  local plugin = PLUGIN_NAMES[module]

  -- One-shot, but not via a `true` return: that only works for an unwrapped
  -- callback, and lib.nvim's create() pcalls callbacks by default, which
  -- discards the return value and would leave this firing on every LazyLoad
  -- forever. Deleting by id works either way -- and before fn(), so a plugin
  -- that loads another one during the patch cannot re-enter this.
  local id
  local function on_lazy_load(ev)
    if ev.data ~= plugin then return end
    if id then pcall(vim.api.nvim_del_autocmd, id) end
    fn()
  end

  id = lib_autocmd.create("User", on_lazy_load, {
    group = "pickers.nvim",
    pattern = "LazyLoad",
    desc = "pickers.nvim: patch " .. module .. " once lazy.nvim loads it",
  })
end

return M
