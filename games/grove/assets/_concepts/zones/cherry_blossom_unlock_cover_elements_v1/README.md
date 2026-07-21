# Cherry Blossom Unlock Cover Mock v1

This concept separates the fully unlocked garden from the locked-state cover.

- `00_unlocked/cherry_blossom_unlocked_reference_v1.png` is the clean, fully unlocked garden reference.
- `01_covered_mock/cherry_blossom_fully_covered_unlock_mock_v1.png` shows the intended fully locked presentation: individual oversized cherry-blossom paper pieces overlap until the scene is hidden.
- `02_cover_pieces/*.png` are the production-ready transparent cover pieces. Reuse, rotate, and overlap them to hide any chosen screen region; remove the relevant instances to reveal that region.
- `metadata/placements.json` is the Scene Workbench scene. It keeps the garden's four primary objects in `primary_objects` and puts all locking petals in the top `coverup` layer.

## Cover-piece roles

| Asset | Best use |
| --- | --- |
| `blossom_cover_round_rosette_v1.png` | Primary broad-area fill |
| `blossom_cover_drifting_petal_v1.png` | Directional seam breaker or irregular negative space |
| `blossom_cover_triple_cluster_v1.png` | Wide horizontal span |
| `blossom_cover_floral_fan_v1.png` | Map-edge and boundary fill |
| `blossom_cover_corner_cascade_v1.png` | Large corner/diagonal cap |

All final cover PNGs are `768 x 768` RGBA images. Their matching `_raw.png` files retain the original `#FF00FF` keyed sources for reprocessing. The intermediate `_processed_*` folders are pipeline evidence from the alpha cleanup step.

## Assembly contract

Place the cover pieces above every map and object layer. Use 15–25% overlap between neighbouring silhouettes and vary rotation/scale slightly. Keep their internal paper shadows; do not add a global dimming mask. A region unlock removes only the cover-piece instances assigned to that region, letting the uncovered garden remain visually coherent.

The Workbench scene has one removable `coverup` cluster for each primary object:

- `unlock_region_pavilion`
- `unlock_region_pond_bridge`
- `unlock_region_temizuya`
- `unlock_region_torii`

Removing a whole cluster reveals exactly its paired primary object. The cover is never baked into the stable backdrop or the objects themselves.

Open the scene with:

```bash
make sw SCENE=cherry_blossom_unlock_cover
```
