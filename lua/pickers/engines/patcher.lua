---@module 'pickers.engines.patcher'
---@brief One patch per engine: every feature contributes, the engine's own
---`setup()` is called once.
---@description
--- pickers.nvim puts several things onto an engine's GLOBAL config so they
--- reach every picker it opens, native ones included: the in-picker keys and
--- entry actions, picker history, `find.exclude`, the `display.*` switches,
--- the PDF text preview. Each used to call the engine's `setup()` itself, one
--- after the other -- up to five `telescope.setup()` and four `fzf-lua.setup()`
--- calls at the moment the engine loaded, every one reading and re-folding
--- what the previous one had just written.
---
--- Now a feature only *contributes*. Its module exposes
--- `contribute(cfg) -> { [engine] = fun(current): table|nil }` -- cheap,
--- closures only, nothing engine-related is required while it runs. When an
--- engine has loaded (`pickers.engines.when_loaded`), this module
---
---   1. takes ONE snapshot of the engine's current configuration,
---   2. asks every contribution for its part, given that snapshot,
---   3. deep-merges the parts in registration order (later wins),
---   4. applies the result with a single call.
---
--- A contribution is responsible for folding the HOST'S own configuration in
--- (read from `current`), so the host still wins where it should -- see each
--- module for its own rule (keys/actions: host binding wins; display switches:
--- the explicit switch wins). Contributions touch disjoint keys of the engine's
--- config, or list the host's existing values first, so the merge is
--- order-independent except where a module says it deliberately overrides.
---
---   engine key   snapshot (`current`)                     applied with
---   telescope    { defaults, pickers }                    `telescope.setup(spec)`
---   fzf-lua      { setup_opts, globals }                  `fzf-lua.setup(spec, true)`
---   snacks       { picker }  (`Snacks.config.picker`)     deep-merged over that table
---
--- A contribution that throws is reported and skipped; the others still land.
--- Installing again (a second `pickers.setup()`) replaces what is waiting for
--- an engine that has not loaded yet, and re-patches one that has -- every
--- contribution is idempotent.

local M = {}

---Contributor modules, in merge order. A later contributor wins on a key two
---of them touch: `display_native` comes after `entry_actions.patch` so an
---explicit `display.*` switch overrides a host value that one folded in.
---@type string[]
M.CONTRIBUTORS = {
  "pickers.keys",
  "pickers.entry_actions.patch",
  "pickers.history",
  "pickers.find_native",
  "pickers.display_native",
  "pickers.integrations.pdf_text",
}

---Snapshot of an engine's current configuration. `{}` when it cannot be read,
---so a contribution just sees "nothing configured yet".
---@type table<string, fun(): table>
local SNAPSHOT = {
  telescope = function()
    local ok, config = pcall(require, "telescope.config")
    if not ok then return {} end
    return { defaults = config.values or {}, pickers = config.pickers or {} }
  end,
  ["fzf-lua"] = function()
    local ok, config = pcall(require, "fzf-lua.config")
    if not ok then return {} end
    return { setup_opts = config.setup_opts or {}, globals = config.globals or {} }
  end,
  snacks = function()
    local ok, snacks = pcall(require, "snacks")
    if not ok then return {} end
    return { picker = snacks.config.picker or {} }
  end,
}

---Apply a merged spec to an engine.
---@type table<string, fun(spec: table)>
local APPLY = {
  telescope = function(spec)
    require("telescope").setup(spec)
  end,
  ["fzf-lua"] = function(spec)
    -- `true`: keep fzf-lua's earlier options; it otherwise resets to defaults.
    require("fzf-lua").setup(spec, true)
  end,
  snacks = function(spec)
    -- Snacks reads `Snacks.config.picker` each time a picker opens, so this is
    -- live before or after `Snacks.setup()`.
    local snacks = require("snacks")
    snacks.config.picker = vim.tbl_deep_extend("force", snacks.config.picker or {}, spec)
  end,
}

---Contributions waiting for an engine that has not loaded yet.
---@type table<string, (fun(current: table): table|nil)[]>
local pending = {}

---@param engine string
---@param message string
local function warn(engine, message)
  local ok, notify = pcall(require, "lib.nvim.notify")
  if ok then notify.create("[pickers.engines.patcher]").warn(engine .. ": " .. message) end
end

---Collect, merge, apply -- the one call per engine.
---@param engine string
local function run(engine)
  local list = pending[engine]
  pending[engine] = nil
  if not list then return end

  local current = SNAPSHOT[engine]()
  local spec = {}
  for _, contribution in ipairs(list) do
    local ok, part = pcall(contribution, current)
    if not ok then
      warn(engine, "a contribution failed: " .. tostring(part))
    elseif type(part) == "table" and next(part) ~= nil then
      spec = vim.tbl_deep_extend("force", spec, part)
    end
  end
  if next(spec) == nil then return end

  local ok, err = pcall(APPLY[engine], spec)
  if not ok then warn(engine, "could not apply the patch: " .. tostring(err)) end
end

---Register every contribution and patch each engine once it is loaded.
---@param cfg Pickers.Config|nil
---@param only string[]|nil  restrict to these contributor modules (default: all)
function M.install(cfg, only)
  cfg = cfg or require("pickers.config").get()

  ---@type table<string, (fun(current: table): table|nil)[]>
  local per_engine = {}
  for _, name in ipairs(only or M.CONTRIBUTORS) do
    local ok, contributions = pcall(function()
      return require(name).contribute(cfg)
    end)
    if not ok then
      warn("*", name .. ".contribute failed: " .. tostring(contributions))
    else
      for engine, contribution in pairs(contributions or {}) do
        if SNAPSHOT[engine] and type(contribution) == "function" then
          per_engine[engine] = per_engine[engine] or {}
          table.insert(per_engine[engine], contribution)
        end
      end
    end
  end

  local when_loaded = require("pickers.engines.when_loaded")
  for engine, list in pairs(per_engine) do
    local waiting = pending[engine] ~= nil
    -- The latest contributions replace whatever is still queued.
    pending[engine] = list
    if package.loaded[engine] then
      -- Loaded already (also covers an engine that came in without the signal
      -- an earlier waiter was watching for): patch now. That waiter, if it ever
      -- fires, finds nothing queued and does nothing.
      run(engine)
    elseif not waiting then
      -- One waiter per engine, however often install() runs before it loads.
      when_loaded.run(engine, function()
        run(engine)
      end)
    end
  end
end

return M
