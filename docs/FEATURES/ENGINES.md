# Engines

Every picker in this plugin runs on one of three backends. Which one is a
resolution step, not a hard-coded choice — the same `:Pickers cwd files` works
on telescope.nvim, fzf-lua or snacks.nvim, and the features in
[KEYS.md](KEYS.md) exist so it also *behaves* the same on all three.

## Engine resolution

`engine = "auto"` (the default) picks the first installed backend in the order
telescope → fzf-lua → snacks. Naming an engine explicitly pins it, and falls
back to the resolved default when that one is not installed rather than failing
the call.

An engine adapter is a small module with a fixed surface — `pick_files`,
`pick_grep`, `pick_item` and the builtin dispatch — so a fourth backend is a
new file in `engines/`, not a change anywhere else.

- **Module:** [`engines/init.lua`](../../lua/pickers/engines/init.lua),
  adapters in `engines/{telescope,fzf,snacks}.lua`
- **Config:** `engine` (`"auto"` | `"telescope"` | `"fzf"` | `"snacks"`)

## Per-call engine override

`pickers.command.handle({ fargs = {…}, engine = "telescope" })` runs one
dispatch on a named engine regardless of the configured default. This is a Lua
API, deliberately not exposed as a `:Pickers` argument: it exists so a single
*keymap* can prefer a specific engine for a specific job, which is what
`mappings`' per-entry override uses underneath.

- **Module:** [`command/init.lua`](../../lua/pickers/command/init.lua)
- **Keymaps:** see [KEYS.md](KEYS.md#declarative-mappings)

## One idea, three option names

A picker call carries its `roots` — the directories, or single files, a grep is
restricted to. Each backend spells that differently, and none of them complains
about a name it does not know:

| Engine | Option the library reads |
|---|---|
| telescope | `search_dirs` |
| fzf-lua | `search_paths` |
| snacks | `dirs` |

The fzf-lua adapter passed `search_dirs` until 2026-09-03 — telescope's
spelling. fzf-lua dropped it in silence, so every scoped grep on that engine
ran over the CWD and returned plausible results from the wrong place; only
their paths gave it away. Since the failure is invisible at runtime, the
mapping is asserted in `TESTS/pickers_spec.lua` (one stub per library, one
check per engine) rather than trusted.

All three take **files** where they take directories, which is what lets a
caller narrow a grep to a handful of files rather than a whole tree.

## Deferred engine wiring

Engine setup that must happen *after* the engine loads — patching in the
in-picker keys, the result-count poller, history options — is registered
against the engine's own load event rather than run at `setup()` time. A
lazy-loaded telescope is therefore still patched, and pickers.nvim does not
force any engine to load just to configure it.

- **Module:** [`engines/when_loaded.lua`](../../lua/pickers/engines/when_loaded.lua)

## External tool dependencies, declared

The find and grep actions shell out to `fd` and `rg`. Rather than failing at
first use with a shell error, the plugin declares those tools through
`lib.nvim.deps` and shows a one-time popup after install explaining which tools
it wants and why.

- **Module:** `lib.nvim.deps` (spec in the repo root)
- **Config:** `deps_popup` (default `true`) — set `false` in the spec passed to
  `setup()` to silence it for this plugin only, no `vim.g` needed
- **Usercmds:** `:Lib deps show pickers.nvim`, `:Lib deps install pickers.nvim`
