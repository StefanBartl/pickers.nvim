---@module 'pickers.selected_index'
---@brief Overlay showing the index of the currently selected entry in a
---Telescope results buffer. Telescope-only; disabled by default (see
---`Pickers.SelectedIndexConfig` in `pickers.config`).
---@see pickers.selected_index.compute
---@see pickers.selected_index.highlight

local M = {}

local _ns_by_bufnr = {}
local _ns_counter = 0
local _cleanup_by_bufnr = {}
local _visible_by_bufnr = {}

---Get or create the extmark namespace for a specific results buffer.
---@param results_bufnr integer
---@return integer
local function get_or_create_namespace(results_bufnr)
  local existing_ns = _ns_by_bufnr[results_bufnr]
  if existing_ns then return existing_ns end

  _ns_counter = _ns_counter + 1
  local ns = vim.api.nvim_create_namespace("pickers_selected_index_" .. tostring(_ns_counter))
  _ns_by_bufnr[results_bufnr] = ns
  return ns
end

---Clear extmarks and cancel timers for a results buffer.
---@param results_bufnr integer
local function cleanup_namespace(results_bufnr)
  local ns = _ns_by_bufnr[results_bufnr]
  if ns and vim.api.nvim_buf_is_valid(results_bufnr) then
    pcall(vim.api.nvim_buf_clear_namespace, results_bufnr, ns, 0, -1)
  end
  _ns_by_bufnr[results_bufnr] = nil
  _visible_by_bufnr[results_bufnr] = nil

  local cleanup_fn = _cleanup_by_bufnr[results_bufnr]
  if cleanup_fn then
    cleanup_fn()
    _cleanup_by_bufnr[results_bufnr] = nil
  end
end

---Build the zero-argument function that (re)renders the index overlay.
---@param action_state table
---@param ns integer
---@param get_picker fun():table|nil
---@return fun():nil
local function make_update_selected_index(action_state, ns, get_picker)
  local compute = require("pickers.selected_index.compute")

  return function()
    local ok_ent, entry = pcall(function()
      return action_state.get_selected_entry()
    end)

    local picker = get_picker()
    if not picker then return end

    local results_bufnr = picker.results_bufnr
      or (picker.manager and picker.manager.results_bufnr)
      or picker._results_bufnr
    if not results_bufnr or results_bufnr == 0 then return end

    vim.api.nvim_buf_clear_namespace(results_bufnr, ns, 0, -1)

    if _visible_by_bufnr[results_bufnr] == false then return end

    local row = nil
    if type(picker.get_selection_row) == "function" then
      local r = picker.get_selection_row(picker)
      if type(r) == "number" then row = r end
    end
    if not row then
      local win = picker.results_win()
      if win and win ~= 0 then
        local ok_cur, cur = pcall(vim.api.nvim_win_get_cursor, win)
        if ok_cur and type(cur) == "table" then row = cur[1] - 1 end
      end
    end
    if not row then row = 0 end

    local index
    if ok_ent and type(entry) == "table" and type(entry.index) == "number" then
      index = entry.index
    else
      index = compute.compute_index_from_picker(picker, row)
    end

    if not (index and index > 0) then return end

    local cfg = require("pickers.config").get().selected_index
    local pos = cfg.position or "right_align"

    if pos == "overlay" or pos == "right_align" or pos == "eol" then
      require("pickers.selected_index.display.virt_text")(results_bufnr, ns, row, index, pos)
      return
    end

    if pos == "top" or pos == "down" then
      require("pickers.selected_index.display.virt_lines")(results_bufnr, ns, row, index, pos)
      return
    end

    require("pickers.selected_index.display.virt_text")(
      results_bufnr,
      ns,
      row,
      index,
      "right_align"
    )
  end
end

---Attach the selected-index overlay to a picker. Call from `attach_mappings`.
---@param prompt_bufnr integer
---@param map function
---@return boolean
function M.attach_mappings(prompt_bufnr, map)
  local action_state = require("telescope.actions.state")

  local function get_picker()
    local ok, p = pcall(action_state.get_current_picker, prompt_bufnr)
    if ok then return p end
    return nil
  end

  local picker = get_picker()
  if not picker or not picker.results_bufnr or picker.results_bufnr == 0 then return true end

  local results_bufnr = picker.results_bufnr
  local ns = get_or_create_namespace(results_bufnr)
  local cfg = require("pickers.config").get().selected_index

  _visible_by_bufnr[results_bufnr] = cfg.enabled

  local update_selected_index = make_update_selected_index(action_state, ns, get_picker)

  vim.schedule(function()
    vim.defer_fn(update_selected_index, 50)
  end)

  local si_actions = require("pickers.selected_index.actions")
  si_actions.attach(map, update_selected_index)

  if cfg.toggle_key then
    si_actions.attach_toggle(map, cfg.toggle_key, function()
      _visible_by_bufnr[results_bufnr] = not _visible_by_bufnr[results_bufnr]
      update_selected_index()
    end)
  end

  local augname = "PickersSelectedIndexAUG_" .. tostring(results_bufnr)
  local aug = vim.api.nvim_create_augroup(augname, { clear = true })
  local debounce = require("pickers.selected_index.debounce")
  local debounced_update, cleanup_debounce = debounce.debounce(update_selected_index, 30)

  _cleanup_by_bufnr[results_bufnr] = cleanup_debounce

  vim.api.nvim_create_autocmd({ "CursorMoved" }, {
    group = aug,
    buffer = results_bufnr,
    callback = debounced_update,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    buffer = results_bufnr,
    once = true,
    callback = function()
      cleanup_namespace(results_bufnr)
    end,
  })

  return true
end

---Wrap an existing `attach_mappings` function so it also renders the
---selected-index overlay, when the feature is enabled or a `toggle_key` is
---configured (so it can be switched on live for an already-open picker).
---Returns `orig` unchanged (including nil) when neither applies, keeping
---`enabled = false` with no `toggle_key` fully inert.
---@param orig (fun(prompt_bufnr:integer, map:function):boolean|nil)|nil
---@return (fun(prompt_bufnr:integer, map:function):boolean|nil)|nil
function M.wrap_attach_mappings(orig)
  local cfg = require("pickers.config").get().selected_index
  -- Defensive: a config without `selected_index` (e.g. a stale vim.loader cache
  -- of an older DEFAULTS, or a partial config) must never crash the picker.
  if not cfg or (not cfg.enabled and not cfg.toggle_key) then return orig end

  return function(prompt_bufnr, map)
    if orig then orig(prompt_bufnr, map) end
    return M.attach_mappings(prompt_bufnr, map)
  end
end

return M
