---@module 'pickers.config'
---@brief Manages the active configuration; merges user options into defaults.
---@see pickers.config.DEFAULTS

local M = {}

local _cfg = nil ---@type Pickers.Config|nil

---Return the active configuration, initialising from defaults on first call.
---@return Pickers.Config
function M.get()
  if _cfg then return _cfg end
  _cfg = vim.deepcopy(require("pickers.config.DEFAULTS"))
  return _cfg
end

---Validate and normalise a single collection entry.
---Returns nil if the entry is invalid.
---@param raw table
---@return Pickers.Collection|nil
local function normalise_collection(raw)
  if type(raw) ~= "table" then return nil end
  if type(raw.name) ~= "string" or raw.name == "" then return nil end
  if type(raw.dir) ~= "string" or raw.dir == "" then return nil end
  return {
    name = raw.name,
    dir = raw.dir,
    prefix = (type(raw.prefix) == "string") and raw.prefix or nil,
    keys = (type(raw.keys) == "table") and raw.keys or nil,
    only_git = raw.only_git == true,
  }
end

---Validate and normalise the `selected_index` sub-config, merging into `current`.
---@param raw table
---@param current Pickers.SelectedIndexConfig
---@return Pickers.SelectedIndexConfig
local function normalise_selected_index(raw, current)
  local result = vim.deepcopy(current)

  if type(raw.enabled) == "boolean" then result.enabled = raw.enabled end

  if type(raw.position) == "string" then
    local allowed = {
      overlay = true,
      right_align = true,
      eol = true,
      top = true,
      down = true,
    }
    local pos = raw.position == "right" and "right_align" or raw.position
    if allowed[pos] then
      result.position = pos
    else
      vim.notify(
        string.format(
          "[pickers] Invalid selected_index.position %q, keeping %q",
          raw.position,
          result.position
        ),
        vim.log.levels.WARN
      )
    end
  end

  if type(raw.highlight) == "table" then
    local hl = { preset = result.highlight.preset }
    local valid_presets = {
      default = true,
      subtle = true,
      bold = true,
      accent = true,
      minimal = true,
      error = true,
      success = true,
      custom = true,
    }

    if raw.highlight.preset ~= nil then
      if valid_presets[raw.highlight.preset] then
        hl.preset = raw.highlight.preset
      else
        vim.notify(
          string.format(
            '[pickers] Invalid selected_index.highlight.preset %q, using "default"',
            tostring(raw.highlight.preset)
          ),
          vim.log.levels.WARN
        )
        hl.preset = "default"
      end
    end

    if type(raw.highlight.custom) == "table" then
      hl.custom = {}
      local valid_attrs =
        { "fg", "bg", "bold", "italic", "underline", "undercurl", "strikethrough", "blend" }
      for _, attr in ipairs(valid_attrs) do
        if raw.highlight.custom[attr] ~= nil then hl.custom[attr] = raw.highlight.custom[attr] end
      end
    end

    result.highlight = hl
  end

  if raw.toggle_key ~= nil then
    if type(raw.toggle_key) == "string" and raw.toggle_key ~= "" then
      result.toggle_key = raw.toggle_key
    elseif raw.toggle_key == false then
      result.toggle_key = nil
    else
      vim.notify(
        string.format(
          "[pickers] Invalid selected_index.toggle_key %s, keeping previous",
          vim.inspect(raw.toggle_key)
        ),
        vim.log.levels.WARN
      )
    end
  end

  return result
end

---Merge user-provided options into the active configuration.
---@param opts Pickers.Config|nil
function M.apply(opts)
  local cfg = M.get()
  if type(opts) ~= "table" then return end

  if type(opts.engine) == "string" then cfg.engine = opts.engine end
  if type(opts.repos_dir) == "string" then cfg.repos_dir = opts.repos_dir end

  if type(opts.collections) == "table" then
    cfg.collections = {}
    for _, raw in ipairs(opts.collections) do
      local coll = normalise_collection(raw)
      if coll then
        cfg.collections[#cfg.collections + 1] = coll
      else
        vim.notify(
          string.format(
            "[pickers] Invalid collection entry (name+dir required): %s",
            vim.inspect(raw)
          ),
          vim.log.levels.WARN
        )
      end
    end
  end

  if type(opts.depth_aliases) == "table" then
    for k, v in pairs(opts.depth_aliases) do
      if type(k) == "string" and type(v) == "function" then cfg.depth_aliases[k] = v end
    end
  end

  if type(opts.find) == "table" then
    cfg.find = vim.tbl_deep_extend("force", cfg.find, opts.find)
  end

  if type(opts.keymaps) == "table" then
    cfg.keymaps = vim.tbl_deep_extend("force", cfg.keymaps, opts.keymaps)
  end
  if type(opts.usercmds) == "table" then
    cfg.usercmds = vim.tbl_deep_extend("force", cfg.usercmds, opts.usercmds)
  end

  if type(opts.selected_index) == "table" then
    cfg.selected_index = normalise_selected_index(opts.selected_index, cfg.selected_index)
    require("pickers.selected_index.highlight").apply(cfg.selected_index.highlight)
  end
end

return M
