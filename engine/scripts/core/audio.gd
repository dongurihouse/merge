extends RefCounted
## Tiny SFX helper (preload + static; no autoload needed).
##   const Audio = preload("res://engine/scripts/core/audio.gd")
##   Audio.play("merge_success")
## Loads the named effects (FILES) from the active game's audio root once and
## round-robins a small player pool so sounds can overlap. Missing files are
## silently skipped.

const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").Audio   # the engine's audio dials

const FILES := [
	"button_tap", "invalid_soft", "item_drop", "item_pickup",
	"level_complete", "merge_soft", "merge_success", "tidy_poof",
]

static var _sounds := {}
static var _players: Array = []
static var _next := 0
static var _ready := false

static func _ensure() -> void:
	if _ready:
		return
	_ready = true
	var root = Engine.get_main_loop().root
	for n in FILES:
		var p := Game.sound("music/sfx/%s.wav" % n)
		if ResourceLoader.exists(p):
			_sounds[n] = load(p)
	for i in Tune.VOICES:
		var pl := AudioStreamPlayer.new()
		root.add_child(pl)
		_players.append(pl)

static func has(name: String) -> bool:
	_ensure()
	return _sounds.has(name)

static func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not Save.get_setting("sfx", true):
		return
	_ensure()
	if not _sounds.has(name):
		return
	var pl: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	pl.stream = _sounds[name]
	pl.volume_db = volume_db
	pl.pitch_scale = pitch
	pl.play()
