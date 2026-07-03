---@module 'pickers.sources.folder'
---@brief Source: interactively picked folder (async — opens engine dir-picker).

local notify = require("lib.nvim.notify").create("[pickers.sources.folder]")

local M = {}

---@param _cfg  Pickers.Config
---@param callback fun(Pickers.Source|nil)
---@param engine_mod table   Engine module providing pick_dir()
function M.get(_cfg, callback, engine_mod)
  if type(engine_mod) ~= "table" or type(engine_mod.pick_dir) ~= "function" then
    notify.error("Active engine does not support directory picking")
    callback(nil)
    return
  end

  engine_mod.pick_dir({
    prompt = "Folder> ",
    on_select = function(dir)
      if not dir or dir == "" then
        callback(nil)
        return
      end

      local path = vim.fs.normalize(dir)

      if vim.fn.isdirectory(path) == 0 then
        notify.error("Not a valid directory: " .. path)
        callback(nil)
        return
      end

      local name = vim.fn.fnamemodify(path, ":t")
      callback({
        roots = { path },
        prompt = (name ~= "" and name or path) .. "> ",
      })
    end,
  })
end

return M
