---@module 'pickers.quickfix'
---@brief The quickfix (and location) window, upgraded in place: a preview
---@brief float that follows the cursor, and the `pickers.refine` filter stack
---@brief applied to the list itself.
---@description
--- The one picker every engine leaves alone is the one Neovim already ships:
--- `:copen`. This module keeps it -- no picker replaces the list, no engine
--- is involved -- and adds the two things a quickfix window is missing:
---
---   * **Preview.** While the cursor sits on an entry, a float above the
---     list shows the target file around the entry's line, that line
---     highlighted, with the file's own filetype for syntax. It follows
---     `CursorMoved` and disappears when the list window loses focus or
---     closes. `p` toggles it for the session.
---   * **Filter.** `zf` opens `pickers.refine`'s prompt over the list's
---     entries (fields `path` and `text`); the list is replaced by the
---     entries the stack keeps, its title showing the stack, and `zF` puts
---     the full list back. The original entries are kept per list, so
---     filtering is non-destructive.
---
--- The idea is nvim-bqf's; the scope is what this plugin already had the
--- pieces for. bqf's fzf mode is not reproduced: `pickers.refine` is the
--- filter grammar of this plugin, and it is what `<C-f>` runs in the
--- pickers themselves.
---
--- Everything is buffer-local to the quickfix buffer, installed from a
--- `FileType qf` autocmd, and off entirely with `quickfix.enabled = false`.

local M = {}

---@class Pickers.QuickfixPreviewConfig
---@field enabled boolean        # show the preview float at all
---@field height integer         # rows of the float
---@field context integer        # lines above the target line kept visible
---@field border string          # nvim_open_win border
---@field delay_ms integer       # debounce after CursorMoved

---@class Pickers.QuickfixKeysConfig
---@field filter string|false          # open the refine prompt
---@field restore string|false         # put the full list back
---@field toggle_preview string|false  # preview on/off for the session

---@class Pickers.QuickfixConfig
---@field enabled boolean
---@field preview Pickers.QuickfixPreviewConfig
---@field keys Pickers.QuickfixKeysConfig

---@type Pickers.QuickfixConfig
M.DEFAULTS = {
  enabled = true,
  preview = {
    enabled = true,
    height = 12,
    context = 4,
    border = "rounded",
    delay_ms = 40,
  },
  keys = {
    filter = "zf",
    restore = "zF",
    toggle_preview = "p",
  },
}

local NS = vim.api.nvim_create_namespace("pickers_quickfix")
local GROUP = "pickers.nvim.quickfix"

---@type table<integer, integer>  qf buffer -> preview window
local previews = {}
---@type table<integer, integer>  qf buffer -> preview buffer
local preview_bufs = {}
---@type table<integer, table>    qf buffer -> the full item list before filtering
local originals = {}
---@type table<integer, table>    qf buffer -> refine handle
local handles = {}
---@type boolean
local preview_on = true

---@return Pickers.QuickfixConfig
local function cfg()
  local ok, config = pcall(require, "pickers.config")
  if ok then
    local c = config.get().quickfix
    if type(c) == "table" then return c end
  end
  return M.DEFAULTS
end

-- ── list access ──────────────────────────────────────────────────────────────

---@internal
---Whether `win` shows a location list (vs. the quickfix list).
---@param win integer
---@return boolean
local function is_loclist(win)
  local info = vim.fn.getwininfo(win)[1]
  return info ~= nil and info.loclist == 1
end

---@internal
---The items of the list `win` shows, and its title.
---@param win integer
---@return table[] items
---@return string title
local function list_of(win)
  if is_loclist(win) then
    local l = vim.fn.getloclist(win, { items = 1, title = 1 })
    return l.items or {}, l.title or ""
  end
  local q = vim.fn.getqflist({ items = 1, title = 1 })
  return q.items or {}, q.title or ""
end

---@internal
---Replace the list `win` shows (in place, keeping its window).
---@param win integer
---@param items table[]
---@param title string
local function set_list(win, items, title)
  if is_loclist(win) then
    vim.fn.setloclist(win, {}, "r", { items = items, title = title })
  else
    vim.fn.setqflist({}, "r", { items = items, title = title })
  end
end

---@internal
---The current changedtick of the list `win` shows -- bumped by every
---setqflist()/setloclist() write, including a foreign one, so comparing it
---against a value captured earlier detects "something replaced this list
---since then" without caring what that something was.
---@param win integer
---@return integer
local function list_tick(win)
  if is_loclist(win) then return vim.fn.getloclist(win, { changedtick = 0 }).changedtick or 0 end
  return vim.fn.getqflist({ changedtick = 0 }).changedtick or 0
end

---@internal
---A display name for `item`: its buffer's real name when the buffer is
---still valid, `item.filename` otherwise. `nvim_buf_get_name` throws on a
---bufnr that no longer refers to a valid buffer (e.g. :bwipeout-ed while
---its number is still recorded on a stale quickfix/location entry).
---@param item table
---@return string
local function item_name(item)
  local bufnr = item.bufnr
  if bufnr and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    local ok, name = pcall(vim.api.nvim_buf_get_name, bufnr)
    if ok then return name end
  end
  return item.filename or ""
end

---@internal
---The entry under the cursor of `win`, or nil.
---@param win integer
---@return table|nil
local function item_at_cursor(win)
  local items = list_of(win)
  local row = vim.api.nvim_win_get_cursor(win)[1]
  return items[row]
end

-- ── preview ──────────────────────────────────────────────────────────────────

---@internal
---@param qfbuf integer
local function close_preview(qfbuf)
  local win = previews[qfbuf]
  previews[qfbuf] = nil
  if win and vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
end

---@internal
---The preview scratch buffer for `qfbuf`, created once.
---@param qfbuf integer
---@return integer
local function preview_buf(qfbuf)
  local buf = preview_bufs[qfbuf]
  if buf and vim.api.nvim_buf_is_valid(buf) then return buf end
  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  preview_bufs[qfbuf] = buf
  return buf
end

---@internal
---The lines of the item's file around its line, from the loaded buffer when
---there is one and from disk otherwise.
---@param item table
---@param height integer
---@param context integer
---@return string[] lines
---@return integer first  1-based line number of `lines[1]`
---@return string filetype
local function source_lines(item, height, context)
  local lnum = math.max(item.lnum or 1, 1)
  local first = math.max(lnum - context, 1)
  local last = first + height - 1
  local bufnr = item.bufnr
  if bufnr and bufnr > 0 and vim.api.nvim_buf_is_loaded(bufnr) then
    local lines = vim.api.nvim_buf_get_lines(bufnr, first - 1, last, false)
    return lines, first, vim.bo[bufnr].filetype
  end
  local name = item_name(item)
  if name == "" or vim.fn.filereadable(name) ~= 1 then return {}, first, "" end
  -- `readfile(name, "", last)` used to materialise every line from the
  -- start of the file through `last` into one Lua table even though only
  -- `height` of them are ever kept -- for a match deep in a large file
  -- that is a large, repeated allocation on every debounced cursor move.
  -- Reading (and discarding) one line at a time instead keeps only the
  -- window actually shown in memory; the lines before `first` are still
  -- scanned, since a plain text file has no line index to seek by.
  local ok, lines = pcall(function()
    local f = io.open(name, "r")
    if not f then return nil end
    for _ = 1, first - 1 do
      if not f:read("l") then
        f:close()
        return {}
      end
    end
    local out = {}
    for _ = first, last do
      local l = f:read("l")
      if not l then break end
      out[#out + 1] = l
    end
    f:close()
    return out
  end)
  if not ok or not lines then return {}, first, "" end
  local ft = vim.filetype.match({ filename = name }) or ""
  return lines, first, ft
end

---Draw (or redraw) the preview for the entry under the cursor of `win`.
---@param win integer|nil  the quickfix window; default: current
---@return boolean shown
function M.preview(win)
  win = win or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then return false end
  local qfbuf = vim.api.nvim_win_get_buf(win)
  local c = cfg()
  if not c.enabled or not c.preview.enabled or not preview_on then
    close_preview(qfbuf)
    return false
  end
  local item = item_at_cursor(win)
  if not item or (item.bufnr or 0) <= 0 and (item.filename or "") == "" then
    close_preview(qfbuf)
    return false
  end

  local height = math.max(c.preview.height or 12, 3)
  local lines, first, ft = source_lines(item, height, c.preview.context or 4)
  if #lines == 0 then
    close_preview(qfbuf)
    return false
  end

  local buf = preview_buf(qfbuf)
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  local target = (item.lnum or first) - first
  if target >= 0 and target < #lines then
    vim.api.nvim_buf_set_extmark(
      buf,
      NS,
      target,
      0,
      { line_hl_group = "CursorLine", priority = 200 }
    )
  end
  if ft ~= "" and ft ~= vim.bo[buf].filetype then
    if not pcall(vim.treesitter.start, buf, vim.treesitter.language.get_lang(ft)) then
      vim.api.nvim_set_option_value("syntax", ft, { buf = buf })
    end
  end

  local title = (" %s:%d "):format(vim.fn.fnamemodify(item_name(item), ":~:."), item.lnum or 0)
  local width = vim.api.nvim_win_get_width(win)
  local wcfg = {
    relative = "win",
    win = win,
    anchor = "SW",
    row = 0,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = c.preview.border or "rounded",
    title = title,
    title_pos = "left",
    focusable = false,
    zindex = 45,
  }
  local pwin = previews[qfbuf]
  if pwin and vim.api.nvim_win_is_valid(pwin) then
    -- `noautocmd` is only valid on window CREATION (nvim_open_win below) --
    -- passing it to nvim_win_set_config on an already-existing window raises
    -- "'noautocmd' cannot be used with existing windows" (Neovim 0.11+).
    vim.api.nvim_win_set_config(pwin, wcfg)
  else
    pwin = vim.api.nvim_open_win(buf, false, vim.tbl_extend("force", wcfg, { noautocmd = true }))
    vim.api.nvim_set_option_value("number", true, { win = pwin })
    vim.api.nvim_set_option_value("wrap", false, { win = pwin })
    vim.api.nvim_set_option_value("cursorline", false, { win = pwin })
    vim.api.nvim_set_option_value("winhighlight", "NormalFloat:Normal", { win = pwin })
    previews[qfbuf] = pwin
  end
  -- Number the float from the file's own first shown line.
  vim.api.nvim_set_option_value(
    "statuscolumn",
    ("%%{v:lnum + %d}"):format(first - 1) .. " ",
    { win = pwin }
  )
  return true
end

---The preview window of `qfbuf` (default: current buffer), or nil.
---@param qfbuf integer|nil
---@return integer|nil
function M.preview_win(qfbuf)
  local win = previews[qfbuf or vim.api.nvim_get_current_buf()]
  if win and vim.api.nvim_win_is_valid(win) then return win end
  return nil
end

---Preview on/off for the session (`p` in the list).
---@return boolean now_on
function M.toggle_preview()
  preview_on = not preview_on
  if not preview_on then
    for qfbuf in pairs(previews) do
      close_preview(qfbuf)
    end
  else
    M.preview()
  end
  return preview_on
end

-- ── filter ───────────────────────────────────────────────────────────────────

---@internal
---@param qfbuf integer
---@return table  Pickers.Refine.Handle
local function handle_for(qfbuf)
  local h = handles[qfbuf]
  if h then return h end
  h = require("pickers.refine").new({
    fields = {
      path = item_name,
      text = function(it)
        return it.text
      end,
    },
  })
  handles[qfbuf] = h
  return h
end

---Apply the refine stack of `win`'s list: the full list is remembered the
---first time, and every later call filters that, not the previous result.
---@param win integer|nil
---@return integer shown
---@return integer total
function M.apply(win)
  win = win or vim.api.nvim_get_current_win()
  local qfbuf = vim.api.nvim_win_get_buf(win)
  local h = handle_for(qfbuf)
  local orig = originals[qfbuf]
  if not orig or orig.tick ~= list_tick(win) then
    -- Nothing remembered yet, or the list changed since we last wrote to
    -- it -- a fresh :grep, an LSP references list, anything not from our
    -- own apply()/restore() -- so the remembered "original" is for a list
    -- that is gone; start over from what is actually showing now, and
    -- drop clauses that were built against it.
    local items, title = list_of(win)
    orig = { items = items, title = title }
    originals[qfbuf] = orig
    h:clear()
  end
  local kept = h:apply(orig.items)
  set_list(win, kept, h:title(orig.title, #kept, #orig.items))
  orig.tick = list_tick(win)
  return #kept, #orig.items
end

---Put the full list back and clear the stack.
---@param win integer|nil
function M.restore(win)
  win = win or vim.api.nvim_get_current_win()
  local qfbuf = vim.api.nvim_win_get_buf(win)
  local orig = originals[qfbuf]
  local h = handles[qfbuf]
  if h then h:clear() end
  if orig and orig.tick == list_tick(win) then
    -- Only restore when nothing else has touched the list since we last
    -- wrote to it -- otherwise this would clobber a list (e.g. a fresh
    -- :grep) that has nothing to do with our own remembered original.
    set_list(win, orig.items, orig.title)
  end
  originals[qfbuf] = nil
end

---Open the refine prompt for the list in `win`, applying on change.
---@param win integer|nil
function M.filter(win)
  win = win or vim.api.nvim_get_current_win()
  local qfbuf = vim.api.nvim_win_get_buf(win)
  local h = handle_for(qfbuf)
  h:prompt(function()
    if vim.api.nvim_win_is_valid(win) then
      if h:is_active() then
        M.apply(win)
      else
        M.restore(win)
      end
    end
  end)
end

---The refine handle of `qfbuf` (default: current), for hosts and tests.
---@param qfbuf integer|nil
---@return table|nil
function M.handle(qfbuf)
  return handles[qfbuf or vim.api.nvim_get_current_buf()]
end

-- ── attach ───────────────────────────────────────────────────────────────────

---@internal
---@param lhs string|false|nil
---@param buf integer
---@param fn fun()
---@param desc string
local function map(lhs, buf, fn, desc)
  if type(lhs) ~= "string" or lhs == "" then return end
  vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = desc })
end

---Install the preview autocmds and the keys on one quickfix buffer.
---Idempotent per buffer.
---@param qfbuf integer|nil
function M.attach(qfbuf)
  qfbuf = qfbuf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(qfbuf) or vim.bo[qfbuf].buftype ~= "quickfix" then return end
  local c = cfg()
  if not c.enabled then return end
  if vim.b[qfbuf].pickers_quickfix_attached then return end
  vim.api.nvim_buf_set_var(qfbuf, "pickers_quickfix_attached", true)

  local group = vim.api.nvim_create_augroup(GROUP .. "." .. qfbuf, { clear = true })
  local timer = nil
  local function schedule()
    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end
    local delay = c.preview.delay_ms or 40
    if delay <= 0 then
      M.preview()
      return
    end
    timer = vim.uv.new_timer()
    timer:start(delay, 0, function()
      vim.schedule(function()
        local win = vim.api.nvim_get_current_win()
        if vim.api.nvim_win_get_buf(win) == qfbuf then M.preview(win) end
      end)
    end)
  end
  vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter", "WinEnter" }, {
    group = group,
    buffer = qfbuf,
    callback = schedule,
    desc = "pickers.nvim quickfix: preview the entry under the cursor",
  })
  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "BufWinLeave", "BufWipeout" }, {
    group = group,
    buffer = qfbuf,
    callback = function()
      close_preview(qfbuf)
    end,
    desc = "pickers.nvim quickfix: drop the preview when the list loses focus",
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = qfbuf,
    callback = function()
      -- The debounce timer is a libuv handle, not a Lua value -- it stays
      -- alive at the event-loop level until explicitly closed, so the
      -- last pending/fired one for this buffer must be stopped here too,
      -- not just left for garbage collection.
      if timer then
        timer:stop()
        timer:close()
        timer = nil
      end
      originals[qfbuf] = nil
      handles[qfbuf] = nil
      local pb = preview_bufs[qfbuf]
      preview_bufs[qfbuf] = nil
      if pb and vim.api.nvim_buf_is_valid(pb) then
        pcall(vim.api.nvim_buf_delete, pb, { force = true })
      end
    end,
    desc = "pickers.nvim quickfix: forget a wiped list",
  })

  map(c.keys.filter, qfbuf, M.filter, "pickers.nvim quickfix: refine the list")
  map(c.keys.restore, qfbuf, M.restore, "pickers.nvim quickfix: restore the full list")
  map(c.keys.toggle_preview, qfbuf, function()
    M.toggle_preview()
  end, "pickers.nvim quickfix: toggle the preview")
end

---Register the `FileType qf` trigger. Called from `pickers.bindings.setup`.
---@param config Pickers.Config|nil
function M.setup(config)
  local c = (config and config.quickfix) or cfg()
  local group = vim.api.nvim_create_augroup(GROUP, { clear = true })
  if not c.enabled then return end
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "qf",
    callback = function(ev)
      M.attach(ev.buf)
    end,
    desc = "pickers.nvim quickfix: attach preview + filter to the list window",
  })
  -- A list already open when setup() runs.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "qf" then M.attach(buf) end
  end
end

return M
