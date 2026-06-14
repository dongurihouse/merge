extends RefCounted
## The ACTIVE game's clothes (art + audio roots), asked by the engine instead of
## hardcoding asset paths. A game = games/<name>/game.gd (its manifest) + its art.
## To add a game: create games/<name>/game.gd and register it in _GAMES below.

const Config = preload("res://game_config.gd")
const _GAMES := {
	"placeholder": preload("res://games/placeholder/game.gd"),
	"grove": preload("res://games/grove/game.gd"),
}

static func _m():
	return _GAMES.get(Config.ACTIVE, _GAMES["placeholder"])

## res:// path for an art asset (rel = path under a game's art root, e.g.
## "items/flower_1.png"), or "" when this game has no clothes for it — the caller's
## ResourceLoader.exists() then fails and the engine draws its built-in placeholder.
static func art(rel: String) -> String:
	var root: String = _m().ART_ROOT
	return "" if root == "" else root + rel

## res:// path for a sound/music asset, or "" (silent).
static func sound(rel: String) -> String:
	var root: String = _m().AUDIO_ROOT
	return "" if root == "" else root + rel

static func id() -> String:
	return String(Config.ACTIVE)
