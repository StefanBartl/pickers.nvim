# Quickstart

Open the picker with no arguments and pick your way through — scope first, then
action:

```vim
:Pickers
```

Then, once you know the words:

```vim
:Pickers cwd files            " find files below the working directory
:Pickers config grep          " live grep in your Neovim config
:Pickers repos                " pick a git repo, then pick what to do in it
:Pickers dir 2 files          " two directories up
:Pickers dir path=~/notes     " an explicit path
:Pickers builtin git_branches " the engine's own native picker, by name
```

Flags apply to a single call, alone or joined with `+`:

```vim
:Pickers cwd files hidden+follow
:Pickers cwd files all        " hidden + no_ignore + follow, just this once
```

Verify your setup any time with:

```vim
:checkhealth pickers
```

See [what-you-get.md](what-you-get.md) for the rest of the surface at a
glance, or [cheatsheet.md](cheatsheet.md) for everything on one screen.
