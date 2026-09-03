---@module 'pickers.integrations.images.adapters.telescope'
---@brief telescope.nvim: a file previewer that draws image entries and hands
---everything else to telescope's own.
---@description
--- Telescope attaches ONE previewer object per picker, and a previewer's
--- `define_preview` sees every entry — so unlike snacks (a `preview` function
--- with a documented default to fall back to) the branch has to be built into
--- a previewer of our own. It is deliberately telescope's own
--- `previewers.cat` with one extra branch in front:
---
---   image entry     → empty the preview buffer, draw over the window
---   everything else → `conf.values.buffer_previewer_maker(...)`, i.e. exactly
---                     what `previewers.cat` calls, with the user's own
---                     `defaults.preview` settings (timeout, filesize_limit,
---                     the {filetype,mime,filesize,timeout}_hook family)
---
--- **Why not telescope's own `filetype_hook` instead.** That hook exists and
--- would need no previewer of ours — but it only fires once a filetype was
--- detected, and image extensions have none, so the first call is skipped
--- entirely. The second call site fires unconditionally, yet only *after*
--- telescope has read the whole file and written its bytes into the preview
--- buffer as text. Drawing from there would mean reading a megabyte of PNG to
--- throw it away. The branch belongs in front of the read, not behind it.
---
--- **`conf.preview == false` means the user turned previewers off** — that is
--- what `telescope.previewers`' own defaulter checks first, and returning nil
--- here reproduces it: the caller then keeps whatever it would have used
--- without this integration, rather than forcing a preview window back on.

local M = {}

---A buffer previewer with an image branch, or nil when it does not apply
---(integration off, images.nvim missing, a terminal that cannot draw,
---telescope modules unavailable, or previews switched off in telescope's own
---configuration). Nil means "use your usual previewer".
---@return table|nil previewer a telescope previewer object
function M.previewer()
  local images = require("pickers.integrations.images")
  if not images.available() then return nil end

  local ok_prev, previewers = pcall(require, "telescope.previewers")
  local ok_entry, from_entry = pcall(require, "telescope.from_entry")
  local ok_conf, config = pcall(require, "telescope.config")
  if not (ok_prev and ok_entry and ok_conf) then return nil end

  local conf = config.values
  if conf.preview == false then return nil end

  -- A copy: `file_maker` fills its own defaults into this table, and that must
  -- not reach the user's `defaults.preview`.
  local preview_opts = type(conf.preview) == "table" and vim.deepcopy(conf.preview) or {}

  return previewers.new_buffer_previewer({
    title = "File Preview",
    dyn_title = function(_, entry)
      local path = from_entry.path(entry, false, false)
      return path and vim.fn.fnamemodify(path, ":~:.") or ""
    end,
    get_buffer_by_name = function(_, entry)
      return from_entry.path(entry, false, false)
    end,
    define_preview = function(self, entry)
      local path = from_entry.path(entry, true, false)
      if path == nil or path == "" then return end

      if images.is_image(path) then
        -- The image is drawn OVER the window, so whatever the buffer holds
        -- would show through it -- including this same buffer's own contents
        -- from an earlier preview, since telescope caches one buffer per file.
        pcall(vim.api.nvim_buf_set_lines, self.state.bufnr, 0, -1, false, {})
        if images.preview(self.state.winid, path) then return end
        -- Refused (unreadable file, window already gone): fall through to the
        -- text preview rather than leaving the window empty.
      end

      images.clear()
      conf.buffer_previewer_maker(path, self.state.bufnr, {
        bufname = self.state.bufname,
        winid = self.state.winid,
        preview = preview_opts,
      })
    end,
    teardown = function()
      images.clear()
    end,
  })
end

return M
