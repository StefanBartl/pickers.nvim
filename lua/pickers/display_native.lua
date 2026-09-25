---@module 'pickers.display_native'
---@brief Apply the cosmetic `display.*` switches to the engines' global config.
---@description
--- Three opt-in switches, each `nil` (the engine's own default stays) until the
--- host sets a boolean. Patched onto every engine once it is loaded
--- (`pickers.engines.when_loaded`), so they hold for native pickers
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
end

---@param display Pickers.DisplayConfig
local function telescope(display)
  if not pcall(require, "telescope") then return end
  pcall(function()
    local values = require("telescope.config").values or {}
    local defaults = {}
    if type(display.cycle) == "boolean" then
      defaults.scroll_strategy = display.cycle and "cycle" or "limit"
    end
    if type(display.prompt_top) == "boolean" then
      defaults.sorting_strategy = display.prompt_top and "ascending" or "descending"
      defaults.layout_config = vim.tbl_deep_extend("force", values.layout_config or {}, {
        prompt_position = display.prompt_top and "top" or "bottom",
      })
    end
    if next(defaults) then require("telescope").setup({ defaults = defaults }) end
  end)
end

---@param display Pickers.DisplayConfig
local function fzf(display)
  local ok, fzf_lua = pcall(require, "fzf-lua")
  if not ok then return end
  pcall(function()
    local opts = {}
    local fzf_opts = {}
    if type(display.cycle) == "boolean" then fzf_opts["--cycle"] = display.cycle or nil end
    if type(display.prompt_top) == "boolean" then
      fzf_opts["--layout"] = display.prompt_top and "reverse" or "default"
    end
    if next(fzf_opts) then opts.fzf_opts = fzf_opts end
    if type(display.preview_wrap) == "boolean" then
      opts.winopts = { preview = { wrap = display.preview_wrap } }
    end
    if next(opts) then fzf_lua.setup(opts, true) end
  end)
end

---@param display Pickers.DisplayConfig
local function snacks(display)
  if type(display.preview_wrap) ~= "boolean" then return end
  local ok, Snacks = pcall(require, "snacks")
  if not ok then return end
  pcall(function()
    Snacks.config.picker = vim.tbl_deep_extend("keep", Snacks.config.picker or {}, {
      win = { preview = { wo = { wrap = display.preview_wrap } } },
    })
  end)
end

---@param cfg Pickers.Config|nil
function M.patch(cfg)
  cfg = cfg or require("pickers.config").get()
  local display = cfg.display or {}
  if not any_set(display) then return end

  local when_loaded = require("pickers.engines.when_loaded")
  when_loaded.run("telescope", function()
    telescope(display)
  end)
  when_loaded.run("fzf-lua", function()
    fzf(display)
  end)
  when_loaded.run("snacks", function()
    snacks(display)
  end)
end

return M
