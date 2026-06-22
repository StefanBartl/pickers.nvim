---@module 'pickers.engines.fzf'
---@brief fzf-lua adapter — implements the pickers engine interface.
---@description
--- Interface contract (all methods that pickers.nvim calls on an engine):
---   available()        → boolean
---   pick_files(opts)   → nil
---   live_grep(opts)    → nil
---   pick_item(opts)    → nil   (used by repos / wkdbooks sources)
---   pick_dir(opts)     → nil   (used by folder source)

local notify = require("lib.nvim.notify").create("[pickers.engines.fzf]")

local M = {}

-- ── Helpers ──────────────────────────────────────────────────────────────────

---@return string|nil  "fd" | "fdfind" | nil
local function fd_exec()
  if vim.fn.executable("fd") == 1 then return "fd" end
  if vim.fn.executable("fdfind") == 1 then return "fdfind" end
  return nil
end

---Build a shell-safe fd command string for multi-root file listing.
---@param roots string[]
---@return string
local function multi_root_cmd(roots)
  local fd = fd_exec() or "fd"
  local parts = { fd, "--type", "f", "--hidden", "--follow", "--exclude", ".git" }
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
  if not ok then
    notify.error("fzf-lua error: " .. tostring(err))
  end
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
  if not ok then notify.error("fzf-lua unavailable") return end

  -- Custom find command (system source: pre-built fd argv)
  if opts.find_command then
    local cmd_str = table.concat(
      vim.tbl_map(vim.fn.shellescape, opts.find_command),
      " "
    )
    safe_call(fzf.files, {
      cmd    = cmd_str,
      prompt = opts.prompt,
      query  = opts.query,
    })
    return
  end

  -- Multi-root: construct fd command spanning all roots
  if #opts.roots > 1 then
    safe_call(fzf.files, {
      cmd    = multi_root_cmd(opts.roots),
      prompt = opts.prompt,
      query  = opts.query,
    })
    return
  end

  -- Single root: standard fzf.files
  safe_call(fzf.files, {
    cwd    = opts.roots[1],
    prompt = opts.prompt,
    query  = opts.query,
  })
end

---@param opts Pickers.EngineOpts
function M.live_grep(opts)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then notify.error("fzf-lua unavailable") return end

  local extra = opts.additional_args or {}
  local rg_opts_list = vim.list_extend({ "--hidden", "--no-ignore-vcs", "-S" }, extra)

  safe_call(fzf.live_grep, {
    search_dirs = opts.roots,
    prompt      = opts.prompt,
    rg_opts     = table.concat(rg_opts_list, " "),
    query       = opts.query,
  })
end

---Pick one item from a string list (used by repos / wkdbooks sources).
---@param opts { items: string[], prompt: string, on_select: fun(string) }
function M.pick_item(opts)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then notify.error("fzf-lua unavailable") return end

  fzf.fzf_exec(opts.items, {
    prompt   = opts.prompt,
    fzf_opts = { ["--no-multi"] = true },
    actions  = {
      ["default"] = function(selected)
        if selected and selected[1] then
          opts.on_select(selected[1])
        end
      end,
    },
  })
end

---Open a directory picker (used by folder source).
---@param opts { prompt: string, cwd: string|nil, on_select: fun(string) }
function M.pick_dir(opts)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then notify.error("fzf-lua unavailable") return end

  local cwd = opts.cwd or vim.fn.getcwd()

  fzf.files({
    prompt   = opts.prompt or "Folder> ",
    cwd      = cwd,
    fd_opts  = "--type d --hidden --follow --exclude .git",
    actions  = {
      ["default"] = function(selected)
        if not selected or not selected[1] then return end
        local rel  = selected[1]
        local path = vim.fs.normalize(cwd .. "/" .. rel)
        opts.on_select(path)
      end,
    },
  })
end

return M
