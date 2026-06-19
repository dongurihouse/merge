# Grove v1 Art — Generation & Hook-up Runbook

> Design + runbook for the **Grove v1 art** backlog item (regenerate all home-grove art fresh,
> Direction-F, one batch). Operationalizes `grove_spec §9` (Art Direction) + `merge_spec §16`
> (Designing for LLM Asset Generation). The §16 spec is the *law*; this is the *executable plan*.
> Authored 2026-06-15. Status: **design — pending Dev review** (then `writing-plans`).

## 1 · Scope

Regenerate **all** home-grove art fresh — the 2026-06-14 pass (flower/berry/mushroom/honey + 3
generator stand-ins + retired fox/hedgehog givers) is **disowned**, one uniform Direction-F batch:

| Class | Count | Path (under `res://games/grove/assets/`) |
|---|---|---|
| **Item sprites** | **192** — 24 lines × 8 tiers (codes 1–8, 10–25; skip 9) | `items/<base>_<tier>.png` |
| **Generator sprites** | **12** — maps 1–5 | `ui/gen_<id>.png` (+ edit `grove_data.GENERATORS[].tex`) |
| **Board backdrop** | **1** | `ui/bg_grove_board.png` |
| **Shop backdrop** | **1** — the squirrel merchant's market-stall interior (`merge_spec §10` presentation) | `ui/kit/bg_shop.png` (engine renders an interim blur until this lands) |
| **Map scenes** | **5** — farmhouse · barn · pond · orchard · meadow (§16 scene pipeline) | `map/map_<id>.png` + placement coords |
| ~~Engine follow-up~~ | **shipped as T30** (`seed_satchel` `anchor:true` → `askable_lines`, cold-load-safe, `anchor_tests.gd`) — **dropped from this task, verify-only** | — |

**Out of scope** (separate backlog items, not this task): the parents' de-transformation ladder,
giver busts (Radish/Carrot/Frog/Bee/Morel + menagerie), the great-spirit, seed-sprites, the §8
icon canon (Bloomstar/acorn/dewdrop — the emoji-purge item), and maps 6–15 (post-launch).

**Hook-up facts (verified in code):** items load via `Game.art("items/%s_%d.png" % [base, tier])`
(`content.gd:565`); `ART_ROOT = res://games/grove/assets/` (`game.gd:7`); generators load their
`tex` field; maps load `map/map_<id>.png`. The `_gen_queue.json`'s old `res://assets/items/` paths
are **stale** (pre-`engine/`+`games/` reorg) — this runbook uses the current paths.

## 2 · Channel — Engineer authors prompts, the artist generates

The Dev routes generation to an **external artist** (human or the Dev's own image tool). The
Engineer's job is to **author ready-to-send prompts** and to **process + hook up + verify** what
comes back — not to drive the generator. Loop per asset:

1. Engineer writes the prompt (`[subject] + [scaffold] + [STYLE LOCK]`), ready to paste.
2. Dev hands it to the artist → raw image(s) returned.
3. Engineer processes the return (`split_grid` if gridded → `process_icon` trim/center, or
   `process_decor` for scenes), drops it at the engine path, `make import`, verifies.

**Deliverable (decided 2026-06-15):** the artist returns **finished transparent sprites** — so there
is **no chroma background and no keying** (§6 moot); the Engineer trims/centers to spec, verifies,
imports, and splits a grid only if a line is batched as one transparent grid. *(If the Dev later
switches to raw renders, the chroma-key approach is in git history.)*

## 3 · The base prompt

Every prompt = `[subject] + [per-class scaffold] + [STYLE LOCK]`. The **STYLE LOCK** is pasted
verbatim from `grove_spec §9` on every prompt:

> hand-painted anime film background style, soft gouache and watercolor texture with visible
> brushwork, gentle diffuse summer daylight, warm nostalgic pastoral palette of meadow green, straw
> gold and clear sky blue, towering soft cumulus clouds, atmospheric haze in the distance,
> wind-blown grass, painterly cel-shaded subjects with clean simple line work, no photorealism, no
> glossy 3D render, no text

Saturation lever (if it reads "digital anime wallpaper"): add `muted vintage film colors, slightly
faded`. **No text or numerals in any art** (§16 rule 6 — the engine draws all text).

**Top-down rule (corrected 2026-06-15 — Dev caught a perspective board).** The board and items are
**flat** — the board is a grid, items are flat icons. They render **high top-down, uniform item
scale, no horizon / no sky / no distance / no perspective vanishing**. The STYLE LOCK's
`towering soft cumulus clouds, atmospheric haze in the distance, wind-blown grass` clauses force a
landscape-with-horizon, so they are **scene-only** — **dropped** for the board + items (keep the
medium/palette/linework clauses: gouache+watercolour, cel-shaded, warm pastoral palette, clean
outline). Map *scenes* keep a gentle high angle but objects stay **floor-standing**, never
perspective-skewed (§16 rule 2).

## 4 · Items — 3×3 line-grids

**One render per line = that line's 8 tiers laid out in a clean 3×3 grid** (8 used + 1 spare cell),
clearly separated with generous margin (§16 rule 4). One render per line keeps a line's tiers
style-consistent (shared lighting/brushwork), and **24 grid-renders → 192 sprites** (vs 192 single
renders). Items display at ~100 px in-game, so a ~340 px grid cell upscaled to the 512² asset is
ample.

- **Per-class scaffold:** *"a clean 3×3 grid of 8 painted game items, evenly spaced with empty
  margin around each, no overlap, soft contact shadow under each; one [LINE MOTIF] shown at 8
  growth stages stepping up in size and silhouette from a tiny [origin] to a large [trophy]; chunky
  readable silhouette, soft painterly shading with one warm rim light, clean simple outline; on a
  transparent background, any interior gaps fully cut through (transparent), not filled."*
- **Shared per-line motif** + the tier-readability law (steps in size + silhouette, readable at
  ~100 px) per `grove_spec §9` / `merge_spec §6`.
- **Top-down / uniform scale** — items are flat top-down icons at a consistent scale matching the
  board comp (§7), no horizon (§3); the line-grid is just a generation/throughput unit, not a scene.
- **Process:** if the artist batches a line as one transparent 3×3 grid, `split_grid.gd` slices it
  into 9 tiles → `process_icon` (trim/center, transparent no-op) → 512² → `items/<base>_<tier>.png`.
  If tiers come individually, skip the split.

**The 24 lines** (base + ladder concept; full per-tier subjects authored into the regenerated queue
during P1):

| Map | Lines (base) | Ladder concept (t1 → t8, under a shared per-line motif) |
|---|---|---|
| 1 Farmhouse | Wildflower (`flower`), Berry (`berry`), Mushroom (`mushroom`), Honey (`honey`) | seed/origin → sprout → seedling → potted → bush → laden → small tree → mature trophy (the soil/pot motif). *Reference ladders exist in the old queue — re-authored, not reused.* |
| 2 Barn | Egg (`egg`), Feather (`feather`), Milk (`milk`), Wool (`wool`) | single → few → gathered → vessel/nest → basket → … (dairy/coop motif) |
| 3 Pond | Reed (`reed`), Lotus (`lotus`), Fish (`fish`), Snail (`snail`) | sprout/spawn → growth → cluster → mature (water/bank motif) |
| 4 Orchard | Apple (`apple`), Pear (`pear`), Plum (`plum`), Cherry (`cherry`), Walnut (`walnut`), Blossom (`blossom`) | bud → fruitlet → branch → laden bough → basket → tree (orchard motif) |
| 5 Meadow | Glowcap (`glowcap`), Spore (`spore`), Clover (`clover`), Dandelion (`dandelion`), Poppy (`poppy`), Firefly (`firefly`) | spore/seed → sprout → patch → bloom → glowing mature (meadow/lantern motif) |

**Grid-reliability fork (decided in P0):** if the artist's tool can't reliably produce a clean,
splittable, on-style 3×3, fall back to **individual sprites** or a 2×2 (4 tiers/render). The grid is
a throughput goal, not a hard requirement.

## 5 · Generators — individual renders

12 generators are "major items" — larger, "openable/giving" presence (§9) — so each is its **own
render** (not gridded). Finished transparent sprite, trimmed/verified, written to `ui/gen_<id>.png`;
then each generator's `tex` in `grove_data.GENERATORS` is repointed from the 3 stand-ins to its own sprite.

| Map | Generators (id) |
|---|---|
| 1 | `seed_satchel` (the anchor), `pantry_crock` |
| 2 | `hen_coop`, `dairy_stall` |
| 3 | `reed_bed`, `creel` |
| 4 | `orchard_basket`, `stone_fruit_bough`, `nut_blossom` |
| 5 | `glowcap_ring`, `meadow_tuft`, `lantern_bloom` |

## 6 · Holes & light items (no keying needed)

The artist returns **finished transparent sprites** (§2), so there is **no background to key** —
interior holes (rings, baskets, a glow-cap ring) and light-colored items (Milk/Wool/Egg/Feather/
Blossom, which would otherwise blend into white) arrive already cut. The only carry-over is a
**prompt instruction** on every item: *"transparent background; any interior gaps fully cut through
(transparent), not filled."* No chroma background, no `chroma_cut` tool. *(Superseded the original
chroma-key plan when the Dev confirmed finished-sprite delivery, 2026-06-15; the chroma approach is
in git history if delivery ever switches to raw renders.)*

## 7 · Board background + map scenes (the §16 scene pipeline)

The share-gate art (`grove_spec §9`: share-worthy map art is a **launch-gate** criterion).

**Three distinct asset types — never conflated** (Dev correction, 2026-06-15): **items** = the
tier/stage sprites (§4); the **board background** = the flat surface they sit on (below); **map
scenes** = the restoration *places* (below). The growth **stages belong to items only** — never
painted into a board or a map scene. **First render = Map 1 Farmhouse, fully restored** — the style
anchor for the whole batch + the §16 starting render everything else harvests from.

- **Board background** (`ui/bg_grove_board.png`): a **flat top-down** painted garden-clearing ground
  the 7×9 grid sits on — **empty of items** (items are separate sprites, §4, placed on top at
  runtime; that's already how the board draws). Flat, **no horizon / sky / perspective** (a vista
  breaks item scale — Dev caught this 2026-06-15); a calm low-contrast surface under the engine's
  ~60% scrim. `process_decor` (opaque). *(Board bg and items generate SEPARATELY — both flat
  top-down + style-matched, so they compose; the earlier "empty + separate = disaster" was the
  perspective vista, not the layering.)*
- **5 map scenes** (`map/map_<id>.png`, canvas **1084×1451 ≈ 3:4**): each an **open-space painted
  scene** — a locale (yard/grounds/waterside) with its 8 spot objects **floor-standing**, clearly
  separated, surroundings painted in (never plain-white bleed). The **§16 seven-phase pipeline**:
  1. Generate the full scene — all 8 objects placed, clearly separated, soft contact shadows, STYLE LOCK.
  2. Detect → manifest: a tight pixel box per object, `{id, bbox_px}`; **verify by overlay** (never trust raw vision).
  3. Cut each object → transparent (keep contact shadow, don't resize/redraw); check alpha over magenta.
  4. Build the empty background — masked inpaint of only the object regions (pad mask ~12 px).
  5. Recompose — paste cut-outs onto the empty bg at their boxes (round-trip = correctness check).
  6. Verify (human) — diff map + side-by-side; bright diff = bad box / dirty cut / bg drift.
  7. Feed the game — boxes → normalized placement (`pos = box-centre/canvas`, `fsize` scaled to canvas).
- **Object ids must match `grove_content` spot ids** (pulled exactly at P4). The empty bg = the
  ruined/**before** state; the spot cut-out = restored/**after** — the engine composites the
  before→after per spot (§16 rule 3). **Placement boxes already exist** for the home maps in
  `grove_data` (`pos` + `fsize` per spot — e.g. the 8 `fh_*` farmhouse spots), so the harvest mainly
  produces cutouts sized to those; final nudge in the layout sandbox (`data/placements.json`).
- **Farmhouse hub — extra upgrade-look art** (decided 2026-06-15). The hub's 4 **yield** buildings
  (`fh_hearth`/`fh_kitchen`/`fh_well`/`fh_larder`) upgrade **L1→L5** (§3 — a composited-look swap per
  level). This batch generates the **restored (base) look** for all 8 spots **+ a single maxed-L5
  hero** for each of the 4 yield buildings (4 extra cutouts) — shows the ceiling without the full
  ladder. **L2–L4 in-betweens are deferred** to the keystone Part-A build (not built — only the
  `spot_level`/`hub_collected_at` save schema shipped, T22; level progression + rates untuned). The
  4 **décor** spots restore once (no upgrade art).
- **Maps 2–5 are finish-once** (Barn/Pond/Orchard/Meadow — §3; owner "hub-concentrated", 2026-06-15;
  their spots carry **no `kind`/yield** in data): **one restored cutout per spot** (8 each = 32) +
  the empty-yard bg, **no upgrade ladders, no L5 heroes**. Only the Farmhouse hub upgrades.

## 8 · Tooling

- **New:** `split_grid.gd` (transparent grid PNG → 9 tiles, only if the artist batches a line),
  `montage.gd` (review grids — already written this session).
- **Reuse:** `process_icon.gd`, `process_decor.gd`, `icon_gen_browser.js`, `make import` /
  `shot-grove` / `shot-map`.
- **Regenerate** `games/tools/_gen_queue.json` fresh — current paths, grid units, transparent-bg
  prompts, the new roster (the old queue is stale: old cast, root paths, white bg). It stays the
  resumable source of truth (per-item: status / process / prompt), tracking which prompts are out to
  the artist and which have returned + landed.

## 9 · Hook-up

Items: drop at `items/` → `make import` → auto-resolve (no code). Generators: drop at `ui/` + edit
`grove_data.GENERATORS[].tex`. Board: `ui/bg_grove_board.png`. Maps: `map/map_<id>.png` + placement
coords in `placements.json`. **Engine follow-up — done (T30):** `seed_satchel` is flagged
`anchor:true`; quest/gate generation draws `askable_lines = lines_for_zone ∪ anchor_lines`, derived
from the static roster so the anchor stays askable past map 1 on a cold load (`anchor_tests.gd`, 17
asserts). No code left for T36 — verify still green.

## 10 · Verification

- **Per sprite (automated):** alpha-over-magenta (no halos/scraps), subject-not-eaten, 512²,
  transparent, correct dims. A `verify_sprites.gd` check over the batch.
- **Maps (round-trip):** recompose vs original diff map (§16 phase 6) — the built-in correctness check.
- **Share-gate (Dev eyeball — low LLM-reliability, stays with the Dev):** per-line + per-map
  montages for sign-off. Never my eyeball — the §9 share-gate is the load-bearing perceptual call.
- **In-engine:** `make shot-grove` (board with real items), `make shot-map` (map scenes).
- **Regression:** `make test` stays green — only `tex` paths edited in data; bases unchanged.

## 11 · Phasing (batch with checkpoints)

| Phase | Work | Gate |
|---|---|---|
| **P0 — prompt-lock** | **First render = Map 1 Farmhouse, fully restored** (the §16 end-state scene, all 8 spots placed) — the style anchor + the harvest source. Then it feeds the item / board-bg look. | **Dev signs off the look** (§9 share-gate). Locks Direction-F + the §16 harvest. *No mass-gen until this passes.* |
| **P1 — items** | 24 line-grids → 192 sprites. **Batched with checkpoints:** a few lines → montage → Dev spot-check → continue. | Per-line montage clean; auto sprite checks pass. |
| **P2 — generators** | 12 individual → repoint `tex`. | Montage + `shot-grove`. |
| **P3 — board backdrop** | 1 render → `process_decor`. | `shot-grove`. |
| **P4 — map scenes** | §16 pipeline ×5 (scene → boxes → cut → empty bg → recompose → placement). | Round-trip diff per map + Dev share-gate sign-off. |
| **P5 — hook-up + verify** | `make import`, generator `tex` edits, full verification, montages. (Anchor follow-up shipped in T30 — confirm still green.) | `make test` green; in-engine shots; Dev sign-off. |

## 12 · Risks

- **Channel dependency** — generation rides the Dev→artist round-trip; throughput + style are the artist's, so the Engineer front-loads tight prompts and fast feedback to keep iteration cheap.
- **3×3 grid reliability** — the model may not lay out a clean 8-tier grid; fork to individual sprites (P0).
- **Share-gate** — the look is a launch gate + a perceptual call; the Dev's eye decides, montages make it cheap to judge.
- **Map placement drift** — vision boxes run a few % off; overlay-verify every box, final-nudge in the layout sandbox.
- **Volume / time** — 200+ sprites + 5 scene pipelines = many slow round-trips; the resumable queue makes it pausable, the checkpoints catch drift early.
