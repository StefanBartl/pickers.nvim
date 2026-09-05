-- luacheck configuration for pickers.nvim
std = "luajit"
read_globals = { "vim" }

-- pickers.nvim intentionally writes plugin-load guards to vim.g.* — allow it.
-- The spec suite monkeypatches vim.ui.{select,input} around single cases,
-- restoring the original right after — allow writing that field too.
globals = { "vim.g", "vim.ui" }

-- The codebase favours readability over an 80/120 column cap.
max_line_length = false

-- Callbacks frequently receive arguments they do not use (telescope/fzf/nvim
-- signatures). Underscore-prefixed names are already ignored by luacheck; this
-- silences the remaining unused-argument noise in adapter callbacks.
ignore = {
  "212", -- unused argument
}
