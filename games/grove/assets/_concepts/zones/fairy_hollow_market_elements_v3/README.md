# Fairy Hollow Market v3 — unlock canopy

This is the locked-state companion to the accepted v2 Fairy Hollow Market scene.
The original market remains in `primary_objects`; the paper-leaf cover is divided into six
`unlock_region_<primary_object>` clusters in the fixed `coverup` layer. Remove one
complete region cluster to uncover its corresponding market object: mushroom hall, tea stall,
crystal-map stall, stream bridge, flower crate, or lantern gate. Never bake the cover into the
foundation.

Open it with:

```bash
make sw SCENE=fairy_hollow_market ROOT=res://games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1
```

`fairy_hollow_market_elements_v3` is intentionally the highest-numbered bundle, so Scene
Workbench selects it. The v2 unlocked composition is left untouched for reference and rollback.
