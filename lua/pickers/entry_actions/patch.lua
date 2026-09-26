---@module 'pickers.entry_actions.patch'
---@brief Install the entry actions (create_file, open_background, cheatsheet,
---path_copy) and the snacks in-picker keys onto each engine's global config.
---@description
--- Until now these were an export the host merged into its own engine
--- `setup()` by hand (`adapters.*.get_*()`), which made every config carry a
--- glue module per engine. This does the merge itself, the same way
--- `pickers.keys.patch` already does for the built-in actions -- each engine
--- patched once it is loaded, in one call per engine (`pickers.engines.patcher`),
--- so nothing is forced to load early.
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

---Host entries first: what the host already bound is kept, ours fills the gaps.
---@param current table|nil
---@param ours table
---@return table
local function fold(current, ours)
  return vim.tbl_extend("keep", current or {}, ours)
end

---@return fun(current: table): table|nil
local function telescope()
  return function(current)
    local mappings = (current.defaults or {}).mappings or {}
    local ours = require("pickers.entry_actions.adapters.telescope").get_mappings()
    return {
      defaults = { mappings = { i = fold(mappings.i, ours.i), n = fold(mappings.n, ours.n) } },
    }
  end
end

---@return fun(current: table): table|nil
local function fzf()
  return function(current)
    local ours = require("pickers.entry_actions.adapters.fzf").get_actions()
    if vim.tbl_isempty(ours) then return nil end
    -- fzf-lua keys its global actions per provider: `actions.files` is the
    -- table the files/grep/buffers/... pickers inherit from. A flat
    -- `actions = { ["ctrl-a"] = ... }` is not read by any of them.
    --
    -- A user-supplied `actions.files` REPLACES fzf-lua's defaults rather than
    -- merging into them, so start from what is in force: the host's own table
    -- if it set one, otherwise fzf-lua's defaults (enter, ctrl-s/v/t, alt-q...).
    local files = ((current.setup_opts or {}).actions or {}).files
    if type(files) ~= "table" then
      local ok, defaults = pcall(require, "fzf-lua.defaults")
      files = ok and vim.deepcopy(defaults.defaults.actions.files) or {}
    end
    return { actions = { files = fold(files, ours) } }
  end
end

---@param cfg Pickers.Config
---@return fun(current: table): table|nil
local function snacks(cfg)
  return function(current)
    local keys = require("pickers.keys")
    local ea = require("pickers.entry_actions.adapters.snacks")
    local win = keys.snacks_win(cfg)
    local picker = current.picker or {}
    local cur_win = picker.win or {}

    -- Only the subtrees touched here are returned (`actions`, `win.*.keys`),
    -- each with the host's own entries first -- never the whole picker table,
    -- so this cannot overwrite what another contribution sets next to it.
    return {
      actions = fold(
        picker.actions,
        vim.tbl_extend("force", keys.snacks_actions(), ea.get_actions())
      ),
      win = {
        -- entry_actions bind on BOTH windows: a picker opens with focus in
        -- the input prompt, so a list-only binding would be unreachable.
        input = {
          keys = fold(
            (cur_win.input or {}).keys,
            vim.tbl_extend("force", win.input.keys, ea.get_input_keys())
          ),
        },
        list = {
          keys = fold(
            (cur_win.list or {}).keys,
            vim.tbl_extend("force", win.list.keys, ea.get_keys())
          ),
        },
        preview = { keys = fold((cur_win.preview or {}).keys, win.preview.keys) },
      },
    }
  end
end

---Contributions for `pickers.engines.patcher`. Empty when `keys.enable` is
---false.
---@param cfg Pickers.Config|nil
---@return table<string, fun(current: table): table|nil>
function M.contribute(cfg)
  cfg = cfg or require("pickers.config").get()
  if cfg.keys and cfg.keys.enable == false then return {} end
  return { telescope = telescope(), ["fzf-lua"] = fzf(), snacks = snacks(cfg) }
end

---Patch on its own (a host that wants only this). `bindings.setup` installs
---every contributor together instead.
---@param cfg Pickers.Config|nil
function M.patch(cfg)
  require("pickers.engines.patcher").install(cfg, { "pickers.entry_actions.patch" })
end

return M
