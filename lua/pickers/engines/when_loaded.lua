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
--- it. Under lazy.nvim that means its `User LazyLoad` event; without a plugin
--- manager that reports loads, fall back to the previous `vim.schedule`
--- behaviour rather than silently never patching.
---
--- Call order stays irrelevant for correctness -- both engines deep-merge the
--- tables involved (see `pickers.keys.patch` and `pickers.history.patch`).

local M = {}

--- lazy.nvim plugin names, keyed by the Lua module the patch requires.
---@type table<string, string>
local PLUGIN_NAMES = {
  telescope = "telescope.nvim",
  ["fzf-lua"] = "fzf-lua",
}

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
    -- No lazy.nvim: nothing tells us when the engine shows up. Keep the old
    -- behaviour so the patch still lands on a plain packadd/rtp setup.
    vim.schedule(fn)
    return
  end

  local plugin = PLUGIN_NAMES[module]
  vim.api.nvim_create_autocmd("User", {
    pattern = "LazyLoad",
    callback = function(ev)
      if ev.data ~= plugin then return end
      fn()
      return true -- one-shot: delete this autocmd
    end,
  })
end

return M
