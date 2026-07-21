---@module 'pickers.builtins'
---@brief Registry of native pickers (git/lsp/search/…) — one name, per-engine
---implementation, dispatched by the currently resolved engine.
---@description
--- These are NOT scope×action pickers like `pickers.actions.files/grep` — each
--- entry calls straight into the engine's own native picker function
--- (`Snacks.picker.git_branches()`, `telescope.builtin.git_branches()`,
--- `fzf-lua.git_branches()`, …), bypassing pickers.nvim's roots/find-flags
--- resolution entirely. Exposed as `:Pickers builtin <name>`.
---
--- Every entry name → function-name mapping below was verified against the
--- actual installed plugin sources (not guessed from docs), because the three
--- engines frequently disagree on naming (snacks `recent` / telescope
--- `oldfiles` / fzf-lua `oldfiles`; snacks `man` / telescope `man_pages` / fzf
--- `manpages`; …) and on capability (telescope has no `git_diff` hunks picker
--- and no `lsp_declarations`; neither telescope nor fzf-lua wrap GitHub
--- issues/PRs or per-line git log). A `false` entry is such a documented gap,
--- not an oversight — see docs/BUILTINS.md for the full parity matrix.
---
--- `entry.telescope/fzf/snacks` opts (when present) are defaults merged
--- *underneath* whatever opts `run()` is called with, so callers can always
--- override (e.g. `grep_buffers` needs `grep_open_files = true` on telescope's
--- `live_grep`, but a caller passing their own `grep_open_files` wins).

local notify = require("lib.nvim.notify").create("[pickers.builtins]")

local M = {}

---@type table<string, Pickers.Builtins.Entry>
M.REGISTRY = {
  -- ── Find ──────────────────────────────────────────────────────────────────
  command_history = {
    desc = "Command-line history",
    snacks = { fn = "command_history" },
    telescope = { fn = "command_history" },
    fzf = { fn = "command_history" },
  },
  recent = {
    desc = "Recently opened files",
    snacks = { fn = "recent" },
    telescope = { fn = "oldfiles" },
    fzf = { fn = "oldfiles" },
  },
  projects = {
    desc = "Recent projects (snacks-only — no telescope/fzf-lua equivalent; "
      .. "consider a pickers.nvim collection over repos_dir instead)",
    snacks = { fn = "projects" },
    telescope = false,
    fzf = false,
  },
  notifications = {
    desc = "Notification history (snacks-only — vim.notify history is a "
      .. "snacks.nvim feature; telescope/fzf-lua have no equivalent picker)",
    snacks = { fn = "notifications" },
    telescope = false,
    fzf = false,
  },

  -- ── Git ───────────────────────────────────────────────────────────────────
  git_branches = {
    desc = "Git branches",
    snacks = { fn = "git_branches" },
    telescope = { fn = "git_branches" },
    fzf = { fn = "git_branches" },
  },
  git_log = {
    desc = "Git log (repo-wide commits)",
    snacks = { fn = "git_log" },
    telescope = { fn = "git_commits" },
    fzf = { fn = "git_commits" },
  },
  git_log_file = {
    desc = "Git log for the current file",
    snacks = { fn = "git_log_file" },
    telescope = { fn = "git_bcommits" },
    fzf = { fn = "git_bcommits" },
  },
  git_log_line = {
    desc = "Git log for the current line (snacks-only — telescope/fzf-lua have "
      .. "no per-line `git log -L` picker)",
    snacks = { fn = "git_log_line" },
    telescope = false,
    fzf = false,
  },
  git_status = {
    desc = "Git status",
    snacks = { fn = "git_status" },
    telescope = { fn = "git_status" },
    fzf = { fn = "git_status" },
  },
  git_stash = {
    desc = "Git stash",
    snacks = { fn = "git_stash" },
    telescope = { fn = "git_stash" },
    fzf = { fn = "git_stash" },
  },
  git_diff = {
    desc = "Git diff (hunks) — telescope has no dedicated hunks picker "
      .. "(only per-commit diff previews on git_commits/git_bcommits)",
    snacks = { fn = "git_diff" },
    telescope = false,
    fzf = { fn = "git_diff" },
  },

  -- ── GitHub (snacks-only: no telescope/fzf-lua core equivalent) ───────────
  gh_issue = {
    desc = "GitHub issues, open (snacks-only)",
    snacks = { fn = "gh_issue" },
    telescope = false,
    fzf = false,
  },
  gh_issue_all = {
    desc = "GitHub issues, all states (snacks-only)",
    snacks = { fn = "gh_issue", opts = { state = "all" } },
    telescope = false,
    fzf = false,
  },
  gh_pr = {
    desc = "GitHub pull requests, open (snacks-only)",
    snacks = { fn = "gh_pr" },
    telescope = false,
    fzf = false,
  },
  gh_pr_all = {
    desc = "GitHub pull requests, all states (snacks-only)",
    snacks = { fn = "gh_pr", opts = { state = "all" } },
    telescope = false,
    fzf = false,
  },

  -- ── Buffers / files ───────────────────────────────────────────────────────
  buffers = {
    desc = "Open buffers",
    snacks = { fn = "buffers" },
    telescope = { fn = "buffers" },
    fzf = { fn = "buffers" },
  },
  git_files = {
    desc = "Git-tracked files (ls-files)",
    snacks = { fn = "git_files" },
    telescope = { fn = "git_files" },
    fzf = { fn = "git_files" },
  },

  -- ── Vim / editor state ────────────────────────────────────────────────────
  marks = {
    desc = "Marks",
    snacks = { fn = "marks" },
    telescope = { fn = "marks" },
    fzf = { fn = "marks" },
  },
  jumps = {
    desc = "Jump list",
    snacks = { fn = "jumps" },
    telescope = { fn = "jumplist" },
    fzf = { fn = "jumps" },
  },
  registers = {
    desc = "Registers",
    snacks = { fn = "registers" },
    telescope = { fn = "registers" },
    fzf = { fn = "registers" },
  },
  quickfix = {
    desc = "Quickfix list",
    snacks = { fn = "qflist" },
    telescope = { fn = "quickfix" },
    fzf = { fn = "quickfix" },
  },
  loclist = {
    desc = "Location list",
    snacks = { fn = "loclist" },
    telescope = { fn = "loclist" },
    fzf = { fn = "loclist" },
  },
  autocmds = {
    desc = "Autocommands",
    snacks = { fn = "autocmds" },
    telescope = { fn = "autocommands" },
    fzf = { fn = "autocmds" },
  },
  highlights = {
    desc = "Highlight groups",
    snacks = { fn = "highlights" },
    telescope = { fn = "highlights" },
    fzf = { fn = "highlights" },
  },
  filetypes = {
    desc = "Filetypes (snacks has no filetype picker)",
    snacks = false,
    telescope = { fn = "filetypes" },
    fzf = { fn = "filetypes" },
  },
  spell_suggest = {
    desc = "Spelling suggestions for the word under the cursor (snacks has no equivalent)",
    snacks = false,
    telescope = { fn = "spell_suggest" },
    fzf = { fn = "spell_suggest" },
  },
  search_history = {
    desc = "Search (/) history",
    snacks = { fn = "search_history" },
    telescope = { fn = "search_history" },
    fzf = { fn = "search_history" },
  },
  treesitter = {
    desc = "Treesitter symbols in the current buffer",
    snacks = { fn = "treesitter" },
    telescope = { fn = "treesitter" },
    fzf = { fn = "treesitter" },
  },
  resume = {
    desc = "Resume the last picker (fzf-lua has no resume concept)",
    snacks = { fn = "resume" },
    telescope = { fn = "resume" },
    fzf = false,
  },
  undo = {
    desc = "Undo tree (telescope has no undo-tree picker)",
    snacks = { fn = "undo" },
    telescope = false,
    fzf = { fn = "undotree" },
  },
  icons = {
    desc = "Icon picker (snacks-only)",
    snacks = { fn = "icons" },
    telescope = false,
    fzf = false,
  },
  lazy_specs = {
    desc = "lazy.nvim plugin specs (snacks-only)",
    snacks = { fn = "lazy" },
    telescope = false,
    fzf = false,
  },
  grep_word = {
    desc = "Grep the word under the cursor",
    snacks = { fn = "grep_word" },
    telescope = { fn = "grep_string" },
    fzf = { fn = "grep_cword" },
  },

  -- ── Diagnostics ───────────────────────────────────────────────────────────
  diagnostics = {
    desc = "Diagnostics (workspace-wide)",
    snacks = { fn = "diagnostics" },
    telescope = { fn = "diagnostics" },
    fzf = { fn = "diagnostics_workspace" },
  },
  diagnostics_buffer = {
    desc = "Diagnostics (current buffer only)",
    snacks = { fn = "diagnostics_buffer" },
    telescope = { fn = "diagnostics", opts = { bufnr = 0 } },
    fzf = { fn = "diagnostics_document" },
  },

  -- ── Buffer search ─────────────────────────────────────────────────────────
  lines = {
    desc = "Fuzzy-find lines in the current buffer",
    snacks = { fn = "lines" },
    telescope = { fn = "current_buffer_fuzzy_find" },
    fzf = { fn = "blines" },
  },
  grep_buffers = {
    desc = "Grep across all open buffers",
    snacks = { fn = "grep_buffers" },
    telescope = { fn = "live_grep", opts = { grep_open_files = true } },
    fzf = { fn = "lines" },
  },

  -- ── Search / meta ─────────────────────────────────────────────────────────
  commands = {
    desc = "Ex commands",
    snacks = { fn = "commands" },
    telescope = { fn = "commands" },
    fzf = { fn = "commands" },
  },
  keymaps = {
    desc = "Keymaps",
    snacks = { fn = "keymaps" },
    telescope = { fn = "keymaps" },
    fzf = { fn = "keymaps" },
  },
  man = {
    desc = "Man pages",
    snacks = { fn = "man" },
    telescope = { fn = "man_pages" },
    fzf = { fn = "manpages" },
  },
  help = {
    desc = "Help tags",
    snacks = { fn = "help" },
    telescope = { fn = "help_tags" },
    fzf = { fn = "helptags" },
  },
  colorschemes = {
    desc = "Colorschemes",
    snacks = { fn = "colorschemes" },
    telescope = { fn = "colorscheme" },
    fzf = { fn = "colorschemes" },
  },

  -- ── LSP ───────────────────────────────────────────────────────────────────
  lsp_definitions = {
    desc = "LSP: goto definition",
    snacks = { fn = "lsp_definitions" },
    telescope = { fn = "lsp_definitions" },
    fzf = { fn = "lsp_definitions" },
  },
  lsp_declarations = {
    desc = "LSP: goto declaration (telescope has no dedicated picker for this — "
      .. "only `vim.lsp.buf.declaration()`, not a list)",
    snacks = { fn = "lsp_declarations" },
    telescope = false,
    fzf = { fn = "lsp_declarations" },
  },
  lsp_references = {
    desc = "LSP: references",
    snacks = { fn = "lsp_references" },
    telescope = { fn = "lsp_references" },
    fzf = { fn = "lsp_references" },
  },
  lsp_implementations = {
    desc = "LSP: implementations",
    snacks = { fn = "lsp_implementations" },
    telescope = { fn = "lsp_implementations" },
    fzf = { fn = "lsp_implementations" },
  },
  lsp_type_definitions = {
    desc = "LSP: type definitions",
    snacks = { fn = "lsp_type_definitions" },
    telescope = { fn = "lsp_type_definitions" },
    fzf = { fn = "lsp_typedefs" },
  },
  lsp_incoming_calls = {
    desc = "LSP: incoming calls",
    snacks = { fn = "lsp_incoming_calls" },
    telescope = { fn = "lsp_incoming_calls" },
    fzf = { fn = "lsp_incoming_calls" },
  },
  lsp_outgoing_calls = {
    desc = "LSP: outgoing calls",
    snacks = { fn = "lsp_outgoing_calls" },
    telescope = { fn = "lsp_outgoing_calls" },
    fzf = { fn = "lsp_outgoing_calls" },
  },
  lsp_symbols = {
    desc = "LSP: document symbols",
    snacks = { fn = "lsp_symbols" },
    telescope = { fn = "lsp_document_symbols" },
    fzf = { fn = "lsp_document_symbols" },
  },
  lsp_workspace_symbols = {
    desc = "LSP: workspace symbols",
    snacks = { fn = "lsp_workspace_symbols" },
    telescope = { fn = "lsp_workspace_symbols" },
    fzf = { fn = "lsp_workspace_symbols" },
  },
}

--- Module for the `require(module)[fn](opts)` call per engine.
---@type table<string, string>
local ENGINE_MODULE = {
  snacks = "snacks",
  telescope = "telescope.builtin",
  fzf = "fzf-lua",
}

--- Sorted list of every registered builtin name — used for `:Pickers builtin
--- <Tab>` completion and for completeness tests.
---@return string[]
function M.names()
  local out = {}
  for name in pairs(M.REGISTRY) do
    out[#out + 1] = name
  end
  table.sort(out)
  return out
end

--- Which engines have a real (non-gap) implementation for `name`.
---@param name string
---@return string[]
function M.supported_engines(name)
  local entry = M.REGISTRY[name]
  if not entry then return {} end
  local out = {}
  for _, engine in ipairs({ "snacks", "telescope", "fzf" }) do
    if entry[engine] then out[#out + 1] = engine end
  end
  return out
end

--- Run a registered builtin on the currently resolved engine.
---@param name string
---@param opts table|nil  Passed straight to the engine's native function,
---overriding the entry's own default opts (if any).
---@param engine_name string|nil  Override which engine to dispatch to; nil →
---resolve via `pickers.engines.load()` (respects `cfg.engine`/auto-detect).
function M.run(name, opts, engine_name)
  local entry = M.REGISTRY[name]
  if not entry then
    notify.error(
      "Unknown builtin '" .. tostring(name) .. "'. Run :Pickers builtin <Tab> to list them."
    )
    return
  end

  if not engine_name then
    local _, resolved = require("pickers.engines").load()
    engine_name = resolved
  end
  if not engine_name then return end -- engines.load() already reported the error

  local impl = entry[engine_name]
  if not impl then
    local supported = M.supported_engines(name)
    notify.warn(
      ("'%s' has no %s implementation (supported: %s) — %s"):format(
        name,
        engine_name,
        #supported > 0 and table.concat(supported, ", ") or "none",
        entry.desc
      )
    )
    return
  end

  local mod_name = ENGINE_MODULE[engine_name]
  local ok, mod = pcall(require, mod_name)
  if not ok then
    notify.error(mod_name .. " unavailable")
    return
  end

  local call_opts = vim.tbl_deep_extend("force", impl.opts or {}, opts or {})
  local call_ok, err = pcall(mod[impl.fn], call_opts)
  if not call_ok then
    notify.error(
      ("builtin '%s' (%s.%s) error: %s"):format(name, engine_name, impl.fn, tostring(err))
    )
  end
end

return M
