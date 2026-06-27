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

	# --- a single physical tap on the CARD flips the switch exactly ONCE -----------
	# Regression: with emulate_touch_from_mouse=true one click delivers BOTH a mouse-button
	# AND a screen-touch press to the card; the handler must act on only one, or the switch
	# flips twice (net no-op) and the setting "won't save" (the Sounds-toggle bug).
	var taps: Array = [0]
	var tap_card := Kit.toggle_card({
		"label": "Sounds", "value": true,
		"on_toggle": func(_on: bool) -> void: taps[0] += 1,
	})
	var mb := InputEventMouseButton.new(); mb.button_index = MOUSE_BUTTON_LEFT; mb.pressed = true
	var st := InputEventScreenTouch.new(); st.index = 0; st.pressed = true
	tap_card.gui_input.emit(mb)   # the real mouse press
	tap_card.gui_input.emit(st)   # the emulated touch press from the SAME click
	ok(taps[0] == 1, "one physical card tap fires on_toggle exactly once (no double-fire)")

	# --- rich toggle cards can present mail-style rows ----------------------------
	var rich := Kit.toggle_card({
		"icon": "leaf", "title": "Lantern", "body": "+15s time", "cost": 120, "value": true,
	}, {"label_font": 19, "body_font": 15, "card_art": true})
	var rich_labels := rich.find_children("", "Label", true, false)
	var has_title := false
	var has_body := false
	for l in rich_labels:
		var txt := (l as Label).text
		if txt == "Lantern":
			has_title = true
		if txt == "+15s time":
			has_body = true
	ok(has_title, "rich toggle_card shows a title label")
	ok(has_body, "rich toggle_card shows a detail/body label")
	var cost_chip: Button = null
	for b in rich.find_children("", "Button", true, false):
		var btn := b as Button
		if btn.text == "120" and not btn.has_meta("on"):
			cost_chip = btn
	ok(cost_chip != null, "rich toggle_card shows the cost as a separate cream chip")
	var rich_sw := _find_switch(rich)
	ok(rich_sw != null and cost_chip != null and rich_sw.get_index() > cost_chip.get_index(),
		"rich toggle_card puts the toggle after the cost chip")

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

	# --- settings_dialog renders an optional footer LINK (privacy policy) ----------
	var tapped: Array = [false]
	var linked := Kit.settings_dialog(Kit.DEMO_SETTINGS, 540.0, {
		"banner_text": "Settings",
		"footer_text": "Privacy Policy",
		"on_footer": func() -> void: tapped[0] = true,
	})
	var link: LinkButton = null
	for b in linked.find_children("", "LinkButton", true, false):
		if (b as LinkButton).text == "Privacy Policy":
			link = b
	ok(link != null, "settings_dialog renders the footer link ('Privacy Policy')")
	if link != null:
		link.pressed.emit()
	ok(tapped[0] == true, "pressing the footer link fires on_footer")

	# footer off by default → no link (the workbench preview stays a pure toggle list)
	var plain := Kit.settings_dialog(Kit.DEMO_SETTINGS, 540.0, {"banner_text": "Settings"})
	ok(plain.find_children("", "LinkButton", true, false).is_empty(), "no footer link when footer_text unset")

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
