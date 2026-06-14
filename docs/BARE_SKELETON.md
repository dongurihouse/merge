# Bare Skeleton — one engine, no clothes (T16)

**Goal (owner 2026-06-14):** strip the game to its mechanical/economic skeleton so the features,
the unlock cadence, and the economy are legible and tunable **separately from the "meat,"** and the
cosmetic layer ("clothes") can be swapped per game. Multiple games, one engine.

## What this pass does (Phase 1)

1. **Cut the old Tidy-Up game entirely.** It was a sealed 15-file reach-zero subsystem with **zero**
   live-Grove references (verified against code). Deleted: `scripts/{board,main,levels,room,districts,
   jobs,econ,progress,session,menu,quests}.gd` + `scenes/{Main,Jobs,Room,Menu}.tscn`. One sever point:
   the `home.gd` "Classic" button (→ `Menu.tscn`) — removed. Old tests dropped: `core/run/map/quest/smoke`;
   `save_tests` trimmed of its `Levels/Progress/Econ` assertions. `Makefile` test list updated.
2. **Archive all art + audio.** Moved `assets/{fx,items,map,rooms,ui,music,sfx}` → `/archive/`
   (gitignored, recoverable on disk). Kept `assets/fonts` (text needs `ui.ttf`), `assets/i18n`
   (translations), and root `icon.png` (app icon, UID-referenced). The game now renders on its existing
   **ResourceLoader fallbacks**: board items → tier-numbered discs, brambles → panels with a gate badge,
   furniture → name chips, POIs → named panels, icons → glyphs, particles → a code dot, audio → silence.
   No placeholder-code was needed; the fallbacks already existed.

## The result

Boots straight to the Grove (`Home.tscn`). Plays as a **labeled wireframe** — every mechanic visible,
unlock gates showing their conditions (`★N`, `Lv N`, "after X"), coin sinks present as placeholders
(coin-cost pins), the full user flow intact. The remaining `grove_content.gd` data tables + the
placeholder renderers **are** the data↔skin seam to formalize next.

## Parked follow-ups (NOT done here)

- **Scrub orphaned `save.gd`** accessors/fields (`record_job`, `buy_decor`, `jobs`/`rooms`/`clients`)
  and `palette.FAMILIES` — inert dead code left from the old game.
- **Formalize the data↔skin seam** (the 3 audit "cracks"): colors → one Theme; content tables → split
  structural vs themed; fallback rendering → an extractable renderer.
- **The coin economy** — coins gate nothing and sink only into cosmetics (dead currency); decide its fate
  in the economy pass.

## How to re-dress (next games)

Drop art back under `res://assets/<dir>/` with the same names (the registries derive paths), set the
`features.gd` flags, and re-skin `palette.gd` — no engine changes. `/archive/assets/` holds the Grove's
original art if you want it back.
