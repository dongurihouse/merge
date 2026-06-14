extends RefCounted
## THE switch: which game the shared engine runs. ACTIVE picks the clothes
## (art/audio, via Game); DATA picks the content/tuning tables (compile-time, so
## the engine can read them as consts). Switch BOTH together to change games.
## Games live in games/<name>/.
const ACTIVE := "placeholder"
# 1a: placeholder runs on the grove ruleset (data is OUT of the engine now); its
# OWN minimal generic dataset is the next sub-step (1b).
const DATA := preload("res://games/grove/grove_data.gd")
const PALETTE := preload("res://games/grove/grove_palette.gd")   # the active game's colours
