---@module 'pickers.smart.score'
---@brief Shared scorer + merger for the smart action.
---@description
--- Pure, engine-independent, side-effect free (so it is unit-tested directly in
--- docs/TESTS/pickers_spec.lua). Both file candidates and grep candidates are
--- scored on ONE comparable scale, then merged and sorted into a single ranked
--- list — this is what makes the smart action interleave both sources by
--- relevance instead of showing one block then the other.
---
--- The scoring is deliberately simple and transparent (a substring/subsequence
--- matcher with a few boundary/prefix/exact bonuses) rather than a full fuzzy
--- engine: the engines still own the final in-picker feel, and the numbers here
--- only need to produce a sensible *relative* order between a filename hit and a
--- content hit. Tune the balance via `smart.weights` (see Pickers.SmartConfig).

local M = {}

-- Score a single match component. Case-insensitive. Higher = better; nil = no
-- match at all. Prefers earlier positions, word-boundary/prefix starts, exact
-- equality, and longer contiguous matches; falls back to a weak subsequence
-- score so fuzzy-ish typing still ranks (below any real substring hit).
---@param hay    string
---@param needle string
---@return number|nil
function M.match(hay, needle)
  if needle == "" then return 0 end
  hay = hay:lower()
  needle = needle:lower()

  local start = hay:find(needle, 1, true) -- plain substring (needle may be regex-y; treat literally here)
  if start then
    local s = 100
    s = s - math.min(start - 1, 60) -- earlier is better
    if start == 1 then s = s + 30 end -- prefix
    local prev = start > 1 and hay:sub(start - 1, start - 1) or ""
    if prev == "" or prev:match("[^%w]") then s = s + 15 end -- word-boundary start
    if #needle == #hay then s = s + 40 end -- exact
    s = s + math.min(#needle, 20) -- longer contiguous match
    return s
  end

  -- Subsequence fallback (all needle chars appear in order): weak, always ranks
  -- below a real substring hit.
  local hi, last, gaps = 1, 0, 0
  for i = 1, #needle do
    local c = needle:sub(i, i)
    -- escape magic chars for plain find
    local f = hay:find(c, hi, true)
    if not f then return nil end
    if last > 0 then gaps = gaps + (f - last - 1) end
    last = f
    hi = f + 1
  end
  return math.max(1, 40 - math.min(gaps, 39))
end

---Basename of a slash/backslash path.
---@param path string
---@return string
local function basename(path)
  return path:match("[^/\\]+$") or path
end

---Score a file candidate: filename match dominates, full-path match is a minor
---tiebreaker. Returns nil when neither the name nor the path matches.
---@param query string
---@param path  string   Path relative to its root
---@param w     Pickers.Smart.Weights
---@return number|nil
function M.score_file(query, path, w)
  local sn = M.match(basename(path), query)
  local sp = M.match(path, query)
  if not sn and not sp then return nil end
  return (sn or 0) * w.filename + (sp or 0) * 0.3
end

---Score a grep candidate: content match dominates, with a small filename bonus.
---rg already guarantees the line matched, so a nil content score (possible when
---the query is a regex the literal matcher can't see) falls back to a small base.
---@param query string
---@param path  string   Path relative to its root
---@param text  string   Matched line text
---@param w     Pickers.Smart.Weights
---@return number
function M.score_grep(query, path, text, w)
  local st = M.match(text, query) or 1
  local sn = M.match(basename(path), query) or 0
  return st * w.content + sn * 0.3
end

---Merge file + grep candidates into ONE ranked list.
---
--- A file that ALSO has grep hits gets `weights.both` added (strong relevance:
--- matched by name and contains matches), which floats it above lone hits of
--- either kind — the grep rows for that file still appear on their own merits.
---@param query string
---@param files Pickers.Smart.File[]
---@param greps Pickers.Smart.Grep[]
---@param w     Pickers.Smart.Weights
---@param limit integer|nil
---@return Pickers.Smart.Item[]
function M.rank(query, files, greps, w, limit)
  local items = {} ---@type Pickers.Smart.Item[]

  local grepped = {} ---@type table<string, boolean>
  for _, g in ipairs(greps) do
    grepped[g.abspath] = true
  end

  for _, f in ipairs(files) do
    local s = M.score_file(query, f.path, w)
    if s then
      if grepped[f.abspath] then s = s + w.both end
      items[#items + 1] = {
        kind = "file",
        path = f.path,
        root = f.root,
        abspath = f.abspath,
        score = s,
        display = f.path,
      }
    end
  end

  for _, g in ipairs(greps) do
    local s = M.score_grep(query, g.path, g.text, w)
    items[#items + 1] = {
      kind = "grep",
      path = g.path,
      root = g.root,
      abspath = g.abspath,
      lnum = g.lnum,
      col = g.col,
      text = g.text,
      score = s,
      display = string.format("%s:%d: %s", g.path, g.lnum, (g.text or ""):gsub("^%s+", "")),
    }
  end

  table.sort(items, function(a, b)
    if a.score == b.score then return a.display < b.display end
    return a.score > b.score
  end)

  if limit and #items > limit then
    local trimmed = {}
    for i = 1, limit do
      trimmed[i] = items[i]
    end
    items = trimmed
  end

  for i, it in ipairs(items) do
    it._rank = i
  end
  return items
end

return M
