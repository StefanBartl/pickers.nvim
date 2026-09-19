-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
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
  -- A test double over a typed module surface: replacing the field is the
  -- point of the case, not a second definition of it.
  ---@diagnostic disable-next-line: duplicate-set-field
  engines.load = function()
    return fake_engine
  end

  cmd.handle({ fargs = { "cwd", "files", "all" } })
  check(
    "command.handle: 'files all' forces hidden",
    captured and captured.find and captured.find.hidden == true
  )
  ---@cast captured table
  check("command.handle: 'files all' forces no_ignore", captured.find.no_ignore == true)
  check("command.handle: 'files all' forces follow", captured.find.follow == true)
  check(
    "command.handle: 'files all' does not mutate global cfg.find",
    config.get().find.hidden == false
  )

  -- Without the "all" token, plain configured defaults apply unforced.
  captured = nil
  cmd.handle({ fargs = { "cwd", "files" } })
  ---@cast captured table
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
  -- A test double over a typed module surface: replacing the field is the
  -- point of the case, not a second definition of it.
  ---@diagnostic disable-next-line: duplicate-set-field
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
  -- A test double over a typed module surface: replacing the field is the
  -- point of the case, not a second definition of it.
  ---@diagnostic disable-next-line: duplicate-set-field
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
  -- A test double over a typed module surface: replacing the field is the
  -- point of the case, not a second definition of it.
  ---@diagnostic disable-next-line: duplicate-set-field
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

-- ── pickers.keys — cheatsheet: <C-/> default, in-picker keymap panel ───────
do
  local config = require("pickers.config")
  local keys = require("pickers.keys")

  local cfg0 = config.get()
  check("keys: default cheatsheet lhs", cfg0.keys.cheatsheet == "<C-/>")

  local r = keys.resolve(cfg0)
  check("keys.resolve: cheatsheet lhs", has(r.cheatsheet.lhs, "<C-/>"))
  check(
    "keys.resolve: cheatsheet modes i+n",
    has(r.cheatsheet.modes, "i") and has(r.cheatsheet.modes, "n")
  )

  -- <C-?> was rejected as the default lhs: Neovim's own key-notation
  -- translation resolves it to the literal DEL byte (0x7F), the same byte
  -- terminals commonly send for the physical Backspace key (classic Unix
  -- `stty erase=^?` default) -- verify the resolvable half of that claim
  -- (the byte itself) so a future Neovim change would fail this, not just
  -- take the DEFAULTS.lua comment on faith.
  local c_question = vim.api.nvim_replace_termcodes("<C-?>", true, true, true)
  check("keys: <C-?> resolves to the DEL byte (0x7F)", c_question == "\127")
  local c_slash = vim.api.nvim_replace_termcodes("<C-/>", true, true, true)
  check("keys: <C-/> does NOT resolve to that same byte", c_slash ~= "\127")

  -- telescope adapter degrades to empty mappings when telescope is absent
  local tm = keys.telescope_mappings(cfg0)
  if pcall(require, "telescope.actions") then
    check("keys.telescope: cheatsheet bound (i)", tm.i["<C-/>"] ~= nil)
    check("keys.telescope: cheatsheet bound (n)", tm.n["<C-/>"] ~= nil)
  else
    check("keys.telescope: cheatsheet unbound (telescope absent)", tm.i["<C-/>"] == nil)
  end

  -- fzf-lua: cheatsheet is custom pickers.nvim logic, same class as
  -- create_file/open_background -- must NOT appear in keymap.builtin.
  local fk = keys.fzf_keymap(cfg0)
  check("keys.fzf: excludes cheatsheet", fk["<C-/>"] == nil)

  -- snacks adapter: also not part of the generic win() translation (own
  -- entry_actions concern, same as create_file/open_background).
  local win = keys.snacks_win(cfg0)
  check("keys.snacks: win() excludes cheatsheet", win.input.keys["<C-/>"] == nil)

  -- Unbinding via false
  config.apply({ keys = { cheatsheet = false } })
  check("keys: cheatsheet unbind", #keys.resolve(config.get()).cheatsheet.lhs == 0)

  -- Restore default for any later blocks relying on it.
  config.apply({ keys = { cheatsheet = "<C-/>" } })
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
  check("entry_actions.telescope: cheatsheet bound (i)", tm.i["<C-/>"] ~= nil)
  check("entry_actions.telescope: cheatsheet bound (n)", tm.n["<C-/>"] ~= nil)

  -- snacks adapter: get_keys()/get_input_keys()/get_actions() read
  -- keys.resolve() too.
  local snacks_adapter = require("pickers.entry_actions.adapters.snacks")
  local sk = snacks_adapter.get_keys()
  check("entry_actions.snacks: create_file key", sk["<C-a>"] == "create_file")
  check("entry_actions.snacks: open_background key", sk["<S-CR>"] == "open_background")
  check("entry_actions.snacks: cheatsheet key", sk["<C-/>"] == "cheatsheet")
  local sik = snacks_adapter.get_input_keys()
  check(
    "entry_actions.snacks: cheatsheet input key",
    sik["<C-/>"] ~= nil and sik["<C-/>"][1] == "cheatsheet"
  )
  local sa = snacks_adapter.get_actions()
  check(
    "entry_actions.snacks: cheatsheet action fn",
    type(sa.cheatsheet) == "table" and type(sa.cheatsheet.action) == "function"
  )
  check(
    "entry_actions.snacks: cheatsheet desc reused from pickers.cheatsheet.DESCRIPTIONS",
    sa.cheatsheet.desc == require("pickers.cheatsheet").DESCRIPTIONS.cheatsheet
  )
  check(
    "entry_actions.snacks: create_file/open_background also carry desc",
    type(sa.create_file.desc) == "string" and type(sa.open_background.desc) == "string"
  )

  -- fzf adapter: fixed ctrl-a/ctrl-o/shift-enter/f1, gated only by keys.enable
  -- (cheatsheet's OWN lhs config has no effect on this engine -- see
  -- pickers.entry_actions.adapters.fzf's @description).
  local fzf_adapter = require("pickers.entry_actions.adapters.fzf")
  local fa = fzf_adapter.get_actions()
  check("entry_actions.fzf: ctrl-a present when enabled", type(fa["ctrl-a"]) == "function")
  check("entry_actions.fzf: f1 present when enabled", type(fa["f1"]) == "function")

  config.apply({ keys = { cheatsheet = false } })
  check(
    "entry_actions.fzf: f1 present even when keys.cheatsheet=false (fixed, not config-driven)",
    type(fzf_adapter.get_actions()["f1"]) == "function"
  )
  check(
    "entry_actions.telescope: cheatsheet unbound when keys.cheatsheet=false",
    ts.get_mappings().i["<C-/>"] == nil
  )
  config.apply({ keys = { cheatsheet = "<C-/>" } })

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
      cheatsheet = "<C-/>",
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

-- ── quickfix: preview float + refine filter over a real :copen ──────────────
do
  local quickfix = require("pickers.quickfix")
  local config = require("pickers.config")

  -- Defaults and the deep-merge that keeps a `false` key.
  local cfg = config.get()
  check("quickfix: on by default", cfg.quickfix and cfg.quickfix.enabled == true)
  check(
    "quickfix: default keys",
    cfg.quickfix.keys.filter == "zf" and cfg.quickfix.keys.restore == "zF"
  )
  config.apply({ quickfix = { keys = { toggle_preview = false }, preview = { height = 6 } } })
  check("quickfix: apply merges preview.height", config.get().quickfix.preview.height == 6)
  check("quickfix: apply keeps a false key", config.get().quickfix.keys.toggle_preview == false)
  config.apply({
    quickfix = { keys = { toggle_preview = "p" }, preview = { height = 12, delay_ms = 0 } },
  })

  -- A temp file with known lines, a quickfix list pointing into it.
  local path = vim.fn.tempname() .. ".lua"
  local lines = {}
  for i = 1, 40 do
    lines[i] = ("local line_%d = %d"):format(i, i)
  end
  vim.fn.writefile(lines, path)
  vim.fn.setqflist({}, "r", {
    title = "Spec",
    items = {
      { filename = path, lnum = 20, text = "local line_20 = 20" },
      { filename = path, lnum = 5, text = "local line_5 = 5" },
      { filename = path, lnum = 33, text = "other text" },
    },
  })
  quickfix.setup(config.get())
  vim.cmd("copen")
  local qfwin = vim.api.nvim_get_current_win()
  local qfbuf = vim.api.nvim_get_current_buf()
  check("quickfix: attached on FileType qf", vim.b[qfbuf].pickers_quickfix_attached == true)
  check("quickfix: zf bound in the list", vim.fn.maparg("zf", "n", false, true).buffer == 1)

  -- Preview for the entry under the cursor: file lines around lnum, target highlighted.
  vim.api.nvim_win_set_cursor(qfwin, { 1, 0 })
  check("quickfix: preview drawn", quickfix.preview(qfwin) == true)
  local pwin = quickfix.preview_win(qfbuf)
  check("quickfix: preview window exists", pwin ~= nil and vim.api.nvim_win_is_valid(pwin))
  local pbuf = vim.api.nvim_win_get_buf(pwin)
  local plines = vim.api.nvim_buf_get_lines(pbuf, 0, -1, false)
  check(
    "quickfix: preview starts `context` lines above",
    plines[1] == "local line_16 = 16",
    plines[1]
  )
  check("quickfix: preview has `height` lines", #plines == 12, tostring(#plines))
  local marks = vim.api.nvim_buf_get_extmarks(
    pbuf,
    vim.api.nvim_create_namespace("pickers_quickfix"),
    0,
    -1,
    { details = true }
  )
  check("quickfix: target line highlighted", #marks == 1 and marks[1][2] == 4, vim.inspect(marks))
  local pcfg = vim.api.nvim_win_get_config(pwin)
  check(
    "quickfix: preview anchored to the list window",
    pcfg.relative == "win" and pcfg.focusable == false
  )

  -- Second entry: lnum 5 -> first shown line is 1.
  vim.api.nvim_win_set_cursor(qfwin, { 2, 0 })
  quickfix.preview(qfwin)
  plines = vim.api.nvim_buf_get_lines(pbuf, 0, -1, false)
  check("quickfix: preview clamps to the file start", plines[1] == "local line_1 = 1", plines[1])

  -- Toggle off closes, toggle on redraws.
  check("quickfix: toggle_preview off", quickfix.toggle_preview() == false)
  check("quickfix: preview closed", quickfix.preview_win(qfbuf) == nil)
  check("quickfix: toggle_preview on", quickfix.toggle_preview() == true)
  check("quickfix: preview back", quickfix.preview_win(qfbuf) ~= nil)

  -- Filter through the refine handle, non-destructively, then restore.
  quickfix.apply(qfwin) -- empty stack: remembers the original, keeps all three
  local h = quickfix.handle(qfbuf)
  check("quickfix: refine handle created", h ~= nil)
  h.stack[#h.stack + 1] = { field = "text", term = "line_", mode = "substr", negate = false }
  local shown, total = quickfix.apply(qfwin)
  check("quickfix: apply filters the list", shown == 2 and total == 3, shown .. "/" .. total)
  local q = vim.fn.getqflist({ items = 1, title = 1 })
  check("quickfix: list replaced", #q.items == 2 and q.items[2].lnum == 5)
  check(
    "quickfix: title shows the stack",
    q.title:find("text~line_", 1, true) ~= nil and q.title:find("(2/3)", 1, true) ~= nil,
    q.title
  )
  h.stack[#h.stack + 1] = { field = "text", term = "20", mode = "substr", negate = false }
  shown = quickfix.apply(qfwin)
  check("quickfix: a second clause filters the ORIGINAL list", shown == 1)
  quickfix.restore(qfwin)
  q = vim.fn.getqflist({ items = 1, title = 1 })
  check("quickfix: restore puts the full list back", #q.items == 3 and q.title == "Spec", q.title)
  check("quickfix: restore clears the stack", not h:is_active())

  -- Leaving the list closes the preview; disabling stops attaching.
  vim.cmd("wincmd p")
  vim.api.nvim_exec_autocmds("WinLeave", { buffer = qfbuf })
  check("quickfix: preview closed on WinLeave", quickfix.preview_win(qfbuf) == nil)
  vim.cmd("cclose")
  -- The qf buffer is reused across :cclose/:copen, so attach() is asked
  -- directly, with the per-buffer marker cleared and the feature off.
  config.apply({ quickfix = { enabled = false } })
  quickfix.setup(config.get())
  vim.api.nvim_buf_del_var(qfbuf, "pickers_quickfix_attached")
  quickfix.attach(qfbuf)
  check("quickfix: disabled -> not attached", vim.b[qfbuf].pickers_quickfix_attached ~= true)
  config.apply({ quickfix = { enabled = true } })
  vim.fn.delete(path)
end

-- ── pickers.sources.github — gh argv + JSON -> items (pure) ─────────────────
do
  local gh = require("pickers.sources.github")
  local argv = gh.command("issue", "all", 5)
  check(
    "github.command: gh issue list",
    argv[1] == "gh" and argv[2] == "issue" and argv[3] == "list"
  )
  check("github.command: state + limit", has(argv, "all") and has(argv, "5"))
  check("github.command: pr", gh.command("pr")[2] == "pr")
  local json = vim.json.encode({
    {
      number = 12,
      title = "Broken thing",
      state = "OPEN",
      url = "https://x/12",
      author = { login = "ann" },
    },
    { number = 7, title = "Old", state = "CLOSED", url = "https://x/7" },
    { title = "no number, skipped" },
  })
  local items, err = gh.parse(json, "issue")
  check("github.parse: two items", items ~= nil and #items == 2 and err == nil)
  check(
    "github.parse: text carries number/state/title/author",
    items[1].text:find("#12", 1, true) ~= nil
      and items[1].text:find("open", 1, true) ~= nil
      and items[1].text:find("@ann", 1, true) ~= nil,
    items[1].text
  )
  check(
    "github.parse: fields",
    items[2].number == 7 and items[2].url == "https://x/7" and items[2].kind == "issue"
  )
  local bad, bad_err = gh.parse("not json", "pr")
  check("github.parse: bad JSON reported", bad == nil and bad_err ~= nil)

  -- pick() hands the items to the given engine's pick_item.
  local got
  local fake_engine = {
    pick_item = function(opts)
      got = opts
    end,
  }
  local orig_fetch = gh.fetch
  gh.fetch = function(_, _, cb)
    cb(items, nil)
  end
  gh.pick("issue", "open", fake_engine)
  gh.fetch = orig_fetch
  check(
    "github.pick: prompt + items to pick_item",
    got ~= nil and got.prompt:find("Issues", 1, true) ~= nil and #got.items == 2
  )
end

-- ── pickers.browse — directory entries + the picker flow on a fake engine ───
do
  local browse = require("pickers.browse")
  local broot = vim.fn.tempname()
  vim.fn.mkdir(broot .. "/sub", "p")
  vim.fn.writefile({ "x" }, broot .. "/b.txt")
  vim.fn.writefile({ "y" }, broot .. "/A.lua")
  vim.fn.writefile({ "z" }, broot .. "/.hidden")

  local entries = browse.entries(broot)
  local texts = vim.tbl_map(function(e)
    return e.text
  end, entries)
  check(
    "browse.entries: .. first, dirs, files (case-insensitive), actions last",
    texts[1] == "../"
      and texts[2] == "sub/"
      and texts[3] == ".hidden"
      and texts[4] == "A.lua"
      and texts[5] == "b.txt"
      and texts[6] == "[+] new file…",
    vim.inspect(texts)
  )
  check(
    "browse.entries: file entries carry `file` for the preview",
    entries[5].file == entries[5].path
  )
  check(
    "browse.entries: hidden = false drops dotfiles",
    #browse.entries(broot, { hidden = false, actions = false }) == 4
  )
  check("browse.entries: unreadable dir -> empty", #browse.entries(broot .. "/nope") == 0)

  -- The flow: pick a dir -> reopened there; pick a file -> edited.
  local prompts, last_opts = {}, nil
  local fake_engine = {
    pick_item = function(opts)
      prompts[#prompts + 1] = opts.prompt
      last_opts = opts
    end,
  }
  browse.open(broot, { engine_mod = fake_engine })
  check(
    "browse.open: prompt names the dir",
    #prompts == 1 and prompts[1]:find("Browse", 1, true) ~= nil
  )
  local sub
  for _, e in ipairs(last_opts.items) do
    if e.text == "sub/" then sub = e end
  end
  last_opts.on_select(sub)
  check(
    "browse.open: picking a dir reopens there",
    #prompts == 2 and last_opts.items[1].text == "../"
  )
  last_opts.on_select(last_opts.items[1])
  check("browse.open: .. goes back up", #prompts == 3)
  local file
  for _, e in ipairs(last_opts.items) do
    if e.text == "b.txt" then file = e end
  end
  last_opts.on_select(file)
  check(
    "browse.open: picking a file edits it",
    vim.fs.normalize(vim.api.nvim_buf_get_name(0)) == vim.fs.normalize(broot .. "/b.txt")
  )

  -- Operations.
  check(
    "browse.new_dir",
    browse.new_dir(broot .. "/made") and vim.fn.isdirectory(broot .. "/made") == 1
  )
  local ok_r = browse.rename(broot .. "/b.txt", broot .. "/c.txt")
  check(
    "browse.rename",
    ok_r
      and vim.fn.filereadable(broot .. "/c.txt") == 1
      and vim.fn.filereadable(broot .. "/b.txt") == 0
  )
  check(
    "browse.rename: buffer follows",
    vim.fs.normalize(vim.api.nvim_buf_get_name(0)) == vim.fs.normalize(broot .. "/c.txt")
  )
  local ok_r2, err_r2 = browse.rename(broot .. "/c.txt", broot .. "/A.lua")
  check("browse.rename: refuses to overwrite", ok_r2 == false and err_r2 ~= nil)
  vim.cmd("enew!")
  check(
    "browse.delete: file",
    browse.delete(broot .. "/c.txt") and vim.fn.filereadable(broot .. "/c.txt") == 0
  )
  check(
    "browse.delete: dir",
    browse.delete(broot .. "/made") and vim.fn.isdirectory(broot .. "/made") == 0
  )
  vim.fn.delete(broot, "rf")
end

-- ── pickers.tabs — groups, switch, query carry-over, title suffix ────────────
do
  local tabs = require("pickers.tabs")
  local config = require("pickers.config")
  check("tabs: default groups", has(tabs.names(), "default") and has(tabs.names(), "git"))
  config.apply({ tabs = { groups = { mine = { "cwd files", "builtin buffers" }, git = false } } })
  check(
    "tabs: apply adds a group and drops one",
    has(tabs.names(), "mine") and not has(tabs.names(), "git")
  )
  check("tabs: unknown group -> nil", tabs.targets("nope") == nil)

  -- command.handle stubbed: record the fargs + query each run gets.
  local command = require("pickers.command")
  local orig_handle = command.handle
  local runs = {}
  command.handle = function(opts)
    runs[#runs + 1] = { fargs = opts.fargs, query = opts.query }
  end
  check("tabs: no state before open", tabs.current() == nil and tabs.title_suffix() == "")
  tabs.open("mine")
  check(
    "tabs.open: runs the first target",
    #runs == 1 and table.concat(runs[1].fargs, " ") == "cwd files" and runs[1].query == nil
  )
  check("tabs: title suffix", tabs.title_suffix() == " [1/2 cwd files]", tabs.title_suffix())
  check("tabs.next: switches", tabs.next("foo") == true)
  vim.wait(50, function()
    return #runs == 2
  end)
  check(
    "tabs.next: next target with the query",
    #runs == 2 and table.concat(runs[2].fargs, " ") == "builtin buffers" and runs[2].query == "foo",
    vim.inspect(runs[2])
  )
  tabs.next("bar")
  vim.wait(50, function()
    return #runs == 3
  end)
  check("tabs.next: wraps around", #runs == 3 and table.concat(runs[3].fargs, " ") == "cwd files")
  tabs.prev()
  vim.wait(50, function()
    return #runs == 4
  end)
  check(
    "tabs.prev: back to the last target",
    #runs == 4 and table.concat(runs[4].fargs, " ") == "builtin buffers"
  )
  tabs.reset()
  check("tabs.switch: nothing active -> false", tabs.switch(1) == false)
  command.handle = orig_handle
  config.apply({
    tabs = {
      groups = {
        git = { "builtin git_branches", "builtin git_commits", "builtin git_stash" },
        mine = false,
      },
    },
  })

  -- The query reaches the files action through command.handle.
  local files = require("pickers.actions.files")
  local orig_run = files.run
  local seen_source
  files.run = function(source)
    seen_source = source
  end
  local orig_load = require("pickers.engines").load
  require("pickers.engines").load = function()
    return { pick_files = function() end }
  end
  command.handle({ fargs = { "cwd", "files" }, query = "carried" })
  require("pickers.engines").load = orig_load
  files.run = orig_run
  check(
    "command.handle: query lands on the source",
    seen_source ~= nil and seen_source.query == "carried"
  )

  -- keys: the new opt-in actions resolve unbound by default and bind when set.
  local keys = require("pickers.keys")
  local r = keys.resolve(config.get())
  check("keys: tab_next unbound by default", r.tab_next ~= nil and #r.tab_next.lhs == 0)
  config.apply({ keys = { tab_next = "<Tab>", tab_prev = "<S-Tab>" } })
  r = keys.resolve(config.get())
  check("keys: tab_next bound", has(r.tab_next.lhs, "<Tab>"))
  local ts = require("pickers.keys.adapters.telescope").mappings(r)
  local sw = require("pickers.keys.adapters.snacks").win(r)
  local acts = keys.snacks_actions()
  check(
    "keys/snacks: tab_next in win keys + actions",
    sw.input.keys["<Tab>"] ~= nil and type(acts.tab_next) == "function"
  )
  check(
    "keys/fzf: tab_next reported as skipped",
    has(require("pickers.keys.adapters.fzf").skipped(r), "tab_next")
  )
  check(
    "keys/telescope: tab_next maps to a function (or telescope absent)",
    ts.i["<Tab>"] == nil or type(ts.i["<Tab>"]) == "function"
  )
  config.apply({ keys = { tab_next = false, tab_prev = false } })
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

    -- dir's nav slot: aliases, numeric depths, and the "path=" prefix.
    local nav_completion = vim.fn.getcompletion("Pickers dir ", "cmdline")
    check("complete: dir nav offers action words too", has(nav_completion, "files"))
    check("complete: dir nav offers depth_aliases (git)", has(nav_completion, "git"))
    check("complete: dir nav offers numeric depth 3", has(nav_completion, "3"))
    check("complete: dir nav offers path=", has(nav_completion, "path="))

    -- A collection named "cwd" collides with a built-in scope: M.register's
    -- `used` guard must skip it (first-match-wins) rather than ask the
    -- composer to register the same route path twice.
    require("pickers.config").apply({
      collections = {
        { name = "cwd", dir = vim.fn.getcwd() },
        { name = "notes", dir = "/tmp/notes" },
      },
    })
    local ok_reregister = pcall(cmp.register, require("pickers.config").get())
    check("complete: re-register with a colliding collection name does not throw", ok_reregister)

    local scopes2 = vim.fn.getcompletion("Pickers ", "cmdline")
    local cwd_count = 0
    for _, s in ipairs(scopes2) do
      if s == "cwd" then cwd_count = cwd_count + 1 end
    end
    check("complete: colliding collection name does not appear twice", cwd_count == 1)

    local acts2 = vim.fn.getcompletion("Pickers cwd ", "cmdline")
    check(
      "complete: built-in cwd route still resolves actions after collision",
      has(acts2, "files")
    )

    require("pickers.config").apply({ collections = {} })
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
  check(
    "builtins: explorer on fzf is the in-house browser",
    type(explorer.fzf) == "table" and type(explorer.fzf.run) == "function"
  )
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
  check(
    "builtins: gh_issue runs on every engine",
    type(gh_issue.telescope.run) == "function" and type(gh_issue.fzf.run) == "function"
  )

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

-- ── pickers.smart.frecency — M.patch() autocmd registration ─────────────────
-- BufReadPost/VimLeavePre are only ever created here, so this suite is free
-- to clean them up itself afterwards without touching any other test.
do
  package.loaded["pickers.smart.frecency"] = nil
  local frecency = require("pickers.smart.frecency")
  local config = require("pickers.config")

  local tmp_dir = vim.fn.tempname()
  vim.fn.mkdir(tmp_dir, "p")
  local cfg = vim.tbl_deep_extend(
    "force",
    config.get(),
    { smart = { frecency = { enabled = true, weight = 1.0, dir = tmp_dir } } }
  )

  -- `nvim_get_autocmds` raises for a group that does not exist yet (this is
  -- the first real -- non-stubbed -- autocmd this file registers), so the
  -- lookup is pcall'd, same as lib.nvim's own internal `group_exists()`.
  ---@param event string
  local function count(event)
    local ok, acs = pcall(vim.api.nvim_get_autocmds, { group = "pickers.nvim", event = event })
    return ok and #acs or 0
  end

  local before_read, before_leave = count("BufReadPost"), count("VimLeavePre")

  frecency.patch(cfg)
  check(
    "frecency.patch: registers one BufReadPost visit-recorder",
    count("BufReadPost") == before_read + 1
  )
  check("frecency.patch: registers one VimLeavePre flush", count("VimLeavePre") == before_leave + 1)

  -- BUG: `M.patch()` has no idempotency guard of its own, and the shared
  -- "pickers.nvim" augroup it registers into is resolved by NAME through
  -- `lib.nvim.bindings.autocmd.group()`, which memoizes the id and hands it
  -- back WITHOUT clearing unless the caller explicitly passes `clear=true`
  -- -- which frecency.lua never does. So calling `pickers.setup()` a second
  -- time with `smart.frecency.enabled=true` both times (a config reload,
  -- or a second plugin-manager `config()` run) does not replace the
  -- handler, it ADDS a second one: every buffer read gets recorded twice
  -- and `VimLeavePre` flushes twice, permanently, for the rest of the
  -- session -- the same "string augroup resolved without clearing" family
  -- already found in other repos in this campaign.
  frecency.patch(cfg)
  check(
    "BUG: frecency.patch() called twice registers a SECOND BufReadPost "
      .. "handler instead of staying at one",
    count("BufReadPost") == before_read + 2,
    "count=" .. count("BufReadPost")
  )
  check(
    "BUG: ...and a second VimLeavePre flush handler too",
    count("VimLeavePre") == before_leave + 2,
    "count=" .. count("VimLeavePre")
  )

  vim.api.nvim_clear_autocmds({ group = "pickers.nvim", event = { "BufReadPost", "VimLeavePre" } })
  vim.fn.delete(tmp_dir, "rf")
  package.loaded["pickers.smart.frecency"] = nil
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
  -- A test double over a typed module surface: replacing the field is the
  -- point of the case, not a second definition of it.
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.fn.executable = function(name)
    if name == "fd" then return 1 end
    return 0
  end

  local captured_title
  package.loaded["ui.kit"] = {
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
  package.loaded["ui.kit"] = nil
  package.loaded["pickers.sources.system"] = nil
end
-- luacheck: pop

-- ── entry_actions.create_file: name prompt routes through kit.input ────────
do
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")

  local captured_title
  package.loaded["ui.kit"] = {
    input = function(opts)
      captured_title = opts.title
      opts.on_submit("newfile.txt")
    end,
  }
  package.loaded["pickers.entry_actions.create_file"] = nil
  local create_file = require("pickers.entry_actions.create_file")

  create_file.run(dir)
  -- M.run schedules the prompt; wait for it to have been asked rather than
  -- for a stopwatch, the way when_loaded's scheduled fallback below does.
  vim.wait(500, function()
    return captured_title ~= nil
  end)

  check(
    "entry_actions.create_file: kit.input was asked",
    captured_title ~= nil,
    tostring(captured_title)
  )
  check(
    "entry_actions.create_file: file created from the submitted name",
    vim.fn.filereadable(dir .. "/newfile.txt") == 1
  )

  package.loaded["ui.kit"] = nil
  package.loaded["pickers.entry_actions.create_file"] = nil
end

-- ── ui.dir_nav_picker: "path=…" entry routes through kit.input ──────────────
do
  local captured_title
  package.loaded["ui.kit"] = {
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

  package.loaded["ui.kit"] = nil
  package.loaded["pickers.ui.dir_nav_picker"] = nil
end

-- ── pickers.cheatsheet: lines() reads keys.resolve(), show() drives kit.viewer ─
do
  local config = require("pickers.config")
  package.loaded["pickers.cheatsheet"] = nil
  local cheatsheet = require("pickers.cheatsheet")

  config.apply({ keys = { enable = true, cheatsheet = "<C-/>", history_back = "<C-p>" } })

  local lines = cheatsheet.lines()
  local text = table.concat(lines, "\n")
  check("cheatsheet.lines: shows the bound cheatsheet key", text:find("<C-/>", 1, true) ~= nil)
  check(
    "cheatsheet.lines: shows its description",
    text:find("Show this cheatsheet", 1, true) ~= nil
  )
  check(
    "cheatsheet.lines: shows another bound action (history_back)",
    text:find("<C-p>", 1, true) ~= nil
  )
  check("cheatsheet.lines: footer names q/<Esc>", text:find("q / <Esc>  close", 1, true) ~= nil)

  config.apply({ keys = { history_back = false } })
  local lines_unbound = cheatsheet.lines()
  check(
    "cheatsheet.lines: an unbound action's lhs does not appear",
    table.concat(lines_unbound, "\n"):find("<C-p>", 1, true) == nil
  )
  config.apply({ keys = { history_back = "<C-p>" } })

  local overridden = cheatsheet.lines({ cheatsheet = "f1" })
  local overridden_text = table.concat(overridden, "\n")
  check(
    "cheatsheet.lines: an override wins over keys.resolve()'s lhs (fzf-lua's f1)",
    overridden_text:find("f1", 1, true) ~= nil and overridden_text:find("<C-/>", 1, true) == nil
  )

  -- show(): drives ui.kit.viewer and wires on_close through the returned surface.
  local captured_opts
  local captured_on_close
  package.loaded["ui.kit"] = {
    viewer = function(opts)
      captured_opts = opts
      return {
        on_close = function(_self, fn)
          captured_on_close = fn
        end,
      }
    end,
  }
  package.loaded["pickers.cheatsheet"] = nil
  local cheatsheet2 = require("pickers.cheatsheet")

  local closed = false
  cheatsheet2.show({
    on_close = function()
      closed = true
    end,
  })
  check("cheatsheet.show: opened kit.viewer", captured_opts ~= nil)
  check("cheatsheet.show: title", captured_opts and captured_opts.title == "pickers.nvim keymaps")
  check(
    "cheatsheet.show: lines match lines()",
    captured_opts
      and table.concat(captured_opts.lines, "\n"):find("Show this cheatsheet", 1, true) ~= nil
  )
  check(
    "cheatsheet.show: on_close wired through the surface",
    type(captured_on_close) == "function"
  )
  if captured_on_close then captured_on_close() end
  check("cheatsheet.show: on_close fires", closed)

  -- Fallback when ui.kit has no viewer(): must not throw, must still call on_close.
  package.loaded["ui.kit"] = nil
  package.loaded["pickers.cheatsheet"] = nil
  local cheatsheet3 = require("pickers.cheatsheet")
  local fallback_closed = false
  local ok_fallback = pcall(cheatsheet3.show, {
    on_close = function()
      fallback_closed = true
    end,
  })
  check("cheatsheet.show: fallback path does not throw", ok_fallback)
  check("cheatsheet.show: fallback path still fires on_close", fallback_closed)

  package.loaded["ui.kit"] = nil
  package.loaded["pickers.cheatsheet"] = nil
end

-- ── pickers.cheatsheet.hint(): title/header text for telescope/fzf-lua ──────
do
  local config = require("pickers.config")
  package.loaded["pickers.cheatsheet"] = nil
  local cheatsheet = require("pickers.cheatsheet")

  config.apply({ keys = { enable = true, cheatsheet = "<C-/>" } })
  check(
    "cheatsheet.hint: telescope names the bound key",
    cheatsheet.hint("telescope") == "<C-/> cheatsheet"
  )
  check(
    "cheatsheet.hint: fzf-lua always says f1 (fixed, ignores keys.cheatsheet's lhs)",
    cheatsheet.hint("fzf-lua") == "f1 cheatsheet"
  )

  config.apply({ keys = { cheatsheet = false } })
  check("cheatsheet.hint: telescope is empty when unbound", cheatsheet.hint("telescope") == "")
  check(
    "cheatsheet.hint: fzf-lua still says f1 when keys.cheatsheet=false (fixed binding)",
    cheatsheet.hint("fzf-lua") == "f1 cheatsheet"
  )

  config.apply({ keys = { enable = false } })
  check(
    "cheatsheet.hint: telescope empty when keys.enable=false",
    cheatsheet.hint("telescope") == ""
  )
  check("cheatsheet.hint: fzf-lua empty when keys.enable=false", cheatsheet.hint("fzf-lua") == "")

  config.apply({ keys = { enable = true, cheatsheet = "<C-/>" } })
  package.loaded["pickers.cheatsheet"] = nil
end
-- (the actual results_title/--header wiring into engines.telescope/engines.fzf
-- is exercised further down, in the "engine live_grep option tests" block,
-- alongside the other stubbed fzf-lua/telescope live_grep checks)

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

-- ── pickers.integrations.images — image previews via images.nvim ────────────
-- images.nvim is a soft dependency and is deliberately NOT on the test
-- runtimepath, so the "not installed" half below is the real behaviour, not a
-- simulation of it. The "installed" half runs against a stub injected into
-- package.loaded — the only way to check the branch logic without a terminal
-- that can actually draw, which is also why the drawing itself is images.nvim's
-- own test suite's problem and not this one's.
do
  local images = require("pickers.integrations.images")

  -- ── images.nvim absent: every answer is a clean no ────────────────────────
  check(
    "integrations.images: available() is false without images.nvim",
    images.available() == false
  )
  check(
    "integrations.images: is_image() is false without images.nvim",
    images.is_image("/tmp/a.png") == false
  )
  check(
    "integrations.images: preview() refuses without images.nvim",
    images.preview(0, "/tmp/a.png") == false
  )
  images.clear() -- a no-op, not an error

  local cfg_mod = require("pickers.config")
  check("integrations.images: enabled() defaults to true", images.enabled() == true)
  cfg_mod.apply({ images = { enabled = false } })
  check("integrations.images: images.enabled = false is honoured", images.enabled() == false)
  cfg_mod.apply({ images = { enabled = true } })
  check("integrations.images: the opt-out is reversible", images.enabled() == true)

  -- ── images.nvim present (stubbed): the bridge forwards ────────────────────
  local prev_api = package.loaded["images.integrations.picker"]
  local drawn, cleared = {}, 0
  package.loaded["images.integrations.picker"] = {
    available = function()
      return true
    end,
    is_image = function(path)
      return type(path) == "string" and path:lower():match("%.png$") ~= nil
    end,
    preview = function(winid, file)
      drawn[#drawn + 1] = { winid = winid, file = file }
      return true
    end,
    clear = function()
      cleared = cleared + 1
    end,
  }

  check("integrations.images: available() follows images.nvim", images.available() == true)
  check("integrations.images: is_image() delegates", images.is_image("/x/a.png") == true)
  check("integrations.images: a non-image is still a no", images.is_image("/x/a.md") == false)
  -- This stub has no is_previewable/is_pdf -- an images.nvim that predates the
  -- PDF half. The integration has to keep working for images rather than go
  -- dark, which is the whole point of checking the surface by shape.
  check(
    "integrations.images: is_previewable() falls back to is_image() on an older images.nvim",
    images.is_previewable("/x/a.png") == true and images.is_previewable("/x/doc.pdf") == false
  )
  check(
    "integrations.images: is_pdf() is false on an older images.nvim",
    images.is_pdf("/x/doc.pdf") == false
  )
  check(
    "integrations.images: preview() forwards window + file",
    images.preview(7, "/x/a.png") == true and drawn[1].winid == 7 and drawn[1].file == "/x/a.png"
  )

  -- ── snacks adapter: image draws, everything else falls through ────────────
  local prev_snacks = package.loaded["snacks.picker.preview"]
  local fell_through = 0
  package.loaded["snacks.picker.preview"] = {
    file = function()
      fell_through = fell_through + 1
    end,
  }

  local preview_fn = require("pickers.integrations.images.adapters.snacks").preview_fn()
  check(
    "images/snacks: a preview function is returned when available",
    type(preview_fn) == "function"
  )

  local function ctx_for(file)
    return {
      win = 42,
      item = { file = file },
      preview = { reset = function() end, set_title = function() end },
    }
  end

  local before = #drawn
  preview_fn(ctx_for("/x/shot.png"))
  check(
    "images/snacks: an image entry is drawn into the preview window",
    #drawn == before + 1 and drawn[#drawn].winid == 42 and fell_through == 0
  )

  local cleared_before = cleared
  preview_fn(ctx_for("/x/notes.md"))
  check(
    "images/snacks: a text entry clears the overlay and falls through to snacks",
    cleared == cleared_before + 1 and fell_through == 1 and #drawn == before + 1
  )

  package.loaded["snacks.picker.preview"] = prev_snacks

  -- ── telescope adapter: same branch, telescope's own previewer behind it ───
  local prev_tele = {
    ["telescope.previewers"] = package.loaded["telescope.previewers"],
    ["telescope.from_entry"] = package.loaded["telescope.from_entry"],
    ["telescope.config"] = package.loaded["telescope.config"],
  }
  local maker_calls = 0
  package.loaded["telescope.previewers"] = {
    new_buffer_previewer = function(o)
      return o
    end,
  }
  package.loaded["telescope.from_entry"] = {
    path = function(entry)
      return entry.path
    end,
  }
  package.loaded["telescope.config"] = {
    values = {
      preview = {},
      buffer_previewer_maker = function()
        maker_calls = maker_calls + 1
      end,
    },
  }

  local tele = require("pickers.integrations.images.adapters.telescope")
  local previewer = tele.previewer()
  check("images/telescope: a previewer is built when available", type(previewer) == "table")

  local state = { state = { bufnr = vim.api.nvim_create_buf(false, true), winid = 0 } }
  before, cleared_before = #drawn, cleared
  previewer.define_preview(state, { path = "/x/shot.png" })
  check(
    "images/telescope: an image entry is drawn, telescope's maker untouched",
    #drawn == before + 1 and drawn[#drawn].file == "/x/shot.png" and maker_calls == 0
  )

  previewer.define_preview(state, { path = "/x/notes.md" })
  check(
    "images/telescope: a text entry clears the overlay and hands over to telescope",
    maker_calls == 1 and cleared == cleared_before + 1 and #drawn == before + 1
  )

  -- Previews switched off in telescope's own config: stay out of the way.
  package.loaded["telescope.config"] = { values = { preview = false } }
  check("images/telescope: `preview = false` yields no previewer", tele.previewer() == nil)

  for k, v in pairs(prev_tele) do
    package.loaded[k] = v
  end
  package.loaded["images.integrations.picker"] = prev_api
end

-- ── pickers.integrations.images — PDF entries ───────────────────────────────
-- The same bridge, asked the other half of its question. images.nvim is still
-- not on the runtimepath, so the surface is stubbed again -- this time with the
-- PDF half present, which is what lets the two adapters be checked against an
-- entry that is ACCEPTED BEFORE ITS PICTURE EXISTS. That is the whole
-- difference between a PDF and an image here, and everything below is one of
-- its two consequences: the line that says what the wait is for, and the
-- fall-through that has to survive the wait without landing on somebody else's
-- preview.
do
  local images = require("pickers.integrations.images")
  local prev_api = package.loaded["images.integrations.picker"]

  local drawn, cleared = {}, 0
  ---@type fun(ok: boolean, err: string|nil)|nil the last accepted draw's on_done, held back
  local pending
  ---@type fun()|nil …and its on_ready, so both can be fired out of turn
  local pending_ready
  local function matches(path, pattern)
    return type(path) == "string" and path:lower():match(pattern) ~= nil
  end
  package.loaded["images.integrations.picker"] = {
    available = function()
      return true
    end,
    is_image = function(path)
      return matches(path, "%.png$")
    end,
    is_pdf = function(path)
      return matches(path, "%.pdf$")
    end,
    is_previewable = function(path)
      return matches(path, "%.png$") or matches(path, "%.pdf$")
    end,
    preview = function(winid, file, opts)
      drawn[#drawn + 1] = { winid = winid, file = file }
      pending = opts and opts.on_done or nil
      pending_ready = opts and opts.on_ready or nil
      return true
    end,
    clear = function()
      cleared = cleared + 1
    end,
  }

  check("integrations.images: is_pdf() delegates", images.is_pdf("/x/doc.pdf") == true)
  check("integrations.images: a png is not a PDF", images.is_pdf("/x/a.png") == false)
  check(
    "integrations.images: is_previewable() covers both",
    images.is_previewable("/x/doc.pdf") == true and images.is_previewable("/x/a.png") == true
  )
  check(
    "integrations.images: a text file is not previewable",
    images.is_previewable("/x/a.md") == false
  )

  -- ── on_done: reaches the caller, but only while it is still the preview ───
  local reported = {}
  images.preview(3, "/x/doc.pdf", {
    on_done = function(ok, err)
      reported[#reported + 1] = { ok = ok, err = err }
    end,
  })
  assert(pending)
  pending(false, "pdftoppm exited 1")
  check(
    "integrations.images: on_done reaches the caller",
    #reported == 1 and reported[1].ok == false and reported[1].err == "pdftoppm exited 1"
  )

  reported = {}
  images.preview(3, "/x/doc.pdf", {
    on_done = function(ok)
      reported[#reported + 1] = ok
    end,
  })
  local stale = pending
  images.preview(3, "/x/other.pdf", { on_done = function() end })
  assert(stale)
  stale(false, "too late")
  check("integrations.images: a newer preview silences the older on_done", #reported == 0)

  reported = {}
  images.preview(3, "/x/doc.pdf", {
    on_done = function(ok)
      reported[#reported + 1] = ok
    end,
  })
  stale = pending
  images.clear()
  assert(stale)
  stale(false, "too late")
  check("integrations.images: clear() silences a pending on_done", #reported == 0)

  -- ── on_ready: forwarded, and under the same guard ─────────────────────────
  -- The placeholder removal rides on it, so a stale one firing would empty a
  -- buffer that already belongs to another entry.
  local readied = 0
  images.preview(3, "/x/doc.pdf", {
    on_ready = function()
      readied = readied + 1
    end,
  })
  assert(pending_ready)
  pending_ready()
  check("integrations.images: on_ready reaches the caller", readied == 1)

  readied = 0
  images.preview(3, "/x/doc.pdf", {
    on_ready = function()
      readied = readied + 1
    end,
  })
  local stale_ready = pending_ready
  images.preview(3, "/x/other.pdf", {})
  assert(stale_ready)
  stale_ready()
  check("integrations.images: a newer preview silences the older on_ready", readied == 0)

  -- ── snacks adapter ───────────────────────────────────────────────────────
  local prev_snacks = package.loaded["snacks.picker.preview"]
  local fell_through = 0
  package.loaded["snacks.picker.preview"] = {
    file = function()
      fell_through = fell_through + 1
    end,
  }

  local preview_fn = require("pickers.integrations.images.adapters.snacks").preview_fn()
  local lines_set
  local function ctx_for(file)
    return {
      win = 42,
      item = { file = file },
      preview = {
        reset = function() end,
        set_title = function() end,
        set_lines = function(_, lines)
          lines_set = lines
        end,
      },
    }
  end

  lines_set = nil
  local before = #drawn
  preview_fn(ctx_for("/x/doc.pdf"))
  check(
    "images/snacks: a PDF entry is drawn into the preview window",
    #drawn == before + 1 and drawn[#drawn].file == "/x/doc.pdf" and fell_through == 0
  )
  check(
    "images/snacks: and the window says what the wait is for",
    type(lines_set) == "table" and table.concat(lines_set, " "):match("rendering") ~= nil
  )

  -- …and stops saying it the moment the page exists. Left in place it would
  -- stay on screen BESIDE the picture, which covers only its own box.
  assert(pending_ready)
  pending_ready()
  check(
    "images/snacks: on_ready empties the window again before the draw",
    type(lines_set) == "table" and next(lines_set) == nil
  )

  assert(pending)
  pending(false, "pdftoppm exited 1")
  check("images/snacks: a page that will not rasterize falls through to snacks", fell_through == 1)

  lines_set = nil
  before = #drawn
  preview_fn(ctx_for("/x/shot.png"))
  check(
    "images/snacks: an image entry draws without a placeholder",
    #drawn == before + 1 and lines_set == nil
  )

  package.loaded["snacks.picker.preview"] = prev_snacks

  -- ── telescope adapter ────────────────────────────────────────────────────
  local prev_tele = {
    ["telescope.previewers"] = package.loaded["telescope.previewers"],
    ["telescope.from_entry"] = package.loaded["telescope.from_entry"],
    ["telescope.config"] = package.loaded["telescope.config"],
  }
  local maker_calls = 0
  package.loaded["telescope.previewers"] = {
    new_buffer_previewer = function(o)
      return o
    end,
  }
  package.loaded["telescope.from_entry"] = {
    path = function(entry)
      return entry.path
    end,
  }
  package.loaded["telescope.config"] = {
    values = {
      preview = {},
      buffer_previewer_maker = function()
        maker_calls = maker_calls + 1
      end,
    },
  }

  local previewer = require("pickers.integrations.images.adapters.telescope").previewer()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local state = { state = { bufnr = bufnr, winid = 0 } }

  before = #drawn
  previewer.define_preview(state, { path = "/x/doc.pdf" })
  check(
    "images/telescope: a PDF entry is drawn, telescope's maker untouched",
    #drawn == before + 1 and drawn[#drawn].file == "/x/doc.pdf" and maker_calls == 0
  )
  check(
    "images/telescope: and the emptied buffer says what the wait is for",
    table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), " "):match("rendering") ~= nil
  )

  assert(pending_ready)
  pending_ready()
  check(
    "images/telescope: on_ready empties the buffer again before the draw",
    table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "") == ""
  )

  assert(pending)
  pending(false, "pdftoppm exited 1")
  check(
    "images/telescope: a page that will not rasterize hands over to telescope",
    maker_calls == 1
  )

  before = #drawn
  previewer.define_preview(state, { path = "/x/shot.png" })
  check(
    "images/telescope: an image entry leaves the buffer empty",
    #drawn == before + 1 and table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "") == ""
  )

  for k, v in pairs(prev_tele) do
    package.loaded[k] = v
  end
  package.loaded["images.integrations.picker"] = prev_api
end

-- ── live_grep: each engine gets the option key ITS library reads ────────────
-- The bug this pins: the fzf-lua adapter passed `search_dirs` -- telescope's
-- spelling. fzf-lua never read it, and an unknown option is dropped in
-- silence, so every scoped grep through that engine ran over the CWD instead
-- of over `roots`. Nothing errored and results appeared; only their paths gave
-- it away. Three libraries, three names for the same idea (`search_dirs`,
-- `search_paths`, `dirs`), and no way to notice a wrong one at runtime -- so
-- the mapping is asserted here rather than trusted.
--
-- Needs lib.nvim: the engine modules require `lib.nvim.notify` at load.
do
  local ok = pcall(require, "lib.nvim.notify")
  if not ok then
    print("  skip engine live_grep option tests (lib.nvim not on runtimepath)")
  else
    local prev = {
      ["fzf-lua"] = package.loaded["fzf-lua"],
      ["telescope.builtin"] = package.loaded["telescope.builtin"],
      ["snacks.picker"] = package.loaded["snacks.picker"],
    }
    -- A directory and a single file: narrowing to a handful of files is what
    -- all three options support, and what a caller scoping a grep needs.
    local roots = { "/x/docs", "/x/notes/one.md" }
    local got

    package.loaded["fzf-lua"] = {
      live_grep = function(o)
        got = o
      end,
    }
    got = nil
    require("pickers.engines.fzf").live_grep({ roots = roots, prompt = "P" })
    check(
      "fzf live_grep: roots go to search_paths",
      got ~= nil and vim.deep_equal(got.search_paths, roots),
      got and vim.inspect(got.search_paths)
    )
    -- Deliberately probing a field fzf-lua's own opts type never declares --
    -- the assertion IS that it stays absent (the wrong-key bug this whole
    -- block guards against would set it).
    ---@diagnostic disable-next-line: undefined-field
    check("fzf live_grep: no search_dirs, which fzf-lua would ignore", got.search_dirs == nil)
    check(
      "fzf live_grep: --header names the cheatsheet key, visible on open",
      got.fzf_opts and got.fzf_opts["--header"] == "f1 cheatsheet",
      got.fzf_opts and vim.inspect(got.fzf_opts)
    )

    package.loaded["telescope.builtin"] = {
      live_grep = function(o)
        got = o
      end,
    }
    got = nil
    require("pickers.engines.telescope").live_grep({ roots = roots, prompt = "P" })
    check(
      "telescope live_grep: roots go to search_dirs",
      got ~= nil and vim.deep_equal(got.search_dirs, roots),
      got and vim.inspect(got.search_dirs)
    )
    check(
      "telescope live_grep: results_title names the cheatsheet key, visible on open",
      got.results_title == "<C-/> cheatsheet",
      tostring(got.results_title)
    )

    -- keys.enable = false: both hints disappear entirely (not just "").
    require("pickers.config").apply({ keys = { enable = false } })
    package.loaded["pickers.cheatsheet"] = nil
    got = nil
    require("pickers.engines.fzf").live_grep({ roots = roots, prompt = "P" })
    check(
      "fzf live_grep: no --header when keys.enable=false",
      got.fzf_opts["--header"] == nil,
      vim.inspect(got.fzf_opts)
    )
    got = nil
    require("pickers.engines.telescope").live_grep({ roots = roots, prompt = "P" })
    check(
      "telescope live_grep: no results_title when keys.enable=false",
      got.results_title == nil,
      tostring(got.results_title)
    )
    require("pickers.config").apply({ keys = { enable = true } })
    package.loaded["pickers.cheatsheet"] = nil

    package.loaded["snacks.picker"] = {
      grep = function(o)
        got = o
      end,
    }
    got = nil
    require("pickers.engines.snacks").live_grep({ roots = roots, prompt = "P" })
    check(
      "snacks live_grep: roots go to dirs",
      got ~= nil and vim.deep_equal(got.dirs, roots),
      got and vim.inspect(got.dirs)
    )

    for k, v in pairs(prev) do
      package.loaded[k] = v
    end
  end
end

-- ── pickers.refine — filter stack, predicate, title, prompt ─────────────────
do
  local refine = require("pickers.refine")

  local fields = {
    path = function(it)
      return it.path
    end,
    content = function(it)
      return it.line
    end,
  }
  local items = {
    { path = "src/app.lua", line = "local x = 1" },
    { path = "src/app_test.lua", line = "assert(x)" },
    { path = "docs/readme.md", line = "install" },
  }

  -- predicate: substring, case-insensitive, AND across clauses
  do
    local pred = refine.predicate(
      { { field = "path", mode = "substr", term = "SRC", negate = false } },
      fields
    )
    check("refine.predicate: substr is case-insensitive", pred(items[1]) and not pred(items[3]))

    local two = refine.predicate({
      { field = "path", mode = "substr", term = "src", negate = false },
      { field = "content", mode = "substr", term = "assert", negate = false },
    }, fields)
    check("refine.predicate: clauses AND", two(items[2]) and not two(items[1]))
  end

  -- negate, incl. nil field value
  do
    local pred = refine.predicate(
      { { field = "path", mode = "substr", term = "test", negate = true } },
      fields
    )
    check("refine.predicate: negate excludes matches", not pred(items[2]) and pred(items[1]))

    local nofield = refine.predicate(
      { { field = "author", mode = "substr", term = "x", negate = false } },
      fields
    )
    check("refine.predicate: unknown field passes", nofield(items[1]))

    local neg_nil = refine.predicate(
      { { field = "author", mode = "substr", term = "x", negate = true } },
      {}
    )
    check("refine.predicate: negated missing field passes", neg_nil(items[1]))
  end

  -- regex mode
  do
    local pred = refine.predicate(
      { { field = "path", mode = "regex", term = "%.md$", negate = false } },
      fields
    )
    check("refine.predicate: regex matches", pred(items[3]) and not pred(items[1]))
  end

  -- apply preserves order, does not mutate
  do
    local filtered = refine.apply(
      items,
      { { field = "path", mode = "substr", term = "src", negate = false } },
      fields
    )
    check(
      "refine.apply: filters and keeps order",
      #filtered == 2 and filtered[1].path == "src/app.lua"
    )
    check("refine.apply: empty stack returns input", refine.apply(items, {}, fields) == items)
  end

  -- summary / title
  do
    local stack = {
      { field = "path", mode = "substr", term = "src", negate = false },
      { field = "content", mode = "regex", term = "test", negate = true },
    }
    check("refine.summary", refine.summary(stack) == "path~src · ¬content=~test")
    check(
      "refine.title: with counts",
      refine.title("Matches", stack, 2, 10) == "Matches — path~src · ¬content=~test (2/10)"
    )
    check("refine.title: empty stack", refine.title("Matches", {}, nil, 10) == "Matches (10)")
  end

  -- stateful handle + prompt flow via a stubbed vim.ui
  do
    local h = refine.new({ fields = fields })
    check("refine handle: starts inactive", not h:is_active())

    local prev = vim.ui
    -- Menu order is sorted field names: content/contains, content/excludes,
    -- path/contains, path/excludes. Pick #3 (path contains) + input "src".
    vim.ui = {
      select = function(choices, _o, cb)
        cb(choices[3])
      end,
      input = function(_o, cb)
        cb("src")
      end,
    }
    local changed = 0
    h:prompt(function()
      changed = changed + 1
    end)
    check(
      "refine handle: prompt added a clause",
      h:is_active() and #h.stack == 1 and h.stack[1].field == "path"
    )
    check("refine handle: on_change fired once", changed == 1)
    check("refine handle: apply uses the stack", #h:apply(items) == 2)

    -- regex term via /.../  (choice #4 = path excludes)
    vim.ui = {
      select = function(choices, _o, cb)
        cb(choices[4])
      end,
      input = function(_o, cb)
        cb("/%.md$/")
      end,
    }
    h:prompt(function() end)
    check(
      "refine handle: /.../ becomes regex",
      h.stack[2].mode == "regex"
        and h.stack[2].term == "%.md$"
        and h.stack[2].negate
        and h.stack[2].field == "path"
    )

    -- cancelled prompt: no clause, no on_change — but on_done still fires
    vim.ui = {
      select = function(_c, _o, cb)
        cb(nil)
      end,
      input = function(_o, cb)
        cb(nil)
      end,
    }
    local n = #h.stack
    local changed_fired, done_fired = false, false
    h:prompt(function()
      changed_fired = true
    end, function()
      done_fired = true
    end)
    check(
      "refine handle: cancelled select does not fire on_change",
      #h.stack == n and not changed_fired
    )
    check("refine handle: on_done fires even on cancel", done_fired)

    -- clear
    vim.ui = {
      select = function(choices, _o, cb)
        for _, c in ipairs(choices) do
          if c.kind == "clear" then return cb(c) end
        end
      end,
    }
    h:prompt(function() end)
    check("refine handle: clear empties the stack", #h.stack == 0)

    vim.ui = prev
  end
end

-- ── pickers.error — typed Result wrapper ─────────────────────────────────────
do
  local perr = require("pickers.error")

  local err = perr.new("UnknownScopeError", "no such scope 'x'")
  check("error.new: kind", err.kind == "UnknownScopeError")
  check("error.new: message", err.message == "no such scope 'x'")
  check(
    "error.tostring: formats kind+message",
    perr.tostring(err) == "[UnknownScopeError] no such scope 'x'"
  )
  check("error.tostring: missing kind falls back", perr.tostring({ message = "m" }) == "[Error] m")
  check("error.tostring: missing message falls back", perr.tostring({ kind = "K" }) == "[K] ")

  local ok_res = perr.safe_call("InternalError", function(a, b)
    return a + b
  end, 2, 3)
  check(
    "error.safe_call: ok result",
    ok_res.ok == true and ok_res.result == 5 and ok_res.err == nil
  )

  local err_res = perr.safe_call("InternalError", function()
    error("boom")
  end)
  check("error.safe_call: failure ok=false", err_res.ok == false and err_res.result == nil)
  check("error.safe_call: failure tags kind", err_res.err and err_res.err.kind == "InternalError")
  check(
    "error.safe_call: failure message includes original",
    err_res.err and err_res.err.message:find("boom", 1, true) ~= nil
  )
end

-- ── pickers.config.DEFAULTS — depth_aliases resolvers ────────────────────────
-- cwd/home are one-liners; root and git are the two with actual walk-up
-- logic (dir_nav_picker and pickers.actions.dir only ever call these through
-- cfg.depth_aliases, so this is the only place they get exercised directly).
do
  local config = require("pickers.config")
  local aliases = config.get().depth_aliases

  check("depth_aliases: cwd resolver returns a string", type(aliases.cwd()) == "string")
  check("depth_aliases: home resolver returns a string", type(aliases.home()) == "string")
  check(
    "depth_aliases: root resolver returns an existing directory",
    vim.fn.isdirectory(aliases.root()) == 1
  )

  -- Both git-resolver branches derive their answer from `vim.uv.cwd()`, and
  -- `getcwd(3)` hands back the path with every symlink already resolved. On
  -- macOS the per-user temp dir sits behind the /var → /private/var symlink,
  -- so `tempname()` says "/var/folders/…" while the resolver — correctly and
  -- consistently — says "/private/var/folders/…". Two spellings of one
  -- directory: the resolver is stable, the comparison was the naive half.
  -- Resolve both sides before comparing; the assertion still tells `repo`
  -- apart from `repo/sub` and from `repo/.git`, which is what it is for.
  ---@param path string
  ---@return string
  local function real(path)
    return vim.fs.normalize(vim.uv.fs_realpath(path) or path)
  end

  local orig_cwd = vim.uv.cwd()
  local base = vim.fn.tempname()
  vim.fn.mkdir(base .. "/repo/.git", "p")
  vim.fn.mkdir(base .. "/repo/sub", "p")
  vim.uv.chdir(base .. "/repo/sub")
  local found = aliases.git()
  check(
    "depth_aliases: git resolver finds the upward .git",
    real(found) == real(base .. "/repo"),
    tostring(found)
  )

  local no_git = vim.fn.tempname()
  vim.fn.mkdir(no_git, "p")
  vim.uv.chdir(no_git)
  local fallback = aliases.git()
  check(
    "depth_aliases: git resolver falls back to cwd without a repo",
    real(fallback) == real(no_git),
    tostring(fallback)
  )

  vim.uv.chdir(orig_cwd)
  vim.fn.delete(base, "rf")
  vim.fn.delete(no_git, "rf")
end

-- ── pickers.actions.grep — per-source find override merges over cfg.find ────
-- Same merge contract as pickers.actions.files (see that suite), mirrored
-- here since grep has its own M.run rather than sharing files' code path.
do
  local config = require("pickers.config")
  local grep = require("pickers.actions.grep")

  config.apply({ find = { hidden = true, follow = true, no_ignore = false } })

  local captured
  local fake_engine = {
    live_grep = function(opts)
      captured = opts
    end,
  }

  grep.run({ roots = { "/tmp" }, prompt = "cwd> " }, fake_engine)
  check(
    "actions.grep: no override -> global find",
    vim.deep_equal(captured.find, config.get().find)
  )
  check("actions.grep: roots forwarded", captured.roots[1] == "/tmp")
  check("actions.grep: prompt forwarded", captured.prompt == "cwd> ")
  check(
    "actions.grep: additional_args defaults empty",
    vim.deep_equal(captured.additional_args, {})
  )

  grep.run({
    roots = { "/tmp" },
    prompt = "notes> ",
    find = { hidden = false },
    additional_args = { "-tlua" },
  }, fake_engine, { "--fixed-strings" })
  check("actions.grep: source find override applied", captured.find.hidden == false)
  check(
    "actions.grep: source additional_args + extra_args merged",
    has(captured.additional_args, "-tlua") and has(captured.additional_args, "--fixed-strings")
  )
  check("actions.grep: global cfg.find untouched by override", config.get().find.hidden == true)

  config.apply({ find = { hidden = true, no_ignore = false, follow = true } })
end

-- ── pickers.actions.smart — find override merge + missing-adapter guard ─────
do
  local config = require("pickers.config")
  local smart_action = require("pickers.actions.smart")

  config.apply({ find = { hidden = true, follow = true, no_ignore = false } })

  local captured
  local fake_engine = {
    smart = function(opts)
      captured = opts
    end,
  }
  smart_action.run(
    { roots = { "/tmp" }, prompt = "cwd> ", additional_args = { "-tlua" } },
    fake_engine
  )
  check(
    "actions.smart: no override -> global find",
    vim.deep_equal(captured.find, config.get().find)
  )
  check("actions.smart: roots forwarded", captured.roots[1] == "/tmp")
  check("actions.smart: additional_args passthrough", has(captured.additional_args, "-tlua"))

  smart_action.run({ roots = { "/tmp" }, prompt = "n> ", find = { hidden = false } }, fake_engine)
  check("actions.smart: source find override applied", captured.find.hidden == false)
  check("actions.smart: global cfg.find untouched", config.get().find.hidden == true)

  -- Engine with no smart() adapter: notify.error and bail out, never throws.
  local ok = pcall(smart_action.run, { roots = { "/tmp" }, prompt = "n> " }, {})
  check("actions.smart: missing adapter does not throw", ok)

  config.apply({ find = { hidden = true, no_ignore = false, follow = true } })
end

-- ── pickers.actions.dir — nav-arg resolution + dispatch ──────────────────────
-- resolve() itself is local; exercised here only through M.run's observable
-- effect (which engine call it produces, or that it produces none).
do
  local config = require("pickers.config")
  local dir_action = require("pickers.actions.dir")
  local last = require("pickers.last")

  local names = dir_action.alias_names()
  check(
    "actions.dir.alias_names: includes builtins",
    has(names, "cwd") and has(names, "home") and has(names, "root") and has(names, "git")
  )
  check("actions.dir.alias_names: sorted", names[1] <= names[#names])

  local calls
  local fake_engine = {
    pick_files = function(opts)
      calls = opts
    end,
  }
  local expect_cwd = vim.fs.normalize(vim.uv.cwd() or vim.fn.getcwd())

  -- Numeric depth "0" -> cwd itself, action given directly.
  calls = nil
  dir_action.run("0", "files", fake_engine)
  check("actions.dir: numeric 0 resolves to cwd", calls ~= nil and calls.roots[1] == expect_cwd)
  check("actions.dir: dispatch recorded in pickers.last", last.get().action == "files")

  -- "path=..." explicit path, quoted, keyword case-insensitive.
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  calls = nil
  dir_action.run('PATH="' .. tmp .. '"', "files", fake_engine)
  check(
    "actions.dir: path= (quoted, uppercase keyword) resolves",
    calls ~= nil and calls.roots[1] == vim.fs.normalize(tmp)
  )

  -- Named alias, case-insensitive.
  calls = nil
  dir_action.run("CWD", "files", fake_engine)
  check(
    "actions.dir: alias lookup is case-insensitive",
    calls ~= nil and calls.roots[1] == expect_cwd
  )

  -- Not an alias, not numeric, and not a real directory as a raw path: the
  -- after_path isdirectory guard bails before ever reaching the engine.
  calls = nil
  dir_action.run("this-is-not-a-real-directory-xyz", "files", fake_engine)
  check("actions.dir: unresolvable path does not dispatch", calls == nil)

  -- A depth_aliases resolver that errors: caught, notified, nil path -> no dispatch.
  config.apply({ depth_aliases = {
    boom = function()
      error("nope")
    end,
  } })
  calls = nil
  local ok = pcall(dir_action.run, "boom", "files", fake_engine)
  check("actions.dir: failing alias resolver does not throw", ok)
  check("actions.dir: failing alias resolver does not dispatch", calls == nil)

  -- nil nav_arg + nil action: interactive dir-nav picker, then action picker.
  package.loaded["pickers.ui.dir_nav_picker"] = {
    open = function(_cfg, cb)
      cb("0")
    end,
  }
  package.loaded["pickers.ui.action_picker"] = {
    open = function(cb)
      cb("files")
    end,
  }
  calls = nil
  dir_action.run(nil, nil, fake_engine)
  check(
    "actions.dir: interactive nav+action reaches dispatch",
    calls ~= nil and calls.roots[1] == expect_cwd
  )
  package.loaded["pickers.ui.dir_nav_picker"] = nil
  package.loaded["pickers.ui.action_picker"] = nil

  vim.fn.delete(tmp, "rf")
end

-- ── pickers.engines.when_loaded — run-now / schedule / lazy-load branches ───
do
  local when_loaded = require("pickers.engines.when_loaded")

  local prev_telescope = package.loaded["telescope"]
  local prev_lazy = package.loaded["lazy.core.config"]

  -- Already loaded: fn() runs synchronously, no autocmd involved.
  package.loaded["telescope"] = { some = "table" }
  local ran = false
  when_loaded.run("telescope", function()
    ran = true
  end)
  check("when_loaded: already-loaded module runs fn immediately", ran)

  -- Not loaded, no lazy.nvim: falls back to vim.schedule.
  package.loaded["telescope"] = nil
  package.loaded["lazy.core.config"] = nil
  local scheduled = false
  when_loaded.run("telescope", function()
    scheduled = true
  end)
  check("when_loaded: not scheduled synchronously without lazy.nvim", not scheduled)
  vim.wait(50, function()
    return scheduled
  end)
  check("when_loaded: vim.schedule fallback eventually runs fn", scheduled)

  -- Not loaded, lazy.nvim present: waits for a matching `User LazyLoad`,
  -- ignores a non-matching one, and fires exactly once.
  package.loaded["lazy.core.config"] = { fake = true }
  local fired = 0
  when_loaded.run("telescope", function()
    fired = fired + 1
  end)
  check("when_loaded: lazy.nvim path does not run fn synchronously", fired == 0)

  vim.api.nvim_exec_autocmds("User", { pattern = "LazyLoad", data = "some-other-plugin.nvim" })
  check("when_loaded: non-matching LazyLoad event is ignored", fired == 0)

  vim.api.nvim_exec_autocmds("User", { pattern = "LazyLoad", data = "telescope.nvim" })
  check("when_loaded: matching LazyLoad event runs fn", fired == 1)

  vim.api.nvim_exec_autocmds("User", { pattern = "LazyLoad", data = "telescope.nvim" })
  check("when_loaded: one-shot -- a second matching event does not re-run fn", fired == 1)

  package.loaded["telescope"] = prev_telescope
  package.loaded["lazy.core.config"] = prev_lazy
end

-- ── entry_actions.extract — telescope/snacks path-from-item fallback chains ─
-- Mirrors the existing entry_actions.extract.fzf suite for the other two
-- engines' extractors.
do
  local extract_ts = require("pickers.entry_actions.extract.telescope")

  check("extract.telescope: nil entry -> nil", extract_ts(nil) == nil)
  check(
    "extract.telescope: prefers entry.path",
    extract_ts({ path = "/a", filename = "/b" }) == "/a"
  )
  check("extract.telescope: falls back to filename", extract_ts({ filename = "/b" }) == "/b")
  check("extract.telescope: falls back to string value", extract_ts({ value = "/c" }) == "/c")
  check("extract.telescope: non-string value ignored", extract_ts({ value = { 1 } }) == nil)
  check("extract.telescope: empty-string path -> nil", extract_ts({ path = "" }) == nil)

  local extract_snacks = require("pickers.entry_actions.extract.snacks")

  check("extract.snacks: nil item -> nil", extract_snacks(nil) == nil)
  check("extract.snacks: item.path", extract_snacks({ path = "/a" }) == "/a")
  check("extract.snacks: item.filename", extract_snacks({ filename = "/b" }) == "/b")
  check("extract.snacks: nested item.item.path", extract_snacks({ item = { path = "/c" } }) == "/c")
  check(
    "extract.snacks: nested item.item.filename",
    extract_snacks({ item = { filename = "/d" } }) == "/d"
  )
  check("extract.snacks: text fallback", extract_snacks({ text = "/e" }) == "/e")
  check("extract.snacks: no matching field -> nil", extract_snacks({ other = 1 }) == nil)
  -- item.file set but snacks.picker.util is not on this runtimepath: the
  -- Snacks.picker.util.path branch's pcall fails, falls through to the same
  -- manual chain, which also reads item.file.
  check(
    "extract.snacks: item.file (util unavailable) still resolves",
    extract_snacks({ file = "/f" }) == "/f"
  )
end

-- ── entry_actions.open_background — empty-path guard, error path, show flag ─
do
  local config = require("pickers.config")

  local prev_core = package.loaded["lib.nvim.buffer.open_background"]
  local behavior
  package.loaded["lib.nvim.buffer.open_background"] = function(path)
    return behavior(path)
  end
  package.loaded["pickers.entry_actions.open_background"] = nil
  local open_bg = require("pickers.entry_actions.open_background")

  check("open_background: empty path -> false, no core call", open_bg.run("") == false)
  check("open_background: nil path -> false", open_bg.run(nil) == false)

  behavior = function()
    return false, "boom"
  end
  check("open_background: core failure -> false", open_bg.run("/some/file") == false)

  behavior = function()
    return true, 42
  end
  check("open_background: core success -> true", open_bg.run("/some/file") == true)

  -- keys.open_background_show default false: opts.win is never touched.
  local win = vim.api.nvim_get_current_win()
  local buf_before = vim.api.nvim_win_get_buf(win)
  open_bg.run("/some/file", { win = win })
  check(
    "open_background: show disabled by default -> window untouched",
    vim.api.nvim_win_get_buf(win) == buf_before
  )

  -- keys.open_background_show = true: the given window is pointed at the
  -- buffer, without moving focus there.
  local real_buf = vim.api.nvim_create_buf(false, true)
  behavior = function()
    return true, real_buf
  end
  config.apply({ keys = { open_background_show = true } })
  local cur_win_before = vim.api.nvim_get_current_win()
  open_bg.run("/some/file", { win = win })
  check(
    "open_background: show enabled -> window buffer switched",
    vim.api.nvim_win_get_buf(win) == real_buf
  )
  check("open_background: focus stays put", vim.api.nvim_get_current_win() == cur_win_before)

  vim.api.nvim_win_set_buf(win, buf_before)
  vim.api.nvim_buf_delete(real_buf, { force = true })
  config.apply({ keys = { open_background_show = false } })
  package.loaded["lib.nvim.buffer.open_background"] = prev_core
  package.loaded["pickers.entry_actions.open_background"] = nil
end

-- ── pickers.sources.folder — engine.pick_dir() wiring + validation ──────────
do
  local folder = require("pickers.sources.folder")

  local got
  local ok = pcall(folder.get, {}, function(source)
    got = { called = true, source = source }
  end, {})
  check("sources.folder: missing pick_dir does not throw", ok)
  check("sources.folder: missing pick_dir calls back with nil", got and got.source == nil)

  got = nil
  folder.get({}, function(source)
    got = { called = true, source = source }
  end, {
    pick_dir = function(opts)
      opts.on_select(nil)
    end,
  })
  check("sources.folder: cancelled pick_dir -> callback(nil)", got and got.source == nil)

  got = nil
  folder.get({}, function(source)
    got = { called = true, source = source }
  end, {
    pick_dir = function(opts)
      opts.on_select("")
    end,
  })
  check("sources.folder: empty-string selection -> callback(nil)", got and got.source == nil)

  got = nil
  folder.get({}, function(source)
    got = { called = true, source = source }
  end, {
    pick_dir = function(opts)
      opts.on_select("/definitely/not/a/real/directory/xyz")
    end,
  })
  check("sources.folder: nonexistent dir -> callback(nil)", got and got.source == nil)

  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp .. "/myproject", "p")
  got = nil
  folder.get({}, function(source)
    got = { called = true, source = source }
  end, {
    pick_dir = function(opts)
      opts.on_select(tmp .. "/myproject")
    end,
  })
  check(
    "sources.folder: valid dir -> roots set",
    got and got.source and got.source.roots[1] == vim.fs.normalize(tmp .. "/myproject")
  )
  check(
    "sources.folder: prompt uses basename",
    got and got.source and got.source.prompt == "myproject> "
  )

  vim.fn.delete(tmp, "rf")
end

-- ── pickers.sources.plugins_book — list_names/resolve/complete over a collection ─
do
  local config = require("pickers.config")
  local plugins_book = require("pickers.sources.plugins_book")

  local base = vim.fn.tempname()
  vim.fn.mkdir(base .. "/cascade.nvim", "p")
  vim.fn.mkdir(base .. "/markdown.nvim", "p")
  vim.fn.mkdir(base .. "/TEMPLATES", "p")

  config.apply({ collections = {} })
  check(
    "plugins_book.list_names: no collection -> empty",
    vim.tbl_isempty(plugins_book.list_names(config.get()))
  )
  check(
    "plugins_book.resolve: no collection -> nil",
    plugins_book.resolve(config.get(), "cascade.nvim") == nil
  )

  config.apply({
    collections = { { name = "plugins_book", dir = base, prefix = "", exclude = { "TEMPLATES" } } },
  })
  local cfg = config.get()

  local names = plugins_book.list_names(cfg)
  check("plugins_book.list_names: finds cascade.nvim", has(names, "cascade.nvim"))
  check("plugins_book.list_names: finds markdown.nvim", has(names, "markdown.nvim"))
  check("plugins_book.list_names: excludes TEMPLATES", not has(names, "TEMPLATES"))
  check("plugins_book.list_names: sorted", names[1] <= names[#names])

  check("plugins_book.resolve: known plugin", plugins_book.resolve(cfg, "cascade.nvim") ~= nil)
  check("plugins_book.resolve: unknown plugin -> nil", plugins_book.resolve(cfg, "nope") == nil)
  check("plugins_book.resolve: excluded name -> nil", plugins_book.resolve(cfg, "TEMPLATES") == nil)
  check("plugins_book.resolve: empty name -> nil", plugins_book.resolve(cfg, "") == nil)

  local completed = plugins_book.complete("casc")
  check("plugins_book.complete: prefix match", has(completed, "cascade.nvim"))
  check("plugins_book.complete: prefix excludes non-match", not has(completed, "markdown.nvim"))
  check("plugins_book.complete: empty arglead -> all names", #plugins_book.complete("") == #names)

  vim.fn.delete(base, "rf")
  config.apply({ collections = {} })
end

-- ── pickers.sources.wkdbooks — collection lookup, repos_dir fallback, error ─
do
  local config = require("pickers.config")

  local prev_collection = package.loaded["pickers.sources.collection"]
  local captured
  package.loaded["pickers.sources.collection"] = {
    get = function(coll, _cfg, callback, _engine)
      captured = coll
      callback({ roots = { coll.dir }, prompt = coll.name .. "> " })
    end,
  }
  package.loaded["pickers.sources.wkdbooks"] = nil
  local wkdbooks = require("pickers.sources.wkdbooks")

  -- "wkdbooks" collection present: used as-is, no fallback synthesis.
  config.apply({
    collections = { { name = "wkdbooks", dir = "/x/wkdbooks", prefix = "wkdbook-" } },
    repos_dir = "/should/not/be/used",
  })
  wkdbooks.get(config.get(), function() end, {})
  check("wkdbooks: uses the configured collection dir", captured.dir == "/x/wkdbooks")
  check("wkdbooks: uses the configured collection prefix", captured.prefix == "wkdbook-")

  -- No "wkdbooks" collection, but repos_dir set: synthesizes one.
  config.apply({ collections = {} })
  config.apply({ repos_dir = vim.fn.getcwd() })
  captured = nil
  wkdbooks.get(config.get(), function() end, {})
  check(
    "wkdbooks: falls back to repos_dir/WKDBooks",
    captured and captured.dir == vim.fn.getcwd() .. "/WKDBooks"
  )
  check("wkdbooks: fallback prefix is wkdbook-", captured and captured.prefix == "wkdbook-")

  -- Neither collection nor repos_dir: error, callback(nil), no throw.
  config.apply({ collections = {} })
  local cfg = config.get()
  cfg.repos_dir = nil
  captured = nil
  local got = "unset"
  local ok = pcall(wkdbooks.get, cfg, function(source)
    got = source
  end, {})
  check("wkdbooks: no collection + no repos_dir does not throw", ok)
  check("wkdbooks: no collection + no repos_dir -> callback(nil)", got == nil)
  check("wkdbooks: no collection + no repos_dir -> collection.get not called", captured == nil)

  package.loaded["pickers.sources.collection"] = prev_collection
  package.loaded["pickers.sources.wkdbooks"] = nil
  config.apply({ collections = {}, repos_dir = vim.fn.getcwd() })
end

-- ── pickers.sources.drives — cross-platform drives/mount-points source ──────
-- Round 1 skipped this file: "shells real Get-PSDrive/df via vim.system, no
-- stable mock surface without replacing the whole process layer". That no
-- longer holds -- `vim.system` is a plain global, not a `require()`-time
-- upvalue, so it can be monkey-patched directly around the call (the same
-- technique open.nvim's keywords_spec already uses for its own subprocess
-- calls), with no real PowerShell/df ever spawned.
do
  package.loaded["pickers.sources.drives"] = nil
  local drives = require("pickers.sources.drives")

  local is_win = drives.is_windows()
  check(
    "drives.is_windows: matches vim.fn.has",
    is_win == (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
  )

  -- Branch on the REAL command the module builds (not on an assumed host),
  -- so this suite is correct whether it runs on the Windows dev box or the
  -- Ubuntu CI runner. The Windows stdout reuses the actual cwd's own drive
  -- letter and the POSIX one reuses "/" -- both are guaranteed to exist as
  -- real directories, since `isdirectory()` still runs for real against them.
  local win_drive = (vim.uv.cwd() or vim.fn.getcwd()):match("^(%a:)") or "C:"

  local orig_system = vim.system
  local seen_cmd
  local next_stdout = ""
  vim.system = function(cmd, _opts, cb)
    seen_cmd = cmd
    vim.schedule(function()
      cb({ stdout = next_stdout })
    end)
  end

  -- Deliberately messy: trailing whitespace and a duplicate entry, so the
  -- trim + dedup steps in windows_roots/posix_roots are actually exercised,
  -- not just given already-clean input.
  if is_win then
    next_stdout = win_drive .. "\\  \r\n" .. win_drive .. "\\\r\n"
  else
    next_stdout = "Mounted on\n/   \n/\n"
  end

  local got
  drives.roots(function(r)
    got = r
  end)
  vim.wait(2000, function()
    return got ~= nil
  end)

  check("drives.roots: shells out to the platform's own tool", seen_cmd ~= nil)
  check(
    "drives.roots: picks powershell on Windows, df elsewhere",
    (is_win and seen_cmd[1] == "powershell") or (not is_win and seen_cmd[1] == "df")
  )
  check("drives.roots: parses at least one root", got ~= nil and #got >= 1, vim.inspect(got))
  check(
    "drives.roots: a duplicate line collapses to one entry",
    got ~= nil and #got == 1,
    "#=" .. tostring(got and #got)
  )

  -- Session cache: "drives don't change during a session" (module comment)
  -- -- a second call must be served from the cache, not shell out again.
  seen_cmd = nil
  local got2
  drives.roots(function(r)
    got2 = r
  end)
  check("drives.roots: second call is served synchronously (cached)", got2 ~= nil)
  check("drives.roots: a cache hit does not shell out again", seen_cmd == nil)
  check("drives.roots: cached result is the same table", got2 == got)

  -- M.get(): the cached roots become a Pickers.Source with the expected
  -- prompt and noise-exclusion globs.
  local source
  drives.get({}, function(s)
    source = s
  end)
  check("drives.get: wraps the cached roots", source ~= nil and #source.roots == #got)
  check("drives.get: sets the All Drives prompt", source ~= nil and source.prompt == "All Drives> ")
  check(
    "drives.get: excludes .git via additional_args",
    source ~= nil and has(source.additional_args, "!.git/")
  )

  vim.system = orig_system
  package.loaded["pickers.sources.drives"] = nil
end

-- ── pickers.ui.action_picker — ui.kit.select, vim.ui.select fallback ────────
-- Mirrors the ui.dir_nav_picker / entry_actions.create_file kit.input suites'
-- package.loaded["ui.kit"] stubbing convention.
do
  local captured
  package.loaded["ui.kit"] = {
    select = function(opts)
      captured = opts
      opts.on_select("grep")
    end,
  }
  package.loaded["pickers.ui.action_picker"] = nil
  local action_picker = require("pickers.ui.action_picker")

  local chosen
  action_picker.open(function(a)
    chosen = a
  end)
  check("action_picker: routes through ui.kit.select", captured ~= nil)
  check(
    "action_picker: offers files/grep/smart",
    has(captured.items, "files") and has(captured.items, "grep") and has(captured.items, "smart")
  )
  check("action_picker: forwards the chosen action", chosen == "grep")

  package.loaded["ui.kit"] = nil
  package.loaded["pickers.ui.action_picker"] = nil
  action_picker = require("pickers.ui.action_picker")

  local prev_select = vim.ui.select
  local select_items
  vim.ui.select = function(items, _opts, cb)
    select_items = items
    cb("smart")
  end
  chosen = nil
  action_picker.open(function(a)
    chosen = a
  end)
  check("action_picker: falls back to vim.ui.select without ui.kit", select_items ~= nil)
  check("action_picker: fallback forwards the chosen action", chosen == "smart")

  vim.ui.select = prev_select
  package.loaded["pickers.ui.action_picker"] = nil
end

-- ── pickers.smart — defaults()/config() merge, query() orchestration ────────
-- search.collect/score.rank/frecency.lookup are each already covered on
-- their own; this is the glue that decides whether frecency runs at all and
-- forwards the right shape to score.rank.
do
  local config = require("pickers.config")
  local smart = require("pickers.smart")

  local d = smart.defaults()
  check("smart.defaults: matches DEFAULTS.smart", d.limit == 2000 and d.timeout == 3000)
  check(
    "smart.defaults: is a copy, not the live DEFAULTS table",
    d ~= require("pickers.config.DEFAULTS").smart
  )

  config.apply({ smart = { limit = 500 } })
  local c = smart.config()
  check("smart.config: merges user config over defaults", c.limit == 500)
  check("smart.config: untouched sibling stays default", c.timeout == 3000)
  config.apply({ smart = { limit = 2000 } })

  local prev_search = package.loaded["pickers.smart.search"]
  local prev_score = package.loaded["pickers.smart.score"]
  local prev_frecency = package.loaded["pickers.smart.frecency"]

  local collect_args, rank_args, lookup_args
  package.loaded["pickers.smart.search"] = {
    collect = function(opts)
      collect_args = opts
      return { { abspath = "/a" } }, { { abspath = "/b" } }
    end,
  }
  package.loaded["pickers.smart.score"] = {
    rank = function(...)
      rank_args = { ... }
      return { "ranked" }
    end,
  }
  package.loaded["pickers.smart.frecency"] = {
    lookup = function(_cfg, paths)
      lookup_args = paths
      return { ["/a"] = 1 }
    end,
  }

  config.apply({ smart = { frecency = { enabled = false } } })
  local result = smart.query("needle", { roots = { "/r" }, find = {} })
  check("smart.query: forwards query to search.collect", collect_args.query == "needle")
  check("smart.query: forwards roots to search.collect", collect_args.roots[1] == "/r")
  check("smart.query: frecency disabled -> no lookup call", lookup_args == nil)
  check("smart.query: rank's frecency arg is nil when disabled", rank_args[6] == nil)
  check("smart.query: returns score.rank's result", vim.deep_equal(result, { "ranked" }))

  config.apply({ smart = { frecency = { enabled = true, weight = 1.0 } } })
  lookup_args = nil
  smart.query("needle2", { roots = { "/r" }, find = {} })
  check(
    "smart.query: frecency enabled -> lookup called with collected abspaths",
    lookup_args ~= nil and has(lookup_args, "/a") and has(lookup_args, "/b")
  )
  check("smart.query: rank receives the frecency table", rank_args[6] and rank_args[6]["/a"] == 1)

  config.apply({ smart = { frecency = { enabled = false, weight = 1.0 } } })
  package.loaded["pickers.smart.search"] = prev_search
  package.loaded["pickers.smart.score"] = prev_score
  package.loaded["pickers.smart.frecency"] = prev_frecency
end

-- ── pickers.bindings.collections — compat commands + optional keymaps ───────
do
  local collections = require("pickers.bindings.collections")

  local prev_command = package.loaded["pickers.command"]
  local captured
  package.loaded["pickers.command"] = {
    handle = function(opts)
      captured = opts
    end,
  }

  collections.register({
    name = "zzqux",
    dir = "/tmp/zzqux",
    keys = { files = "<leader>ZZqf", grep = "<leader>ZZqg", smart = "<leader>ZZqs" },
  })

  check("bindings.collections: :ZzquxFiles registered", vim.fn.exists(":ZzquxFiles") == 2)
  check("bindings.collections: :ZzquxGrep registered", vim.fn.exists(":ZzquxGrep") == 2)
  check("bindings.collections: :ZzquxSmart registered", vim.fn.exists(":ZzquxSmart") == 2)

  captured = nil
  vim.cmd("ZzquxFiles")
  check(
    "bindings.collections: :ZzquxFiles routes to command.handle('zzqux','files')",
    captured and vim.deep_equal(captured.fargs, { "zzqux", "files" })
  )

  captured = nil
  vim.cmd("ZzquxGrep")
  check(
    "bindings.collections: :ZzquxGrep routes to command.handle('zzqux','grep')",
    captured and vim.deep_equal(captured.fargs, { "zzqux", "grep" })
  )

  local kf = vim.fn.maparg("<leader>ZZqf", "n", false, true)
  check("bindings.collections: files keymap registered", not vim.tbl_isempty(kf))
  captured = nil
  if type(kf.callback) == "function" then kf.callback() end
  check(
    "bindings.collections: files keymap routes to command.handle",
    captured and vim.deep_equal(captured.fargs, { "zzqux", "files" })
  )

  -- Re-registering the same collection must not throw (vim.fn.exists guard
  -- skips re-creating the compat commands; force=true would allow it anyway).
  local ok = pcall(collections.register, { name = "zzqux", dir = "/tmp/zzqux" })
  check("bindings.collections: re-register does not throw", ok)

  package.loaded["pickers.command"] = prev_command
end

-- ── pickers.bindings.usrcmds — compat commands: direct dispatch + fallback ──
do
  local config = require("pickers.config")
  local usrcmds = require("pickers.bindings.usrcmds")
  usrcmds.register()

  for _, name in ipairs({
    "DirPicker",
    "FindConfig",
    "GrepConfig",
    "FindInFolder",
    "LiveGrep",
    "AllDrives",
    "AllDrivesGrep",
    "FindOnSystem",
    "RepoFiles",
    "RepoGrep",
    "WkdBookFiles",
    "WkdBookGrep",
    "PluginsBookFiles",
    "PluginsBookGrep",
    "PickersRepeat",
    "PickersScopes",
    "PickersResume",
  }) do
    check("usrcmds: :" .. name .. " registered", vim.fn.exists(":" .. name) == 2)
  end

  local prev_command = package.loaded["pickers.command"]
  local captured
  package.loaded["pickers.command"] = {
    handle = function(opts)
      captured = opts
    end,
  }

  captured = nil
  vim.cmd("FindConfig")
  check(
    "usrcmds: :FindConfig -> handle({config, files})",
    captured and vim.deep_equal(captured.fargs, { "config", "files" })
  )

  captured = nil
  vim.cmd("GrepConfig")
  check(
    "usrcmds: :GrepConfig -> handle({config, grep})",
    captured and vim.deep_equal(captured.fargs, { "config", "grep" })
  )

  captured = nil
  vim.cmd("LiveGrep")
  check(
    "usrcmds: :LiveGrep -> handle({cwd, grep})",
    captured and vim.deep_equal(captured.fargs, { "cwd", "grep" })
  )

  captured = nil
  vim.cmd("DirPicker 2 files")
  check(
    "usrcmds: :DirPicker forwards fargs with a dir prefix",
    captured and vim.deep_equal(captured.fargs, { "dir", "2", "files" })
  )

  captured = nil
  vim.cmd("RepoFiles")
  check(
    "usrcmds: :RepoFiles (no arg) -> handle({repos, files})",
    captured and vim.deep_equal(captured.fargs, { "repos", "files" })
  )

  captured = nil
  vim.cmd("PluginsBookFiles")
  check(
    "usrcmds: :PluginsBookFiles (no arg) -> handle({plugins_book, files})",
    captured and vim.deep_equal(captured.fargs, { "plugins_book", "files" })
  )

  package.loaded["pickers.command"] = prev_command

  -- With a name argument, :RepoFiles/:RepoGrep/:PluginsBook* resolve and
  -- dispatch straight to the engine, skipping pickers.command.handle.
  local prev_engines = package.loaded["pickers.engines"]
  local engine_calls
  package.loaded["pickers.engines"] = {
    load = function()
      return {
        pick_files = function(opts)
          engine_calls = { kind = "files", opts = opts }
        end,
        live_grep = function(opts)
          engine_calls = { kind = "grep", opts = opts }
        end,
      }
    end,
  }

  local base = vim.fn.tempname()
  vim.fn.mkdir(base .. "/lib.nvim/.git", "p")
  config.apply({ repos_dir = base })

  engine_calls = nil
  vim.cmd("RepoFiles lib.nvim")
  check(
    "usrcmds: :RepoFiles <name> resolves and dispatches directly",
    engine_calls
      and engine_calls.kind == "files"
      and engine_calls.opts.roots[1] == vim.fs.normalize(base .. "/lib.nvim")
  )

  engine_calls = nil
  vim.cmd("RepoGrep lib.nvim")
  check(
    "usrcmds: :RepoGrep <name> resolves and dispatches directly",
    engine_calls and engine_calls.kind == "grep"
  )

  -- Wrapped in pcall purely to keep this test process alive: an unresolved
  -- name's notify.error(...) surfaces as a real error through vim.cmd() in
  -- this headless harness (lib.nvim's usercmd pcall only guards a *thrown*
  -- callback, not an ERROR-level notification). What matters here is that
  -- resolution stopped before ever reaching the engine.
  engine_calls = nil
  pcall(vim.cmd, "RepoFiles does-not-exist")
  check("usrcmds: :RepoFiles <unknown name> does not dispatch", engine_calls == nil)

  local completed = vim.fn.getcompletion("RepoFiles lib", "cmdline")
  check("usrcmds: :RepoFiles completion resolves repo names", has(completed, "lib.nvim"))

  vim.fn.delete(base, "rf")
  package.loaded["pickers.engines"] = prev_engines

  local prev_last = package.loaded["pickers.last"]
  local last_ran = false
  package.loaded["pickers.last"] = {
    run = function()
      last_ran = true
    end,
  }
  vim.cmd("PickersRepeat")
  check("usrcmds: :PickersRepeat -> pickers.last.run()", last_ran)
  package.loaded["pickers.last"] = prev_last

  local prev_builtins = package.loaded["pickers.builtins"]
  local resume_name
  package.loaded["pickers.builtins"] = {
    run = function(name)
      resume_name = name
    end,
  }
  vim.cmd("PickersResume")
  check("usrcmds: :PickersResume -> builtins.run('resume')", resume_name == "resume")
  package.loaded["pickers.builtins"] = prev_builtins

  local ok_scopes = pcall(vim.cmd, "PickersScopes")
  check("usrcmds: :PickersScopes does not throw", ok_scopes)

  config.apply({ repos_dir = vim.fn.getcwd() })
end

-- ── pickers.bindings.autocmds — VimEnter fallback, guarded by setup_called ──
do
  local prev_setup_called = vim.g.pickers_nvim_setup_called
  local prev_bindings = package.loaded["pickers.bindings"]

  local setup_calls = 0
  package.loaded["pickers.bindings"] = {
    setup = function()
      setup_calls = setup_calls + 1
    end,
  }
  package.loaded["pickers.bindings.autocmds"] = nil
  local autocmds = require("pickers.bindings.autocmds")
  autocmds.register()

  -- setup() was already called: the fallback is a no-op.
  vim.g.pickers_nvim_setup_called = true
  vim.api.nvim_exec_autocmds("VimEnter", {})
  check("autocmds: setup_called=true -> fallback skips bindings.setup", setup_calls == 0)

  -- `once = true` already consumed that autocmd; register a fresh one to
  -- exercise the "setup() was never called" branch.
  package.loaded["pickers.bindings.autocmds"] = nil
  autocmds = require("pickers.bindings.autocmds")
  autocmds.register()
  vim.g.pickers_nvim_setup_called = false
  vim.api.nvim_exec_autocmds("VimEnter", {})
  check("autocmds: setup_called=false -> fallback runs bindings.setup once", setup_calls == 1)

  vim.api.nvim_exec_autocmds("VimEnter", {})
  check("autocmds: fallback is one-shot (once=true)", setup_calls == 1)

  vim.g.pickers_nvim_setup_called = prev_setup_called
  package.loaded["pickers.bindings"] = prev_bindings
  package.loaded["pickers.bindings.autocmds"] = nil
end

-- ── pickers.bindings — setup(): enable-flag gating of every sub-registrar ───
do
  local calls
  local function reset_calls()
    calls =
      { composer = 0, keymaps = 0, usrcmds = 0, collections = 0, mappings = 0, keys_patch = 0 }
  end

  local prev = {
    ["pickers.command.composer"] = package.loaded["pickers.command.composer"],
    ["pickers.bindings.keymaps"] = package.loaded["pickers.bindings.keymaps"],
    ["pickers.bindings.usrcmds"] = package.loaded["pickers.bindings.usrcmds"],
    ["pickers.bindings.collections"] = package.loaded["pickers.bindings.collections"],
    ["pickers.mappings"] = package.loaded["pickers.mappings"],
    ["pickers.keys"] = package.loaded["pickers.keys"],
  }

  package.loaded["pickers.command.composer"] = {
    register = function()
      calls.composer = calls.composer + 1
    end,
  }
  package.loaded["pickers.bindings.keymaps"] = {
    register = function()
      calls.keymaps = calls.keymaps + 1
    end,
  }
  package.loaded["pickers.bindings.usrcmds"] = {
    register = function()
      calls.usrcmds = calls.usrcmds + 1
    end,
  }
  package.loaded["pickers.bindings.collections"] = {
    register = function()
      calls.collections = calls.collections + 1
    end,
  }
  package.loaded["pickers.mappings"] = {
    apply = function()
      calls.mappings = calls.mappings + 1
    end,
  }
  package.loaded["pickers.keys"] = {
    patch = function()
      calls.keys_patch = calls.keys_patch + 1
    end,
  }
  package.loaded["pickers.bindings"] = nil
  local bindings = require("pickers.bindings")

  reset_calls()
  bindings.setup({
    keymaps = { enable = true },
    usercmds = { enable = true },
    collections = { { name = "a", dir = "/a" }, { name = "b", dir = "/b" } },
    keys = { enable = true },
  })
  check("bindings.setup: composer always registers", calls.composer == 1)
  check("bindings.setup: keymaps.enable=true -> registered", calls.keymaps == 1)
  check("bindings.setup: usercmds.enable=true -> registered", calls.usrcmds == 1)
  check("bindings.setup: one collections.register() per collection", calls.collections == 2)
  check("bindings.setup: mappings.apply always runs", calls.mappings == 1)
  check("bindings.setup: keys.enable=true -> keys.patch runs", calls.keys_patch == 1)

  reset_calls()
  bindings.setup({
    keymaps = { enable = false },
    usercmds = { enable = false },
    collections = {},
    keys = { enable = false },
  })
  check("bindings.setup: keymaps.enable=false -> skipped", calls.keymaps == 0)
  check("bindings.setup: usercmds.enable=false -> skipped", calls.usrcmds == 0)
  check(
    "bindings.setup: no collections -> collections.register never called",
    calls.collections == 0
  )
  check("bindings.setup: keys.enable=false -> keys.patch skipped", calls.keys_patch == 0)
  check("bindings.setup: composer still registers", calls.composer == 1)
  check("bindings.setup: mappings.apply still runs", calls.mappings == 1)

  reset_calls()
  bindings.setup({ keymaps = { enable = false }, usercmds = { enable = false }, collections = {} })
  check("bindings.setup: keys defaults to enabled when cfg.keys is nil", calls.keys_patch == 1)

  for name, mod in pairs(prev) do
    package.loaded[name] = mod
  end
  package.loaded["pickers.bindings"] = nil
end

-- ── pickers.health — :checkhealth pickers ────────────────────────────────────
-- Round 1 skipped this file outright ("a pure :checkhealth report, nothing
-- it returns to assert on") -- true for most of it, but `M.check()` is a
-- single unbroken function body, so a raised error partway through still
-- means the WHOLE report never finishes, which is something `pcall` can see
-- even with nothing returned. Real `vim.health.*` (Neovim 0.10+) is a plain
-- printer outside an actual `:checkhealth` buffer too, so it needs no stub.
do
  package.loaded["pickers.health"] = nil
  local health = require("pickers.health")

  -- Smoke test: with lib.nvim actually present (a real CI/dev sibling), the
  -- full report -- dependencies, engines, CLI tools, config, images,
  -- collections, declared tools -- runs to completion without raising. This
  -- is the path every real, correctly-installed user takes.
  local ok_smoke = pcall(health.check)
  check("health.check: does not raise when lib.nvim is fully present", ok_smoke)

  -- BUG: the dependency section's "not found" branch for
  -- lib.nvim.bindings.usercmd.composer (line ~32) reports it missing via an
  -- ordinary `vim.health.error()` and carries on -- the same graceful
  -- pattern every other missing-dependency check in this function uses. But
  -- the very last line of `M.check()` unconditionally does
  -- `require("lib.nvim.bindings.usercmd.composer").checkhealth("Pickers")`,
  -- OUTSIDE any pcall, calling straight into the exact module the section
  -- above just reported as absent. On a real "not found" that require
  -- throws again -- this time uncaught -- so `:checkhealth pickers` crashes
  -- outright instead of finishing the report, in precisely the situation
  -- where the user most needs a coherent one. Same "health.lua's
  -- dependency-missing branch calls into the missing dependency
  -- unconditionally afterwards" family already found in four other repos.
  local prev_loaded = package.loaded["lib.nvim.bindings.usercmd.composer"]
  package.loaded["lib.nvim.bindings.usercmd.composer"] = nil
  package.preload["lib.nvim.bindings.usercmd.composer"] = function()
    error("simulated: module not found")
  end

  local ok_missing = pcall(health.check)
  check(
    "BUG: health.check() crashes (instead of finishing the report) when "
      .. "lib.nvim.bindings.usercmd.composer is missing, even though the "
      .. "earlier dependency check already reported it as missing",
    not ok_missing
  )

  package.preload["lib.nvim.bindings.usercmd.composer"] = nil
  package.loaded["lib.nvim.bindings.usercmd.composer"] = prev_loaded
  package.loaded["pickers.health"] = nil
end

-- ── pickers (init.lua) — setup(): sets the flag, wires opt-in patches ───────
do
  local prev_setup_called = vim.g.pickers_nvim_setup_called
  local prev = {
    ["pickers.config"] = package.loaded["pickers.config"],
    ["pickers.bindings"] = package.loaded["pickers.bindings"],
    ["pickers.history"] = package.loaded["pickers.history"],
    ["pickers.smart.frecency"] = package.loaded["pickers.smart.frecency"],
    ["pickers"] = package.loaded["pickers"],
  }

  local calls
  local function reset_calls()
    calls = { bindings_setup = 0, history_patch = 0, frecency_patch = 0 }
  end

  local fake_cfg
  package.loaded["pickers.config"] = {
    apply = function() end,
    get = function()
      return fake_cfg
    end,
  }
  package.loaded["pickers.bindings"] = {
    setup = function()
      calls.bindings_setup = calls.bindings_setup + 1
    end,
  }
  package.loaded["pickers.history"] = {
    patch = function()
      calls.history_patch = calls.history_patch + 1
    end,
  }
  package.loaded["pickers.smart.frecency"] = {
    patch = function()
      calls.frecency_patch = calls.frecency_patch + 1
    end,
  }
  package.loaded["pickers"] = nil
  local pickers = require("pickers")

  vim.g.pickers_nvim_setup_called = nil
  reset_calls()
  fake_cfg = {
    history = { enabled = false },
    smart = { frecency = { enabled = false } },
    deps_popup = false,
  }
  pickers.setup({})
  check(
    "pickers.setup: marks vim.g.pickers_nvim_setup_called",
    vim.g.pickers_nvim_setup_called == true
  )
  check("pickers.setup: always calls bindings.setup", calls.bindings_setup == 1)
  check("pickers.setup: history.enabled=false -> history.patch skipped", calls.history_patch == 0)
  check(
    "pickers.setup: frecency.enabled=false -> frecency.patch skipped",
    calls.frecency_patch == 0
  )

  reset_calls()
  fake_cfg =
    { history = { enabled = true }, smart = { frecency = { enabled = true } }, deps_popup = false }
  pickers.setup({})
  check("pickers.setup: history.enabled=true -> history.patch runs", calls.history_patch == 1)
  check("pickers.setup: frecency.enabled=true -> frecency.patch runs", calls.frecency_patch == 1)

  for name, mod in pairs(prev) do
    package.loaded[name] = mod
  end
  vim.g.pickers_nvim_setup_called = prev_setup_called
end

-- ── Summary ─────────────────────────────────────────────────────────────────
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
