---@module 'pickers'
---@brief pickers.nvim — unified fuzzy-picker plugin.
---@description
--- Consolidates find_config, find_in_folder, dir_picker, repo_pickers,
--- grep, search_all_drives and system_find into one plugin backed by a
--- single telescope or fzf-lua engine (auto-detected from what is installed).
---
--- Minimal setup (lazy.nvim):
---   {
---     "StefanBartl/pickers.nvim",
---     lazy = false,                       -- required: load at startup
---     dependencies = { "StefanBartl/lib.nvim" },
---     config = function()
---       require("pickers").setup({
---         engine    = "auto",
---         repos_dir = vim.env.REPOS_DIR,
---       })
---     end,
---   }
---
--- Without setup() the plugin still works — default keymaps and compat
--- user-commands are registered automatically at VimEnter by plugin/pickers.lua.
---
--- Optional engine ownership + auto-install: `require("pickers").plugin_spec({
--- engine = "snacks", own_engine = true })` returns a ready lazy.nvim spec
--- list that installs AND configures the chosen engine too, called from
--- your OWN plugin list at spec-build time (not from setup()) — see
--- `pickers.plugin_spec` for why, and ROADMAP.md. Off by default; the
--- example above (bring-your-own-engine) remains the default model.

local M = {}

M.plugin_spec = require("pickers.plugin_spec").plugin_spec

---Configure and activate pickers.nvim.
---
--- This sets vim.g.pickers_nvim_setup_called so that plugin/pickers.lua
--- does not redundantly re-register bindings at VimEnter.
---
---@param opts Pickers.Config|nil
function M.setup(opts)
  -- Mark as setup so the VimEnter fallback in plugin/pickers.lua is skipped.
  vim.g.pickers_nvim_setup_called = true

  require("pickers.config").apply(opts)
  local cfg = require("pickers.config").get()
  require("pickers.bindings").setup(cfg)

  if cfg.history.enabled then require("pickers.history").patch(cfg) end
  if cfg.smart.frecency and cfg.smart.frecency.enabled then
    require("pickers.smart.frecency").patch(cfg)
  end

  -- One-time (persisted across restarts) popup on the first setup() after
  -- installing this plugin: which CLI tools it wants and why
  -- (docs/install.json). `:Lib deps show pickers.nvim` thereafter.
  -- `cfg.deps_popup = false` (set right in the setup() spec,
  -- config/DEFAULTS.lua) disables it for this plugin specifically. pcall'd:
  -- an older lib.nvim without lib.nvim.deps mustn't break setup() over an
  -- informational popup.
  if cfg.deps_popup ~= false then
    local ok_deps, deps = pcall(require, "lib.nvim.deps")
    if ok_deps then deps.show_once("pickers.nvim") end
  end
end

return M
