extends SceneTree
## Headless guard for the SETTINGS kit face — the new toggle_card + settings_dialog the game's
## engine/scripts/ui/settings.gd builds from (the SAME author-once-in-workbench / read-in-game pattern
## as the mailbox). Run:  godot --headless --path . -s res://engine/tests/settings_kit_tests.gd
## Proves: a toggle_card carries its label + the shared switch; pressing the switch flips the value and
## fires the entry's on_toggle; settings_dialog wraps the shared frame (banner) around one card per flag;
## and the config transforms read defaults + saved overrides — so the workbench's saved JSON drives it.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const Settings = preload("res://engine/scripts/ui/settings.gd")
const Identity = preload("res://engine/scripts/core/identity.gd")
const Save = preload("res://engine/scripts/core/save.gd")

var _pass := 0
var _fail := 0

# Redirect the save to a throwaway dir (mirrors debug_overlay_tests.fresh) so get_setting /
# grove / reset run against a clean fixture, never the real user save.
func fresh(name: String) -> void:
	var dir := "user://tu_settings_kit_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func _entry_of_kind(entries: Array, kind: String) -> Dictionary:
	for e in entries:
		if String((e as Dictionary).get("kind", "")) == kind:
			return e
	return {}

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

func _has_label_text(root: Node, text: String) -> bool:
	for l in root.find_children("", "Label", true, false):
		if (l as Label).text == text:
			return true
	return false

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

	# --- duplicate MOUSE presses from one physical tap still flip only ONCE --------
	# Desktop has BOTH emulate_touch_from_mouse and emulate_mouse_from_touch on, so one click can
	# arrive as the click's mouse press PLUS a second mouse press (its emulated touch re-converted
	# back to a mouse) in the SAME frame. The mouse-only guard above does NOT catch that (both are
	# mouse buttons) — only a per-frame guard does. Without it the switch flips twice (net no-op)
	# and the setting "won't save" (the reported "Sounds resets on restart" bug on the Mac build).
	var dbl: Array = [0]
	var dbl_card := Kit.toggle_card({
		"label": "Sounds", "value": true,
		"on_toggle": func(_on: bool) -> void: dbl[0] += 1,
	})
	var mb1 := InputEventMouseButton.new(); mb1.button_index = MOUSE_BUTTON_LEFT; mb1.pressed = true
	var mb2 := InputEventMouseButton.new(); mb2.button_index = MOUSE_BUTTON_LEFT; mb2.pressed = true
	dbl_card.gui_input.emit(mb1)   # the real click
	dbl_card.gui_input.emit(mb2)   # the re-emulated duplicate mouse press from the SAME tap
	ok(dbl[0] == 1, "two same-frame mouse presses (one physical tap) flip the switch exactly once")

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

	# --- info_card: a read-only label + value row, no switch -----------------------
	var info := Kit.info_card({"label": "Game Center", "value": "ABC123"})
	var info_has_label := false
	var info_has_value := false
	for l in info.find_children("", "Label", true, false):
		var t := (l as Label).text
		if t == "Game Center":
			info_has_label = true
		if t == "ABC123":
			info_has_value = true
	ok(info_has_label, "info_card shows its label")
	ok(info_has_value, "info_card shows its value text")
	ok(_find_switch(info) == null, "info_card carries no toggle switch (read-only)")

	# --- action_card: a button row that fires on_action ----------------------------
	var acted: Array = [0]
	var action := Kit.action_card({"label": "Reset save", "on_action": func() -> void: acted[0] += 1})
	var action_btn: Button = null
	for b in action.find_children("", "Button", true, false):
		if (b as Button).text == "Reset save" and not (b as Button).has_meta("on"):
			action_btn = b
	ok(action_btn != null, "action_card shows a button with its label")
	if action_btn != null:
		action_btn.pressed.emit()
	ok(acted[0] == 1, "pressing the action_card button fires on_action")

	# --- action_card with confirm_label: two-tap before firing ---------------------
	var confirmed: Array = [0]
	var two := Kit.action_card({
		"label": "Reset save", "confirm_label": "Tap again to wipe",
		"on_action": func() -> void: confirmed[0] += 1,
	})
	var two_btn: Button = null
	for b in two.find_children("", "Button", true, false):
		if not (b as Button).has_meta("on"):
			two_btn = b
	ok(two_btn != null and two_btn.text == "Reset save", "two-tap action starts with its base label")
	if two_btn != null:
		two_btn.pressed.emit()
	ok(confirmed[0] == 0, "first tap does NOT fire on_action (arms the confirm)")
	ok(two_btn != null and two_btn.text == "Tap again to wipe", "first tap morphs the label to the confirm prompt")
	if two_btn != null:
		two_btn.pressed.emit()
	ok(confirmed[0] == 1, "second tap fires on_action")

	# --- settings_dialog renders entries BY KIND (toggle default · info · action) --
	var mixed := Kit.settings_dialog([
		{"label": "Music", "value": false},                                  # no kind → toggle
		{"kind": "info", "label": "Game Center", "value": "not signed in"},
		{"kind": "action", "label": "Reset save", "on_action": func() -> void: pass},
	], 540.0, {"banner_text": "Settings"})
	var mixed_switches := 0
	for b in mixed.find_children("", "Button", true, false):
		if (b as Button).has_meta("on"):
			mixed_switches += 1
	ok(mixed_switches == 1, "settings_dialog renders the toggle entry as exactly one switch")
	var mixed_value := false
	for l in mixed.find_children("", "Label", true, false):
		if (l as Label).text == "not signed in":
			mixed_value = true
	ok(mixed_value, "settings_dialog renders the info entry's value")
	var mixed_action := false
	for b in mixed.find_children("", "Button", true, false):
		if (b as Button).text == "Reset save" and not (b as Button).has_meta("on"):
			mixed_action = true
	ok(mixed_action, "settings_dialog renders the action entry's button")

	# --- settings._entries ALWAYS appends the Game Center id + Reset save rows --------
	# These are player-facing (no debug gate): the settings list always grows a read-only Game Center
	# id row and a destructive Reset save action, in every build.
	fresh("gc_reset_rows")
	var host := Control.new()
	get_root().add_child(host)
	var entries_def: Array = Settings._entries(host)        # default build — no debug flag set
	var info_e := _entry_of_kind(entries_def, "info")
	var action_e := _entry_of_kind(entries_def, "action")
	ok(String(info_e.get("label", "")) == "Game Center", "settings show a Game Center info row")
	ok(String(info_e.get("value", "")) == "not signed in",
		"the GC row reads 'not signed in' when there is no id (off iOS)")
	ok(String(action_e.get("label", "")) == "Reset save", "settings show a Reset save action row")
	ok(bool(action_e.get("destructive", false)), "the Reset row is flagged destructive")
	host.queue_free()

	# --- the Reset action's on_action wipes progress to a fresh save ------------------
	fresh("reset_action")
	Save.add_exp(50)
	ok(Save.exp_total() == 50, "seed: the save carries progress before reset")
	var host2 := Control.new()                 # NOT added to the tree → _reflect skips the scene reload
	var reset_entry := _entry_of_kind(Settings._entries(host2), "action")
	ok(reset_entry.has("on_action"), "the Reset row carries an on_action")
	if reset_entry.has("on_action"):
		(reset_entry["on_action"] as Callable).call()
	ok(Save.exp_total() == 0, "the Reset action wipes progress to a fresh save")
	host2.free()

	# --- the settings dialog GROWS to fit all its rows (no bottom clip) ---------------
	# Regression: the debug rows make the settings content taller; the card must grow so the LAST row
	# sits inside it. The frame used to size the body to rows.size.y (a lagging current size), leaving a
	# taller dialog one row short and clipping Reset + the footer behind the scroll. Built + laid out the
	# real way (open's width + content_scale) and measured headless.
	fresh("dialog_fit")
	var fit_host := Control.new()
	get_root().add_child(fit_host)
	var fit_cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var fit_opts := Kit.settings_opts_from_config(fit_cfg)
	fit_opts["banner_text"] = "Settings"
	fit_opts["content_scale"] = Kit.dialog_content_scale(fit_cfg, "settings")
	fit_opts["footer_text"] = "Privacy Policy"
	var fit_w := 1080.0 * float(Kit.DIALOG_DESIGN_PCT["settings"]) / 100.0
	var fit_dlg := Kit.settings_dialog(Settings._entries(fit_host), fit_w, fit_opts)
	get_root().add_child(fit_dlg)
	for i in 24:
		await process_frame
	var fit_card: PanelContainer = null
	for c in fit_dlg.get_children():
		if c is PanelContainer:
			fit_card = c
	var fit_reset: Button = null
	for b in fit_dlg.find_children("", "Button", true, false):
		var bt := String((b as Button).text)
		if bt == "Reset save" or bt == "Tap again to wipe":
			fit_reset = b
	ok(fit_card != null and fit_reset != null, "the built settings dialog exposes a card + the Reset button")
	var card_bottom := (fit_card.global_position.y + fit_card.size.y) if fit_card != null else 0.0
	var reset_bottom := (fit_reset.global_position.y + fit_reset.size.y) if fit_reset != null else 1.0e9
	ok(fit_reset != null and reset_bottom <= card_bottom + 1.0,
		"the Reset row sits inside the dialog card (card grew to fit the rows, no clip)")
	fit_dlg.queue_free()
	fit_host.queue_free()

	# --- the live settings dialog refreshes the Game Center id after async auth ----
	# TestFlight auth completes asynchronously after the Settings dialog may already be open. The row must
	# update from the placeholder to the cached id without requiring the owner to close/reopen Settings.
	fresh("gc_live_refresh")
	var live_host := Control.new()
	live_host.size = Vector2(1080, 1920)
	get_root().add_child(live_host)
	Settings.open(live_host)
	for i in 6:
		await process_frame
	ok(_has_label_text(live_host, "not signed in"), "open Settings starts with the GC placeholder when no id is cached")
	var live_save := Save.grove()
	live_save["gc_player_id"] = "G:TESTFLIGHT123"
	Save.grove_write()
	for i in 20:
		await process_frame
	ok(_has_label_text(live_host, "G:TESTFLIGHT123"),
		"the open Settings dialog refreshes to the Game Center id when auth caches it")
	live_host.queue_free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
