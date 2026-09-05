---@module 'pickers.plugin_spec'
---@brief Optional engine ownership + auto-install, via `require("pickers").plugin_spec()`.
---@description
--- `pickers.setup({ own_engine = true })` alone cannot install a missing
--- engine: lazy.nvim reads a plugin's static `dependencies` field BEFORE any
--- `config()` function runs, so pickers.nvim's own spec can't conditionally
--- depend on e.g. `folke/snacks.nvim` based on an `engine=` value that is
--- only known once `setup()` runs -- by then lazy has already resolved and
--- installed dependencies for the current session.
---
--- `plugin_spec()` sidesteps that by being called from the *user's own*
--- plugin list, at spec-BUILD time, where the engine choice is known early
--- enough to shape `dependencies` correctly. It returns a ready lazy.nvim
--- spec list (1 entry when `own_engine` is false/unset, 2 when true) with
--- the right `dependencies` and a `config()` that also calls
--- `Snacks.setup()` / `telescope.setup()` / `fzf-lua.setup()` on the user's
--- behalf:
---
---   require("lazy").setup({
---     require("pickers").plugin_spec({ engine = "snacks", own_engine = true }),
---     -- ...your other plugins
---   })
---
--- `own_engine` defaults to false/off (today's behaviour, unchanged):
--- `docs/keymaps.md` and `pickers.keys` already document, deliberately,
--- that "pickers.nvim does not own `Snacks.setup()`" -- so users keep full
--- control over engine-specific config that has nothing to do with picking
--- (snacks dashboard/explorer/notifier, telescope extensions, fzf-lua
--- winopts, …) without a second competing `setup()` call fighting theirs.
--- `own_engine = true` is a real, separate, opt-in mode for users who want
--- zero engine config of their own -- not a replacement for the default
--- "you own the engine, pickers.nvim just detects it" model.
---
--- `engine = "auto"` (or unset) with `own_engine = true` is out of scope --
--- there is no single engine to install -- and raises an error immediately
--- (at spec-build time, not buried inside a later `config()` failure).

local M = {}

---@type table<string, { repo: string, dependencies: string[]|nil, setup_module: string }>
local ENGINE_PLUGINS = {
  telescope = {
    repo = "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    setup_module = "telescope",
  },
  fzf = {
    repo = "ibhagwan/fzf-lua",
    dependencies = nil,
    setup_module = "fzf-lua",
  },
  snacks = {
    repo = "folke/snacks.nvim",
    dependencies = nil,
    setup_module = "snacks",
  },
}

---@class Pickers.PluginSpecOpts
---@field engine       Pickers.Engine|nil    Required when `own_engine = true`; must be "telescope"|"fzf"|"snacks" ("auto" is out of scope)
---@field own_engine   boolean|nil           Default: false. See module @brief.
---@field engine_opts  table|nil             Passed to the engine's own `setup()` (telescope/fzf-lua/snacks), when `own_engine = true`.
---@field picker_opts  Pickers.Config|nil    Passed to `require("pickers").setup()`. `engine` is filled in automatically from `opts.engine` unless already set.

---Build a ready-to-use lazy.nvim spec list for pickers.nvim, optionally also
---installing + configuring its engine.
---@param opts Pickers.PluginSpecOpts|nil
---@return table[] specs  Always a list (1 entry when own_engine is off, 2 when on) -- splat into your own lazy spec list.
function M.plugin_spec(opts)
  opts = opts or {}
  local own_engine = opts.own_engine == true
  local picker_opts = vim.tbl_deep_extend("force", {}, opts.picker_opts or {})

  if not own_engine then
    if opts.engine and picker_opts.engine == nil then picker_opts.engine = opts.engine end
    return {
      {
        "StefanBartl/pickers.nvim",
        dependencies = { "StefanBartl/lib.nvim" },
        config = function()
          require("pickers").setup(picker_opts)
        end,
      },
    }
  end

  local engine_plugin = ENGINE_PLUGINS[opts.engine]
  if not engine_plugin then
    error(
      "pickers.plugin_spec: own_engine=true requires an explicit engine "
        .. '("telescope"|"fzf"|"snacks"), got '
        .. vim.inspect(opts.engine)
        .. ' -- "auto" has no single engine to install.'
    )
  end

  -- The engine plugin's OWN config() (below) already calls its setup()
  -- before pickers.setup() runs (lazy.nvim loads dependencies first), so
  -- pickers.setup() itself needs nothing engine-specific beyond `engine=` --
  -- no separate "own_engine" runtime flag on Pickers.Config is needed.
  picker_opts.engine = opts.engine

  return {
    {
      engine_plugin.repo,
      dependencies = engine_plugin.dependencies,
      config = function()
        require(engine_plugin.setup_module).setup(opts.engine_opts or {})
      end,
    },
    {
      "StefanBartl/pickers.nvim",
      dependencies = { "StefanBartl/lib.nvim", engine_plugin.repo },
      config = function()
        require("pickers").setup(picker_opts)
      end,
    },
  }
end

return M
