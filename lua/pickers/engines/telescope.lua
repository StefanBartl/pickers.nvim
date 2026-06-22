---@module 'pickers.engines.telescope'
---@brief telescope.nvim adapter — implements the pickers engine interface.
---@see pickers.engines.fzf  (same interface)

local notify = require("lib.nvim.notify").create("[pickers.engines.telescope]")

local M = {}

-- ── Helpers ──────────────────────────────────────────────────────────────────

---Require multiple telescope sub-modules at once.
---@return boolean ok, table builtin, table pickers, table finders, table conf, table actions, table state
local function load_telescope()
  local ok_b, builtin = pcall(require, "telescope.builtin")
  local ok_p, pickers = pcall(require, "telescope.pickers")
  local ok_f, finders = pcall(require, "telescope.finders")
  local ok_c, conf    = pcall(require, "telescope.config")
  local ok_a, actions = pcall(require, "telescope.actions")
  local ok_s, state   = pcall(require, "telescope.actions.state")
  local ok = ok_b and ok_p and ok_f and ok_c and ok_a and ok_s
  return ok, builtin, pickers, finders, conf, actions, state
end

---Safely call a function; report errors via notify.
---@param fn function
---@param opts table
local function safe_call(fn, opts)
  local ok, err = pcall(fn, opts)
  if not ok then
    notify.error("telescope error: " .. tostring(err))
  end
end

-- ── Public engine interface ───────────────────────────────────────────────────

---@return boolean
function M.available()
  local ok = pcall(require, "telescope.builtin")
  return ok
end

---@param opts Pickers.EngineOpts
function M.pick_files(opts)
  local ok, builtin = pcall(require, "telescope.builtin")
  if not ok then notify.error("telescope.builtin unavailable") return end

  local call_opts = {
    prompt_title = opts.prompt,
    default_text = opts.query,
  }

  if opts.find_command then
    -- Custom find command (system source)
    call_opts.find_command = opts.find_command
    call_opts.cwd = opts.roots[1]
  elseif #opts.roots > 1 then
    -- Multi-root: telescope supports search_dirs natively
    call_opts.search_dirs = opts.roots
  else
    call_opts.cwd = opts.roots[1]
  end

  safe_call(builtin.find_files, call_opts)
end

---@param opts Pickers.EngineOpts
function M.live_grep(opts)
  local ok, builtin = pcall(require, "telescope.builtin")
  if not ok then notify.error("telescope.builtin unavailable") return end

  local extra = opts.additional_args or {}
  safe_call(builtin.live_grep, {
    prompt_title  = opts.prompt,
    search_dirs   = opts.roots,
    default_text  = opts.query,
    additional_args = function()
      return vim.list_extend({ "--hidden", "--no-ignore-vcs", "-S" }, extra)
    end,
  })
end

---Pick one item from a string list.
---@param opts { items: string[], prompt: string, on_select: fun(string) }
function M.pick_item(opts)
  local ok, pickers, finders, conf, actions, action_state
  ok, _, pickers, finders, conf, actions, action_state = load_telescope()
  if not ok then notify.error("telescope modules unavailable") return end

  pickers.new({}, {
    prompt_title = opts.prompt,
    finder       = finders.new_table({ results = opts.items }),
    sorter       = conf.values.generic_sorter({}),
    attach_mappings = function(_, _map)
      actions.select_default:replace(function(bufnr)
        actions.close(bufnr)
        local sel = action_state.get_selected_entry()
        if sel then opts.on_select(sel[1]) end
      end)
      return true
    end,
  }):find()
end

---Open a directory picker.
---@param opts { prompt: string, cwd: string|nil, on_select: fun(string) }
function M.pick_dir(opts)
  local ok, _, pickers, finders, conf, actions, action_state
  ok, _, pickers, finders, conf, actions, action_state = load_telescope()
  if not ok then notify.error("telescope modules unavailable") return end

  local cwd = opts.cwd or vim.fn.getcwd()

  pickers.new({}, {
    prompt_title = opts.prompt or "Folder",
    finder = finders.new_oneshot_job(
      { "fd", "--type", "d", "--hidden", "--follow", "--exclude", ".git", ".", cwd },
      {
        entry_maker = function(entry)
          return {
            value   = entry,
            display = entry,
            ordinal = entry,
            path    = cwd .. "/" .. entry,
          }
        end,
      }
    ),
    sorter    = conf.values.file_sorter({}),
    previewer = conf.values.file_previewer({}),
    attach_mappings = function(_, _map)
      actions.select_default:replace(function(bufnr)
        actions.close(bufnr)
        local sel = action_state.get_selected_entry()
        if sel then
          opts.on_select(vim.fs.normalize(sel.path or sel.value or sel[1]))
        end
      end)
      return true
    end,
  }):find()
end

return M
