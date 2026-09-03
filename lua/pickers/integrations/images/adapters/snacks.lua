---@module 'pickers.integrations.images.adapters.snacks'
---@brief snacks.nvim: the per-picker `preview` function that draws image
---entries and lets everything else through.
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
    if images.is_image(file) then
      ctx.preview:reset()
      ctx.preview:set_title(vim.fn.fnamemodify(file, ":t"))
      if images.preview(ctx.win, file) then return end
      -- The draw was refused (an unreadable file, a window that went away
      -- between selection and preview): fall through to the text preview
      -- rather than leaving the window empty.
    end

    images.clear()
    return require("snacks.picker.preview").file(ctx)
  end
end

return M
