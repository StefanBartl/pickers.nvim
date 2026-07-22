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
-- (see lib.nvim/templates/README.md); $REPOS_DIR is kept for back-compat.
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
      { name = "proj", dir = "/tmp/proj", prefix = "", only_git = true, find = { hidden = false } },
    },
    keymaps = { cwd_grep = "<leader>zz" },
  })
  local cfg = config.get()

  check("apply: engine set", cfg.engine == "fzf", tostring(cfg.engine))
  check("apply: invalid collections dropped", #cfg.collections == 2, "#=" .. #cfg.collections)
  check("apply: first collection name", cfg.collections[1] and cfg.collections[1].name == "notes")
  check("apply: only_git normalised", cfg.collections[2] and cfg.collections[2].only_git == true)
  check("apply: prefix empty-string kept", cfg.collections[2] and cfg.collections[2].prefix == "")
  check("apply: collection find override kept", cfg.collections[2] and cfg.collections[2].find.hidden == false)
  check("apply: collection with no find override → nil", cfg.collections[1] and cfg.collections[1].find == nil)
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

-- ── pickers.actions.files — per-collection find override merges over cfg.find ─
do
  local config = require("pickers.config")
  local files = require("pickers.actions.files")

  config.apply({ find = { hidden = true, follow = true, no_ignore = false } })

  local captured
  local fake_engine = {
    pick_files = function(opts) captured = opts end,
  }

  -- No override on the source: falls through to global cfg.find unchanged.
  files.run({ roots = { "/tmp" }, prompt = "cwd> " }, fake_engine)
  check("actions.files: no override → global find", vim.deep_equal(captured.find, config.get().find))

  -- Partial override: only the given fields change, the rest stays global.
  files.run(
    { roots = { "/tmp" }, prompt = "notes> ", find = { hidden = false, exclude = { "*.md" } } },
    fake_engine
  )
  check("actions.files: override hidden=false applied", captured.find.hidden == false)
  check("actions.files: override exclude applied", has(captured.find.exclude, "*.md"))
  check("actions.files: unmentioned field (follow) stays global", captured.find.follow == true)
  check(
    "actions.files: global cfg.find itself untouched by override",
    config.get().find.hidden == true
  )

  -- sources.collection passes coll.find through to the resolved Source.
  local collection_source = require("pickers.sources.collection")
  config.apply({
    collections = {
      { name = "notes", dir = vim.fn.getcwd(), find = { hidden = false } },
    },
  })
  local coll = config.get().collections[1]
  local resolved
  collection_source.get(coll, config.get(), function(src) resolved = src end, {})
  check("sources.collection: find passed through to Source", resolved and resolved.find and resolved.find.hidden == false)
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

-- ── config.apply — result_count normalisation; wrap_attach_mappings contract ─
do
  local config = require("pickers.config")
  local result_count = require("pickers.result_count")

  local cfg0 = config.get()
  check("result_count: default disabled", cfg0.result_count.enabled == false)

  -- Fully inert contract (same as selected_index): disabled → wrap returns
  -- `orig` completely unchanged, including nil.
  check("result_count.wrap: disabled → nil stays nil", result_count.wrap_attach_mappings(nil) == nil)
  local passthrough = function() end
  check(
    "result_count.wrap: disabled → orig fn unchanged",
    result_count.wrap_attach_mappings(passthrough) == passthrough
  )

  config.apply({ result_count = { enabled = true } })
  local cfg1 = config.get()
  check("result_count: enabled overridden", cfg1.result_count.enabled == true)
  check(
    "result_count.wrap: enabled → wraps into a new function",
    type(result_count.wrap_attach_mappings(nil)) == "function"
  )

  config.apply({ result_count = { enabled = false } })
  check("result_count: restored to disabled", config.get().result_count.enabled == false)
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
  check(
    "history: invalid limit keeps previous",
    cfg3.history.limit == 50,
    tostring(cfg3.history.limit)
  )
end

-- ── pickers.keys — resolve / per-engine adapters / normalisation ────────────
do
  local config = require("pickers.config")
  local keys = require("pickers.keys")

  -- Defaults
  local cfg0 = config.get()
  check("keys: default enabled", cfg0.keys.enable == true)
  check("keys: default preview_scroll_down", cfg0.keys.preview_scroll_down == "<PageDown>")

  -- resolve(): action → { lhs, modes }
  local r = keys.resolve(cfg0)
  local scroll_modes = r.preview_scroll_down.modes
  local hist_modes = r.history_back.modes
  check("keys.resolve: scroll lhs", has(r.preview_scroll_down.lhs, "<PageDown>"))
  check("keys.resolve: scroll modes i+n", has(scroll_modes, "i") and has(scroll_modes, "n"))
  check("keys.resolve: history lhs", has(r.history_back.lhs, "<C-p>"))
  check("keys.resolve: history mode i only", has(hist_modes, "i") and not has(hist_modes, "n"))

  -- snacks adapter: preview scroll reaches every window, history input-only
  local win = keys.snacks_win(cfg0)
  check("keys.snacks: input has PageDown", win.input.keys["<PageDown>"] ~= nil)
  check("keys.snacks: list has PageDown", win.list.keys["<PageDown>"] == "preview_scroll_down")
  check("keys.snacks: preview has PageDown", win.preview.keys["<PageDown>"] ~= nil)
  check("keys.snacks: input has history <C-p>", win.input.keys["<C-p>"] ~= nil)
  check("keys.snacks: list has NO history <C-p>", win.list.keys["<C-p>"] == nil)
  -- create_file/open_background are entry_actions' own concern (list-window
  -- only, via pickers.entry_actions.adapters.snacks) -- snacks_win() must not
  -- also bind them, or a user merging both would get duplicate/conflicting
  -- bindings in the input/preview windows.
  check("keys.snacks: win() excludes create_file", win.input.keys["<C-a>"] == nil)
  check("keys.snacks: win() excludes open_background", win.input.keys["<S-CR>"] == nil)

  -- fzf adapter: only vertical preview scroll translates
  local fk = keys.fzf_keymap(cfg0)
  check("keys.fzf: PageDown → preview-page-down", fk["<PageDown>"] == "preview-page-down")
  check("keys.fzf: PageUp → preview-page-up", fk["<PageUp>"] == "preview-page-up")
  check("keys.fzf: no horizontal scroll", fk["<C-Left>"] == nil and fk["<C-Right>"] == nil)
  check("keys.fzf: no history binding", fk["<C-p>"] == nil and fk["<C-n>"] == nil)

  -- fzf_skipped(): reports bound-but-unmappable actions, for :checkhealth
  local skipped = keys.fzf_skipped(cfg0)
  check("keys.fzf_skipped: lists history_back", has(skipped, "history_back"))
  check("keys.fzf_skipped: lists preview_scroll_left", has(skipped, "preview_scroll_left"))
  check("keys.fzf_skipped: excludes mapped scroll_down", not has(skipped, "preview_scroll_down"))

  -- Normalisation: list form, false (unbind), and enable toggle
  config.apply({ keys = { preview_scroll_down = { "<PageDown>", "<C-d>" }, history_back = false } })
  local r1 = keys.resolve(config.get())
  local dl = r1.preview_scroll_down.lhs
  check("keys: list form both lhs", has(dl, "<PageDown>") and has(dl, "<C-d>"))
  check("keys: false unbinds", #r1.history_back.lhs == 0)

  -- telescope adapter degrades to empty mappings when telescope is absent
  local tm = keys.telescope_mappings(cfg0)
  check("keys.telescope: i/n buckets present", type(tm.i) == "table" and type(tm.n) == "table")

  -- patch() must never throw, regardless of which engines are installed
  local ok_patch = pcall(keys.patch, cfg0)
  check("keys.patch: does not throw", ok_patch)

  config.apply({ keys = { enable = false } })
  check("keys.resolve: disabled → empty", vim.tbl_isempty(keys.resolve(config.get())))

  -- Restore defaults for any later blocks relying on them.
  config.apply({
    keys = {
      enable = true,
      preview_scroll_down = "<PageDown>",
      history_back = "<C-p>",
      create_file = "<C-a>",
      open_background = { "<S-CR>", "<C-o>" },
      preview_toggle = false,
    },
  })
end

-- ── pickers.keys — preview_toggle: opt-in, telescope-only ───────────────────
do
  local config = require("pickers.config")
  local keys = require("pickers.keys")

  local cfg0 = config.get()
  check("keys: default preview_toggle is false", cfg0.keys.preview_toggle == false)
  check("keys.resolve: default preview_toggle unbound", #keys.resolve(cfg0).preview_toggle.lhs == 0)

  config.apply({ keys = { preview_toggle = "<M-p>" } })
  local cfg1 = config.get()
  local r = keys.resolve(cfg1)
  check("keys.resolve: preview_toggle lhs", has(r.preview_toggle.lhs, "<M-p>"))

  -- telescope adapter binds it (actions.layout.toggle_preview, not actions.*)
  -- when telescope is on the runtimepath; degrades to empty otherwise, same
  -- as every other keys.telescope_mappings() case in this suite.
  local tm = keys.telescope_mappings(cfg1)
  if pcall(require, "telescope.actions.layout") then
    check("keys.telescope: preview_toggle bound (i)", tm.i["<M-p>"] ~= nil)
    check("keys.telescope: preview_toggle bound (n)", tm.n["<M-p>"] ~= nil)
  else
    check("keys.telescope: preview_toggle unbound (telescope absent)", tm.i["<M-p>"] == nil)
  end

  -- fzf-lua and snacks already ship this natively -- must not appear in either.
  local fk = keys.fzf_keymap(cfg1)
  check("keys.fzf: excludes preview_toggle", fk["<M-p>"] == nil)
  local win = keys.snacks_win(cfg1)
  check("keys.snacks: excludes preview_toggle (input)", win.input.keys["<M-p>"] == nil)
  check("keys.snacks: excludes preview_toggle (list)", win.list.keys["<M-p>"] == nil)
  check("keys.snacks: excludes preview_toggle (preview)", win.preview.keys["<M-p>"] == nil)

  -- Restore default (opt-in, off).
  config.apply({ keys = { preview_toggle = false } })
end

-- ── pickers.entry_actions — absorbed into pickers.keys, adapters read resolve() ─
do
  local config = require("pickers.config")
  local keys = require("pickers.keys")

  -- create_file/open_background are part of the same unified `keys` config.
  local cfg0 = config.get()
  check("keys: default create_file", cfg0.keys.create_file == "<C-a>")
  check(
    "keys: default open_background",
    has(cfg0.keys.open_background, "<S-CR>") and has(cfg0.keys.open_background, "<C-o>")
  )

  local r = keys.resolve(cfg0)
  check("keys.resolve: create_file lhs", has(r.create_file.lhs, "<C-a>"))
  check(
    "keys.resolve: open_background lhs",
    has(r.open_background.lhs, "<S-CR>") and has(r.open_background.lhs, "<C-o>")
  )

  -- telescope adapter: get_mappings() reads keys.resolve(), not a separate config.
  local ts = require("pickers.entry_actions.adapters.telescope")
  local tm = ts.get_mappings()
  check("entry_actions.telescope: create_file bound (i)", tm.i["<C-a>"] ~= nil)
  check("entry_actions.telescope: create_file bound (n)", tm.n["<C-a>"] ~= nil)
  check("entry_actions.telescope: open_background bound", tm.i["<S-CR>"] ~= nil)

  -- snacks adapter: get_keys() reads keys.resolve() too.
  local snacks_adapter = require("pickers.entry_actions.adapters.snacks")
  local sk = snacks_adapter.get_keys()
  check("entry_actions.snacks: create_file key", sk["<C-a>"] == "create_file")
  check("entry_actions.snacks: open_background key", sk["<S-CR>"] == "open_background")

  -- fzf adapter: fixed ctrl-a/ctrl-o/shift-enter, gated only by keys.enable.
  local fzf_adapter = require("pickers.entry_actions.adapters.fzf")
  local fa = fzf_adapter.get_actions()
  check("entry_actions.fzf: ctrl-a present when enabled", type(fa["ctrl-a"]) == "function")

  config.apply({ keys = { enable = false } })
  check("entry_actions.telescope: empty when keys.enable=false", vim.tbl_isempty(ts.get_mappings().i))
  check("entry_actions.fzf: empty when keys.enable=false", vim.tbl_isempty(fzf_adapter.get_actions()))
  check("entry_actions.snacks: empty when keys.enable=false", vim.tbl_isempty(snacks_adapter.get_keys()))

  -- Restore defaults for any later blocks relying on them.
  config.apply({
    keys = {
      enable = true,
      preview_scroll_down = "<PageDown>",
      history_back = "<C-p>",
      create_file = "<C-a>",
      open_background = { "<S-CR>", "<C-o>" },
    },
  })
  config.apply({ keys = { history_back = "<C-p>" } })
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

    check("complete: built-in builtin", has(scopes, "builtin"))
    local builtin_names = vim.fn.getcompletion("Pickers builtin ", "cmdline")
    check("complete: builtin git_branches", has(builtin_names, "git_branches"))
    check("complete: builtin lsp_definitions", has(builtin_names, "lsp_definitions"))
  end
end

-- ── pickers.builtins — registry shape, names(), run() dispatch ──────────────
do
  local builtins = require("pickers.builtins")

  -- names(): sorted, matches REGISTRY keys 1:1
  local names = builtins.names()
  local sorted_copy = vim.deepcopy(names)
  table.sort(sorted_copy)
  check("builtins.names: sorted", vim.deep_equal(names, sorted_copy))

  local registry_count = 0
  for _ in pairs(builtins.REGISTRY) do
    registry_count = registry_count + 1
  end
  check("builtins.names: matches REGISTRY size", #names == registry_count, tostring(#names))
  check("builtins.names: includes git_branches", has(names, "git_branches"))
  check("builtins.names: includes lsp_workspace_symbols", has(names, "lsp_workspace_symbols"))
  check("builtins.names: includes notifications", has(names, "notifications"))

  -- Registry shape: every entry has desc + at least one real (non-false)
  -- engine implementation, and every impl has a non-empty fn.
  local shape_ok = true
  local zero_impl = nil
  for name, entry in pairs(builtins.REGISTRY) do
    if type(entry.desc) ~= "string" or entry.desc == "" then shape_ok = false end
    local any_impl = false
    for _, engine in ipairs({ "snacks", "telescope", "fzf" }) do
      local impl = entry[engine]
      if impl then
        any_impl = true
        if type(impl.fn) ~= "string" or impl.fn == "" then shape_ok = false end
      elseif impl ~= false then
        shape_ok = false -- must be exactly `false`, not nil, to mark a gap
      end
    end
    if not any_impl then zero_impl = name end
  end
  check("builtins.REGISTRY: every entry has desc + valid impl shape", shape_ok)
  check("builtins.REGISTRY: no entry is all-gap", zero_impl == nil, tostring(zero_impl))

  -- Documented gaps match what was verified against the real plugin sources.
  local git_diff = builtins.REGISTRY.git_diff
  local git_log_line = builtins.REGISTRY.git_log_line
  local lsp_decl = builtins.REGISTRY.lsp_declarations
  local gh_issue = builtins.REGISTRY.gh_issue
  check("builtins: git_diff has no telescope impl", git_diff.telescope == false)
  check(
    "builtins: git_log_line is snacks-only",
    git_log_line.telescope == false and git_log_line.fzf == false
  )
  check("builtins: lsp_declarations has no telescope impl", lsp_decl.telescope == false)
  check("builtins: gh_issue is snacks-only", gh_issue.telescope == false and gh_issue.fzf == false)

  -- supported_engines()
  local gd_engines = builtins.supported_engines("git_diff")
  local gd_ok = has(gd_engines, "snacks")
    and has(gd_engines, "fzf")
    and not has(gd_engines, "telescope")
  check("builtins.supported_engines: git_diff has snacks+fzf, not telescope", gd_ok)
  check(
    "builtins.supported_engines: unknown name → empty",
    #builtins.supported_engines("nope") == 0
  )

  -- run(): unknown name doesn't throw; explicit engine_name with no impl
  -- doesn't throw (gap path); explicit engine_name with impl but engine module
  -- absent doesn't throw (require() failure path).
  check("builtins.run: unknown name does not throw", pcall(builtins.run, "nope_not_real"))
  check(
    "builtins.run: gap engine does not throw",
    pcall(builtins.run, "git_diff", nil, "telescope")
  )
  check(
    "builtins.run: missing engine module does not throw",
    pcall(builtins.run, "git_branches", nil, "telescope")
  )
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
    vim.wait(200, function()
      return #calls > 0
    end)

    check("debounce: fires exactly once", #calls == 1, "#=" .. #calls)
    check("debounce: fires with the most recent args", calls[1] == "b", tostring(calls[1]))
    check("debounce: cleanup is callable", type(cleanup) == "function")
    cleanup() -- must not error when idle
  end
end

-- ── Summary ─────────────────────────────────────────────────────────────────
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
