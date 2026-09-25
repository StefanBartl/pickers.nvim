# Tabs

Tab groups — `pickers.tabs`: a named list of `:Pickers` targets you cycle
through from inside an open picker, the typed query travelling along.
search.nvim's tabbed UI, over this plugin's grammar instead of telescope
functions:

```lua
tabs = {
  groups = {
    default = { "cwd files", "cwd grep", "builtin buffers" },
    git = { "builtin git_branches", "builtin git_commits", "builtin git_stash" },
  },
},
keys = { tab_next = "<Tab>", tab_prev = "<S-Tab>" },  -- opt-in
```

`:Pickers tabs default` runs `cwd files`; `tab_next` closes it and runs
`cwd grep` with whatever was typed as the new picker's initial query;
`tab_prev` goes back. The group wraps around and ends when a picker opened
any other way closes — the state is per launch, not global. A target is any
argument string `:Pickers` takes, so a collection or `dir git files` is a
valid tab too; a `builtin` target has no query slot and starts empty.

No tab bar is drawn. The prompt title carries `[2/3 cwd grep]` instead,
because every engine already draws a title and none offers a second line
for free.

`tab_next`/`tab_prev` are **opt-in** (`false` by default): `<Tab>` is
telescope's multi-select toggle, so the key is the host's choice. They are
telescope and snacks actions; fzf-lua's `keymap.builtin` cannot run Lua, so
there the switch is not available (reported by `:checkhealth pickers` like
the other fzf gaps). For snacks, both the win keys and
`keys.snacks_actions()` are patched into `Snacks.config.picker` for you —
the win keys name the actions, the actions table holds them.

- **Module:** [`tabs/init.lua`](../../lua/pickers/tabs/init.lua)
  (`open`, `next`, `prev`, `switch`, `names`, `targets`, `title_suffix`)
- **Config:** `tabs.groups`, `keys.tab_next`, `keys.tab_prev` — see
  [configuration.md](../configuration.md#tabs)
- **Usercmds:** `:Pickers tabs [group]`
