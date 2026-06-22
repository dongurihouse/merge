# Five vine maps — wire the real art into the tool + game

Date: 2026-06-21

## Goal

The five real map locales now exist as clean art + overgrowth mask in
`games/grove/assets/_originals/maps/` (`farm`, `garden`, `gate`, `mill`, `orchard`, each with a
`*_mask.png`). Make all five:

1. **Editable in the vine mask tool** — registered in the tool's `maps.json` with their real
   base + mask, so the tool's map switcher shows all five and the user can hand-draw each map's
   polygon regions.
2. **Hooked up to the game** — each map drives one of the five game slots, with its display name +
   residents matching the new art, and its restorable regions appearing in-game as they are authored.

This extends the already-built vine pipeline (`docs/superpowers/specs/2026-06-21-vine-driven-home-map-design.md`):
`VineMapView` renderer, `VineMaps` registry, and `grove_data._apply_vine_maps` positional overlay
already exist. This task supplies the remaining four maps' art, registers all five, and resolves the
art/name/residents alignment for the real content.

## Decisions (settled with the user)

- **Progression order:** `farm → orchard → garden → mill → gate`. Farm stays the home hub (slot 0).
- **Names match the art:** display names + residents are re-themed to the new art. **Internal slot
  ids stay stable** (`farmhouse`/`barn`/`pond`/`orchard`/`meadow`) so existing saves, unlock keys
  (`<slotid>_r<i>`), `last_map`, and `map_for_id` are untouched.
- **Region-less maps show clean base art now** (not the legacy placeholder, and not fully-overgrown):
  a registered map with no authored regions renders only its clean base image, has no buyable spots,
  and never counts as complete (so it does not unlock the next map or invite residents).

### Position → slot → art → name map

Slots are wired **positionally** (tool entry *i* → game slot *i*). The progression order therefore
lands as:

| Pos | Slot id (stable) | Art | Tool entry id | Asset | Display name | Residents |
|----|----|----|----|----|----|----|
| 0 | `farmhouse` (hub) | farm | `map1_farm` | `map1.png` (unchanged) | The Farm | Hen-kin, Piglet-kin *(unchanged)* |
| 1 | `barn` | orchard | `map2_orchard` | `map2.png` | The Orchard | Bee-kin, Robin |
| 2 | `pond` | garden | `map3_garden` | `map3.png` | The Garden | Butterfly-kin, Ladybird |
| 3 | `orchard` | mill | `map4_mill` | `map4.png` | The Mill | Field-mouse, Sparrow |
| 4 | `meadow` | gate | `map5_gate` | `map5.png` | The Gate | Hedgehog-kin, Wren |

The internal id `orchard` ends up showing Mill art and the `barn` slot shows Orchard art — ids are
opaque save keys, so this is intentional and harmless. Resident critter names are proposals, easily
edited later. Board generators (keyed by map **index**, not name) are left as-is — out of scope.

## Design

### 1. Asset processing (no resize)

All ten files are already 941×1672 and `map1.png`/`map1_mask.png` are byte-identical to
`farm.png`/`farm_mask.png`, so "processing" a map is a straight copy + Godot import:

- Copy `_originals/maps/{orchard,garden,mill,gate}.png` and their `*_mask.png` into
  `games/grove/assets/map/` as `map2.png`/`map2_mask.png` … `map5.png`/`map5_mask.png`
  (numbered by progression position; `map1` = farm stays as-is).
- `make import` so the `.import` sidecars + `.ctex` caches exist.
- `mask_mode` defaults to `"luminance"` for every map (same as farm). Verify each mask renders as the
  overgrowth area in the tool; switch any that read inverted to the tool's other mode.

### 2. Tool registration — "allow me to edit them"

Rewrite `games/tools/vine_mask_tool/maps/maps.json` to **five** entries in progression order,
replacing the `map2_placeholder` entry (and delete `map2_placeholder_regions.json`). Each new entry:

```json
{
  "id": "map2_orchard",
  "name": "Map 2 — Orchard",
  "base": "res://games/grove/assets/map/map2.png",
  "mask": "res://games/grove/assets/map/map2_mask.png",
  "mask_mode": "luminance",
  "region_count": 0,
  "regions_path": "res://games/tools/vine_mask_tool/maps/map2_orchard_regions.json"
}
```

`map1_farm` (8 regions) is unchanged. The four new maps start with **no regions file** — the tool's
`_load_saved_regions` returns `[]` when the file is absent, so the user draws regions in the tool's
hand-draw mode and Save writes the `regions_path` file. No regions files are pre-authored by this task.

### 3. Game wiring — "hook them up"

`grove_data._apply_vine_maps` and `map.gd` already render vine maps. Two changes make a region-less
map show clean base art safely:

- **`grove_data._apply_vine_maps`:** drop the `if spots.is_empty(): continue`. Always overlay the
  vine entry (`maps[i]["vine"] = entry`, `erase("home")`, `maps[i]["spots"] = spots`) even when
  `spots == []`. This makes the slot vine-driven so its base art renders. Guard: skip an entry whose
  `base` asset does not exist (so a half-added map can never blank the slot).
- **`map.gd._build_map_base` vine branch:** always add the clean base cover layer; **only build the
  `VineMapView` overlay when the map has ≥1 region** (`VineMaps.regions_for(vine)` non-empty).
  Rationale: `VineMapView._region_count` is `maxi(regions.size(), 1)`, so a 0-region view would paint
  one overlay across the whole mask (fully overgrown). Skipping the overlay yields true clean base art.
- **`content.gd.map_spots_done`:** return `false` when `MAPS[z].spots.is_empty()`. A map with no spots
  has nothing restored, so it is not "done." This is the single chokepoint that keeps a region-less
  map from (a) paying the completion reward in `map.gd._build_map`, (b) being added to `gates` by the
  old-save backfill in `board.gd`, and (c) inviting residents / unlocking the next map via
  `map_complete`. All legacy maps have 8 spots, so this only affects region-less vine maps.

Net behavior: farm (8 regions) is live now. Each new map shows its clean base immediately and becomes
fully playable (buyable region discs, completion, next-map unlock) the moment its regions are authored
in the tool and saved — no game-code change per map.

Known dev-state limitation: while a frontier map has 0 regions it is the `frontier_map` but has no
cheapest spot, so the board's §7 fence meter has no target until regions are authored. This is a
transient authoring state, not a shipping state; not addressed here.

### 4. Names + residents

- `grove_data.MAPS[i].name` → "The Farm / The Orchard / The Garden / The Mill / The Gate" (the existing
  "The X" voice), per the position→slot table.
- `grove_data.RESIDENT_KINDS` (keyed by stable slot id) re-themed to match each slot's new art per the
  table. Keys unchanged; only the member lists change.

### 5. Tests + visual verification

- **Update churn:** `grove_vine_tests._test_multimap` currently relies on `map2_placeholder`'s 8
  regions; re-point it to assert the new registry — five entries, `map1_farm` still has 8 regions and
  overlays slot 0, and a region-less entry overlays its slot as vine-driven with `spots == []` and
  `map_spots_done == false`. Update any suite asserting the old map display names.
- **New asserts:** a region-less vine map renders a base cover layer but **no** `VineMapView` node;
  `map_spots_done` is false for a spot-less map; with farm's regions present its 8 spots still seat.
- **Full sweep:** `make test` green (engine + grove).
- **Visual (not eyeballed from a thumbnail):** capture the map-select (all five cards) and the home,
  plus one new map's clean base, via the quiet-godot real renderer; deliver the PNGs for human review.

## Out of scope

- Authoring the four new maps' regions (the user does this in the tool — this task only enables it).
- Board generator re-theming (keyed by index; flavor mismatch accepted for now).
- Per-region cost/name overrides for the new maps (cost ladder + in-tool cost authoring already cover it).
- Any economy-balance, merge-board, or residents-sub-game logic change beyond the resident name lists.

## Risks

- **Mask mode wrong for a new map** → vines render inverted/absent. Mitigation: verify each mask in the
  tool capture; `mask_mode` is per-map and switchable.
- **`map_spots_done` change breaking a hidden caller.** Mitigation: it only changes the empty-spots
  case, which no legacy map hits; full `make test` sweep confirms.
- **Import drift after copying assets** (the `.ctex` cache is gitignored/per-checkout). Mitigation:
  `make import` before verification; note for any later checkout.
