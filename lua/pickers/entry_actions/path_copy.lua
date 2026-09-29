---@module 'pickers.entry_actions.path_copy'
---@brief Engine-agnostic path-copy actions for the selected picker entries:
---absolute path, parent directory, env-rooted path ($REPOS_DIR/…), project
---root / project-relative / buffer-relative paths, and Markdown links.
---@description
--- The curated subset of filetree.nvim's `path_copy`/`markdown_links`/
--- `copy_file_list` features that still makes sense on a PICKER RESULT ROW --
--- a plain path string, not a `FiletreeNode` (see filetree.nvim's
--- lua/filetree/features/paths/path_copy/init.lua and
--- lua/filetree/features/paths/markdown_links/init.lua for the reference
--- semantics this mirrors):
---
---   absolute           /home/user/project/src/foo.lua               ([a, [f)
---   dirname            /home/user/project/src  (parent directory)   (]a)
---   env_rooted         $REPOS_DIR/foo.nvim/x.lua                     ([e)
---   project_root       /home/user/project  (nearest .git ancestor)   ([R)
---   project_relative   src/foo.lua  (relative to that root)          (]R)
---   buffer_relative    ./foo.lua  (relative to the OPEN buffer)      (]b)
---   markdown_link      [foo.lua](relative/path)                      (ML, MM)
---
--- filetree.nvim's "marks if any, else the node under the cursor" idiom maps
--- onto the picker's own multi-selection (Tab on every engine): every format
--- works on ALL selected entries when there are any, else on the current one,
--- one line per entry. That is what `[f` (file list) and `MM` (links from the
--- marked entries) are in a picker -- there is no separate marks concept.
---
--- Deliberately NOT ported: the recursive markdown-link variant (`MR` -- a
--- result row is one file, not a directory subtree) and trash. filetree.nvim's
--- "gb" (add to buffer list, no focus switch) is not duplicated here either:
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

---@internal
---Cached `.git`-marker root finder (lib.nvim), built on first use.
---@type Lib.Fs.FindRoot|nil
local root_finder

---@internal
---Nearest project root above `abs` -- the closest ancestor holding a `.git`
---entry -- falling back to the cwd when there is none, like filetree.nvim's
---`resolve_root`.
---@param abs string
---@return string
local function project_root(abs)
  root_finder = root_finder
    or require("lib.nvim.fs.find_root")({ markers = { ".git" }, cache_chain = true })
  local ok, root = pcall(root_finder.find, abs)
  if ok and type(root) == "string" and root ~= "" then return root end
  return fn.getcwd()
end

---@internal
---Directory the OPEN buffer lives in -- the base a link written into that
---buffer resolves against (cwd is the wrong base: `docs/A.md` linking to
---`docs/B.md` is `./B.md`, not `docs/B.md`). Same order as filetree.nvim's
---`editor_dir`: the window behind the picker, then the alternate file, then
---the cwd. `win` is that window when the engine knows it.
---@param win integer|nil
---@return string
local function editor_dir(win)
  if win and vim.api.nvim_win_is_valid(win) then
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
    if name ~= "" then return fn.fnamemodify(name, ":p:h") end
  end

  -- pcall'd: `expand("#:p")` THROWS E194 when there is no alternate file.
  local ok, alt = pcall(fn.expand, "#:p")
  if ok and type(alt) == "string" and alt ~= "" then return fn.fnamemodify(alt, ":p:h") end

  return fn.getcwd()
end

---@internal
---`abs` relative to `base`, a descendant marked with an explicit `./` (a bare
---`docs/X.md` resolves against the reader's cwd in some renderers).
---@param abs string
---@param base string
---@return string
local function dot_relative(abs, base)
  local rel = require("lib.nvim.fs.relpath")(abs, base)
  -- An absolute result means "no relative form exists" (different drives).
  if rel:match("^%a:/") or rel:sub(1, 1) == "/" then return rel end
  if rel == "." or rel == ".." or rel:match("^%.%.?/") then return rel end
  return "./" .. rel
end

---One format builder per supported action. Every builder receives an
---already-absolute path plus the run context (`{ win = integer|nil }`) and
---returns the text to copy for that ONE entry.
---@type table<string, fun(abs: string, ctx: { win: integer|nil }): string>
M.FORMATS = {
  absolute = function(abs)
    return abs
  end,
  dirname = function(abs)
    return fn.fnamemodify(abs, ":h")
  end,
  env_rooted = env_rooted,
  project_root = project_root,
  project_relative = function(abs)
    return require("lib.nvim.fs.relpath")(abs, project_root(abs))
  end,
  buffer_relative = function(abs, ctx)
    return dot_relative(abs, editor_dir(ctx.win))
  end,
  markdown_link = markdown_link,
}

---Stable order the cheatsheet/tests iterate in.
---@type string[]
M.FORMAT_ORDER = {
  "absolute",
  "dirname",
  "env_rooted",
  "project_root",
  "project_relative",
  "buffer_relative",
  "markdown_link",
}

---path_copy format name -> `pickers.keys` action name, shared by the three
---engine adapters so none of them keeps its own copy of this table.
---@type table<string, string>
M.ACTION_FOR = {
  absolute = "copy_absolute",
  dirname = "copy_dirname",
  env_rooted = "copy_env_rooted",
  project_root = "copy_project_root",
  project_relative = "copy_project_relative",
  buffer_relative = "copy_buffer_relative",
  markdown_link = "markdown_link",
}

---Build `fmt`'s text for `paths` without touching any register -- the pure
---half of `M.run`, split out so it can be unit-tested without stubbing
---`vim.fn.setreg`. One line per entry, blank paths skipped and repeated lines
---dropped (ten entries in one repo yield ONE `project_root` line).
---@param fmt string
---@param paths string|string[]|nil
---@param opts { win: integer|nil }|nil
---@return string|nil text  nil when `fmt` is unknown or there is no usable path.
function M.build(fmt, paths, opts)
  local builder = M.FORMATS[fmt]
  if not builder then return nil end
  if type(paths) == "string" then paths = { paths } end

  local ctx = { win = opts and opts.win or nil }
  local lines, seen = {}, {}
  for _, path in ipairs(paths or {}) do
    if type(path) == "string" and path ~= "" then
      local line = unify_slashes(builder(fn.fnamemodify(path, ":p"), ctx))
      if not seen[line] then
        seen[line] = true
        lines[#lines + 1] = line
      end
    end
  end

  if #lines == 0 then return nil end
  return table.concat(lines, "\n")
end

---Copy `paths` in the given format to the "+" and unnamed registers, and
---notify. A path may be relative; every format resolves it to an absolute
---path first (a picker's selected entry is not guaranteed to already be
---absolute, unlike a filetree.nvim node's `path`).
---@param fmt string  One of `M.FORMAT_ORDER`.
---@param paths string|string[]|nil  The selected entries, or the current one.
---@param opts { win: integer|nil }|nil  `win` = the window behind the picker
---(the base of `buffer_relative`).
---@return boolean ok
function M.run(fmt, paths, opts)
  if not M.FORMATS[fmt] then
    notify.warn("Unknown path_copy format: " .. tostring(fmt))
    return false
  end

  local text = M.build(fmt, paths, opts)
  if not text then
    notify.warn("No valid path found")
    return false
  end

  fn.setreg("+", text)
  fn.setreg('"', text)

  local _, breaks = text:gsub("\n", "")
  if breaks == 0 then
    notify.info(string.format("[%s] %s", fmt, text))
  else
    notify.info(string.format("[%s] Copied %d lines", fmt, breaks + 1))
  end
  return true
end

return M
