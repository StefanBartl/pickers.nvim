---@module 'pickers.integrations.pdf_text'
---@brief Text preview for PDF entries in telescope, via pdfport.nvim.
---@description
--- The `images` integration draws a PDF's first page when the terminal can
--- draw pictures. Where it cannot, telescope falls back to its own previewer,
--- which shows a PDF as binary noise. This installs pdfport.nvim's
--- `filetype_hook` (extracted text) as telescope's global
--- `defaults.preview.filetype_hook`, so that fallback is readable.
---
--- pdfport.nvim is a soft dependency and is required lazily, on the first PDF
--- preview -- not when telescope loads -- so installing this costs nothing
--- until a PDF is actually previewed. A `filetype_hook` the host already set
--- keeps priority: it is called first, and only when it declines (returns
--- falsy) does the PDF text preview run.
---
--- Telescope only. fzf-lua's builtin previewer has no per-call Lua hook (a
--- `preview` function is only consulted when no builtin previewer exists),
--- and snacks previews through the `images` integration.
---
--- Config: `images.pdf_text` (default `true`).

local M = {}

---@type function|nil the hook installed by `patch()`, to avoid stacking on a re-run
local installed

---@param cfg Pickers.Config|nil
function M.patch(cfg)
  cfg = cfg or require("pickers.config").get()
  if cfg.images and cfg.images.pdf_text == false then return end

  require("pickers.engines.when_loaded").run("telescope", function()
    if not pcall(require, "telescope") then return end
    pcall(function()
      local preview = (require("telescope.config").values or {}).preview
      preview = type(preview) == "table" and preview or {}
      local existing = preview.filetype_hook
      if existing ~= nil and existing == installed then return end

      installed = function(filepath, bufnr, opts)
        if type(existing) == "function" then
          local handled = existing(filepath, bufnr, opts)
          if handled then return handled end
        end
        local ok, pdf = pcall(require, "pdfport.integrations.telescope")
        if not ok then return false end
        return pdf.filetype_hook(filepath, bufnr, opts)
      end

      require("telescope").setup({
        defaults = { preview = vim.tbl_extend("force", preview, { filetype_hook = installed }) },
      })
    end)
  end)
end

return M
