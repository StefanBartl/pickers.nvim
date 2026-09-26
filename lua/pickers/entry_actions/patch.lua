---@module 'pickers.entry_actions.patch'
---@brief Install the entry actions (create_file, open_background, cheatsheet,
---path_copy) and the snacks in-picker keys onto each engine's global config.
---@description
--- Until now these were an export the host merged into its own engine
--- `setup()` by hand (`adapters.*.get_*()`), which made every config carry a
--- glue module per engine. This does the merge itself, the same way
--- `pickers.keys.patch` already does for the built-in actions -- each engine
--- patched once it is loaded (`pickers.engines.when_loaded`), so nothing is
--- forced to load early.
---
--- The host's own configuration always wins on conflict: a key or action it
--- already bound is left alone, pickers.nvim only fills in what is missing.
---
---   telescope -> `defaults.mappings` (telescope replaces that table on a
---                second `setup()`, so the current one is folded in first)
--- fzf-lua   -> `actions.files`, the table every file-based picker inherits
---                (`setup(.., true)` keeps earlier options,
---                but on a conflict the NEW value would win -- so the
---                host's own actions are folded in first here too)
---   snacks    -> `Snacks.config.picker` (`actions` + `win` keys). Snacks
---                reads that table each time a picker opens, so patching it
---                after `Snacks.setup()` still takes effect.
---
--- The adapters' `get_*()` functions stay public for a host that prefers to
--- merge by hand.

local M = {}

local function telescope()
  local ok = pcall(require, "telescope")
  if not ok then return end
  pcall(function()
    local current = (require("telescope.config").values or {}).mappings or {}
    local ours = require("pickers.entry_actions.adapters.telescope").get_mappings()
    require("telescope").setup({
      defaults = {
        mappings = {
          i = vim.tbl_extend("keep", current.i or {}, ours.i),
          n = vim.tbl_extend("keep", current.n or {}, ours.n),
        },
      },
    })
  end)
end

local function fzf()
  local ok, fzf_lua = pcall(require, "fzf-lua")
  if not ok then return end
  pcall(function()
    local ours = require("pickers.entry_actions.adapters.fzf").get_actions()
    if vim.tbl_isempty(ours) then return end
    -- fzf-lua keys its global actions per provider: `actions.files` is the
    -- table the files/grep/buffers/... pickers inherit from. A flat
    -- `actions = { ["ctrl-a"] = ... }` is not read by any of them.
    -- A user-supplied `actions.files` REPLACES fzf-lua's defaults rather than
    -- merging into them, so start from what is in force: the host's own table
    -- if it set one, otherwise fzf-lua's defaults (enter, ctrl-s/v/t, alt-q...).
    local current = ((require("fzf-lua.config").setup_opts or {}).actions or {}).files
    if type(current) ~= "table" then
      current = vim.deepcopy(require("fzf-lua.defaults").defaults.actions.files)
    end
    fzf_lua.setup({ actions = { files = vim.tbl_extend("keep", current, ours) } }, true)
  end)
end

---@param cfg Pickers.Config
local function snacks(cfg)
  local ok, Snacks = pcall(require, "snacks")
  if not ok then return end
  pcall(function()
    local keys = require("pickers.keys")
    local ea = require("pickers.entry_actions.adapters.snacks")
    local win = keys.snacks_win(cfg)

    local ours = {
      actions = vim.tbl_extend("force", keys.snacks_actions(), ea.get_actions()),
      win = {
        -- entry_actions bind on BOTH windows: a picker opens with focus in
        -- the input prompt, so a list-only binding would be unreachable.
        input = { keys = vim.tbl_extend("force", win.input.keys, ea.get_input_keys()) },
        list = { keys = vim.tbl_extend("force", win.list.keys, ea.get_keys()) },
        preview = { keys = win.preview.keys },
      },
    }
    Snacks.config.picker = vim.tbl_deep_extend("keep", Snacks.config.picker or {}, ours)
  end)
end

---Patch every engine once it is loaded. No-op when `keys.enable == false`.
---@param cfg Pickers.Config|nil
function M.patch(cfg)
  cfg = cfg or require("pickers.config").get()
  if cfg.keys and cfg.keys.enable == false then return end

  local when_loaded = require("pickers.engines.when_loaded")
  when_loaded.run("telescope", telescope)
  when_loaded.run("fzf-lua", fzf)
  when_loaded.run("snacks", function()
    snacks(cfg)
  end)
end

return M
