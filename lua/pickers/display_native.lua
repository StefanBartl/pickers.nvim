---@module 'pickers.display_native'
---@brief Apply the cosmetic `display.*` switches to the engines' global config.
---@description
--- Opt-in switches, each `nil` (the engine's own default stays) until the host
--- sets a value. Patched onto every engine once it is loaded (one call per
--- engine, see `pickers.engines.patcher`), so they hold for native pickers
--- (`:FzfLua files`, `:Telescope find_files`, ...) as well as pickers.nvim's own:
---
---   cycle         wrap around at either end of the result list
---                   telescope `scroll_strategy` = "cycle"/"limit"
---                   fzf-lua   `fzf_opts["--cycle"]`
---                   snacks    already cycles by default -- untouched
---   prompt_top    prompt above the results (true) or below (false)
---                   telescope `sorting_strategy` + `layout_config.prompt_position`
---                   fzf-lua   `fzf_opts["--layout"]` = "reverse"/"default"
---                   snacks    layout-dependent -- untouched
---   path_adaptive shorten long paths to the picker's width (lib.nvim's
---                 `fs.path_shorten`), instead of telescope's fixed "shorten"
---                   telescope `path_display` (a function reading `winwidth`)
---                   fzf-lua   no equivalent (only a numeric `path_shorten`)
---                   snacks    truncates to the column width by itself
---   preview_wrap  wrap long lines in the preview
---                   fzf-lua   `winopts.preview.wrap`
---                   snacks    `win.preview.wo.wrap`
---                   telescope no option: its buffer previewer always turns
---                             wrap off -- untouched
---
--- A switch set here is explicit, so it wins over the same option in the
--- host's own engine config. Unset switches touch nothing.

local M = {}

---@param display Pickers.DisplayConfig
---@return boolean
local function any_set(display)
  return type(display.cycle) == "boolean"
    or type(display.prompt_top) == "boolean"
    or type(display.preview_wrap) == "boolean"
    or display.path_adaptive == true
end

---@param display Pickers.DisplayConfig
---@return fun(current: table): table|nil
local function telescope(display)
  return function(current)
    local defaults = {}
    if type(display.cycle) == "boolean" then
      defaults.scroll_strategy = display.cycle and "cycle" or "limit"
    end
    if type(display.prompt_top) == "boolean" then
      defaults.sorting_strategy = display.prompt_top and "ascending" or "descending"
      defaults.layout_config = vim.tbl_deep_extend(
        "force",
        (current.defaults or {}).layout_config or {},
        { prompt_position = display.prompt_top and "top" or "bottom" }
      )
    end
    if display.path_adaptive == true then
      local ok, shorten = pcall(require, "lib.nvim.fs.path_shorten")
      if ok then
        defaults.path_display = function(picker_opts, path)
          local width = type(picker_opts) == "table" and picker_opts.winwidth
          local max_len = type(width) == "number" and math.max(10, width - 10) or 60
          return shorten(path, max_len)
        end
      end
    end
    if next(defaults) then return { defaults = defaults } end
  end
end

---@param display Pickers.DisplayConfig
---@return fun(current: table): table|nil
local function fzf(display)
  return function()
    local opts, fzf_opts = {}, {}
    -- `false` (not nil) so a `--cycle` the host set earlier is switched off too.
    if type(display.cycle) == "boolean" then fzf_opts["--cycle"] = display.cycle end
    if type(display.prompt_top) == "boolean" then
      fzf_opts["--layout"] = display.prompt_top and "reverse" or "default"
    end
    if next(fzf_opts) then opts.fzf_opts = fzf_opts end
    if type(display.preview_wrap) == "boolean" then
      opts.winopts = { preview = { wrap = display.preview_wrap } }
    end
    if next(opts) then return opts end
  end
end

---@param display Pickers.DisplayConfig
---@return fun(current: table): table|nil
local function snacks(display)
  if type(display.preview_wrap) ~= "boolean" then return nil end
  -- The patcher deep-merges this over the host's own snacks config with
  -- "force": an explicit display switch wins, like it does on telescope/fzf-lua.
  return function()
    return { win = { preview = { wo = { wrap = display.preview_wrap } } } }
  end
end

---Contributions for `pickers.engines.patcher`. Empty while no switch is set.
---@param cfg Pickers.Config|nil
---@return table<string, fun(current: table): table|nil>
function M.contribute(cfg)
  cfg = cfg or require("pickers.config").get()
  local display = cfg.display or {}
  if not any_set(display) then return {} end
  return { telescope = telescope(display), ["fzf-lua"] = fzf(display), snacks = snacks(display) }
end

---Patch on its own (a host that wants only this). `bindings.setup` installs
---every contributor together instead.
---@param cfg Pickers.Config|nil
function M.patch(cfg)
  require("pickers.engines.patcher").install(cfg, { "pickers.display_native" })
end

return M
