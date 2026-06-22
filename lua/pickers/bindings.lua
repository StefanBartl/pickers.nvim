---@module 'pickers.bindings'
---@brief ALL keymaps and compat user-commands in one thematically organised file.
---@description
--- Keymaps registered when keymaps.enable = true:
---   <leader>dp   Dir navigation picker          (was custom.dir_picker)
---   <leader>fb   Find files in picked folder    (was custom.find_in_folder)
---   <leader>fc   Find files in nvim config      (was custom.find_config)
---   <leader>gc   Grep in nvim config            (was custom.find_config)
---   <leader>li   Live grep in CWD               (was custom.grep)
---   (cwd_files)  Find files in CWD              (nil by default)
---
--- Compat user-commands registered when usercmds.enable = true:
---   :DirPicker [nav]          → :Pickers dir [nav]
---   :FindInFolder             → :Pickers folder files
---   :FindConfig               → :Pickers config files
---   :GrepConfig               → :Pickers config grep
---   :LiveGrep                 → :Pickers cwd grep
---   :AllDrives                → :Pickers drives files
---   :AllDrivesGrep            → :Pickers drives grep
---   :FindOnSystem             → :Pickers system files
---   :RepoFiles                → :Pickers repos files
---   :RepoGrep                 → :Pickers repos grep
---   :WkdBookFiles             → :Pickers wkdbooks files
---   :WkdBookGrep              → :Pickers wkdbooks grep

local M = {}

-- ── Keymaps ───────────────────────────────────────────────────────────────────

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

---@param km Pickers.Keymaps
function M._register_keymaps(km)
  -- ── Dir navigation (preserved: <leader>dp) ────────────────────────────────
  map(km.dir_pick, function()
    require("pickers.command").handle({ fargs = { "dir" } })
  end, "[pickers] Dir: navigate (alias / depth / path)")

  -- ── Folder fuzzy find (preserved: <leader>fb) ─────────────────────────────
  map(km.folder_files, function()
    require("pickers.command").handle({ fargs = { "folder", "files" } })
  end, "[pickers] Find files in interactively picked folder")

  -- ── Config pickers (preserved: <leader>fc / <leader>gc) ──────────────────
  map(km.config_files, function()
    require("pickers.command").handle({ fargs = { "config", "files" } })
  end, "[pickers] Find files in nvim config")

  map(km.config_grep, function()
    require("pickers.command").handle({ fargs = { "config", "grep" } })
  end, "[pickers] Grep in nvim config")

  -- ── CWD pickers (grep preserved: <leader>li; files optional) ─────────────
  map(km.cwd_grep, function()
    require("pickers.command").handle({ fargs = { "cwd", "grep" } })
  end, "[pickers] Live grep in CWD")

  map(km.cwd_files, function()
    require("pickers.command").handle({ fargs = { "cwd", "files" } })
  end, "[pickers] Find files in CWD")
end

-- ── User commands ─────────────────────────────────────────────────────────────

---Create a user command with consistent defaults.
---@param name  string
---@param fn    fun(opts: table)
---@param desc  string
---@param nargs string|nil  default "*"
local function usercmd(name, fn, desc, nargs)
  vim.api.nvim_create_user_command(name, fn, {
    desc  = desc,
    nargs = nargs or "*",
  })
end

function M._register_usercmds()
  -- ── Dir picker compat ──────────────────────────────────────────────────────
  usercmd("DirPicker", function(opts)
    local fargs = { "dir" }
    for _, a in ipairs(opts.fargs) do fargs[#fargs + 1] = a end
    require("pickers.command").handle({ fargs = fargs })
  end, "[pickers compat] :DirPicker [nav] → :Pickers dir [nav]", "*")

  -- ── Config pickers compat ──────────────────────────────────────────────────
  usercmd("FindConfig", function(_)
    require("pickers.command").handle({ fargs = { "config", "files" } })
  end, "[pickers compat] :FindConfig → :Pickers config files", "?")

  usercmd("GrepConfig", function(_)
    require("pickers.command").handle({ fargs = { "config", "grep" } })
  end, "[pickers compat] :GrepConfig → :Pickers config grep", "?")

  -- ── Folder / find-in-folder compat ────────────────────────────────────────
  usercmd("FindInFolder", function(_)
    -- Path arg from legacy usage is ignored; interactive dir picker is shown instead.
    require("pickers.command").handle({ fargs = { "folder", "files" } })
  end, "[pickers compat] :FindInFolder → :Pickers folder files", "*")

  -- ── Live grep compat ───────────────────────────────────────────────────────
  usercmd("LiveGrep", function(_)
    require("pickers.command").handle({ fargs = { "cwd", "grep" } })
  end, "[pickers compat] :LiveGrep → :Pickers cwd grep", "?")

  -- ── All drives compat ──────────────────────────────────────────────────────
  usercmd("AllDrives", function(_)
    require("pickers.command").handle({ fargs = { "drives", "files" } })
  end, "[pickers compat] :AllDrives → :Pickers drives files", "?")

  usercmd("AllDrivesGrep", function(_)
    require("pickers.command").handle({ fargs = { "drives", "grep" } })
  end, "[pickers compat] :AllDrivesGrep → :Pickers drives grep", "?")

  -- ── System find compat ─────────────────────────────────────────────────────
  usercmd("FindOnSystem", function(_)
    require("pickers.command").handle({ fargs = { "system", "files" } })
  end, "[pickers compat] :FindOnSystem → :Pickers system files", "?")

  -- ── Repo pickers ───────────────────────────────────────────────────────────
  usercmd("RepoFiles", function(_)
    require("pickers.command").handle({ fargs = { "repos", "files" } })
  end, "[pickers] :RepoFiles — pick repo, then find files", "?")

  usercmd("RepoGrep", function(_)
    require("pickers.command").handle({ fargs = { "repos", "grep" } })
  end, "[pickers] :RepoGrep — pick repo, then live grep", "?")

  -- ── WkdBook pickers ────────────────────────────────────────────────────────
  usercmd("WkdBookFiles", function(_)
    require("pickers.command").handle({ fargs = { "wkdbooks", "files" } })
  end, "[pickers] :WkdBookFiles — pick wkdbook, then find files", "?")

  usercmd("WkdBookGrep", function(_)
    require("pickers.command").handle({ fargs = { "wkdbooks", "grep" } })
  end, "[pickers] :WkdBookGrep — pick wkdbook, then live grep", "?")
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
end

return M
