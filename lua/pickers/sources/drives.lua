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

local M = {}

-- Module-level cache — drives don't change during a session.
local _cache = nil ---@type string[]|nil

-- ── Platform detection ────────────────────────────────────────────────────────

local function is_windows()
  local ok, m = pcall(require, "lib.nvim.cross.platform.is_windows")
  if ok and type(m) == "function" then return m() end
  if ok and type(m) == "table" and type(m.check) == "function" then return m.check() end
  return vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
end

local function is_wsl()
  local ok, m = pcall(require, "lib.nvim.cross.platform.is_wsl")
  if ok and type(m) == "function" then return m() end
  if ok and type(m) == "table" and type(m.check) == "function" then return m.check() end
  if vim.env.WSLENV then return true end
  local ok2, lines = pcall(vim.fn.readfile, "/proc/version")
  return ok2 and lines and lines[1] and lines[1]:lower():find("microsoft", 1, true) ~= nil
end

-- ── Root discovery ────────────────────────────────────────────────────────────

local function windows_roots()
  local roots = {}
  local _, out = require("lib.nvim.cross.run_argv").run_blocking_captured({
    "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
    "Get-PSDrive -PSProvider FileSystem | Select -ExpandProperty Root",
  })
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
  return roots
end

local function wsl_roots()
  local dirs = {}
  for letter in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
    local p = "/mnt/" .. letter
    if vim.fn.isdirectory(p) == 1 then dirs[#dirs + 1] = p end
  end
  return dirs
end

local function posix_roots()
  local dirs = {}
  local _, out = require("lib.nvim.cross.run_argv").run_blocking_captured({ "df", "-P", "--output=target" })
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
  return dirs
end

local function get_roots()
  if _cache then return _cache end

  local raw
  if is_windows() then
    raw = windows_roots()
  elseif is_wsl() then
    raw = wsl_roots()
  else
    raw = posix_roots()
  end

  _cache = require("lib.lua.tables").dedup_list(raw)
  return _cache
end

-- ── Public API ────────────────────────────────────────────────────────────────

---@param _cfg    Pickers.Config
---@param callback fun(Pickers.Source|nil)
function M.get(_cfg, callback)
  local roots = get_roots()
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
end

return M
