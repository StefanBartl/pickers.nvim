# UI

What the plugin draws itself, as opposed to what the engine draws.

## The pickers that pick a picker

`:Pickers` with an argument missing does not error — it asks. Omitting the
scope opens a scope picker listing every built-in scope and every registered
collection; omitting the action opens an action picker; `dir` with no
navigation argument opens a navigation picker first.

They use `lib.nvim.ui.kit.select` when lib.nvim is installed and fall back to
`vim.ui.select` otherwise — a `pcall` per call, so a missing lib.nvim degrades
the prompt rather than breaking the command. Either way the plugin does not
introduce a fourth selection UI of its own.

- **Module:** [`ui/scope_picker.lua`](../../lua/pickers/ui/scope_picker.lua),
  [`ui/action_picker.lua`](../../lua/pickers/ui/action_picker.lua),
  [`ui/dir_nav_picker.lua`](../../lua/pickers/ui/dir_nav_picker.lua)
- **Usercmds:** `:Pickers`, `:Pickers cwd`, `:Pickers dir`

## Result count

Shows the live match count in the prompt window's title — `Find Files (128)`.

**Telescope only, and off by default.** fzf-lua and snacks both show a
position/total counter natively, so this is skipped there rather than drawn
twice.

It polls the entry manager every 150 ms while the results buffer is open rather
than hooking an event, because a live finder streams matches in asynchronously
and there is no `CursorMoved` or `TextChanged` to hang an update off.

- **Module:** [`result_count/init.lua`](../../lua/pickers/result_count/init.lua)
- **Config:** `result_count = { enabled }` (default `false`)

## Long-path shortening

Cosmetic, off by default. Shortens long paths in the results list through each
engine's own native mechanism — `path_display = { "shorten" }` on telescope,
`path_shorten = true` on fzf-lua, and a no-op on snacks, which already
truncates to the available column width.

No pickers.nvim-side logic: three engines that already solve this get their own
switch flipped, rather than a fourth implementation.

- **Module:** [`engines/`](../../lua/pickers/engines/) — per adapter
- **Config:** `display.path_shorten` (default `false`)

## Health check

`:checkhealth pickers` reports, in this order: the required dependencies, which
picker engines are installed and which one resolves, whether `rg` and `fd` are
on `PATH` (`fdfind` counts), the merged configuration, whether image previews
are active and whether a PDF page can be rasterized, the registered
collections, and the external tools declared in `docs/install.json`. The
`:Pickers` command tree adds a section of its own through lib.nvim's composer.

- **Module:** [`health.lua`](../../lua/pickers/health.lua)
- **Usercmds:** `:checkhealth pickers`
