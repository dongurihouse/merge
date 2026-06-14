extends RefCounted
## Game #1 — the BASE. Provides NO clothes: blank art/audio/font mean the engine draws
## its built-in placeholders, runs silent, and uses a system font. Reuses the shared
## ruleset + palette for now (its own dataset is a later step). This is the bare engine
## you test the mechanics on.
const ID := "placeholder"
const DATA := preload("res://games/grove/grove_data.gd")
const PALETTE := preload("res://games/grove/grove_palette.gd")
const ART_ROOT := ""
const AUDIO_ROOT := ""
const FONT := ""
