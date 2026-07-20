# Fairy Hollow Market v3 — unlock canopy

This is the locked-state companion to the accepted v2 Fairy Hollow Market scene.
The original market remains in `primary_objects`; each paper-leaf cover is a separate cluster in
the fixed `foreground_objects` layer. Remove one complete `unlock_canopy_*` cluster when that
part of the scene unlocks. Never bake the cover into the foundation.

Open it with:

```bash
make sw SCENE=fairy_hollow_market ROOT=res://games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1
```

`fairy_hollow_market_elements_v3` is intentionally the highest-numbered bundle, so Scene
Workbench selects it. The v2 unlocked composition is left untouched for reference and rollback.
