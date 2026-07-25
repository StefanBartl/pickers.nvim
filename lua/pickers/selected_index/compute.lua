---@module 'pickers.selected_index.compute'
---@brief Last-resort fallback index computation, used only when neither
---`picker:get_index(row)` (telescope's own authoritative row<->index
---mapping, the primary path -- see `pickers.selected_index` update logic)
---nor `entry.index` is available. In practice this means a non-standard
---picker object (missing `get_index`) with an entry_maker that happens to
---set `.index` some other way; real telescope Pickers always have
---`get_index`, so this module is defensive/legacy rather than load-bearing.

local M = {}

local cache = require("pickers.selected_index.cache")

---Compute the 1-based index for the selected entry from the picker's results.
---@param picker table|nil telescope picker instance (may be nil early in the picker lifecycle)
---@param row number zero-based row in the results buffer
---@return number index best-effort 1-based index
function M.compute_index_from_picker(picker, row)
  if picker == nil then return row + 1 end

  local results = nil
  if type(picker.results) == "table" and #picker.results > 0 then
    results = picker.results
  elseif
    picker.manager
    and type(picker.manager.results) == "table"
    and #picker.manager.results > 0
  then
    results = picker.manager.results
  elseif picker._results and type(picker._results) == "table" and #picker._results > 0 then
    results = picker._results
  end

  if not results then return row + 1 end

  local upto = math.min(row + 1, #results)

  local count = cache.count_upto(results, upto)
  if not count or type(count) ~= "number" then
    local c = 0
    for i = 1, upto do
      if results[i] ~= nil then c = c + 1 end
    end
    if c == 0 then return row + 1 end
    return c
  end

  if count == 0 then return row + 1 end
  return count
end

return M
