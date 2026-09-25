---@module 'pickers.find_native'
---@brief Apply `find.exclude` to the engines' native file/grep pickers.
---@description
--- `find.exclude` already reaches every picker pickers.nvim opens itself. A
--- keymap that calls `:FzfLua files` or `:Telescope find_files` directly, or a
--- builtin dispatched to the engine, never passes through those calls -- so
--- the same exclude list used to be kept by hand once per engine config. This
--- patches it onto each engine's own global config instead, once the engine is
--- loaded (`pickers.engines.when_loaded`):
---
---   telescope -> `defaults.file_ignore_patterns` (Lua patterns, escaped)
---   fzf-lua   -> `files.fd_opts` (`--exclude`) and `grep.rg_opts` (`-g '!..'`)
---   snacks    -> `Snacks.config.picker.sources.{files,grep}.exclude`
---
--- Entries the host already has are not duplicated. No-op when the effective
--- exclude list is empty or `find.native == false`.
---
--- `with_ignore_list()` implements `find.ignore_list`: lib.nvim's shared list
--- (`lib.nvim.fs.ignore.list`) folded into the excludes.

local M = {}

---Convert one of lib.nvim's Lua-pattern ignore entries into a fd/rg glob.
---Only the plain shapes (`%.log`, `yarn.lock`, `pnpm%-lock.yaml`) convert;
---anything using real pattern magic is dropped rather than guessed at.
---@param pat string
---@return string|nil
local function pattern_to_glob(pat)
  local unescaped = pat:gsub("%%([%.%-])", "%1")
  if unescaped:find("[%%%[%]%(%)%+%*%?%^%$]") then return nil end
  -- A leading dot-extension pattern (`%.log`) is an extension, not a name.
  if pat:sub(1, 2) == "%." then return "*" .. unescaped end
  return unescaped
end

---@param exclude string[]|nil
---@return string[]
function M.with_ignore_list(exclude)
  local ok, list = pcall(require, "lib.nvim.fs.ignore.list")
  local out, seen = {}, {}
  local function add(g)
    if type(g) == "string" and g ~= "" and not seen[g] then
      seen[g] = true
      out[#out + 1] = g
    end
  end
  if ok and type(list) == "table" then
    for _, name in ipairs(list.basenames or {}) do
      add(name)
    end
    for _, pat in ipairs(list.patterns or {}) do
      add(pattern_to_glob(pat))
    end
  end
  for _, g in ipairs(exclude or {}) do
    add(g)
  end
  return out
end

---Escape a glob into a Lua pattern for telescope's file_ignore_patterns.
---@param glob string
---@return string
local function glob_to_lua_pattern(glob)
  local escaped = glob:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%0"):gsub("%*", ".*")
  return escaped
end

---@param exclude string[]
local function telescope(exclude)
  if not pcall(require, "telescope") then return end
  pcall(function()
    local current = (require("telescope.config").values or {}).file_ignore_patterns or {}
    local have = {}
    for _, p in ipairs(current) do
      have[p] = true
    end
    local merged = vim.deepcopy(current)
    for _, g in ipairs(exclude) do
      local p = glob_to_lua_pattern(g)
      if not have[p] then
        have[p] = true
        merged[#merged + 1] = p
      end
    end
    require("telescope").setup({ defaults = { file_ignore_patterns = merged } })
  end)
end

---Append `flag` + quoted glob for every exclude the option string lacks.
---@param base string|nil
---@param exclude string[]
---@param flag string
---@param negate boolean
---@return string
local function append_globs(base, exclude, flag, negate)
  local out = base or ""
  for _, g in ipairs(exclude) do
    local arg = vim.fn.shellescape((negate and "!" or "") .. g)
    if not out:find(arg, 1, true) then out = out .. " " .. flag .. " " .. arg end
  end
  return out
end

---@param exclude string[]
local function fzf(exclude)
  local ok, fzf_lua = pcall(require, "fzf-lua")
  if not ok then return end
  pcall(function()
    local globals = require("fzf-lua.config").globals or {}
    local files = (globals.files or {}).fd_opts
    local grep = (globals.grep or {}).rg_opts
    fzf_lua.setup({
      files = { fd_opts = append_globs(files, exclude, "--exclude", false) },
      grep = { rg_opts = append_globs(grep, exclude, "-g", true) },
    }, true)
  end)
end

---@param exclude string[]
local function snacks(exclude)
  local ok, Snacks = pcall(require, "snacks")
  if not ok then return end
  pcall(function()
    local picker = Snacks.config.picker or {}
    picker.sources = picker.sources or {}
    for _, source in ipairs({ "files", "grep" }) do
      local s = picker.sources[source] or {}
      local have, list = {}, vim.deepcopy(s.exclude or {})
      for _, g in ipairs(list) do
        have[g] = true
      end
      for _, g in ipairs(exclude) do
        if not have[g] then list[#list + 1] = g end
      end
      s.exclude = list
      picker.sources[source] = s
    end
    Snacks.config.picker = picker
  end)
end

---@param cfg Pickers.Config|nil
function M.patch(cfg)
  cfg = cfg or require("pickers.config").get()
  local find = cfg.find or {}
  if find.native == false then return end
  local exclude = find.exclude
  if type(exclude) ~= "table" or #exclude == 0 then return end

  local when_loaded = require("pickers.engines.when_loaded")
  when_loaded.run("telescope", function()
    telescope(exclude)
  end)
  when_loaded.run("fzf-lua", function()
    fzf(exclude)
  end)
  when_loaded.run("snacks", function()
    snacks(exclude)
  end)
end

return M
