# Tidy Up (Donguri Merge) — project notes

## Asset intake

Raw art lands in `games/grove/assets/_originals/new/`. When asked to process intake or "pick up the
new art," follow `docs/design/asset-intake.md`: open and **classify** each drop, author a
`plan.json`, run `make intake`, verify, archive.

The split is load-bearing: **scripts are deterministic** (every pixel op + every file move);
**all judgment — classification, naming, params — goes in the plan**, authored by the agent. Scripts
never guess. Raws are archived, never deleted. Map scenes are handed off to the §16 flow in
`docs/design/grove_art_pipeline.md`, not auto-processed.
