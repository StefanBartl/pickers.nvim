---@module 'pickers.selected_index.display.virt_text'
---@brief Render the index using an extmark's virt_text.

local highlight = require("pickers.selected_index.highlight")

---@param results_bufnr integer
---@param ns integer
---@param row integer
---@param index integer
---@param text_align Pickers.SelectedIndex.VirtTextPos
---@return boolean success
return function(results_bufnr, ns, row, index, text_align)
  if not vim.api.nvim_buf_is_valid(results_bufnr) then return false end

  local line_count = vim.api.nvim_buf_line_count(results_bufnr)
  if row < 0 or row >= line_count then return false end

  if type(index) ~= "number" or index < 1 then return false end

  local hl_group = highlight.get_group()
  local virt_text = { { tostring(index) .. ". ", hl_group } }

  local ok = pcall(vim.api.nvim_buf_set_extmark, results_bufnr, ns, row, 0, {
    virt_text = virt_text,
    hl_mode = "combine",
    virt_text_pos = text_align,
  })

  return ok
end
