extends RefCounted
## Two debug gates (owner). PRODUCTION is the default and always CLEAN.
##
## on()  — the on-screen STATE-JUMP panel (reset / premium / unlock / level-up).
##         Shows only when authoring() (below) is on: the same explicit debug gate
##         as the layout editor, minus quiet captures (see on()).
##
## authoring() — the owner's drag-to-place LAYOUT editor (adjust placements on the
##         map + inside rooms, then SAVE). Turned on DELIBERATELY; never auto-on.
##         Enable with NO source edit:
##             godot --path . -- debug      (args after -- are user args)
##             TU_DEBUG=1 godot --path .
##
## Neither gate is ever on in headless logic suites or quiet capture runs (they'd
## pollute tests/screenshots). Capture tools that WANT the layout-editor chrome set
## Debug.force = true (e.g. games/grove/tools/map_shot.gd `place=1`) — force drives authoring()
## only, so the state-jump panel never leaks into a screenshot.

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Login = preload("res://engine/scripts/core/login.gd")   # the daily calendar — debug_advance_day()
const Look = preload("res://engine/scripts/ui/skin.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").Hud       # EDGE_MARGIN — the level badge's top inset
# The level-badge BOX height — mirrors Hud.LV_BADGE_PX (NOT preloaded: hud.gd ↔ scene preloads form a cycle).
# The debug menu sits just below the badge box; keep this in sync if the HUD badge size changes.
const LV_BADGE_BOX := 225.0

static var force := false

## Whether the action column is expanded. Persists across the scene reload an
## action triggers, so the panel stays open and you can tap actions repeatedly.
static var _menu_open := false

## The state-jump debug PANEL: on only when explicitly authoring(). Never in
## headless suites or quiet captures — the quiet guard here also keeps the panel
## out of force-driven screenshots (force bypasses quiet in authoring() below).
static func on() -> bool:
	if DisplayServer.get_name() == "headless":
		return false                     # logic suites never show chrome
	if OS.get_environment("TU_QUIET") == "1":
		return false                     # quiet captures stay clean of the panel
	return authoring()                   # only when explicitly authoring

## The owner LAYOUT editor: explicit only (force / TU_DEBUG / `-- debug`), ANY game.
## NOT auto-on in base. force is checked first so capture tools get the editor even
## under TU_QUIET (where the panel above stays hidden).
static func authoring() -> bool:
	if force:
		return true
	if DisplayServer.get_name() == "headless":
		return false
	if OS.get_environment("TU_QUIET") == "1":
		return false
	if OS.get_environment("TU_DEBUG") == "1":
		return true
	return "debug" in OS.get_cmdline_user_args()


# --- on-screen debug panel (debug/authoring only) --------------------------------
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
	# Pinned just below the level badge — RELATIVE to its box (top inset + safe-top + the badge box height),
	# so it follows the badge's size instead of a fixed 120 that the bigger badge now overlaps.
	col.position = Vector2(12, Tune.EDGE_MARGIN + Look.safe_top(host) + LV_BADGE_BOX + 8.0)
	col.add_theme_constant_override("separation", 4)
	layer.add_child(col)

	var menu := VBoxContainer.new()
	menu.visible = _menu_open               # reopen after an action's scene reload
	menu.add_theme_constant_override("separation", 4)
	var toggle := _dbg_button("DEBUG", Color("#C0392B"))
	toggle.pressed.connect(func() -> void:
		_menu_open = not _menu_open
		menu.visible = _menu_open)
	col.add_child(toggle)
	col.add_child(menu)

	_action(menu, host, "Reset progress", _act_reset)
	_action(menu, host, "+100 premium", _act_premium)
	_action(menu, host, "+5 stars", _act_stars)
	_action(menu, host, "Unlock next map", _act_unlock_map)
	_action(menu, host, "Level up", _act_level_up)
	_action(menu, host, "Advance day", _act_advance_day)
	_action(menu, host, "-25 water", _act_reduce_water)
	if host.has_method("debug_drop_coin"):       # board-only: spawn a coin to exercise tap-to-collect
		_action(menu, host, "Drop coin", _act_drop_coin)

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

## Top up the exp total so you can claim spots through the normal UI (the single unlock
## button enables as exp crosses each spot's threshold). Exactly like real play — earn_exp
## advances the one progression total. Tap again for the big later-map gate spots.
static func _act_stars(host: Control) -> void:
	G.earn_exp(5)
	_reflect(host)

## Claim every spot in the next unfinished map + push exp past its thresholds (so the next
## map opens), exactly like real play.
static func _act_unlock_map(host: Control) -> void:
	var g := Save.grove()
	var unlocks: Dictionary = g.get("unlocks", {})
	g["unlocks"] = unlocks
	var z := -1
	for i in G.MAPS.size():
		if not G.map_spots_done(i, unlocks):
			z = i
			break
	if z < 0:
		return                              # every map already restored
	for sp in G.MAPS[z].spots:
		unlocks[String(sp.id)] = true
	# bump exp to where the NEXT map opens — covers all of map z's spot thresholds
	g["exp"] = maxi(int(g.get("exp", 0)), G.spot_unlock_exp(z + 1, 0))
	Save.grove_write()
	_reflect(host)

## Push exp to the next level threshold (the clock is uncapped).
static func _act_level_up(host: Control) -> void:
	var g := Save.grove()
	var lvl := G.level_for_exp(int(g.get("exp", 0)))
	g["exp"] = G.exp_at_level(lvl + 1)
	Save.grove_write()
	_reflect(host)

## Fast-forward the daily-login calendar to the next day (claims today to advance the
## streak, then reopens the claim) — the game's designated "next day" debug helper.
## Water regen is real-time, not day-based, so this does not refill the can.
static func _act_advance_day(host: Control) -> void:
	Login.debug_advance_day()
	_reflect(host)

## Board-only: drop a coin onto a free cell so you can exercise the tap-to-collect flow on demand.
## No _reflect — the coin animates in live and debug_drop_coin() persists it (no scene reload).
static func _act_drop_coin(host: Control) -> void:
	if host.has_method("debug_drop_coin"):
		host.debug_drop_coin()

## Knock 25 off the water can (floored at 0) to walk down into the out-of-water flow.
static func _act_reduce_water(host: Control) -> void:
	var g := Save.grove()
	g["water"] = maxi(0, int(g.get("water", G.WATER_CAP)) - 25)
	Save.grove_write()
	_reflect(host)
