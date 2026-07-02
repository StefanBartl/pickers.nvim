---@module 'docs.BINDINGS'
---@brief Single-source reference of every keymap, user-command and autocmd that
---       pickers.nvim registers. Kept as data (not prose) so it can double as a
---       cheatsheet source and be consumed programmatically (e.g. which-key).
---
--- This file is documentation only — it is NOT required by the runtime. The
--- authoritative registration lives in `lua/pickers/bindings/`. Keep both in
--- sync when adding or changing a binding.

---@class Bindings.Keymap
---@field default  string|nil  Default lhs (nil = registered but disabled by default)
---@field config   string      Key in `keymaps` used to override/disable it
---@field maps_to  string      The `:Pickers …` invocation it triggers
---@field desc     string      Human description

---@class Bindings.Usercmd
---@field name     string      Command name (without leading ':')
---@field maps_to  string      Equivalent `:Pickers …` invocation
---@field nargs    string      nvim_create_user_command nargs value
---@field desc     string      Human description

---@class Bindings.Autocmd
---@field event    string      Autocmd event
---@field source   string      File that registers it
---@field desc     string      What it does

return {
  -- ── Keymaps ────────────────────────────────────────────────────────────────
  -- Registered when `keymaps.enable = true`. Disable one by setting its config
  -- key to nil; disable all with `keymaps = { enable = false }`.
  keymaps = {
    { default = "<leader>dp", config = "dir_pick",     maps_to = ":Pickers dir",          desc = "Dir navigation picker (alias / depth / path)" },
    { default = "<leader>fb", config = "folder_files", maps_to = ":Pickers folder files", desc = "Find files in an interactively picked folder" },
    { default = "<leader>fc", config = "config_files", maps_to = ":Pickers config files", desc = "Find files in the Neovim config dir" },
    { default = "<leader>gc", config = "config_grep",  maps_to = ":Pickers config grep",  desc = "Live grep in the Neovim config dir" },
    { default = "<leader>li", config = "cwd_grep",     maps_to = ":Pickers cwd grep",     desc = "Live grep in the current working directory" },
    { default = nil,          config = "cwd_files",    maps_to = ":Pickers cwd files",    desc = "Find files in the current working directory (disabled by default)" },
  },

  -- ── User-commands ──────────────────────────────────────────────────────────
  -- `:Pickers` is always registered by plugin/pickers.lua. The compat commands
  -- below are registered when `usercmds.enable = true`.
  usercmds = {
    { name = "Pickers",       maps_to = ":Pickers [scope] [nav|action] [action]", nargs = "*", desc = "Unified entry point (always registered)" },
    { name = "DirPicker",     maps_to = ":Pickers dir [nav]",     nargs = "*", desc = "Dir navigation picker" },
    { name = "FindConfig",    maps_to = ":Pickers config files",  nargs = "?", desc = "Find files in nvim config" },
    { name = "GrepConfig",    maps_to = ":Pickers config grep",   nargs = "?", desc = "Live grep in nvim config" },
    { name = "FindInFolder",  maps_to = ":Pickers folder files",  nargs = "*", desc = "Pick a folder, then find files" },
    { name = "LiveGrep",      maps_to = ":Pickers cwd grep",      nargs = "?", desc = "Live grep in CWD" },
    { name = "AllDrives",     maps_to = ":Pickers drives files",  nargs = "?", desc = "Find files across all drives" },
    { name = "AllDrivesGrep", maps_to = ":Pickers drives grep",   nargs = "?", desc = "Live grep across all drives" },
    { name = "FindOnSystem",  maps_to = ":Pickers system files",  nargs = "?", desc = "Systemwide fd search (prompts)" },
    { name = "RepoFiles",     maps_to = ":Pickers repos files",   nargs = "?", desc = "Pick a repo, then find files" },
    { name = "RepoGrep",      maps_to = ":Pickers repos grep",    nargs = "?", desc = "Pick a repo, then live grep" },
    { name = "WkdBookFiles",  maps_to = ":Pickers wkdbooks files", nargs = "?", desc = "Pick a wkdbook, then find files" },
    { name = "WkdBookGrep",   maps_to = ":Pickers wkdbooks grep",  nargs = "?", desc = "Pick a wkdbook, then live grep" },
  },

  -- ── Collection-generated commands ──────────────────────────────────────────
  -- For every entry in `collections`, two compat commands are generated from the
  -- PascalCase collection name (e.g. name = "notes_lua"):
  --   :NotesLuaFiles → :Pickers notes_lua files
  --   :NotesLuaGrep  → :Pickers notes_lua grep
  -- Plus the optional `keys.files` / `keys.grep` keymaps if configured.
  collection_commands = {
    files = { pattern = ":{PascalName}Files", maps_to = ":Pickers {name} files" },
    grep  = { pattern = ":{PascalName}Grep",  maps_to = ":Pickers {name} grep" },
  },

  -- ── Autocmds ───────────────────────────────────────────────────────────────
  autocmds = {
    { event = "VimEnter", source = "plugin/pickers.lua", desc = "Register default keymaps/usercmds at startup when the user did not call setup() (guarded by vim.g.pickers_nvim_setup_called)" },
  },
}
