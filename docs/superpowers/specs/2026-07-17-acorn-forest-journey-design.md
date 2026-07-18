# Acorn Forest — The Lantern Trail (Journey + Customization) Design Spec

> **⚠️ SUPERSEDED (2026-07-17)** by `2026-07-17-picturebook-scenes-design.md`. The journey/keystone/
> reveal framing was cut — the zones felt too similar and the "leading home" thread added no purpose.
> Replaced by a **picture book of completely-different pages** (complete a page → turn to the next).
> Kept here for the customization thinking, which carried forward.

**Date:** 2026-07-17
**Builds on:** the home build-and-upgrade map (`docs/superpowers/specs/2026-07-17-home-build-upgrade-map-design.md`, shipped).
**Decision:** Replace the single "evolving farmstead" with a **journey across the forest** — an ordered
trail of **clearings** (zones), each a storybook scene of restore-able and **customizable** items,
gated by a **keystone** that reveals the next clearing. The pull is *curiosity* (what's over the next
rise) and *personalization* (a forest that's unmistakably yours). Story is thin, wordless, optional.

## 1 · The pull (why the player keeps going)

Three reinforcing motives, softest first:

1. **Curiosity — the trail unrolls.** Each clearing's **keystone** (a lantern), when finished, plays a
   "waking" beat and burns the mist off the **next clearing**, which until then sits ahead as a greyed
   silhouette you can pan to but not enter. There is *always* one more lantern to light. Endlessly
   extensible: the final keystone points "over the ridge" — every future zone is just "the trail went
   further," needing no re-architecture.
2. **Personalization — homes for your friends, a trail that's yours.** Most items **unlock, then
   customize** among many generated variations. You are not decorating a generic map: each woken
   creature *moves into a home you build and style for them*, and every lantern along *your* trail is
   yours to choose. This is the self-expression + collection engine and the cosmetic economy sink.
3. **Restoration — the grey lifts.** Restoring and upgrading items visibly de-greys each clearing;
   completing a clearing brightens its patch of the world map. Progress you can see, not just a number.

## 2 · The story (wordless, optional)

A child wanders into **Acorn Forest**, gone thin and grey. At the forest edge a lost **firefly** blinks,
too dim to find its way home. Tending the edge-glade back to life gathers more fireflies; together they
spark the first lantern, and its glow unrolls the next stretch of trail. Clearing by clearing, each
restoration wakes a sleeping forest creature and gathers more light, until the fireflies stream ahead to
spark the next lantern and unveil the next hollow. The firefly is going home — to the **Great Oak** at
the forest's heart, asleep so long the whole wood forgot its color. Told only in faces, light, and
before→after; a player who ignores it still feels *what's over that hill?*

## 3 · Element roles

Every item in a clearing has exactly one role:

- **🌿 Backdrop (restore-only).** Natural scenery — ferns, brook, brambles, roots. Unlocks and upgrades
  in steps (each step de-greys). No customization (variation on raw nature reads as noise). Carries the
  restoration spine and can gate the keystone.
- **✦ Cozy item (unlock → customize).** Built/crafted objects — lanterns, bridges, benches, planters,
  signposts, chimes, birdhouses. Unlocks in steps, then the player picks among many **variations**.
  The personalization + cosmetic-sink surface.
- **🐾 Creature home (unlock → customize + wakes a resident).** A den/hollow/pond-house for the
  clearing's creature. Same unlock→customize as a cozy item, and its completion **wakes the creature =
  opens that resident line** in the global bucket (§7). The emotional heart of customization ("a gift,
  not a paint-swap").
- **🔑 Keystone (unlock → customize + reveals next clearing).** A special lantern. Unlocks in steps,
  is customizable, and its **final step** plays the wake beat and reveals the next clearing. One per
  clearing (the last one is the finale).

## 4 · Progression & gating

- **Build steps** cost coins and require a minimum **level** (the coin clock, unchanged) — the pacing
  brake. Each element unlocks over 2+ steps: `empty → site(s) → built`.
- **Clearing gating.** Clearing *N+1* is `locked` (misty silhouette, pannable but not enterable) until
  clearing *N*'s **keystone** is built. Building it flips *N+1* to `revealed` (enterable) and fires the
  wake beat. The **first** clearing (Edge Glade) is unlocked from the start.
- **Customization** is coin- or premium-priced, always **optional** — never gates travel or the
  keystone. A soft "cozy" shimmer rewards a fully-styled clearing; a woken creature is more animated in
  a decorated home. No hard gameplay gate.
- **Cells → residents.** A completed 🐾 creature home grants bucket cells (as buildings do today) *and*
  opens that creature's resident line. Waking = capacity + a new production line, together.

## 5 · Customization model

Each ✦/🐾/🔑 element, once **built**, exposes a **variation set** — many skins of the same object,
generated by the art pipeline. The player owns the base (from building) and buys variations with coins
or diamonds; a chosen variation becomes the element's rendered look. Variations may be grouped into
**themed sets** (e.g. "Autumn", "Blossom", "Crystal") for collection satisfaction; premium/seasonal
variations are the diamond cosmetic sink the economy already wants (grove_spec §5 guardrails: cosmetic
only, no power). Data: each element carries `customizations: [{id, set, texture, cost:{coins|diamonds}}]`;
`Save.grove()["home"].custom[element_id]` stores the chosen variation (already implemented for buildings).

**Example variation sets** (illustrative; final list is a content/pipeline task):

- **Lantern** (✦/🔑): Paper · Iron-Cage · Carved-Gourd · Crystal-Jar · Mushroom-Cap · Star-Jar ·
  Acorn-Lamp · Firefly-Jar · Frosted-Glass · Woven-Reed.
- **Hollow-Log Den** (🐾 hedgehog): Bare-Log · Moss-Roof · Toadstool-Roof · Painted-Door ·
  Flower-Wreathed · Lantern-Hung.
- **Footbridge** (✦): Rope · Plank · Stone · Vine-Wrapped · Carved-Rail.
- **Planter** (✦): Wildflower · Fern · Mushroom · Berry · Pumpkin (seasonal) · Holly (seasonal).
- **Signpost** (✦): Plain-Wood · Carved · Painted · Mossy · Acorn-Topped.
- **Wind-Chime** (✦): Shell · Wood · Bell · Crystal · Acorn.

## 6 · The clearings (content)

Notation: **role** · *steps* (build steps to complete) · creature (for 🐾). Variation examples per item
are drawn from §5 sets; each item ships with its own generated set.

### 6.1 · The Edge Glade — *sunlit forest edge; you enter here (unlocked at start)*

| Element | Role | Steps | Notes / variations |
|---|---|---|---|
| Wildflower Patch | 🌿 backdrop | 2 | de-greys the glade; the forest's first pulse |
| Toadstool Cluster | 🌿 backdrop | 2 | red-caps grow fatter each step |
| Hollow-Log Den | 🐾 **Bramble the hedgehog** | 3 | wakes Bramble → opens the *coin* line; variations: Bare-Log → Flower-Wreathed |
| Berry-Bush Planter | ✦ cozy | 2 | variations: Wildflower · Berry · Mushroom |
| Mossy Bench | ✦ cozy | 2 | variations: Log · Stone · Carved |
| Trail Signpost | ✦ cozy | 2 | variations: Plain-Wood · Carved · Acorn-Topped |
| **The First Lantern** | 🔑 keystone | 3 | lit → wake beat → **Fernvale Hollow revealed**; variations: full Lantern set |

### 6.2 · Fernvale Hollow — *shaded ferny dell + a brook*

| Element | Role | Steps | Notes / variations |
|---|---|---|---|
| Fern Beds | 🌿 backdrop | 2 | unfurl greener each step |
| The Brook | 🌿 backdrop | 3 | trickle → singing stream |
| Pond-House | 🐾 **Dewdrop the frog** | 3 | wakes Dewdrop → opens the *water* line; variations: Lilypad · Reed · Stone hut |
| Footbridge | ✦ cozy | 2 | Rope · Plank · Stone · Vine |
| Stepping-Stone Lamps | ✦ cozy | 2 | small path-lanterns (Lantern set, mini) |
| Wind-Chime Branch | ✦ cozy | 2 | Shell · Wood · Bell · Crystal |
| **The Toadstool Lantern** | 🔑 keystone | 3 | a giant styleable glowcap; lit → **Bramblewood revealed** |

### 6.3 · Bramblewood Thicket — *thorny, berry-rich tangle*

| Element | Role | Steps | Notes / variations |
|---|---|---|---|
| Blackberry Vines | 🌿 backdrop | 2 | ripen dark and heavy |
| Bramble Tunnels | 🌿 backdrop | 3 | cleared into cozy hollows |
| Fox Burrow | 🐾 **Russet the fox** | 3 | wakes Russet → opens the *boost* line; variations: Earthen · Root-Arch · Flower-Fringed |
| Firefly-Jar Lamps | ✦ cozy | 2 | Lantern set (jar styles) |
| Berry-Cart Table | ✦ cozy | 2 | a gathering table; Plain · Painted · Draped |
| Twig Archway | ✦ cozy | 2 | Twig · Vine · Flower · Antler |
| **The Bramble Arch Lantern** | 🔑 keystone | 3 | lit → **Whispering Pines revealed** |

### 6.4 · The Whispering Pines — *tall dark pines, hush and wind*

| Element | Role | Steps | Notes / variations |
|---|---|---|---|
| Pinecone Grove | 🌿 backdrop | 2 | cones + saplings |
| Pine Canopy | 🌿 backdrop | 3 | the grey lifts from the boughs |
| Owl Hollow | 🐾 **Hoot the owl** | 3 | wakes Hoot → opens the *diamond* line; variations: Bare-Hollow · Shuttered · Treehouse · Moss-Vine |
| Canopy Platform | ✦ cozy | 2 | Rope-ladder · Plank · Carved |
| String-Lights & Chimes | ✦ cozy | 2 | Lantern/Chime sets |
| Birdhouse Cluster | ✦ cozy | 2 | Cottage · Barn · Acorn · Toadstool |
| **The Old Signpost Lantern** | 🔑 keystone | 3 | cleared → **the Great Oak revealed** |

### 6.5 · The Great Oak Heart — *the climax; the firefly's home*

| Element | Role | Steps | Notes / variations |
|---|---|---|---|
| The Roots | 🌿 backdrop | 3 | each step lifts grey across the whole world map |
| Bloom Canopy | 🌿 backdrop | 3 | the crown returns to color |
| Oak-Door Homes | 🐾 **the four friends' shared home** | 3 | style each of the four little trunk-doors; deepens all four lines |
| The Great Swing | ✦ cozy | 2 | Rope · Plank-seat · Flower-swing |
| Memory-Acorn Lanterns | ✦ cozy | 2 | Lantern set (acorn styles) |
| Root-Ring Benches | ✦ cozy | 2 | Log · Stone · Carved |
| **The Great Oak's Waking** | 🔑 keystone (finale) | 4 | the Oak wakes, the forest floods gold, the four creatures gather; the trail points **over the ridge** → the runway for future clearings |

## 7 · System architecture

Extends the shipped home model (`home_build.gd` / `home.gd` / `home_zone_view.gd`), which already does
step-building, level/coin gating, cells-from-completion, and customization. New pieces:

- **World manifest.** Replace the single `zone_farmhouse.json` with a **world** of ordered clearings:
  `world.json` → `[{id, label, world_pos, foundation, elements:[…], keystone_id, reveals_clearing}]`.
  Each element: `{id, role, position, display_size, sort_y, states:[…], customizations:[…], creature?,}`.
  `role ∈ {backdrop, cozy, home, keystone}`; `creature` (home only) maps to a resident line; the
  keystone's clearing carries `reveals_clearing` = the next clearing id.
- **Clearing state (save).** `Save.grove()["world"]` = `{current: clearing_id, revealed: [ids]}` plus the
  existing per-element `built`/`custom` under `home`. A clearing is enterable iff in `revealed`; the
  first is seeded revealed.
- **Keystone → reveal.** `home.buy_step` on a keystone whose final step completes: append
  `reveals_clearing` to `revealed`, fire the wake beat, and (for a 🐾-less keystone) nothing else; the
  creature line opens on the 🐾 home's completion, independently.
- **Creature → resident line.** Completing a 🐾 home calls the bucket to open its `creature` line
  (extends the current cells-granted path). The four homes map to the four mechanical lines
  (`RESIDENT_LINE_KINDS`: coin/water/boost/diamond); the Oak deepens all four. The **creature is the
  narrative face** of the line — the produced resident art (today sprout/dewdrop/ember/starlight) is
  regenerated to the forest cast (hedgehog/frog/fox/owl) so the woken friend and its spirits match. The
  mechanical line is unchanged; only the skin re-themes.
- **World camera / travel.** The clearings lay out **along the trail** in one continuous world space;
  the Home scene renders the world through a **pannable camera** (extends `home_zone_view`'s fit into a
  world→screen transform), so the player scrolls down the trail from clearing to clearing. The camera
  clamps to the revealed extent. A `locked` clearing ahead renders as a **greyed, misted silhouette**
  (its foundation at low saturation under a fog layer, with **no interactive elements**) — visible to
  pan toward, not to enter. Lighting the prior keystone burns the fog off (the wake beat) and extends
  the camera clamp to include it. v1 lays the five clearings on a simple vertical/diagonal trail; the
  layout is data (`world_pos`), so future clearings just append.
- **Wake beat.** A short scripted celebration on keystone completion: the creature stirs, fireflies
  gather and stream to the next lantern, the next clearing's fog burns off. Render-only FX.
- **Customization UI.** The existing per-building variant list (from the shipped model) generalizes to
  any built ✦/🐾/🔑 element: tap a built element → a variation picker (owned + buyable variations,
  grouped by set), buy with coins/diamonds, apply. The dock/nav is unchanged.

## 8 · Data model (concrete)

```
world.json
{
  "version": 1,
  "clearings": [
    {
      "id": "edge_glade", "label": "The Edge Glade",
      "world_pos": [0, 0], "foundation": "res://.../clearings/edge_glade.png",
      "keystone_id": "eg_first_lantern", "reveals_clearing": "fernvale",
      "elements": [
        {"id": "eg_wildflowers", "role": "backdrop", "position": [..], "display_size": [..],
         "sort_y": .., "states": [{id,texture}, ...]},
        {"id": "eg_log_den", "role": "home", "creature": "coin", "position": [..], ...,
         "states": [...], "customizations": [{id,set,texture,cost:{coins:..}}, ...]},
        {"id": "eg_first_lantern", "role": "keystone", ...,
         "states": [...], "customizations": [...]}
      ]
    },
    { "id": "fernvale", ... }, ...
  ]
}
```

- `grove_data` gains a `CLEARINGS`/element gameplay table (step costs, min_level, cells, creature line)
  parallel to today's `BUILDINGS`; the manifest carries art + placement + variations. All numbers
  **PROVISIONAL** (economy-sim re-pass owns them).
- `home_build.gd` extends: `role`, `reveals`, `creature` on defs; `is_keystone`, `revealed_after` pure
  helpers; `world state` (current/revealed) beside `built`/`custom`.
- `home.gd` extends: `enter(clearing_id)`, `revealed(clearing_id)`, `buy_step` fires reveal + line-open
  on the right completions.

## 9 · Testing

- **Pure module** (headless): keystone completion reveals exactly the next clearing (once); a 🐾 home
  completion opens exactly its creature line + grants cells (idempotent); customization apply/price;
  a locked clearing is not enterable; travel updates `current`; save round-trip of world + custom state.
- **Renderer** (headless node-tree): a revealed clearing renders its elements (state textures, painter
  order, single input surface); a locked clearing renders the silhouette+fog and NO interactive
  elements; the variation picker lists owned + buyable variations for a built element.
- **Screenshots** (`quiet_godot`): each clearing built + mid-build, a locked silhouette, the wake beat,
  and a customized vs default element — for the Dev share-gate.
- `make test-fast` after every change; full `make test` before hand-off.

## 10 · Out of scope / deferred

- **Art generation** of the clearings, elements, and all customization variations (the pipeline's job;
  this spec defines the *slots* and example sets, not final assets).
- **Economy-sim re-pass** — all costs, level gates, cell counts, variation prices (coins/diamonds) are
  placeholders; the sim owns them, including the customization cosmetic-sink balance.
- **Social / visiting** other players' forests (a future self-expression payoff).
- **Seasonal variation drops / events** (a live-ops layer on the variation system).
- Retiring the leftover farm assets + the dead map.gd spot/mask methods (a focused cleanup pass).

## 11 · Migration

Pre-launch: the schema bump (v5→v6) wipes to a fresh Edge Glade start; no migration. The farm
(`fh_*`) buildings + `zone_farmhouse.json` are superseded by the forest clearings (archived, not
deleted).
