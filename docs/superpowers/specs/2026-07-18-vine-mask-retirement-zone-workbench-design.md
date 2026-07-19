# Vine Mask Retirement + Zone Workbench — Design

Date: 2026-07-18. Status: approved by Dev (runtime scope, data home, delete scope, tool shape all
confirmed as the recommended options).

## Goal

Remove the retired vine-mask system (code, tool, shaders, bakes, and the old map art it edited),
and replace its authoring role with a **Zone Workbench**: the same polygon-drawing workflow,
pointed at the five picture-book pages, saving **unlock zones** per scene.

## Context

The build-and-upgrade redesign (spec 2026-07-17) retired the vine overlay at runtime. The scripts
`games/grove/vine/vine_maps.gd` and `vine_map_view.gd` are already deleted; every remaining vine
code path is dead and would crash if reached (it `load()`s the deleted scripts). The vine mask tool
(`make vine`) cannot even parse — it preloads the deleted view. The live map path renders pages via
`HomeZoneView` from generated `zone_<scene>.json` manifests.

## Part A — Full vine sweep

All of the following is removed in one pass (the dead cluster is mutually referential, so partial
removal breaks parsing):

1. `engine/scripts/scenes/map.gd`: the `is_vine` branches in `_seat_spots` and `_build_map_base`;
   `_build_vine_spot`; `_region_zone_hit`; `VINE_DEBUG_MODES`; `_vine_debug_mode_idx`;
   `debug_cycle_vine_fx`; `debug_vine_diag`; `_active_vine_view`; `_apply_vine_debug_mode`;
   `_vine_diag_enabled`; `_print_vine_diag`; stale vine comments. Call graph is verified before
   deletion (a helper may have a live non-vine caller — keep any such helper).
2. `engine/scripts/ui/debug.gd`: the "Vine FX mode" and "Vine diag" menu actions and their
   `_act_*` statics (registered via `has_method`, so they pair with the map.gd cluster).
3. Delete `games/tools/vine_mask_tool/` entirely: `VineMaskTool.tscn`, `vine_mask_tool.gd`,
   the three vine shaders, `maps/` region JSONs + `maps.json`, and the baked `region_map_*.png`
   files. The reusable pieces (`region_editor_overlay.gd`, `region_list_panel.gd`) move to the
   new tool first.
4. Delete `games/tools/bake_vine_region_maps.gd` (+ `.uid`); Makefile drops the `vine` and
   `bake-vine` targets; `bake` becomes `bake-textures` only.
5. Delete `games/grove/assets/baked/vine/` and the old map art the tool edited:
   `games/grove/assets/map/map1..5.png` and their `*_mask.png` — after grep-verifying no live
   reference. Decorative UI art whose name contains "vine" (`icon_vine` — the Play CTA restore
   face, `divider_vine`, `tiers_vine_*`) is **unrelated and stays**.
6. Stale comment fixes where they reference deleted pieces (e.g. `home_chrome.gd`'s
   `grove_vine_tests` pointer).

Raw originals under `assets/_originals/` are never deleted (art-guide rule).

## Part B — Zone Workbench

- New `games/tools/zone_workbench/`: `ZoneWorkbench.tscn` + `zone_workbench.gd`, plus the moved
  `region_editor_overlay.gd` and `region_list_panel.gd` (re-pathed; stars/cost column removed —
  the game derives unlock costs from the exp ladder, not the file).
- Launch: `make zones`. Optional quiet screenshot target only if trivially cheap; otherwise skip
  (grow tools incrementally).
- Scene picker lists the five picture-book pages from `G.MAPS` entries that carry a
  `zone_manifest`. The canvas renders the real page through `HomeZoneView.build` with every
  building resolved to "built", so zones are drawn on exactly what the game shows.
- Zones are polygons in native canvas coordinates (1320 x 2346). List order = unlock order.
  Each zone: `name`, `enabled`, `points` (>= 3 vertices), optional `button` point (the unlock
  disc anchor; absent = centroid), exactly like the vine regions minus cost/tuning.
- Save writes a sibling file `games/grove/assets/map/pages/unlocks_<scene>.json`:

  ```json
  {
    "version": 1,
    "scene": "fairy_hollow",
    "canvas": [1320, 2346],
    "zones": [
      {"name": "Zone 1", "enabled": true, "points": [[x, y], ...], "button": [x, y]}
    ]
  }
  ```

  Sibling files survive `build_page_manifests.py` regeneration of `zone_<scene>.json`.
- **Authoring only**: nothing at runtime reads `unlocks_<scene>.json` yet. Wiring the exp-gated
  tap-to-unlock flow to these zones is a follow-up task.

## Testing

- New headless suite `games/grove/tests/grove_zone_workbench_tests.gd` (added to `GROVE_TESTS`):
  boot the workbench headless, load a real page, `add_region`-equivalent + reorder + save, reload,
  assert round-trip fidelity and schema shape.
- `make test-fast` after each change; full `make test` before merge.

## Workflow

Work happens in a fresh out-of-tree worktree; on verified-done the branch merges to `main` and the
worktree is removed (standing workflow). Since baked art is deleted, no `make import` hazard, but
deleted `.import` files must be removed alongside their PNGs.
