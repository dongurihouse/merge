extends RefCounted
## PRODUCTION vs DEBUG mode (owner 2026-06-12).
##
## PRODUCTION is the default and is always CLEAN — no authoring chrome, no debug
## affordances, nothing a player could stumble into. DEBUG unlocks the owner's
## authoring tools; today that means the drag-to-place editor (Layout) on the map
## and inside rooms — adjust placements, then SAVE them. New debug adjustments
## hang off Debug.on() the same way.
##
## The BASE game (games/placeholder) is ALWAYS in debug — running it IS the test
## harness; the real game (grove) stays clean. Force debug on ANY game, NO source
## edit:
##     godot --path . -- debug          (everything after -- is a user arg)
##   or set an environment variable:
##     TU_DEBUG=1 godot --path .
##
## Debug is NEVER on in headless logic suites or quiet capture runs (those would
## pollute tests/screenshots). Capture tools that WANT the debug chrome set
## Debug.force = true explicitly (e.g. tools/home_shot.gd `place=1`).

const Save = preload("res://engine/scripts/save.gd")
const G = preload("res://engine/scripts/content.gd")
const Game = preload("res://engine/scripts/game.gd")

static var force := false

static func on() -> bool:
	if force:
		return true
	if DisplayServer.get_name() == "headless":
		return false                     # logic suites
	if OS.get_environment("TU_QUIET") == "1":
		return false                     # quiet capture runs
	if Game.id() == "placeholder":
		return true                      # the base/testing build always has debug
	if OS.get_environment("TU_DEBUG") == "1":
		return true
	return "debug" in OS.get_cmdline_user_args()


# --- on-screen debug panel (base/testing only) -----------------------------------
## A corner toggle that expands to a column of state-jump actions. Map and Board
## call this at the END of _ready(); it's a NO-OP unless on(), so it never appears
## in production, headless tests, or quiet captures. Add an action = one _action().
static func mount(host: Control) -> void:
	if not on():
		return
	var layer := CanvasLayer.new()
	layer.name = "DebugOverlay"
	layer.layer = 128                      # above every game chrome layer
	var col := VBoxContainer.new()
	col.position = Vector2(12, 64)         # top-left, clear of the notch + HUD
	col.add_theme_constant_override("separation", 4)
	layer.add_child(col)

	var menu := VBoxContainer.new()
	menu.visible = false
	menu.add_theme_constant_override("separation", 4)
	var toggle := _dbg_button("DEBUG", Color("#C0392B"))
	toggle.pressed.connect(func() -> void: menu.visible = not menu.visible)
	col.add_child(toggle)
	col.add_child(menu)

	_action(menu, host, "Reset progress", _act_reset)
	_action(menu, host, "+100 premium", _act_premium)
	_action(menu, host, "Unlock next zone", _act_unlock_zone)
	_action(menu, host, "Level up", _act_level_up)

	host.add_child(layer)

static func _action(menu: VBoxContainer, host: Control, label: String, fn: Callable) -> void:
	var b := _dbg_button(label, Color("#2C3E50"))
	b.pressed.connect(fn.bind(host))
	menu.add_child(b)

static func _dbg_button(text: String, bg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(184, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color.WHITE)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(bg, 0.92)
	s.set_corner_radius_all(6)
	s.set_border_width_all(2)
	s.border_color = Color(1, 1, 1, 0.5)
	s.content_margin_left = 12.0
	s.content_margin_right = 12.0
	s.content_margin_top = 6.0
	s.content_margin_bottom = 6.0
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	b.add_theme_stylebox_override("pressed", s)
	return b

# --- actions: mutate Save, then reload the scene so the change shows --------------
static func _reflect(host: Control) -> void:
	if host.is_inside_tree():
		host.get_tree().call_deferred("reload_current_scene")

static func _act_reset(host: Control) -> void:
	Save.reset()
	_reflect(host)

static func _act_premium(host: Control) -> void:
	Save.add_diamonds(100)               # the free premium currency; convert via shop
	_reflect(host)

## Unlock every spot in the next unfinished zone + grant the matching exp, so the
## chapter (= spots bought) and the level advance together, exactly like real play.
static func _act_unlock_zone(host: Control) -> void:
	var g := Save.grove()
	var unlocks: Dictionary = g.get("unlocks", {})
	g["unlocks"] = unlocks
	var z := -1
	for i in G.ZONES.size():
		if not G.zone_done(i, unlocks):
			z = i
			break
	if z < 0:
		return                              # every zone already restored
	var cost := 0
	for sp in G.ZONES[z].spots:
		var sid := String(sp.id)
		if not unlocks.has(sid):
			unlocks[sid] = true
			cost += int(sp.cost)
	g["exp"] = int(g.get("exp", 0)) + cost * G.EXP_PER_STAR
	Save.grove_write()
	_reflect(host)

## Push exp just past the next level threshold (a no-op once at max level).
static func _act_level_up(host: Control) -> void:
	var g := Save.grove()
	var lvl := G.level_for_exp(int(g.get("exp", 0)))
	if lvl >= G.LEVEL_XP.size():
		return                              # already at max level
	g["exp"] = int(G.LEVEL_XP[lvl])
	Save.grove_write()
	_reflect(host)
