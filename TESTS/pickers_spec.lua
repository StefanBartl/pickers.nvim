-- pickers.nvim — unit tests (no framework, no network).
--
-- Run:
--   nvim -l TESTS/pickers_spec.lua
--
-- The script derives its own runtimepath from its location and picks up
-- lib.nvim as a sibling repo (../lib.nvim) if present. Exits non-zero on
-- failure so it can be used in CI.

-- ── Self-bootstrapping runtimepath ──────────────────────────────────────────
local this = debug.getinfo(1, "S").source:sub(2) -- strip leading '@'
local tests_dir = vim.fn.fnamemodify(this, ":h")
local root = vim.fn.fnamemodify(tests_dir, ":h:h") -- TESTS → repo root
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
      ---@diagnostic disable-next-line: missing-fields -- being invalid is the point
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
  check(
    "apply: collection find override kept",
    cfg.collections[2] and cfg.collections[2].find.hidden == false
  )
  check(
    "apply: collection with no find override → nil",
    cfg.collections[1] and cfg.collections[1].find == nil
  )
  check("apply: keymap overridden", cfg.keymaps.cwd_grep == "<leader>zz")
  check("apply: keymap default kept", cfg.keymaps.config_files == "<leader>fc")
  check("apply: repos_files default nil", cfg.keymaps.repos_files == nil)
  check("apply: repos_grep default nil", cfg.keymaps.repos_grep == nil)
  check("apply: system_files default nil", cfg.keymaps.system_files == nil)

  -- find defaults (hidden/follow on, no_ignore off so .gitignore is respected)
  check("find: hidden default true", cfg.find.hidden == true)
  check("find: no_ignore default false", cfg.find.no_ignore == false)
  check("find: follow default true", cfg.find.follow == true)

  -- find override merges over defaults
  config.apply({ find = { no_ignore = true } })
  local cfg2 = config.get()
  check("find: no_ignore overridden", cfg2.find.no_ignore == true)
  check("find: hidden still default", cfg2.find.hidden == true)

  -- smart config defaults + deep-merge
  check(
    "smart: weights default",
    cfg.smart.weights.filename == 1.0 and cfg.smart.weights.both == 25
  )
  check("smart: limit default", cfg.smart.limit == 2000)
  config.apply({ smart = { weights = { content = 2.0 } } })
  local cfg3 = config.get()
  check("smart: weight overridden", cfg3.smart.weights.content == 2.0)
  check("smart: sibling weight kept", cfg3.smart.weights.filename == 1.0)

  -- smart.frecency: opt-in, off by default
  check("smart.frecency: default disabled", cfg.smart.frecency.enabled == false)
  check("smart.frecency: default weight", cfg.smart.frecency.weight == 1.0)
  config.apply({ smart = { frecency = { enabled = true, weight = 2.5 } } })
  local cfg4 = config.get()
  check("smart.frecency: enabled overridden", cfg4.smart.frecency.enabled == true)
  check("smart.frecency: weight overridden", cfg4.smart.frecency.weight == 2.5)
  check("smart.frecency: sibling weights untouched", cfg4.smart.weights.filename == 1.0)
  config.apply({ smart = { frecency = { enabled = false, weight = 1.0 } } })

  -- smart.dedup_grep_rows: opt-in, off by default
  check("smart.dedup_grep_rows: default disabled", cfg.smart.dedup_grep_rows == false)
  config.apply({ smart = { dedup_grep_rows = true } })
  check("smart.dedup_grep_rows: overridden", config.get().smart.dedup_grep_rows == true)
  config.apply({ smart = { dedup_grep_rows = false } })
end

-- ── pickers.bindings.keymaps — repos_files/repos_grep/system_files opt-in ───
do
  local config = require("pickers.config")
  config.apply({
    keymaps = {
      repos_files = "<leader>zrf",
      repos_grep = "<leader>zrg",
      system_files = "<leader>zsf",
    },
  })
  require("pickers.bindings.keymaps").register(config.get().keymaps)

  local rf = vim.fn.maparg("<leader>zrf", "n", false, true)
  local rg = vim.fn.maparg("<leader>zrg", "n", false, true)
  local sf = vim.fn.maparg("<leader>zsf", "n", false, true)
  check("keymaps: repos_files registered", not vim.tbl_isempty(rf))
  -- `pickers: `, not `[pickers] `: the desc prefix comes from
  -- lib.nvim's keymap registry since the migration to it, and it writes
  -- `<plugin>: <desc>`.
  check("keymaps: repos_files desc", rf.desc == "pickers: Pick a repo, then find files")
  check("keymaps: repos_grep registered", not vim.tbl_isempty(rg))
  check("keymaps: system_files registered", not vim.tbl_isempty(sf))

  -- cwd_files stays nil (unset) → map() must no-op, not throw or register "".
  local ok = pcall(require("pickers.bindings.keymaps").register, config.get().keymaps)
  check("keymaps: re-register with unset cwd_files does not throw", ok)
end

-- ── pickers.actions.files — per-collection find override merges over cfg.find ─
do
  local config = require("pickers.config")
  local files = require("pickers.actions.files")

  config.apply({ find = { hidden = true, follow = true, no_ignore = false } })

  local captured
  local fake_engine = {
    pick_files = function(opts)
      captured = opts
    end,
  }

  -- No override on the source: falls through to global cfg.find unchanged.
  files.run({ roots = { "/tmp" }, prompt = "cwd> " }, fake_engine)
  check(
    "actions.files: no override → global find",
    vim.deep_equal(captured.find, config.get().find)
  )

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

  -- 3rd-arg override (the "find all" escape hatch): forced on top of
  -- cfg.find/source.find, regardless of configured defaults.
  config.apply({ find = { hidden = false, no_ignore = false, follow = false } })
  files.run(
    { roots = { "/tmp" }, prompt = "cwd> " },
    fake_engine,
    { hidden = true, no_ignore = true, follow = true }
  )
  check("actions.files: override forces hidden=true", captured.find.hidden == true)
  check("actions.files: override forces no_ignore=true", captured.find.no_ignore == true)
  check("actions.files: override forces follow=true", captured.find.follow == true)
  check(
    "actions.files: override does not mutate global cfg.find",
    config.get().find.hidden == false
  )
  config.apply({ find = { hidden = true, no_ignore = false, follow = true } })

  -- sources.collection passes coll.find through to the resolved Source.
  local collection_source = require("pickers.sources.collection")
  config.apply({
    collections = {
      { name = "notes", dir = vim.fn.getcwd(), find = { hidden = false } },
    },
  })
  local coll = config.get().collections[1]
  local resolved
  collection_source.get(coll, config.get(), function(src)
    resolved = src
  end, {})
  check(
    "sources.collection: find passed through to Source",
    resolved and resolved.find and resolved.find.hidden == false
  )
end

-- ── pickers.last / pickers.command.dispatch — :PickersRepeat state ──────────
do
  local last = require("pickers.last")
  local cmd = require("pickers.command")

  local calls = {}
  local fake_engine = {
    pick_files = function(opts)
      calls[#calls + 1] = { kind = "files", opts = opts }
    end,
    live_grep = function(opts)
      calls[#calls + 1] = { kind = "grep", opts = opts }
    end,
  }

  -- pickers.command.dispatch is the single choke point every scope (standard,
  -- collection, dir) routes through -- it must record into pickers.last.
  cmd.dispatch("files", { roots = { "/a" }, prompt = "A> " }, fake_engine)
  check("last: records action", last.get().action == "files")
  check("last: records source", last.get().source.roots[1] == "/a")
  check("dispatch: reached the engine", #calls == 1 and calls[1].kind == "files")

  -- A second dispatch overwrites, not accumulates -- only the most recent.
  cmd.dispatch("grep", { roots = { "/b" }, prompt = "B> " }, fake_engine)
  check("last: overwritten by second dispatch", last.get().action == "grep")
  check("last: overwritten source", last.get().source.roots[1] == "/b")

  -- last.run() replays the exact same {action, source} via a freshly
  -- resolved engine, without needing to re-specify anything.
  local ok = pcall(last.run)
  check("last.run: does not throw", ok)
end

-- ── pickers.command.handle — "find all" escape hatch (:Pickers cwd files all) ─
do
  local config = require("pickers.config")
  local engines = require("pickers.engines")
  local cmd = require("pickers.command")

  config.apply({ find = { hidden = false, no_ignore = false, follow = false } })

  local captured
  local fake_engine = {
    pick_files = function(opts)
      captured = opts
    end,
    live_grep = function(opts)
      captured = opts
    end,
  }
  local real_load = engines.load
  engines.load = function()
    return fake_engine
  end

  cmd.handle({ fargs = { "cwd", "files", "all" } })
  check(
    "command.handle: 'files all' forces hidden",
    captured and captured.find and captured.find.hidden == true
  )
  check("command.handle: 'files all' forces no_ignore", captured.find.no_ignore == true)
  check("command.handle: 'files all' forces follow", captured.find.follow == true)
  check(
    "command.handle: 'files all' does not mutate global cfg.find",
    config.get().find.hidden == false
  )

  -- Without the "all" token, plain configured defaults apply unforced.
  captured = nil
  cmd.handle({ fargs = { "cwd", "files" } })
  check(
    "command.handle: plain 'files' keeps configured hidden=false",
    captured.find.hidden == false
  )

  -- "all" is a no-op for grep (files-only escape hatch).
  captured = nil
  cmd.handle({ fargs = { "cwd", "grep", "all" } })
  check("command.handle: 'grep all' still dispatches grep, ignoring 'all'", captured ~= nil)

  -- opts.engine threads straight into pickers.engines.load(requested).
  local seen_requested
  engines.load = function(requested)
    seen_requested = requested
    return fake_engine
  end
  cmd.handle({ fargs = { "cwd", "files" }, engine = "telescope" })
  check("command.handle: opts.engine reaches engines.load", seen_requested == "telescope")
  cmd.handle({ fargs = { "cwd", "files" } })
  check("command.handle: unset opts.engine passes nil (default resolution)", seen_requested == nil)

  engines.load = real_load
  config.apply({ find = { hidden = true, no_ignore = false, follow = true } })
end

-- ── pickers.mappings — name classification + registration ───────────────────
do
  local mappings = require("pickers.mappings")
  local config = require("pickers.config")

  -- classify(): builtin names win over the <scope>_<action> pattern.
  check("mappings.classify: builtin name", mappings.classify("explorer") == "builtin")
  local kind, scope, action = mappings.classify("cwd_files")
  check("mappings.classify: scope_action kind", kind == "scope_action")
  check("mappings.classify: scope_action scope", scope == "cwd", tostring(scope))
  check("mappings.classify: scope_action action", action == "files", tostring(action))

  local k2, s2, a2 = mappings.classify("notes_lua_grep")
  check("mappings.classify: scope with underscore kind", k2 == "scope_action")
  check("mappings.classify: scope with underscore", s2 == "notes_lua" and a2 == "grep", s2)

  local k3, s3 = mappings.classify("cwd_find_all")
  check("mappings.classify: find_all kind", k3 == "find_all")
  check("mappings.classify: find_all scope", s3 == "cwd", tostring(s3))

  check("mappings.classify: unresolvable name", mappings.classify("not_a_real_thing_xyz") == nil)

  -- apply(): valid entries register a normal-mode keymap; malformed/
  -- unresolvable entries are skipped (no keymap, no throw).
  config.apply({
    mappings = {
      cwd_files = { "<leader>ZZtestfiles" },
      explorer = { "<leader>ZZtestexplorer", "snacks" },
      bogus_entry_name = { "<leader>ZZtestbogus" },
      malformed = "not-a-table",
    },
  })
  local ok_apply = pcall(mappings.apply, config.get())
  check("mappings.apply: does not throw", ok_apply)
  check(
    "mappings.apply: valid scope_action entry registers a keymap",
    vim.fn.maparg("<leader>ZZtestfiles", "n") ~= ""
  )
  check(
    "mappings.apply: valid builtin entry registers a keymap",
    vim.fn.maparg("<leader>ZZtestexplorer", "n") ~= ""
  )
  check(
    "mappings.apply: unresolvable name registers no keymap",
    vim.fn.maparg("<leader>ZZtestbogus", "n") == ""
  )

  -- Cleanup: unset the test keymaps and reset mappings config.
  pcall(vim.keymap.del, "n", "<leader>ZZtestfiles")
  pcall(vim.keymap.del, "n", "<leader>ZZtestexplorer")
  config.apply({ mappings = {} })
end

-- ── pickers.plugin_spec — engine ownership + auto-install spec builder ──────
do
  local pickers = require("pickers")
  local plugin_spec = pickers.plugin_spec

  -- own_engine unset/false: single entry, no engine dependency added.
  local plain = plugin_spec({})
  check("plugin_spec: own_engine=false returns 1 entry", #plain == 1, "#=" .. #plain)
  check("plugin_spec: repo is pickers.nvim", plain[1][1] == "StefanBartl/pickers.nvim")
  check(
    "plugin_spec: deps are just lib.nvim",
    #plain[1].dependencies == 1 and plain[1].dependencies[1] == "StefanBartl/lib.nvim"
  )

  local real_setup = pickers.setup
  local captured_opts
  pickers.setup = function(o)
    captured_opts = o
  end
  plain[1].config()
  check("plugin_spec: plain config() calls pickers.setup", captured_opts ~= nil)
  pickers.setup = real_setup

  -- own_engine=true, engine="auto" (or unset): errors immediately, at
  -- spec-build time -- "auto" has no single engine to install.
  local ok_auto = pcall(plugin_spec, { own_engine = true, engine = "auto" })
  check("plugin_spec: own_engine=true + engine='auto' errors", not ok_auto)
  local ok_unset = pcall(plugin_spec, { own_engine = true })
  check("plugin_spec: own_engine=true + no engine errors", not ok_unset)

  -- own_engine=true, engine="snacks": 2 entries, engine repo first (no
  -- pickers.nvim dependency loop), pickers.nvim depends on both lib.nvim
  -- and the engine repo.
  local snacks_spec = plugin_spec({ own_engine = true, engine = "snacks", engine_opts = { x = 1 } })
  check("plugin_spec: own_engine=true returns 2 entries", #snacks_spec == 2, "#=" .. #snacks_spec)
  check("plugin_spec: engine entry repo", snacks_spec[1][1] == "folke/snacks.nvim")
  check("plugin_spec: pickers entry repo", snacks_spec[2][1] == "StefanBartl/pickers.nvim")
  check(
    "plugin_spec: pickers entry depends on both lib.nvim and the engine",
    has(snacks_spec[2].dependencies, "StefanBartl/lib.nvim")
      and has(snacks_spec[2].dependencies, "folke/snacks.nvim")
  )

  -- engine entry's config() calls the engine's own setup() with engine_opts
  -- (stubbed via package.loaded so this doesn't require snacks installed).
  local captured_engine_opts
  package.loaded["snacks"] = {
    setup = function(o)
      captured_engine_opts = o
    end,
  }
  snacks_spec[1].config()
  check(
    "plugin_spec: engine config() calls Snacks.setup(engine_opts)",
    captured_engine_opts and captured_engine_opts.x == 1
  )
  package.loaded["snacks"] = nil

  -- pickers entry's config() calls pickers.setup() with engine filled in.
  pickers.setup = function(o)
    captured_opts = o
  end
  snacks_spec[2].config()
  check("plugin_spec: pickers config() fills in engine=snacks", captured_opts.engine == "snacks")
  pickers.setup = real_setup

  -- telescope pulls in plenary as an extra dependency.
  local ts_spec = plugin_spec({ own_engine = true, engine = "telescope" })
  check(
    "plugin_spec: telescope entry depends on plenary",
    has(ts_spec[1].dependencies, "nvim-lua/plenary.nvim")
  )
end

-- ── pickers.ui.scope_picker.list() — :PickersScopes' data source ────────────
do
  local config = require("pickers.config")
  local scope_picker = require("pickers.ui.scope_picker")

  config.apply({ collections = { { name = "notes", dir = "/tmp/notes" } } })
  local scopes = scope_picker.list()

  check("scope_picker.list: includes built-in cwd", has(scopes, "cwd"))
  check("scope_picker.list: includes built-in dir", has(scopes, "dir"))
  check("scope_picker.list: includes collection name", has(scopes, "notes"))
  check(
    "scope_picker.list: built-ins come before collections",
    (function()
      local cwd_i, notes_i
      for i, s in ipairs(scopes) do
        if s == "cwd" then cwd_i = i end
        if s == "notes" then notes_i = i end
      end
      return cwd_i and notes_i and cwd_i < notes_i
    end)()
  )
end

-- ── config.apply — removed selected_index shape is ignored, not applied ─────
do
  local config = require("pickers.config")
  ---@diagnostic disable-next-line: assign-type-mismatch
  local ok = pcall(config.apply, { selected_index = { enabled = true } })
  check("removed selected_index opts: apply() does not throw", ok)
  ---@diagnostic disable-next-line: assign-type-mismatch
  local ok2 = pcall(config.apply, { experimental = { selected_index = { enabled = true } } })
  check("removed experimental opts: apply() does not throw", ok2)
end

-- ── config.apply — result_count normalisation; wrap_attach_mappings contract ─
do
  local config = require("pickers.config")
  local result_count = require("pickers.result_count")

  local cfg0 = config.get()
  check("result_count: default disabled", cfg0.result_count.enabled == false)

  -- Fully inert contract: disabled → wrap returns `orig` completely
  -- unchanged, including nil.
  check(
    "result_count.wrap: disabled → nil stays nil",
    result_count.wrap_attach_mappings(nil) == nil
  )
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

-- ── config.apply — display.path_shorten normalisation (cosmetic, optional) ──
do
  local config = require("pickers.config")

  local cfg0 = config.get()
  check("display: default path_shorten disabled", cfg0.display.path_shorten == false)

  config.apply({ display = { path_shorten = true } })
  check("display: path_shorten overridden", config.get().display.path_shorten == true)

  -- Invalid value is silently ignored, keeping the previous value.
  config.apply({ display = { path_shorten = "yes" } })
  check("display: non-boolean ignored, keeps previous", config.get().display.path_shorten == true)

  config.apply({ display = { path_shorten = false } })
  check("display: restored to disabled", config.get().display.path_shorten == false)
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

-- ── pickers.keys — split/vsplit/tab: on by default, native in all 3 engines ─
do
  local config = require("pickers.config")
  local keys = require("pickers.keys")

  local cfg0 = config.get()
  check("keys: default split lhs", cfg0.keys.split == "<C-s>")
  check("keys: default vsplit lhs", cfg0.keys.vsplit == "<C-v>")
  check("keys: default tab lhs", cfg0.keys.tab == "<C-t>")

  local r = keys.resolve(cfg0)
  check("keys.resolve: split lhs", has(r.split.lhs, "<C-s>"))
  check("keys.resolve: vsplit lhs", has(r.vsplit.lhs, "<C-v>"))
  check("keys.resolve: tab lhs", has(r.tab.lhs, "<C-t>"))
  check("keys.resolve: split modes i+n", has(r.split.modes, "i") and has(r.split.modes, "n"))

  -- telescope adapter: select_horizontal/select_vertical/select_tab
  local tm = keys.telescope_mappings(cfg0)
  if pcall(require, "telescope.actions") then
    check("keys.telescope: split bound (i)", tm.i["<C-s>"] ~= nil)
    check("keys.telescope: vsplit bound (n)", tm.n["<C-v>"] ~= nil)
    check("keys.telescope: tab bound (i)", tm.i["<C-t>"] ~= nil)
  else
    check("keys.telescope: split unbound (telescope absent)", tm.i["<C-s>"] == nil)
  end

  -- fzf-lua ships ctrl-s/ctrl-v/ctrl-t natively/fixed -- must not appear in
  -- keymap.builtin or fzf_skipped() (not a capability gap).
  local fk = keys.fzf_keymap(cfg0)
  check(
    "keys.fzf: excludes split/vsplit/tab",
    fk["<C-s>"] == nil and fk["<C-v>"] == nil and fk["<C-t>"] == nil
  )
  local skipped = keys.fzf_skipped(cfg0)
  check(
    "keys.fzf_skipped: excludes split/vsplit/tab",
    not has(skipped, "split") and not has(skipped, "vsplit")
  )

  -- snacks adapter: action names match 1:1, so they pass through the default
  -- (non-history, non-skip) branch onto input+list+preview.
  local win = keys.snacks_win(cfg0)
  check("keys.snacks: input has split", win.input.keys["<C-s>"] ~= nil)
  check("keys.snacks: list has vsplit", win.list.keys["<C-v>"] == "vsplit")
  check("keys.snacks: preview has tab", win.preview.keys["<C-t>"] == "tab")

  -- Unbinding via false
  config.apply({ keys = { split = false } })
  check("keys: split unbind", #keys.resolve(config.get()).split.lhs == 0)

  -- Restore defaults for any later blocks relying on them.
  config.apply({ keys = { split = "<C-s>", vsplit = "<C-v>", tab = "<C-t>" } })
end

-- ── pickers.keys — mouse_confirm: double-click opens, on by default ─────────
do
  local config = require("pickers.config")
  local keys = require("pickers.keys")

  local cfg0 = config.get()
  check("keys: default mouse_confirm lhs", cfg0.keys.mouse_confirm == "<2-LeftMouse>")

  local r = keys.resolve(cfg0)
  check("keys.resolve: mouse_confirm lhs", has(r.mouse_confirm.lhs, "<2-LeftMouse>"))
  check(
    "keys.resolve: mouse_confirm mode n only",
    has(r.mouse_confirm.modes, "n") and not has(r.mouse_confirm.modes, "i")
  )

  -- telescope adapter: actions.select_default, bound in mappings.n only
  -- (telescope has no default mouse mapping at all -- the actual gap).
  local tm = keys.telescope_mappings(cfg0)
  if pcall(require, "telescope.actions") then
    check("keys.telescope: mouse_confirm bound (n)", tm.n["<2-LeftMouse>"] ~= nil)
    check("keys.telescope: mouse_confirm not in insert map", tm.i["<2-LeftMouse>"] == nil)
  else
    check("keys.telescope: mouse_confirm unbound (telescope absent)", tm.n["<2-LeftMouse>"] == nil)
  end

  -- fzf-lua: real fzf binary handles mouse clicks itself -- capability gap,
  -- same class as history; must be reported by fzf_skipped().
  local fk = keys.fzf_keymap(cfg0)
  check("keys.fzf: excludes mouse_confirm", fk["<2-LeftMouse>"] == nil)
  local skipped = keys.fzf_skipped(cfg0)
  check("keys.fzf_skipped: lists mouse_confirm", has(skipped, "mouse_confirm"))

  -- snacks adapter: translates to its own "confirm" action, list window only.
  local win = keys.snacks_win(cfg0)
  check("keys.snacks: list mouse_confirm → confirm", win.list.keys["<2-LeftMouse>"] == "confirm")
  check("keys.snacks: input excludes mouse_confirm", win.input.keys["<2-LeftMouse>"] == nil)
  check("keys.snacks: preview excludes mouse_confirm", win.preview.keys["<2-LeftMouse>"] == nil)

  -- Unbinding via false
  config.apply({ keys = { mouse_confirm = false } })
  check("keys: mouse_confirm unbind", #keys.resolve(config.get()).mouse_confirm.lhs == 0)

  -- Restore default for any later blocks relying on it.
  config.apply({ keys = { mouse_confirm = "<2-LeftMouse>" } })
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
  check(
    "entry_actions.telescope: empty when keys.enable=false",
    vim.tbl_isempty(ts.get_mappings().i)
  )
  check(
    "entry_actions.fzf: empty when keys.enable=false",
    vim.tbl_isempty(fzf_adapter.get_actions())
  )
  check(
    "entry_actions.snacks: empty when keys.enable=false",
    vim.tbl_isempty(snacks_adapter.get_keys())
  )

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

-- ── pickers.entry_actions.extract.fzf — clean fields vs raw display line ────
do
  local extract = require("pickers.entry_actions.extract.fzf")

  -- Clean .path/.filename fields (fzf-lua-populated metadata, never carry an
  -- icon prefix) must survive untouched even when they contain a space --
  -- the icon-strip regex must not fire on them. Regression test: it used to
  -- unconditionally strip "first token + space" off *any* string reaching
  -- this point, corrupting e.g. Windows' "C:\Program Files\..." into
  -- "Files\...".
  check(
    "extract.fzf: clean .path with space survives",
    extract({ path = "C:/Program Files/foo.txt" }):find("Program Files", 1, true) ~= nil
  )
  check(
    "extract.fzf: clean .filename with space survives",
    extract({ filename = "/home/user/John Doe/notes.md" }):find("John Doe", 1, true) ~= nil
  )

  -- The raw display-line fallback (selected[1], no .path/.filename) DOES
  -- carry fzf's own icon/ANSI formatting and must still be stripped.
  local icon_line = "\239\130\156 /home/user/project/main.lua"
  local stripped = extract({ icon_line })
  check(
    "extract.fzf: icon-prefixed [1] fallback still stripped",
    stripped:find("main.lua", 1, true) ~= nil
  )
  check("extract.fzf: icon glyph removed", not stripped:find("239", 1, true))
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
        -- Exactly one of `fn` (flat mod[fn] dispatch) or `run` (custom
        -- invoker, e.g. telescope's file_browser extension) must be present.
        local has_fn = type(impl.fn) == "string" and impl.fn ~= ""
        local has_run = type(impl.run) == "function"
        if has_fn == has_run then shape_ok = false end
      elseif impl ~= false then
        shape_ok = false -- must be exactly `false`, not nil, to mark a gap
      end
    end
    if not any_impl then zero_impl = name end
  end
  check("builtins.REGISTRY: every entry has desc + valid impl shape", shape_ok)
  check("builtins.REGISTRY: no entry is all-gap", zero_impl == nil, tostring(zero_impl))

  -- Regression: snacks picker functions live on `snacks.picker`, not the
  -- top-level `Snacks` table (whose metatable turns Snacks.command_history
  -- into a failing require("snacks.command_history")). This guards the whole
  -- snacks builtin path — the user's default engine.
  check(
    "builtins.engine_module: snacks → snacks.picker",
    builtins.engine_module("snacks") == "snacks.picker"
  )
  check(
    "builtins.engine_module: telescope → telescope.builtin",
    builtins.engine_module("telescope") == "telescope.builtin"
  )
  check("builtins.engine_module: fzf → fzf-lua", builtins.engine_module("fzf") == "fzf-lua")

  -- Dispatch actually calls the right function on the right module (stubbed,
  -- so it works headless without a real snacks/telescope install).
  do
    local prev = package.loaded["snacks.picker"]
    local called_with
    package.loaded["snacks.picker"] = {
      command_history = function(o)
        called_with = o
      end,
    }
    builtins.run("command_history", { marker = 1 }, "snacks")
    package.loaded["snacks.picker"] = prev
    check(
      "builtins.run: snacks dispatches to snacks.picker[fn]",
      type(called_with) == "table" and called_with.marker == 1
    )
  end

  -- explorer: snacks fn, telescope custom run-invoker, fzf documented gap.
  local explorer = builtins.REGISTRY.explorer
  check(
    "builtins: explorer snacks uses fn=explorer",
    explorer.snacks and explorer.snacks.fn == "explorer"
  )
  check(
    "builtins: explorer telescope uses a run-invoker",
    type(explorer.telescope.run) == "function"
  )
  check("builtins: explorer has no fzf impl", explorer.fzf == false)
  check(
    "builtins.run: explorer run-invoker path does not throw",
    pcall(builtins.run, "explorer", nil, "telescope")
  )

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

-- ── pickers.smart.search — fd_args/rg_args exclude-glob wiring ──────────────
do
  local search = require("pickers.smart.search")

  local fd = search.fd_args({ exclude = { "*.log", "node_modules" } }, "foo")
  local function count_pairs(list, flag, value)
    local n = 0
    for i, v in ipairs(list) do
      if v == flag and list[i + 1] == value then n = n + 1 end
    end
    return n
  end
  check("search.fd_args: --exclude *.log", count_pairs(fd, "--exclude", "*.log") == 1)
  check("search.fd_args: --exclude node_modules", count_pairs(fd, "--exclude", "node_modules") == 1)

  local rg = search.rg_args({ exclude = { "*.log", "node_modules" } }, nil, "foo")
  check("search.rg_args: -g !*.log", count_pairs(rg, "-g", "!*.log") == 1)
  check("search.rg_args: -g !node_modules", count_pairs(rg, "-g", "!node_modules") == 1)
  check("search.rg_args: still ends in -- query", rg[#rg - 1] == "--" and rg[#rg] == "foo")

  local rg_none = search.rg_args({}, nil, "foo")
  check("search.rg_args: no exclude → no extra -g beyond .git", not has(rg_none, "!*.log"))
end

-- ── pickers.smart.frecency — opt-in recency/frequency ranking boost ─────────
do
  local frecency = require("pickers.smart.frecency")
  local config = require("pickers.config")

  local tmp_dir = vim.fn.tempname()
  vim.fn.mkdir(tmp_dir, "p")
  local cfg = vim.tbl_deep_extend(
    "force",
    config.get(),
    { smart = { frecency = { enabled = true, weight = 1.0, dir = tmp_dir } } }
  )

  frecency._reset_cache()
  check("frecency: unrecorded path scores 0", frecency.score(cfg, "/never/visited.lua") == 0)

  frecency.record(cfg, "/tmp/a.lua")
  check("frecency: recorded path scores > 0", frecency.score(cfg, "/tmp/a.lua") > 0)

  frecency.record(cfg, "/tmp/a.lua")
  frecency.record(cfg, "/tmp/b.lua")
  check(
    "frecency: more visits score higher (same recency)",
    frecency.score(cfg, "/tmp/a.lua") > frecency.score(cfg, "/tmp/b.lua")
  )

  -- lookup(): only returns entries for the requested abspaths, weighted.
  local lk = frecency.lookup(cfg, { "/tmp/a.lua", "/tmp/never.lua" })
  check("frecency.lookup: includes visited path", lk["/tmp/a.lua"] and lk["/tmp/a.lua"] > 0)
  check("frecency.lookup: excludes unvisited path", lk["/tmp/never.lua"] == nil)

  -- Disabled → lookup() always empty, regardless of recorded visits.
  local cfg_off =
    vim.tbl_deep_extend("force", config.get(), { smart = { frecency = { enabled = false } } })
  check(
    "frecency.lookup: disabled → empty",
    vim.tbl_isempty(frecency.lookup(cfg_off, { "/tmp/a.lua" }))
  )

  -- flush()/persistence round-trip: reset the in-memory cache and re-load
  -- from the dir we just wrote to.
  frecency.flush(cfg)
  frecency._reset_cache()
  check("frecency: score survives a flush + cache reset", frecency.score(cfg, "/tmp/a.lua") > 0)

  frecency._reset_cache()
  vim.fn.delete(tmp_dir, "rf")

  -- Legacy adoption: a store written before the heuristic moved to lib.nvim
  -- is a flat `path -> { count, last }` map at the same path, with none of
  -- cache.disk's envelope around it. It must be adopted, not silently
  -- restarted -- these counts are months of real use.
  local legacy_dir = vim.fn.tempname()
  vim.fn.mkdir(legacy_dir, "p")
  local legacy_cfg = vim.tbl_deep_extend(
    "force",
    config.get(),
    { smart = { frecency = { enabled = true, weight = 1.0, dir = legacy_dir } } }
  )

  local legacy = assert(io.open(legacy_dir .. "/frecency.json", "w"))
  legacy:write(vim.json.encode({ ["/legacy/kept.lua"] = { count = 4, last = os.time() } }))
  legacy:close()

  frecency._reset_cache()
  check(
    "frecency: a pre-extraction store is adopted, not restarted",
    frecency.score(legacy_cfg, "/legacy/kept.lua") > 0
  )

  -- Written back in the new shape, so the migration path is not reachable a
  -- second time -- and the counts are still there when it is not.
  frecency._reset_cache()
  check(
    "frecency: the adopted store persists in the new shape",
    frecency.score(legacy_cfg, "/legacy/kept.lua") > 0
  )

  local converted = assert(io.open(legacy_dir .. "/frecency.json", "r"))
  local decoded = vim.json.decode(converted:read("*a"))
  converted:close()
  check("frecency: the file was rewritten in cache.disk's shape", decoded.data ~= nil)

  frecency._reset_cache()
  vim.fn.delete(legacy_dir, "rf")
end

-- ── pickers.smart.score — pure scorer + merge/rank ──────────────────────────
do
  local score = require("pickers.smart.score")
  local w = { filename = 1.0, content = 1.0, both = 25 }

  -- match(): substring beats subsequence; no-match is nil; empty needle = 0
  check("score.match: empty needle → 0", score.match("anything", "") == 0)
  check("score.match: no match → nil", score.match("abc", "xyz") == nil)
  local prefix = score.match("config.lua", "config")
  local mid = score.match("my_config.lua", "config")
  check(
    "score.match: prefix beats mid",
    prefix and mid and prefix > mid,
    tostring(prefix) .. " vs " .. tostring(mid)
  )
  local sub = score.match("cfg", "config") -- subsequence only? "config" not subseq of "cfg" → nil
  check("score.match: non-subsequence → nil", sub == nil)
  check("score.match: subsequence weak match", (score.match("configuration", "cfg") or 0) > 0)

  -- score_file: filename hit outranks a path-only hit
  local name_hit = score.score_file("init", "lua/init.lua", w)
  local path_hit = score.score_file("lua", "lua/deep/nested.lua", w)
  check("score.score_file: name hit > path hit", name_hit and path_hit and name_hit > path_hit)
  check("score.score_file: no match → nil", score.score_file("zzz", "a/b/c.lua", w) == nil)

  -- rank: merges files + greps into ONE list, both_bonus floats the dual hit
  local files = {
    { path = "smart.lua", root = "/r", abspath = "/r/smart.lua" },
    { path = "smarty.lua", root = "/r", abspath = "/r/smarty.lua" },
  }
  local greps = {
    {
      path = "smart.lua",
      root = "/r",
      abspath = "/r/smart.lua",
      lnum = 3,
      col = 1,
      text = "local smart = true",
    },
  }
  local ranked = score.rank("smart", files, greps, w, 100)
  check("score.rank: merged length", #ranked == 3, "#=" .. #ranked)
  check(
    "score.rank: has file + grep kinds",
    ranked[1] and (ranked[1].kind == "file" or ranked[1].kind == "grep")
  )
  -- the file that also has grep hits (smart.lua) should be the top file
  local top = ranked[1]
  check("score.rank: dual-hit file floats to top", top.abspath == "/r/smart.lua", top.abspath)
  check("score.rank: _rank assigned", ranked[1]._rank == 1 and ranked[#ranked]._rank == #ranked)

  -- limit trims
  local trimmed = score.rank("smart", files, greps, w, 2)
  check("score.rank: limit trims", #trimmed == 2, "#=" .. #trimmed)

  -- optional 6th `frecency` param: additive bonus by abspath, nil-safe when
  -- omitted (already covered by every check above, all called without it).
  local ranked_plain = score.rank("smart", files, greps, w, 100)
  local ranked_boosted = score.rank("smart", files, greps, w, 100, { ["/r/smarty.lua"] = 1000 })
  local plain_top = ranked_plain[1].abspath
  local boosted_top = ranked_boosted[1].abspath
  check("score.rank: frecency bonus changes ranking", plain_top ~= boosted_top, boosted_top)
  check("score.rank: frecency bonus floats boosted path to top", boosted_top == "/r/smarty.lua")

  -- optional 7th `dedup_grep_rows` param: collapses multiple grep hits for
  -- the SAME file down to its single best-scoring line.
  local multi_greps = {
    { path = "dup.lua", root = "/r", abspath = "/r/dup.lua", lnum = 1, col = 1, text = "smart" },
    {
      path = "dup.lua",
      root = "/r",
      abspath = "/r/dup.lua",
      lnum = 5,
      col = 1,
      text = "not a match at all",
    },
    {
      path = "dup.lua",
      root = "/r",
      abspath = "/r/dup.lua",
      lnum = 9,
      col = 1,
      text = "smart smart smart",
    },
  }
  local no_dedup = score.rank("smart", {}, multi_greps, w, 100)
  check("score.rank: no dedup keeps every grep row", #no_dedup == 3, "#=" .. #no_dedup)

  local deduped = score.rank("smart", {}, multi_greps, w, 100, nil, true)
  check("score.rank: dedup collapses to one row per file", #deduped == 1, "#=" .. #deduped)
  -- "smart" (lnum 1) is an exact whole-line match to the query and outscores
  -- "smart smart smart" (lnum 9, longer, no exact-match bonus) and the
  -- non-matching line (lnum 5) -- dedup keeps that highest-scoring row.
  local kept_score = score.score_grep("smart", "dup.lua", "smart", w)
  local other_score = score.score_grep("smart", "dup.lua", "smart smart smart", w)
  check("score.rank: dedup keeps the best-scoring line", deduped[1].lnum == 1, deduped[1].lnum)
  check("score.rank: kept line does outscore the other candidate", kept_score > other_score)
end

-- ── sources.system: fd-search prompt routes through kit.input ───────────────
-- luacheck: push ignore 122
do
  local orig_executable = vim.fn.executable
  vim.fn.executable = function(name)
    if name == "fd" then return 1 end
    return 0
  end

  local captured_title
  package.loaded["lib.nvim.ui.kit"] = {
    input = function(opts)
      captured_title = opts.title
      opts.on_submit(".lua /home/user")
    end,
  }
  package.loaded["pickers.sources.system"] = nil
  local system = require("pickers.sources.system")

  local got_source
  system.get({}, function(source)
    got_source = source
  end)

  check("sources.system: kit.input was asked", captured_title ~= nil, tostring(captured_title))
  check(
    "sources.system: fd argv built from the submitted input",
    got_source ~= nil and vim.tbl_contains(got_source.find_command, "/home/user"),
    got_source and vim.inspect(got_source.find_command)
  )

  vim.fn.executable = orig_executable
  package.loaded["lib.nvim.ui.kit"] = nil
  package.loaded["pickers.sources.system"] = nil
end
-- luacheck: pop

-- ── entry_actions.create_file: name prompt routes through kit.input ────────
do
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")

  local captured_title
  package.loaded["lib.nvim.ui.kit"] = {
    input = function(opts)
      captured_title = opts.title
      opts.on_submit("newfile.txt")
    end,
  }
  package.loaded["pickers.entry_actions.create_file"] = nil
  local create_file = require("pickers.entry_actions.create_file")

  create_file.run(dir)
  vim.wait(50) -- M.run schedules the prompt

  check(
    "entry_actions.create_file: kit.input was asked",
    captured_title ~= nil,
    tostring(captured_title)
  )
  check(
    "entry_actions.create_file: file created from the submitted name",
    vim.fn.filereadable(dir .. "/newfile.txt") == 1
  )

  package.loaded["lib.nvim.ui.kit"] = nil
  package.loaded["pickers.entry_actions.create_file"] = nil
end

-- ── ui.dir_nav_picker: "path=…" entry routes through kit.input ──────────────
do
  local captured_title
  package.loaded["lib.nvim.ui.kit"] = {
    select = function(opts)
      opts.on_select("path=…")
    end,
    input = function(opts)
      captured_title = opts.title
      opts.on_submit("/some/dir")
    end,
  }
  package.loaded["pickers.ui.dir_nav_picker"] = nil
  local dir_nav_picker = require("pickers.ui.dir_nav_picker")

  local got_result
  dir_nav_picker.open({ depth_aliases = {} }, function(result)
    got_result = result
  end)

  check(
    "dir_nav_picker: kit.input was asked for the explicit path",
    captured_title ~= nil,
    tostring(captured_title)
  )
  check(
    "dir_nav_picker: submitted path is prefixed with 'path='",
    got_result == "path=/some/dir",
    tostring(got_result)
  )

  package.loaded["lib.nvim.ui.kit"] = nil
  package.loaded["pickers.ui.dir_nav_picker"] = nil
end

-- ── pick_item(): Pickers.Item preview extension, all three engines ─────────
-- Items may be plain strings (unchanged behaviour — repos/wkdbooks sources
-- still pass those) or `Pickers.Item` tables `{ text, file? }`. When at least
-- one item carries `file`, each engine attaches its own native preview;
-- `on_select` always receives back the EXACT original entry, never a
-- re-parsed copy. Stubbed so this runs without telescope/fzf-lua/snacks
-- installed — see engines/@types/init.lua for the Pickers.Item contract.

-- telescope ───────────────────────────────────────────────────────────────
do
  local prev = {
    ["telescope.builtin"] = package.loaded["telescope.builtin"],
    ["telescope.pickers"] = package.loaded["telescope.pickers"],
    ["telescope.finders"] = package.loaded["telescope.finders"],
    ["telescope.config"] = package.loaded["telescope.config"],
    ["telescope.actions"] = package.loaded["telescope.actions"],
    ["telescope.actions.state"] = package.loaded["telescope.actions.state"],
  }

  local captured, fake_entry_maker, fake_results
  package.loaded["telescope.builtin"] = {}
  package.loaded["telescope.pickers"] = {
    new = function(_, opts)
      captured = opts
      fake_entry_maker = opts.finder.entry_maker
      fake_results = opts.finder.results
      return {
        find = function()
          local entry = fake_entry_maker(fake_results[1])
          opts.attach_mappings(nil, nil)
          _G.__pickers_test_telescope_entry = entry
          _G.__pickers_test_telescope_select_default()
        end,
      }
    end,
  }
  package.loaded["telescope.finders"] = {
    new_table = function(o)
      return o
    end,
  }
  package.loaded["telescope.config"] = {
    values = {
      generic_sorter = function()
        return "sorter"
      end,
      file_previewer = function()
        return "file_previewer"
      end,
    },
  }
  package.loaded["telescope.actions"] = {
    select_default = {
      replace = function(_self, fn)
        _G.__pickers_test_telescope_select_default = function()
          fn(0)
        end
      end,
    },
    close = function() end,
  }
  package.loaded["telescope.actions.state"] = {
    get_selected_entry = function()
      return _G.__pickers_test_telescope_entry
    end,
  }
  package.loaded["pickers.engines.telescope"] = nil
  local telescope_engine = require("pickers.engines.telescope")

  local got
  telescope_engine.pick_item({
    items = { "alpha", "beta" },
    prompt = "Test",
    on_select = function(item)
      got = item
    end,
  })
  check("pick_item/telescope: plain strings — on_select gets the string back", got == "alpha")
  check("pick_item/telescope: plain strings — no previewer attached", captured.previewer == false)

  local items = { { text = "Tmpl A", file = "/tmp/a.lua" }, { text = "Tmpl B" } }
  local got_item
  telescope_engine.pick_item({
    items = items,
    prompt = "Templates",
    on_select = function(item)
      got_item = item
    end,
  })
  check(
    "pick_item/telescope: file-carrying items — previewer attached",
    captured.previewer == "file_previewer"
  )
  check("pick_item/telescope: on_select gets back the EXACT original table", got_item == items[1])

  _G.__pickers_test_telescope_entry = nil
  _G.__pickers_test_telescope_select_default = nil
  package.loaded["pickers.engines.telescope"] = nil
  for k, v in pairs(prev) do
    package.loaded[k] = v
  end
end

-- fzf-lua ─────────────────────────────────────────────────────────────────
do
  local prev_fzf = package.loaded["fzf-lua"]
  local captured
  package.loaded["fzf-lua"] = {
    fzf_exec = function(items, opts)
      captured = { items = items, opts = opts }
    end,
  }
  package.loaded["pickers.engines.fzf"] = nil
  local fzf_engine = require("pickers.engines.fzf")

  local got
  fzf_engine.pick_item({
    items = { "alpha", "beta" },
    prompt = "Test",
    on_select = function(item)
      got = item
    end,
  })
  check(
    "pick_item/fzf: plain strings — items passed through untouched",
    captured.items[1] == "alpha"
  )
  check(
    "pick_item/fzf: plain strings — no --delimiter set",
    captured.opts.fzf_opts["--delimiter"] == nil
  )
  check("pick_item/fzf: plain strings — no preview function set", captured.opts.preview == nil)
  captured.opts.actions["default"]({ "alpha" })
  check("pick_item/fzf: plain strings — on_select gets the raw string", got == "alpha")

  local items = { { text = "Tmpl A", file = "/tmp/a.lua" }, { text = "Tmpl B" } }
  fzf_engine.pick_item({ items = items, prompt = "Templates", on_select = function() end })
  check(
    "pick_item/fzf: file item — hidden tab-delimited file field",
    captured.items[1] == "Tmpl A\t/tmp/a.lua"
  )
  check(
    "pick_item/fzf: file item — item without `file` has no tab field",
    captured.items[2] == "Tmpl B"
  )
  check(
    "pick_item/fzf: file item — --with-nth hides the hidden field",
    captured.opts.fzf_opts["--with-nth"] == "1"
  )
  check(
    "pick_item/fzf: file item — preview is a Lua function (no shell `cat` dependency)",
    type(captured.opts.preview) == "function"
  )

  local tmpfile = vim.fn.tempname()
  vim.fn.writefile({ "line one", "line two" }, tmpfile)
  local preview_text = captured.opts.preview({ "Tmpl A\t" .. tmpfile })
  check(
    "pick_item/fzf: preview function reads the real file content",
    preview_text == "line one\nline two"
  )
  check(
    "pick_item/fzf: preview function returns empty for a no-file item",
    captured.opts.preview({ "Tmpl B" }) == ""
  )
  vim.fn.delete(tmpfile)

  local got_item
  fzf_engine.pick_item({
    items = items,
    prompt = "Templates",
    on_select = function(item)
      got_item = item
    end,
  })
  captured.opts.actions["default"]({ "Tmpl A\t/tmp/a.lua" })
  check(
    "pick_item/fzf: on_select gets back the EXACT original table via by_line",
    got_item == items[1]
  )

  package.loaded["pickers.engines.fzf"] = nil
  package.loaded["fzf-lua"] = prev_fzf
end

-- snacks ──────────────────────────────────────────────────────────────────
do
  local prev_snacks = package.loaded["snacks.picker"]
  local captured
  package.loaded["snacks.picker"] = {
    select = function(items, opts, on_choice)
      captured = { items = items, opts = opts, on_choice = on_choice }
    end,
  }
  package.loaded["pickers.engines.snacks"] = nil
  local snacks_engine = require("pickers.engines.snacks")

  snacks_engine.pick_item({ items = { "alpha" }, prompt = "Test", on_select = function() end })
  check(
    "pick_item/snacks: plain string — format_item uses tostring",
    captured.opts.format_item("alpha") == "alpha"
  )

  local items = { { text = "Tmpl A", file = "/tmp/a.lua" } }
  local got_item
  snacks_engine.pick_item({
    items = items,
    prompt = "Templates",
    on_select = function(item)
      got_item = item
    end,
  })
  check(
    "pick_item/snacks: table item — format_item reads .text",
    captured.opts.format_item(items[1]) == "Tmpl A"
  )
  captured.on_choice(items[1])
  check("pick_item/snacks: on_select receives the exact original table", got_item == items[1])

  package.loaded["pickers.engines.snacks"] = nil
  package.loaded["snacks.picker"] = prev_snacks
end

-- ── search-flag escalation ──────────────────────────────────────────────────
--
-- `all` was the only accepted token, forcing hidden+no_ignore+follow together.
-- The three do different things — hidden reaches dotfiles, no_ignore reaches
-- ignored ones, follow crosses symlinks — so all-or-nothing meant walking
-- node_modules just to see a .env. What matters here is that `all` still
-- means all three, that each name works alone, that they combine, and that a
-- typo is reported rather than silently dropping the escalation.
do
  local files = require("pickers.actions.files")
  local real_run = files.run
  local seen
  files.run = function(_, _, override)
    seen = override
  end

  local function escalate(token)
    seen = nil
    require("pickers.command").handle({ fargs = { "cwd", "files", token } })
    return seen
  end

  local all = escalate("all")
  check(
    "find_all: `all` still means all three",
    type(all) == "table" and all.hidden and all.no_ignore and all.follow,
    vim.inspect(all)
  )

  local hidden = escalate("hidden")
  check(
    "find_all: a single flag sets only itself",
    type(hidden) == "table" and hidden.hidden and not hidden.no_ignore and not hidden.follow,
    vim.inspect(hidden)
  )

  local combo = escalate("hidden+follow")
  check(
    "find_all: `+` combines without pulling in the third",
    type(combo) == "table" and combo.hidden and combo.follow and not combo.no_ignore,
    vim.inspect(combo)
  )

  check("find_all: no token means no override", escalate(nil) == nil)
  check("find_all: an unknown flag yields no override", escalate("bogus") == nil)

  files.run = real_run
end

-- ── Summary ─────────────────────────────────────────────────────────────────
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
