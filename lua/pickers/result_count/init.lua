---@module 'pickers.result_count'
---@brief Shows the live result count in the prompt window's title (e.g.
---"Find Files (128)"). Telescope-only, disabled by default -- fzf-lua and
---snacks.nvim both already show a position/total counter natively.
---@see Pickers.ResultCountConfig

local M = {}

---Poll the entry manager's result count and rewrite the prompt border title,
---until the results buffer is gone. Polling (not an autocmd) because result
---counts can change asynchronously as a live finder (e.g. live_grep) streams
---in matches, with no CursorMoved/TextChanged to hang an update off of.
---@param results_bufnr integer
---@param base_title string
---@param get_picker fun():table|nil
local function start_polling(results_bufnr, base_title, get_picker)
  local last_count = nil

  local function tick()
    if not vim.api.nvim_buf_is_valid(results_bufnr) then return end

    local picker = get_picker()
    if picker and picker.manager and picker.prompt_border then
      local ok, count = pcall(function()
        return picker.manager:num_results()
      end)
      if ok and count ~= last_count then
        last_count = count
        pcall(function()
          picker.prompt_border:change_title(string.format("%s (%d)", base_title, count))
        end)
      end
    end

    vim.defer_fn(tick, 150)
  end

  tick()
end

---Attach the result-count title to a picker. Call from `attach_mappings`.
---@param prompt_bufnr integer
---@return boolean
function M.attach_mappings(prompt_bufnr)
  local action_state = require("telescope.actions.state")

  local function get_picker()
    local ok, p = pcall(action_state.get_current_picker, prompt_bufnr)
    if ok then return p end
    return nil
  end

  local picker = get_picker()
  if not picker or not picker.results_bufnr or picker.results_bufnr == 0 then return true end

  local base_title = picker.prompt_title or ""
  start_polling(picker.results_bufnr, base_title, get_picker)

  return true
end

---Wrap an existing `attach_mappings` function so it also drives the
---result-count title, when `result_count.enabled` is true. Returns `orig`
---unchanged (including nil) otherwise, keeping the default fully inert.
---@param orig (fun(prompt_bufnr:integer, map:function):boolean|nil)|nil
---@return (fun(prompt_bufnr:integer, map:function):boolean|nil)|nil
function M.wrap_attach_mappings(orig)
  local cfg = require("pickers.config").get().result_count
  if not cfg or not cfg.enabled then return orig end

  return function(prompt_bufnr, map)
    if orig then orig(prompt_bufnr, map) end
    return M.attach_mappings(prompt_bufnr)
  end
end

return M
