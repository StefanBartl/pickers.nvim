---@module 'pickers.integrations.images'
---@brief Draw image entries — and the first page of a PDF — in the preview
---window, via images.nvim (a soft, opt-in integration).
---@description
--- Every file picker here already *lists* `.png`/`.jpg`/… — a result list is
--- a result list, and `fd` does not care what a file contains. What used to
--- follow was the disappointing half: selecting such an entry showed the
--- engine's text preview of a binary file ("Binary cannot be previewed", or a
--- screenful of bytes). With
--- [images.nvim](https://github.com/StefanBartl/images.nvim) installed, the
--- preview window shows the actual picture instead.
---
--- **A PDF entry is the same feature.** `.pdf` is a result like any other and
--- previewed as bytes for the same reason, and images.nvim answers for it
--- through the same surface: it rasterizes the first page (pdfport.nvim, and
--- poppler's `pdftoppm` underneath) and draws the result. Nothing in this
--- module reads a PDF or knows what a page is — `is_previewable()` replaces
--- `is_image()` in the two adapters, and that is the whole of the difference.
--- On a machine without a rasterizer the answer is simply no and the entry
--- stays the engine's to preview.
---
--- What a page does add is a *wait*, and with it the two callbacks on
--- `M.preview`: something has to fill the moment before the picture exists,
--- and something has to take it away again at the right tick. A drawn image
--- covers the box it was given and no more — a portrait page in a wide preview
--- window leaves most of that window uncovered — so a placeholder that is not
--- removed stays on screen beside the picture.
---
--- **The dependency is one-directional and soft.** images.nvim exposes a
--- three-function surface for exactly this (`images.integrations.picker`:
--- `available()` / `is_previewable()` / `preview(winid, file)`), pickers.nvim
--- calls it, and nothing here fails when images.nvim is absent —
--- `available()` is then simply false and every engine keeps its own
--- previewer. That is why the OSC 1337 details (which terminal can draw, where
--- a bordered window's content actually starts, when an overlay has to be
--- repainted away) live over there and not here — together with the
--- rasterizing, for the same reason: this module knows *which window* to draw
--- into, images.nvim knows *how*.
---
--- **Three checks, in this order, before any preview is taken over:**
---   1. `cfg.images.enabled` — the user's opt-out, honoured even when
---      everything else says yes.
---   2. images.nvim installed and exposing the surface.
---   3. images.nvim reports the terminal can draw at all.
---
--- Step 3 is the one worth naming: images.nvim answers this strictly here
--- (unlike its own `:Image show`, which warns and draws anyway). A picker
--- preview is the one place where the fallback beats the attempt — an empty
--- preview window is worse than the text preview the engine would have shown
--- by itself. On an unrecognised terminal the answer is therefore no, and the
--- escape hatch is images.nvim's own `display.assume_supported = true`.
---
--- **Engine coverage** (each engine as far as its preview API reaches):
---   * snacks   — full. A picker takes a `preview` function per call, so
---                image entries draw and everything else falls through to
---                snacks' own file previewer.
---   * telescope — full for the file pickers. A picker takes a `previewer`
---                object per call; `pickers.integrations.images.adapters
---                .telescope` builds one that draws image entries and hands
---                everything else to telescope's own buffer previewer.
---   * fzf-lua  — not wired. Its builtin previewer is a class in fzf-lua's own
---                object system, driven by the fzf process rather than by a
---                per-call Lua hook, and it already ships its own image
---                support through `previewers.builtin.extensions` (chafa /
---                viu / ueberzug). Same class of documented capability gap as
---                its history keys, and the same answer: use the engine's
---                native mechanism. See docs/FEATURES/IMAGES.md.

local M = {}

--- images.nvim's picker surface, or nil when it is not installed (or is too
--- old to have one). Verified by shape rather than by version: the surface is
--- three functions, and a version number would only be a proxy for them.
---@internal
---@return table|nil
local function api()
  local ok, mod = pcall(require, "images.integrations.picker")
  if not ok or type(mod) ~= "table" then return nil end
  if
    type(mod.available) ~= "function"
    or type(mod.is_image) ~= "function"
    or type(mod.preview) ~= "function"
  then
    return nil
  end
  return mod
end

---Whether the integration is switched on in the configuration. Separate from
---`available()` so a user's `images = { enabled = false }` reads as a decision
---in `:checkhealth pickers`, not as "images.nvim seems to be missing".
---@return boolean
function M.enabled()
  local cfg = require("pickers.config").get()
  return (cfg.images or {}).enabled ~= false
end

---Whether image previews can be used right now: enabled, images.nvim present,
---and the terminal able to draw. Engines call this ONCE per picker, before
---they decide which previewer to attach — not per entry.
---@return boolean
function M.available()
  if not M.enabled() then return false end
  local images = api()
  return images ~= nil and images.available() == true
end

---Whether an entry's path is an image, by images.nvim's own configured
---extension list (so a user who adds `avif` there gets it here too).
---@param path string|nil
---@return boolean
function M.is_image(path)
  if type(path) ~= "string" or path == "" then return false end
  local images = api()
  return images ~= nil and images.is_image(path) == true
end

---Whether an entry is one images.nvim would draw: an image, or a PDF page it
---can rasterize. The question the adapters ask per entry.
---
---Falls back to `is_image()` against an images.nvim that predates the PDF half
---of the surface — the integration then behaves exactly as it did before, for
---images, instead of going dark. Checked by shape rather than by version, the
---same way `api()` checks the surface itself.
---@param path string|nil
---@return boolean
function M.is_previewable(path)
  if type(path) ~= "string" or path == "" then return false end
  local images = api()
  if not images then return false end
  if type(images.is_previewable) == "function" then return images.is_previewable(path) == true end
  return images.is_image(path) == true
end

---Whether an entry is a PDF images.nvim would rasterize. Narrower than
---`is_previewable` and asked for one reason only: a page that is not cached
---yet takes a moment to produce, and an adapter that knows a wait is coming
---can put a line in the preview window to say so. See the adapters.
---@param path string|nil
---@return boolean
function M.is_pdf(path)
  if type(path) ~= "string" or path == "" then return false end
  local images = api()
  return images ~= nil and type(images.is_pdf) == "function" and images.is_pdf(path) == true
end

---@type integer Which preview is the current one; see `M.preview`.
local generation = 0

---Draw `file` into the preview window `winid`.
---
---`false` means "not drawn — show your own preview instead", and comes back
---before anything has been painted, so a caller can fall through to the
---engine's previewer without a flicker. `true` means the draw was accepted;
---it lands in the next tick (images.nvim defers, because a preview window is
---usually filled in the same tick it is drawn into) — or, for a PDF page that
---has not been rasterized before, in a few hundred milliseconds.
---
---`opts.on_done` is how an accepted draw that then fails still reaches the
---caller: an unreadable image, a page that will not rasterize.
---`opts.on_ready` is the opposite moment — the picture exists and is about to
---be drawn, which is when a placeholder put there to fill the wait has to come
---down. It cannot wait for `on_done`: the drawn image covers only the box it
---was given (shaped like the picture, not like the window), so a line left
---beside it stays visible, and editing the buffer after the draw makes Neovim
---repaint over the picture instead.
---
---Both run at most once, and **only while this is still the preview on
---screen** — a later selection (or a `M.clear()`) silences them, because by
---then the window belongs to another entry and writing this one's fallback or
---placeholder removal into it would replace what the engine has just correctly
---put there. That guard is why these go through here at all rather than
---callers passing images.nvim's own callbacks straight through.
---@param winid integer preview window
---@param file string absolute path
---@param opts { on_done?: fun(ok: boolean, err: string|nil), on_ready?: fun() }|nil
---@return boolean ok
function M.preview(winid, file, opts)
  local images = api()
  if not images then return false end

  opts = opts or {}
  generation = generation + 1
  local ticket = generation

  ---@param fn function|nil
  ---@return function|nil
  local function while_current(fn)
    if not fn then return nil end
    return function(...)
      if ticket ~= generation then return end
      fn(...)
    end
  end

  return images.preview(winid, file, {
    on_done = while_current(opts.on_done),
    on_ready = while_current(opts.on_ready),
  }) == true
end

---Repaint the drawn image away, and disown any preview still in flight.
---Callers must do this when the selection moves from an image to a non-image
---entry: the preview window stays open in that case, and the picture would
---otherwise sit on top of the text preview that follows it. (A *closing*
---preview window is images.nvim's own business — it arms that cleanup itself.)
---@return nil
function M.clear()
  generation = generation + 1
  local images = api()
  if images then images.clear() end
end

return M
