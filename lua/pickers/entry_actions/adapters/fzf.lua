---@module 'pickers.entry_actions.adapters.fzf'
---@brief fzf-lua entry-action registrations: create_file + open_background +
---cheatsheet + path_copy (copy_absolute/copy_dirname/copy_env_rooted/
---copy_project_root/copy_project_relative/copy_buffer_relative/markdown_link)
---+ system (open_system/reveal_in_manager).
---@description
--- fzf-lua action-table keys are fzf's own bind syntax ("ctrl-a", not
--- Neovim's "<C-a>"), so unlike the telescope/snacks adapters this one does
--- not read `keys.create_file`/`keys.open_background`/`keys.cheatsheet` —
--- there is no general, safe way to translate Neovim keymap syntax to fzf
--- bind syntax. Only `keys.enable` is honoured; the ctrl-a/ctrl-o/shift-enter/
--- f1 bindings themselves are fixed (matching the previous nvim-config
--- behavior exactly for the first two; f1 is new here).
---
--- The path_copy/system actions are fixed here too, for a second, more
--- fundamental reason than the others: fzf's own `--bind` syntax has no
--- concept of a multi-keystroke chord like vim's `[a` (it binds a single
--- logical key/event, not a pending-key state machine), so the chords have no
--- fzf equivalent at all. Fixed single physical keys are used instead -- the
--- same ones `pickers.keys`' direct (Ctrl/Alt) defaults resolve to on
--- telescope/snacks:
---
---   ctrl-y copy_absolute       alt-t copy_project_root    alt-l markdown_link
---   alt-y  copy_dirname        alt-e copy_project_relative alt-o open_system
---   alt-v  copy_env_rooted     alt-j copy_buffer_relative  alt-x reveal_in_manager
---
--- `ctrl-y` shadows fzf-lua's own git-picker-only `git_yank_commit`
--- (git_commits/git_bcommits/git_stash) exactly the way `ctrl-a`/`create_file`
--- already shadows those pickers' own `ctrl-a` overrides (git_branches/
--- git_worktrees) -- same accepted precedent, and harmless here too: a git-log
--- entry has no file path for `extract()` to find, so path_copy would just
--- warn "No valid path found" where the git-specific action fires instead.
--- The copy actions take every Tab-selected line (fzf hands them all to the
--- action), else the current one.
---
--- The cheatsheet needs its own resume dance, same shape as
--- do_open_background's but the other way round: fzf-lua's action table
--- always closes the running fzf process before the Lua callback runs (that's
--- how `--expect`/action wrapping works, not something an action can opt out
--- of), so the callback waits for the terminal to actually close, opens the
--- read-only panel, and resumes fzf once THAT closes. path_copy's and
--- system's own actions use the same resume dance (silently, no panel) since closing is
--- not optional here either -- filetree.nvim's non-disruptive "stay in
--- place" behavior is approximated by reopening right after the copy.

local notify = require("lib.nvim.notify").create("[pickers.entry_actions.adapters.fzf]")
local extract = require("pickers.entry_actions.extract.fzf")
local create_file = require("pickers.entry_actions.create_file")
local open_background = require("pickers.entry_actions.open_background")
local path_copy = require("pickers.entry_actions.path_copy")
local link_insert = require("pickers.entry_actions.link_insert")
local system = require("pickers.entry_actions.system")

local M = {}

---@internal
---fzf-lua's cached invocation context window: the window the picker was
---opened from, same role as telescope's original_win_id / snacks' picker.main.
---@return integer|nil
local function origin_win()
  local ok, ctx = pcall(function()
    return require("fzf-lua.utils").__CTX()
  end)
  return ok and ctx and ctx.winid or nil
end

---@internal
---Resume the picker right after an action ran: fzf-lua always closes the
---running fzf process before an action callback, so this approximates a
---non-disruptive "stay in place" (same defer as do_open_background).
local function resume()
  vim.defer_fn(function()
    require("fzf-lua").resume()
  end, 50)
end

---@internal
---Every path in `selected` (fzf hands over all Tab-selected lines, or just the
---current one), each run through the single-entry extractor.
---@param selected table|string|nil
---@return string[]
local function extract_all(selected)
  -- A metadata table (`{ path = ... }`) is ONE entry, a list is many lines.
  if type(selected) == "table" and (selected.path or selected.filename) then
    local path = extract(selected)
    return path and { path } or {}
  end

  local lines = type(selected) == "table" and selected or { selected }
  local paths = {}
  for _, line in ipairs(lines) do
    local path = extract(type(line) == "string" and { line } or line)
    if path then paths[#paths + 1] = path end
  end
  return paths
end

---@internal
---Path-copy entry action (see pickers.entry_actions.path_copy), then resume.
---@param fmt string
---@return fun(selected: table|string)
local function do_copy(fmt)
  return function(selected)
    path_copy.run(fmt, extract_all(selected), { win = origin_win() })
    resume()
  end
end

---@internal
---Insert the selected entries as Markdown links into the window behind the
---picker (see pickers.entry_actions.link_insert). fzf-lua has already closed
---its process before an action runs, so there is nothing to close and, unlike
---the copy actions, nothing to resume.
---@param selected table|string
local function do_link_insert(selected)
  local paths, win = extract_all(selected), origin_win()
  vim.defer_fn(function()
    link_insert.run(paths, { win = win })
  end, 50)
end

---@internal
---System entry action (see pickers.entry_actions.system) on the first
---selected entry, then resume.
---@param action "open"|"reveal"
---@return fun(selected: table|string)
local function do_system(action)
  return function(selected)
    system.run(action, extract_all(selected)[1])
    resume()
  end
end

---@internal
---@param selected table|string
local function do_open_background(selected)
  local path = extract(selected)
  if not path then
    notify.warn("No valid path found")
    return
  end
  -- No line/col here (would need to parse the raw grep-formatted entry) --
  -- best-effort.
  open_background.run(path, { win = origin_win() })
  resume()
end

---@internal
---@param selected table|string
local function do_create_file(selected)
  local path = extract(selected)
  if not path then
    notify.warn("No valid path found")
    return
  end
  -- fzf-lua's picker runs in a terminal buffer; give it time to close
  -- before showing vim.ui.input (create_file.run schedules on top of this).
  vim.defer_fn(function()
    create_file.run(path)
  end, 150)
end

---@internal
---The fixed fzf keys of the path_copy actions, keyed by path_copy format.
---@type table<string, string>
local COPY_KEYS = {
  absolute = "ctrl-y",
  dirname = "alt-y",
  env_rooted = "alt-v",
  project_root = "alt-t",
  project_relative = "alt-e",
  buffer_relative = "alt-j",
  markdown_link = "alt-l",
}

---@internal
---The fixed fzf key of the insert-link action.
local LINK_INSERT_KEY = "alt-n"

---@internal
---The fixed fzf keys of the system actions, keyed by system action.
---@type table<string, string>
local SYSTEM_KEYS = {
  open = "alt-o",
  reveal = "alt-x",
}

---@internal
---Fixed lhs (fzf bind syntax) shown for the fzf-lua rows of the cheatsheet
---panel itself — the Neovim-notation defaults `pickers.keys.resolve()` would
---otherwise report don't apply on this engine (see @description above).
---@type table<string, string>
local FZF_OVERRIDES = {
  create_file = "ctrl-a",
  open_background = "ctrl-o / shift-enter",
  cheatsheet = "f1",
}
for fmt, key in pairs(COPY_KEYS) do
  FZF_OVERRIDES[path_copy.ACTION_FOR[fmt]] = key
end
for action, key in pairs(SYSTEM_KEYS) do
  FZF_OVERRIDES[system.ACTION_FOR[action]] = key
end
FZF_OVERRIDES[link_insert.ACTION] = LINK_INSERT_KEY

local function do_cheatsheet()
  -- Let the fzf terminal buffer finish closing before opening the panel
  -- (same wait `do_create_file` gives `vim.ui.input`, see its comment).
  vim.defer_fn(function()
    require("pickers.cheatsheet").show({
      overrides = FZF_OVERRIDES,
      on_close = function()
        -- Same post-close delay `do_open_background` gives `fzf.resume()`.
        vim.defer_fn(function()
          require("fzf-lua").resume()
        end, 50)
      end,
    })
  end, 150)
end

---Build the fzf-lua `actions` table fragment for create_file/open_background/
---cheatsheet/path_copy/system.
---@return table<string, function> actions
function M.get_actions()
  if require("pickers.config").get().keys.enable == false then return {} end

  local actions = {
    ["ctrl-a"] = do_create_file,
    ["ctrl-o"] = do_open_background,
    ["shift-enter"] = do_open_background,
    ["f1"] = do_cheatsheet,
  }
  for fmt, key in pairs(COPY_KEYS) do
    actions[key] = do_copy(fmt)
  end
  actions[LINK_INSERT_KEY] = do_link_insert
  for action, key in pairs(SYSTEM_KEYS) do
    actions[key] = do_system(action)
  end
  return actions
end

return M
