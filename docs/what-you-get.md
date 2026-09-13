# What you get with the defaults

| Scope | Looks in |
| --- | --- |
| `cwd` | The current working directory |
| `config` | `stdpath("config")` |
| `folder` | A folder you pick interactively |
| `repos` | A git repository under `repos_dir` |
| `wkdbooks` | A `wkdbook-*` subdirectory under `repos_dir/WKDBooks` |
| `system` | Systemwide via `fd`, prompting for the query |
| `drives` | Every mount point or drive letter |
| `dir <nav>` | `1`…`N` levels up, `git`, `home`, `cwd`, `root`, an alias, or `path=<dir>` |

| Key | Does |
| --- | --- |
| `<leader>dp` | `:Pickers dir` — a count is the depth, so `2<leader>dp` goes two up |
| `<leader>.` | `:Pickers builtin explorer` |

Every scope takes `files`, `grep` or `smart`, and every one of them completes
with `<Tab>`. The full set of keys is [keymaps.md](keymaps.md); the
full command grammar is [commands.md](commands.md).
