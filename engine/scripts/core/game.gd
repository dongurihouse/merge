extends RefCounted
## The active game's parameters, asked by the engine instead of hardcoding them.
## DATA + PALETTE are the COMPILE-TIME base ruleset (GDScript can't reach a script's
## consts through a runtime var, so they can't be a per-run env layer); the CLOTHES
## (art/audio/font) layer on at RUNTIME, picked by the GAME env var. A game provides
## what it has — a blank field means "use the engine default" (placeholder / silent /
## system font). The active build + roster live in games/active.gd; each game's own
## parameters live in games/<name>/game.gd.
const Active := preload("res://games/active.gd")

# the compile-time base ruleset — engine scripts read these as consts (G.<CONST>, Pal)
const DATA := Active.DATA
const PALETTE := Active.PALETTE

## Which game's CLOTHES are active: the GAME env var, else the bare base. No source
## edit per run — `make run_base` / `make run_grove` just set GAME=.
static func active() -> String:
	var e := OS.get_environment("GAME")
	return e if not e.is_empty() else Active.DEFAULT

## The active clothes manifest (runtime); an unknown GAME falls back to the base.
static func _m():
	return Active.ROSTER.get(active(), Active.ROSTER[Active.DEFAULT])

## res:// path for an art asset (rel = path under a game's art root, e.g.
## "items/flower/flower_1.png"), or "" when this game has no clothes for it — the caller's
## ResourceLoader.exists() then fails and the engine draws its built-in placeholder.
static func art(rel: String) -> String:
	var root: String = _m().ART_ROOT
	return "" if root == "" else root + rel

## res:// path for a sound/music asset, or "" (silent).
static func sound(rel: String) -> String:
	var root: String = _m().AUDIO_ROOT
	return "" if root == "" else root + rel

## res:// path of the active game's UI font, or "" (engine falls back to a system font).
static func font() -> String:
	return _m().FONT

## res:// path of the active game's UI KIT script, or "" (engine draws its code-drawn fallbacks).
## The kit preloads engine scripts, so the engine can only reach it by runtime load() — hence a
## path, not a script ref. THE indirection for every `load(Game.kit())` in engine/scripts/.
static func kit() -> String:
	return _m().KIT

## res:// path of the kit's workbench-saved settings JSON, or "" (defaults stand). Declared in the
## manifest rather than derived from kit(): it is a sibling FILE, not a suffix of the script, and
## reading it through the kit would need the kit loaded first (a cycle on the engine's FX path).
static func kit_settings() -> String:
	return _m().KIT_SETTINGS

## res:// path of the active game's home/map chrome-id script, or "" (the map bakes its fallback).
static func home_chrome() -> String:
	return _m().HOME_CHROME
