---@module 'pickers.keys'
---@brief Engine-agnostic in-picker keymaps: preview scroll, history navigation,
---and the create_file/open_background entry actions — one config surface for
---everything that acts *inside* an open picker (as opposed to `keymaps`, which
---launches a scope in the first place).
---@description
--- Engine-neutral action names, translated per engine:
---
---   preview_scroll_down   preview_scroll_up
---   preview_scroll_left   preview_scroll_right
---   history_back          history_forward
---   create_file           open_background
---
--- Installation mirrors `pickers.history`: rather than injecting per-call into
--- every engine adapter, preview-scroll/history are patched onto each engine's
--- *global* config, so they apply to every picker that engine opens —
--- pickers.nvim's own pickers AND native builtins (git/lsp/…):
---
---   telescope → `telescope.setup({ defaults = { mappings = ... } })`  (patch)
---   fzf-lua   → `fzf-lua.setup({ keymap = { builtin = ... } })`       (patch)
---   snacks    → `Snacks.picker` `win` keys                            (export)
---
--- Snacks is the exception: pickers.nvim does not own `Snacks.setup()`, so it
--- cannot self-patch. Call `keys.snacks_win()` and merge the result into your
--- own `require("snacks").setup({ picker = ... })` — see docs/KEYMAPS.md.
---
--- fzf-lua is the documented capability gap: its builtin previewer has vertical
--- preview scroll but no horizontal scroll, and its `--history` binds ctrl-p /
--- ctrl-n natively (not remappable here). Unmappable actions are skipped and
--- reported once via `notify.debug` — see `pickers.keys.adapters.fzf`.
---
--- `create_file`/`open_background` are NOT patched globally like the other
--- four actions — unlike preview-scroll/history (built-in engine actions),
--- they run pickers.nvim-specific logic (`pickers.entry_actions.*`), so they
--- follow the same "you merge it into your own setup()" model as before. Only
--- the *config* (`cfg.keys.create_file`/`cfg.keys.open_background`) moved into
--- this unified namespace; see `pickers.entry_actions` for the adapters that
--- read `pickers.keys.resolve()` to build their mapping tables.

local M = {}

--- Engine-neutral action spec: default lhs + the modes each action binds in.
--- The concrete lhs come from `cfg.keys`; `modes` are fixed per action (preview
--- scroll works in insert + normal, history only in insert, matching how the
--- prompt is used).
---@type table<string, { default: string|string[], modes: string[] }>
M.ACTIONS = {
  preview_scroll_down = { default = "<PageDown>", modes = { "i", "n" } },
  preview_scroll_up = { default = "<PageUp>", modes = { "i", "n" } },
  preview_scroll_left = { default = "<C-Left>", modes = { "i", "n" } },
  preview_scroll_right = { default = "<C-Right>", modes = { "i", "n" } },
  history_back = { default = "<C-p>", modes = { "i" } },
  history_forward = { default = "<C-n>", modes = { "i" } },
  create_file = { default = "<C-a>", modes = { "i", "n" } },
  open_background = { default = { "<S-CR>", "<C-o>" }, modes = { "i", "n" } },
}

--- Stable iteration order (pairs() is unordered; adapters and tests want
--- deterministic output).
---@type string[]
M.ORDER = {
  "preview_scroll_down",
  "preview_scroll_up",
  "preview_scroll_left",
  "preview_scroll_right",
  "history_back",
  "history_forward",
  "create_file",
  "open_background",
}

--- Normalise one raw config value into a list of lhs strings.
---   string     → { string }
---   string[]   → filtered copy
---   false/nil  → {}   (nil is only reached when DEFAULTS omit the key)
---@param v string|string[]|false|nil
---@return string[]
local function to_lhs_list(v)
  if type(v) == "string" then return { v } end
  if type(v) == "table" then
    local out = {}
    for _, x in ipairs(v) do
      if type(x) == "string" and x ~= "" then out[#out + 1] = x end
    end
    return out
  end
  return {}
end

--- Resolve the active config into `action -> { lhs = string[], modes = string[] }`.
--- Returns an empty table when the whole feature is disabled (`keys.enable=false`),
--- keeping every adapter fully inert.
---@param cfg Pickers.Config|nil
---@return table<string, { lhs: string[], modes: string[] }>
function M.resolve(cfg)
  cfg = cfg or require("pickers.config").get()
  local kc = cfg.keys or {}
  if kc.enable == false then return {} end

  local out = {}
  for _, name in ipairs(M.ORDER) do
    local spec = M.ACTIONS[name]
    local raw = kc[name]
    if raw == nil then raw = spec.default end
    out[name] = { lhs = to_lhs_list(raw), modes = spec.modes }
  end
  return out
end

-- ── Engine exports ────────────────────────────────────────────────────────────

--- Snacks `win` keys table for `require("snacks").setup({ picker = { win = ... } })`.
--- Returns `{ input = {keys=...}, list = {keys=...}, preview = {keys=...} }`.
---@param cfg Pickers.Config|nil
---@return { input: { keys: table }, list: { keys: table }, preview: { keys: table } }
function M.snacks_win(cfg)
  return require("pickers.keys.adapters.snacks").win(M.resolve(cfg))
end

--- Telescope `defaults.mappings` table (`{ i = {...}, n = {...} }`).
---@param cfg Pickers.Config|nil
---@return { i: table<string, function>, n: table<string, function> }
function M.telescope_mappings(cfg)
  return require("pickers.keys.adapters.telescope").mappings(M.resolve(cfg))
end

--- fzf-lua `keymap.builtin` table.
---@param cfg Pickers.Config|nil
---@return table<string, string>
function M.fzf_keymap(cfg)
  return require("pickers.keys.adapters.fzf").keymap(M.resolve(cfg))
end

--- Actions bound in the active config that fzf-lua cannot remap (its builtin
--- previewer has no horizontal preview scroll, and history is fzf-native,
--- fixed to ctrl-p/ctrl-n). Empty when nothing is bound to them, or the whole
--- `keys` feature is disabled. Consumed by `:checkhealth pickers`.
---@param cfg Pickers.Config|nil
---@return string[]
function M.fzf_skipped(cfg)
  return require("pickers.keys.adapters.fzf").skipped(M.resolve(cfg))
end

--- Install the in-picker keys onto each available engine's global config, so
--- they apply to every picker that engine opens. No-op when disabled.
---
--- Telescope is patched immediately (`defaults.mappings` deep-merges, so a later
--- user `telescope.setup()` keeps ours as long as they don't redefine the same
--- lhs). fzf-lua is patched deferred via `vim.schedule` — its `setup()` resets
--- config unless `do_not_reset_defaults=true` is passed, and deferring makes our
--- call land after the user's own `setup()` in the startup batch (same reasoning
--- as `pickers.history.patch`). Snacks is not patched here — pickers.nvim does
--- not own `Snacks.setup()`; use `keys.snacks_win()`.
---@param cfg Pickers.Config|nil
function M.patch(cfg)
  cfg = cfg or require("pickers.config").get()
  local resolved = M.resolve(cfg)
  if vim.tbl_isempty(resolved) then return end

  require("pickers.keys.adapters.telescope").patch(resolved)

  vim.schedule(function()
    require("pickers.keys.adapters.fzf").patch(resolved)
  end)
end

return M
