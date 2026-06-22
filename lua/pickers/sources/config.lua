---@module 'pickers.sources.config'
---@brief Source: Neovim configuration directory (sync).

local M = {}

---@param _cfg Pickers.Config
---@param callback fun(Pickers.Source|nil)
function M.get(_cfg, callback)
  local root = vim.fs.normalize(tostring(vim.fn.stdpath("config")))
  callback({ roots = { root }, prompt = "Config> " })
end

return M
