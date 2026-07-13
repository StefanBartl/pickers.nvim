---@module 'pickers.engines.fzf'
---@brief fzf-lua adapter — implements the pickers engine interface.
---@description
--- Interface contract (all methods that pickers.nvim calls on an engine):
---   available()        → boolean
---   pick_files(opts)   → nil
---   live_grep(opts)    → nil
---   pick_item(opts)    → nil   (used by repos / wkdbooks sources)
---   pick_dir(opts)     → nil   (used by folder source)
---
--- Escape behaviour (double-escape to close):
---   fzf runs inside a Neovim terminal buffer.  A terminal-mode <Esc> keymap
---   is injected via winopts.on_create BEFORE fzf reads stdin, so Neovim
---   intercepts the key first:
---     1st <Esc>  (t-mode)  →  <C-\><C-n>  →  Normal mode of the fzf buffer
---     2nd <Esc>  (n-mode)  →  nvim_win_close  →  fzf process exits

local notify = require("lib.nvim.notify").create("[pickers.engines.fzf]")

local M = {}

-- ── Double-escape helper ─────────────────────────────────────────────────────

---Injected into winopts.on_create for every fzf-lua call.
---Sets buffer-local t-mode and n-mode <Esc> keymaps on the fzf terminal buffer
---so that the first <Esc> goes to Normal mode (without aborting fzf) and the
---second <Esc> closes the window (killing the fzf process via stdin close).
local function setup_double_esc()
  local buf = vim.api.nvim_get_current_buf()

  -- t-mode: intercept <Esc> before fzf sees it → exit terminal mode
  vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", {
    buffer = buf,
    silent = true,
    nowait = true,
  })

  -- n-mode: second <Esc> closes the floating window; fzf exits on stdin close
  vim.keymap.set("n", "<Esc>", function()
    local ok, err = pcall(vim.api.nvim_win_close, 0, true)
    if not ok then notify.debug("win_close error (already closed?): " .. tostring(err)) end
  end, {
    buffer = buf,
    silent = true,
    nowait = true,
  })
end

-- ── Other helpers ────────────────────────────────────────────────────────────

---@return string|nil  "fd" | "fdfind" | nil
local function fd_exec()
  if vim.fn.executable("fd") == 1 then return "fd" end
  if vim.fn.executable("fdfind") == 1 then return "fdfind" end
  return nil
end

---Build the fd option string (everything after `fd`, before any path args) from
---the user's find flags. Reused for single-root fd_opts and multi-root cmd.
---@param find Pickers.FindOpts|nil
---@return string
local function fd_opts_string(find)
  local f = find or {}
  local parts = { "--color=never", "--type", "f", "--exclude", ".git" }
  if f.hidden then parts[#parts + 1] = "--hidden" end
  if f.no_ignore then parts[#parts + 1] = "--no-ignore" end
  if f.follow then parts[#parts + 1] = "--follow" end
  if type(f.exclude) == "table" then
    for _, g in ipairs(f.exclude) do
      parts[#parts + 1] = "--exclude"
      parts[#parts + 1] = vim.fn.shellescape(g)
    end
  end
  return table.concat(parts, " ")
end

---Build a shell-safe fd command string for multi-root file listing.
---@param roots string[]
---@param find  Pickers.FindOpts|nil
---@return string
local function multi_root_cmd(roots, find)
  local fd = fd_exec() or "fd"
  local parts = { fd, fd_opts_string(find) }
  for _, r in ipairs(roots) do
    parts[#parts + 1] = vim.fn.shellescape(r)
  end
  return table.concat(parts, " ")
end

---Safely call an fzf-lua function, surfacing errors via notify.
---@param fn function
---@param opts table
local function safe_call(fn, opts)
  local ok, err = pcall(fn, opts)
  if not ok then notify.error("fzf-lua error: " .. tostring(err)) end
end

---`fzf_opts` for `--history`, or nil when history is disabled or scope isn't
---"plugin" (under "global"/"patch" the global fzf-lua default already covers
---it — see `pickers.history`).
---@param kind "files"|"grep"|"item"|"dir"
---@return table|nil
local function history_fzf_opts(kind)
  local cfg = require("pickers.config").get()
  if not cfg.history.enabled or cfg.history.fzf_scope ~= "plugin" then return nil end
  return { ["--history"] = require("pickers.history").fzf_path(cfg, kind) }
end

-- ── Public engine interface ───────────────────────────────────────────────────

---@return boolean
function M.available()
  local ok = pcall(require, "fzf-lua")
  return ok
end

---@param opts Pickers.EngineOpts
function M.pick_files(opts)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    notify.error("fzf-lua unavailable")
    return
  end

  local base = {
    prompt = opts.prompt,
    query = opts.query,
    winopts = { on_create = setup_double_esc },
    fzf_opts = history_fzf_opts("files"),
  }

  -- Custom find command (system source: pre-built fd argv)
  if opts.find_command then
    local cmd_str = table.concat(vim.tbl_map(vim.fn.shellescape, opts.find_command), " ")
    base.cmd = cmd_str
    safe_call(fzf.files, base)
    return
  end

  -- Multi-root: construct fd command spanning all roots
  if #opts.roots > 1 then
    base.cmd = multi_root_cmd(opts.roots, opts.find)
    safe_call(fzf.files, base)
    return
  end

  -- Single root: standard fzf.files with cwd + user find flags
  base.cwd = opts.roots[1]
  base.fd_opts = fd_opts_string(opts.find)
  safe_call(fzf.files, base)
end

---@param opts Pickers.EngineOpts
function M.live_grep(opts)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    notify.error("fzf-lua unavailable")
    return
  end

  local extra = opts.additional_args or {}
  local rg_opts_list = vim.list_extend({ "--hidden", "--no-ignore-vcs", "-S" }, extra)

  safe_call(fzf.live_grep, {
    search_dirs = opts.roots,
    prompt = opts.prompt,
    rg_opts = table.concat(rg_opts_list, " "),
    query = opts.query,
    winopts = { on_create = setup_double_esc },
    fzf_opts = history_fzf_opts("grep"),
  })
end

---Pick one item from a string list (used by repos / wkdbooks sources).
---@param opts { items: string[], prompt: string, on_select: fun(string) }
function M.pick_item(opts)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    notify.error("fzf-lua unavailable")
    return
  end

  fzf.fzf_exec(opts.items, {
    prompt = opts.prompt,
    fzf_opts = vim.tbl_extend("force", { ["--no-multi"] = true }, history_fzf_opts("item") or {}),
    winopts = { on_create = setup_double_esc },
    actions = {
      ["default"] = function(selected)
        if selected and selected[1] then opts.on_select(selected[1]) end
      end,
    },
  })
end

---Open a directory picker (used by folder source).
---@param opts { prompt: string, cwd: string|nil, on_select: fun(string) }
function M.pick_dir(opts)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    notify.error("fzf-lua unavailable")
    return
  end

  local cwd = opts.cwd or vim.fn.getcwd()

  fzf.files({
    prompt = opts.prompt or "Folder> ",
    cwd = cwd,
    fd_opts = "--type d --hidden --follow --exclude .git",
    winopts = { on_create = setup_double_esc },
    fzf_opts = history_fzf_opts("dir"),
    actions = {
      ["default"] = function(selected)
        if not selected or not selected[1] then return end
        local path = vim.fs.normalize(cwd .. "/" .. selected[1])
        opts.on_select(path)
      end,
    },
  })
end

return M
