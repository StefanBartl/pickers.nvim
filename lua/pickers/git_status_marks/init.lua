---@module 'pickers.git_status_marks'
---@brief A "marks"-style list of uncommitted files (staged/unstaged/both), on
---the engine's own item picker, with the filter switchable at the top of the
---list.
---@description
--- Data source: `lib.nvim.git.status_porcelain` (`git status --porcelain -z
--- -u`, already parsed into a `path -> {code, orig_path}` map) -- the SAME
--- helper gitsuite.nvim's own `features.status` and filetree.nvim's
--- `features.git.git_status` decoration already build on, not a second
--- porcelain parser. Nothing here shells out to git directly.
---
--- Distinct from the existing `git_status` builtin (`builtins/init.lua`),
--- which dispatches straight into the engine's OWN native status picker
--- (`Snacks.picker.git_status()` and friends -- typically diff-preview
--- focused, no staged/unstaged split). This module builds its own item list
--- instead, the same "engine-agnostic list on `pick_item`" shape `pickers.
--- browse` already uses, because a staged/unstaged/both filter that reopens
--- the list is not something any of the three engines' native git-status
--- picker exposes as an option.
---
--- The filter is three rows AT THE TOP of the list (`[x] show: ...`), not a
--- raw keypress: `pick_item()` has no per-call custom-keymap hook on any of
--- the three engines (snacks' `Picker.select` in particular is deliberately
--- minimal, see its own module doc), and `pickers.browse` already estab-
--- lishes "extra rows that reopen the list" as this codebase's answer to
--- "toggle a picker's own state without leaving it" -- reused here rather
--- than inventing a second mechanism.
---
--- Selecting a file row opens it (`vim.cmd.edit`), the plain picker default.
--- `pickers.entry_actions` (`[a`/`]a`/`[e`/`ML`, …) apply automatically, the
--- same as any other `pick_item()`-based list in this plugin -- the nvim-
--- config's own telescope/fzf-lua/snacks setup merges those in globally, not
--- per picker instance.

local notify = require("lib.nvim.notify").create("[pickers.git_status_marks]")

local M = {}

---@alias Pickers.GitStatusMarks.Filter "all"|"staged"|"unstaged"

---@type Pickers.GitStatusMarks.Filter[]
M.FILTER_ORDER = { "all", "staged", "unstaged" }

---@type table<Pickers.GitStatusMarks.Filter, string>
M.FILTER_LABELS = {
  all = "both (staged + unstaged)",
  staged = "staged only",
  unstaged = "unstaged only",
}

-- ── pure classification ──────────────────────────────────────────────────────

---Whether a two-character `git status --porcelain` code has a staged
---(index) change -- column X set to anything but blank/`?`.
---@param code string
---@return boolean
function M.is_staged(code)
  local x = code:sub(1, 1)
  return x ~= " " and x ~= "?"
end

---Whether `code` has an unstaged (worktree) change -- column Y set to
---anything but blank. An untracked file (`??`) counts as unstaged: it has no
---index entry at all, so "staged only" correctly excludes it.
---@param code string
---@return boolean
function M.is_unstaged(code)
  return code:sub(2, 2) ~= " "
end

---Whether `code` passes `filter`. `"all"` (and any unrecognised filter,
---defensively) never excludes anything.
---@param code string
---@param filter Pickers.GitStatusMarks.Filter
---@return boolean
function M.matches_filter(code, filter)
  if filter == "staged" then return M.is_staged(code) end
  if filter == "unstaged" then return M.is_unstaged(code) end
  return true
end

-- ── pure list building ───────────────────────────────────────────────────────

---@class Pickers.GitStatusMarks.Row
---@field path string       Repo-root-relative path.
---@field code string       Two-character XY status.
---@field orig_path string|nil  Source path of a rename/copy.

---Filter `map` (a `Lib.Git.StatusMap`) down to `filter`, sorted by path.
---Pure -- takes an already-parsed status map, so it is testable with a
---fixture, no git process and no repo needed.
---@param map table<string, { code: string, orig_path: string|nil }>
---@param filter Pickers.GitStatusMarks.Filter
---@return Pickers.GitStatusMarks.Row[]
function M.build_rows(map, filter)
  local out = {}
  for path, entry in pairs(map or {}) do
    if M.matches_filter(entry.code, filter) then
      out[#out + 1] = { path = path, code = entry.code, orig_path = entry.orig_path }
    end
  end
  table.sort(out, function(a, b)
    return a.path < b.path
  end)
  return out
end

---`rows` (repo-root-relative) into `Pickers.Item`s (`text`, `file` for the
---preview, plus `path`/`code`/`kind` riding along for `on_select`). Pure --
---string joins only, no filesystem access.
---@param rows Pickers.GitStatusMarks.Row[]
---@param repo_root string
---@return table[] # Pickers.Item[], each also carrying kind="file"
function M.to_items(rows, repo_root)
  local out = {}
  for _, row in ipairs(rows) do
    out[#out + 1] = {
      text = ("[%s] %s"):format(row.code, row.path),
      file = repo_root .. "/" .. row.path,
      path = row.path,
      code = row.code,
      kind = "file",
    }
  end
  return out
end

---The three filter-toggle rows shown at the top of the list, current one
---marked. Pure.
---@param current Pickers.GitStatusMarks.Filter
---@param root string|nil  Repo root, carried as `path` (see below). Omitted
---by the pure classification tests above, which don't exercise entry_actions.
---@return table[] # Pickers.Item[], each also carrying kind="toggle"/filter
function M.toggle_rows(current, root)
  local out = {}
  for _, f in ipairs(M.FILTER_ORDER) do
    local mark = (f == current) and "x" or " "
    out[#out + 1] = {
      text = ("[%s] show: %s"):format(mark, M.FILTER_LABELS[f]),
      kind = "toggle",
      filter = f,
      -- A real, harmless path -- same "give every row its own path" precedent
      -- pickers.browse's own action rows use (`path = dir`). Without this, a
      -- pickers.entry_actions key (`[a`/copy_absolute, …) fired on a toggle
      -- row falls through extract.snacks' `item.text` fallback and copies
      -- this row's DISPLAY LABEL ("[ ] show: staged only") as if it were a
      -- path, instead of warning "No valid path found".
      path = root,
    }
  end
  return out
end

-- ── the picker ───────────────────────────────────────────────────────────────

---@class Pickers.GitStatusMarks.Opts
---@field engine_mod? table
---@field dir? string  Git dir/cwd to query (`git -C <dir> status ...`). Defaults to the cwd.
---@field filter? Pickers.GitStatusMarks.Filter  Defaults to "all".

---Open the list on `opts.engine_mod` (default: the resolved engine).
---@param opts Pickers.GitStatusMarks.Opts|nil
function M.open(opts)
  opts = opts or {}
  local engine_mod = opts.engine_mod or require("pickers.engines").load()
  if not engine_mod then return end

  local dir = opts.dir or vim.uv.cwd() or vim.fn.getcwd()
  local filter = opts.filter
  if not M.FILTER_LABELS[filter] then filter = "all" end

  local git = require("lib.nvim.git")
  local root = git.repo_root({ dir = dir })
  if not root then
    notify.warn("git status: not inside a git repository")
    return
  end

  local map, err = git.status_porcelain({ dir = dir })
  if not map then
    notify.error("git status: " .. tostring(err or "failed"))
    return
  end

  local rows = M.build_rows(map, filter)
  if #rows == 0 then notify.info("git status: no " .. M.FILTER_LABELS[filter] .. " changes") end

  local items = M.toggle_rows(filter, root)
  vim.list_extend(items, M.to_items(rows, root))

  engine_mod.pick_item({
    prompt = "Git status — " .. M.FILTER_LABELS[filter],
    items = items,
    on_select = function(item)
      if type(item) ~= "table" then return end
      if item.kind == "toggle" then
        M.open({ engine_mod = engine_mod, dir = dir, filter = item.filter })
      elseif item.kind == "file" then
        vim.cmd.edit(vim.fn.fnameescape(item.file))
      end
    end,
  })
end

return M
