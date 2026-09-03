---@module 'pickers.engines.snacks'
---@brief snacks.nvim (Snacks.picker) adapter — implements the pickers engine interface.
---@see pickers.engines.fzf  (same interface)
---@description
--- Interface contract (all methods that pickers.nvim calls on an engine):
---   available()        → boolean
---   pick_files(opts)   → nil
---   live_grep(opts)    → nil
---   pick_item(opts)    → nil   (used by repos / wkdbooks sources)
---   pick_dir(opts)     → nil   (used by folder source)
---
--- Snacks has no native raw-argv override for `files`/`grep` and no native
--- directory-picker source — both are handled here the same way
--- pickers.engines.telescope/fzf handle them: shell out to `fd` ourselves for
--- pick_dir, and build a custom finder via snacks' own proc() builder (the
--- same one files.lua/grep.lua use internally) for find_command.
---
--- `cfg.display.path_shorten` (see `pickers.config`'s `Pickers.DisplayConfig`)
--- is intentionally NOT wired here, unlike telescope/fzf-lua: snacks already
--- truncates the displayed path to fit the available column width by
--- default (`Snacks.picker.util.truncpath`, in its own formatter), so there
--- is nothing to opt into.
---
--- Image previews (`pickers.integrations.images`) are wired into every picker
--- here that lists files -- pick_files, smart, pick_item -- as a `preview`
--- function, which snacks resolves per call. `preview_fn()` returns nil
--- whenever the integration does not apply, and nil is the right value to
--- pass: an unset `preview` is what makes snacks use its own default.
--- pick_dir is left out on purpose (a directory is never an image entry).
--- PDF entries ride the same function; see the adapter for what changes when
--- the picture has to be made before it can be drawn.

local notify = require("lib.nvim.notify").create("[pickers.engines.snacks]")
local spawn_env = require("lib.nvim.cross.run.env")

local M = {}

---@internal
---fd's executable name. Debian and Ubuntu ship it as `fdfind` because `fd` is
---taken by another package, so hard-coding `"fd"` makes the directory picker
---fail outright there. fzf-lua's own `files()` provider auto-detects this
---internally; these two engines shell out themselves and have to do it here.
---@return string|nil  "fd" | "fdfind" | nil
local function fd_exec()
  if vim.fn.executable("fd") == 1 then return "fd" end
  if vim.fn.executable("fdfind") == 1 then return "fdfind" end
  return nil
end

---Safely call a function; report errors via notify.
---@internal
---@param fn function
---@param opts table
local function safe_call(fn, opts)
  local ok, err = pcall(fn, opts)
  if not ok then notify.error("snacks error: " .. tostring(err)) end
end

---The image-preview function for this call, or nil when image previews do not
---apply (see `pickers.integrations.images`). Resolved per picker, not cached:
---the terminal, the configuration and images.nvim's own availability can all
---change between two pickers within a session.
---@internal
---@return (fun(ctx: table))|nil
local function preview_fn()
  return require("pickers.integrations.images.adapters.snacks").preview_fn()
end

-- ── Public engine interface ───────────────────────────────────────────────────

---@return boolean
function M.available()
  local ok, picker = pcall(require, "snacks.picker")
  return ok and type(picker) == "table"
end

---@param opts Pickers.EngineOpts
function M.pick_files(opts)
  local ok, Picker = pcall(require, "snacks.picker")
  if not ok then
    notify.error("snacks.picker unavailable")
    return
  end

  -- Custom find command (system source) — bypass the "files" source's own
  -- cmd-selection entirely via a custom finder, same proc() builder snacks'
  -- own files.lua uses internally.
  if opts.find_command then
    safe_call(Picker.pick, {
      source = "files",
      title = opts.prompt,
      preview = preview_fn(),
      finder = function(_, ctx)
        return require("snacks.picker.source.proc").proc(
          ctx:opts({
            cmd = opts.find_command[1],
            args = vim.list_slice(opts.find_command, 2),
            ---@param item snacks.picker.finder.Item
            transform = function(item)
              item.cwd = opts.roots[1]
              item.file = item.text
            end,
          }),
          ctx
        )
      end,
    })
    return
  end

  local f = opts.find or {}
  local call_opts = {
    title = opts.prompt,
    hidden = f.hidden,
    ignored = f.no_ignore,
    follow = f.follow,
    exclude = f.exclude,
    preview = preview_fn(),
  }

  if #opts.roots > 1 then
    call_opts.dirs = opts.roots
  else
    call_opts.cwd = opts.roots[1]
  end

  safe_call(Picker.files, call_opts)
end

---@param opts Pickers.EngineOpts
function M.live_grep(opts)
  local ok, Picker = pcall(require, "snacks.picker")
  if not ok then
    notify.error("snacks.picker unavailable")
    return
  end

  local extra = opts.additional_args or {}
  -- Same flags telescope/fzf pass; "-S" is redundant with grep's own
  -- always-on "--smart-case" but harmless.
  local args = { "--hidden", "--no-ignore-vcs", "-S" }
  for _, g in ipairs((opts.find or {}).exclude or {}) do
    args[#args + 1] = "-g"
    args[#args + 1] = "!" .. g
  end
  vim.list_extend(args, extra)

  local call_opts = { title = opts.prompt, args = args }
  if #opts.roots > 1 then
    call_opts.dirs = opts.roots
  else
    call_opts.dirs = { opts.roots[1] }
  end

  safe_call(Picker.grep, call_opts)
end

---Combined grep + find-files picker (the `smart` action).
---
--- Implemented as a live picker with a custom *synchronous* finder: on every
--- prompt change snacks calls the finder with the raw search text
--- (`ctx.filter.search`), we run the shared core (pickers.smart.query) which
--- returns an already-merged, already-ranked list, and we hand that back as a
--- plain table. Returning a table takes snacks' sync finder path (no streaming),
--- and under `live = true` the secondary matcher pattern is empty, so snacks
--- preserves our order instead of re-fuzzy-sorting — i.e. OUR relevance ranking
--- is what the user sees. `format = "file"` renders file rows and grep rows
--- (file + line) natively; the default `jump` confirm opens item.file at pos.
---@param opts Pickers.EngineOpts
function M.smart(opts)
  local ok, Picker = pcall(require, "snacks.picker")
  if not ok then
    notify.error("snacks.picker unavailable")
    return
  end

  safe_call(Picker.pick, {
    source = "smart",
    title = opts.prompt or "Smart> ",
    live = true,
    format = "file",
    preview = preview_fn(),
    matcher = { sort_empty = false },
    finder = function(_, ctx)
      local items = require("pickers.smart").query(ctx.filter.search or "", {
        roots = opts.roots,
        find = opts.find,
        additional_args = opts.additional_args,
      })
      local out = {}
      for i, it in ipairs(items) do
        out[i] = {
          text = it.display,
          file = it.abspath,
          pos = it.lnum and { it.lnum, (it.col or 1) - 1 } or nil,
          line = it.text,
          score = it.score,
        }
      end
      return out
    end,
  })
end

---Pick one item from a list. Items may be plain strings (unchanged) or
---`Pickers.Item` tables `{ text, file? }`.
---
---No branching needed here, unlike the telescope/fzf adapters: `Picker.select`
---builds its internal finder entries via `setmetatable({}, { __index = item })`
---for table items (see snacks.picker.select), so `it.file` already resolves
---straight through to our `file` field — and snacks' own picker config
---defaults `preview` to `Snacks.picker.preview.file` whenever nothing else is
---set, which `select()` never overrides. A `file` field is previewed "for
---free"; items without one just get snacks' own graceful "no preview
---available" — the config's own existing default, not new behaviour from
---this change. `format_item` only needs to read `.text` off a table item
---instead of falling through to `tostring()`.
---@param opts { items: (string|Pickers.Item)[], prompt: string, on_select: fun(item: string|Pickers.Item) }
function M.pick_item(opts)
  local ok, Picker = pcall(require, "snacks.picker")
  if not ok then
    notify.error("snacks.picker unavailable")
    return
  end

  local preview = preview_fn()
  Picker.select(opts.items, {
    prompt = opts.prompt,
    format_item = function(item)
      return (type(item) == "table") and item.text or tostring(item)
    end,
    -- `select` builds its own picker options and merges `snacks` over them, so
    -- this is the only way in -- and the only key that may travel this way:
    -- `select`'s own `on_close` completes the vim.ui.select contract, and a
    -- merge would replace it rather than wrap it.
    snacks = preview and { preview = preview } or nil,
  }, function(item)
    if item then opts.on_select(item) end
  end)
end

---Open a directory picker. Snacks has no native dir source (neither do
---telescope/fzf — both shell out to `fd --type d` themselves); match that
---precedent, then hand the results to Snacks.picker.select.
---@param opts { prompt: string, cwd: string|nil, on_select: fun(string) }
function M.pick_dir(opts)
  local ok, Picker = pcall(require, "snacks.picker")
  if not ok then
    notify.error("snacks.picker unavailable")
    return
  end

  local fd = fd_exec()
  if not fd then
    notify.error("Neither 'fd' nor 'fdfind' found in PATH. Install fd-find.")
    return
  end

  local cwd = opts.cwd or vim.fn.getcwd()

  vim.system(
    { fd, "--type", "d", "--hidden", "--follow", "--exclude", ".git", ".", cwd },
    spawn_env.apply({ text = true }),
    function(res)
      vim.schedule(function()
        if res.code ~= 0 then
          notify.error("fd failed: " .. (res.stderr or "unknown error"))
          return
        end

        local dirs = {}
        for line in (res.stdout or ""):gmatch("[^\r\n]+") do
          dirs[#dirs + 1] = vim.fs.normalize(cwd .. "/" .. line)
        end

        if #dirs == 0 then
          notify.warn("No subdirectories found")
          return
        end

        Picker.select(dirs, { prompt = opts.prompt or "Folder> " }, function(dir)
          if dir then opts.on_select(dir) end
        end)
      end)
    end
  )
end

return M
