# Fairy Hollow unlock canopy — concept pack v1

This pack demonstrates an unlock treatment where a finished Fairy Hollow scene is hidden by a
small family of large cut-paper leaf tiles. The cover is not a baked blanket: each processed PNG
is independently removable, repeatable, and can be rotated or scaled slightly.

## Contents

- `mock/fairy_hollow_fully_unlocked_mock_v1.png` — the completely revealed target scene.
- `mock/fairy_hollow_fully_covered_leaf_canopy_mock_v1.png` — visual direction for a fully
  locked scene; the visible seams show the intended removable-tile language.
- `cover_sprites/processed/` — six RGBA canopy pieces on transparent backgrounds.
- `preview/fairy_hollow_leaf_canopy_assembled_preview_v1.png` — a deterministic assembly test
  using the separate sprites over the unlocked mock.

Gameplay rule: start with overlapping cover pieces (the heavier pieces first); removing one
reveals the underlying scene directly. Do not add an empty socket or replacement ground beneath a
removed piece.
