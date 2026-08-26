---@module 'pickers.bindings.keymaps'
---@brief The built-in normal-mode keymaps (registered when `keymaps.enable`).
---@description
--- All but two of these run the same thing with different arguments, so they
--- are a table rather than fourteen near-identical blocks: a new picker route
--- needs one row, not a copy of the surrounding boilerplate.
---
--- Declared through `lib.nvim.bindings.keymap`'s registry. Each is an
--- individually overridable config value as before -- most are `nil` by
--- default, so setting one is what claims a key -- and `false` drops one. What
--- is new is that a wrong *name* is reported instead of silently binding
--- nothing.
---
--- which-key needs no registration for these: it reads the mappings itself and
--- labels each from its own `desc`. `bindings/whichkey.lua` used to re-register
--- those same descriptions, which only gave one string two places to drift
--- apart in.

local keymap = require("lib.nvim.bindings.keymap")

local M = {}

---@internal
--- Run one `:Pickers` route.
---@param fargs string[]
---@return fun(): nil
local function route(fargs)
  return function()
    require("pickers.command").handle({ fargs = fargs })
  end
end

--- The routes, in the order docs and the health report should read them.
---@type { name: string, fargs: string[], desc: string }[]
local ROUTES = {
  { name = "explorer", fargs = { "explorer" }, desc = "File explorer / browser (active engine)" },
  {
    name = "folder_files",
    fargs = { "folder", "files" },
    desc = "Find files in interactively picked folder",
  },
  { name = "config_files", fargs = { "config", "files" }, desc = "Find files in nvim config" },
  { name = "config_grep", fargs = { "config", "grep" }, desc = "Grep in nvim config" },
  { name = "cwd_grep", fargs = { "cwd", "grep" }, desc = "Live grep in CWD" },
  { name = "cwd_files", fargs = { "cwd", "files" }, desc = "Find files in CWD" },
  { name = "repos_files", fargs = { "repos", "files" }, desc = "Pick a repo, then find files" },
  { name = "repos_grep", fargs = { "repos", "grep" }, desc = "Pick a repo, then live grep" },
  {
    name = "system_files",
    fargs = { "system", "files" },
    desc = "Systemwide fd search (prompts for query)",
  },
  { name = "cwd_smart", fargs = { "cwd", "smart" }, desc = "Smart (grep + find) in CWD" },
  {
    name = "config_smart",
    fargs = { "config", "smart" },
    desc = "Smart (grep + find) in nvim config",
  },
  {
    name = "folder_smart",
    fargs = { "folder", "smart" },
    desc = "Smart (grep + find) in interactively picked folder",
  },
  {
    name = "cwd_find_all",
    fargs = { "cwd", "files", "all" },
    desc = "Find all files in CWD (forces hidden+no_ignore+follow)",
  },
}

--- Declare and bind the built-in keymaps.
---@param km Pickers.Keymaps
---@return Lib.Keymap.Registered[]
function M.register(km)
  ---@type table<string, Lib.Keymap.Action>
  local actions = {
    -- The one route that is not a plain argument list: a count is the depth.
    dir_pick = {
      rhs = function()
        -- `2<lhs>` is "two levels up", the same thing `:Pickers dir 2` has
        -- always meant. The concept existed on the command and nothing was
        -- passing it from the keymap.
        --
        -- Raw `vim.v.count`, not `count1`: 0 has to stay distinguishable,
        -- since no count opens the interactive picker while `:Pickers dir 0`
        -- is a real depth (the cwd itself).
        local n = vim.v.count
        require("pickers.command").handle({
          fargs = n > 0 and { "dir", tostring(n) } or { "dir" },
        })
      end,
      desc = "Dir: navigate (alias / depth / path)",
    },
  }

  ---@type string[]
  local order = { "dir_pick" }

  for _, r in ipairs(ROUTES) do
    -- `explorer` goes through the builtins runner rather than the command
    -- router, which is the only reason it is not a plain route.
    if r.name == "explorer" then
      actions[r.name] = {
        rhs = function()
          require("pickers.builtins").run("explorer")
        end,
        desc = r.desc,
      }
    else
      actions[r.name] = { rhs = route(r.fargs), desc = r.desc }
    end
    order[#order + 1] = r.name
  end

  return keymap.register("pickers", { order = order, actions = actions }, km)
end

return M
