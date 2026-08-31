# Persistence

What survives a picker closing: the query you typed, the picker you had open,
and which files you actually visit.

## Picker history

File-based history of past queries, off by default, stored under
`stdpath("data")/pickers.nvim/history`.

The interesting part is that the three engines make three different promises,
and this feature does not pretend otherwise:

- **fzf-lua** takes a `--history <path>` per invocation, so each provider
  (files / grep / item) can have its own file. `fzf_scope` chooses between
  `"plugin"` (separate files, only on pickers.nvim's own calls), `"global"`
  (pickers.nvim sets nothing; you wire `history.fzf_opts()` into your own
  `fzf-lua.setup()`), and `"patch"` (pickers.nvim merges into fzf-lua's setup
  itself, so your own `:FzfLua` usage shares the file too).
- **telescope** has no scope knob at all. Its history is a process-wide
  singleton created on first use and reused by every telescope picker, not just
  this plugin's. Enabling history there always behaves like a global default
  regardless of `fzf_scope` — a telescope architecture limit, recorded rather
  than worked around.
- **snacks** ignores this config entirely. Its history is built into the picker
  core, always on, one file per source, with no knob exposed anywhere in its
  opts schema. Setting `history.enabled` while on snacks is a no-op *for
  snacks* and still takes effect for the other two if they are installed.

- **Module:** [`history/init.lua`](../../lua/pickers/history/init.lua)
- **Config:** `history = { enabled, fzf_scope, dir, limit }` (default off)
- **Keymaps:** `keys.history_back` / `keys.history_forward` — see
  [KEYS.md](KEYS.md#in-picker-keys)

## Frecency

Visit tracking that feeds the `smart` ranking. Recorded on `BufReadPost` for
real listed file buffers only, persisted as JSON. Opt-in and off by default,
and documented in full where it is used —
[ACTIONS.md](ACTIONS.md#frecency-boost).

- **Module:** [`smart/frecency.lua`](../../lua/pickers/smart/frecency.lua) —
  the config shape, the `BufReadPost` definition of "a visit", and the
  enabled-gate. The heuristic itself (bucketed recency, log-dampened counts,
  the JSON store) is
  [`lib.nvim.frecency`](https://github.com/StefanBartl/lib.nvim/blob/main/lua/lib/nvim/frecency/README.md),
  extracted from this file so `gopath.nvim` could rank its alternate-file
  candidates the same way instead of growing a second copy of the same
  buckets.
- **Config:** `smart.frecency = { enabled, weight, dir }`
- **Storage:** `stdpath("data")/pickers.nvim/frecency.json`, unchanged in
  place. The file's *shape* is `lib.nvim.cache.disk`'s since the extraction
  (a flat `path -> { count, last }` map became a `{ saved_at, data }`
  envelope), and a store written before it is **adopted on first use**: the
  old shape is read once, seeded into the new store and written back. Nothing
  is lost and nothing has to be done by hand. The migration path cannot run
  twice — after the write the old shape is no longer there — and seeding
  refuses a store that already holds anything, so it cannot overwrite real
  history either.

## Repeat and resume

Two different questions, two commands:

- `:PickersRepeat` reopens the most recently dispatched action — same scope,
  same action, fresh query.
- `:PickersResume` reopens the last picker *with* its last query, i.e. the
  engine's own resume.

- **Module:** [`command/init.lua`](../../lua/pickers/command/init.lua)
- **Usercmds:** `:PickersRepeat`, `:PickersResume`

## Discovered drives

The `drives` scope enumerates mounted drives once per session and caches the
result, rather than probing on every call. Documented as a cache rather than
hidden: a drive mounted mid-session needs a restart to appear.

- **Module:** [`sources/drives.lua`](../../lua/pickers/sources/drives.lua)
