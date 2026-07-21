# Hollow v3 — unlock canopy

(Bundle renamed from `fairy_hollow_market_elements_v3` to `hollow_elements_v3` on 2026-07-21; the
scene is now the one-word `hollow` page. Composition unchanged.)

This is the locked-state companion to the accepted v2 Hollow scene.
The original market remains in `primary_objects`; the paper-leaf cover is divided into six
`unlock_region_<primary_object>` clusters in the fixed `coverup` layer. Remove one
complete region cluster to uncover its corresponding market object: mushroom hall, tea stall,
crystal-map stall, stream bridge, flower crate, or lantern gate. Never bake the cover into the
foundation.

Open it with:

```bash
make sw SCENE=hollow ROOT=res://games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1
```

`hollow_elements_v3` is intentionally the highest-numbered bundle, so Scene
Workbench selects it. The v2 unlocked composition is left untouched for reference and rollback.
