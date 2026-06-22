---@module 'pickers.config'
---@brief Manages the active configuration; merges user options into defaults.
---@see pickers.config.defaults

local M = {}

-- Module-local state — never exposed as global
local _cfg = nil  ---@type Pickers.Config|nil

---Return the active configuration, initialising from defaults on first call.
---@return Pickers.Config
function M.get()
  if _cfg then return _cfg end

  _cfg = vim.deepcopy(require("pickers.config.defaults"))

  -- Lazily compute wkdbooks_dir when not explicitly set
  if not _cfg.wkdbooks_dir and _cfg.repos_dir then
    _cfg.wkdbooks_dir = _cfg.repos_dir .. "/WKDBooks"
  end

  return _cfg
end

---Merge user-provided options into the active configuration.
---Only known top-level keys are accepted; unknown keys are ignored silently.
---@param opts Pickers.Config|nil
---@return nil
function M.apply(opts)
  local cfg = M.get()
  if type(opts) ~= "table" then return end

  if type(opts.engine) == "string" then
    cfg.engine = opts.engine
  end
  if type(opts.repos_dir) == "string" then
    cfg.repos_dir = opts.repos_dir
    -- Re-derive wkdbooks_dir unless the user also supplied it
    if not opts.wkdbooks_dir then
      cfg.wkdbooks_dir = opts.repos_dir .. "/WKDBooks"
    end
  end
  if type(opts.wkdbooks_dir) == "string" then
    cfg.wkdbooks_dir = opts.wkdbooks_dir
  end
  if type(opts.wkdbook_prefix) == "string" then
    cfg.wkdbook_prefix = opts.wkdbook_prefix
  end

  -- Merge alias table: only string-key → function entries accepted
  if type(opts.depth_aliases) == "table" then
    for k, v in pairs(opts.depth_aliases) do
      if type(k) == "string" and type(v) == "function" then
        cfg.depth_aliases[k] = v
      end
    end
  end

  if type(opts.keymaps) == "table" then
    cfg.keymaps = vim.tbl_deep_extend("force", cfg.keymaps, opts.keymaps)
  end
  if type(opts.usercmds) == "table" then
    cfg.usercmds = vim.tbl_deep_extend("force", cfg.usercmds, opts.usercmds)
  end
end

return M
