---@module 'pickers.preview_modes'
---@brief Several switchable previews per `pick_item` entry (engine-agnostic state).
---@description
--- A `Pickers.Item` may carry `previews = { <mode> = Pickers.PreviewSpec, ... }`.
--- Every engine then shows the preview of the current mode and lets the user
--- cycle through the modes with a key (`opts.preview_toggle_key`, default
--- `<M-c>`). This module holds what is the same for all three engines: which
--- modes exist, which one is current, how an item resolves to a spec, how the
--- spec's `line` is put in view and how the key is spelled for fzf-lua and
--- snacks. The current mode lives here only; no engine keeps a copy of it.
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

---Preview height assumed when fzf does not report one (`$FZF_PREVIEW_LINES`).
M.FZF_DEFAULT_HEIGHT = 20

---@class Pickers.PreviewSpec
---@field file string?     Absolute path shown with the engine's file previewer.
---@field line integer?    1-based line to put in view (for `file` and `lines` alike).
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

---Back to the first mode. A picker that is opened again (fzf-lua's resume
---restarts fzf with the same closures and so the same state) starts in the
---first mode, like a new one.
function State:reset()
  self.idx = 1
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

---The text of `spec` as lines: its `lines`, or the file's content.
---@param spec Pickers.PreviewSpec|nil
---@return string[]
local function text_lines(spec)
  if not spec then return {} end
  if spec.lines then
    local out = {}
    for i, l in ipairs(spec.lines) do
      out[i] = tostring(l)
    end
    return out
  end
  if spec.file then
    local ok, lines = pcall(vim.fn.readfile, spec.file)
    if not ok then return { "could not read " .. spec.file } end
    return lines
  end
  return {}
end

---Preview text for engines that can only show a string (fzf-lua): the lines,
---or the file's content.
---@param spec Pickers.PreviewSpec|nil
---@return string
function M.as_text(spec)
  return table.concat(text_lines(spec), "\n")
end

---The whole fzf-lua preview: the mode line `label`, then the spec's text with
---its `line` in view.
---
---fzf's preview is its own text window, and fzf scrolls it only through
---`--preview-window` offsets. Those are fixed per fzf process (fzf-lua's own
---resize/flex/fullscreen handling resets them), while the mode lives here in
---Lua, so a scroll offset kept in fzf drifts from the mode. The line is put in
---view by cutting the text instead: it starts so that `line` sits in the
---middle of the `height` rows under the mode line, from the top when the text
---fits or the line is near it, never so far that the end leaves rows empty.
---When the text is cut, the mode line says from which line on it is shown.
---@param label string
---@param spec Pickers.PreviewSpec|nil
---@param height integer|nil  Rows of the preview window (`$FZF_PREVIEW_LINES`).
---@return string
function M.fzf_text(label, spec, height)
  local lines = text_lines(spec)
  local line = spec and tonumber(spec.line)
  local first = 1
  if line then
    local rows = math.max(1, (tonumber(height) or M.FZF_DEFAULT_HEIGHT) - M.FZF_HEADER_LINES)
    first = math.floor(line) - math.floor((rows - 1) / 2)
    first = math.max(1, math.min(first, #lines - rows + 1))
  end
  if first == 1 then return label .. "\n" .. table.concat(lines, "\n") end
  return string.format("%s  (from line %d)\n%s", label, first, table.concat(lines, "\n", first))
end

---Put `line` of the buffer shown in `win` in view, centred (telescope and
---snacks, for `file` and `lines` specs alike). A line past the end is clamped
---to the last one.
---@param win integer|nil
---@param line integer|nil
function M.show_line(win, line)
  line = tonumber(line)
  if not (line and win and vim.api.nvim_win_is_valid(win)) then return end
  local count = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
  pcall(vim.api.nvim_win_set_cursor, win, { math.max(1, math.min(math.floor(line), count)), 0 })
  vim.api.nvim_win_call(win, function()
    vim.cmd("normal! zz")
  end)
end

return M
