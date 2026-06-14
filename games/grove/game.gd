extends RefCounted
## Game #2 — GROVE. A full clothes layer over the base engine: art, audio, and font,
## plus the ruleset + palette it shares as the base. Blank fields = engine default.
const ID := "grove"
const DATA := preload("res://games/grove/grove_data.gd")        # the grove's content + tuning
const PALETTE := preload("res://games/grove/grove_palette.gd")  # the grove's colours
const ART_ROOT := "res://games/grove/assets/"
const AUDIO_ROOT := "res://games/grove/assets/"
const FONT := "res://games/grove/fonts/ui.ttf"                  # grove's UI face (Baloo 2, OFL)
