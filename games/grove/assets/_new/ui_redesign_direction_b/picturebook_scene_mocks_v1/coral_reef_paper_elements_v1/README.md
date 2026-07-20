# Coral Reef Paper scene workbench bundle

New scene workbench target:

```bash
make sw SCENE=coral_reef_paper
make shot-sw SCENE=coral_reef_paper OUT=/tmp/coral_reef_paper_sw.png
```

This bundle was created from:

`games/grove/assets/_concepts/zones/layer_ready_coral_reef_v1`

The scene uses:

- `01_backdrop/coral_reef_paper_foundation_v1.png` as the fixed foundation.
- Five modular paper-plate hero props in `03_structures/`.
- `05_coverings/coral_reef_paper_cover_overlay_no_bubbles_v1.png` as the foreground occluder.
- `metadata/placements.json` as the workbench authority.

Known follow-up: regenerate bubbles as a dedicated atmosphere layer if we want animated/soft underwater bubble FX.
