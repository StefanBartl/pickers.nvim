---@module 'pickers.history'
---@brief Native picker-history: file-based, per `Pickers.HistoryConfig`.
---@description
--- fzf-lua's `--history <path>` is a plain per-invocation CLI flag, so each
--- provider (files/grep/item) can get its own file — see `fzf_path()`/`fzf_opts()`
--- and `cfg.history.fzf_scope`.
---
--- Telescope's history is a process-wide singleton (one `History` object,
--- created lazily on first use and cached for the whole session by
--- `telescope.actions.state.get_current_history()`), so there is no
--- per-call/per-scope isolation possible for it — enabling it always behaves
--- like a global default, regardless of `fzf_scope` (which does not apply to
--- telescope at all). See `telescope.opts()` and `patch()`.
---
--- snacks.nvim is NOT covered by this module — its picker core creates a
--- per-source history file unconditionally in `Picker.new` (fixed path under
--- `stdpath("data")/snacks/`, no `enabled`/`dir`/`limit` field anywhere in its
--- opts schema). There is nothing to opt into or patch; `cfg.history.*` simply
--- does not apply when the active engine is snacks. See docs/CONFIGURATION.md
--- ("History" section) for the user-facing explanation.

local M = {}

---Resolve (and ensure) the history directory.
---@param cfg Pickers.Config
---@return string
function M.dir(cfg)
  local dir = (cfg.history.dir and cfg.history.dir ~= "") and cfg.history.dir
    or (vim.fn.stdpath("data") .. "/pickers.nvim/history")
  dir = vim.fs.normalize(dir)
  vim.fn.mkdir(dir, "p")
  return dir
end

---Telescope `defaults.history` value. Always the same regardless of `fzf_scope`
---(telescope's history is a session-wide singleton — see module @brief).
---@param cfg Pickers.Config
---@return { path: string, limit: integer }
function M.telescope_opts(cfg)
  return {
    path = M.dir(cfg) .. "/telescope.txt",
    limit = cfg.history.limit,
  }
end

---Per-provider fzf-lua history file path. Used under `fzf_scope = "plugin"`.
---@param cfg  Pickers.Config
---@param kind "files"|"grep"|"item"|"dir"
---@return string
function M.fzf_path(cfg, kind)
  return M.dir(cfg) .. "/fzf_" .. kind .. ".txt"
end

---Single unified fzf-lua `fzf_opts` table (one shared history file across all
---providers). Used under `fzf_scope = "global"`/`"patch"`, mirroring what a
---global `fzf-lua.setup()` default naturally means.
---@param cfg Pickers.Config
---@return table
function M.fzf_opts(cfg)
  return { ["--history"] = M.dir(cfg) .. "/fzf_global.txt" }
end

---Install pickers.nvim's history as the engines' own default, without the
---user touching their own `telescope.setup()`/`fzf-lua.setup()` calls.
---
--- Both engines are patched deferred via `vim.schedule()`, so this call runs
--- after the current synchronous startup batch (i.e. after all lazy.nvim
--- `config()` functions) instead of forcing a `require("telescope")` (or
--- fzf-lua) load on every startup even when the user never opens a picker.
---
--- Telescope: call order never mattered for correctness anyway — it merges
--- `defaults.history` with "keep" semantics (see
--- `telescope/config.lua:set_defaults`), so deferring is free.
---
--- fzf-lua (only when `fzf_scope == "patch"`): `fzf-lua.setup()` resets the
--- whole config from scratch unless `do_not_reset_defaults=true` is passed,
--- so a plain immediate call here could be wiped out by a later user
--- `setup()` call — deferring makes it land after the user's own config
--- regardless of plugin declaration order.
---@param cfg Pickers.Config
function M.patch(cfg)
  vim.schedule(function()
    pcall(function()
      require("telescope").setup({ defaults = { history = M.telescope_opts(cfg) } })
    end)
  end)

  if cfg.history.fzf_scope == "patch" then
    vim.schedule(function()
      pcall(function()
        require("fzf-lua").setup({ fzf_opts = M.fzf_opts(cfg) }, true)
      end)
    end)
  end
end

return M
