---@module 'pickers.entry_actions.system'
---@brief Engine-agnostic "hand the selected entry to the OS" actions: open it
---with its default application, or reveal it in the system file manager.
---@description
--- Mirrors filetree.nvim's `system.open_with` (`<leader>sm`) and
--- `system.open_in_fm` (`<leader>fm`) on a picker RESULT ROW. Both platform
--- dispatches live in lib.nvim (`cross.open_default`, `cross.reveal_in_fm`),
--- shared with filetree.nvim and open.nvim, so a fix there lands everywhere.
---
---   open     -> the application registered for the file's extension
---   reveal   -> the file selected in its parent directory (Explorer/Finder/…)
---
--- Only the first entry is used: launching an application per marked entry is
--- a surprise nobody asked for. Neither action closes the picker.

local notify = require("lib.nvim.notify").create("[pickers.entry_actions.system]")

local M = {}

---system action name -> `pickers.keys` action name, shared by the engine
---adapters.
---@type table<string, string>
M.ACTION_FOR = {
  open = "open_system",
  reveal = "reveal_in_manager",
}

---Launcher per action: `(abs_path) -> ok, err`.
---@type table<string, fun(path: string): boolean, string|nil>
M.LAUNCHERS = {
  open = function(path)
    return require("lib.nvim.cross.open_default")(path)
  end,
  reveal = function(path)
    return require("lib.nvim.cross.reveal_in_fm")(path, { reveal = true })
  end,
}

---@param action "open"|"reveal"
---@param path string|nil
---@return boolean ok
function M.run(action, path)
  local launch = M.LAUNCHERS[action]
  if not launch then
    notify.warn("Unknown system action: " .. tostring(action))
    return false
  end
  if not path or path == "" then
    notify.warn("No valid path found")
    return false
  end

  local abs = vim.fn.fnamemodify(path, ":p")
  local ok, err = launch(abs)
  if not ok then
    notify.warn(string.format("Could not %s %s: %s", action, abs, tostring(err)))
    return false
  end
  return true
end

return M
