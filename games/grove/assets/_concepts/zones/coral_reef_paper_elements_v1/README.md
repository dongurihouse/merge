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
- `01_backdrop/coral_reef_paper_foundation_no_extra_plates_v2.png` removes extra raised platform cap plates so only modular props own visible paper plates.
- `01_backdrop/coral_reef_paper_foundation_undersea_gray_v3.png` is the active foundation: it preserves those v2 sockets while using muted gray-teal water and slate-blue paper ledges for a deeper underwater mood.
- Five modular paper-plate hero props in `03_structures/`.
- `05_coverings/coral_reef_paper_cover_overlay_no_bubbles_v1.png` as the foreground occluder.
- `metadata/placements.json` as the workbench authority.

Known follow-up: regenerate bubbles as a dedicated atmosphere layer if we want animated/soft underwater bubble FX.
