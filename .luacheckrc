-- luacheck configuration for pickers.nvim
std = "luajit"
read_globals = { "vim" }

-- pickers.nvim intentionally writes plugin-load guards to vim.g.* — allow it.
-- The spec suite monkeypatches vim.ui.{select,input}, vim.system,
-- vim.fn.executable, vim.fn.mkdir and vim.uv.fs_scandir around single cases,
-- restoring the original right after — allow writing those fields too
-- (vim.system: pickers.sources.drives' real Get-PSDrive/df calls and
-- pickers.smart.search's fd/rg calls, stubbed out so no subprocess actually
-- runs; vim.fn.mkdir/vim.uv.fs_scandir: simulating a filesystem-boundary
-- failure without touching a real unwritable path or broken mount).
globals = { "vim.g", "vim.ui", "vim.system", "vim.fn", "vim.uv" }

-- The codebase favours readability over an 80/120 column cap.
max_line_length = false

-- Callbacks frequently receive arguments they do not use (telescope/fzf/nvim
-- signatures). Underscore-prefixed names are already ignored by luacheck; this
-- silences the remaining unused-argument noise in adapter callbacks.
ignore = {
  "212", -- unused argument
}
