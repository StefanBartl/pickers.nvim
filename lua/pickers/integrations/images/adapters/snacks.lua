---@module 'pickers.integrations.images.adapters.snacks'
---@brief snacks.nvim: the per-picker `preview` function that draws image and
---PDF entries and lets everything else through.
---@description
--- Snacks resolves `opts.preview` to a single function called with a context
--- (`{ item, win, preview, picker, … }`) whenever the selection changes, so
--- one function has to serve both cases: draw the image, or reproduce what
--- snacks would have done. The "would have done" half is not guesswork —
--- `Snacks.picker.config.preview` falls back to `Snacks.picker.preview.file`
--- whenever a source sets no preview of its own, which is exactly the case for
--- every picker this integration is attached to (files, smart, select). So
--- delegating to `Snacks.picker.preview.file` for a non-image entry is not an
--- approximation of the default; it *is* the default.
---
--- Two ordering details carry the whole thing:
---
--- * `ctx.preview:reset()` before drawing. The preview window keeps whatever
---   buffer the previous entry left in it, and an image is drawn *over* the
---   window, not into its buffer — without the reset the picture would sit on
---   top of the last file's text.
--- * `images.clear()` on the way out of an image entry. The overlay belongs to
---   the terminal, not to the window under it: nothing but a repaint removes
---   it, so moving from an image to a text entry has to say so explicitly.
---   (A closing picker is images.nvim's own business — it arms that cleanup
---   itself.)
---
--- **A PDF entry waits, once.** An image is already a picture; a page has to
--- be rasterized first, which is a few hundred milliseconds the first time and
--- nothing at all afterwards (images.nvim caches the page on disk). Three
--- things follow, and all three are in the branch below.
---
--- * A line goes into the preview window to say what the wait is for.
--- * It is taken out again in `on_ready`, the tick before the draw. The image
---   does **not** cover the whole window — its box is shaped like the picture,
---   so a portrait page leaves most of a wide preview window untouched and the
---   line would simply sit there next to it. `on_done` cannot be used for
---   this: it runs after the draw, and a buffer edit then repaints over the
---   picture.
--- * The fall-through to snacks' own previewer has to survive the wait — a
---   draw that is accepted and then fails would otherwise leave the window
---   empty — so the same fallback is passed as `on_done`.
---
--- Both callbacks are silenced once the selection has moved on (see
--- `pickers.integrations.images.preview`), which is what makes it safe to hold
--- `ctx` in a callback at all.
---
--- Attached per call by `pickers.engines.snacks` rather than patched into
--- `Snacks.setup()`: pickers.nvim does not own the user's snacks
--- configuration — the same rule that makes `pickers.keys.snacks_win()` an
--- export to merge rather than a patch to apply.

local M = {}

---A `preview` function for `Snacks.picker.pick`/`files`/`select` opts, or nil
---when image previews are unavailable (integration off, images.nvim missing,
---or a terminal that cannot draw). Nil is the useful answer: leaving
---`opts.preview` unset is what makes snacks use its own default.
---@return (fun(ctx: table))|nil
function M.preview_fn()
  local images = require("pickers.integrations.images")
  if not images.available() then return nil end

  return function(ctx)
    local file = ctx.item and ctx.item.file

    -- Guarded, because both routes to it can be taken for one entry: refused
    -- synchronously *and* reported through `on_done`. Snacks would survive
    -- previewing the same file twice; the flicker is the reason not to.
    local fell_back = false
    local function fallback()
      if fell_back then return end
      fell_back = true
      images.clear()
      return require("snacks.picker.preview").file(ctx)
    end

    if images.is_previewable(file) then
      ctx.preview:reset()
      ctx.preview:set_title(vim.fn.fnamemodify(file, ":t"))

      -- Only for a PDF, and only until the page exists: the picture covers the
      -- box it was given and no more, so a line still in the buffer when the
      -- draw lands stays visible beside it.
      local waiting = images.is_pdf(file)
      if waiting then ctx.preview:set_lines({ "", "  rendering the page…" }) end

      local accepted = images.preview(ctx.win, file, {
        on_ready = waiting and function()
          ctx.preview:set_lines({})
        end or nil,
        on_done = function(ok)
          if not ok then fallback() end
        end,
      })
      if accepted then return end
      -- The draw was refused (an unreadable file, a window that went away
      -- between selection and preview): fall through to the text preview
      -- rather than leaving the window empty.
    end

    return fallback()
  end
end

return M
