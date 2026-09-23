---@module 'pickers.entry_actions.path_copy'
---@brief Engine-agnostic path-copy actions for the currently selected picker
---entry: copy its absolute path, its parent directory, an env-rooted path
---($REPOS_DIR/…), or a Markdown link.
---@description
--- The curated subset of filetree.nvim's `path_copy`/`markdown_links`
--- features that still makes sense on a PICKER RESULT ROW -- a plain path
--- string, not a `FiletreeNode` (see filetree.nvim's
--- lua/filetree/features/paths/path_copy/init.lua and
--- lua/filetree/features/paths/markdown_links/init.lua for the reference
--- semantics this mirrors):
---
---   absolute       /home/user/project/src/foo.lua                ([a)
---   dirname        /home/user/project/src  (parent directory)    (]a)
---   env_rooted     $REPOS_DIR/foo.nvim/x.lua                      ([e)
---   markdown_link  [foo.lua](relative/path)                       (ML)
---
--- Deliberately NOT ported: marks ("m"/Trash), the recursive/from-marked
--- markdown-link variants (MR/MM) -- a picker result row is one file, not a
--- directory subtree, and pickers.nvim has no multi-select-aware "marks"
--- concept to drive a "from marked" variant. filetree.nvim's "gb" (add to
--- buffer list, no focus switch) is likewise not duplicated here:
--- `pickers.entry_actions.open_background` (`keys.open_background`, default
--- <S-CR>/<C-o>) already IS that action on every engine -- the nvim-config's
--- own history literally renamed it from "open_badd" to "open_background"
--- (see entry_actions/adapters/telescope.lua's module doc).
---
--- Every format writes to both the "+" (system) and unnamed '"' registers,
--- matching filetree.nvim's and this plugin's own clipboard convention.

local notify = require("lib.nvim.notify").create("[pickers.entry_actions.path_copy]")
local unify_slashes = require("lib.nvim.cross.fs.separators.unify_slashes")
local is_windows = require("lib.nvim.cross.platform.is_windows")

local fn = vim.fn

local M = {}

---@internal
---Fold `$REPOS_DIR` back into an absolute path when it lives under it.
---Falls back to the plain absolute path when the env var is unset/empty or
---`abs` is not under it -- same "no relative form, leave it as-is" posture
---as filetree.nvim's `util.path.env_rooted`. Reads `pickers.config`'s
---already-resolved `repos_dir` (the one sanctioned place this env var is
---read in this plugin, see `pickers.config`'s own module doc) rather than
---`vim.env.REPOS_DIR` directly.
---@param abs string
---@return string
local function env_rooted(abs)
  local root = require("pickers.config").get().repos_dir
  if type(root) ~= "string" or root == "" then return abs end

  local norm = unify_slashes(abs)
  local norm_root = unify_slashes(root):gsub("/+$", "")

  -- Windows compares paths case-insensitively, and a drive letter alone can
  -- differ in case between $REPOS_DIR and what the picker reports for a
  -- file under it -- a case-sensitive compare would just never match there.
  local function fold(s)
    return is_windows() and s:lower() or s
  end
  local folded, folded_root = fold(norm), fold(norm_root)

  local under = folded == folded_root or folded:sub(1, #folded_root + 1) == folded_root .. "/"
  if not under then return abs end

  local rest = norm:sub(#norm_root + 2)
  return rest == "" and "$REPOS_DIR" or ("$REPOS_DIR/" .. rest)
end

---@internal
---Markdown link for `abs`, relative to cwd -- same convention as
---filetree.nvim's markdown_links feature (`[name](relative/path)`).
---@param abs string
---@return string
local function markdown_link(abs)
  local rel = unify_slashes(fn.fnamemodify(abs, ":."))
  local name = fn.fnamemodify(abs, ":t")
  return string.format("[%s](%s)", name, rel)
end

---One format builder per supported `[a`/`]a`/`[e`/`ML`-style action. Every
---builder receives an already-absolute path and returns the text to copy.
---@type table<string, fun(abs: string): string>
M.FORMATS = {
  absolute = function(abs)
    return abs
  end,
  dirname = function(abs)
    return fn.fnamemodify(abs, ":h")
  end,
  env_rooted = env_rooted,
  markdown_link = markdown_link,
}

---Stable order the cheatsheet/tests iterate in.
---@type string[]
M.FORMAT_ORDER = { "absolute", "dirname", "env_rooted", "markdown_link" }

---Build `fmt`'s text for `path` without touching any register -- the pure
---half of `M.run`, split out so it can be unit-tested without stubbing
---`vim.fn.setreg`.
---@param fmt string
---@param path string
---@return string|nil text  nil when `fmt` is unknown or `path` is empty.
function M.build(fmt, path)
  local builder = M.FORMATS[fmt]
  if not builder or not path or path == "" then return nil end
  local abs = fn.fnamemodify(path, ":p")
  return unify_slashes(builder(abs))
end

---Copy `path` in the given format to the "+" and unnamed registers, and
---notify. `path` may be relative; every format resolves it to an absolute
---path first (a picker's selected entry is not guaranteed to already be
---absolute, unlike a filetree.nvim node's `path`).
---@param fmt "absolute"|"dirname"|"env_rooted"|"markdown_link"
---@param path string|nil
---@return boolean ok
function M.run(fmt, path)
  if not M.FORMATS[fmt] then
    notify.warn("Unknown path_copy format: " .. tostring(fmt))
    return false
  end
  if not path or path == "" then
    notify.warn("No valid path found")
    return false
  end

  local text = M.build(fmt, path)
  ---@cast text string  -- fmt/path were both validated above
  fn.setreg("+", text)
  fn.setreg('"', text)
  notify.info(string.format("[%s] %s", fmt, text))
  return true
end

return M
