---@module 'pickers.entry_actions.link_insert'
---@brief Insert the selected entries as Markdown links into the window behind
---the picker, cursor into the first link.
---@description
--- The sibling of `path_copy`'s `markdown_link`, which only copies to the
--- registers: this one WRITES the links into the buffer the picker was opened
--- from -- one link inline at the cursor, several on lines of their own below
--- it -- and leaves the cursor where the first link still needs typing (its
--- empty title, else its path) in insert mode (`lib.nvim.markdown.link_cursor`).
--- filetree.nvim's `MI` is the same action in the tree.
---
--- The link path is spelled by `link_insert.path` (see `pickers.config`):
---   "buffer"   relative to the TARGET buffer's directory (`./x`, `../x`) -- default
---   "cwd"      relative to the working directory
---   "absolute" the full path
---   "env"      `$VAR/rest` when the file lies under a known root (gopath.nvim's
---              `shorten_path` when installed, else `$REPOS_DIR` /
---              `$NVIM_CONFIG_DIR` literally), else the "buffer" form
---
--- The caller closes the picker first (the window behind it is where the text
--- goes, and insert mode must end up there, not in a prompt buffer that is
--- about to disappear); `run` then inserts on the next loop iteration.

local notify = require("lib.nvim.notify").create("[pickers.entry_actions.link_insert]")
local feedback = require("lib.nvim.notify").create("[pickers]", { messages = true })
local unify_slashes = require("lib.nvim.cross.fs.separators.unify_slashes")

local fn = vim.fn

local M = {}

--- Action name in `pickers.keys`.
M.ACTION = "markdown_link_insert"

---@internal
---Directory the target buffer lives in, nil for an unnamed/special buffer.
---@param buf integer
---@return string|nil
local function buffer_dir(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  local special = vim.bo[buf].buftype ~= "" or name:match("^%a[%w+.-]*://") ~= nil
  if name == "" or special then return nil end
  return fn.fnamemodify(name, ":p:h")
end

---@internal
---`abs` relative to `base`, a descendant marked with an explicit `./`.
---@param abs string
---@param base string
---@return string
local function dot_relative(abs, base)
  local rel = require("lib.nvim.fs.relpath")(abs, base)
  if rel:match("^%a:/") or rel:sub(1, 1) == "/" then return rel end
  if rel == "." or rel == ".." or rel:match("^%.%.?/") then return rel end
  return "./" .. rel
end

---@internal
---`$VAR/rest` for `abs`, or nil when it lies under no known root.
---@param abs string
---@return string|nil
local function env_path(abs)
  local ok, gopath = pcall(require, "gopath.env_shorten")
  if ok and type(gopath.shorten_path) == "function" then
    local shortened = gopath.shorten_path(abs)
    if shortened then return shortened end
  end

  local function under(root)
    if type(root) ~= "string" or root == "" then return nil end
    local norm_root = unify_slashes(root):gsub("/+$", "")
    local norm = unify_slashes(abs)
    local lower = vim.fn.has("win32") == 1
    local a, r = lower and norm:lower() or norm, lower and norm_root:lower() or norm_root
    if a == r then return "" end
    if a:sub(1, #r + 1) == r .. "/" then return norm:sub(#norm_root + 1) end
    return nil
  end

  local repos = under(require("pickers.config").get().repos_dir)
  if repos then return "$REPOS_DIR" .. repos end
  local nvim = under(fn.stdpath("config"))
  if nvim then return "$NVIM_CONFIG_DIR" .. nvim end
  return nil
end

---The link target for `abs` as written into `buf`, per `link_insert.path`.
---@param abs string
---@param buf integer
---@param mode? string  default: the configured `link_insert.path`
---@return string
function M.target(abs, buf, mode)
  mode = mode or require("pickers.config").get().link_insert.path
  if mode == "absolute" then return unify_slashes(abs) end
  if mode == "env" then
    local rooted = env_path(abs)
    if rooted then return rooted end
  end
  if mode == "cwd" then return unify_slashes(fn.fnamemodify(abs, ":.")) end

  local base = buffer_dir(buf)
  if not base then return unify_slashes(fn.fnamemodify(abs, ":.")) end
  return dot_relative(abs, base)
end

---One `[name](target)` per path for `buf`.
---@param paths string[]
---@param buf integer
---@param mode? string
---@return string[]
function M.build(paths, buf, mode)
  local links, seen = {}, {}
  for _, path in ipairs(paths) do
    local abs = fn.fnamemodify(path, ":p")
    local link = string.format("[%s](%s)", fn.fnamemodify(abs, ":t"), M.target(abs, buf, mode))
    if not seen[link] then
      seen[link] = true
      links[#links + 1] = link
    end
  end
  return links
end

---@internal
---The window to insert into: `win` (the one behind the picker) when it is a
---normal editable window, else the window the user came from.
---@param win integer|nil
---@return integer|nil
local function target_window(win)
  local find_usable = require("lib.nvim.window.find_usable")
  if win and find_usable.is_usable_window(win) then return win end
  return find_usable.previous_window()
end

---Insert `paths` as links. Call AFTER the picker is closed.
---@param paths string[]
---@param opts? { win?: integer|nil }  `win` = the window behind the picker
---@return boolean ok
---@return string|nil err  why nothing was inserted
function M.run(paths, opts)
  opts = opts or {}
  if not paths or #paths == 0 then
    notify.warn("No valid path found")
    return false, "no path"
  end

  local ok_lc, link_cursor = pcall(require, "lib.nvim.markdown.link_cursor")
  if not ok_lc or type(link_cursor.insert_links) ~= "function" then
    notify.warn("Inserting links needs a newer lib.nvim (markdown.link_cursor.insert_links)")
    return false, "lib.nvim too old"
  end

  local win = target_window(opts.win)
  if not win then
    notify.warn("No editor window to insert into")
    return false, "no window"
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype ~= "" or not vim.bo[buf].modifiable then
    notify.warn("The window behind the picker is not an editable file buffer")
    return false, "not editable"
  end

  local links = M.build(paths, buf)
  local cursor_opts = require("pickers.config").get().link_insert.cursor
  if not link_cursor.insert_links(buf, win, links, cursor_opts) then
    notify.warn("Could not insert the link(s)")
    return false, "insert failed"
  end
  feedback.info(string.format("inserted %d markdown link(s)", #links))
  return true
end

return M
