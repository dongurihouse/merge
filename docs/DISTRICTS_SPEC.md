# Tidy Up — Districts Spec (1–8)

The content roadmap for the district ladder. Companion to `archive/TIDY_UP_SPEC.md` (the locked
hierarchy: **TOWN → DISTRICT → CLIENT → JOB**) and `MAP_PROMPTS.md` (the art shopping
lists). Districts 1–3 are LIVE; 4–5 are fully defined (the locked Plants/Kitchenware
expansion); 6–8 are sketches `[sketch]` — themed runway, details to be locked when their
turn comes.

---

## §1 — What makes a district feel different (the theming contract)

Every district differs along SIX axes, all data-driven from `scripts/districts.gd`:

| Axis | What it is | Where it lives |
|---|---|---|
| **Signature family** | The item family that DEBUTS here and dominates its boards | `family` + level grids |
| **Tile identity rule** | A level uses only families debuted so far; the signature family is the most common one on the board. District 1 is pure (it's the tutorial run). **Enforced by `tests/map_tests.gd`** — a mis-themed level fails CI. | level grids |
| **Board tray** | The mat the pockets sit on (laundry mat → bookshelf board → play mat …) | `tray` (fallback: `board_tray.png`) |
| **Board backdrop** | The room behind the board (laundry nook → study → playroom …) | `bg` (fallback: bedroom) |
| **Friction debut** | ONE new wordless mechanic introduced (and then mixed) here | level fields |
| **Client + lump** | The household hiring you: a face, a run of 4–6 jobs, a thank-you line, a one-time coin lump | `client` |

Art is always **optional at ship time** — every axis falls back to the current art, so a
district can go live code-first and re-skin when its images land (that's how 1–3 shipped).

**Board-size band:** each district also occupies a band of the size curve, so later
districts read as "bigger jobs": D1 3×3–5×5 · D2 5×5–5×6 · D3 5×5–6×6 · D4 6×6–6×7 ·
D5 6×7 · D6+ 6×7 plus occasional "big job" boards.

**Run length rule:** a district ships with **4–6 jobs**. (Current runs are thin — 4/3/2 —
Paperleaf and Tumble Park are backfill targets before any new district opens.)

---

## §2 — Live districts (1–3)

| # | District | Family | Client | Friction debut | Tiles | Art still wanted |
|---|---|---|---|---|---|---|
| 1 | **Linen Lane** | Clothes | **Wren** (frazzled parent) · +150 | Locked Drawers (after the core teach) | PURE clothes | card · bust · `tray_clothes` · `bg_linen_lane` |
| 2 | **Paperleaf Court** | Books | **Juniper** (retired teacher) · +150 | Dust Covers (+ Ticket & Shelf goals) | Books-dominant + clothes | card · bust · `tray_books` · `bg_paperleaf` |
| 3 | **Tumble Park** | Toys | **Pip** (energetic kid) · +150 | Tangles + Clear-the-Floor | Toys-dominant + books + clothes | card · bust · `tray_toys` · `bg_tumble` |

---

## §3 — District 4: Sprout Terrace (Plants) — next up

- **Signature family:** Plants, `fam 4` (codes 401–405). Tile ladder: *sprout → seedling →
  potted plant → blooming planter → hanging garden*. Art: `plants_1..5` (512², transparent,
  per ICON_PROMPTS.md conventions).
- **Client:** **Fern** — a soft-spoken greenhouse keeper whose nursery overflowed.
  Thanks line: *"The seedlings have room to grow now — come smell the mint sometime!"*
  Lump: +150 (re-tune at economy freeze).
- **Friction debut: Spilled Pile** (from FRICTION_MECHANICS backlog) — a stack of 2–3 items
  occupying ONE cell; only the top item is grabbable, each merge beside it un-stacks one.
  Visually obvious (a wobbly pile), zero rules text, cozy ("sort the heap").
- **Tile identity:** Plants-dominant + any of clothes/books/toys as minority filler.
- **Boards:** 6×6–6×7 — the first "big job" district; longer solves, bigger payouts.
- **Board look:** `tray_plants` (woven jute / potting tray) · `bg_sprout` (greenhouse porch,
  morning light).
- **Run:** 5 jobs (`sprout_01..05`), drip: pure-intro → +drawers → +covers → +spilled-pile
  debut level → everything medley.
- **Art shopping list (~10):** plants_1–5 · district card · Fern bust · tray · bg
  (+ optional planter drawer skin).

## §4 — District 5: Copper Kettle Row (Kitchenware)

- **Signature family:** Kitchenware, `fam 5` (codes 501–505). Ladder: *teaspoon → teacup →
  stacked bowls → copper pot → full kettle shelf*. Art: `kitchen_1..5`.
- **Client:** **Maslo** — a round, flour-dusted baker drowning in pans before the morning rush.
  Thanks: *"Every pot has its hook again — warm buns on the house, forever."* Lump: +150.
- **Friction debut: Buttoned Hamper** — the any-merge lock variant: a hamper cell that pops
  open after ANY N merges anywhere (a button pops per merge). Complements Drawers
  (adjacent-trigger) without new spatial rules.
- **Tile identity:** Kitchenware-dominant + minorities from any earlier family.
- **Boards:** 6×7 standard, with the first 7×7 "deep clean" finale board.
- **Board look:** `tray_kitchen` (checkered tea towel / butcher block) · `bg_kettle`
  (warm copper-and-tile kitchen).
- **Run:** 5–6 jobs. Drip: intro → +hamper debut → mixes with all prior frictions.
- **Art shopping list (~10):** kitchen_1–5 · card · Maslo bust · tray · bg.

---

## §5 — Sketches (6–8) `[sketch]`

| # | District | Family (codes) | Client | Friction candidate | Notes |
|---|---|---|---|---|---|
| 6 | **Tinker's Yard** | Tools (601–605): *screw → wrench → toolbox → cabinet → workbench* | **Gus**, a humming grandpa tinkerer | **Tidy Conveyor** — the deferred living-inflow belt. NEEDS a design pass: must stay can't-lose (belt pauses when the board is busy, never overflows). If it can't be made chill, fall back to a Spilled-Pile/Hamper medley. | First "workshop" palette break (warm wood + steel blues). |
| 7 | **Maple Desk Office** | Papers (701–705): *loose page → folder → binder → drawer file → tidy archive* | **Quill**, a deadline-swamped writer | **None — the breather district.** All six existing frictions in deliberate combos; mastery, not novelty (mirrors the spec's "new content ≠ new rules" stance). | Star-goal showcase: every level has a skippable ticket so ★★ stays missable. |
| 8 | **Keepsake Attic** | Keepsakes (801–805): *button tin → photo stack → memory box → trunk → heirloom shelf* | **Nana Moss**, sorting a lifetime of treasures | Seasonal/event hooks — the attic re-decorates per season; boards are sentimental "medley" jobs. | The emotional capstone; candidate home for the v2 Collections/Trophy UI. |

---

## §6 — Per-district budget & rollout checklist

**Art budget per new district (~10 images):** 5 tile tiers · 1 district card (1024×512) ·
1 client bust (512²) · 1 tray (1024²) · 1 board backdrop (1080×1920) — prompts follow the
templates in `MAP_PROMPTS.md` (cards/busts §2–3, trays/backdrops §5).

**Rollout checklist (code is ~1 day each once art exists):**
1. `palette.gd` FAMILIES entry (name + art base) — engine/board code needs nothing else.
2. `districts.gd` entry (card/tray/bg/client/jobs).
3. 4–6 authored levels obeying the weight rule + tile identity (map_tests enforce both).
4. Friction debut built behind its level field (the level-design language).
5. i18n rows for names/thanks/hints; `--import`; screenshot pass per state.
