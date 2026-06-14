extends RefCounted
## Game #1 — PLACEHOLDER. Pure mechanism, no clothes: empty roots mean the engine
## renders its built-in placeholders (tier discs, name chips, glyph icons) and is
## silent. This is the bare engine you test the mechanics on.
const ART_ROOT := ""
const AUDIO_ROOT := ""
const FONT := ""                          # no font → the engine uses a system rounded face
# 1a: placeholder runs on the grove ruleset for now (data is OUT of the engine);
# its OWN minimal generic dataset is the next sub-step (1b).
const DATA = preload("res://games/grove/grove_data.gd")
