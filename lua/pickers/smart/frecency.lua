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
--- on-disk *shape* changed with the extraction — a flat `path -> { count,
--- last }` map became `lib.nvim.cache.disk`'s `{ saved_at, data }` envelope —
--- so a store written before it is **adopted on first use** rather than
--- silently starting over. `migrate_legacy` reads the old shape once, seeds
--- the store with it and writes it back in the new one; from then on the file
--- is ordinary and the migration path never runs again, because the shape it
--- looks for is no longer there.

local M = {}

---Directories whose legacy store has already been examined this session, so
---the file is read once rather than on every `record`/`score` call.
---@internal
---@type table<string, true>
local migrated = {}

---Adopt a store written before the heuristic moved to lib.nvim.
---
---The pre-extraction file was a flat `path -> { count, last }` map at exactly
---this path; the current one wraps that in `cache.disk`'s `{ saved_at, data }`
---envelope. Distinguishing them is therefore a property of the decoded table
---rather than a version field: the old shape has neither key, and any table
---carrying one is already the new shape and left alone.
---
---Seeding refuses a store that already holds anything, so this cannot
---overwrite real history even if the old file somehow reappears.
---@internal
---@param dir string
---@param handle Lib.Frecency.Store
local function migrate_legacy(dir, handle)
  if migrated[dir] then return end
  migrated[dir] = true

  local file = io.open(dir .. "/frecency.json", "r")
  if not file then return end
  local content = file:read("*a")
  file:close()
  if not content or content == "" then return end

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then return end
  if decoded.data ~= nil or decoded.saved_at ~= nil then return end

  -- Written back immediately: the new shape lands at the same path, so the
  -- old one is gone and this branch cannot be reached again.
  if handle:seed(decoded) then handle:flush() end
end

---The one store this plugin uses. `autoflush = false` because `M.patch()`
---registers its own `VimLeavePre` in this plugin's autocmd group — letting
---lib.nvim add a second one would flush twice and put half of this feature's
---autocmds under a group that has nothing to do with pickers.
---@internal
---@param cfg Pickers.Config
---@return Lib.Frecency.Store
local function store(cfg)
  local frecency = cfg.smart.frecency or {}
  local dir = (type(frecency.dir) == "string" and frecency.dir ~= "") and frecency.dir
    or (vim.fn.stdpath("data") .. "/pickers.nvim")

  local handle = require("lib.nvim.frecency").store({
    namespace = "frecency",
    dir = dir,
    autoflush = false,
  })

  migrate_legacy(dir, handle)
  return handle
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
  migrated = {}
  require("lib.nvim.frecency")._reset_handles()
end

return M
