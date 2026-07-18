# Picture-Book Scenes — the decorate-and-turn spend surface

**Date:** 2026-07-17
**Supersedes:** `2026-07-17-acorn-forest-journey-design.md` (the lantern-trail journey).
**Builds on:** the shipped home build-and-upgrade model (`2026-07-17-home-build-upgrade-map-design.md`).
**Decision:** The game's spend surface is a **picture book**. Each **page** is one self-contained scene
full of things you **unlock, upgrade, and customize**. Fill a page in completely → **turn to the next
page**: the same art style and the same mechanic, but a **completely different scene with different
things**. No hub, no home base, no journey, no story thread. The variety between pages *is* the point —
it makes the player feel they're working somewhere genuinely new, not repainting one place.

## 1 · The model

- The spend surface is an ordered **book of pages**. Only the current **frontier** page is being
  completed; earlier pages stay **browsable** (flip back to keep customizing — the whole book is yours).
- A **page** = a distinct scene (a season, a biome, an occasion) with **6–10 items** native to it.
- Every **item** builds out in **stages**, each completed by delivering a **recipe** of merge-items
  (§7), then is **customizable** among many generated variations.
- A page is **complete** when all its items are built. Completing the frontier page **turns to the next
  page** (unlocks the next scene) and grants **exactly ONE resident-bucket cell** (decision 2026-07-17:
  one cell per zone/page — not a bundle; v1 book = 5 cells total).
- The merge **board** is the engine that feeds the book. Its **generators accumulate into a permanent
  library** whose lines are reused across pages (§7), so the board deepens as you go. The **coin clock**
  and the **resident bucket** carry over; page-completion is the bucket's new cell source.

## 2 · The pull (why the player keeps playing)

1. **Completion.** Fill in the current page — a clear, satisfying "finish the picture" goal.
2. **Curiosity.** Every next page is a *completely different* place — what's page 7? A pull that never
   runs dry, because pages are diverse by construction (different biome/season/occasion), not reskins.
3. **Self-expression + collection.** Each item carries many variations; a page is both "complete it" and
   "make it yours," and the browsable book means your whole gallery stays personal and revisitable.

## 3 · What carries / what changes

**Carries over (from the shipped model):** the pure build module (`home_build.gd` — unlock steps,
level+coin gate, customize), the Save adapter (`home.gd`), the layered scene renderer
(`home_zone_view.gd` — foundation + items, painter-sorted, single input surface), the coin clock, the
resident bucket, and the merge board.

**Changes:** the single "one evolving home" becomes an **ordered sequence of pages**; add page-turn
(frontier completion → next page unlocks) and page browsing. Cell-grants move from per-building to
**per-page completion** — one cell per completed page.

**Dropped (from the superseded journey spec):** keystones, next-zone reveal, misty silhouettes, the
wake beat, creature→resident wiring, the world-pan camera, and any narrative thread. A page simply
completes and turns.

## 4 · Page & item model

**Page** (one per scene): `{id, index, label, foundation, canvas, items:[…]}`. The renderer draws ONE
page at a time, fit to the viewport (exactly as the home zone renders today).

**Item** (the only element type — no roles/keystones): every item **builds out in stages → customize**.
- `states`: the build progression `empty → stage1 → … → built` (art per stage).
- `stages`: `[{recipe, min_level, shows_state}]` — each stage is completed by delivering a **recipe**
  of merge-items (§7), not a flat coin cost. 2+ stages; a min-level per stage still paces. The recipe
  is the primary sink for board output; **staggered** so a page's demands (and the lines it needs)
  evolve as it builds out — the freshness engine for a long page.
- `customizations`: `[{id, set, texture, cost:{coins|diamonds}}]` — the variation skins, offered once
  the item is **built**. Optional, never blocks page completion.
- A minority of items may be **backdrop** (build-only, no `customizations`) where variation would read
  as noise (drifting leaves, falling snow) — but the default is customizable, since customization is
  the point.

Page completion = every item `built`. (Customization is *not* required to turn the page — it's the
optional beautify/collection layer, available anytime, including on flipped-back pages.)

## 5 · Progression & economy

- **Build stages** are completed by delivering **recipes** (item deliveries, §7) — the primary sink
  for board output — with a per-stage min **level** gate (lifetime earned coins) as the pacing brake.
  Coins remain a secondary currency (merge drops, selling) for **customization** + speed-ups. The exact
  split (recipe sizes vs. coin costs) is the sim re-pass's call.
- **Page turn:** completing the frontier page unlocks the next page, plays a short **page-turn
  transition**, and grants **one resident-bucket cell** (capacity drip — a fixed 1 per page, decision
  2026-07-17). Level-ups keep gifting water/diamonds as today.
- **Customization** is a coins/diamonds sink, cosmetic-only (grove_spec §5 guardrails), themed into
  **sets** for collection; premium/seasonal variations are the diamond cosmetic sink the economy wants.
- **Residents** (global bucket) produce coins in the background and remain the endgame collection/
  Expedition loop — decoupled from any one page. *(Decision: kept + fed by page completion. Revisitable
  — a purely cosmetic book with no residents is possible, but retiring residents removes the v1 coin
  faucet + endgame, so the default keeps them.)*
- **Invariants for the sim re-pass** (deferred): no-strand (an affordable next item step always exists
  at nominal coin flow), sink > faucet (build ladder + customization vs. the faucet), cells = one per
  completed page (fixed — not a sim dial).

## 6 · Example pages (content)

Illustrative — the final roster/order and all art are a content/pipeline task. Each item is
unlock-in-steps + customize-with-variations; a few `~backdrop` items are build-only.

The **5-page v1**, in play order (Autumn Orchard removed):

| # | Page (scene) | Items (unlock · upgrade · customize) |
|---|---|---|
| 1 | **Fairy Hollow** *(night forest — the FTUE page)* | glowing toadstools · firefly lanterns · toadstool cottage · wishing well · lantern-vines · fox den |
| 2 | **Snowy Village** *(winter)* | log cabin · ice sculptures · skating pond · sled · gift stall · lantern posts · *~falling snow* |
| 3 | **Desert Oasis** | palm trees · sand sculptures · caravan tent · stone well · spice-market stall · fountain |
| 4 | **Coral Reef** *(underwater)* | coral fans · sunken ship · treasure chest · anemones · giant clam · mermaid statue · *~bubble streams* |
| 5 | **Cherry-Blossom Garden** *(spring)* | sakura trees · koi pond · red arched bridge · tea pavilion · stone lanterns · torii gate · *~drifting petals* |

Extensible without limit: pumpkin patch, seaside pier, lavender field, mountain shrine, lighthouse
cove… Every page's items are native to that scene, so completing page 4 feels nothing like page 1.
**Example variation sets** (per item, generated by the pipeline): a *toadstool cottage* in Classic ·
Spotted · Mossy · Lantern-Hung · Frosted · Twilight; a *tent* in Striped · Patched · Silk · Woven ·
Royal; a *koi pond* in Calm · Lily-Covered · Bridge-Lit · Blossom. (Sets support collection + seasonal
drops.)

## 7 · Generators, library & recipes (the board side)

The merge **board** is the engine that feeds the book: generators produce item lines, you merge them,
and you **deliver recipes** to build out the current page's items. Design (decided: *library + deploy,
moderate chains*):

**Generators = a permanent, accumulating library.**
- A **generator** produces one **item line** (a 12-tier merge ladder), as today.
- **8 base generators** (2–3 new per page, themed to the scene) + **4 crafted specials** (no generator
  of their own — merged from two ingredient lines). `glowshroom` (P1) is the FTUE anchor. There are
  **no separate evergreen anchors** — the lean roster starts from page 1's lines.
- Generators **accumulate** into a permanent **library** — **never retired, never sold**. Every line
  stays valuable because later recipes (and the specials) keep calling it back (below).

**The library & deploy (board management).**
- You own every unlocked generator in a **library/shelf**. Only a bounded **active set** (~5, ≤
  `QUEST_GEN_CAP`) sits on the board producing at once; you **deploy/swap** from the library based on
  what the current buildout recipes need — a light strategic beat that also refreshes play. Reuse the
  existing `gen_bag` as the storage substrate; the active-slot cap stays fixed however big the library
  grows (so the board never jams — the `POP_LINE_CAP` reason).

**Multi-stage buildout + recipes (the sink).**
- Each decorate item builds out in **stages** (§4); each stage is completed by delivering a **recipe** —
  a set of merge-items mixing the page's **new-line** items and **earlier pages' line items**.
- Lines **stagger in** across a page's stages, so the board's demands evolve *within* a long page.
- Delivering recipes is the primary sink for board output; completing every item's stages completes the
  page.

**Cross-zone chains — moderate, mostly via specials.** Each **special** is crafted from two ingredient
lines drawn across pages (e.g. Snowy's *Winter Berries* = Wild Berries from Fairy + Snowballs), so the
cross-zone web is baked into the roster; decorate recipes also borrow 1–2 earlier base lines directly.
Never deep dependency trees (`tea_cup`'s two-level craft is the deepest). This keeps old generators
earning their keep and weaves the book together, while staying readable and mostly cozy.

**The count.** **8 base generators + 4 crafted specials = 12 lines for the 5-page v1** — lean and each
reused across pages. Base count grows **+1–2 per future page**; the real constraint is the **active slot
cap** (~5), not the library size.

**The v1 line roster** (play order; each a 12-tier line; specials in italics):

| # | Page | Base lines | *Special (craft)* |
|---|---|---|---|
| 1–2 | **Fairy Hollow** | Glow-mushrooms *(anchor)* · Wild Berries | — |
| 3–5 | **Snowy Village** | Snowballs/Ice · Woolens | *Winter Berries (WildBerries+Snowballs)* |
| 6–8 | **Desert Oasis** | Desert Fruits · Sand | *Spices (WildBerries+Woolens)* |
| 9–10 | **Coral Reef** | Shells | *Corals (Sand+Snowballs)* |
| 11–12 | **Cherry-Blossom** | Koi | *Tea Cup (Spices+WildBerries)* |

The **full 12-line roster, the special craft recipes, the cross-zone web, and every item's stage
recipes** for the 5-page v1 are authored in `docs/design/picturebook_lines_recipes.md` (tiers/quantities
PROVISIONAL — the sim re-pass owns them).

**Economy integration** is deferred to the sim re-pass: recipes are the primary sink, coins/level the
pacing + customization sink; recipe sizes, tiers, coin costs, and the cross-zone reuse rate are its
numbers to tune. This spec fixes the STRUCTURE (accumulate + library/deploy + multi-stage recipes +
moderate cross-zone), not the values.

## 8 · Data model (concrete)

```
book.json
{
  "version": 1,
  "pages": [
    {
      "id": "fairy_hollow", "index": 0, "label": "Fairy Hollow",
      "foundation": "res://.../pages/fairy_hollow.png",
      "canvas": [941, 1672],
      "items": [
        {"id": "fh_toadstools", "position": [..], "display_size": [..], "sort_y": ..,
         "states": [{id,texture}, ...],
         "stages": [{recipe:[{line, tier, qty}, ...], min_level, shows_state}, ...],
         "customizations": [{id, set, texture, cost:{coins|diamonds}}, ...]},
        ...
      ],
      "generators": ["glowshroom", "wildberries"]   // this page's new base lines
    },
    { "id": "snowy_village", "index": 1,
      "generators": ["snowballs", "woolens"],
      "specials": [{"id": "winter_berries", "craft": ["wildberries", "snowballs"]}], ... },
    ...
  ]
}
```

- `grove_data` gains a `PAGES` gameplay table (per-item **stage recipes**/min_level, per-page signature
  generator ids; cells need no per-page field — every page grants 1) parallel to today's `BUILDINGS`, plus a `GENERATORS` roster
  extended to the accumulating library; the `book.json` manifest carries art + placement + variations.
  All numbers **PROVISIONAL** (economy-sim re-pass owns them).
- **Save:** `Save.grove()["book"] = {frontier, viewing}`; `["home"]` per-item `built`/`custom` (item ids
  unique across pages); `["gen_library"]` = owned generator ids; the existing `gen_bag` / board `gens`
  hold the **deployed active set**. A page completes when all its items are built; the frontier advances
  on completion; a recipe delivery advances an item's current stage.

## 9 · System architecture

Extends the shipped `home_build.gd` / `home.gd` / `home_zone_view.gd` and the board's generator/quest
layer:

- **`home_build.gd`** (pure): generalize one building set → a **book of pages**; items advance by
  **recipe delivery** per stage (`can_advance(item, delivered)`, `advance_stage`); add
  `page_complete`, `next_page`, `page_cells`. Customize rules unchanged.
- **`home.gd`** (adapter): `frontier()`, `viewing()`, `set_viewing(id)` (≤ frontier); `deliver(item_id,
  items)` advances a stage and, on the stage that completes the last item of the frontier page, advances
  the frontier + grants the page's single cell; `cells_total()` = the count of completed pages.
- **Generator library** (extends the existing gen/gen_bag): `library()` (owned), `deploy(gen_id)` /
  `stow(gen_id)` moving generators between the library and the board's bounded active set; a page's
  base generators join the library when the page becomes frontier; specials are crafted once their
  ingredient lines are owned.
- **Recipes ↔ quests:** the existing giver-fence/quest delivery mechanic becomes the surface for a
  page's **current stage recipes** — deliver the asked merge-items to advance the buildout. (Reuses
  `quests.gd` / `board_actions.deliver_quest`; the "reward" becomes stage progress + the coin/customize
  economy on top.)
- **`home_zone_view.gd`** (renderer): draw the **viewed page** (foundation + items by build state,
  painter-sorted, single input surface) — one page fit to the viewport, as today. Add a **page-turn**
  transition and a small **page nav** (prev/next within unlocked pages). No world camera, no silhouettes.
- **Scene (`map.gd`)**: the tap → build/customize dialogs act on the viewed page's items; a build tap
  now shows the item's **stage recipe** (what to deliver) instead of a flat coin price. Resident dock +
  chrome unchanged.

## 10 · Testing

- **Pure module** (headless): a stage advances iff its recipe is delivered (incl. cross-page line
  items); `page_complete` true iff all items built; frontier advances exactly once; `page_cells`
  idempotent; `set_viewing` refuses pages past the frontier; `deploy`/`stow` respect the active-slot
  cap and never lose a library generator; save round-trip of book + gen_library + item state.
- **Renderer** (headless node-tree): the viewed page renders one node per item at its build state,
  painter-sorted, single input surface; the page nav lists only unlocked pages; the variation picker
  lists owned + buyable variations for a built item; the build dialog shows the current stage recipe.
- **Screenshots** (`quiet_godot`): 3–4 *different* pages built + mid-build, and a customized vs default
  item — proving the scenes read as genuinely distinct (the whole point) for the Dev share-gate.
- `make test-fast` after every change; full `make test` before hand-off.

## 11 · Out of scope / deferred

- **Art generation** of the 5 pages (foundations + items + all customization variations) **and the 12
  lines** (12-tier ladders) — the pipeline's job; this spec defines the *slots*, scenes/lines, and
  example variation sets, not final assets.
- **Economy-sim re-pass** — all costs, level gates, cell bundles, variation prices, **recipe sizes/tiers,
  and the cross-zone reuse rate** are placeholders it owns.
- **Page & generator roster/order** beyond the examples (a content decision); seasonal/event pages +
  variation drops (a live-ops layer).
- Retiring the leftover farm assets + the dead `map.gd` spot/mask methods (a focused cleanup pass).

## 12 · Migration

Pre-launch: bump the save schema (v5→v6), wiping to a fresh page-1 start; no migration. The farm
(`fh_*`) buildings + `zone_farmhouse.json` are superseded by the book's pages (archived, not deleted).
