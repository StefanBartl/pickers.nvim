-- pickers.nvim — unit tests (no framework, no network).
--
-- Run:
--   nvim -l docs/TESTS/pickers_spec.lua
--
-- The script derives its own runtimepath from its location and picks up
-- lib.nvim as a sibling repo (../lib.nvim) if present. Exits non-zero on
-- failure so it can be used in CI.

-- ── Self-bootstrapping runtimepath ──────────────────────────────────────────
local this = debug.getinfo(1, "S").source:sub(2) -- strip leading '@'
local tests_dir = vim.fn.fnamemodify(this, ":h")
local root = vim.fn.fnamemodify(tests_dir, ":h:h") -- docs/TESTS → repo root
vim.opt.runtimepath:append(root)

-- $LIB_NVIM_PATH is the convention shared with lib.nvim's other dependents
-- (see lib.nvim/nvim/templates/README.md); $REPOS_DIR is kept for back-compat.
local lib = vim.fn.fnamemodify(root, ":h") .. "/lib.nvim"
if vim.env.LIB_NVIM_PATH and vim.fn.isdirectory(vim.env.LIB_NVIM_PATH) == 1 then
  lib = vim.env.LIB_NVIM_PATH
elseif vim.env.REPOS_DIR and vim.fn.isdirectory(vim.env.REPOS_DIR .. "/lib.nvim") == 1 then
  lib = vim.env.REPOS_DIR .. "/lib.nvim"
end
if vim.fn.isdirectory(lib) == 1 then vim.opt.runtimepath:append(lib) end

-- ── Tiny assertion harness ──────────────────────────────────────────────────
local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
    print("  ok   " .. name)
  else
    failed = failed + 1
    print("  FAIL " .. name .. (detail and ("  → " .. detail) or ""))
  end
end
local function has(list, val)
  return vim.tbl_contains(list, val)
end

-- ── to_pascal ───────────────────────────────────────────────────────────────
do
  local util = require("pickers.bindings.util")
  check("to_pascal: notes", util.to_pascal("notes") == "Notes")
  check("to_pascal: notes_lua", util.to_pascal("notes_lua") == "NotesLua")
  check("to_pascal: a_b_c", util.to_pascal("a_b_c") == "ABC")
end

-- ── config.apply — collection normalisation & merges ────────────────────────
do
  local config = require("pickers.config")
  config.apply({
    engine = "fzf",
    collections = {
      { name = "notes", dir = "/tmp/notes" },
      { name = "", dir = "/x" }, -- invalid: empty name → dropped
      { dir = "/y" }, -- invalid: no name    → dropped
      { name = "proj", dir = "/tmp/proj", prefix = "", only_git = true },
    },
    keymaps = { cwd_grep = "<leader>zz" },
  })
  local cfg = config.get()

  check("apply: engine set", cfg.engine == "fzf", tostring(cfg.engine))
  check("apply: invalid collections dropped", #cfg.collections == 2, "#=" .. #cfg.collections)
  check("apply: first collection name", cfg.collections[1] and cfg.collections[1].name == "notes")
  check("apply: only_git normalised", cfg.collections[2] and cfg.collections[2].only_git == true)
  check("apply: prefix empty-string kept", cfg.collections[2] and cfg.collections[2].prefix == "")
  check("apply: keymap overridden", cfg.keymaps.cwd_grep == "<leader>zz")
  check("apply: keymap default kept", cfg.keymaps.config_files == "<leader>fc")

  -- find defaults (hidden/follow on, no_ignore off so .gitignore is respected)
  check("find: hidden default true", cfg.find.hidden == true)
  check("find: no_ignore default false", cfg.find.no_ignore == false)
  check("find: follow default true", cfg.find.follow == true)

  -- find override merges over defaults
  config.apply({ find = { no_ignore = true } })
  local cfg2 = config.get()
  check("find: no_ignore overridden", cfg2.find.no_ignore == true)
  check("find: hidden still default", cfg2.find.hidden == true)
end

-- ── config.apply — selected_index normalisation ─────────────────────────────
do
  local config = require("pickers.config")
  local cfg0 = config.get()
  check("selected_index: default disabled", cfg0.selected_index.enabled == false)
  check("selected_index: default position", cfg0.selected_index.position == "right_align")
  check("selected_index: default preset", cfg0.selected_index.highlight.preset == "default")

  config.apply({
    selected_index = {
      enabled = true,
      position = "right",
      highlight = { preset = "accent" },
    },
  })
  local cfg1 = config.get()
  check("selected_index: enabled overridden", cfg1.selected_index.enabled == true)
  check(
    "selected_index: 'right' normalised to 'right_align'",
    cfg1.selected_index.position == "right_align",
    tostring(cfg1.selected_index.position)
  )
  check("selected_index: preset overridden", cfg1.selected_index.highlight.preset == "accent")

  config.apply({
    selected_index = {
      position = "not_a_real_position",
      highlight = { preset = "not_a_real_preset" },
    },
  })
  local cfg2 = config.get()
  check(
    "selected_index: invalid position falls back to previous",
    cfg2.selected_index.position == "right_align",
    tostring(cfg2.selected_index.position)
  )
  check(
    "selected_index: invalid preset falls back to default",
    cfg2.selected_index.highlight.preset == "default",
    tostring(cfg2.selected_index.highlight.preset)
  )

  config.apply({
    selected_index = {
      highlight = { preset = "custom", custom = { fg = "#ff0000", bold = true, not_a_field = 1 } },
    },
  })
  local cfg3 = config.get()
  check("selected_index: custom fg kept", cfg3.selected_index.highlight.custom.fg == "#ff0000")
  check("selected_index: custom bold kept", cfg3.selected_index.highlight.custom.bold == true)
  check(
    "selected_index: unknown custom field dropped",
    cfg3.selected_index.highlight.custom.not_a_field == nil
  )

  check("selected_index: toggle_key default nil", cfg3.selected_index.toggle_key == nil)

  config.apply({ selected_index = { toggle_key = "<M-i>" } })
  local cfg4 = config.get()
  check("selected_index: toggle_key set", cfg4.selected_index.toggle_key == "<M-i>")

  config.apply({ selected_index = { toggle_key = 42 } })
  local cfg5 = config.get()
  check(
    "selected_index: invalid toggle_key type keeps previous",
    cfg5.selected_index.toggle_key == "<M-i>",
    tostring(cfg5.selected_index.toggle_key)
  )

  config.apply({ selected_index = { toggle_key = false } })
  local cfg6 = config.get()
  check("selected_index: toggle_key = false clears it", cfg6.selected_index.toggle_key == nil)
end

-- ── config.apply — history normalisation ────────────────────────────────────
do
  local config = require("pickers.config")
  local cfg0 = config.get()
  check("history: default disabled", cfg0.history.enabled == false)
  check("history: default fzf_scope", cfg0.history.fzf_scope == "plugin")
  check("history: default limit", cfg0.history.limit == 200)

  config.apply({ history = { enabled = true, fzf_scope = "patch", dir = "/tmp/hist", limit = 50 } })
  local cfg1 = config.get()
  check("history: enabled overridden", cfg1.history.enabled == true)
  check("history: fzf_scope overridden", cfg1.history.fzf_scope == "patch")
  check("history: dir overridden", cfg1.history.dir == "/tmp/hist")
  check("history: limit overridden", cfg1.history.limit == 50)

  config.apply({ history = { fzf_scope = "not_a_real_scope" } })
  local cfg2 = config.get()
  check(
    "history: invalid fzf_scope falls back to previous",
    cfg2.history.fzf_scope == "patch",
    tostring(cfg2.history.fzf_scope)
  )

  config.apply({ history = { limit = -5 } })
  local cfg3 = config.get()
  check("history: invalid limit keeps previous", cfg3.history.limit == 50, tostring(cfg3.history.limit))
end

-- ── :Pickers completion (composer) — needs lib.nvim; skip cleanly if absent ─
-- Registers the real :Pickers command (as plugin/pickers.lua would) and drives
-- its actual completion via getcompletion(), exercising the composer route
-- tree end-to-end rather than a since-removed pure-function shim.
do
  local ok, cmp = pcall(require, "pickers.command.composer")
  if not ok then
    print("  skip :Pickers completion tests (lib.nvim not on runtimepath)")
  else
    cmp.register(require("pickers.config").get())

    local scopes = vim.fn.getcompletion("Pickers ", "cmdline")
    check("complete: built-in cwd", has(scopes, "cwd"))
    check("complete: built-in config", has(scopes, "config"))
    check("complete: collection notes", has(scopes, "notes"))

    local acts = vim.fn.getcompletion("Pickers cwd ", "cmdline")
    check("complete: action files", has(acts, "files"))
    check("complete: action grep", has(acts, "grep"))

    local filtered = vim.fn.getcompletion("Pickers co", "cmdline")
    check("complete: filter 'co' includes config", has(filtered, "config"))
    check("complete: filter 'co' excludes cwd", not has(filtered, "cwd"))
  end
end

-- ── sources.repos — list_names / resolve / complete; needs lib.nvim ─────────
do
  local ok, repos = pcall(require, "pickers.sources.repos")
  if not ok then
    print("  skip sources.repos tests (lib.nvim not on runtimepath)")
  else
    local config = require("pickers.config")

    local base = vim.fn.tempname()
    vim.fn.mkdir(base, "p")
    vim.fn.mkdir(base .. "/lib.nvim/.git", "p")
    vim.fn.mkdir(base .. "/markdown.nvim/.git", "p")
    vim.fn.mkdir(base .. "/not_a_repo", "p") -- no .git → excluded

    config.apply({ repos_dir = base })
    local cfg = config.get()

    local names = repos.list_names(cfg)
    check("repos.list_names: finds lib.nvim", has(names, "lib.nvim"))
    check("repos.list_names: finds markdown.nvim", has(names, "markdown.nvim"))
    check("repos.list_names: excludes non-git dirs", not has(names, "not_a_repo"))

    check("repos.resolve: known repo", repos.resolve(cfg, "lib.nvim") ~= nil)
    check("repos.resolve: unknown repo", repos.resolve(cfg, "nope") == nil)
    check("repos.resolve: non-git dir", repos.resolve(cfg, "not_a_repo") == nil)

    local completed = repos.complete("lib")
    check("repos.complete: prefix match", has(completed, "lib.nvim"))
    check("repos.complete: prefix excludes non-match", not has(completed, "markdown.nvim"))

    vim.fn.delete(base, "rf")
  end
end

-- ── pickers.history — dir / telescope_opts / fzf_path / fzf_opts ────────────
do
  local config = require("pickers.config")
  local history = require("pickers.history")

  local base = vim.fn.tempname()
  config.apply({ history = { enabled = true, dir = base, limit = 42 } })
  local cfg = config.get()

  local dir = history.dir(cfg)
  check("history.dir: uses override", dir == vim.fs.normalize(base), dir)
  check("history.dir: creates the directory", vim.fn.isdirectory(dir) == 1)

  local topts = history.telescope_opts(cfg)
  check("history.telescope_opts: path under dir", topts.path == dir .. "/telescope.txt", topts.path)
  check("history.telescope_opts: limit passed through", topts.limit == 42)

  check(
    "history.fzf_path: per-kind file",
    history.fzf_path(cfg, "files") == dir .. "/fzf_files.txt"
  )
  check(
    "history.fzf_path: differs per kind",
    history.fzf_path(cfg, "grep") ~= history.fzf_path(cfg, "files")
  )

  local fopts = history.fzf_opts(cfg)
  check("history.fzf_opts: unified history file", fopts["--history"] == dir .. "/fzf_global.txt")

  vim.fn.delete(base, "rf")
end

-- ── selected_index.debounce — thin adapter over lib.nvim.debounce ───────────
do
  local ok, debounce = pcall(require, "pickers.selected_index.debounce")
  if not ok then
    print("  skip selected_index.debounce tests (lib.nvim not on runtimepath)")
  else
    local calls = {}
    local fn, cleanup = debounce.debounce(function(v)
      calls[#calls + 1] = v
    end, 20)

    fn("a")
    fn("b") -- resets the timer; only "b" should fire
    vim.wait(200, function() return #calls > 0 end)

    check("debounce: fires exactly once", #calls == 1, "#=" .. #calls)
    check("debounce: fires with the most recent args", calls[1] == "b", tostring(calls[1]))
    check("debounce: cleanup is callable", type(cleanup) == "function")
    cleanup() -- must not error when idle
  end
end

-- ── Summary ─────────────────────────────────────────────────────────────────
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
