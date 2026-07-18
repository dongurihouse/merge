# Picture-Book — Lines & Recipes (content reference)

Companion to `docs/superpowers/specs/2026-07-17-picturebook-scenes-design.md`. Lists the generator
**lines** (item ladders) and the per-item **stage recipes** for the 6-page v1. **All tiers and
quantities are PROVISIONAL** — the economy-sim re-pass owns the exact numbers; this fixes the roster,
the recipe shapes, and the cross-zone dependency web.

Notation: `N× line·tT` = deliver N items of `line` at tier T. Cross-page borrows are marked *(Page N)*.
Every line is a 12-tier merge ladder. Difficulty ramps per page (P1 asks ~t2–5, P6 ~t7–10); borrowed
old lines are asked at comfortable mid tiers, since you've owned that generator since its page.

---

## 1 · The line roster (20 base + 6 craftable specials)

**Evergreen anchors — present on every page:**

| id | name | notes |
|---|---|---|
| `wildflower` | Wildflower | the never-retiring FTUE anchor; low-tier glue in most recipes |
| `acorn_caps` | Acorn-caps | forage staple; mid-tier glue across pages |

**Page-signature lines — 3 new per page, joined to the permanent library on page unlock:**

| Page | id | name |
|---|---|---|
| P1 Snowy Village | `snowballs` | Snowballs |
| | `pinecones` | Pinecones |
| | `woolens` | Woolens (mittens/scarves) |
| P2 Autumn Orchard | `apples` | Apples |
| | `pumpkins` | Pumpkins |
| | `leaves` | Fallen Leaves |
| P3 Desert Oasis | `dates` | Dates |
| | `spices` | Spices |
| | `waterskins` | Waterskins |
| P4 Coral Reef | `shells` | Shells |
| | `pearls` | Pearls |
| | `kelp` | Kelp |
| P5 Cherry-Blossom Garden | `blossoms` | Blossoms |
| | `koi` | Koi |
| | `tea_leaves` | Tea-leaves |
| P6 Fairy Hollow | `glowshroom` | Glow-mushrooms |
| | `fireflies` | Fireflies |
| | `wildberries` | Wildberries |

**Craftable specials — 1 per page (optional; crafted by merging two of the page's signature lines, no
generator of their own):**

| Page | id | name | recipe (craft) |
|---|---|---|---|
| P1 | `gingerbread` | Gingerbread | `woolens` + `pinecones` |
| P2 | `cider` | Cider | `apples` + `pumpkins` |
| P3 | `mint_tea` | Mint Tea | `spices` + `waterskins` |
| P4 | `treasure` | Sunken Treasure | `shells` + `pearls` |
| P5 | `mochi` | Mochi | `blossoms` + `tea_leaves` |
| P6 | `wish_potion` | Wish-potion | `glowshroom` + `wildberries` |

**Total:** 20 base generator lines + 6 specials = 26 lines. Base count grows **+3 per future page**.

---

## 2 · The cross-zone web (which old lines each page borrows)

Later pages pull 1–2 earlier lines into their later-stage recipes, so no generator goes dead:

| Page | borrows from earlier pages |
|---|---|
| P1 Snowy Village | — (own lines + evergreen) |
| P2 Autumn Orchard | `pinecones`, `woolens` (P1) |
| P3 Desert Oasis | `apples` (P2), `pinecones` (P1) |
| P4 Coral Reef | `waterskins` (P3), `pumpkins` (P2) |
| P5 Cherry-Blossom | `pearls` (P4), `dates` (P3) |
| P6 Fairy Hollow | `kelp` (P4), `blossoms` (P5), `pinecones` (P1) |

---

## 3 · Per-page item recipes

Each item completes over its stages; delivering a stage's recipe advances it. `built` = final stage
done. (~backdrop items are build-only, tiny/no recipe.)

### P1 · Snowy Village *(asks ~t2–t5; no borrows)*

| Item | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|
| Log Cabin | 3× wildflower·t2 · 2× pinecones·t2 | 4× pinecones·t3 · 3× woolens·t3 | 3× woolens·t4 · 2× snowballs·t4 · 4× pinecones·t4 |
| Snowman | 3× snowballs·t2 · 2× wildflower·t3 | 4× snowballs·t4 · 2× woolens·t3 | — |
| Skating Pond | 3× snowballs·t3 · 3× wildflower·t3 | 4× snowballs·t5 · 3× pinecones·t4 | — |
| Lit Pine Trees | 3× pinecones·t3 · 2× acorn_caps·t3 | 4× pinecones·t5 · 3× woolens·t4 | — |
| Sled | 2× woolens·t3 · 3× pinecones·t3 | 3× woolens·t5 · 2× snowballs·t5 | — |
| Gift Stall | 3× woolens·t4 · 2× wildflower·t4 | 4× woolens·t5 · 3× snowballs·t5 · 2× acorn_caps·t4 | — |
| Lantern Posts | 2× acorn_caps·t3 · 3× pinecones·t3 | 3× snowballs·t5 · 2× woolens·t5 · 1× gingerbread·t2 | — |
| *~Falling Snow* | *build-only (2× wildflower·t2)* | | |

### P2 · Autumn Orchard *(asks ~t3–t6; borrows pinecones, woolens)*

| Item | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|
| Apple Trees | 3× apples·t3 · 2× wildflower·t3 | 4× apples·t5 · 3× leaves·t4 | 3× apples·t6 · 2× pinecones·t5 *(P1)* |
| Hay Bales | 3× leaves·t3 · 2× acorn_caps·t4 | 4× leaves·t5 · 2× pumpkins·t4 | — |
| Scarecrow | 3× pumpkins·t4 · 2× woolens·t4 *(P1)* | 4× pumpkins·t6 · 3× leaves·t5 | — |
| Cider Press | 3× apples·t4 · 2× pumpkins·t4 | 3× cider·t2 · 4× apples·t6 | — |
| Pumpkin Patch | 3× pumpkins·t3 · 3× wildflower·t4 | 4× pumpkins·t6 · 2× leaves·t5 | — |
| Wooden Cart | 2× pinecones·t5 *(P1)* · 3× leaves·t4 | 3× pumpkins·t6 · 2× apples·t6 | — |
| Picnic Table | 3× leaves·t4 · 2× apples·t5 | 3× woolens·t6 *(P1)* · 2× cider·t3 | — |
| *~Drifting Leaves* | *build-only (2× leaves·t3)* | | |

### P3 · Desert Oasis *(asks ~t4–t7; borrows apples, pinecones)*

| Item | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|
| Palm Trees | 3× dates·t4 · 2× wildflower·t4 | 4× dates·t6 · 3× waterskins·t5 | 3× dates·t7 · 2× spices·t6 |
| Caravan Tent | 3× spices·t4 · 2× waterskins·t5 | 4× spices·t6 · 3× dates·t6 | 2× mint_tea·t3 · 3× spices·t7 |
| Camel | 3× waterskins·t5 · 2× dates·t5 | 4× waterskins·t7 · 2× apples·t6 *(P2)* | — |
| Stone Well | 3× waterskins·t4 · 3× wildflower·t5 | 4× waterskins·t7 · 2× spices·t6 | — |
| Woven Rugs | 3× spices·t5 · 2× pinecones·t6 *(P1)* | 4× spices·t7 · 3× dates·t7 | — |
| Hanging Lanterns | 2× acorn_caps·t5 · 3× spices·t5 | 3× dates·t7 · 2× mint_tea·t4 | — |
| Spice-Market Stall | 3× spices·t6 · 2× dates·t6 | 4× spices·t7 · 3× apples·t6 *(P2)* · 2× waterskins·t7 | — |
| Fountain | 3× waterskins·t6 · 2× wildflower·t6 | 3× waterskins·t8 · 2× spices·t7 | — |

### P4 · Coral Reef *(asks ~t5–t8; borrows waterskins, pumpkins)*

| Item | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|
| Coral Fans | 3× shells·t5 · 2× wildflower·t5 | 4× shells·t7 · 3× kelp·t6 | 3× shells·t8 · 2× pearls·t7 |
| Sunken Ship | 3× kelp·t5 · 2× waterskins·t6 *(P3)* | 4× kelp·t7 · 3× shells·t7 | 2× treasure·t3 · 3× kelp·t8 |
| Treasure Chest | 3× pearls·t6 · 2× shells·t6 | 3× treasure·t2 · 4× pearls·t8 | — |
| Anemones | 3× kelp·t5 · 3× wildflower·t6 | 4× kelp·t7 · 2× shells·t7 | — |
| Giant Clam | 3× pearls·t6 · 2× shells·t7 | 4× pearls·t8 · 3× kelp·t7 | — |
| Kelp Beds | 3× kelp·t5 · 2× pumpkins·t6 *(P2)* | 4× kelp·t8 · 2× shells·t7 | — |
| Mermaid Statue | 3× pearls·t7 · 2× shells·t7 | 4× pearls·t8 · 3× kelp·t8 · 2× waterskins·t7 *(P3)* | — |
| *~Bubble Streams* | *build-only (2× kelp·t5)* | | |

### P5 · Cherry-Blossom Garden *(asks ~t6–t9; borrows pearls, dates)*

| Item | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|
| Sakura Trees | 3× blossoms·t6 · 2× wildflower·t6 | 4× blossoms·t8 · 3× tea_leaves·t7 | 3× blossoms·t9 · 2× koi·t8 |
| Red Arched Bridge | 3× tea_leaves·t6 · 2× dates·t7 *(P3)* | 4× tea_leaves·t8 · 3× blossoms·t8 | — |
| Koi Pond | 3× koi·t6 · 3× wildflower·t7 | 4× koi·t8 · 2× pearls·t8 *(P4)* | 3× koi·t9 · 2× blossoms·t9 |
| Stone Lanterns | 2× acorn_caps·t7 · 3× tea_leaves·t7 | 3× blossoms·t9 · 2× mochi·t3 | — |
| Tea Pavilion | 3× tea_leaves·t7 · 2× koi·t7 | 3× mochi·t2 · 4× tea_leaves·t9 | — |
| Bonsai | 3× blossoms·t7 · 2× tea_leaves·t8 | 4× blossoms·t9 · 3× koi·t8 | — |
| Torii Gate | 3× blossoms·t8 · 2× pearls·t8 *(P4)* | 4× blossoms·t9 · 3× tea_leaves·t9 · 2× dates·t8 *(P3)* | — |
| *~Drifting Petals* | *build-only (2× blossoms·t6)* | | |

### P6 · Fairy Hollow *(asks ~t7–t10; borrows kelp, blossoms, pinecones)*

| Item | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|
| Glowing Toadstools | 3× glowshroom·t7 · 2× wildflower·t7 | 4× glowshroom·t9 · 3× fireflies·t8 | 3× glowshroom·t10 · 2× wildberries·t9 |
| Firefly Lanterns | 3× fireflies·t7 · 2× acorn_caps·t8 | 4× fireflies·t9 · 3× glowshroom·t9 | — |
| Toadstool Cottage | 3× glowshroom·t8 · 2× pinecones·t7 *(P1)* | 4× glowshroom·t9 · 3× wildberries·t8 · 2× blossoms·t9 *(P5)* | 2× wish_potion·t3 · 3× glowshroom·t10 |
| Wishing Well | 3× wildberries·t7 · 2× kelp·t8 *(P4)* | 4× wildberries·t9 · 2× fireflies·t9 | — |
| Lantern-Vines | 3× fireflies·t8 · 3× wildflower·t8 | 4× fireflies·t10 · 2× glowshroom·t9 | — |
| Fox Den | 3× wildberries·t8 · 2× glowshroom·t8 | 4× wildberries·t9 · 3× fireflies·t9 | — |
| Crescent-Moon Swing | 3× fireflies·t9 · 2× wildberries·t9 | 3× wish_potion·t2 · 4× fireflies·t10 · 2× pinecones·t8 *(P1)* | — |

---

## 4 · Notes for the sim re-pass

- **Quantities/tiers are illustrative.** The sim owns them against the no-strand, sink>faucet, and
  merge-always-pays invariants (grove_spec §5), plus the recipe-depth / cross-zone-reuse dials.
- **Active-slot pressure:** a page's active recipes should never demand more distinct lines than the
  board's deploy cap (~5–6). Above, each page's live demands stay within `own 3 + evergreen 2 + ≤2
  borrowed`, deployed as the stages stagger in.
- **Specials** are optional depth; if cut for v1, replace each special·tT term with more of the page's
  signature lines.
- **Backdrop items** (~) are build-only flavor — keep their recipes trivial so they never gate a page.
