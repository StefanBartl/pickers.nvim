---@module 'pickers.preview_modes'
---@brief Several switchable previews per `pick_item` entry (engine-agnostic state).
---@description
--- A `Pickers.Item` may carry `previews = { <mode> = Pickers.PreviewSpec, ... }`.
--- Every engine then shows the preview of the current mode and lets the user
--- cycle through the modes with a key (`opts.preview_toggle_key`, default
--- `<M-t>`). This module holds what is the same for all three engines: which
--- modes exist, which one is current, how an item resolves to a spec and how
--- the key is spelled for fzf-lua and snacks.
---
--- Callers that pass no `previews` anywhere never reach this module's state:
--- `M.new` answers nil and the engines keep their file-only behaviour.

local M = {}

M.DEFAULT_KEY = "<M-t>"

---@class Pickers.PreviewSpec
---@field file string?     Absolute path shown with the engine's file previewer.
---@field line integer?    1-based line to put in view when `file` is set.
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

---Title for the preview window: the current mode, the other ones in brackets-free form.
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

---`<M-t>` / `<A-t>` / `<C-t>` / `<S-Tab>` spelled as snacks wants it (`<a-t>`).
---@param key string
---@return string
function M.snacks_key(key)
  return (key:gsub("^<[Mm]%-", "<a-"):gsub("^<[Cc]%-", "<c-"):lower())
end

---The same key spelled for fzf's `--bind` (`alt-t`, `ctrl-t`).
---@param key string
---@return string
function M.fzf_key(key)
  local k = key:lower()
  local mod, rest = k:match("^<([mac])%-(.+)>$")
  if mod then return ((mod == "c") and "ctrl-" or "alt-") .. rest end
  return (k:gsub("^<(.+)>$", "%1"))
end

---Preview text for engines that can only show a string (fzf-lua): the lines,
---or the file's content.
---@param spec Pickers.PreviewSpec|nil
---@return string
function M.as_text(spec)
  if not spec then return "" end
  if spec.lines then return table.concat(spec.lines, "\n") end
  if spec.file then
    local ok, lines = pcall(vim.fn.readfile, spec.file)
    if not ok then return "could not read " .. spec.file end
    return table.concat(lines, "\n")
  end
  return ""
end

return M
