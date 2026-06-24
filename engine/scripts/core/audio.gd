extends RefCounted
## Tiny SFX helper (preload + static; no autoload needed).
##   const Audio = preload("res://engine/scripts/core/audio.gd")
##   Audio.play("merge_success")
## Loads every cue named in music/sfx/manifest.json (one or more take-variants
## each) and round-robins a small player pool so sounds can overlap. Missing
## cues are silently skipped. play() varies pitch/gain per trigger (the juice).

const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").Audio

static var _sounds := {}      # name -> Array[AudioStream] (the variants)
static var _rr := {}          # name -> next variant index (round-robin)
static var _players: Array = []
static var _next := 0
static var _ready := false

static func _ensure() -> void:
	if _ready:
		return
	_ready = true
	var mpath := Game.sound("music/sfx/manifest.json")
	if mpath != "" and FileAccess.file_exists(mpath):
		var txt := FileAccess.get_file_as_string(mpath)
		var data: Dictionary = JSON.parse_string(txt) if txt != "" else {}
		var cues: Dictionary = data.get("cues", {})
		for name in cues:
			var count := int(cues[name])
			var variants: Array = []
			for v in range(count):
				var fn := "music/sfx/%s.wav" % name if count == 1 \
					else "music/sfx/%s_%d.wav" % [name, v + 1]
				var p := Game.sound(fn)
				if ResourceLoader.exists(p):
					variants.append(load(p))
			if not variants.is_empty():
				_sounds[name] = variants
	var root = Engine.get_main_loop().root
	for i in Tune.VOICES:
		var pl := AudioStreamPlayer.new()
		root.add_child(pl)
		_players.append(pl)

static func has(name: String) -> bool:
	_ensure()
	return _sounds.has(name)

static func variant_count(name: String) -> int:
	_ensure()
	return _sounds.get(name, []).size()

static func jitter_pitch(base: float) -> float:
	var cents := randf_range(-Tune.PITCH_JITTER_CENTS, Tune.PITCH_JITTER_CENTS)
	return base * pow(2.0, cents / 1200.0)

static func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not Save.get_setting("sfx", true):
		return
	_ensure()
	var variants: Array = _sounds.get(name, [])
	if variants.is_empty():
		return
	var idx := int(_rr.get(name, 0))             # round-robin per name
	_rr[name] = (idx + 1) % variants.size()
	var pl: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	pl.stream = variants[idx]
	pl.pitch_scale = jitter_pitch(pitch)         # center on caller's pitch, jitter on top
	pl.volume_db = volume_db + randf_range(-Tune.GAIN_JITTER_DB, Tune.GAIN_JITTER_DB)
	pl.play()
