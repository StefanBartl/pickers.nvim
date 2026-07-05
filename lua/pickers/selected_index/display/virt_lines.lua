---@module 'pickers.selected_index.display.virt_lines'
---@brief Render the index using an extmark's virt_lines (above or below the row).

local highlight = require("pickers.selected_index.highlight")

---@param bufnr integer
---@param ns integer
---@param row integer
---@param index integer
---@param above Pickers.SelectedIndex.VirtLinePos
---@return boolean success
return function(bufnr, ns, row, index, above)
  if not vim.api.nvim_buf_is_valid(bufnr) then return false end

  local virt_lines_above = (above == "top")
  local hl_group = highlight.get_group()
  local virt_line = { { tostring(index) .. ". ", hl_group } }

  local ok = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, 0, {
    virt_lines = { virt_line },
    virt_lines_above = virt_lines_above,
    hl_mode = "combine",
  })

  return ok
end
