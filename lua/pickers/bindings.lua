---@module 'pickers.bindings'
---@brief ALL keymaps and compat user-commands in one thematically organised file.
---@description
--- Keymaps registered when keymaps.enable = true:
---   <leader>dp   Dir navigation picker
---   <leader>fb   Find files in picked folder
---   <leader>fc   Find files in nvim config
---   <leader>gc   Grep in nvim config
---   <leader>li   Live grep in CWD
---   (cwd_files)  Find files in CWD  (nil by default)
---
--- Compat user-commands (usercmds.enable = true):
---   :DirPicker [nav]  :FindInFolder  :FindConfig  :GrepConfig
---   :LiveGrep  :AllDrives  :AllDrivesGrep  :FindOnSystem
---   :RepoFiles  :RepoGrep  :WkdBookFiles  :WkdBookGrep
---
--- Collection compat-commands (auto-generated per collection):
---   :{PascalName}Files  →  :Pickers {name} files
---   :{PascalName}Grep   →  :Pickers {name} grep

local M = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

---Register a single normal-mode keymap, preferring lib.nvim.map if available.
---@param lhs  string|nil
---@param rhs  function
---@param desc string
local function map(lhs, rhs, desc)
  if not lhs then return end
  local ok, lib_map = pcall(require, "lib.nvim.map")
  if ok and type(lib_map) == "function" then
    lib_map("n", lhs, rhs, { desc = desc })
  else
    vim.keymap.set("n", lhs, rhs, { desc = desc, silent = true })
  end
end

---Create a user command with consistent defaults.
---@param name  string
---@param fn    fun(opts: table)
---@param desc  string
---@param nargs string|nil  default "*"
local function usercmd(name, fn, desc, nargs)
  vim.api.nvim_create_user_command(name, fn, { desc = desc, nargs = nargs or "*" })
end

---Convert snake_case name to PascalCase for compat command names.
---  "notes"     → "Notes"
---  "notes_lua" → "NotesLua"
---@param name string
---@return string
local function to_pascal(name)
  local r = name:gsub("_(%a)", function(l) return l:upper() end)
  return r:sub(1, 1):upper() .. r:sub(2)
end

-- ── Keymaps ───────────────────────────────────────────────────────────────────

---@param km Pickers.Keymaps
function M._register_keymaps(km)
  map(km.dir_pick, function()
    require("pickers.command").handle({ fargs = { "dir" } })
  end, "[pickers] Dir: navigate (alias / depth / path)")

  map(km.folder_files, function()
    require("pickers.command").handle({ fargs = { "folder", "files" } })
  end, "[pickers] Find files in interactively picked folder")

  map(km.config_files, function()
    require("pickers.command").handle({ fargs = { "config", "files" } })
  end, "[pickers] Find files in nvim config")

  map(km.config_grep, function()
    require("pickers.command").handle({ fargs = { "config", "grep" } })
  end, "[pickers] Grep in nvim config")

  map(km.cwd_grep, function()
    require("pickers.command").handle({ fargs = { "cwd", "grep" } })
  end, "[pickers] Live grep in CWD")

  map(km.cwd_files, function()
    require("pickers.command").handle({ fargs = { "cwd", "files" } })
  end, "[pickers] Find files in CWD")
end

-- ── Built-in compat user-commands ─────────────────────────────────────────────

function M._register_usercmds()
  usercmd("DirPicker", function(opts)
    local fargs = { "dir" }
    for _, a in ipairs(opts.fargs) do fargs[#fargs + 1] = a end
    require("pickers.command").handle({ fargs = fargs })
  end, "[pickers compat] :DirPicker [nav] → :Pickers dir [nav]", "*")

  usercmd("FindConfig", function(_)
    require("pickers.command").handle({ fargs = { "config", "files" } })
  end, "[pickers compat] :FindConfig → :Pickers config files", "?")

  usercmd("GrepConfig", function(_)
    require("pickers.command").handle({ fargs = { "config", "grep" } })
  end, "[pickers compat] :GrepConfig → :Pickers config grep", "?")

  usercmd("FindInFolder", function(_)
    require("pickers.command").handle({ fargs = { "folder", "files" } })
  end, "[pickers compat] :FindInFolder → :Pickers folder files", "*")

  usercmd("LiveGrep", function(_)
    require("pickers.command").handle({ fargs = { "cwd", "grep" } })
  end, "[pickers compat] :LiveGrep → :Pickers cwd grep", "?")

  usercmd("AllDrives", function(_)
    require("pickers.command").handle({ fargs = { "drives", "files" } })
  end, "[pickers compat] :AllDrives → :Pickers drives files", "?")

  usercmd("AllDrivesGrep", function(_)
    require("pickers.command").handle({ fargs = { "drives", "grep" } })
  end, "[pickers compat] :AllDrivesGrep → :Pickers drives grep", "?")

  usercmd("FindOnSystem", function(_)
    require("pickers.command").handle({ fargs = { "system", "files" } })
  end, "[pickers compat] :FindOnSystem → :Pickers system files", "?")

  usercmd("RepoFiles", function(_)
    require("pickers.command").handle({ fargs = { "repos", "files" } })
  end, "[pickers] :RepoFiles — pick repo, then find files", "?")

  usercmd("RepoGrep", function(_)
    require("pickers.command").handle({ fargs = { "repos", "grep" } })
  end, "[pickers] :RepoGrep — pick repo, then live grep", "?")

  usercmd("WkdBookFiles", function(_)
    require("pickers.command").handle({ fargs = { "wkdbooks", "files" } })
  end, "[pickers] :WkdBookFiles — pick wkdbook, then find files", "?")

  usercmd("WkdBookGrep", function(_)
    require("pickers.command").handle({ fargs = { "wkdbooks", "grep" } })
  end, "[pickers] :WkdBookGrep — pick wkdbook, then live grep", "?")
end

-- ── Collection compat-commands + keymaps ──────────────────────────────────────

---Register compat commands and optional keymaps for one collection.
---@param coll Pickers.Collection
function M._register_collection_bindings(coll)
  local pascal    = to_pascal(coll.name)
  local files_cmd = pascal .. "Files"
  local grep_cmd  = pascal .. "Grep"
  local name      = coll.name

  -- Skip if the compat command already exists (e.g. WkdBookFiles from _register_usercmds)
  if vim.fn.exists(":" .. files_cmd) ~= 2 then
    usercmd(files_cmd, function(_)
      require("pickers.command").handle({ fargs = { name, "files" } })
    end, "[pickers coll] :" .. files_cmd .. " → :Pickers " .. name .. " files", "?")
  end

  if vim.fn.exists(":" .. grep_cmd) ~= 2 then
    usercmd(grep_cmd, function(_)
      require("pickers.command").handle({ fargs = { name, "grep" } })
    end, "[pickers coll] :" .. grep_cmd .. " → :Pickers " .. name .. " grep", "?")
  end

  -- Optional keymaps from coll.keys
  if type(coll.keys) == "table" then
    if coll.keys.files then
      map(coll.keys.files, function()
        require("pickers.command").handle({ fargs = { name, "files" } })
      end, "[pickers] " .. name .. ": find files")
    end
    if coll.keys.grep then
      map(coll.keys.grep, function()
        require("pickers.command").handle({ fargs = { name, "grep" } })
      end, "[pickers] " .. name .. ": live grep")
    end
  end
end

-- ── Entry point ───────────────────────────────────────────────────────────────

---@param cfg Pickers.Config
function M.setup(cfg)
  if cfg.keymaps and cfg.keymaps.enable then
    M._register_keymaps(cfg.keymaps)
  end
  if cfg.usercmds and cfg.usercmds.enable then
    M._register_usercmds()
  end
  for _, coll in ipairs(cfg.collections or {}) do
    M._register_collection_bindings(coll)
  end
end

return M
