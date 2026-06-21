# Vine-driven home map — design

Date: 2026-06-21
Worktree: `.claude/worktrees/vine-home-map` (branch `worktree-vine-home-map`)

## Goal

Make the game's home map render the **vine-overgrowth output of the vine mask tool** (`make vine`)
instead of today's hand-baked farmhouse art, and make the relationship **data-driven** so that:

1. The home map shows `map1.png` with the animated vine overlay exactly as the tool previews it.
2. The number of unlockable areas on the home map equals the number of regions detected in the tool.
3. Editing regions in the tool (and saving) updates the home map automatically — no game-code edits.
4. Maps added in the tool (`map2`, `map3`, …) automatically become playable game maps, with
   `mapN` in the tool mapping to the `N`-th map in the game, carrying all its settings.

## Background — the two systems today

**Vine mask tool** (`games/tools/vine_mask_tool/`)
- `maps/maps.json` — registry of maps. Each entry: `{id, name, base, mask, mask_mode, region_count, regions_path}`.
- `maps/<map>_regions.json` — per-map authored regions: `image_size`, `mask_offset`, and a `regions`
  array. Each region: `{name, enabled, points (8-pt polygon, pixel coords), tuning (15 shader knobs)}`.
- Renders with `shaders/ominous_vines.gdshader` (+ shadow/embers shaders). The base image is the
  **clean** art; the shader paints animated glowing vines inside the masked area.
- Per-region rendering uses a shared **region-index map texture** (each pixel's red channel encodes
  which region it belongs to) plus per-overlay uniforms `region_index` / `region_count` /
  `region_enabled`. Each region spawns 4 `TextureRect` layers (shadow, glow, vines, embers), each with
  a duplicated `ShaderMaterial` carrying that region's tuning.
- The rendering core in `scripts/vine_mask_tool.gd` (load art → build mask alpha → build region-index
  map → spawn per-region overlays → apply tuning → `set_region_enabled`) is cleanly separable from the
  editing UI that sits on top.

**Grove game home map** (`engine/scripts/scenes/map.gd`, `games/grove/grove_data.gd`)
- `grove_data.MAPS` is a hardcoded array of 5 maps. Map 0 (`farmhouse`, `hub:true`) is the home.
- The home renders via the §16 mask-reveal path: an overgrown base (`farm_brokenv2.png`) with a clean
  layer (`farm.png`) revealed per building through baked per-building masks (`mask_fh_*.png`).
- Unlockables are **spots**: `MAPS[z].spots` — each `{id, name, kind, cost, pos}`. Buying a spot adds
  its `id` to `Save.grove().unlocks`; progression code reads only `id` and `cost` from each spot
  (`content.gd`: `map_spots_done`, `owned_count`, `map_stars_left`, `frontier_map`, `is_cheapest_open`).
- The game does **not** currently read any vine-tool output.

`map1.png` (the tool's base) is a fully clean farm; `map1_mask.png` marks the vine overgrowth. So the
vine model is *additive*: clean base, vines painted on top, unlock = turn a region's vines off.

## Design

### 1. Shared rendering component — `VineMapView`

Extract the rendering core out of `vine_mask_tool.gd` into a reusable node script,
**`games/grove/vine/vine_map_view.gd`** (`extends Control`, `class_name VineMapView`). Responsibilities:

- `load_map(map_entry: Dictionary, regions: Array)` — load base + build the luminance→alpha mask
  texture + build the region-index map texture from the polygons.
- Spawn the per-region overlay layers (shadow/glow/vines/embers) and apply each region's `tuning`.
- `set_region_enabled(index: int, on: bool)` and `region_count() -> int`.
- Pure rendering: **no editing UI, no file IO for saving** (it receives already-parsed data).

The vine **shaders move** to `games/grove/vine/shaders/` (shared location both consumers reference).
`VineMaskTool.tscn` and `vine_mask_tool.gd` are updated to point at the new shader paths and to render
through `VineMapView` (the tool keeps all its editing controls; it manipulates a `VineMapView`
instance and calls its render methods, instead of owning the overlay-building code). The tool's existing
`verify_vine_mask_tool.gd` must still pass, guaranteeing no visual regression.

Rationale: one renderer means the game can never drift from the tool, and the overlay-building code
lives in exactly one place.

### 2. Vine-map registry — `VineMaps`

A small helper, **`games/grove/vine/vine_maps.gd`**, is the single reader of the tool's output:

- `MAPS_JSON := "res://games/tools/vine_mask_tool/maps/maps.json"` (the tool writes here; the game
  reads here — this is what makes updates "automatic").
- `entries() -> Array` — parsed `maps.json` `maps` array (in file order).
- `regions_for(entry) -> Array` — parsed regions array from the entry's `regions_path`.
- `count() -> int` — number of vine maps.

The game reads these at map-build time (each home open), so a tool save is reflected on next open with
no rebuild step. (Live hot-reload while the game is running is out of scope — YAGNI.)

### 3. `grove_data.MAPS` becomes vine-aware (positional replacement)

`grove_data._build_maps()` overlays vine maps onto the map list by index:

- For map index `i`, if `VineMaps.entries()[i]` exists, that game map is **vine-driven**: it carries the
  vine entry plus spots derived from its regions (below). Index 0 stays the hub.
- Otherwise the legacy hardcoded entry is used unchanged.

With the tool holding `map1` + a `map2` placeholder, the resulting game maps are:

| game index | source | role |
|---|---|---|
| 0 | tool `map1` (farm) | hub / home — vine-driven |
| 1 | tool `map2` (placeholder copy of map1) | vine-driven, proves the pipeline |
| 2,3,4 | legacy `pond`, `orchard`, `meadow` | unchanged |

Adding `map3` to the tool later makes game index 2 vine-driven automatically, shifting legacy maps down.
**Open choice flagged for review:** this *replaces* legacy slots positionally (the legacy `barn` is
displaced by the `map2` placeholder). The alternative is to **append** vine maps after the legacy ones.
Default chosen: positional replacement, because it matches "mapN in the tool = the N-th map in the game."

A vine-driven game-map entry looks like:

```gdscript
{
  "id": "map1_farm",            # = the tool entry id
  "name": "Map 1 - Farm",       # = the tool entry name
  "hub": true,                  # index 0 only
  "vine": { ...the maps.json entry... },   # base/mask/regions_path/region_count
  "spots": [ ...one per region, see §4... ],
}
```

`map.gd` detects a vine-driven map by the presence of `vine` and renders through `VineMapView`
(§5); legacy maps keep their existing render paths untouched.

### 4. Region → spot model (cost defaults + override file)

For a vine-driven map, spots are generated one-per-region (in region order):

- `id` = `"<map_id>_r<index>"` (e.g. `map1_farm_r0`) — stable, so `Save.unlocks` persists per region.
- `name` = override, else the region's `name` ("Region 1").
- `cost` = override, else the default ladder `[3,3,3,4,4,4,5,5]` indexed by region (clamped/repeating
  past 8: tail value 5). Tunable later.
- `pos` = the region polygon's **centroid**, normalized to `image_size` — where the unlock badge sits.

The optional override file **`games/grove/vine/<map_id>_spots.json`** maps region index → `{name, cost}`:

```json
{ "0": {"name": "Cottage", "cost": 3}, "3": {"cost": 6} }
```

Absent file or absent key → defaults. This keeps the vine tool focused purely on visuals while letting
us hand-tune economy per map.

### 5. `map.gd` integration

- `_build_map_base(z, home)` gains a vine branch: if `MAPS[z]` has `vine`, build a clip frame, add the
  clean base layer (`vine.base` → `map1.png`, cover-fit, same as today's base), then add a `VineMapView`
  child loaded with the entry + regions, sized to the map art rect.
- The `VineMapView` is kept on the scene so spot buys can toggle it. After seating spots, for each region
  call `view.set_region_enabled(i, not spot_owned(spots[i].id))` — owned regions show clean, unowned
  show vines.
- Spots seat through a **vine badge path** (not the §16 building reveal): an unowned region shows the
  `✿ N★` cost badge at its centroid (reuse `_home_badge` / the kit disc); an owned region seats an
  invisible tap marker (like `_home_owned_item`) so the spot list stays index-aligned. Buying a region
  (existing buy flow) → `unlocks` gains its id → on rebuild the region's vines are disabled.
- Map-select card art for a vine-driven map uses its clean base (`vine.base`).

Reduced-motion (`FX.calm()`): pass through to `VineMapView` so animation can be frozen (the shader's
time-driven terms can be damped); detail deferred to the plan, but the hook is part of the component API.

### 6. The `map2` placeholder

Add a second entry to the tool's `maps/maps.json` that reuses map1's art and a **copy** of its regions
JSON (`map2_placeholder_regions.json`), so the tool's map switcher shows two maps and the game gets a
second vine-driven map. This proves `mapN → mapN` end-to-end without new art. It can be re-pointed at
real art later by editing `maps.json` only.

## Components & boundaries

| Unit | Responsibility | Depends on |
|---|---|---|
| `vine/shaders/*` | the vine look | — |
| `vine/vine_map_view.gd` | render base+vines+regions; toggle regions | shaders |
| `vine/vine_maps.gd` | read maps.json + regions json | tool output files |
| `grove_data.gd` | overlay vine maps onto MAPS by index; derive spots | `vine_maps.gd` |
| `map.gd` | seat the view + vine badges; wire unlock→region_enabled | `vine_map_view.gd`, `grove_data` |
| `vine_mask_tool.gd` | editing UI on top of a `VineMapView` | `vine_map_view.gd` |

## Testing

- **Engine/grove suites must stay green.** Existing grove tests that assert the 7 farmhouse spots /
  farmhouse ids will be updated to the vine-driven home (8 region spots, ids `map1_farm_r*`). This is
  expected churn, not a regression — the home's *content* is deliberately changing.
- New `grove` tests (logic, headless):
  - `VineMaps.count()` ≥ 1 and the home map (index 0) is vine-driven with `region_count` spots.
  - Spot count for a vine map == regions in its JSON (drive it by reading the JSON, so adding a region
    in fixture data changes the count).
  - Cost ladder + override file resolution (override wins; absent → default).
  - Buying a region spot adds its id to `unlocks`; `map_spots_done` true only when all regions owned.
  - Multi-map: with a `map2` entry, `MAPS` exposes a second vine-driven map at index 1; `map_unlocked`
    gates it behind map 0 completion (existing progression rule, unchanged).
  - `VineMapView` instantiates headlessly with the real data and reports `region_count()` == JSON count
    and `set_region_enabled` doesn't error. (Pixel/visual correctness is verified by a real-renderer
    capture, not the headless suite — see below.)
- **Tool parity:** `verify_vine_mask_tool.gd` still passes after the refactor.
- **Visual verification (not eyeballed from a thumbnail):** capture the home map via the real-renderer
  quiet-godot path and deliver the PNG for human review; compare against `make vine` for map1. Confirm
  unlocking a region clears its vines (capture before/after one buy).

## Out of scope

- Converting legacy `pond`/`orchard`/`meadow` to vine maps (no vine art yet).
- Authoring per-region cost/name inside the vine tool UI (override file covers tuning for now).
- Live hot-reload of the home while the game runs.
- Any change to the merge board, economy balance numbers, or residents sub-game.

## Risks

- **Tool refactor regressing the editor.** Mitigation: extract behind the existing
  `verify_vine_mask_tool.gd`; run `make vine` capture before/after.
- **Existing grove tests coupled to farmhouse content.** Mitigation: update them as part of the change;
  they assert the *mechanism*, re-point fixtures to the vine home.
- **Asset import after baked/texture moves.** Moving shaders + adding map2 needs `make import` in the
  worktree before resources resolve.
