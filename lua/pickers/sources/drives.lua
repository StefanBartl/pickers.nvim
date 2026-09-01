---@module 'pickers.sources.drives'
---@brief Source: all mount points / drive letters (cross-platform, session-cached).
---@description
--- Platform detection order:
---   1. lib.nvim.cross platform helpers (if available)
---   2. vim.fn.has("win32") / vim.fn.has("win64")
---   3. $WSLENV env var  →  WSL
---
--- Windows: PowerShell Get-PSDrive, fallback A-Z drive letter scan.
--- WSL:     /mnt/* directory scan.
--- POSIX:   df -P --output=target.

local notify = require("lib.nvim.notify").create("[pickers.sources.drives]")
local spawn_env = require("lib.nvim.cross.run.env")

local M = {}

---@internal
---Run `cmd` and hand its stdout to `cb`, without blocking the UI thread.
---
---`lib.nvim.cross.run_argv.run_blocking_captured` takes no opts (no env
---support), so `Get-PSDrive`/`df` are run through `vim.system` directly with
---a completed env (PATH + session vars) instead — neither binary is exotic,
---but a short PATH from a non-login-shell start would still miss `df` on a
---minimal $PATH, and Windows PowerShell least of all should be assumed to be
---resolvable without it.
---
---This used to be `run_captured()`, blocking on `:wait()`. On Windows the
---command is PowerShell, whose startup alone costs several hundred
---milliseconds — the whole `drives` scope froze Neovim before the picker even
---appeared. `M.get` was already callback-shaped, so making the discovery
---asynchronous did not change the module's public surface at all.
---
---Falls back to `run_argv` (and, transitively, `vim.fn.system`) on
---Neovim < 0.10, matching the module's own fallback convention.
---@param cmd string[]
---@param cb fun(output: string)
local function run_captured(cmd, cb)
  if not vim.system then
    local _, out = require("lib.nvim.cross.run_argv").run_blocking_captured(cmd)
    cb(out or "")
    return
  end

  vim.system(cmd, spawn_env.apply({ text = true }), function(obj)
    -- vim.system callbacks run off the main loop; everything downstream calls
    -- vim.fn.isdirectory and eventually opens a picker.
    vim.schedule(function()
      cb((obj and obj.stdout) or "")
    end)
  end)
end

-- Module-level cache — drives don't change during a session.
local _cache = nil ---@type string[]|nil

-- ── Platform detection ────────────────────────────────────────────────────────

---@internal
---Detect Windows via lib.nvim.cross platform helpers, falling back to `vim.fn.has`.
---@return boolean
local function is_windows()
  local ok, m = pcall(require, "lib.nvim.cross.platform.is_windows")
  if ok and type(m) == "function" then return m() end
  if ok and type(m) == "table" and type(m.check) == "function" then return m.check() end
  return vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
end

---@internal
---Detect WSL via lib.nvim.cross platform helpers, falling back to `$WSLENV` /
---`/proc/version`.
---@return boolean
local function is_wsl()
  local ok, m = pcall(require, "lib.nvim.cross.platform.is_wsl")
  if ok and type(m) == "function" then return m() end
  if ok and type(m) == "table" and type(m.check) == "function" then return m.check() end
  if vim.env.WSLENV then return true end
  local ok2, lines = pcall(vim.fn.readfile, "/proc/version")
  return ok2 and lines and lines[1] and lines[1]:lower():find("microsoft", 1, true) ~= nil
end

-- ── Root discovery ────────────────────────────────────────────────────────────

---@internal
---Windows mount points via `Get-PSDrive`, falling back to an A-Z drive-letter scan.
---@param cb fun(roots: string[])
local function windows_roots(cb)
  run_captured({
    "powershell",
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-Command",
    "Get-PSDrive -PSProvider FileSystem | Select -ExpandProperty Root",
  }, function(out)
    local roots = {}
    for line in (out or ""):gmatch("[^\r\n]+") do
      local r = line:match("^%s*(.-)%s*$")
      if r and r ~= "" then
        r = r:gsub("[/\\]+$", "\\")
        if vim.fn.isdirectory(r) == 1 then roots[#roots + 1] = r end
      end
    end
    -- Fallback: brute-force drive letter scan
    if #roots == 0 then
      for byte = string.byte("A"), string.byte("Z") do
        local d = string.char(byte) .. ":\\"
        if vim.fn.isdirectory(d) == 1 then roots[#roots + 1] = d end
      end
    end
    cb(roots)
  end)
end

---@internal
---WSL mount points: existing `/mnt/<letter>` directories.
---@return string[]
local function wsl_roots()
  local dirs = {}
  for letter in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
    local p = "/mnt/" .. letter
    if vim.fn.isdirectory(p) == 1 then dirs[#dirs + 1] = p end
  end
  return dirs
end

---@internal
---POSIX mount points via `df -P --output=target`, falling back to a fixed
---candidate list (/, /Volumes, /media, /mnt).
---@param cb fun(dirs: string[])
local function posix_roots(cb)
  run_captured({ "df", "-P", "--output=target" }, function(out)
    local dirs = {}
    local lines = vim.split(out or "", "\r?\n")
    -- Drop the header line ("Mounted on") that `tail -n +2` used to strip.
    for i = 2, #lines do
      local p = lines[i]:match("^%s*(.-)%s*$")
      if p and p ~= "" and vim.fn.isdirectory(p) == 1 then dirs[#dirs + 1] = p end
    end
    if #dirs == 0 then
      for _, p in ipairs({ "/", "/Volumes", "/media", "/mnt" }) do
        if vim.fn.isdirectory(p) == 1 then dirs[#dirs + 1] = p end
      end
    end
    cb(dirs)
  end)
end

---@internal
---Resolve and cache the current platform's mount-point/drive roots.
---@see M.get
---@param cb fun(roots: string[])
local function get_roots(cb)
  if _cache then
    cb(_cache)
    return
  end

  local function done(raw)
    _cache = require("lib.lua.tables").dedup_list(raw)
    cb(_cache)
  end

  if is_windows() then
    windows_roots(done)
  elseif is_wsl() then
    -- Pure directory probing, no process involved -- stays inline.
    done(wsl_roots())
  else
    posix_roots(done)
  end
end

-- ── Public API ────────────────────────────────────────────────────────────────

---Whether the current platform is native Windows (not WSL). Exported because
---`pickers.sources.system` needs to know when `"/"` does not mean "everything":
---on native Windows it is just the *current* drive's root, so a systemwide
---search rooted there silently searches one drive.
---@return boolean
function M.is_windows()
  return is_windows()
end

---Every mount point / drive letter for this platform, session-cached.
---Asynchronous because discovery shells out (PowerShell on Windows, `df` on
---POSIX) -- see `run_captured`'s note on why that must not block.
---Exported so a source that needs a "search everything" root list does not
---have to duplicate the platform detection.
---@param cb fun(roots: string[])
function M.roots(cb)
  get_roots(cb)
end

---The drive/mount-point source, as `pickers.sources` expects it.
---@param _cfg    Pickers.Config
---@param callback fun(source: Pickers.Source|nil)
function M.get(_cfg, callback)
  get_roots(function(roots)
    if #roots == 0 then
      notify.warn("No drive roots / mount points found")
      callback(nil)
      return
    end

    callback({
      roots = roots,
      prompt = "All Drives> ",
      -- Exclude noisy directories that would explode search time
      additional_args = {
        "-g",
        "!.git/",
        "-g",
        "!node_modules/",
        "-g",
        "!dist/",
        "-g",
        "!build/",
        "-g",
        "!target/",
        "-g",
        "!vendor/",
        "-g",
        "!.cache/",
      },
    })
  end)
end

return M
