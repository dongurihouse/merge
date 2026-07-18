# Picture-Book — Lines & Recipes (content reference)

Companion to `docs/superpowers/specs/2026-07-17-picturebook-scenes-design.md`. Lists the generator
**lines** and the per-item **stage recipes** for the **5-page v1** (Autumn Orchard removed). **All tiers
and quantities are PROVISIONAL** — the economy-sim re-pass owns the exact numbers; this fixes the
roster, the recipe shapes, and the cross-zone dependency web.

Notation: `N× line·tT` = deliver N items of `line` at tier T. Cross-page borrows are marked *(P#)*.
Every line is a 12-tier merge ladder. Difficulty ramps per page (P1 ~t2–5 → P5 ~t7–10); borrowed old
lines are asked at comfortable mid tiers, since you've owned that generator since its page.

---

## 1 · The line roster — 12 lines (8 base generators + 4 crafted specials)

Play order: **P1 Fairy Hollow → P2 Snowy Village → P3 Desert Oasis → P4 Coral Reef → P5 Cherry-Blossom.**

**Base generators (8)** — produced on the board; accumulate into the permanent library:

| # | id | name | page |
|---|---|---|---|
| 1 | `glowshroom` | Glow-mushrooms | P1 Fairy Hollow *(the FTUE anchor — first generator)* |
| 2 | `wildberries` | Wild Berries | P1 Fairy Hollow |
| 3 | `snowballs` | Snowballs / Ice Sculptures | P2 Snowy Village |
| 4 | `woolens` | Woolens | P2 Snowy Village |
| 6 | `desert_fruits` | Desert Fruits | P3 Desert Oasis |
| 7 | `sand` | Sand / Sand Sculptures | P3 Desert Oasis |
| 9 | `shells` | Shells | P4 Coral Reef |
| 11 | `koi` | Koi | P5 Cherry-Blossom |

**Crafted specials (4)** — no generator of their own; made by merging two ingredient lines (the
cross-zone web lives here):

| # | id | name | page | craft recipe |
|---|---|---|---|---|
| 5 | `winter_berries` | Winter Berries | P2 Snowy Village | `wildberries` (2, P1) + `snowballs` (3) |
| 8 | `spices` | Spices | P3 Desert Oasis | `wildberries` (2, P1) + `woolens` (4, P2) |
| 10 | `corals` | Corals | P4 Coral Reef | `sand` (7, P3) + `snowballs` (3, P2) |
| 12 | `tea_cup` | Tea Cup | P5 Cherry-Blossom | `spices` (8, P3) + `wildberries` (2, P1) |

Notes:
- **No separate evergreen anchor** — `glowshroom` (line 1) is the FTUE starting generator.
- **`tea_cup` is a two-level craft:** its ingredient `spices` is itself a special (`wildberries` +
  `woolens`), so making a tea cup chains `wildberries+woolens → spices`, then `spices+wildberries →
  tea_cup`. The deepest craft in v1.
- **Base count grows +1–2 per future page;** specials keep weaving old lines into new pages.

---

## 2 · The cross-zone web

Every special pulls in lines from earlier pages, so no generator goes dead:

| Special (page) | draws on |
|---|---|
| Winter Berries (P2) | wildberries *(P1)* + snowballs *(P2)* |
| Spices (P3) | wildberries *(P1)* + woolens *(P2)* |
| Corals (P4) | sand *(P3)* + snowballs *(P2)* |
| Tea Cup (P5) | spices *(P3)* + wildberries *(P1)* |

Decorate-item recipes (below) also borrow a base line or two directly from earlier pages.

---

## 3 · Per-page item recipes

Each item completes over its stages; delivering a stage's recipe advances it. `built` = final stage.
(~backdrop items are build-only flavor, trivial recipe.)

### P1 · Fairy Hollow *(lines: glowshroom, wildberries; asks ~t2–t5; no borrows — the FTUE page)*

| Item | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|
| Glowing Toadstools | 3× glowshroom·t2 | 4× glowshroom·t3 · 2× wildberries·t3 | 3× glowshroom·t4 · 3× wildberries·t4 |
| Firefly Lanterns | 3× glowshroom·t2 · 2× wildberries·t2 | 4× glowshroom·t4 · 2× wildberries·t3 | — |
| Toadstool Cottage | 3× wildberries·t3 · 2× glowshroom·t3 | 4× glowshroom·t4 · 3× wildberries·t4 | 3× glowshroom·t5 · 3× wildberries·t5 |
| Wishing Well | 3× wildberries·t3 | 4× wildberries·t4 · 2× glowshroom·t4 | — |
| Lantern-Vines | 2× glowshroom·t3 · 2× wildberries·t3 | 3× glowshroom·t5 · 2× wildberries·t4 | — |
| Fox Den | 3× wildberries·t4 · 2× glowshroom·t4 | 4× wildberries·t5 · 3× glowshroom·t5 | — |

### P2 · Snowy Village *(lines: snowballs, woolens, winter_berries; borrows glowshroom/wildberries P1; asks ~t3–t6)*

| Item | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|
| Log Cabin | 3× woolens·t3 · 2× snowballs·t3 | 4× snowballs·t5 · 3× woolens·t4 | 3× woolens·t6 · 2× winter_berries·t3 |
| Ice Sculptures | 3× snowballs·t3 | 4× snowballs·t5 · 2× woolens·t4 | 3× snowballs·t6 · 2× wildberries·t5 *(P1)* |
| Skating Pond | 3× snowballs·t4 · 2× woolens·t4 | 4× snowballs·t6 · 2× winter_berries·t3 | — |
| Sled | 3× woolens·t4 · 2× snowballs·t4 | 3× woolens·t6 · 2× glowshroom·t5 *(P1)* | — |
| Gift Stall | 3× woolens·t4 · 2× winter_berries·t2 | 4× woolens·t6 · 3× winter_berries·t3 | — |
| Lantern Posts | 2× snowballs·t4 · 3× woolens·t4 | 3× snowballs·t6 · 2× winter_berries·t3 | — |

### P3 · Desert Oasis *(lines: desert_fruits, sand, spices; borrows woolens/wildberries; asks ~t4–t7)*

| Item | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|
| Palm Trees | 3× desert_fruits·t4 · 2× sand·t4 | 4× desert_fruits·t6 · 3× sand·t5 | 3× desert_fruits·t7 · 2× spices·t4 |
| Sand Sculptures | 3× sand·t4 | 4× sand·t6 · 2× desert_fruits·t5 | 3× sand·t7 · 2× snowballs·t6 *(P2 — ice↔sand)* |
| Caravan Tent | 3× spices·t3 · 2× woolens·t5 *(P2)* | 4× spices·t5 · 3× sand·t6 | — |
| Stone Well | 3× sand·t4 · 3× desert_fruits·t5 | 4× sand·t7 · 2× spices·t4 | — |
| Spice-Market Stall | 3× spices·t4 · 2× desert_fruits·t6 | 4× spices·t6 · 3× sand·t7 · 2× wildberries·t6 *(P1)* | — |
| Fountain | 3× sand·t6 · 2× desert_fruits·t6 | 3× sand·t7 · 2× spices·t5 | — |

### P4 · Coral Reef *(lines: shells, corals; borrows sand/snowballs; asks ~t5–t8)*

| Item | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|
| Coral Fans | 3× shells·t5 · 2× corals·t3 | 4× shells·t7 · 3× corals·t5 | 3× shells·t8 · 2× corals·t6 |
| Sunken Ship | 3× shells·t5 · 2× sand·t6 *(P3)* | 4× shells·t7 · 3× corals·t5 | 3× shells·t8 · 2× corals·t6 |
| Treasure Chest | 3× corals·t4 · 2× shells·t6 | 4× corals·t6 · 3× shells·t7 | — |
| Anemones | 3× shells·t5 · 2× corals·t4 | 4× shells·t7 · 2× snowballs·t7 *(P2 — sea-ice)* | — |
| Giant Clam | 3× shells·t6 · 2× corals·t5 | 4× shells·t8 · 3× corals·t6 | — |
| Mermaid Statue | 3× corals·t6 · 2× shells·t7 | 4× corals·t7 · 3× shells·t8 · 2× sand·t7 *(P3)* | — |

### P5 · Cherry-Blossom Garden *(lines: koi, tea_cup; borrows shells/spices/wildberries; asks ~t6–t9)*

| Item | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|
| Sakura Trees | 3× koi·t6 · 2× tea_cup·t3 | 4× koi·t8 · 3× tea_cup·t5 | 3× koi·t9 · 2× tea_cup·t6 |
| Koi Pond | 3× koi·t6 | 4× koi·t8 · 2× shells·t8 *(P4)* | 3× koi·t9 · 2× tea_cup·t5 |
| Red Arched Bridge | 3× tea_cup·t4 · 2× koi·t7 | 4× tea_cup·t6 · 3× koi·t8 | — |
| Tea Pavilion | 3× tea_cup·t5 · 2× koi·t7 | 4× tea_cup·t7 · 3× koi·t8 | — |
| Stone Lanterns | 2× koi·t7 · 3× tea_cup·t4 | 3× koi·t9 · 2× spices·t7 *(P3)* | — |
| Torii Gate | 3× koi·t8 · 2× tea_cup·t6 | 4× koi·t9 · 3× tea_cup·t7 · 2× wildberries·t8 *(P1)* | — |

---

## 4 · Notes for the sim re-pass

- **Quantities/tiers are illustrative.** The sim owns them against no-strand, sink>faucet, and
  merge-always-pays (grove_spec §5), plus recipe-depth / cross-zone-reuse dials.
- **Active-slot pressure:** a page's live demands should stay within the board deploy cap (~5–6 distinct
  lines). Each page above stays within `own 2–3 + ≤2 borrowed` deployed as stages stagger in.
- **Specials are crafted, not generated** — a page's special appears once both ingredient lines are in
  the library (guaranteed by the play order); crafting one is a merge of the two ingredients.
- **Backdrop items** (~) are build-only flavor — keep their recipes trivial so they never gate a page.
