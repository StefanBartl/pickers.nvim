# pickers.nvim — Checklist audits

These lists are **pickers.nvim-specific derivations** of Stefan's shared Lua/Neovim
checklists (in `Notes/MyNotes/Checklists/Lua/`). Each source checklist is applied
to this repo and reduced to what actually matters here, with a concrete status.

Status legend: ✅ done · ⚠️ partial · ❌ open · N/A not applicable to this plugin.

| File | Source checklist |
|---|---|
| [zentrale-prinzipien.md](zentrale-prinzipien.md) | Zentrale-Prinzipien.md (mental audit) |
| [arch-coding.md](arch-coding.md) | Arch&Coding-Regeln.md |
| [schnell-check.md](schnell-check.md) | Checklist.md (Schnell-Check + PR-Review + Coding) |

The remaining Checklist.md sections — sorting algorithms, data-structure
operations, complexity notation, bit tricks — are **N/A**: pickers.nvim
implements none of these; it delegates all listing/sorting to telescope/fzf-lua.

See also [NEOTREE_FEATURES.md](NEOTREE_FEATURES.md) — filetree feature audit for a
future `filetree.nvim`.

Open action items distilled from these audits live in [../ROADMAP.md](../ROADMAP.md).
