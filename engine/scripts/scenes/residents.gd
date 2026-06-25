extends Control
## The Residents screen — the management hub for the habitat loop (residents expansion).
## Renders the in-hand holding area + each completed map's habitat, and drives place / merge /
## collect / sell / acquire via engine/scripts/core/habitat.gd. Reached from the map's residents
## button; returns to the Map scene. (Supersedes the per-map welcome overlay — that legacy path
## in map.gd stays callable but is no longer the entry point.)

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Habitat = preload("res://engine/scripts/core/habitat.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")

var _hud: Dictionary = {}
var _root: Control = null

func _ready() -> void:
	_hud = Hud.build(self, {"on_refresh": func() -> void: _rebuild()})
	_build()

## Tear down + rebuild the content column from the live model. Called after every action.
func _rebuild() -> void:
	if _root != null:
		_root.queue_free()
	_build()

func _build() -> void:
	# 1. content column (a VBoxContainer under the HUD band)
	# 2. the COMPLETED maps as rows (G.completed_maps / G.can_populate gate which maps show)
	# 3. the hand strip
	# 4. the acquire-stub button + the Back button
	# (Detailed wiring in Tasks 6-7.)
	pass

func _on_back() -> void:
	Audio.play("button_tap", -2.0)
	SceneWarm.go(get_tree(), "res://engine/scenes/Map.tscn")
