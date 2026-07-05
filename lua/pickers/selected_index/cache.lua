---@module 'pickers.selected_index.cache'
---@brief Incremental, weak-keyed cache for counting non-nil results entries.

local M = {}

-- Weak-key cache for automatic GC when the results table is collected.
M._cache = setmetatable({}, { __mode = "k" })

---@type integer
local MAX_CACHE_ENTRIES = 100

---Cleanup old cache entries when the limit is exceeded.
---@return nil
local function cleanup_if_needed()
  local count = 0
  for _ in pairs(M._cache) do
    count = count + 1
  end

  if count > MAX_CACHE_ENTRIES then
    local to_clear = {}
    local i = 0
    for k in pairs(M._cache) do
      if i > MAX_CACHE_ENTRIES / 2 then break end
      to_clear[#to_clear + 1] = k
      i = i + 1
    end

    for _, k in ipairs(to_clear) do
      M._cache[k] = nil
    end
  end
end

---Reset the cache entry for a given results table (or all entries).
---@param tbl table|nil
---@return nil
function M.reset(tbl)
  if not tbl then
    M._cache = setmetatable({}, { __mode = "k" })
    return
  end
  M._cache[tbl] = nil
end

---Get the non-nil count up to `upto` with incremental caching.
---@param results table
---@param upto integer 1-based inclusive index
---@return integer count
---@return boolean from_cache
function M.count_upto(results, upto)
  if type(results) ~= "table" then return 0, false end

  local entry = M._cache[results]
  local results_len = #results

  if not entry then
    cleanup_if_needed()
    entry = {
      cached_upto = 0,
      cached_count = 0,
      len_snapshot = results_len,
    }
    M._cache[results] = entry
  else
    if entry.len_snapshot ~= results_len then
      entry.len_snapshot = results_len
      if results_len < entry.cached_upto then
        entry.cached_upto = 0
        entry.cached_count = 0
      end
    end
  end

  local target = math.min(upto, results_len)
  if target <= 0 then return 0, false end

  if entry.cached_upto >= target then return entry.cached_count, true end

  local start_idx = entry.cached_upto + 1
  local count = entry.cached_count

  for i = start_idx, target do
    if results[i] ~= nil then count = count + 1 end
  end

  entry.cached_upto = target
  entry.cached_count = count

  return count, false
end

return M
