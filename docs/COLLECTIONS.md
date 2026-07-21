# Collections

Collections are user-defined named scopes. Each collection becomes a first-class
`:Pickers` scope, gets auto-generated compat commands (`{PascalName}Files` /
`{PascalName}Grep`), and optional keymaps. `dir` is expanded on merge (`~`,
`$VAR`, `%VAR%`), so a literal `"$REPOS_DIR/Notes"` string works too — not
just a pre-expanded `vim.env.*` value.

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
}
```

## prefix field behaviour

| `prefix` value | Behaviour |
|---|---|
| `nil` (not set) | `dir` is used directly as the search root |
| `""` (empty string) | All immediate subdirs of `dir` are listed; pick one |
| `"xyz-"` | Only subdirs whose name starts with `"xyz-"` are listed |

## Auto-generated compat commands

For a collection named `"notes_lua"`:

| Command | Equivalent |
|---|---|
| `:NotesLuaFiles` | `:Pickers notes_lua files` |
| `:NotesLuaGrep` | `:Pickers notes_lua grep` |
