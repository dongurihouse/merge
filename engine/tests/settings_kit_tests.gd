extends SceneTree
## Headless guard for the SETTINGS kit face — the new toggle_card + settings_dialog the game's
## engine/scripts/ui/settings.gd builds from (the SAME author-once-in-workbench / read-in-game pattern
## as the mailbox). Run:  godot --headless --path . -s res://engine/tests/settings_kit_tests.gd
## Proves: a toggle_card carries its label + the shared switch; pressing the switch flips the value and
## fires the entry's on_toggle; settings_dialog wraps the shared frame (banner) around one card per flag;
## and the config transforms read defaults + saved overrides — so the workbench's saved JSON drives it.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _find_switch(card: Node) -> Button:
	for b in card.find_children("", "Button", true, false):
		if (b as Button).has_meta("on"):
			return b
	return null

func _initialize() -> void:
	OS.set_environment("GAME", "grove")   # the card / switch art lives in grove's clothes (Game.art root)
	print("== Settings kit guard ==")

	# --- a toggle_card carries its label + the shared switch ----------------------
	var flipped: Array = [null]
	var card := Kit.toggle_card({
		"label": "Music", "value": false,
		"on_toggle": func(on: bool) -> void: flipped[0] = on,
	})
	var labels := card.find_children("", "Label", true, false)
	var has_label := false
	for l in labels:
		if (l as Label).text == "Music":
			has_label = true
	ok(has_label, "toggle_card shows its label ('Music')")
	var sw := _find_switch(card)
	ok(sw != null, "toggle_card embeds the shared toggle_switch (a Button with the 'on' meta)")
	ok(sw != null and bool(sw.get_meta("on")) == false, "switch seeds the entry value (off)")

	# --- pressing the switch flips the value AND fires the entry's on_toggle -------
	if sw != null:
		sw.pressed.emit()
	ok(sw != null and bool(sw.get_meta("on")) == true, "press flips the switch on")
	ok(flipped[0] == true, "press fires on_toggle(true)")
	if sw != null:
		sw.pressed.emit()
	ok(flipped[0] == false, "second press fires on_toggle(false)")

	# --- card_art off still builds (the flat-pill fallback) -----------------------
	var flat := Kit.toggle_card({"label": "Sounds", "value": true}, {"card_art": false})
	ok(_find_switch(flat) != null, "card_art off still builds a working row")

	# --- settings_dialog = the shared frame (banner) + one card per flag ----------
	var dialog := Kit.settings_dialog(Kit.DEMO_SETTINGS, 540.0, {"banner_text": "Settings"})
	ok(dialog.find_child("DialogBanner", true, false) != null, "settings_dialog wraps the SHARED frame (banner present)")
	var switches := 0
	for b in dialog.find_children("", "Button", true, false):
		if (b as Button).has_meta("on"):
			switches += 1
	ok(switches == Kit.DEMO_SETTINGS.size(), "settings_dialog renders one toggle row per flag (%d)" % switches)

	# --- the config transforms: defaults + saved overrides ------------------------
	var d := Kit.toggle_card_opts_from_config({})
	ok(int(d.get("label_font", 0)) == 28 and float(d.get("switch_h", 0)) == 44.0 and bool(d.get("card_art", false)) == true,
		"toggle_card_opts defaults (label_font 28 · switch_h 44 · card_art on)")
	var o := Kit.toggle_card_opts_from_config({"toggle_card": {"label_font": 30, "switch_h": 50, "card_art": false}})
	ok(int(o.get("label_font", 0)) == 30 and float(o.get("switch_h", 0)) == 50.0 and bool(o.get("card_art", true)) == false,
		"toggle_card_opts reads saved overrides")
	var so := Kit.settings_opts_from_config({"settings": {"row_gap": 20}})
	ok(so.has("toggle") and so["toggle"] is Dictionary, "settings_opts carries the toggle-card style under 'toggle'")
	ok(float(so.get("row_gap", -1)) == 20.0, "settings_opts reads the saved row_gap")
	ok(so.has("banner_font") and so.has("close_size"), "settings_opts inherits the shared frame chrome")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
