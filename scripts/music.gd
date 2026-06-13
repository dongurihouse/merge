extends RefCounted
## Tidy Up — ONE continuous ambient playlist across every screen (order O).
## Two takes (assets/music/amb_grove1+2, .ogg wins over .mp3) alternate A↔B
## forever on `finished` — no crossfade, the material is near-silence. The
## player lives on root, so scene swaps never cut the audio. ensure() is
## idempotent: it NEVER restarts a playing stream. Degrades silently while
## no takes exist. The "music" user setting IS the toggle (no Features flag).

const Save = preload("res://scripts/save.gd")

const VOLUME_DB := -8.0

static var _player: AudioStreamPlayer
static var _take := 0              # index of the take last started
static var take_dir := "res://assets/music/"   # tests may point this at a fixture

## Start the playlist if it isn't already playing. Safe to call from every
## scene's _ready — a playing stream is left untouched.
static func ensure() -> void:
	if not bool(Save.get_setting("music", true)):
		return
	if _player != null and _player.playing:
		return                      # never interrupt the bed
	var takes := _takes()
	if takes.is_empty():
		return                      # nothing landed yet — quietly nothing
	_make_player()
	_start(takes[_take % takes.size()])

static func stop() -> void:
	if _player != null and _player.playing:
		_player.stop()

## Re-apply after the music setting changes (Off → stop, On → ensure).
static func refresh() -> void:
	if bool(Save.get_setting("music", true)):
		ensure()
	else:
		stop()

# --- internals ---------------------------------------------------------------------

## The takes present on disk, in order. Per take, .ogg wins if both ever exist.
## (.wav accepted last — the silent test fixture; real takes are ogg/mp3.)
static func _takes() -> Array:
	var out: Array = []
	for n in [1, 2]:
		for ext in ["ogg", "mp3", "wav"]:
			var p := "%samb_grove%d.%s" % [take_dir, n, ext]
			if ResourceLoader.exists(p) or FileAccess.file_exists(p):
				out.append(p)
				break
	return out

static func _start(path: String) -> void:
	var stream: AudioStream
	if path.ends_with(".wav") and not ResourceLoader.exists(path):
		stream = AudioStreamWAV.load_from_file(path)   # the unimported test fixture
	else:
		stream = load(path)
	if stream == null:
		return
	# loop stays FALSE — WE alternate takes on `finished`; the loop flag would
	# trap the playlist on take 1 forever
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = false
	_player.stream = stream
	_player.volume_db = VOLUME_DB
	# the player may still be entering the tree (add_child was deferred from a
	# scene's _ready) — playing before it's inside the tree errors, so defer too
	if _player.is_inside_tree():
		_player.play()
	else:
		_player.play.call_deferred()

static func _on_finished() -> void:
	var takes := _takes()
	if takes.is_empty():
		return
	_take += 1                      # alternate A↔B (a single take replays itself)
	_start(takes[_take % takes.size()])

static func _make_player() -> void:
	if _player != null:
		return
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.finished.connect(_on_finished)
	# deferred: ensure() is called from a scene's _ready, when root is mid-setup
	# ("busy setting up children" errors on a direct add_child)
	Engine.get_main_loop().root.add_child.call_deferred(_player)
