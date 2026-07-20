extends SceneTree
## Headless guard for the settings toggle SWITCH (Look.toggle_switch — the sliced
## kit/switch_on·off pill driving the music / sounds rows).
##   godot --headless --path . -s res://engine/tests/switch_tests.gd
## Proves: the on/off sprites resolve as grove art (so the art branch runs, not the
## fallback), the builder seeds the requested state + paints the matching sprite, and a
## press flips the state, repaints, and fires on_changed with the new value.

const Look = preload("res://engine/scripts/ui/skin.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _initialize() -> void:
	OS.set_environment("GAME", "grove")   # the switch art lives in grove's clothes (Game.art root)
	print("== Toggle switch guard ==")

	# --- the switch is CODE-DRAWN now (the muddy switch_on/off.png art is retired): a track + a knob ----
	var track_color := func(sw: Button) -> Color:
		var tr := sw.get_node("sw_track") as Panel
		return (tr.get_theme_stylebox("panel") as StyleBoxFlat).bg_color

	# --- the builder seeds the requested state -----------------------------------
	var on_sw := Look.toggle_switch(true, func(_v: bool) -> void: pass)
	ok(bool(on_sw.get_meta("on")) == true, "built ON -> meta on == true")
	ok(on_sw.get_node_or_null("sw_art") == null and on_sw.get_node_or_null("sw_track") != null \
		and on_sw.get_node_or_null("sw_knob") != null, "code-drawn: a track + knob, not the retired sprite")
	ok(track_color.call(on_sw).is_equal_approx(Pal.BTN_PRIMARY), "ON track is leaf green")
	var off_sw := Look.toggle_switch(false, func(_v: bool) -> void: pass)
	ok(bool(off_sw.get_meta("on")) == false, "built OFF -> meta on == false")

	# --- the OFF track is a clean neutral slate, NOT the old muddy bark brown ----
	var off_c: Color = track_color.call(off_sw)
	ok(not off_c.is_equal_approx(Pal.BTN_PRIMARY), "OFF track is not the ON green")
	ok(off_c.is_equal_approx(Color(Pal.INK, 0.22)), "OFF track is the clean neutral slate (not bark brown)")
	# the knob slides to the two ends per state (OFF left of ON)
	var off_knob := off_sw.get_node("sw_knob") as Panel
	var on_knob := on_sw.get_node("sw_knob") as Panel
	ok(off_knob.position.x < on_knob.position.x, "the knob sits left when OFF, right when ON")

	# --- a press flips the state, repaints, and fires on_changed(new) -------------
	var seen: Array = []
	var sw := Look.toggle_switch(false, func(v: bool) -> void: seen.append(v))
	sw.pressed.emit()
	ok(bool(sw.get_meta("on")) == true, "press OFF->ON flips meta to true")
	ok(seen.size() == 1 and bool(seen[0]) == true, "press fires on_changed(true)")
	ok(track_color.call(sw).is_equal_approx(Pal.BTN_PRIMARY), "press repaints the track to ON green")
	sw.pressed.emit()
	ok(bool(sw.get_meta("on")) == false, "second press flips back to false")
	ok(seen.size() == 2 and bool(seen[1]) == false, "second press fires on_changed(false)")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
