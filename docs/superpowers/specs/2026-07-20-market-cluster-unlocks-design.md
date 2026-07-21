# Fairy Hollow Market — cluster cover-up unlocks

**Date:** 2026-07-20
**Status:** Approved design, pre-implementation

## Goal

Replace the first picture-book page's scene with the new `fairy_hollow_market` scene, and
give it a **per-cluster cover-up / unlock layer**: the fully-built market art sits under a
leaf overlay grouped into a handful of clusters; each cluster is one unlock. When a cluster's
gate is met its lock icon becomes tappable; tapping it clears that cluster's leaves (the
existing reveal animation) to expose the art already built underneath.

## Context (current system)

- Page 1 is `fairy_hollow` (`hub: true`), rendered by [map.gd](../../../engine/scripts/scenes/map.gd)
  via [home_zone_view.gd](../../../engine/scripts/ui/home_zone_view.gd) from
  `assets/map/pages/zone_fairy_hollow.json`.
- **Coverings** already exist ([scene_coverings.gd](../../../engine/scripts/ui/scene_coverings.gd)):
  leaves scatter over each locked *building*, and `reveal()` animates a staggered pop-out
  when a plot's first build step is bought. This is exactly the "leaves move away" behaviour.
- **Progression** is the existing per-region exp/level ladder plus a star cost. Today the
  single bottom-right CTA (`_play_btn`) flips from PLAY to RESTORE when the next spot is
  affordable, and `_on_unlock_pressed` buys the cheapest next step.
- The **`fairy_hollow_market`** scene exists only as a Scene-Workbench concept bundle
  (`assets/_concepts/zones/fairy_hollow_market_elements_v1`), with 6 hero clusters. It has no
  runtime `zone_manifest` in `pages/` yet.
- `build_page_manifests.py` deterministically emits `zone_<scene>.json` from a bundle's
  `metadata/placements.json`, copying the layer PNGs into `pages/<scene>/`.

## The 6 clusters (canvas 1320×2346, center-bottom anchors)

Unlock order is **strict, bottom-of-scene first, working up** (descending y):

| # | Cluster            | anchor (x,y) | size (w×h) |
|---|--------------------|--------------|------------|
| 1 | `lantern_gate`     | 679, 2345    | 396×467    |
| 2 | `flower_crate`     | 1067, 2338   | 505×578    |
| 3 | `stream_bridge`    | 237, 1969    | 474×584    |
| 4 | `crystal_map_stall`| 1040, 1412   | 552×765    |
| 5 | `tea_stall`        | 251, 1252    | 502×751    |
| 6 | `mushroom_hall`    | 835, 786     | 509×723    |

## Design decisions

1. **Promote the market scene, keep the page id `fairy_hollow`.** Generate the market
   manifest and repoint page 1's `zone_manifest` (and `covering_frames`) at it. The id stays
   `fairy_hollow` because it is load-bearing (hub flag, save keys, unlock gates, map-select);
   only the rendered content changes.
2. **Clusters are the unlock unit, keyed by the manifest's existing `cluster` field.** No
   separate zone-workbench polygon file — every building already carries a `cluster` tag, so
   the runtime buckets covering + lock + unlock by that tag. One cluster = one unlock unit.
3. **Cosmetic reveal only.** The layered market art underneath is always built; unlocking a
   cluster only clears its leaf overlay. No build-step flow behind the reveal.
4. **Same progression as before**, re-bucketed from per-building spots to the 6 clusters:
   the exp/level ladder + star cost, consumed one cluster at a time.
5. **Strict sequence.** Only the next locked cluster (lowest index still locked) can ever be
   "ready". All later clusters read plain-locked.
6. **Keep the bottom pill as the progress counter** (N clusters left to restore); the
   per-cluster on-map lock icons become the tap target. The bottom CTA reverts to plain PLAY.

## Components

### A. Scene promotion (data + assets)
- Add `fairy_hollow_market` to `build_page_manifests.py` and generate
  `zone_fairy_hollow_market.json` + copy layer PNGs into `pages/fairy_hollow_market/`.
- Point `G.MAPS` page-1 `zone_manifest` at the market manifest; set `covering_frames` to the
  scene's leaf set. Define the 6 clusters' unlock order + costs as the page's unlock units
  (replacing the vestigial per-building `spots` list, keeping save-compat behaviour).

### B. Cover-up layer, per cluster ([scene_coverings.gd](../../../engine/scripts/ui/scene_coverings.gd))
- Add a `scatter_cluster(members, frames)` (or group the existing per-building scatter under a
  cluster group) so one covering group covers a whole cluster's combined envelope.
- Track the covering group by **cluster id** (not building id) in `map.gd`'s `_zone_coverings`.
- `reveal()` fires unchanged for the cluster's whole group on unlock.

### C. Lock badge, three states (new small UI unit)
Mounted at each covered cluster's anchor:
- **Locked** — dim padlock (`ui/meadow_v2/icon_padlock.png`), non-interactive.
- **Ready** — brightened + gentle breathing/glow pulse (reuse `FX.breathe_once`/existing pulse),
  only on the next-in-sequence cluster once its gate is met.
- **Tap → unlock** — pays the cost via the existing unlock path, then the cluster's leaves
  reveal away and the badge is freed.

### D. Wiring in [map.gd](../../../engine/scripts/scenes/map.gd)
- On `_build_map`, for each still-locked cluster mount its covering group + lock badge; compute
  which cluster is "next" and whether its gate is met to pick locked vs ready.
- Lock-badge tap → the existing unlock/claim routine, scoped to that cluster; on success call
  `SceneCoverings.reveal` for the cluster group and rebuild.
- Bottom pill: repoint its counter to clusters-remaining; revert `_play_btn` to plain PLAY.

## Testing

- **Manifest generation**: `zone_fairy_hollow_market.json` exists with the 6 clusters, correct
  canvas/anchors; `make import` loads the layer PNGs (grove_page_manifest_tests).
- **Covering/reveal**: headless test that per-cluster covering groups are created for locked
  clusters and removed on unlock (grove_placement/ui suites).
- **Sequence gate**: only the lowest-index locked cluster can be ready; unlocking advances the
  next; the bottom counter tracks clusters-remaining.
- Run `make test-fast` after each slice; `make test` before handoff.

## Out of scope

- Regenerating clean transparent cluster sprites (the bundle is a first-pass source crop).
- Applying the same mechanic to pages 2–5.
- Any change to the exp/level curve values themselves.
