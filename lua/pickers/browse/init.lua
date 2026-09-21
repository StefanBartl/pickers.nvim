---@module 'pickers.browse'
---@brief A file browser on the engine's own item picker: one directory per
---picker, directories first, `..` to go up, and the file operations
---(new file, new directory, rename, delete) as rows of the same list --
---through fileops.nvim when it is installed, plain `vim.uv` otherwise.
---@description
--- The telescope-file-browser harvest, composed from two things this
--- collection already had: `pick_item` (the engine-agnostic list every
--- engine implements, with a file previewer when an item carries `file`)
--- and fileops.nvim's operations. Picking a directory reopens the browser
--- there, picking a file edits it, picking an action row asks for a name
--- with `vim.ui.input` and then reopens the browser so the result is
--- visible. Nothing here is engine-specific, which is also why fzf-lua --
--- the engine with no explorer at all -- gets one.
---
--- What it is not: a tree. It is a list of one directory at a time, which
--- is what a picker draws well; the tree is snacks' explorer or
--- filetree.nvim.

local notify = require("lib.nvim.notify").create("[pickers]")

local M = {}

---@class Pickers.BrowseEntry: Pickers.Item
---@field path string
---@field kind "dir"|"file"|"up"|"action"
---@field action? "new_file"|"new_dir"|"rename"|"delete"

---@class Pickers.BrowseOpts
---@field engine_mod? table
---@field hidden? boolean      # list dotfiles (default true)
---@field actions? boolean     # show the action rows (default true)

local ACTIONS = {
  { action = "new_file", text = "[+] new file…" },
  { action = "new_dir", text = "[+] new directory…" },
  { action = "rename", text = "[~] rename…" },
  { action = "delete", text = "[-] delete…" },
}

---@internal
---@param p string
---@return string
local function norm(p)
  p = vim.fs.normalize(p)
  if #p > 1 and p:sub(-1) == "/" then p = p:sub(1, -2) end
  return p
end

---The entries of `dir`, directories first (each with a trailing `/`),
---then files, both sorted case-insensitively; `..` first when `dir` has a
---parent; the action rows last. Pure apart from the directory read.
---@param dir string
---@param opts Pickers.BrowseOpts|nil
---@return Pickers.BrowseEntry[]
function M.entries(dir, opts)
  opts = opts or {}
  dir = norm(dir)
  if vim.fn.isdirectory(dir) ~= 1 then return {} end
  local dirs, files = {}, {}
  local ok = pcall(function()
    for name, kind in vim.fs.dir(dir) do
      if opts.hidden ~= false or name:sub(1, 1) ~= "." then
        local path = dir .. "/" .. name
        if kind == "directory" then
          dirs[#dirs + 1] = { text = name .. "/", path = path, kind = "dir" }
        else
          files[#files + 1] = { text = name, path = path, kind = "file", file = path }
        end
      end
    end
  end)
  if not ok then return {} end
  local function by_name(a, b)
    return a.text:lower() < b.text:lower()
  end
  table.sort(dirs, by_name)
  table.sort(files, by_name)

  local out = {}
  local parent = vim.fs.dirname(dir)
  if parent and parent ~= dir then out[#out + 1] = { text = "../", path = parent, kind = "up" } end
  vim.list_extend(out, dirs)
  vim.list_extend(out, files)
  if opts.actions ~= false then
    for _, a in ipairs(ACTIONS) do
      out[#out + 1] = { text = a.text, path = dir, kind = "action", action = a.action }
    end
  end
  return out
end

-- ── operations ───────────────────────────────────────────────────────────────

---@internal
---@return table|nil  fileops.ops.file, when installed
local function fileops()
  local ok, mod = pcall(require, "fileops.ops.file")
  if ok and type(mod) == "table" then return mod end
  return nil
end

---@internal
---@param action string
---@param path string
local function changed(action, path)
  local fo = fileops()
  if fo and type(fo.notify_change) == "function" then
    pcall(fo.notify_change, action, path, { refresh_explorers = true })
  end
end

---@internal
---@param prompt string
---@param default string|nil
---@param cb fun(answer: string)
local function ask(prompt, default, cb)
  vim.ui.input({ prompt = prompt, default = default or "" }, function(answer)
    if type(answer) == "string" and answer ~= "" then cb(answer) end
  end)
end

---@internal
---Whether `name` is safe to join onto a directory as a single new path
---segment for new_file/new_dir/rename: no path separator (a bare name
---typed into "New file in <dir>: " must not reach outside `dir`, e.g.
---`../../etc/passwd` or `C:\Windows\...`) and not `.`/`..`.
---@param name string
---@return boolean
local function safe_name(name)
  if name == "" or name == "." or name == ".." then return false end
  return not name:find("[/\\]")
end

---Create and edit `path` (parents made), via fileops when present.
---@param path string
---@return boolean ok
function M.new_file(path)
  local fo = fileops()
  if fo and type(fo.edit_new) == "function" then
    local ok = fo.edit_new(path, { refresh_explorers = true })
    return ok ~= false
  end
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.cmd.edit(vim.fn.fnameescape(path))
  return true
end

---Create directory `path` (parents made).
---@param path string
---@return boolean ok
function M.new_dir(path)
  local ok = vim.fn.mkdir(path, "p") == 1
  if ok then changed("mkdir", path) end
  return ok
end

---Rename `from` to `to`, refusing to overwrite.
---@param from string
---@param to string
---@return boolean ok
---@return string|nil err
function M.rename(from, to)
  if vim.uv.fs_stat(to) then return false, "exists: " .. to end
  -- Resolved before the move (the path is gone afterwards): a buffer may
  -- spell the same file through a symlink, e.g. macOS /var -> /private/var.
  local real_from = vim.uv.fs_realpath(from)
  local ok, err = vim.uv.fs_rename(from, to)
  if not ok then return false, tostring(err) end
  -- A buffer showing the old path follows it.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local name = norm(vim.api.nvim_buf_get_name(buf))
      if name == norm(from) or (real_from and name == norm(real_from)) then
        pcall(vim.api.nvim_buf_set_name, buf, to)
      end
    end
  end
  changed("rename", to)
  return true, nil
end

---Delete `path` (a file, or a directory recursively), via fileops'
---`delete_path` when present (trash-aware there), `vim.fn.delete` otherwise.
---@param path string
---@return boolean ok
---@return string|nil err
function M.delete(path)
  local fo = fileops()
  if fo and type(fo.delete_path) == "function" then
    local ok, msg = fo.delete_path(path, {})
    return ok ~= false, ok and nil or msg
  end
  local rc = vim.fn.delete(path, "rf")
  if rc ~= 0 then return false, "could not delete " .. path end
  changed("delete", path)
  return true, nil
end

-- ── the picker ───────────────────────────────────────────────────────────────

---@internal
---A second list over the plain entries of `dir`, for rename/delete.
---@param dir string
---@param prompt string
---@param engine_mod table
---@param cb fun(entry: Pickers.BrowseEntry)
local function pick_entry(dir, prompt, engine_mod, cb)
  local items = {}
  for _, e in ipairs(M.entries(dir, { actions = false })) do
    if e.kind == "dir" or e.kind == "file" then items[#items + 1] = e end
  end
  if #items == 0 then
    notify.info("nothing in " .. dir)
    return
  end
  engine_mod.pick_item({ prompt = prompt, items = items, on_select = cb })
end

---@internal
---@param entry Pickers.BrowseEntry
---@param opts Pickers.BrowseOpts
local function run_action(entry, opts)
  local dir = entry.path
  local reopen = function()
    M.open(dir, opts)
  end
  if entry.action == "new_file" then
    ask("New file in " .. dir .. ": ", nil, function(name)
      if not safe_name(name) then
        notify.error("new file: invalid name " .. name)
        return
      end
      M.new_file(dir .. "/" .. name)
    end)
  elseif entry.action == "new_dir" then
    ask("New directory in " .. dir .. ": ", nil, function(name)
      if not safe_name(name) then
        notify.error("new directory: invalid name " .. name)
        return
      end
      if M.new_dir(dir .. "/" .. name) then reopen() end
    end)
  elseif entry.action == "rename" then
    pick_entry(dir, "Rename which?", opts.engine_mod, function(e)
      ask("Rename to: ", e.text:gsub("/$", ""), function(name)
        if not safe_name(name) then
          notify.error("rename: invalid name " .. name)
          reopen()
          return
        end
        local ok, err = M.rename(e.path, dir .. "/" .. name)
        if not ok then notify.error("rename: " .. tostring(err)) end
        reopen()
      end)
    end)
  elseif entry.action == "delete" then
    pick_entry(dir, "Delete which?", opts.engine_mod, function(e)
      vim.ui.select({ "yes", "no" }, { prompt = "Delete " .. e.path .. "?" }, function(answer)
        if answer == "yes" then
          local ok, err = M.delete(e.path)
          if not ok then notify.error("delete: " .. tostring(err)) end
        end
        reopen()
      end)
    end)
  end
end

---Open the browser at `dir` (default: the cwd) on `opts.engine_mod`
---(default: the resolved engine).
---@param dir string|nil
---@param opts Pickers.BrowseOpts|nil
function M.open(dir, opts)
  opts = opts or {}
  opts.engine_mod = opts.engine_mod or require("pickers.engines").load()
  if not opts.engine_mod then return end
  dir = norm(dir or vim.uv.cwd() or vim.fn.getcwd())
  local items = M.entries(dir, opts)
  if #items == 0 then
    notify.warn("not a readable directory: " .. dir)
    return
  end
  opts.engine_mod.pick_item({
    prompt = "Browse " .. vim.fn.fnamemodify(dir, ":~"),
    items = items,
    on_select = function(entry)
      if type(entry) ~= "table" then return end
      if entry.kind == "dir" or entry.kind == "up" then
        M.open(entry.path, opts)
      elseif entry.kind == "file" then
        vim.cmd.edit(vim.fn.fnameescape(entry.path))
      elseif entry.kind == "action" then
        run_action(entry, opts)
      end
    end,
  })
end

return M
