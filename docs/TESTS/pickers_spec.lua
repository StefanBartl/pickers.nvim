-- pickers.nvim — unit tests (no framework, no network).
--
-- Run:
--   nvim -l docs/TESTS/pickers_spec.lua
--
-- The script derives its own runtimepath from its location and picks up
-- lib.nvim as a sibling repo (../lib.nvim) if present. Exits non-zero on
-- failure so it can be used in CI.

-- ── Self-bootstrapping runtimepath ──────────────────────────────────────────
local this      = debug.getinfo(1, "S").source:sub(2) -- strip leading '@'
local tests_dir = vim.fn.fnamemodify(this, ":h")
local root      = vim.fn.fnamemodify(tests_dir, ":h:h") -- docs/TESTS → repo root
vim.opt.runtimepath:append(root)

local lib = vim.fn.fnamemodify(root, ":h") .. "/lib.nvim"
if vim.env.REPOS_DIR and vim.fn.isdirectory(vim.env.REPOS_DIR .. "/lib.nvim") == 1 then
  lib = vim.env.REPOS_DIR .. "/lib.nvim"
end
if vim.fn.isdirectory(lib) == 1 then
  vim.opt.runtimepath:append(lib)
end

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
local function has(list, val) return vim.tbl_contains(list, val) end

-- ── to_pascal ───────────────────────────────────────────────────────────────
do
  local util = require("pickers.bindings.util")
  check("to_pascal: notes",     util.to_pascal("notes") == "Notes")
  check("to_pascal: notes_lua", util.to_pascal("notes_lua") == "NotesLua")
  check("to_pascal: a_b_c",     util.to_pascal("a_b_c") == "ABC")
end

-- ── config.apply — collection normalisation & merges ────────────────────────
do
  local config = require("pickers.config")
  config.apply({
    engine = "fzf",
    collections = {
      { name = "notes", dir = "/tmp/notes" },
      { name = "",      dir = "/x" },       -- invalid: empty name → dropped
      { dir = "/y" },                        -- invalid: no name    → dropped
      { name = "proj",  dir = "/tmp/proj", prefix = "", only_git = true },
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

-- ── command.complete — needs lib.nvim; skip cleanly if absent ───────────────
do
  local ok, cmd = pcall(require, "pickers.command")
  if not ok then
    print("  skip command.complete tests (lib.nvim not on runtimepath)")
  else
    local scopes = cmd.complete("", "Pickers ", 0)
    check("complete: built-in cwd", has(scopes, "cwd"))
    check("complete: built-in config", has(scopes, "config"))
    check("complete: collection notes", has(scopes, "notes"))

    local acts = cmd.complete("", "Pickers cwd ", 0)
    check("complete: action files", has(acts, "files"))
    check("complete: action grep", has(acts, "grep"))

    local filtered = cmd.complete("co", "Pickers co", 0)
    check("complete: filter 'co' includes config", has(filtered, "config"))
    check("complete: filter 'co' excludes cwd", not has(filtered, "cwd"))
  end
end

-- ── Summary ─────────────────────────────────────────────────────────────────
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
