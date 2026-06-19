extends SceneTree
## Headless guard for the settings toggle SWITCH (Look.toggle_switch — the sliced
## kit/switch_on·off pill driving the music / sounds / calm rows).
##   godot --headless --path . -s res://engine/tests/switch_tests.gd
## Proves: the on/off sprites resolve as grove art (so the art branch runs, not the
## fallback), the builder seeds the requested state + paints the matching sprite, and a
## press flips the state, repaints, and fires on_changed with the new value.

const Look = preload("res://engine/scripts/ui/skin.gd")
const Game = preload("res://engine/scripts/core/game.gd")

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

	# --- the sliced sprites resolve as grove art (the art branch, not the fallback) ---
	ok(ResourceLoader.exists(Game.art("ui/kit/switch_on.png")), "switch_on.png resolves as grove art")
	ok(ResourceLoader.exists(Game.art("ui/kit/switch_off.png")), "switch_off.png resolves as grove art")

	# --- the builder seeds the requested state -----------------------------------
	var on_sw := Look.toggle_switch(true, func(_v: bool) -> void: pass)
	ok(bool(on_sw.get_meta("on")) == true, "built ON -> meta on == true")
	ok(on_sw.get_node_or_null("sw_art") != null, "art present -> sw_art TextureRect (not the fallback)")
	var off_sw := Look.toggle_switch(false, func(_v: bool) -> void: pass)
	ok(bool(off_sw.get_meta("on")) == false, "built OFF -> meta on == false")

	# --- the painted sprite matches the state ------------------------------------
	var off_art := off_sw.get_node("sw_art") as TextureRect
	ok(off_art.texture != null, "OFF switch paints a texture")
	ok(off_art.texture.resource_path.ends_with("switch_off.png"),
		"OFF paints switch_off.png (got %s)" % off_art.texture.resource_path)

	# --- a press flips the state, repaints, and fires on_changed(new) -------------
	var seen: Array = []
	var sw := Look.toggle_switch(false, func(v: bool) -> void: seen.append(v))
	sw.pressed.emit()
	ok(bool(sw.get_meta("on")) == true, "press OFF->ON flips meta to true")
	ok(seen.size() == 1 and bool(seen[0]) == true, "press fires on_changed(true)")
	ok((sw.get_node("sw_art") as TextureRect).texture.resource_path.ends_with("switch_on.png"),
		"press repaints to switch_on.png")
	sw.pressed.emit()
	ok(bool(sw.get_meta("on")) == false, "second press flips back to false")
	ok(seen.size() == 2 and bool(seen[1]) == false, "second press fires on_changed(false)")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
