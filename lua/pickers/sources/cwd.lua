---@module 'pickers.sources.cwd'
---@brief Source: current working directory (sync).

local M = {}

---@param _cfg Pickers.Config
---@param callback fun(Pickers.Source|nil)
function M.get(_cfg, callback)
  local root = vim.fs.normalize(vim.uv.cwd() or vim.fn.getcwd())
  callback({ roots = { root }, prompt = "CWD> " })
end

return M
