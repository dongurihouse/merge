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
- Every **item** follows the shipped contract: **unlock in steps** (coin- + level-gated) → then
  **customize** among many generated variations.
- A page is **complete** when all its items are built. Completing the frontier page **turns to the next
  page** (unlocks the next scene) and grants a bundle of resident-bucket cells.
- The merge **board** (core play) and the **coin clock** (level from lifetime earned coins) are
  unchanged — they fund the book. The **resident bucket** (global) is unchanged; page-completion is its
  new cell source.

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
**per-page completion**.

**Dropped (from the superseded journey spec):** keystones, next-zone reveal, misty silhouettes, the
wake beat, creature→resident wiring, the world-pan camera, and any narrative thread. A page simply
completes and turns.

## 4 · Page & item model

**Page** (one per scene): `{id, index, label, foundation, canvas, items:[…]}`. The renderer draws ONE
page at a time, fit to the viewport (exactly as the home zone renders today).

**Item** (the only element type — no roles/keystones): every item is **unlock → customize**.
- `states`: the build progression `empty → site(s) → built` (art per state).
- `steps`: `[{cost_coins, min_level, shows_state}]` — 2+ steps; the coin+level gate paces completion.
- `customizations`: `[{id, set, texture, cost:{coins|diamonds}}]` — the variation skins, offered once
  the item is **built**. Optional, never blocks page completion.
- A minority of items may be **backdrop** (build-only, no `customizations`) where variation would read
  as noise (drifting leaves, falling snow) — but the default is customizable, since customization is
  the point.

Page completion = every item `built`. (Customization is *not* required to turn the page — it's the
optional beautify/collection layer, available anytime, including on flipped-back pages.)

## 5 · Progression & economy

- **Build steps** cost coins and require a min **level** (lifetime earned coins) — the pacing brake,
  unchanged. This meters how fast a page fills in.
- **Page turn:** completing the frontier page unlocks the next page, plays a short **page-turn
  transition**, and grants a **cell bundle** to the resident bucket (capacity drip). Level-ups keep
  gifting water/diamonds as today.
- **Customization** is a coins/diamonds sink, cosmetic-only (grove_spec §5 guardrails), themed into
  **sets** for collection; premium/seasonal variations are the diamond cosmetic sink the economy wants.
- **Residents** (global bucket) produce coins in the background and remain the endgame collection/
  Expedition loop — decoupled from any one page. *(Decision: kept + fed by page completion. Revisitable
  — a purely cosmetic book with no residents is possible, but retiring residents removes the v1 coin
  faucet + endgame, so the default keeps them.)*
- **Invariants for the sim re-pass** (deferred): no-strand (an affordable next item step always exists
  at nominal coin flow), sink > faucet (build ladder + customization vs. the faucet), cells ≈ the
  designed bucket capacity across the page arc.

## 6 · Example pages (content)

Illustrative — the final roster/order and all art are a content/pipeline task. Each item is
unlock-in-steps + customize-with-variations; a few `~backdrop` items are build-only.

| # | Page (scene) | Items (unlock · upgrade · customize) |
|---|---|---|
| 1 | **Snowy Village** *(winter)* | log cabins · snowmen · frozen skating pond · lit pine trees · a sled · smoking chimney · gift stall · lantern posts · *~falling snow* |
| 2 | **Autumn Orchard** *(fall)* | apple trees · hay bales · scarecrow · cider press · pumpkin patch · wooden cart · picnic table · *~drifting leaves* |
| 3 | **Desert Oasis** | palm trees · caravan tent · camel · stone well · woven rugs · hanging lanterns · spice-market stall · fountain |
| 4 | **Coral Reef** *(underwater)* | coral fans · sunken ship · treasure chest · anemones · giant clam · kelp beds · mermaid statue · *~bubble streams* |
| 5 | **Cherry-Blossom Garden** *(spring)* | sakura trees · red arched bridge · koi pond · stone lanterns · tea pavilion · bonsai · torii gate · *~drifting petals* |
| 6 | **Fairy Hollow** *(night forest)* | glowing toadstools · firefly lanterns · toadstool cottage · wishing well · lantern-vines · a fox den · crescent-moon swing |

Extensible without limit: pumpkin patch, seaside pier, lavender field, mountain shrine, candy land,
lighthouse cove… Every page's items are native to that scene, so completing page 4 feels nothing like
page 1. **Example variation sets** (per item, generated by the pipeline): a *snowman* in Classic ·
Top-Hat · Carrot-Nose · Scarfed · Ice-Crystal · Grumpy; a *tent* in Striped · Patched · Silk · Woven ·
Royal; a *koi pond* in Calm · Lily-Covered · Bridge-Lit · Autumn-Leaf. (Sets support collection +
seasonal drops.)

## 7 · Data model (concrete)

```
book.json
{
  "version": 1,
  "pages": [
    {
      "id": "snowy_village", "index": 0, "label": "Snowy Village",
      "foundation": "res://.../pages/snowy_village.png",
      "canvas": [941, 1672],
      "items": [
        {"id": "sv_cabin", "position": [..], "display_size": [..], "sort_y": ..,
         "states": [{id,texture}, ...],
         "steps": [{cost_coins, min_level, shows_state}, ...],
         "customizations": [{id, set, texture, cost:{coins|diamonds}}, ...]},
        {"id": "sv_snow", "backdrop": true, "states": [...], "steps": [...]},
        ...
      ]
    },
    { "id": "autumn_orchard", "index": 1, ... }, ...
  ]
}
```

- `grove_data` gains a `PAGES` gameplay table (per-item step costs/min_level, per-page cell bundle),
  parallel to today's `BUILDINGS`; the `book.json` manifest carries art + placement + variations. All
  numbers **PROVISIONAL** (economy-sim re-pass owns them).
- **Save:** `Save.grove()["book"] = {frontier: page_id, viewing: page_id}` plus the existing per-item
  `built`/`custom` under `home` (keyed by item id, unique across pages). A page is complete when all its
  items are built; the frontier advances on completion; `viewing` is the currently-shown page (browse).

## 8 · System architecture

Extends the shipped `home_build.gd` / `home.gd` / `home_zone_view.gd`:

- **`home_build.gd`** (pure): generalize from one building set to a **book of pages**; add
  `page_complete(state, page_def) -> bool`, `next_page(book_def, frontier) -> id`,
  `page_cells(page_def)`; item build/customize rules unchanged.
- **`home.gd`** (adapter): `frontier()`, `viewing()`, `set_viewing(page_id)` (browse; only ≤ frontier),
  `buy_step(item_id)` — on the step that completes the last item of the frontier page, advance the
  frontier + grant the page's cell bundle; `cells_total()` = sum of completed pages' bundles.
- **`home_zone_view.gd`** (renderer): draw the **viewed page's** manifest (foundation + items by
  current build state, painter-sorted, single input surface) — one page fit to the viewport, exactly as
  the home zone renders today. Add a **page-turn** transition and a small **page nav** (prev/next within
  unlocked pages) for browsing. No world camera, no silhouettes.
- **Scene (`map.gd`)**: the tap flow (`_on_build_tap`) and the build/customize dialogs are unchanged;
  they now act on the viewed page's items. The Play/Restore CTA reads "any buyable item on the frontier
  page." The resident dock + chrome are unchanged.

## 9 · Testing

- **Pure module** (headless): item unlock/customize rules (carried); `page_complete` true iff all items
  built; frontier advances exactly once on completion; `page_cells` grant is idempotent;
  `set_viewing` refuses pages past the frontier; save round-trip of book + item state.
- **Renderer** (headless node-tree): the viewed page renders one item node per item at its build-state
  texture, painter-sorted, single input surface; the page nav lists only unlocked pages; the variation
  picker lists owned + buyable variations for a built item.
- **Screenshots** (`quiet_godot`): 3–4 *different* pages built + mid-build, and a customized vs default
  item — proving the scenes read as genuinely distinct (the whole point) for the Dev share-gate.
- `make test-fast` after every change; full `make test` before hand-off.

## 10 · Out of scope / deferred

- **Art generation** of the pages (foundations + items + all customization variations) — the pipeline's
  job; this spec defines the *slots*, example scenes, and example variation sets, not final assets.
- **Economy-sim re-pass** — all costs, level gates, cell bundles, variation prices are placeholders.
- **Page roster & order** beyond the examples (a content decision); seasonal/event pages (a live-ops
  layer on the page + variation systems).
- Retiring the leftover farm assets + the dead `map.gd` spot/mask methods (a focused cleanup pass).

## 11 · Migration

Pre-launch: bump the save schema (v5→v6), wiping to a fresh page-1 start; no migration. The farm
(`fh_*`) buildings + `zone_farmhouse.json` are superseded by the book's pages (archived, not deleted).
