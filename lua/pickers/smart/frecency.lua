---@module 'pickers.smart.frecency'
---@brief Optional recency/frequency signal for the smart action's ranking.
---@description
--- Opt-in (`smart.frecency.enabled`, off by default). Tracks how often and
--- how recently a file was opened, via a `BufReadPost` autocmd, so that a
--- file you edit often outranks an equal-scoring stranger in the `smart`
--- action's merged results — see `pickers.smart.score.rank`'s `frecency`
--- param.
---
--- **The heuristic itself lives in `lib.nvim.frecency` now.** It used to live
--- here, and this file was its only home: bucketed recency weights, a
--- log-dampened visit count, a JSON store loaded lazily and flushed on exit.
--- `gopath.nvim` wants the same signal for a different kind of candidate, and
--- the choice was between a second copy of those buckets in a second
--- repository or one implementation both plugins read. Two copies of a
--- ranking heuristic do not stay equal — they drift by one bucket boundary
--- and then rank the same file differently in two windows of the same editor.
---
--- What stays here is what is actually about *this* plugin: the config shape
--- (`smart.frecency.{enabled,weight,dir}`), the `BufReadPost` definition of
--- "a visit" — a real, readable file loaded into an ordinary buffer, which is
--- a picker's notion of use and nobody else's — and the enabled-gate, so a
--- disabled `lookup` returns an empty table without ever touching disk.
---
--- Storage is unchanged in place: `stdpath("data")/pickers.nvim/frecency.json`
--- by default, `smart.frecency.dir` still overriding the directory. The
--- on-disk *shape* is now `lib.nvim.cache.disk`'s (`{ saved_at, data }`), so
--- a store written before this change reads back empty and starts over. That
--- is deliberate rather than migrated: the feature is off by default, so a
--- store only exists where someone turned it on, and the cost of starting
--- over is a few days of visits rather than anything that cannot be re-earned.

local M = {}

---The one store this plugin uses. `autoflush = false` because `M.patch()`
---registers its own `VimLeavePre` in this plugin's autocmd group — letting
---lib.nvim add a second one would flush twice and put half of this feature's
---autocmds under a group that has nothing to do with pickers.
---@internal
---@param cfg Pickers.Config
---@return Lib.Frecency.Store
local function store(cfg)
  local frecency = cfg.smart.frecency or {}
  return require("lib.nvim.frecency").store({
    namespace = "frecency",
    dir = (type(frecency.dir) == "string" and frecency.dir ~= "") and frecency.dir
      or (vim.fn.stdpath("data") .. "/pickers.nvim"),
    autoflush = false,
  })
end

---Record a visit to `abspath`. Marks the in-memory store dirty; call
---`M.flush()` (or wait for the `VimLeavePre` autocmd from `M.patch()`) to
---persist it.
---@param cfg     Pickers.Config
---@param abspath string
function M.record(cfg, abspath)
  store(cfg):record(abspath)
end

---Frecency score for `abspath` -- combines visit frequency (log-dampened, so
---one path opened hundreds of times doesn't permanently dominate) and how
---recently it was last visited. 0 for a path never recorded.
---@param cfg     Pickers.Config
---@param abspath string
---@return number
function M.score(cfg, abspath)
  return store(cfg):score(abspath)
end

---Write any pending visits to disk. No-op when nothing changed since the
---last save.
---@param cfg Pickers.Config
function M.flush(cfg)
  store(cfg):flush()
end

---Register the `BufReadPost` visit-recording hook + a `VimLeavePre` flush.
---No-op when `smart.frecency.enabled` is false (the default).
---@param cfg Pickers.Config
function M.patch(cfg)
  if not (cfg.smart.frecency and cfg.smart.frecency.enabled) then return end

  ---@internal
  local function on_buf_read()
    local bufnr = vim.api.nvim_get_current_buf()
    if vim.bo[bufnr].buftype ~= "" then return end
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" or vim.fn.filereadable(name) == 0 then return end
    M.record(cfg, vim.fs.normalize(name))
  end

  ---@internal
  local function on_leave()
    M.flush(cfg)
  end

  local ok, lib_autocmd = pcall(require, "lib.nvim.bindings.autocmd")
  if ok and type(lib_autocmd) == "table" and type(lib_autocmd.create) == "function" then
    lib_autocmd.create("BufReadPost", on_buf_read, {
      group = "pickers.nvim",
      desc = "pickers.nvim: record smart-action frecency visit",
    })
    lib_autocmd.create("VimLeavePre", on_leave, {
      group = "pickers.nvim",
      desc = "pickers.nvim: flush smart-action frecency store",
    })
  else
    -- lib-docs: fallback
    vim.api.nvim_create_autocmd("BufReadPost", { callback = on_buf_read })
    -- lib-docs: fallback
    vim.api.nvim_create_autocmd("VimLeavePre", { callback = on_leave })
  end
end

---Build the `abspath -> weighted bonus` lookup table `score.rank` expects,
---for exactly the candidate paths in this query (no point scoring paths
---that aren't even in the result set).
---@param cfg     Pickers.Config
---@param abspaths string[]
---@return table<string, number>
function M.lookup(cfg, abspaths)
  -- The gate stays here rather than in the store: disabled means "do not
  -- read the file at all", and a store cannot know what a caller's config
  -- switch means.
  if not (cfg.smart.frecency and cfg.smart.frecency.enabled) then return {} end
  -- The weight is passed per call, not baked into the handle: a store handle
  -- lives for the session and `smart.frecency.weight` can change under it.
  return store(cfg):lookup(abspaths, cfg.smart.frecency.weight or 1.0)
end

---Test-only: drop the in-memory cache so the next call re-reads from disk
---(or starts fresh). Does not touch anything on disk itself.
function M._reset_cache()
  require("lib.nvim.frecency")._reset_handles()
end

return M
