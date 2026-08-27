---@module 'pickers.smart.frecency'
---@brief Optional recency/frequency signal for the smart action's ranking.
---@description
--- Opt-in (`smart.frecency.enabled`, off by default). Tracks how often and
--- how recently a file was opened, via a `BufReadPost` autocmd, so that a
--- file you edit often outranks an equal-scoring stranger in the `smart`
--- action's merged results — see `pickers.smart.score.rank`'s `frecency`
--- param.
---
--- Persisted as JSON, one entry per absolute path (`{ count, last }`), under
--- `stdpath("data")/pickers.nvim/frecency.json` by default (override with
--- `smart.frecency.dir`, same convention as `pickers.history`'s `dir`).
--- Loaded lazily on first use, written back on `VimLeavePre` and whenever
--- `M.flush()` is called explicitly (the on-disk copy is a best-effort
--- snapshot, not written on every single visit).
---
--- `M.score()` never touches disk after the initial load -- pure in-memory
--- table lookup -- so it is cheap to call once per candidate path while
--- ranking a `smart` query.

local M = {}

---@type table<string, { count: integer, last: integer }>|nil
local store = nil
local dirty = false

---@internal
---@param cfg Pickers.Config
---@return string
local function dir(cfg)
  local d = (cfg.smart.frecency and cfg.smart.frecency.dir and cfg.smart.frecency.dir ~= "")
      and cfg.smart.frecency.dir
    or (vim.fn.stdpath("data") .. "/pickers.nvim")
  d = vim.fs.normalize(d)
  vim.fn.mkdir(d, "p")
  return d
end

---@internal
---@param cfg Pickers.Config
---@return string
local function file_path(cfg)
  return dir(cfg) .. "/frecency.json"
end

---@internal
---@param cfg Pickers.Config
local function load(cfg)
  if store then return end
  store = {}
  local f = io.open(file_path(cfg), "r")
  if not f then return end
  local content = f:read("*a")
  f:close()
  if not content or content == "" then return end
  local ok, decoded = pcall(vim.json.decode, content)
  if ok and type(decoded) == "table" then store = decoded end
end

---@internal
---@param cfg Pickers.Config
local function save(cfg)
  if not store then return end
  local ok, encoded = pcall(vim.json.encode, store)
  if not ok then return end
  local f = io.open(file_path(cfg), "w")
  if not f then return end
  f:write(encoded)
  f:close()
  dirty = false
end

--- Bucketed recency weight (the same shape of heuristic telescope-frecency /
--- browser "frecency" scores use): a visit from the last hour counts far
--- more than one from a month ago.
---@internal
---@param age_seconds number
---@return number
local function recency_weight(age_seconds)
  if age_seconds < 3600 then
    return 100 -- < 1h
  elseif age_seconds < 86400 then
    return 80 -- < 1d
  elseif age_seconds < 604800 then
    return 60 -- < 1w
  elseif age_seconds < 2592000 then
    return 40 -- < 30d
  else
    return 20
  end
end

---Record a visit to `abspath`. Marks the in-memory store dirty; call
---`M.flush()` (or wait for the `VimLeavePre` autocmd from `M.patch()`) to
---persist it.
---@param cfg     Pickers.Config
---@param abspath string
function M.record(cfg, abspath)
  if not abspath or abspath == "" then return end
  load(cfg)
  ---@cast store table<string, { count: integer, last: integer }>
  local entry = store[abspath] or { count = 0, last = 0 }
  entry.count = entry.count + 1
  entry.last = os.time()
  store[abspath] = entry
  dirty = true
end

---Frecency score for `abspath` -- combines visit frequency (log-dampened, so
---one path opened hundreds of times doesn't permanently dominate) and how
---recently it was last visited. 0 for a path never recorded.
---@param cfg     Pickers.Config
---@param abspath string
---@return number
function M.score(cfg, abspath)
  load(cfg)
  ---@cast store table<string, { count: integer, last: integer }>
  local entry = store[abspath]
  if not entry then return 0 end
  local age = os.time() - (entry.last or 0)
  return math.log((entry.count or 0) + 1) * recency_weight(age)
end

---Write any pending visits to disk. No-op when nothing changed since the
---last save.
---@param cfg Pickers.Config
function M.flush(cfg)
  if dirty then save(cfg) end
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
  local out = {}
  if not (cfg.smart.frecency and cfg.smart.frecency.enabled) then return out end
  local weight = cfg.smart.frecency.weight or 1.0
  for _, p in ipairs(abspaths) do
    local s = M.score(cfg, p)
    if s > 0 then out[p] = s * weight end
  end
  return out
end

---Test-only: drop the in-memory cache so the next call re-reads from disk
---(or starts fresh). Does not touch anything on disk itself.
function M._reset_cache()
  store = nil
  dirty = false
end

return M
