# Picture-Book — Lines & Recipes (content reference)

Companion to `docs/superpowers/specs/2026-07-17-picturebook-scenes-design.md`. Lists the generator
**lines** and the per-item **stage recipes** for the **5-page v1** (Autumn Orchard removed). **All tiers
and quantities are PROVISIONAL** — the economy-sim re-pass owns the exact numbers; this fixes the
roster, the recipe shapes, and the cross-zone dependency web.

Notation: `N× line·tT` = deliver N items of `line` at tier T. Cross-page borrows are marked *(P#)*.
Every line is a 12-tier merge ladder. **Tier rules** (from the 2026-07-17 pacing evaluation, §4):
difficulty scales by **quantity of mid-tier items, not tier exponent** — own base lines cap at **t8**
(plus ONE t9 capstone in the whole book, Torii Gate); **borrowed** old lines cap at **t6**; **specials**
cap at **t5** when borrowed / **t6** on their own page (their per-item cost is 2–3× a base item).

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
| Palm Trees | 3× desert_fruits·t4 · 2× sand·t4 | 4× desert_fruits·t6 · 3× sand·t5 | 3× desert_fruits·t7 · 3× spices·t4 |
| Sand Sculptures | 4× sand·t4 | 4× sand·t6 · 2× desert_fruits·t5 | 3× sand·t7 · 2× snowballs·t6 *(P2 — ice↔sand)* |
| Caravan Tent | 3× spices·t3 · 2× woolens·t5 *(P2)* | 4× spices·t5 · 3× sand·t6 | — |
| Stone Well | 3× sand·t4 · 3× desert_fruits·t5 | 4× sand·t7 · 2× spices·t4 | — |
| Spice-Market Stall | 4× spices·t4 · 2× desert_fruits·t6 | 5× spices·t5 · 3× sand·t6 · 3× wildberries·t5 *(P1)* | — |
| Fountain | 3× sand·t6 · 2× desert_fruits·t6 | 4× desert_fruits·t7 · 2× winter_berries·t4 *(P2)* | — |

### P4 · Coral Reef *(lines: shells, corals; borrows sand/snowballs/glowshroom; asks ~t4–t8)*

| Item | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|
| Coral Fans | 3× shells·t5 · 3× corals·t3 | 4× shells·t7 · 4× corals·t5 | 2× shells·t8 · 2× corals·t6 |
| Sunken Ship | 3× shells·t5 · 3× sand·t6 *(P3)* | 5× shells·t7 · 3× corals·t5 | 2× shells·t8 · 3× glowshroom·t6 *(P1 — bioluminescent wreck)* |
| Treasure Chest | 4× corals·t4 · 2× shells·t6 | 5× corals·t5 · 3× shells·t7 | — |
| Anemones | 4× shells·t5 · 3× corals·t4 | 4× shells·t7 · 3× snowballs·t6 *(P2 — sea-ice)* | 2× shells·t8 · 2× corals·t6 |
| Giant Clam | 3× shells·t6 · 3× corals·t5 | 4× shells·t7 · 2× corals·t6 | 2× shells·t8 · 2× wildberries·t6 *(P1)* |
| Mermaid Statue | 4× corals·t5 · 2× shells·t7 | 3× corals·t6 · 2× shells·t8 · 2× sand·t6 *(P3)* | 2× shells·t8 · 2× corals·t6 · 2× winter_berries·t5 *(P2)* |

### P5 · Cherry-Blossom Garden *(lines: koi, tea_cup; borrows from every page; asks ~t3–t8 + the one t9 capstone)*

| Item | Stage 1 | Stage 2 | Stage 3 | Stage 4 |
|---|---|---|---|---|
| Sakura Trees | 3× koi·t6 · 3× tea_cup·t3 | 5× koi·t7 · 4× tea_cup·t4 | 3× koi·t8 · 5× tea_cup·t5 | 3× koi·t8 · 4× tea_cup·t5 · 2× winter_berries·t5 *(P2)* |
| Koi Pond | 4× koi·t6 | 5× koi·t7 · 4× shells·t6 *(P4)* | 3× koi·t8 · 3× tea_cup·t5 | 3× koi·t8 · 4× shells·t6 *(P4)* · 2× glowshroom·t6 *(P1 — night pond)* |
| Red Arched Bridge | 4× tea_cup·t4 · 2× koi·t7 | 6× tea_cup·t5 · 3× woolens·t6 *(P2)* | 3× koi·t8 · 4× spices·t5 *(P3)* | — |
| Tea Pavilion | 4× tea_cup·t4 · 2× koi·t7 | 7× tea_cup·t5 · 4× desert_fruits·t6 *(P3)* | 3× koi·t8 · 5× tea_cup·t5 | — |
| Stone Lanterns | 3× tea_cup·t4 · 2× koi·t7 | 4× koi·t8 · 4× glowshroom·t6 *(P1)* | 5× tea_cup·t5 · 3× sand·t6 *(P3)* | — |
| Torii Gate | 3× koi·t8 · 3× tea_cup·t5 | 3× koi·t8 · 4× tea_cup·t5 · 3× wildberries·t6 *(P1)* | **1× koi·t9 (the book's capstone)** · 4× corals·t5 *(P4)* · 3× winter_berries·t5 *(P2)* | — |

---

## 4 · Pacing & economy evaluation (2026-07-17)

Model: effort in clicks (a base item·tT costs `2^(T-1)` clicks; a one-level special 2×; tea_cup 3×);
coins per delivery via the live quest_reward fold (`clicks/7 + clicks/cpc[band]·1.05^(t-4)`); level from
the coin clock (`LEVEL_BASE_COINS 30 / STEP 12`). Owner call (2026-07-17): **keep the ~19K-click total**
(≈3+ weeks engaged free play) and fix distribution only. The tables in §3 ARE the revised set; its
measured curve:

| Page | clicks | cum | ×prev | worst stage | page-end level |
|---|---|---|---|---|---|
| P1 Fairy Hollow | 592 | 592 | — | 112 | L4 |
| P2 Snowy Village | 1,128 | 1,720 | 1.91 | 152 | L8 |
| P3 Desert Oasis | 2,424 | 4,144 | 2.15 | 304 | L13 |
| P4 Coral Reef | 5,192 | 9,336 | 2.14 | 512 | L22 |
| P5 Cherry-Blossom | 8,780 | 18,116 | 1.69 | 672 | L33 |

**Total ≈ 18.1K clicks · ~7.0K coins · book ends ≈ L33.** Utilization after revision: koi 28% · shells
19% · tea_cup 13% · corals 9% · sand 7% · every other line 2–5% (nothing dead; was koi 32% + winter_
berries 0%). Deploy pressure: ≤5 generators per page (fits the cap).

**What the revision fixed** (vs the first draft): single-stage walls cut 1,856→672 max (difficulty now
scales by QUANTITY of mid-tier items, not tier exponent); exactly ONE t9 ask in the book (Torii Gate's
capstone); specials asked ≤t5 borrowed / ≤t6 own-page; borrowed lines ≤t6; P4/P5 borrow from every
earlier page (their 2-line rosters were concentrating 76% of the book on 3 lines).

**Watch items for the sim re-pass:**
- **koi at 28%** is the ceiling case — if P5 play-feels monotonous, either add a 2nd P5 base line or
  shift more P5 bulk onto tea_cup (whose crafting itself runs 3 other generators).
- **`endgame_clicks` (economy_tuning.json) is stale at 4,300** — tuned for the retired 25-spot arc.
  Re-anchor to ≈18,000 when the sim re-runs (owner dial; not changed here).
- The sim re-proves no-strand, sink>faucet, merge-always-pays (grove_spec §5) on these recipes, and
  owns all exact quantities/tiers.
- **Active-slot pressure:** a page's live demands stay within the deploy cap (~5–6 distinct
  generators); each page above needs ≤5 (`own 2–3 + ≤2 borrowed`), staggered by stage.
- **Specials are crafted, not generated** — available once both ingredient lines are in the library
  (guaranteed by play order).
- **Backdrop items** (~) are build-only flavor — keep their recipes trivial so they never gate a page.
