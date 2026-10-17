---@module 'pickers.preview_modes'
---@brief Several switchable previews per `pick_item` entry (engine-agnostic state).
---@description
--- A `Pickers.Item` may carry `previews = { <mode> = Pickers.PreviewSpec, ... }`.
--- Every engine then shows the preview of the current mode and lets the user
--- cycle through the modes with a key (`opts.preview_toggle_key`, default
--- `<M-c>`). This module holds what is the same for all three engines: which
--- modes exist, which one is current, how an item resolves to a spec and how
--- the key is spelled for fzf-lua and snacks.
---
--- The default key is `<M-c>` ("cycle"), not `<M-t>`: `<M-t>` is the
--- in-picker key of `copy_project_root`, and in a list with previews the
--- preview switch would shadow it.
---
--- Callers that pass no `previews` anywhere never reach this module's state:
--- `M.new` answers nil and the engines keep their file-only behaviour.

local M = {}

M.DEFAULT_KEY = "<M-c>"

---Lines fzf-lua's text preview puts above the spec's content (the mode line).
M.FZF_HEADER_LINES = 1

---@class Pickers.PreviewSpec
---@field file string?     Absolute path shown with the engine's file previewer.
---@field line integer?    1-based line to put in view (fzf-lua also honours it for `lines`).
---@field lines string[]?  Text shown instead of a file.
---@field ft string?       Filetype used to highlight `lines`.

---@class Pickers.PreviewModes
---@field modes string[]
---@field idx integer
---@field key string
local State = {}
State.__index = State

---@return string
function State:current()
  return self.modes[self.idx]
end

---Switch to the next mode (wraps around).
---@return string mode
function State:toggle()
  self.idx = self.idx % #self.modes + 1
  return self.modes[self.idx]
end

---Title for the preview window: all modes, the current one in brackets (`[normal] table`).
---@return string
function State:label()
  local out = {}
  for i, name in ipairs(self.modes) do
    out[i] = (i == self.idx) and ("[" .. name .. "]") or name
  end
  return table.concat(out, " ")
end

---The preview of `item` in the current mode, or nil when it has none there.
---A plain `file` (and `line`) on the item stands in for a missing "normal" mode.
---@param item string|table
---@return Pickers.PreviewSpec|nil
function State:spec(item)
  if type(item) ~= "table" then return nil end
  local mode = self:current()
  local spec = item.previews and item.previews[mode]
  if spec then return spec end
  if mode == "normal" and item.file then return { file = item.file, line = item.line } end
  return nil
end

---The line to scroll to for `item` in every mode, in mode order (0 = top).
---fzf-lua's preview is fzf's own text window: fzf can only scroll it through
---`--preview-window +{N}`, a field of the item's line, so every mode's line
---is written into the line as a hidden field (see `State:fzf_scroll`).
---@param item string|table
---@return integer[]
function State:lines_per_mode(item)
  local out = {}
  local saved = self.idx
  for i = 1, #self.modes do
    self.idx = i
    local spec = self:spec(item)
    local line = spec and tonumber(spec.line)
    out[i] = (line and line >= 1) and math.floor(line) or 0
  end
  self.idx = saved
  return out
end

---fzf `--preview-window` scroll offsets for the modes. The mode lines sit in
---the fields `first_field`, `first_field + 1`, ... of every fzf line; the
---mode line on top of the text preview is a fixed header (`~1`), hence the
---`+1`, and `-/2` centres the target line.
---@param first_field integer
---@return { initial: string, cycle: string }
---  `initial`: the offset for the first mode (fzf-lua's `preview_offset`);
---  `cycle`: the argument of `change-preview-window(...)` that, pressed together
---  with the mode switch, steps to the next mode's field and wraps around.
function State:fzf_scroll(first_field)
  local function offset(i)
    return string.format("+{%d}+%d-/2", first_field + i - 1, M.FZF_HEADER_LINES)
  end
  local cycle = {}
  for i = 2, #self.modes do
    cycle[#cycle + 1] = offset(i)
  end
  cycle[#cycle + 1] = offset(1)
  return {
    initial = offset(1) .. ":~" .. M.FZF_HEADER_LINES,
    cycle = table.concat(cycle, "|"),
  }
end

---@param items (string|table)[]
---@return boolean
function M.wanted(items)
  for _, it in ipairs(items or {}) do
    if type(it) == "table" and type(it.previews) == "table" and next(it.previews) then
      return true
    end
  end
  return false
end

---The state for one `pick_item` call, or nil when no item has `previews`.
---`opts.preview_modes` fixes the order; otherwise the modes found on the items
---are used, "normal" first and the rest alphabetically.
---@param opts { items: (string|table)[], preview_modes?: string[], preview_toggle_key?: string }
---@return Pickers.PreviewModes|nil
function M.new(opts)
  if not M.wanted(opts.items) then return nil end
  local modes = opts.preview_modes
  if type(modes) ~= "table" or #modes == 0 then
    local seen = {}
    for _, it in ipairs(opts.items) do
      if type(it) == "table" and type(it.previews) == "table" then
        for name in pairs(it.previews) do
          seen[name] = true
        end
      end
    end
    modes = {}
    for name in pairs(seen) do
      modes[#modes + 1] = name
    end
    table.sort(modes, function(a, b)
      if a == "normal" then return b ~= "normal" end
      if b == "normal" then return false end
      return a < b
    end)
  end
  return setmetatable({
    modes = vim.deepcopy(modes),
    idx = 1,
    key = opts.preview_toggle_key or M.DEFAULT_KEY,
  }, State)
end

---`<M-c>` / `<A-c>` / `<C-t>` / `<S-Tab>` spelled as snacks wants it (`<a-c>`).
---@param key string
---@return string
function M.snacks_key(key)
  return (key:gsub("^<[Mm]%-", "<a-"):gsub("^<[Cc]%-", "<c-"):lower())
end

---The same key spelled for fzf's `--bind` (`alt-t`, `ctrl-t`).
---@param key string
---@return string
function M.fzf_key(key)
  local NAMES = { cr = "enter", s = "shift", bs = "bspace", ["s-tab"] = "shift-tab" }
  local function name(n)
    return NAMES[n] or n
  end
  local k = key:lower()
  local mod, rest = k:match("^<([mac])%-(.+)>$")
  if mod then return ((mod == "c") and "ctrl-" or "alt-") .. name(rest) end
  return name((k:gsub("^<(.+)>$", "%1")))
end

---Preview text for engines that can only show a string (fzf-lua): the lines,
---or the file's content.
---@param spec Pickers.PreviewSpec|nil
---@return string
function M.as_text(spec)
  if not spec then return "" end
  if spec.lines then
    local out = {}
    for i, l in ipairs(spec.lines) do
      out[i] = tostring(l)
    end
    return table.concat(out, "\n")
  end
  if spec.file then
    local ok, lines = pcall(vim.fn.readfile, spec.file)
    if not ok then return "could not read " .. spec.file end
    return table.concat(lines, "\n")
  end
  return ""
end

return M
