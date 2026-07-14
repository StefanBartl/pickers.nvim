---@module 'pickers.entry_actions.create_file'
---@brief Engine-agnostic create-file/folder wrapper.
---@description
--- Shared core behind every picker's "create file/folder" entry action:
--- notify + vim.ui.input prompt + lib.nvim.fs.create_entry, opening newly
--- created files in the current window. Picker-library specifics
--- (entry-path extraction, closing/deferring the picker) live in the
--- sibling extract/*.lua and adapters/*.lua modules — this module only
--- needs the already-extracted `path`.

local notify = require("lib.nvim.notify").create("[pickers.entry_actions.create_file]")
local create_entry_core = require("lib.nvim.fs.create_entry")

local fn = vim.fn

local M = {}

---Create file or directory, notify, and open newly created files.
---@param parent_dir string Parent directory path
---@param name string Name of file/folder to create
local function create_entry(parent_dir, name)
  local ok, kind, path_or_err = create_entry_core(parent_dir, name)
  if not ok then
    notify.error(path_or_err)
    return
  end

  if kind == "directory" then
    notify.info(("Directory created: %s"):format(fn.fnamemodify(path_or_err, ":t")))
  else
    notify.info(("File created: %s"):format(fn.fnamemodify(path_or_err, ":t")))
    vim.schedule(function()
      vim.cmd("edit " .. fn.fnameescape(path_or_err))
    end)
  end
end

---Resolve the parent directory to create in from a selected path (file or dir).
---@param path string
---@return string parent_dir
local function parent_dir_of(path)
  if fn.isdirectory(path) == 1 then
    return path
  end
  return fn.fnamemodify(path, ":h")
end

---Prompt for a name and create it inside `path`'s directory. Called by each
---engine adapter after it has already extracted `path` from the selected
---entry. Always schedules the `vim.ui.input` prompt (matching the previous
---per-picker behavior) so it appears after the current picker has finished
---closing; callers that need a longer delay (e.g. fzf-lua's terminal-buffer
---picker) should defer their own call to `M.run` on top of this.
---@param path string Selected entry's path (file or directory)
function M.run(path)
  if not path or path == "" then
    notify.warn("No valid path found")
    return
  end

  path = fn.fnamemodify(path, ":p")

  local parent_dir = parent_dir_of(path)
  if not parent_dir or parent_dir == "" then
    notify.error("Could not determine parent directory")
    return
  end

  vim.schedule(function()
    vim.ui.input({
      prompt = "Create in " .. fn.fnamemodify(parent_dir, ":~:.") .. " (/ for folder): ",
      default = "",
    }, function(input)
      if not input or input == "" then
        return
      end
      create_entry(parent_dir, input)
    end)
  end)
end

return M
