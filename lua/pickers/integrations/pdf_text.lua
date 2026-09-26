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

---@type table|false|nil pdfport's telescope integration once looked up; `false` = not installed
local pdf_mod

---Looked up once. The hook runs for EVERY previewed file, and a failing
---`require` walks the whole runtimepath each time it is repeated.
---@return table|false
local function pdfport()
  if pdf_mod == nil then
    local ok, mod = pcall(require, "pdfport.integrations.telescope")
    pdf_mod = ok and mod or false
  end
  return pdf_mod
end

---@param cfg Pickers.Config|nil
---@return table<string, fun(current: table): table|nil>
function M.contribute(cfg)
  cfg = cfg or require("pickers.config").get()
  if cfg.images and cfg.images.pdf_text == false then return {} end

  return {
    telescope = function(current)
      local preview = (current.defaults or {}).preview
      preview = type(preview) == "table" and preview or {}
      local existing = preview.filetype_hook
      if existing ~= nil and existing == installed then return nil end

      installed = function(filepath, bufnr, opts)
        if type(existing) == "function" then
          local handled = existing(filepath, bufnr, opts)
          if handled then return handled end
        end
        -- Cheapest test first: almost every preview is not a PDF.
        if type(filepath) ~= "string" or not filepath:lower():match("%.pdf$") then return false end
        local pdf = pdfport()
        if not pdf then return false end
        return pdf.filetype_hook(filepath, bufnr, opts)
      end

      return {
        defaults = { preview = vim.tbl_extend("force", preview, { filetype_hook = installed }) },
      }
    end,
  }
end

---Patch on its own (a host that wants only this). `bindings.setup` installs
---every contributor together instead.
---@param cfg Pickers.Config|nil
function M.patch(cfg)
  require("pickers.engines.patcher").install(cfg, { "pickers.integrations.pdf_text" })
end

return M
