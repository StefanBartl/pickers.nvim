---@module 'pickers.engines.report'
---@brief What every engine's `pick_files` does with `opts.on_select`: turn the
---picked entry into an absolute path and report it, without letting the caller's
---callback take the picker down.
---@description
--- Shared by the three engines so the rules are stated once:
---   * the path handed over is absolute and normalised, whichever way the engine
---     spells its entries (telescope: `entry.path` or a name relative to `cwd`;
---     fzf-lua: a decorated line resolved by `entry_to_file`; snacks: an item);
---   * the report is scheduled -- the engine's own default action has just run
---     (or is about to, for snacks confirmed from insert mode), and the caller
---     usually wants the file already open;
---   * the callback runs under `pcall`: an error in it is reported as a notification
---     instead of surfacing as a stack trace from inside the picker.

local notify = require("lib.nvim.notify").create("[pickers.engines]")

local M = {}

---Whether `path` is absolute (a POSIX root or a Windows drive / UNC root).
---@param path string
---@return boolean
function M.is_absolute(path)
  local first = path:sub(1, 1)
  return first == "/" or first == "\\" or path:match("^%a:[/\\]") ~= nil
end

---`path` as an absolute, normalised path; a relative one is taken against `root`
---(the nvim cwd when none is given).
---@param path string
---@param root string|nil
---@return string
function M.absolute(path, root)
  if not M.is_absolute(path) then path = (root or vim.uv.cwd()) .. "/" .. path end
  return vim.fs.normalize(path)
end

---Report `path` to `on_select`, scheduled and guarded.
---@param on_select fun(path: string)
---@param path string
function M.call(on_select, path)
  vim.schedule(function()
    local ok, err = pcall(on_select, path)
    if not ok then notify.error("on_select failed: " .. tostring(err)) end
  end)
end

return M
