extends RefCounted
## The active build. There is NO global game config — each game's parameters live in
## its own games/<name>/game.gd, and this file just says which build is active.
##
## DATA + PALETTE are the COMPILE-TIME base ruleset + colours: GDScript reads a
## script's consts only through a compile-time class ref, so these can't be a per-run
## env layer — BASE is the one build-level pick (grove's, shared by the bare base for
## now). The CLOTHES (art/audio/font) of each game in ROSTER layer on at RUNTIME via
## the GAME env var — no source edits; `make run_base` / `make run_grove` set GAME=.

# The compile-time base ruleset + colours.
const BASE := preload("res://games/grove/game.gd")
const DATA := BASE.DATA
const PALETTE := BASE.PALETTE

# The games whose clothes can layer on at runtime; GAME= picks one (default: bare base).
const ROSTER := {
	"placeholder": preload("res://games/placeholder/game.gd"),
	"grove": preload("res://games/grove/game.gd"),
}
const DEFAULT := "placeholder"
