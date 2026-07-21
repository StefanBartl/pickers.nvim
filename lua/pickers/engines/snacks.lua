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

local notify = require("lib.nvim.notify").create("[pickers.engines.snacks]")

local M = {}

---@return string  "fd" | "fdfind" (Debian/Ubuntu package name), fd assumed if neither is found.
local function fd_exec()
  if vim.fn.executable("fd") == 1 then return "fd" end
  if vim.fn.executable("fdfind") == 1 then return "fdfind" end
  return "fd"
end

---Safely call a function; report errors via notify.
---@param fn function
---@param opts table
local function safe_call(fn, opts)
  local ok, err = pcall(fn, opts)
  if not ok then
    notify.error("snacks error: " .. tostring(err))
  end
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
  local args = vim.list_extend({ "--hidden", "--no-ignore-vcs", "-S" }, extra)

  local call_opts = { title = opts.prompt, args = args }
  if #opts.roots > 1 then
    call_opts.dirs = opts.roots
  else
    call_opts.dirs = { opts.roots[1] }
  end

  safe_call(Picker.grep, call_opts)
end

---Pick one item from a string list.
---@param opts { items: string[], prompt: string, on_select: fun(string) }
function M.pick_item(opts)
  local ok, Picker = pcall(require, "snacks.picker")
  if not ok then
    notify.error("snacks.picker unavailable")
    return
  end

  Picker.select(opts.items, { prompt = opts.prompt }, function(item)
    if item then
      opts.on_select(item)
    end
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

  local cwd = opts.cwd or vim.fn.getcwd()

  vim.system(
    { fd_exec(), "--type", "d", "--hidden", "--follow", "--exclude", ".git", ".", cwd },
    { text = true },
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
          if dir then
            opts.on_select(dir)
          end
        end)
      end)
    end
  )
end

return M
