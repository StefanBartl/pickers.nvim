---@module 'pickers.entry_actions.adapters.fzf'
---@brief fzf-lua entry-action registrations: create_file + open_background + cheatsheet.
---@description
--- fzf-lua action-table keys are fzf's own bind syntax ("ctrl-a", not
--- Neovim's "<C-a>"), so unlike the telescope/snacks adapters this one does
--- not read `keys.create_file`/`keys.open_background`/`keys.cheatsheet` —
--- there is no general, safe way to translate Neovim keymap syntax to fzf
--- bind syntax. Only `keys.enable` is honoured; the ctrl-a/ctrl-o/shift-enter/
--- f1 bindings themselves are fixed (matching the previous nvim-config
--- behavior exactly for the first two; f1 is new here).
---
--- The cheatsheet needs its own resume dance, same shape as
--- do_open_background's but the other way round: fzf-lua's action table
--- always closes the running fzf process before the Lua callback runs (that's
--- how `--expect`/action wrapping works, not something an action can opt out
--- of), so the callback waits for the terminal to actually close, opens the
--- read-only panel, and resumes fzf once THAT closes.

local notify = require("lib.nvim.notify").create("[pickers.entry_actions.adapters.fzf]")
local extract = require("pickers.entry_actions.extract.fzf")
local create_file = require("pickers.entry_actions.create_file")
local open_background = require("pickers.entry_actions.open_background")

local M = {}

---@internal
---@param selected table|string
local function do_open_background(selected)
  local path = extract(selected)
  if not path then
    notify.warn("No valid path found")
    return
  end
  -- fzf-lua's cached invocation context: the window it was opened from, same
  -- role as telescope's original_win_id / snacks' picker.main. No line/col
  -- here (would need to parse the raw grep-formatted entry) -- best-effort.
  local ok_ctx, ctx = pcall(function()
    return require("fzf-lua.utils").__CTX()
  end)
  open_background.run(path, { win = ok_ctx and ctx and ctx.winid or nil })
  vim.defer_fn(function()
    require("fzf-lua").resume()
  end, 50)
end

---@internal
---@param selected table|string
local function do_create_file(selected)
  local path = extract(selected)
  if not path then
    notify.warn("No valid path found")
    return
  end
  -- fzf-lua's picker runs in a terminal buffer; give it time to close
  -- before showing vim.ui.input (create_file.run schedules on top of this).
  vim.defer_fn(function()
    create_file.run(path)
  end, 150)
end

---@internal
---Fixed lhs (fzf bind syntax) shown for the fzf-lua rows of the cheatsheet
---panel itself — the Neovim-notation defaults `pickers.keys.resolve()` would
---otherwise report don't apply on this engine (see @description above).
local FZF_OVERRIDES = {
  create_file = "ctrl-a",
  open_background = "ctrl-o / shift-enter",
  cheatsheet = "f1",
}

local function do_cheatsheet()
  -- Let the fzf terminal buffer finish closing before opening the panel
  -- (same wait `do_create_file` gives `vim.ui.input`, see its comment).
  vim.defer_fn(function()
    require("pickers.cheatsheet").show({
      overrides = FZF_OVERRIDES,
      on_close = function()
        -- Same post-close delay `do_open_background` gives `fzf.resume()`.
        vim.defer_fn(function()
          require("fzf-lua").resume()
        end, 50)
      end,
    })
  end, 150)
end

---Build the fzf-lua `actions` table fragment for create_file/open_background/
---cheatsheet.
---@return table<string, function> actions
function M.get_actions()
  if require("pickers.config").get().keys.enable == false then return {} end

  return {
    ["ctrl-a"] = do_create_file,
    ["ctrl-o"] = do_open_background,
    ["shift-enter"] = do_open_background,
    ["f1"] = do_cheatsheet,
  }
end

return M
