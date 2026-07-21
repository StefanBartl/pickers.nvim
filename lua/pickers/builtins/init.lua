---@module 'pickers.builtins'
---@brief Registry of native picker-engine builtins (buffers, LSP, git, marks,
---diagnostics, ...), dispatched to whichever engine `pickers.engines.load()`
---resolves. Complements the `:Pickers <scope> <action>` layer, which only
---knows plain files/grep -- this is "everything else the engine ships out
---of the box", reached via `:Pickers builtin <name>`.
---@description
--- Deliberately excludes plain files/grep (already covered by `:Pickers cwd
--- files/grep` etc.) and non-picker features (`explorer`, `dashboard`,
--- `notifications`). Every mapping below was verified against the actually
--- installed plugin sources, not guessed from docs -- see docs/BUILTINS.md
--- for the full parity matrix and per-entry rationale for `false` gaps.

local notify = require("lib.nvim.notify").create("[pickers.builtins]")

---@alias Pickers.Builtins.EngineName "telescope"|"fzf"|"snacks"

---@class Pickers.Builtins.Entry
---@field telescope string|false  Function name in `telescope.builtin`, or false if unsupported.
---@field fzf       string|false  Function name in `fzf-lua` (`require("fzf-lua")`), or false.
---@field snacks    string|false  Source name in `snacks.picker`, or false.

local M = {}

---@type table<string, Pickers.Builtins.Entry>
M.REGISTRY = {
  -- ── General nvim introspection ─────────────────────────────────────────
  buffers          = { telescope = "buffers",         fzf = "buffers",         snacks = "buffers" },
  -- Engines disagree on naming: snacks calls this "recent", not "oldfiles".
  oldfiles         = { telescope = "oldfiles",        fzf = "oldfiles",        snacks = "recent" },
  help             = { telescope = "help_tags",       fzf = "helptags",        snacks = "help" },
  man_pages        = { telescope = "man_pages",       fzf = "manpages",        snacks = "man" },
  marks            = { telescope = "marks",           fzf = "marks",           snacks = "marks" },
  jumps            = { telescope = "jumplist",        fzf = "jumps",           snacks = "jumps" },
  registers        = { telescope = "registers",       fzf = "registers",       snacks = "registers" },
  keymaps          = { telescope = "keymaps",         fzf = "keymaps",         snacks = "keymaps" },
  commands         = { telescope = "commands",        fzf = "commands",        snacks = "commands" },
  command_history  = { telescope = "command_history", fzf = "command_history", snacks = "command_history" },
  search_history   = { telescope = "search_history",  fzf = "search_history",  snacks = "search_history" },
  autocmds         = { telescope = "autocommands",    fzf = "autocmds",        snacks = "autocmds" },
  highlights       = { telescope = "highlights",      fzf = "highlights",      snacks = "highlights" },
  -- snacks has no filetype picker.
  filetypes        = { telescope = "filetypes",       fzf = "filetypes",       snacks = false },
  colorschemes     = { telescope = "colorscheme",     fzf = "colorschemes",    snacks = "colorschemes" },
  -- snacks has no spell-suggest picker.
  spell_suggest    = { telescope = "spell_suggest",   fzf = "spell_suggest",   snacks = false },
  quickfix         = { telescope = "quickfix",        fzf = "quickfix",        snacks = "qflist" },
  loclist          = { telescope = "loclist",         fzf = "loclist",         snacks = "loclist" },
  treesitter       = { telescope = "treesitter",      fzf = "treesitter",      snacks = "treesitter" },
  resume           = { telescope = "resume",          fzf = false,             snacks = "resume" },
  -- telescope has no undo-tree picker.
  undo             = { telescope = false,             fzf = "undotree",        snacks = "undo" },
  -- snacks-only: icon picker, lazy.nvim plugin-spec picker.
  icons            = { telescope = false,             fzf = false,            snacks = "icons" },
  lazy_specs       = { telescope = false,             fzf = false,            snacks = "lazy" },
  -- Search word/WORD under cursor: same idea, different names per engine.
  grep_word        = { telescope = "grep_string",     fzf = "grep_cword",      snacks = "grep_word" },

  -- ── Git ─────────────────────────────────────────────────────────────────
  git_files        = { telescope = "git_files",       fzf = "git_files",       snacks = "git_files" },
  git_status       = { telescope = "git_status",      fzf = "git_status",      snacks = "git_status" },
  -- snacks has no per-file bcommits picker.
  git_bcommits     = { telescope = "git_bcommits",    fzf = "git_bcommits",    snacks = false },
  -- snacks calls its commit-log picker "git_log", not "git_commits".
  git_commits      = { telescope = "git_commits",     fzf = "git_commits",     snacks = "git_log" },
  git_branches     = { telescope = "git_branches",    fzf = "git_branches",    snacks = "git_branches" },
  git_stash        = { telescope = "git_stash",       fzf = "git_stash",       snacks = "git_stash" },
  -- telescope has no diff picker.
  git_diff         = { telescope = false,             fzf = "git_diff",       snacks = "git_diff" },
  -- snacks-only: per-line git blame/log picker.
  git_log_line     = { telescope = false,             fzf = false,            snacks = "git_log_line" },

  -- ── LSP ─────────────────────────────────────────────────────────────────
  lsp_references          = { telescope = "lsp_references",        fzf = "lsp_references",        snacks = "lsp_references" },
  lsp_definitions         = { telescope = "lsp_definitions",       fzf = "lsp_definitions",        snacks = "lsp_definitions" },
  -- telescope has no separate declarations picker (folded into definitions upstream).
  lsp_declarations        = { telescope = false,                   fzf = "lsp_declarations",       snacks = "lsp_declarations" },
  lsp_implementations     = { telescope = "lsp_implementations",   fzf = "lsp_implementations",    snacks = "lsp_implementations" },
  -- fzf-lua's name is "lsp_typedefs", not "lsp_type_definitions".
  lsp_type_definitions    = { telescope = "lsp_type_definitions",  fzf = "lsp_typedefs",           snacks = "lsp_type_definitions" },
  -- snacks folds document/workspace symbols into one "lsp_symbols" source.
  lsp_document_symbols    = { telescope = "lsp_document_symbols",  fzf = "lsp_document_symbols",   snacks = "lsp_symbols" },
  lsp_workspace_symbols   = { telescope = "lsp_workspace_symbols", fzf = "lsp_workspace_symbols",  snacks = "lsp_symbols" },
  lsp_incoming_calls      = { telescope = "lsp_incoming_calls",    fzf = "lsp_incoming_calls",     snacks = "lsp_incoming_calls" },
  lsp_outgoing_calls      = { telescope = "lsp_outgoing_calls",    fzf = "lsp_outgoing_calls",     snacks = "lsp_outgoing_calls" },

  -- ── Diagnostics ─────────────────────────────────────────────────────────
  -- telescope/fzf use the same picker for both scopes, toggled via opts
  -- (telescope: `bufnr = 0`; fzf: document vs workspace function name).
  diagnostics             = { telescope = "diagnostics", fzf = "diagnostics_workspace", snacks = "diagnostics" },
  diagnostics_buffer      = { telescope = "diagnostics", fzf = "diagnostics_document",  snacks = "diagnostics_buffer" },

  -- ── GitHub / project (snacks-only) ─────────────────────────────────────
  gh_issue                = { telescope = false, fzf = false, snacks = "gh_issue" },
  gh_pr                   = { telescope = false, fzf = false, snacks = "gh_pr" },
  projects                = { telescope = false, fzf = false, snacks = "projects" },
}

---Sorted list of registered builtin names, for tab-completion and docs.
---@return string[]
function M.names()
  local out = {}
  for name in pairs(M.REGISTRY) do
    out[#out + 1] = name
  end
  table.sort(out)
  return out
end

---@param engine_name Pickers.Builtins.EngineName
---@param fn_name string
---@param opts table|nil
local function call(engine_name, fn_name, opts)
  if engine_name == "telescope" then
    require("telescope.builtin")[fn_name](opts)
  elseif engine_name == "fzf" then
    require("fzf-lua")[fn_name](opts)
  elseif engine_name == "snacks" then
    require("snacks.picker")[fn_name](opts)
  end
end

---Run a registered builtin picker with whichever engine is currently resolved.
---@param name string
---@param opts table|nil
function M.run(name, opts)
  local entry = M.REGISTRY[name]
  if not entry then
    notify.error(string.format("Unknown builtin %q. See docs/BUILTINS.md for the list.", name))
    return
  end

  local engine, engine_name = require("pickers.engines").load()
  if not engine or not engine_name then return end

  local fn_name = entry[engine_name]
  if not fn_name then
    notify.warn(string.format("Builtin %q has no %s equivalent — see docs/BUILTINS.md", name, engine_name))
    return
  end

  call(engine_name, fn_name, opts)
end

return M
