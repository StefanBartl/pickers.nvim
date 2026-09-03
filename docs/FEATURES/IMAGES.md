# Images

Image entries — and PDFs — drawn as pictures in the preview window, instead of
previewed as bytes.

## What it does

The file pickers here have always *listed* `.png`/`.jpg`/`.webp`/`.pdf`/… —
`fd` does not care what a file contains, so a result list of a directory of
screenshots is a result list like any other. What followed was the
disappointing half: moving onto such an entry showed the engine's text preview
of a binary file — "Binary cannot be previewed", or a screenful of bytes.

With [images.nvim](https://github.com/StefanBartl/images.nvim) installed, the
preview window shows the picture. Nothing else changes: the same pickers, the
same keys, the same entries; only the preview of an image entry is different.

```
:Pickers cwd files          → screenshots/2026-08-31.png   [the actual image]
:Pickers cwd smart shot     → the same, from the merged ranking
```

## PDFs, the same way

A `.pdf` entry previews as its **first page**, with
[pdfport.nvim](https://github.com/StefanBartl/pdfport.nvim) installed
alongside images.nvim (and poppler's `pdftoppm`, which pdfport shells out to).

```
:Pickers cwd files invoice  → invoices/2026-08.pdf         [page 1, drawn]
```

Nothing in pickers.nvim reads a PDF or knows what a page is. images.nvim
answers for it through the same surface: it rasterizes the page and draws the
result, so from here a PDF entry and an image entry are the same entry. On a
machine without a rasterizer the answer is simply no, and the PDF stays the
engine's to preview — as before, and without a word about it.

One visible difference: a page has to be *made* before it can be drawn. The
first sight of a given page costs a `pdftoppm` run (~250 ms for an A4 page),
during which the preview window says `rendering the page…` — a line that is
taken back out the tick before the page is drawn, because the picture covers
only its own box and anything left beside it would stay on screen. After that
the page is cached on disk by images.nvim and the draw is immediate, in this
session and every later one. A page that will not rasterize — an encrypted or
damaged file — falls back to the engine's own text preview rather than leaving
that line on screen.

Which page and at what resolution is images.nvim's setting, not one of ours:

```lua
require("images").setup({
  pdf = { enabled = true, page = 1, dpi = 120 },
})
```

## Switching it on (and off)

Nothing to switch on: it is active as soon as images.nvim is installed and the
terminal can draw. To keep the text preview anyway:

```lua
require("pickers").setup({
  images = { enabled = false },
})
```

`:checkhealth pickers` reports which of the three states applies — switched
off, images.nvim not installed, or active — because the three need three
different fixes.

## Engine coverage

| Engine | Image and PDF preview | How |
| --- | --- | --- |
| snacks.nvim | yes — `pick_files`, `smart`, `pick_item` | a `preview` function per call; other entries fall through to snacks' own `preview.file`, which is what those sources use by default anyway |
| telescope.nvim | yes — `pick_files`, `pick_item` | a `previewer` object per call: telescope's own `previewers.cat` with one branch in front of it |
| fzf-lua | no — use its own | its builtin previewer is driven by the fzf process, with no per-call Lua hook, and it already ships image support of its own |

Two documented gaps rather than oversights:

**telescope's `smart` keeps the grep previewer.** A smart list interleaves
file rows with grep rows, and a grep row has to land on its matched line — a
capability the image previewer would have to reimplement in order to hand it
back. Use the file picker for browsing images on telescope, or snacks, where
the fallback previewer handles both natively.

**fzf-lua previews images through fzf-lua.** It has an `extensions` mechanism
for exactly this, mapping a file extension to a command that renders into the
preview pane:

```lua
require("fzf-lua").setup({
  previewers = {
    builtin = {
      extensions = {
        ["png"] = { "chafa", "<file>" },
        ["jpg"] = { "chafa", "<file>" },
      },
    },
  },
})
```

Same class of capability gap as its in-picker history keys (see
[KEYS](KEYS.md)): the engine owns the mechanism, and the honest answer is to
point at it rather than to fake it from outside.

## How it is wired

The dependency runs one way only. images.nvim exposes a three-function surface
for foreign pickers — `images.integrations.picker` with `available()`,
`is_previewable(path)` and `preview(winid, file)` — and pickers.nvim calls it.
Nothing here requires images.nvim; without it `available()` is false and every
engine keeps its own previewer, exactly as before. The PDF half arrived on that
same surface and cost the adapters one word: `is_previewable()` where they used
to ask `is_image()`. An older images.nvim without it falls back to `is_image()`
rather than going dark, so the two plugins update in either order.

Three checks decide, in this order:

1. `images = { enabled = … }` — the user's opt-out, honoured first.
2. images.nvim installed, and exposing that surface.
3. images.nvim reports that this terminal can draw at all.

Step 3 is stricter here than in images.nvim's own commands, deliberately.
`:Image show` warns on an unrecognised terminal and draws anyway, because
detection is a heuristic (the iTerm2 protocol has no capability query) and a
false negative must not break a working setup. A picker preview inverts that
trade: taking the window over and drawing nothing leaves it empty, where the
engine's text preview would have worked. On a terminal that draws but is not
recognised, images.nvim's own `display.assume_supported = true` settles it.

The drawn image is an overlay on the terminal, not content in the window's
buffer — the protocol has no image ids, so it can only be repainted away.
Moving from an image entry to a text entry therefore clears explicitly, and a
closing preview window is cleaned up by images.nvim itself.

One more thing follows from a PDF page being drawn *later* than the entry was
selected: the fall-through to the engine's previewer has to survive the wait,
and it must not fire once the selection has moved on. Both adapters therefore
pass their fallback as a completion callback, and
`pickers.integrations.images.preview()` silences it as soon as a newer preview
(or a `clear()`) has replaced it — otherwise a page that failed two entries ago
would overwrite what the engine has just correctly put in the window.

- **Module:** [`integrations/images/init.lua`](../../lua/pickers/integrations/images/init.lua),
  [`adapters/snacks.lua`](../../lua/pickers/integrations/images/adapters/snacks.lua),
  [`adapters/telescope.lua`](../../lua/pickers/integrations/images/adapters/telescope.lua)
- **Config:** `images.enabled` (default `true`); which page and at what
  resolution is images.nvim's `pdf = { … }`
- **Dependency:** [images.nvim](https://github.com/StefanBartl/images.nvim),
  soft and `pcall`'d — absent, nothing changes. PDF pages additionally need
  [pdfport.nvim](https://github.com/StefanBartl/pdfport.nvim) and `pdftoppm`,
  both of which images.nvim reaches, never this plugin
- **Health:** `:checkhealth pickers` → "image previews (images.nvim)", which
  reports the PDF half as a line of its own

## The other direction

images.nvim has an image browser of its own: `:Image pickers [cfile|cwd|path]`
walks a directory tree for image files and previews them the same way, with
`<Tab>` multi-select whose confirm opens the marked images as one gallery.
That one is images.nvim's picker, bound directly to snacks.picker; this page
is about the reverse case, where pickers.nvim owns the picker and the images
are whatever happened to be in the results. The two sit side by side — use
`:Image pickers` to go looking for images, and this to see them on the way
past.
