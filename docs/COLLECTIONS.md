# Collections

Collections are user-defined named scopes. Each collection becomes a first-class
`:Pickers` scope, gets auto-generated compat commands (`{PascalName}Files` /
`{PascalName}Grep`), and optional keymaps.

## Collection config

```lua
collections = {
  -- Direct root — dir is used as-is
  { name = "notes",       dir = vim.env.REPOS_DIR .. "/Notes",
    keys = { files = "<leader>mnf", grep = "<leader>mng" } },

  -- Prefix-filtered subdirs — pick one, then search inside it
  { name = "wkdbooks",    dir = vim.env.REPOS_DIR .. "/WKDBooks",
    prefix = "wkdbook-",
    keys = { files = "<leader>wkf", grep = "<leader>wkg" } },

  -- All subdirs (empty prefix string) — pick one, then search inside it
  { name = "projects",    dir = "/home/user/projects", prefix = "" },

  -- Only subdirs that contain .git/
  { name = "myrepos",     dir = "/home/user/src", prefix = "", only_git = true },

  -- Per-collection find override — merged over the global `find` defaults,
  -- not replacing them; unset fields keep the global value.
  { name = "vendored",    dir = "/home/user/vendor",
    find = { no_ignore = true, exclude = { "*.lock" } } },
}
```

## prefix field behaviour

| `prefix` value | Behaviour |
|---|---|
| `nil` (not set) | `dir` is used directly as the search root |
| `""` (empty string) | All immediate subdirs of `dir` are listed; pick one |
| `"xyz-"` | Only subdirs whose name starts with `"xyz-"` are listed |

## find override

A collection's `find` field (`{ hidden?, no_ignore?, follow?, exclude? }`)
overrides the global `find` config for that collection's **files** action
only — grep is unaffected (it doesn't use `find` flags). It's a partial
merge: only the fields you set change, everything else keeps the global
default. Useful for e.g. a vendored-code collection where you want
`.gitignore`d files included, without changing that behaviour everywhere
else.

## Auto-generated compat commands

For a collection named `"notes_lua"`:

| Command | Equivalent |
|---|---|
| `:NotesLuaFiles` | `:Pickers notes_lua files` |
| `:NotesLuaGrep` | `:Pickers notes_lua grep` |
