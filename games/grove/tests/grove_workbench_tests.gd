extends SceneTree
## Headless tests for the UI workbench's SELECTIVE rebuild — editing an element rebuilds ONLY that
## element (now) plus its dependents (staggered, one per frame), never the whole 16-element gallery.
##   godot --headless -s res://games/grove/tests/grove_workbench_tests.gd

const View = preload("res://games/grove/tools/ui_workbench_view.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Design = preload("res://engine/scripts/core/design.gd")
const Pal = preload("res://games/grove/grove_palette.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const Login = preload("res://engine/scripts/core/login.gd")
const LoginMystery = preload("res://engine/scripts/ui/login_mystery.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const RushFx = preload("res://engine/scripts/ui/rush_fx.gd")
const LandFx = preload("res://engine/scripts/ui/land_fx.gd")
const MergeFx = preload("res://engine/scripts/ui/merge_fx.gd")
const LaunchFx = preload("res://engine/scripts/ui/launch_fx.gd")
const MoveFx = preload("res://engine/scripts/ui/move_fx.gd")

var _pass := 0
var _fail := 0
var _fx_settings_path := ""

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# Count the currency-number labels inside a pill (one per currency pair). The gold pill also has a
# "+" label, so count only numeric text.
func _pill_numbers(pill: Control) -> int:
	var n := 0
	for l in pill.find_children("*", "Label", true, false):
		if String((l as Label).text).is_valid_int():
			n += 1
	return n

# True if any Label in `node`'s subtree has exactly `text`.
func _has_label_text(node: Control, text: String) -> bool:
	for l in node.find_children("*", "Label", true, false):
		if String((l as Label).text) == text:
			return true
	return false

func _controls_with_label(node: Control, text: String) -> Array:
	var out := []
	for l in node.find_children("*", "Label", true, false):
		if String((l as Label).text) == text and l.get_parent() is Control:
			out.append(l.get_parent() as Control)
	return out

# Like _has_label_text but for text carried on a Button (e.g. the shared pill_button cost chip).
func _has_button_text(node: Control, text: String) -> bool:
	if node is Button and String((node as Button).text) == text:
		return true
	for b in node.find_children("*", "Button", true, false):
		if String((b as Button).text) == text:
			return true
	return false

func _source_contains(path: String, needle: String) -> bool:
	return FileAccess.get_file_as_string(path).find(needle) != -1

func _fresh_fx_settings(name: String) -> void:
	var dir := "user://tu_grove_workbench_fx_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	_fx_settings_path = dir + "ui_workbench_settings.json"
	FX.configure_reward_fx_config_for_test(_fx_settings_path)

func _saved_fx_config() -> Dictionary:
	if not FileAccess.file_exists(_fx_settings_path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_fx_settings_path))
	if parsed is Dictionary and parsed.has("fx") and parsed["fx"] is Dictionary:
		return parsed["fx"]
	return {}

# The first Button at or under `node` (the tappable surface), or null.
func _first_button(node: Control) -> Button:
	if node is Button:
		return node as Button
	var bs := node.find_children("*", "Button", true, false)
	return bs[0] if not bs.is_empty() else null

func _locked_placeholder(node: Control) -> TextureRect:
	return node.find_child("SlotCellLockedPlaceholder", true, false) as TextureRect

# The first Button at/under `node` whose text CONTAINS `frag` (case-insensitive), or null — to read its
# art (the normal stylebox) or assert its presence. (find_children can't match on text.)
func _find_button(node: Control, frag: String) -> Button:
	if node is Button and String((node as Button).text).findn(frag) != -1:
		return node as Button
	for b in node.find_children("*", "Button", true, false):
		if String((b as Button).text).findn(frag) != -1:
			return b as Button
	return null

func _find_button_with_label(node: Control, text: String) -> Button:
	if node is Button and ((node as Button).tooltip_text == text or _has_label_text(node, text)):
		return node as Button
	for b in node.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn.tooltip_text == text or _has_label_text(btn, text):
			return btn
	return null

func _painted_top(node: Control) -> float:
	if node == null:
		return INF
	var top := INF
	for tr in node.find_children("*", "TextureRect", true, false):
		var tex := (tr as TextureRect).texture
		var img := tex.get_image() if tex != null else null
		if img == null or tex.get_width() <= 0 or tex.get_height() <= 0:
			continue
		var used := img.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			continue
		var scale_y := (tr as TextureRect).get_global_rect().size.y / float(tex.get_height())
		top = minf(top, (tr as TextureRect).get_global_rect().position.y + float(used.position.y) * scale_y)
	return top

func _piece_holder_max_px(node: Control) -> float:
	var max_px := -1.0
	for art in node.find_children("ItemArt", "TextureRect", true, false):
		var parent := (art as Node).get_parent()
		if parent is Control:
			max_px = maxf(max_px, (parent as Control).size.x)
	return max_px

func _piece_art_max_px(node: Control) -> float:
	var max_px := -1.0
	for found in node.find_children("ItemArt", "TextureRect", true, false):
		var art := found as TextureRect
		var parent := art.get_parent()
		if parent is Control:
			var art_w := (parent as Control).size.x - art.offset_left + art.offset_right
			max_px = maxf(max_px, art_w)
	return max_px

# The texture on a Button's `normal` stylebox when it wears sprite art (a StyleBoxTexture), else null —
# lets a test prove two buttons share the SAME baked sprite (e.g. the level cta atom) without node names.
func _btn_tex(b: Button) -> Texture2D:
	if b == null:
		return null
	var sb := b.get_theme_stylebox("normal")
	return (sb as StyleBoxTexture).texture if sb is StyleBoxTexture else null

func _first_control(node: Control, pattern: String, klass: String = "Control") -> Control:
	var found := node.find_children(pattern, klass, true, false)
	return found[0] as Control if not found.is_empty() else null

func _ancestor_named(n: Node, node_name: String) -> Control:
	var p := n
	while p != null:
		if p is Control and String(p.name).begins_with(node_name):
			return p as Control
		p = p.get_parent()
	return null

func _slider_max(view: Control, label: String) -> float:
	for row in view._sidebar_body.find_children("*", "HBoxContainer", true, false):
		var kids := (row as HBoxContainer).get_children()
		if kids.size() >= 2 and kids[0] is Label and String((kids[0] as Label).text) == label:
			for kid in kids:
				if kid is HSlider:
					return (kid as HSlider).max_value
	return -INF

func _slider_min(view: Control, label: String) -> float:
	for row in view._sidebar_body.find_children("*", "HBoxContainer", true, false):
		var kids := (row as HBoxContainer).get_children()
		if kids.size() >= 2 and kids[0] is Label and String((kids[0] as Label).text) == label:
			for kid in kids:
				if kid is HSlider:
					return (kid as HSlider).min_value
	return INF

func _has_sidebar_label(view: Control, label: String) -> bool:
	for found in view._sidebar_body.find_children("*", "Label", true, false):
		if String((found as Label).text) == label:
			return true
	return false

func _sidebar_panel(view: Control) -> Control:
	var n: Node = view._sidebar_body
	while n != null:
		if n is PanelContainer:
			return n as Control
		n = n.get_parent()
	return null

func _sidebar_label_containing(view: Control, text: String) -> Label:
	for found in view._sidebar_body.find_children("*", "Label", true, false):
		var label := found as Label
		if String(label.text).find(text) != -1:
			return label
	return null

# Count the slot tiles in a bag dialog's grid (the GridContainer's children).
func _grid_cells(dialog: Control) -> int:
	var grids := dialog.find_children("*", "GridContainer", true, false)
	return (grids[0] as GridContainer).get_child_count() if not grids.is_empty() else -1

# The unlockable cell's highlight pop style. Returns null if the cell carries no such pop (not unlockable).
func _unlockable_highlight_style(node: Control) -> StyleBoxFlat:
	for p in node.find_children("SlotCellUnlockableHighlight", "Panel", true, false):
		var sb: StyleBox = (p as Panel).get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			return sb as StyleBoxFlat
	return null

# The unlockable cell's accent colour — shared by the glow/shadow highlight. Returns transparent if the
# cell carries no such pop (not unlockable).
func _unlockable_tint(node: Control) -> Color:
	var sb := _unlockable_highlight_style(node)
	return sb.border_color if sb != null else Color(0, 0, 0, 0)

# The unlockable highlight pop's rim drop-shadow size (px). -1 if the cell has no such pop.
func _unlockable_shadow_size(node: Control) -> int:
	var sb := _unlockable_highlight_style(node)
	return sb.shadow_size if sb != null else -1

# The unlockable highlight's visible border width. -1 if the cell has no such pop.
func _unlockable_border_width(node: Control) -> int:
	var sb := _unlockable_highlight_style(node)
	if sb == null:
		return -1
	return maxi(maxi(sb.border_width_left, sb.border_width_right), maxi(sb.border_width_top, sb.border_width_bottom))

func _same_rgb(a: Color, b: Color, eps := 0.01) -> bool:
	return absf(a.r - b.r) <= eps and absf(a.g - b.g) <= eps and absf(a.b - b.b) <= eps

# True if `node` or any descendant is of the given built-in class.
func _has_class(node: Node, klass: String) -> bool:
	if node.is_class(klass):
		return true
	for c in node.get_children():
		if _has_class(c, klass):
			return true
	return false

func _id_of(view: Control, key: String) -> int:
	var n = view._sections.get(key)
	return n.get_instance_id() if n != null else 0

func _gallery_neighbors(a: String, b: String) -> bool:
	for col in View.COLUMNS:
		var flat := []
		for row in col:
			for id in row:
				flat.append(String(id))
		var ia := flat.find(a)
		var ib := flat.find(b)
		if ia >= 0 and ib >= 0 and abs(ia - ib) == 1:
			return true
	return false

func _initialize() -> void:
	print("== Workbench selective-rebuild tests ==")
	_fresh_fx_settings("settings")
	var view: Control = View.new()
	root.add_child(view)
	await process_frame
	await process_frame   # _ready -> _build -> _rebuild_gallery populates _sections

	var sidebar := _sidebar_panel(view)
	ok(sidebar != null and is_equal_approx(sidebar.custom_minimum_size.x, 348.0) \
		and sidebar.size_flags_horizontal == Control.SIZE_SHRINK_BEGIN, \
		"workbench sidebar keeps a static 348px width")
	view._selected = "tiers"
	view._rebuild_sidebar()
	await process_frame
	var long_sidebar_note := _sidebar_label_containing(view, "The tiles ARE the SHARED slot cell")
	ok(long_sidebar_note != null \
		and long_sidebar_note.autowrap_mode != TextServer.AUTOWRAP_OFF \
		and long_sidebar_note.size_flags_horizontal == Control.SIZE_EXPAND_FILL \
		and is_equal_approx(long_sidebar_note.custom_minimum_size.x, 0.0), \
		"workbench sidebar descriptive text wraps inside the fixed width")
	view._selected = "rush_bar"
	view._rebuild_sidebar()
	await process_frame
	ok(sidebar != null and is_equal_approx(sidebar.size.x, 348.0), \
		"workbench sidebar actual layout width stays 348px when section text is long")

	ok(view._sections.size() >= 16, "gallery built: every element section registered (%d)" % view._sections.size())
	ok(not View.IDS.has("currency_pill"), "legacy currency_pill gallery id is removed")
	ok(not view._sections.has("currency_pill"), "legacy currency_pill gallery section is removed")
	ok(not view._params.has("currency_pill"), "legacy currency_pill settings block is removed from the workbench")
	ok(View.IDS.has("fx"), "Coin Flow is registered as the UI Workbench FX component")
	ok(view._sections.has("fx"), "Coin Flow gallery section is built")
	ok(view.find_child("FxWorkbenchRoot", true, false) == null, "Coin Flow does not embed the special FX mini-app in the gallery")
	ok(view.find_child("CoinFlowPreview", true, false) != null, "Coin Flow gallery section uses a native workbench component preview")
	ok(view.find_child("CoinFlowSource", true, false) != null, "Coin Flow preview shows the shared source")
	ok(view.find_child("CoinWalletTarget", true, false) != null, "Coin Flow preview shows the wallet target")
	# the FOCUS RING group — the selected-cell corner brackets, live-tunable here, flowing to the board.
	ok(View.IDS.has("focus_ring") and view._sections.has("focus_ring"), "the focus ring is a registered workbench element")
	view._selected = "focus_ring"
	view._rebuild_sidebar()
	await process_frame
	ok(view._sidebar_body.find_children("*", "ColorPickerButton", true, false).size() >= 2, \
		"the focus ring sidebar exposes colour pickers (bracket + halo)")
	view._params["focus_ring"]["color"] = "FF8800"
	view._apply_edit()
	var _fr_kit = load("res://games/grove/tools/ui_workbench_kit.gd")
	var fr_opts: Dictionary = _fr_kit.focus_ring_opts_from_config({"focus_ring": view._params["focus_ring"]})
	ok(fr_opts.color.is_equal_approx(Color("#FF8800")), "a workbench bracket-colour edit flows through the kit transform the board reads")
	ok(view._make_element("focus_ring") != null, "the focus ring preview element builds")

	view._selected = "fx"
	view._rebuild_sidebar()
	await process_frame
	ok(view._sidebar_body.find_child("WorkbenchFxList_coin_pickup", true, false) == null, "Coin Flow sidebar has no duplicated per-action list")
	ok(view._sidebar_body.find_child("WorkbenchFxSavedSettingsHeader", true, false) != null, "Coin Flow sidebar has a saved-settings section")
	ok(view._sidebar_body.find_child("WorkbenchFxTestSettingsHeader", true, false) != null, "Coin Flow sidebar has a test-settings section")
	ok(view._sidebar_body.find_child("WorkbenchFxActionToggle_coin_pickup", true, false) != null, "Coin Flow sidebar keeps per-action on/off toggles in settings")
	ok(view._sidebar_body.find_child("WorkbenchFxIconSizeSlider", true, false) != null, "Coin Flow sidebar shows saved feel sliders")
	ok(view._sidebar_body.find_child("WorkbenchFxAmountSlider", true, false) != null, "Coin Flow sidebar shows preview-only amount slider")
	ok(view._sidebar_body.find_child("WorkbenchFxReplayButton", true, false) != null, "Coin Flow sidebar shows replay in the test section")
	var fx_preview := view.find_child("FxWorkbenchComponent", true, false) as Control
	if fx_preview != null:
		fx_preview.get_parent().remove_child(fx_preview)
		fx_preview.queue_free()
		await process_frame
	view._fx_set_global_setting("amount", 91)
	view._fx_set_global_setting("coin_size", 133)
	view._fx_set_auto_replay(true)
	var fallback_fx_cfg := _saved_fx_config()
	ok(not fallback_fx_cfg.has("amount"), "Coin Flow amount remains test-only when the embedded preview is absent")
	ok(not fallback_fx_cfg.has("source_size"), "Coin Flow source size remains test-only when the embedded preview is absent")
	ok(not fallback_fx_cfg.has("auto_replay"), "Coin Flow auto replay remains test-only when the embedded preview is absent")
	var currency_ids := []
	for id in View.IDS:
		if String(id).find("currency_pill") != -1:
			currency_ids.append(String(id))
	ok(currency_ids.size() == 1 and String(currency_ids[0]) == "gold_currency_pill", \
		"gold_currency_pill is the sole currency pill component in the workbench")
	ok(not _source_contains("res://games/grove/tools/ui_workbench_kit.gd", "static func currency_pill("), \
		"legacy currency_pill builder is removed from the kit")
	ok(not _source_contains("res://games/grove/tools/ui_workbench_kit.gd", "static func currency_pill_style("), \
		"legacy currency_pill style API is removed from the kit")
	ok(not _source_contains("res://games/grove/tools/ui_workbench_kit.gd", "static func currency_pill_opts_from_config("), \
		"legacy currency_pill config resolver is removed from the kit")

	# Let the INITIAL async-polish settle before snapshotting: an element showing a raw placeholder
	# rebuilds itself once its off-thread polish lands (the _awaiting pump). If that lands mid-test it
	# would change an "unrelated" element's id for reasons unrelated to the edit under test, so drain it.
	for _i in 60:
		await process_frame
		if view._awaiting.is_empty() and view._dirty.is_empty():
			break

	# Baseline instance ids for an edited element, a dependent, and two unrelated elements.
	var before := {}
	for k in ["button", "card", "dialog", "icon", "gold_currency_pill"]:
		before[k] = _id_of(view, k)

	# Edit the BUTTON (selected by default). Its style flows into card + every dialog; icon + gold pill are unrelated.
	view._selected = "button"
	view._params["button"]["font"] = 30
	view._apply_edit()

	# Immediately: the edited element is rebuilt NOW; unrelated elements are untouched.
	ok(_id_of(view, "button") != before["button"], "edited element (button) rebuilt immediately")
	ok(_id_of(view, "icon") == before["icon"], "unrelated element (icon) NOT rebuilt")
	ok(_id_of(view, "gold_currency_pill") == before["gold_currency_pill"], "unrelated element (gold_currency_pill) NOT rebuilt")
	ok(view._dirty.has("card") and view._dirty.has("dialog"), "dependents queued dirty (not rebuilt synchronously)")

	# Pump frames: the staggered queue drains, rebuilding the dependents over several frames.
	for i in 12:
		await process_frame
	ok(view._dirty.is_empty(), "dirty queue drains over frames")
	ok(_id_of(view, "card") != before["card"], "dependent (card) rebuilt after pumping")
	ok(_id_of(view, "dialog") != before["dialog"], "dependent (dialog) rebuilt after pumping")
	ok(_id_of(view, "icon") == before["icon"], "unrelated (icon) STILL untouched after pumping")
	ok(_id_of(view, "gold_currency_pill") == before["gold_currency_pill"], "unrelated (gold_currency_pill) STILL untouched after pumping")

	_test_bag_components()
	_test_discovery_cell()
	_test_discovery_frame()
	_test_board_element(view)
	_test_quest_card_config(view)
	_test_new_knobs(view)
	_test_warm_shadow_port()
	_test_mystery_preview(view)
	_test_level_badge_component(view)
	_test_rush_bar_component(view)
	_test_rush_fx_knobs()
	_test_feel_fx()

	# the bag dialog + bag cell are registered gallery items, and the bag depends on the frame, the
	# bag cell, AND the currency pill — editing any of those rebuilds the bag (the §reuse wiring).
	ok(view._sections.has("bag") and view._sections.has("bag_card"), "the bag dialog + bag cell are registered gallery items")
	ok(view._sections.has("gold_badge"), "the CSS-port gold badge is a registered gallery item")
	ok(bool(view._params["gold_badge"]["shadow"]), "gold_badge defaults to the shared Shadow toggle on")
	var gb := Kit.gold_badge(270.0)
	ok(gb is Control and gb.custom_minimum_size == Vector2(270, 270), "gold_badge builds at the requested size")
	ok(gb.find_children("*", "TextureRect", true, false).size() == 1, "gold_badge exposes one generated texture rect")
	_test_gold_badge_has_no_baked_shadow()
	_test_gold_badge_shared_shadow_toggle(view)
	_test_gold_badge_inner_inset(view)
	_test_gold_badge_shine(view)
	_test_gold_badge_gradient(view)
	_test_gold_badge_background_matches_icon_badges(view)
	_test_gold_badge_corner(view)
	_test_gold_badge_inner_corner_tracks_outer(view)
	_test_gold_badge_consumers(view)
	ok(view._sections.has("gold_currency_pill"), "the gold currency pill is a registered gallery item")
	var gcp := Kit.gold_currency_pill({
		"icon": "water", "count": 2450, "plus_x": 0, "plus_y": 0,
		"plus_radius": 28, "plus_shine": 32, "plus_stroke": 2,
		"plus_font": 70, "plus_button": 100, "plus_round": 8, "plus_hue": 65,
		"inner_shadow": 30,
	})
	ok(gcp is Control and _has_label_text(gcp, "2450") and _has_label_text(gcp, "+"), \
		"gold_currency_pill renders the sample count and plus glyph")
	var gcp_frame: StyleBox = (gcp as PanelContainer).get_theme_stylebox("panel")
	ok(gcp_frame is StyleBoxTexture, "gold_currency_pill background uses the code-drawn gold badge texture")
	ok(not (gcp_frame is StyleBoxFlat) or (gcp_frame as StyleBoxFlat).shadow_size == 0, \
		"gold_currency_pill does not add its own flat-panel shadow")
	ok(gcp.find_children("GoldCurrencyBadge", "Control", true, false).is_empty(), \
		"gold_currency_pill icon has no extra square badge background")
	ok(gcp.find_children("GoldCurrencyIcon", "TextureRect", true, false).size() >= 1, \
		"gold_currency_pill reuses the existing currency icon asset")
	var view_size_before_wallet := view.size
	view.size = Vector2(View.PHONE_W * 1.5, View.PHONE_H)
	var wallet_prev: Control = view._make_element("gold_currency_pill")
	root.add_child(wallet_prev)
	await process_frame
	var wallet_amounts: Array = wallet_prev.find_children("GoldCurrencyAmount", "Label", true, false)
	ok(wallet_amounts.size() == 3, \
		"gold_currency_pill workbench preview shows the three live wallet pills")
	ok(_has_label_text(wallet_prev, "100") and _has_label_text(wallet_prev, "0") and _has_label_text(wallet_prev, "5") \
		and wallet_prev.find_children("GoldCurrencyPlusButton", "Panel", true, false).size() == 3, \
		"gold_currency_pill workbench preview uses home-wallet water/coin/gem samples")
	var wallet_layout := Kit.hud_layout_opts_from_config({"hud_layout": view._params["hud_layout"]})
	var wallet_edge := float(wallet_layout.get("edge_margin_px", 18.0))
	var expected_wallet_pill_w := maxf(1.0, roundf(View.PHONE_W * float(wallet_layout.get("currency_pill_w_frac", 0.25))) - wallet_edge)
	ok(wallet_prev.get_child_count() >= 3 and absf(((wallet_prev as Control).get_child(0) as Control).get_global_rect().size.x - expected_wallet_pill_w) <= 0.01, \
		"gold_currency_pill workbench preview sizes each pill to the game screen width, not the wide tool window")
	var gp_default: Dictionary = (view._params["gold_currency_pill"] as Dictionary).duplicate()
	view._params["gold_currency_pill"]["pad_left"] = 33
	view._params["gold_currency_pill"]["icon_size"] = 52
	view._params["gold_currency_pill"]["num_size"] = 42
	var tuned_wallet: Control = view._make_element("gold_currency_pill")
	var tuned_labels: Array = tuned_wallet.find_children("GoldCurrencyAmount", "Label", true, false)
	var tuned_icons: Array = tuned_wallet.find_children("GoldCurrencyIcon", "TextureRect", true, false)
	var tuned_gold_opts := Kit.gold_currency_pill_opts_from_config({"gold_currency_pill": view._params["gold_currency_pill"]})
	var expected_pad_left := float(tuned_gold_opts.pad_left)
	var expected_icon_size := float(tuned_gold_opts.icon_size)
	var expected_num_size := int(tuned_gold_opts.num_size)
	var all_shared: bool = tuned_labels.size() == 3 and tuned_icons.size() == 3
	for tl in tuned_labels:
		var n := tl as Node
		var pill_panel: PanelContainer = null
		while n != null:
			if n is PanelContainer:
				pill_panel = n as PanelContainer
				break
			n = n.get_parent()
		var sb := pill_panel.get_theme_stylebox("panel") as StyleBoxTexture if pill_panel != null else null
		all_shared = all_shared and sb != null and is_equal_approx(float(sb.content_margin_left), expected_pad_left)
	for tl in tuned_labels:
		all_shared = all_shared and int((tl as Label).get_theme_font_size("font_size")) == expected_num_size
	for ti in tuned_icons:
		all_shared = all_shared and (ti as Control).custom_minimum_size.distance_to(Vector2(expected_icon_size, expected_icon_size)) <= 0.01
	ok(all_shared, \
		"gold_currency_pill workbench controls apply padding, icon, and text changes to all three pills")
	wallet_prev.queue_free()
	await process_frame
	view.size = view_size_before_wallet
	view._params["gold_currency_pill"] = gp_default
	var tuned := Kit.gold_currency_pill({
		"icon": "water", "count": 2450, "pill_w": 310, "pill_h": 106,
		"pad_left": 31, "pad_x": 22, "pad_y": 14, "icon_box": 74,
		"icon_size": 44, "icon_x": 7, "icon_y": -5,
		"num_size": 36, "amount_x": 9, "amount_y": -3,
		"gap": 17, "plus_x": 12, "plus_y": -8,
		"plus_radius": 28, "plus_shine": 32, "plus_stroke": 2,
		"plus_font": 132, "plus_button": 120, "plus_round": 8, "plus_hue": 65,
		"inner_shadow": 0,
	})
	var tuned_frame := (tuned as PanelContainer).get_theme_stylebox("panel") as StyleBoxTexture
	ok(tuned_frame != null and int(tuned_frame.content_margin_left) == 31 and int(tuned_frame.content_margin_right) == 22 and int(tuned_frame.content_margin_top) == 14, \
		"gold_currency_pill saved padding controls the badge frame margins")
	var icon_slot := _first_control(tuned, "GoldCurrencyIconSlot")
	var icon := _first_control(tuned, "GoldCurrencyIcon", "TextureRect")
	ok(icon_slot != null and icon != null and icon_slot.custom_minimum_size == Vector2(74, 74) and icon.custom_minimum_size == Vector2(44, 44), \
		"gold_currency_pill icon box + icon size controls resize the icon component")
	ok(icon != null and icon.position.x == 22, \
		"gold_currency_pill icon x control offsets the icon component")
	var amount_slot := _first_control(tuned, "GoldCurrencyAmountSlot")
	var amount := _first_control(tuned, "GoldCurrencyAmount", "Label") as Label
	ok(amount_slot != null and amount != null and amount.position.x == 9 and int(amount.get_theme_font_size("font_size")) == 36, \
		"gold_currency_pill amount x + font controls adjust the amount component")
	var plus_slot := _first_control(tuned, "GoldCurrencyPlusSlot")
	var plus_btn := _first_control(tuned, "GoldCurrencyPlusButton", "Panel")
	ok(plus_slot != null and plus_btn != null and plus_btn.position.x == 12, \
		"gold_currency_pill plus x control offsets the plus component")
	var plus_label := _first_control(tuned, "GoldCurrencyPlusLabel", "Label") as Label
	ok(plus_label != null and int(plus_label.get_theme_font_size("font_size")) >= 44, \
		"gold_currency_pill plus font can be adjusted larger")
	var icon_center := icon.position.y + icon.custom_minimum_size.y * 0.5
	var amount_center := amount.position.y + amount.custom_minimum_size.y * 0.5
	var plus_center := plus_btn.position.y + plus_btn.custom_minimum_size.y * 0.5
	ok(is_equal_approx(icon_center, amount_center) and is_equal_approx(amount_center, plus_center), \
		"gold_currency_pill vertically centers icon, amount, and plus on one line")
	var no_inner := (Kit.gold_currency_pill({"pill_h": 100, "inner_shadow": 0}) as PanelContainer).get_theme_stylebox("panel") as StyleBoxTexture
	var strong_inner := (Kit.gold_currency_pill({"pill_h": 100, "inner_shadow": 100}) as PanelContainer).get_theme_stylebox("panel") as StyleBoxTexture
	var no_px := no_inner.texture.get_image().get_pixel(58, 14)
	var strong_px := strong_inner.texture.get_image().get_pixel(58, 14)
	ok((strong_px.r + strong_px.g + strong_px.b) < (no_px.r + no_px.g + no_px.b), \
		"gold_currency_pill inner_shadow darkens the badge inset groove")
	var gp: Dictionary = view._params["gold_currency_pill"]
	ok(not gp.has("icon_y") and not gp.has("amount_y") and not gp.has("plus_y"), \
		"gold_currency_pill has no individual vertical offset controls")
	ok(view._is_config("gold_currency_pill", "pad_left") and view._is_config("gold_currency_pill", "icon_x") and view._is_config("gold_currency_pill", "amount_x") and view._is_config("gold_currency_pill", "plus_button") and view._is_config("gold_currency_pill", "inner_shadow"), \
		"gold_currency_pill padding and component controls are saved on its own config block")
	ok(not view._is_config("gold_currency_pill", "count"), "gold_currency_pill sample count is preview-only")
	view._selected = "gold_currency_pill"
	view._rebuild_sidebar()
	ok(view._sidebar_body.get_child_count() > 0, "the gold_currency_pill sidebar builds its copied plus controls")
	ok(_slider_max(view, "Plus Font") >= 140.0, "gold_currency_pill sidebar allows a larger plus font")
	ok(_slider_max(view, "Inner Shadow") >= 100.0, "gold_currency_pill sidebar exposes the inner-shadow override")
	var negative_pad_gold: Dictionary = Kit.gold_currency_pill_opts_from_config({"gold_currency_pill": {"pad_y": -8}})
	ok(is_equal_approx(float(negative_pad_gold.pad_y), -8.0), \
		"gold_currency_pill config preserves negative pad_y")
	ok(_slider_min(view, "Pad Y") <= -8.0, "gold_currency_pill sidebar allows pad_y below zero")
	var zero_pad_pill := Kit.gold_currency_pill({"pill_h": 1, "pad_y": 0, "icon_box": 54, "num_size": 30, "plus_button": 100, "show_plus": true})
	var negative_pad_pill := Kit.gold_currency_pill({"pill_h": 1, "pad_y": -8, "icon_box": 54, "num_size": 30, "plus_button": 100, "show_plus": true})
	root.add_child(zero_pad_pill)
	root.add_child(negative_pad_pill)
	await process_frame
	ok(negative_pad_pill.get_combined_minimum_size().y < zero_pad_pill.get_combined_minimum_size().y, \
		"gold_currency_pill negative pad_y reduces laid-out height instead of expanding it")
	zero_pad_pill.queue_free()
	negative_pad_pill.queue_free()
	await process_frame
	var zero_floor_pill := Kit.gold_currency_pill({"pill_h": 64, "pad_y": 0, "icon_box": 54, "num_size": 30, "plus_button": 100, "show_plus": true})
	var negative_floor_pill := Kit.gold_currency_pill({"pill_h": 64, "pad_y": -8, "icon_box": 54, "num_size": 30, "plus_button": 100, "show_plus": true})
	root.add_child(zero_floor_pill)
	root.add_child(negative_floor_pill)
	await process_frame
	ok(negative_floor_pill.get_combined_minimum_size().y < zero_floor_pill.get_combined_minimum_size().y, \
		"gold_currency_pill negative pad_y also reduces an explicit pill_h floor")
	zero_floor_pill.queue_free()
	negative_floor_pill.queue_free()
	await process_frame
	var zero_config_pill := Kit.gold_currency_pill(Kit.gold_currency_pill_opts_from_config({"gold_currency_pill": {"overall_scale": 116, "pill_h": 64, "pad_y": 0, "icon_box": 27, "num_size": 32, "plus_button": 103}}))
	var negative_config_pill := Kit.gold_currency_pill(Kit.gold_currency_pill_opts_from_config({"gold_currency_pill": {"overall_scale": 116, "pill_h": 64, "pad_y": -8, "icon_box": 27, "num_size": 32, "plus_button": 103}}))
	root.add_child(zero_config_pill)
	root.add_child(negative_config_pill)
	await process_frame
	ok(negative_config_pill.get_combined_minimum_size().y < zero_config_pill.get_combined_minimum_size().y, \
		"gold_currency_pill negative pad_y reduces the scaled workbench-config height")
	zero_config_pill.queue_free()
	negative_config_pill.queue_free()
	await process_frame
	var scaled_gold: Dictionary = Kit.gold_currency_pill_opts_from_config({"gold_currency_pill": {"overall_scale": 180}})
	ok(is_equal_approx(float(scaled_gold.pill_w), 525.6) and is_equal_approx(float(scaled_gold.pill_h), 180.0), \
		"gold_currency_pill overall_scale grows the frame as one unit")
	ok(is_equal_approx(float(scaled_gold.icon_box), 97.2) and int(scaled_gold.num_size) == 54 and is_equal_approx(float(scaled_gold.plus_button), 180.0), \
		"gold_currency_pill overall_scale grows icon, font, and plus controls together")
	ok(view._is_config("gold_currency_pill", "overall_scale"), \
		"gold_currency_pill overall_scale is saved config")
	ok(_slider_max(view, "Overall Scale") >= 220.0, "gold_currency_pill sidebar exposes overall scaling")
	# The shipped wallet capsule (workbench-tuned to a COMPACT pill, owner call) must still render tall
	# enough to HOLD its content (icon / number / +) without squishing AND stay a usable touch target.
	# This asserts the LIVE built pill height (gold_currency_pill auto-grows to max(pill_h, content+2·pad_y)),
	# NOT a raw config knob — so it guards the real "is the wallet pill broken?" question at any tuned height.
	# (Replaces the old `pill_h >= 96` floor, which tracked the retired 100px default and never matched the
	# tuned config — it was red from the commit that added it; the compact pill is intentional.)
	var shipped_gold := Kit.gold_currency_pill_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	var live_pill: Control = Kit.gold_currency_pill(shipped_gold, {})
	var live_h: float = live_pill.custom_minimum_size.y
	var content_floor: float = maxf(float(shipped_gold.icon_box), float(shipped_gold.num_size) * 1.45)
	ok(live_h >= maxf(content_floor, 48.0), \
		"the shipped gold_currency_pill renders a wallet capsule that holds its content + stays a touch target (live %d px)" % int(live_h))
	live_pill.queue_free()
	var hud_host := Control.new()
	hud_host.size = Design.size()
	hud_host.custom_minimum_size = Design.size()
	get_root().add_child(hud_host)
	var hud := Hud.build(hud_host, {})
	await process_frame
	ok(hud.coins is Label, "live HUD exposes the coin amount label")
	ok(_ancestor_named(hud.coins, "GoldCurrencyPill") != null, "live HUD currency pills use the gold currency pill")
	ok(hud.coin_plus is Button, "live HUD gold currency pill exposes a real plus button")
	ok(hud.coin_plus is Button and not (hud.coin_plus as Button).flat, \
		"live HUD plus button draws the same green rounded background as the workbench plus")
	var live_gold_opts := Kit.gold_currency_pill_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	var live_amount_slot := _first_control(hud.coin_pill, "GoldCurrencyAmountSlot")
	var live_amount := _first_control(hud.coin_pill, "GoldCurrencyAmount", "Label") as Label
	var live_plus := _first_control(hud.coin_pill, "GoldCurrencyPlusButton", "Button")
	var live_plus_label := _first_control(hud.coin_pill, "GoldCurrencyPlusLabel", "Label") as Label
	ok(live_amount_slot != null and live_amount != null and live_plus != null and live_plus_label != null \
		and absf(live_amount_slot.custom_minimum_size.x - float(live_gold_opts.amount_w)) <= 0.01 \
		and absf(live_amount.position.x - float(live_gold_opts.amount_x)) <= 0.01 \
		and absf(live_plus.position.x - float(live_gold_opts.plus_x)) <= 0.01 \
		and absf(live_plus_label.offset_top - float(live_gold_opts.plus_label_y)) <= 0.01, \
		"live HUD applies the Workbench amount box and plus location settings")
	var wallet_rect := (hud.wallet as Control).get_global_rect()
	var wallet_right_gap := Design.size().x - wallet_rect.end.x
	var hud_layout := Kit.hud_layout_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	var edge_margin := float(hud_layout.get("edge_margin_px", 18.0))
	ok(absf(wallet_right_gap - edge_margin) <= 1.0, \
		"live HUD wallet right margin matches the shared rail margin (%.1f ~= %.1f)" % [wallet_right_gap, edge_margin])
	if (hud.wallet as Control).get_child_count() >= 3:
		for i in 2:
			var left_pill := ((hud.wallet as Control).get_child(i) as Control).get_global_rect()
			var right_pill := ((hud.wallet as Control).get_child(i + 1) as Control).get_global_rect()
			ok(absf(right_pill.position.x - left_pill.end.x - edge_margin) <= 1.0, \
				"live HUD currency pill %d has the shared right margin before the next pill" % [i + 1])
	var level_badge := (hud.level as Label).get_parent()
	while level_badge != null and level_badge.name != "LevelBadge":
		level_badge = level_badge.get_parent()
	ok(absf(_painted_top(level_badge) - edge_margin) <= 1.0, \
		"live HUD level badge painted top uses the shared margin (%.1f ~= %.1f)" % [_painted_top(level_badge), edge_margin])
	var later_weather := Control.new()
	later_weather.name = "WeatherLayer"
	hud_host.add_child(later_weather)
	var level_row := (hud.lv_panel as Control).get_parent() as Control
	ok((hud.wallet as Control).z_index > later_weather.z_index, \
		"live HUD wallet draws above later full-screen weather so the pills are not cut")
	ok(level_row != null and (hud.wallet as Control).z_index > level_row.z_index, \
		"live HUD wallet draws above the level row when their top bands overlap")
	hud_host.queue_free()
	await process_frame

	var board_scene = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(board_scene)
	if board_scene.get("board") == null:
		board_scene._ready()
	await process_frame
	ok(not _has_label_text(board_scene, "Settings"), "board screen hides the settings tile with the rest of the side rail")
	board_scene.queue_free()
	var map_scene = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map_scene)
	if map_scene.get("content") == null:
		map_scene._ready()
	await process_frame
	var map_screen_w: float = map_scene.get_viewport_rect().size.x
	var map_screen_h: float = map_scene.get_viewport_rect().size.y
	var settings_gap: float = map_screen_w - (map_scene._gear as Control).get_global_rect().end.x if map_scene._gear != null else INF
	ok(map_scene._gear != null and _has_label_text(map_scene._gear, "Settings") and map_scene._chrome_nodes.has(map_scene._gear) \
		and absf(settings_gap - edge_margin) <= 1.0, \
		"map Settings tile is built through the side rail chrome path")
	if map_scene._gear != null and map_scene._hud_panels.size() > 0:
		var map_wallet := map_scene._hud_panels[0] as Control
		var rail_gap: float = map_scene._gear.get_global_rect().position.y - (map_wallet.get_child(0) as Control).get_global_rect().end.y
		ok(absf(rail_gap - edge_margin) <= 1.0, \
			"map side rail starts one shared margin below the currency pills (%.1f ~= %.1f)" % [rail_gap, edge_margin])
	var map_button := _find_button_with_label(map_scene, "Map")
	if map_button != null:
		var map_button_rect := map_button.get_global_rect()
		ok(absf(map_button_rect.position.x - edge_margin) <= 1.0 \
			and absf(map_screen_h - map_button_rect.end.y - edge_margin) <= 1.0, \
			"map button uses the shared side/bottom margin")
		var play_button := map_scene.get("_play_btn") as Button
		var play_button_rect := play_button.get_global_rect() if play_button != null else Rect2()
		ok(play_button != null and absf(map_button_rect.end.y - play_button_rect.end.y) <= 1.0, \
			"map button bottom-aligns with the Play CTA")
		map_scene._open_select()
		await process_frame
		if map_scene._select_back != null:
			var back_rect := (map_scene._select_back as Control).get_global_rect()
			ok(absf(back_rect.position.x - edge_margin) <= 1.0 \
				and absf(map_screen_h - back_rect.end.y - edge_margin) <= 1.0, \
				"place-picker back button uses the shared side/bottom margin")
		if map_scene.select_hits.size() >= 2:
			var unlocked_select_card := map_scene.select_hits[0].node as Control
			var locked_select_card := map_scene.select_hits[1].node as Control
			ok(unlocked_select_card != null and locked_select_card != null \
				and unlocked_select_card.size.y > locked_select_card.size.y + 8.0, \
				"place-picker unlocked map cards are slightly taller than locked map cards")
			var left_scroll_clip := unlocked_select_card.get_parent() as Control
			var left_scroll_rect := left_scroll_clip.get_global_rect() if left_scroll_clip != null else Rect2()
			ok(left_scroll_clip != null \
				and absf(left_scroll_rect.position.y) <= 1.0 \
				and absf(left_scroll_rect.end.y - map_screen_h) <= 1.0, \
				"place-picker left map-card scroll viewport extends to the top and bottom screen edges")
		map_scene.queue_free()
	await process_frame

	# REGRESSION: the Slot-cell preview must DEFAULT to a non-zero cost. The cost pill only renders on a
	# locked/unlockable cell WITH a cost > 0, so a zero default leaves the cost_* sliders (font/icon/x/y/
	# scale) with no pill to act on — they look broken.
	ok(String(view._params["bag_card"]["preview"]) == "locked", \
		"the Slot-cell preview defaults to the plain locked background state")
	ok(int(view._params["bag_card"]["cost"]) > 0, "the Slot-cell preview defaults to a visible cost (the cost sliders have a pill to act on)")
	ok(_has_button_text(view._make_element("bag_card"), str(int(view._params["bag_card"]["cost"]))), \
		"the default Slot-cell preview actually renders the cost pill")
	var bag_card_preview := view._make_element("bag_card") as Control
	var bag_card_opts := Kit.bag_card_opts_from_config(view._params)
	ok(bag_card_preview.custom_minimum_size == Vector2(float(bag_card_opts.cell_w) * 2.0, float(bag_card_opts.cell_h) * 2.0), \
		"the Slot-cell workbench preview keeps the original 2x display size")
	var bag_card_section := view._sections["bag_card"] as Control
	var bag_card_body := bag_card_section.get_child(0) as VBoxContainer if bag_card_section != null and bag_card_section.get_child_count() > 0 else null
	var bag_card_holder := bag_card_body.get_child(1) as Control if bag_card_body != null and bag_card_body.get_child_count() > 1 else null
	ok(bag_card_holder != null and bag_card_holder.custom_minimum_size == bag_card_preview.custom_minimum_size, \
		"the Slot-cell gallery section reserves the full preview footprint")
	ok(not View.IDS.has("border_cell") and not view._sections.has("border_cell") and not view._params.has("border_cell"), \
		"the temporary Border cell component is removed; its knobs live on Slot cell")
	ok(not (view._params["bag_card"] as Dictionary).has("cell_art") and not (view._params["bag_card"] as Dictionary).has("cell_slice"), \
		"Slot cell no longer exposes stale art/slice settings")
	ok(view._is_config("bag_card", "frontier_hue") and view._is_config("bag_card", "deep_hue") \
		and view._is_config("bag_card", "rim_alpha") and view._is_config("bag_card", "corner"), \
		"Slot cell owns the locked-background colour and shape knobs")
	var border_opts := Kit.bag_card_opts_from_config({"bag_card": {
		"frontier_hue": 20, "frontier_sat": 60, "frontier_val": 80,
		"deep_hue": 44, "deep_sat": 12, "deep_val": 85,
		"rim_hue": 20, "rim_sat": 60, "rim_val": 80, "rim_alpha": 70,
		"corner": 22,
	}})
	var tuned_slot: Control = Kit.slot_cell({"state": "locked", "frontier": true}, border_opts)
	var tuned_bg := tuned_slot.find_child("SlotCellBackground", true, false) as Panel
	var tuned_sb := tuned_bg.get_theme_stylebox("panel") as StyleBoxFlat if tuned_bg != null else null
	ok(tuned_sb != null and tuned_sb.bg_color.h < Pal.NEAR_UNLOCK.h, \
		"Slot-cell frontier hue tuning changes the locked background colour")
	tuned_slot.free()
	ok(not _source_contains("res://engine/scripts/ui/piece_view.gd", "border_cell_opts_from_config") \
		and _source_contains("res://engine/scripts/ui/piece_view.gd", "\"frontier\": frontier"), \
		"live locked board cells use the Slot-cell background config")

	for src in ["gold_currency_pill", "bag_card", "frame"]:
		view._selected = src
		view._dirty.clear()
		view._apply_edit()
		ok(view._dirty.has("bag"), "editing %s queues the bag to rebuild" % src)

	_test_info_reuses_mail(view)
	_test_unlock_reward_reuses_mail_dialog()

	view.queue_free()
	await process_frame
	# Drain the workbench's async-polish WorkerThreadPool tasks before exit. The icon/badge gallery
	# kicks off polish_async tasks; if one is still running at quit(), the pool's destructor tears down
	# a live GDScript lambda and crashes (signal 11 at shutdown). Baking the dialog sprites made the
	# build fast enough to reach quit() before a task finished, exposing this — so wait them out, the
	# same way kit_polish_async_tests does.
	Kit.clear_async_cache()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)

# The shop's "i" detail sheet REUSES the mail dialog (parchment cards, NO Claim) + a level-style "Got it"
# footer (the shared cta_button atom), replacing the dropped standalone info_dialog. Asserts the new kit
# surface: the cta_button atom, the optional mail footer, the read-only amount chip, the re-pointed
# workbench preview, and that the old info_dialog / _info_row / _info_divider builders are GONE.
func _test_info_reuses_mail(view) -> void:
	# 1. cta_button — the SHARED green level-badge button atom (one source, reused everywhere).
	var cta := Kit.cta_button("Got it", {})
	ok(cta is Button and String((cta as Button).text) == "Got it", "cta_button builds a labelled Button")
	var cta_tex := _btn_tex(cta)
	ok(cta_tex != null, "cta_button wears the baked level-badge sprite (a StyleBoxTexture, not a flat pill)")
	# the level dialog's bottom button IS this same atom → SAME sprite texture (proves reuse, not a copy)
	var lv := Kit.level_dialog({"level": 1, "earned": 0, "next": 6, "into": 0, "span": 6, "remaining": 6, "mode": "info"}, 460.0, Kit.level_opts_from_config(view._params))
	var lv_got := _find_button(lv, "Got it")
	ok(lv_got != null and _btn_tex(lv_got) == cta_tex, "the level dialog's bottom button IS the cta_button atom (same sprite)")

	# 2. mail_dialog — an OPTIONAL Got-it footer: off by default (the inbox is unchanged), a centered
	#    cta_button below the cards when opts.got_it is set (the info sheet's close affordance).
	var mail_plain := Kit.mail_dialog(Kit.DEMO_MAIL, 480.0, {})
	ok(_find_button(mail_plain, "Got it") == null, "mail_dialog shows NO Got-it footer by default (the inbox is unchanged)")
	var mail_foot := Kit.mail_dialog(Kit.DEMO_MAIL, 480.0, {"got_it": "Got it"})
	var foot := _find_button(mail_foot, "Got it")
	ok(foot != null, "mail_dialog adds a Got-it footer button when opts.got_it is set")
	ok(_btn_tex(foot) == cta_tex, "the mail Got-it footer reuses the level cta_button sprite")

	# 3. mail_card — an info-style entry carries a read-only `chip` (icon + amount) and NO Claim button; a
	#    reward entry still shows its Claim (the existing inbox path is unchanged).
	var info_card := Kit.mail_card({"icon": "water", "title": "Water", "body": "tops up your can", "chip": {"icon": "water", "text": "60"}})
	ok(_has_button_text(info_card, "60"), "an info mail_card renders the amount on a read-only chip")
	ok(_find_button(info_card, "Claim") == null, "...and shows NO Claim button")
	var reward_card := Kit.mail_card({"icon": "gift", "title": "Gift", "body": "yay", "reward": {"gems": 50}, "on_claim": func() -> void: pass}, 20, 15, {"text": "Claim"})
	ok(_find_button(reward_card, "Claim") != null, "a reward mail_card still shows its Claim button (unchanged)")
	ok(_has_button_text(reward_card, "50"), "...and its reward chip amount")

	# 4. the workbench "info" preview is re-pointed at the mail dialog: line items as chips + a Got-it footer.
	var info_prev: Control = view._make_element("info")
	ok(_has_button_text(info_prev, "400") and _has_button_text(info_prev, "60"), "the info preview renders each line item's amount as a chip")
	ok(_find_button(info_prev, "Got it") != null, "the info preview shows the Got-it footer")
	ok(_find_button(info_prev, "Claim") == null, "the info preview has NO Claim button")

	# 5. the standalone info_dialog builder (and its info-row helpers) are DROPPED — the info sheet is the
	#    shared mail dialog now.
	var kit_src := "res://games/grove/tools/ui_workbench_kit.gd"
	ok(not _source_contains(kit_src, "static func info_dialog("), "the standalone info_dialog builder is removed from the kit")
	ok(not _source_contains(kit_src, "static func _info_row("), "the _info_row helper is removed from the kit")
	ok(not _source_contains(kit_src, "static func _info_divider("), "the _info_divider helper is removed from the kit")

# The restored-place reward popup should not be a one-off dialog surface. It uses the same shared
# mail-dialog face as the inbox/info sheets: card rows, shared frame/close chrome, and cta_button footer.
func _test_unlock_reward_reuses_mail_dialog() -> void:
	var map_src := "res://engine/scripts/scenes/map.gd"
	ok(_source_contains(map_src, "Kit.mail_dialog(entries"), \
		"the restored-place reward popup is built with the shared mail_dialog")
	ok(_source_contains(map_src, "opts[\"got_it\"] = Strings.t(\"map.unlock.collect\")"), \
		"the restored-place Collect button is the mail_dialog cta footer")
	ok(not _source_contains(map_src, "Kit.pill_button(Strings.t(\"map.unlock.collect\")"), \
		"the restored-place popup no longer hand-builds a Collect pill")
	ok(not _source_contains(map_src, "func _reward_row("), \
		"the restored-place popup no longer carries custom reward-row chrome")
	ok(_source_contains(map_src, "Overlay.mount(self, \"UnlockRewardOverlay\")"), \
		"the restored-place popup mounts on the shared modal layer (kept above map badges)")

# The bag-screen kit pieces: the single-acorn currency pill, the bag-cell card in each state, and the
# bag dialog (shared frame + reused pill + a grid of cells). Built directly from the kit (the same
# transform the game reads), asserting structure — pixels are a screenshot job, not here.
## The merge BOARD as a workbench element: a faithful preview (frame · shared cell well · pieces) with
## live scale/frame/gap knobs plus preview-only `cell`/`cols`/`rows`. Piece size comes from Slot-cell
## content_frac, the same source the live board uses.
# The new workbench knobs (this branch): home-button caption padding + side-rail badge offset, and the
# currency pill's "+" size. Each must be SAVED config the kit resolver reads, default to the shipped look,
# and (for the badge) render a sample badge on the home-button preview so the offset is tunable live.
func _test_new_knobs(view) -> void:
	# home button: caption padding + badge offset are read by the shared resolver…
	var hb: Dictionary = Kit.home_button_opts_from_config({"home_button":
		{"caption_pad_x": 12, "caption_pad_y": 4, "badge_dx": -15, "badge_dy": -12}})
	ok(is_equal_approx(float(hb.caption_pad_x), 12.0) and is_equal_approx(float(hb.caption_pad_y), 4.0), \
		"home_button reads caption_pad_x / caption_pad_y")
	ok(is_equal_approx(float(hb.badge_dx), -15.0) and is_equal_approx(float(hb.badge_dy), -12.0), \
		"home_button reads badge_dx / badge_dy")
	# …and an absent config reproduces the shipped ribbon padding (Tune.TITLE_PAD_X) so nothing shifts.
	ok(is_equal_approx(float(Kit.home_button_opts_from_config({}).caption_pad_x), 30.0), \
		"default caption_pad_x reproduces the shipped ribbon (30)")
	# they are SAVED design config; the sample badge count is preview-only.
	ok(view._is_config("home_button", "caption_pad_x") and view._is_config("home_button", "caption_pad_y"), \
		"caption padding is saved config")
	ok(view._is_config("home_button", "badge_dx") and view._is_config("home_button", "badge_dy"), \
		"badge offset is saved config")
	ok(not view._is_config("home_button", "badge_count"), "the sample badge count is preview-only (not saved)")
	# the home-button preview carries a SAMPLE count badge so the offset is tunable live (default count 3).
	ok(_has_label_text(view._make_element("home_button"), "3"), \
		"the home-button preview shows a sample count badge")
	# the in-disc COUNT overlay (the Bag's "x/y"): its offset + font are read by the shared resolver, default
	# to the shipped placement, and are SAVED config; the sample "x/y" string is preview-only and renders on
	# the nav disc so the offset is tunable live.
	var hbn: Dictionary = Kit.home_button_opts_from_config({"home_button": {"count_dx": 5, "count_dy": 20, "count_font": 30}})
	ok(is_equal_approx(float(hbn.count_dx), 5.0) and is_equal_approx(float(hbn.count_dy), 20.0) and int(hbn.count_font) == 30, \
		"home_button reads count_dx / count_dy / count_font")
	ok(is_equal_approx(float(Kit.home_button_opts_from_config({}).count_dy), 38.0), \
		"default count_dy reproduces the shipped in-disc placement (38)")
	ok(view._is_config("home_button", "count_dx") and view._is_config("home_button", "count_dy") and view._is_config("home_button", "count_font"), \
		"the bag-count offset + font are saved config")
	ok(not view._is_config("home_button", "count"), "the sample bag-count string is preview-only (not saved)")
	ok(_has_label_text(view._make_element("home_button"), "1/6"), \
		"the home-button preview shows the sample bag count inside the disc")
	view._selected = "home_button"
	view._rebuild_sidebar()
	ok(_slider_max(view, "Px") >= 260.0, "the home_button sidebar allows larger shared button sizes")

	# HUD layout: the board is responsive now (fills width / auto-rotates 9×7) and the quest+board stack is
	# bottom-anchored, so the old manual board+quest POSITION and board-HEIGHT knobs are retired. Only the
	# band heights the live layout still reads remain tunable.
	var hud_default: Dictionary = (view._params["hud_layout"] as Dictionary).duplicate()
	var live_knobs := ["quest_bar_h_pct", "bottom_row_h_pct", "button_w_pct", "info_bar_w_pct", "level_w_pct"]
	var has_live := true
	for k in live_knobs:
		has_live = has_live and (view._params["hud_layout"] as Dictionary).has(k) and view._is_config("hud_layout", k)
	ok(has_live, "hud_layout keeps the live band-height controls (quest/bottom/button/info/level)")
	var dead_knobs := ["quest_bar_x_pct", "quest_bar_y_pct", "board_x_pct", "board_y_pct", "board_h_pct"]
	var dead_gone := true
	for k in dead_knobs:
		dead_gone = dead_gone and not (view._params["hud_layout"] as Dictionary).has(k)
	ok(dead_gone, "retired board/quest position + board-height knobs are gone from hud_layout defaults")

	# resolver: the quest band height still resolves to a fraction; the retired geometry fracs are dropped.
	var stack_layout := Kit.hud_layout_opts_from_config({"hud_layout": {"quest_bar_h_pct": 11}})
	ok(stack_layout.has("quest_bar_h_frac") and is_equal_approx(float(stack_layout.quest_bar_h_frac), 0.11) \
		and not stack_layout.has("board_h_frac") and not stack_layout.has("quest_bar_y_frac") \
		and not stack_layout.has("board_x_frac"), \
		"hud_layout resolver exposes the quest band height fraction and drops the retired geometry fracs")

	# preview: board + quest are BOTTOM-ANCHORED — quest above board, board above the bottom row, the board
	# fills (most of) the width, and the quest still clears the currency pills (board is height-capped).
	var preview_w := 1080.0 * 0.26
	var preview_h := 1920.0 * 0.26
	var default_hud_preview: Control = view._make_element("hud_layout")
	var default_quest_box := default_hud_preview.find_child("HudLayoutQuestBar", true, false) as Control
	var default_board_box := default_hud_preview.find_child("HudLayoutBoard", true, false) as Control
	var default_bottom_box := default_hud_preview.find_child("HudLayoutBottomRow", true, false) as Control
	ok(default_quest_box != null and default_board_box != null and default_bottom_box != null \
		and _has_label_text(default_quest_box, "quest") and _has_label_text(default_board_box, "board"), \
		"hud_layout preview draws the quest bar, board, and bottom row")
	ok(default_quest_box.position.y + default_quest_box.custom_minimum_size.y <= default_board_box.position.y + 1.0, \
		"hud_layout preview quest bar sits above the board (bottom-anchored stack)")
	var default_layout := Kit.hud_layout_opts_from_config({"hud_layout": view._params["hud_layout"]})
	var default_bottom_bar_h := preview_h * float(default_layout.get("bottom_row_h_frac", 0.0))
	var default_edge := float(default_layout.get("edge_margin_px", 18.0)) * 0.26
	var btn_w := preview_w * float(view._params["hud_layout"].get("button_w_pct", 15)) / 100.0
	var bottom_y := preview_h - maxf(btn_w, default_bottom_bar_h) - default_edge
	ok(default_board_box.position.y + default_board_box.custom_minimum_size.y <= bottom_y + 2.0, \
		"hud_layout preview board sits above the bottom row")
	ok(absf(default_bottom_box.custom_minimum_size.y - maxf(btn_w, default_bottom_bar_h)) <= 1.0, \
		"hud_layout preview bottom row uses the saved percent-of-screen height")
	ok(default_board_box.custom_minimum_size.x >= preview_w * 0.85, \
		"hud_layout preview board fills most of the width")
	var currency_boxes := _controls_with_label(default_hud_preview, "%d%%" % int(view._params["hud_layout"].get("currency_pill_w_pct", 25)))
	ok(currency_boxes.size() >= 3 \
		and default_quest_box.position.y >= (currency_boxes[0] as Control).position.y + (currency_boxes[0] as Control).custom_minimum_size.y - 0.5, \
		"hud_layout preview quest bar clears the currency pills")

	# sidebar: the live height sliders remain; the retired position + board-height sliders are gone.
	view._selected = "hud_layout"
	view._rebuild_sidebar()
	ok(_slider_max(view, "Quest Bar H Pct") >= 25.0 and _slider_max(view, "Bottom Row H Pct") >= 22.0, \
		"hud_layout sidebar keeps the quest + bottom-row height sliders")
	ok(_slider_max(view, "Board H Pct") < 0.0 and _slider_max(view, "Board Y Pct") < 0.0 \
		and _slider_max(view, "Quest Bar Y Pct") < 0.0 and _slider_max(view, "Board X Pct") < 0.0, \
		"hud_layout sidebar drops the retired board/quest position + board-height sliders")
	view._params["hud_layout"] = hud_default

	# the board bottom ACTION BAR is merged into the Info bar Workbench target: one component owns the full
	# shared tray (Home · Info · Bag), so the workbench cannot accidentally reintroduce inner frames.
	ok(not View.IDS.has("action_bar") and not view._params.has("action_bar"), \
		"the standalone action_bar component is merged into info_bar")
	var ab: Dictionary = Kit.action_bar_opts_from_config({"info_bar": {
		"icon_scale_pct": 65, "pad_x_pct": 6, "pad_y_pct": 4,
		"bag_x_pct": -7, "info_x_pct": 5, "home_x_pct": 8}})
	ok(is_equal_approx(float(ab.icon_scale), 0.65) \
		and is_equal_approx(float(ab.pad_x_frac), 0.06) \
		and is_equal_approx(float(ab.pad_y_frac), 0.04) \
		and is_equal_approx(float(ab.info_x_frac), 0.05) \
		and not ab.has("bag_x_frac") \
		and not ab.has("home_x_frac"), \
		"info_bar resolver reads the shared Bag/Home size knob and ignores Bag/Home x")
	var action_keys := ["icon_scale_pct", "pad_x_pct", "pad_y_pct", "info_x_pct"]
	var action_has_knobs := true
	for k in action_keys:
		action_has_knobs = action_has_knobs and (view._params["info_bar"] as Dictionary).has(k) and view._is_config("info_bar", k)
	ok(action_has_knobs \
		and not (view._params["info_bar"] as Dictionary).has("bag_x_pct") \
		and not (view._params["info_bar"] as Dictionary).has("home_x_pct"), \
		"merged info_bar action knobs keep one shared Bag/Home size control and no Bag/Home x controls")
	var action_prev: Control = view._make_element("info_bar")
	var preview_bag := action_prev.find_child("ActionBarPreviewBag", true, false) as Button
	var preview_home := action_prev.find_child("ActionBarPreviewHome", true, false) as Button
	var preview_info := action_prev.find_child("ActionBarPreviewInfoBar", true, false) as PanelContainer
	ok(action_prev is PanelContainer \
		and action_prev.find_child("ActionBarPreviewSeparatorHomeInfo", true, false) != null \
		and action_prev.find_child("ActionBarPreviewSeparatorInfoBag", true, false) != null, \
		"merged info_bar preview renders the shared tray with Home/Info/Bag separators")
	ok(preview_home != null and preview_bag != null and preview_info != null \
		and preview_home.get_index() < preview_info.get_index() \
		and preview_info.get_index() < preview_bag.get_index() \
		and action_prev.find_child("ActionBarPreviewBagOffset", true, false) == null \
		and action_prev.find_child("ActionBarPreviewHomeOffset", true, false) == null, \
		"merged info_bar preview fixes Home left and Bag right with no Bag/Home x offsets")
	ok(preview_bag != null and preview_bag.get_theme_stylebox("normal") is StyleBoxEmpty \
		and preview_home != null and preview_home.get_theme_stylebox("normal") is StyleBoxEmpty \
		and preview_info != null and preview_info.get_theme_stylebox("panel") is StyleBoxEmpty, \
		"merged info_bar preview has one shared outer border and no inner Bag/Info/Home frames")
	view._selected = "info_bar"
	view._rebuild_sidebar()
	ok(_slider_max(view, "Icon Scale Pct") >= 95.0 and _slider_max(view, "Pad X Pct") >= 16.0 \
		and _slider_min(view, "Info X Pct") <= -30.0 \
		and _slider_max(view, "Bag X Pct") == -INF and _slider_max(view, "Home X Pct") == -INF \
		and _slider_max(view, "Item Icon Scale") >= 160.0 \
		and _slider_min(view, "Info Y") <= -120.0 \
		and _slider_max(view, "Info Button Scale") >= 160.0, \
		"merged info_bar sidebar exposes shared Bag/Home size but no Bag/Home x sliders")

	# the bottom-bar INFO BAR element: its layout knobs are read by the resolver, default to the shipped bar,
	# and are SAVED config; `filled` is preview-only. Its frame uses the shared gold badge skin and retains
	# the shared gold-pill padding as its content margin.
	var ib: Dictionary = Kit.info_bar_opts_from_config({"info_bar": {"height": 150, "inner_scale": 60, "name_font": 28, "sep": 6, "sell_font": 24, "sell_icon": 40, "item_icon_scale": 115, "info_y": 11, "info_button_scale": 80, "hide_info_button": true}})
	ok(is_equal_approx(float(ib.height), 150.0) and is_equal_approx(float(ib.inner_scale), 0.60), \
		"info_bar reads height + inner_scale (0..1)")
	ok(int(ib.name_font) == 28 and int(ib.sep) == 6 and int(ib.sell_font) == 24 and is_equal_approx(float(ib.sell_icon), 0.40), \
		"info_bar reads name_font / sep / sell_font / sell_icon")
	ok(ib.has("item_icon_scale") and is_equal_approx(float(ib.get("item_icon_scale", -1.0)), 1.15), \
		"info_bar reads item_icon_scale as a selected item/generator artwork scale")
	ok(ib.has("info_y") and is_equal_approx(float(ib.get("info_y", 99.0)), 11.0) \
		and ib.has("info_button_scale") and is_equal_approx(float(ib.get("info_button_scale", -1.0)), 0.80), \
		"info_bar reads the info button y offset and size scale")
	ok(ib.has("hide_info_button") and bool(ib.get("hide_info_button", false)), \
		"info_bar reads the saved hide-info-button toggle")
	ok(ib.has("pill") and ib.has("badge"), "info_bar reads gold-pill padding plus the shared gold_badge frame opts")
	ok(is_equal_approx(float(Kit.info_bar_opts_from_config({}).height), 130.0), \
		"default info_bar height matches the bottom-bar wells (130)")
	var default_ib: Dictionary = Kit.info_bar_opts_from_config({})
	ok(default_ib.has("item_icon_scale") and is_equal_approx(float(default_ib.get("item_icon_scale", -1.0)), 0.80), \
		"default info_bar item_icon_scale is 80 percent of bar height")
	ok(default_ib.has("info_y") and is_equal_approx(float(default_ib.get("info_y", 99.0)), 0.0) \
		and default_ib.has("info_button_scale") and is_equal_approx(float(default_ib.get("info_button_scale", -1.0)), 1.0), \
		"default info_bar keeps the info button centered and full-size")
	ok(default_ib.has("hide_info_button") and not bool(default_ib.get("hide_info_button", true)), \
		"default info_bar shows the info button")
	ok(view._is_config("info_bar", "height") and view._is_config("info_bar", "name_font") and view._is_config("info_bar", "sell_icon") and view._is_config("info_bar", "item_icon_scale") and view._is_config("info_bar", "info_y") and view._is_config("info_bar", "info_button_scale") and view._is_config("info_bar", "hide_info_button"), \
		"the info-bar layout knobs are saved config")
	ok(not view._is_config("info_bar", "filled"), "the filled-vs-empty preview toggle is not saved")
	var scaled_bar: PanelContainer = Kit.info_bar({}, ib)
	var scaled_meta := float(scaled_bar.get_meta("item_icon_scale")) if scaled_bar.has_meta("item_icon_scale") else -1.0
	ok(scaled_bar.has_meta("item_icon_scale") and is_equal_approx(scaled_meta, 1.15), \
		"info_bar exposes item_icon_scale for live board and preview renderers")
	ok(scaled_bar.has_meta("item_icon_px") and is_equal_approx(float(scaled_bar.get_meta("item_icon_px")), 172.5), \
		"info_bar exposes selected item art size as a percent of bar height")
	var scaled_info_btn := scaled_bar.get_meta("info_btn") as Button
	var scaled_info_slot := scaled_info_btn.get_parent() as Control
	var scaled_item_slot := scaled_bar.get_meta("info_icon") as Control
	var scaled_text_stack := (scaled_bar.get_meta("name_label") as Label).get_parent() as Control
	var scaled_item_text_row := scaled_item_slot.get_parent() as HBoxContainer
	var scaled_hb := scaled_item_text_row.get_parent() as HBoxContainer
	ok(scaled_hb != null and scaled_hb.get_child(0) == scaled_item_text_row, \
		"the selected item art and text start at the left edge of the info bar layout")
	ok(scaled_info_slot != null \
		and scaled_info_slot.get_parent() != scaled_hb \
		and scaled_info_slot.get_parent() != null \
		and scaled_info_slot.get_parent().get_parent() == scaled_bar, \
		"the info button floats in an overlay instead of consuming layout width")
	ok(scaled_item_text_row != null and scaled_item_text_row.get_child(0) == scaled_item_slot, \
		"the selected item icon starts the item/text group")
	ok(scaled_item_text_row != null \
		and scaled_item_text_row.get_child(1) == scaled_text_stack \
		and scaled_item_text_row.get_theme_constant("separation") == 0, \
		"the selected item text starts immediately after the item icon")
	ok(is_equal_approx(scaled_item_slot.custom_minimum_size.x, 172.5) \
		and is_equal_approx(scaled_item_slot.custom_minimum_size.y, 150.0), \
		"the selected item slot is sized from bar height, not the info button slot")
	ok(scaled_bar.has_meta("info_button_scale") and is_equal_approx(float(scaled_bar.get_meta("info_button_scale")), 0.80), \
		"info_bar exposes info button scale for preview renderers")
	ok(is_equal_approx(scaled_info_btn.custom_minimum_size.x, 72.0) \
		and is_equal_approx(scaled_info_btn.position.y, 20.0), \
		"the info button can be resized and moved vertically inside its fixed slot")
	ok(not scaled_info_btn.visible, \
		"the info button is hidden when the saved hide toggle is on")
	ok(is_equal_approx(scaled_info_slot.custom_minimum_size.x, 90.0), \
		"resizing the info button does not resize the row slot")
	ok(_has_label_text(view._make_element("info_bar"), "Hazelnut · Tier 2"), \
		"the info-bar preview shows a sample selected item")

	# gold currency pill: the plus glyph and surrounding green button are read from the new config block.
	ok(int(Kit.gold_currency_pill_opts_from_config({"gold_currency_pill": {"plus_font": 132}}).plus_font) == 132, \
		"gold_currency_pill reads plus_font")
	ok(view._is_config("gold_currency_pill", "plus_font") and view._is_config("gold_currency_pill", "plus_button"), \
		"gold_currency_pill plus controls are saved config")
	var pill132: Control = Kit.gold_currency_pill({"icon": "water", "count": 1, "show_plus": true, "plus_font": 132, "plus_button": 120}, {"water": 1})
	var pill_default_plus: Control = Kit.gold_currency_pill({"icon": "water", "count": 1, "show_plus": true, "plus_button": 100}, {"water": 1})
	var plus_label := _first_control(pill132, "GoldCurrencyPlusLabel", "Label") as Label
	var plus_panel := _first_control(pill132, "GoldCurrencyPlusButton", "Panel") as Panel
	var default_panel := _first_control(pill_default_plus, "GoldCurrencyPlusButton", "Panel") as Panel
	var default_label := _first_control(pill_default_plus, "GoldCurrencyPlusLabel", "Label") as Label
	ok(plus_label != null and default_label != null and plus_label.get_theme_font_size("font_size") > default_label.get_theme_font_size("font_size"), \
		"the gold currency pill plus font can be adjusted larger")
	ok(plus_panel != null and default_panel != null and plus_panel.custom_minimum_size.x > default_panel.custom_minimum_size.x, \
		"the gold currency pill plus button size is controlled by plus_button")
	var compact_pill := Kit.gold_currency_pill({"pill_h": 72, "pad_y": 12, "icon_box": 54, "num_size": 30, "plus_button": 100, "show_plus": true})
	ok(compact_pill.custom_minimum_size.y >= 78.0, \
		"gold_currency_pill clamps height to fit content and vertical padding")
	ok(not _source_contains("res://engine/scripts/scenes/map.gd", "opts[\"px\"] = 140.0"), \
		"map bottom-nav buttons use the workbench home_button px instead of hard-coded 140")
	ok(not _source_contains("res://engine/scripts/scenes/board.gd", "_build_bag_box(BOTTOM_BTN_PX)") \
		and not _source_contains("res://engine/scripts/scenes/board.gd", "_home_nav_button(BOTTOM_BTN_PX)"), \
		"board Bag/Home wells use the workbench home_button px instead of the old board constant")

	# bundle B (impact propagation): the board merge now routes through the workbench-tuned MergeFx applier,
	# which does the neighbour ripple + big-merge board punch INTERNALLY — the merge cell's neighbours + the
	# board are passed in, with NO separate scene-side ripple/board_punch calls (double-firing would be a bug).
	var board_src := FileAccess.get_file_as_string("res://engine/scripts/scenes/board.gd")
	ok(board_src.find("MergeFx.apply(board_area, n, center, tier, combo, _orthogonal_neighbour_nodes(b), board_area, _merge_opts, 1.0, 0)") != -1, \
		"board merge routes through MergeFx.apply (neighbours + board passed in)")
	ok(board_src.find("_merge_opts = MergeFx.from_config(") != -1, \
		"board resolves the merge_fx config once")
	ok(board_src.find("Feel.ripple(_orthogonal_neighbour_nodes(b),") == -1, \
		"board no longer ripples the merge scene-side (MergeFx.apply owns it)")
	ok(board_src.find("Feel.board_punch(board_area,") == -1, \
		"board no longer punches the board scene-side (MergeFx.apply owns it)")
	ok(board_src.find("func _orthogonal_neighbour_nodes") != -1, \
		"board gathers neighbour nodes scene-side (the grid stays in the scene, not the applier)")
	# discrete coin / special touchdowns still ripple their neighbours scene-side (LandFx has no ripple).
	ok(board_src.find("Feel.ripple(_orthogonal_neighbour_nodes(cell), coin_ctr, 0.8)") != -1, \
		"a coin touchdown ripples its neighbours")
	ok(board_src.find("Feel.ripple(_orthogonal_neighbour_nodes(cell), special_ctr, 0.8)") != -1, \
		"a special-drop touchdown ripples its neighbours")

	# the SIDEBAR slider panel for each edited element builds without error and emits the new sliders
	# (label rows). A typo in a _slider_row key here would otherwise only surface when a human opens the tool.
	for sel in ["home_button", "gold_currency_pill", "info_bar"]:
		view._selected = sel
		view._rebuild_sidebar()
		ok(view._sidebar_body.get_child_count() > 0, "the %s sidebar builds its slider panel" % sel)

func _test_board_element(view) -> void:
	ok(view._sections.has("board"), "the board is a registered gallery item")
	ok(view._is_config("board", "scale") and view._is_config("board", "gap") and view._is_config("board", "frame"), \
		"the live board saves scale, gap, and frame settings")
	ok(not view._is_config("board", "cell") and not view._is_config("board", "cols") and not view._is_config("board", "rows"), \
		"board cell size and grid dimensions are preview-only")
	ok(not (view._params["board"] as Dictionary).has("item"), \
		"the board no longer owns a second item-size knob")
	ok(not view._is_config("board", "pieces"), "the demo-pieces toggle is preview-only (not saved)")

	var board_default: Dictionary = (view._params["board"] as Dictionary).duplicate()
	view._selected = "board"
	view._params["board"]["scale"] = 100
	view._params["board"]["cell"] = 50
	var base: Control = view._make_element("board")
	var w0: float = base.custom_minimum_size.x
	ok(w0 > 0.0, "the board preview reports a real footprint")

	var bag_default: Dictionary = (view._params["bag_card"] as Dictionary).duplicate()
	view._params["bag_card"]["frontier_hue"] = 20
	view._params["bag_card"]["frontier_sat"] = 60
	view._params["bag_card"]["frontier_val"] = 80
	view._params["bag_card"]["deep_hue"] = 44
	view._params["bag_card"]["deep_sat"] = 12
	view._params["bag_card"]["deep_val"] = 85
	var board_with_locks: Control = view._make_element("board")
	var board_slot_opts := Kit.bag_card_opts_from_config(view._params)
	var saw_frontier_lock := false
	var saw_deep_lock := false
	var board_backgrounds := board_with_locks.find_children("SlotCellBackground", "Panel", true, false)
	for bg in board_backgrounds:
		var sb: StyleBox = (bg as Panel).get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			var fill := (sb as StyleBoxFlat).bg_color
			saw_frontier_lock = saw_frontier_lock or _same_rgb(fill, board_slot_opts.frontier_fill)
			saw_deep_lock = saw_deep_lock or _same_rgb(fill, board_slot_opts.deep_fill)
	ok(saw_frontier_lock and saw_deep_lock, \
		"the board preview shows frontier and deep locked cells using Slot-cell background settings")
	ok(board_backgrounds.size() >= int(view._params["board"].cols) * int(view._params["board"].rows), \
		"the board preview renders every cell state through the Slot-cell background")
	ok(_locked_placeholder(board_with_locks) != null and is_equal_approx(_locked_placeholder(board_with_locks).modulate.a, 0.30), \
		"the board preview inherits the shared locked placeholder sprite at 30% opacity")
	ok(_has_class(board_with_locks, "GPUParticles2D"), \
		"the board preview includes the unlockable Slot-cell state")
	view._params["board"]["cell"] = 100
	view._params["board"]["scale"] = 100
	view._params["board"]["pieces"] = true
	view._params["bag_card"]["content_frac"] = 30
	var small_piece_px := _piece_holder_max_px(view._make_element("board"))
	var small_art_px := _piece_art_max_px(view._make_element("board"))
	view._params["bag_card"]["content_frac"] = 95
	var large_piece_px := _piece_holder_max_px(view._make_element("board"))
	var large_art_px := _piece_art_max_px(view._make_element("board"))
	ok(small_piece_px > 0.0 and large_piece_px > small_piece_px + 20.0 \
		and absf(small_piece_px - 30.0) <= 2.0 and absf(large_piece_px - 95.0) <= 2.0 \
		and absf(small_art_px - 30.0) <= 2.0 and large_art_px >= 90.0, \
		"board preview applies Slot-cell content_frac to demo pieces")
	view._params["bag_card"] = bag_default
	var board_scene = load("res://engine/scenes/Board.tscn").instantiate()
	board_scene._apply_board_config({"scale": 100, "gap": 7, "frame": 60, "item": 56, "content_frac": 91})
	ok(absf(float(board_scene.get("_board_item_inset")) - 0.045) <= 0.001, \
		"live board pieces use Slot-cell content_frac instead of board.item")
	board_scene.queue_free()

	# the CELL knob is preview-only: wider preview cells grow the workbench board footprint.
	view._params["board"]["cell"] = 80
	ok(view._make_element("board").custom_minimum_size.x > w0, \
		"a wider preview cell grows the board footprint")

	# the SCALE knob zooms the WHOLE composition, independently of cell
	view._params["board"]["cell"] = 50
	view._params["board"]["scale"] = 200
	ok(view._make_element("board").custom_minimum_size.x > w0, \
		"a larger scale zooms the whole board (scale knob)")

	# editing a board slider rebuilds just the board section (live preview)
	view._params["board"]["scale"] = 100
	view._selected = "board"
	view._rebuild_sidebar()
	ok(_slider_max(view, "Item") == -INF, "the board sidebar does not expose a duplicate item-size slider")
	var id0: int = _id_of(view, "board")
	view._params["board"]["cell"] = 64
	view._apply_edit()
	ok(_id_of(view, "board") != id0, "editing a board slider rebuilds the board element live")
	view._params["board"] = board_default

func _is_warm_shadow(color: Color) -> bool:
	return color.a > 0.0 and color.r > color.b and color.r > 0.08

func _test_warm_shadow_port() -> void:
	# the SHARED box-shadow (both shapes) carries the warm reference tint — fill + feather, same colour.
	var p := Look.shadow_params({"shadow": {"offset_x": 0, "offset_y": 10, "blur": 14, "spread": 4, "alpha": 34, "warmth": 82}})
	for sh in [Look.shadow_rect(40.0, p), Look.shadow_circle(140.0, p)]:
		var st := (sh as Panel).get_theme_stylebox("panel") as StyleBoxFlat
		ok(st != null and _is_warm_shadow(st.shadow_color) and st.shadow_size > 0, \
			"the shared shadow uses the warm reference shadow tint")

	# a component that casts the shared shadow (board) gets the warm tint on its shadow panel
	var board := Kit.board_panel(Vector2(220.0, 160.0), {"shadow": true, "shadow_params": p})
	var board_warm := false
	for pan in board.find_children("*", "Panel", true, false):
		var sb := (pan as Panel).get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null and sb.shadow_size > 0:
			board_warm = _is_warm_shadow(sb.shadow_color)
			break
	ok(board_warm, "the board frame casts the shared warm-tinted shadow")

	# the asset-pipeline baked shadow (shape-true, for sprites) still uses the warm tint
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var baked := Kit.add_drop_shadow(img, {
		"shadow_alpha": 1.0, "shadow_offset": Vector2(4.0, 4.0), "shadow_blur": 0.0, "shadow_pad": 8
	})
	ok(_is_warm_shadow(baked.get_pixel(18, 18)), \
		"baked icon/badge shadows use the warm reference shadow tint")

# The MYSTERY slot reveal as a workbench preview (T54): a registered gallery item built from the SAME
# engine builder the game animates (build_reveal → reels). Static + DETERMINISTIC. States: "revealed" (all
# reels landed, premium shining) and "pick" (the pick phase — reels tappable, one chosen, the Claim button).
# "▶ Play spin" replays the real reel animation on the live element.
func _test_mystery_preview(view) -> void:
	ok(view._sections.has("mystery"), "the mystery slot-reveal dialog is a registered gallery item")
	ok(_gallery_neighbors("daily", "mystery"), "the mystery dialog sits next to the daily calendar in the gallery")
	ok(not view._is_config("mystery", "preview"), "the mystery preview-state picker is preview-only (not saved)")
	ok(is_equal_approx(LoginMystery.reveal_width(2000.0), 560.0), "the reveal width caps at 560 (shared with the live dialog)")

	# the SHARED builder returns the reveal face: a dialog, one REEL per option, a caption, and a Claim button
	var pool: Array = Login.mystery_pool(7)
	var opts := [pool[0], pool[1], pool[2]]
	var built: Dictionary = LoginMystery.build_reveal(opts, [1], LoginMystery.reveal_width(1080.0), {"frame_cfg": view._params})
	ok(built.has("dialog") and built.has("reels") and built.has("caption") and built["claim"] is Button, "build_reveal returns {dialog, reels, caption, claim}")
	ok((built["reels"] as Array).size() == opts.size(), "build_reveal makes one reel per option")
	ok((built["reels"][0] as Control).get_meta("reward", {}) == opts[0], "each reel carries its landed reward")
	(built["dialog"] as Control).queue_free()

	# REVEALED: the day-7 pool shows its amounts, the premium (gem) reels SHINE, and the reels are exposed for replay
	view._params["mystery"]["preview"] = "day 7 · revealed"
	var rev: Control = view._make_element("mystery")
	ok(_has_label_text(rev, "200"), "the day-7 reveal shows a concrete reward amount (200)")
	ok(rev.find_child("Shine", true, false) != null, "a premium (gem) reel shines in the revealed state")
	ok(rev.has_meta("reels") and (rev.get_meta("reels") as Array).size() == 5, "the preview exposes its 5 reels for ▶ Play spin")
	var rev2: Control = view._make_element("mystery")
	ok(_collect_label_set(rev) == _collect_label_set(rev2), "the mystery preview is deterministic (no shuffle between builds)")
	view._play_mystery_spin()   # replays on the live gallery element; must not error
	ok(true, "▶ Play spin replays the reel animation on the live element")
	rev.free(); rev2.free()

	# PICK: the pick phase makes the reels tappable + shows the Claim button, with one reel preselected
	view._params["mystery"]["preview"] = "day 7 · pick"
	var pick: Control = view._make_element("mystery")
	var claim_btn := pick.find_child("MysteryClaim", true, false) as Button
	ok(claim_btn != null and claim_btn.visible, "the pick state shows the Claim button")
	ok(pick.find_child("PickCheck", true, false) != null, "the pick state previews one chosen reel (a check badge)")
	pick.free()

	# the OTHER pool (day 4 = 3 reels / pick 1) renders its 3 reels + a concrete amount
	view._params["mystery"]["preview"] = "day 4 · revealed"
	var d4: Control = view._make_element("mystery")
	ok((d4.get_meta("reels") as Array).size() == int(Login.mystery_config(4).get("show", 0)), "the day-4 reveal renders its 3 reels")
	ok(_has_label_text(d4, "120"), "the day-4 reveal shows a concrete reward amount (120)")
	d4.free()
	view._params["mystery"]["preview"] = "day 7 · revealed"

# The set of all Label texts under `node` (order-independent), for comparing two deterministic builds.
func _collect_label_set(node: Control) -> Dictionary:
	var s := {}
	for l in node.find_children("*", "Label", true, false):
		s[String((l as Label).text)] = true
	return s

func _test_gold_badge_has_no_baked_shadow() -> void:
	var size := 270
	var badge := Kit.gold_badge(float(size))
	var tex_rects := badge.find_children("*", "TextureRect", true, false)
	var tr := tex_rects[0] as TextureRect
	var img := tr.texture.get_image()
	var pad := int(ceil(size * 0.075))
	var bottom_contact := img.get_pixel(pad + int(size * 0.5), pad + size + 1)
	ok(bottom_contact.a < 0.001, "gold_badge texture carries no baked outer shadow")

func _test_gold_badge_shared_shadow_toggle(view) -> void:
	view._params["gold_badge"]["shadow"] = true
	var raw := Kit.gold_badge(270.0)
	var wrapped: Control = view._maybe_wrap_shadow(raw, "gold_badge")
	var shadow_panel := wrapped.get_child(0) as Panel if wrapped.get_child_count() > 0 else null
	var sb := shadow_panel.get_theme_stylebox("panel") as StyleBoxFlat if shadow_panel != null else null
	ok(wrapped.get_instance_id() != raw.get_instance_id() and sb != null and sb.shadow_size > 0, \
		"gold_badge uses the shared shadow wrapper when its Shadow toggle is on")
	view._params["gold_badge"]["shadow"] = false
	var raw2 := Kit.gold_badge(270.0)
	var unwrapped: Control = view._maybe_wrap_shadow(raw2, "gold_badge")
	ok(unwrapped.get_instance_id() == raw2.get_instance_id(), \
		"gold_badge Shadow toggle removes the shared shadow wrapper")
	view._params["gold_badge"]["shadow"] = true

func _gold_badge_preview_image(view) -> Image:
	var badge: Control = view._make_element("gold_badge")
	var tex_rects := badge.find_children("*", "TextureRect", true, false)
	return (tex_rects[0] as TextureRect).texture.get_image()

func _image_sparse_diff(a: Image, b: Image) -> int:
	var changed := 0
	for y in range(0, mini(a.get_height(), b.get_height()), 7):
		for x in range(0, mini(a.get_width(), b.get_width()), 7):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) + absf(ca.a - cb.a) > 0.04:
				changed += 1
	return changed

func _luma(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722

func _max_rgb_delta(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))

func _test_gold_badge_inner_inset(view) -> void:
	ok(view._params["gold_badge"].has("inner_inset"), "gold_badge exposes an inner_inset Workbench control")
	ok(view._is_config("gold_badge", "inner_inset"), "gold_badge inner_inset is saved design config")
	var prev: Dictionary = (view._params["gold_badge"] as Dictionary).duplicate()
	view._params["gold_badge"]["px"] = 270
	view._params["gold_badge"]["inner_inset"] = 6
	var near := _gold_badge_preview_image(view)
	view._params["gold_badge"]["inner_inset"] = 24
	var far := _gold_badge_preview_image(view)
	ok(_image_sparse_diff(near, far) > 20, "gold_badge inner_inset redraws the groove distance from the outer border")
	view._params["gold_badge"] = prev

func _test_gold_badge_shine(view) -> void:
	ok(view._params["gold_badge"].has("shine"), "gold_badge exposes a shine Workbench control")
	ok(view._is_config("gold_badge", "shine"), "gold_badge shine is saved design config")
	var prev: Dictionary = (view._params["gold_badge"] as Dictionary).duplicate()
	view._params["gold_badge"]["px"] = 270
	view._params["gold_badge"]["inner_inset"] = 11
	view._params["gold_badge"]["shine"] = 0
	var dull := _gold_badge_preview_image(view)
	view._params["gold_badge"]["shine"] = 160
	var bright := _gold_badge_preview_image(view)
	ok(_image_sparse_diff(dull, bright) > 20, "gold_badge shine redraws the background highlight")
	view._params["gold_badge"] = prev

func _test_gold_badge_gradient(view) -> void:
	ok(view._params["gold_badge"].has("gradient"), "gold_badge exposes a gradient Workbench control")
	ok(view._is_config("gold_badge", "gradient"), "gold_badge gradient is saved design config")
	view._selected = "gold_badge"
	view._rebuild_sidebar()
	ok(_has_label_text(view._sidebar_body, "Gradient"), "gold_badge sidebar shows the saved Gradient slider")
	var prev: Dictionary = (view._params["gold_badge"] as Dictionary).duplicate()
	view._params["gold_badge"]["px"] = 270
	view._params["gold_badge"]["inner_inset"] = 11
	view._params["gold_badge"]["corner"] = 58
	view._params["gold_badge"]["shine"] = 0
	view._params["gold_badge"]["gradient"] = 0
	var flat := _gold_badge_preview_image(view)
	view._params["gold_badge"]["gradient"] = 100
	var ramp := _gold_badge_preview_image(view)
	var pad := int(ceil(270 * 0.075))
	var flat_delta := absf(_luma(flat.get_pixel(pad + 80, pad + 80)) - _luma(flat.get_pixel(pad + 210, pad + 210)))
	var ramp_delta := absf(_luma(ramp.get_pixel(pad + 80, pad + 80)) - _luma(ramp.get_pixel(pad + 210, pad + 210)))
	ok(flat_delta < ramp_delta * 0.35, "gold_badge gradient controls flat-vs-ramped background shading")
	ok(_image_sparse_diff(flat, ramp) > 20, "gold_badge gradient redraws the background fill")
	view._params["gold_badge"] = prev

func _test_gold_badge_background_matches_icon_badges(view) -> void:
	var prev: Dictionary = (view._params["gold_badge"] as Dictionary).duplicate()
	view._params["gold_badge"]["px"] = 270
	view._params["gold_badge"]["inner_inset"] = 11
	view._params["gold_badge"]["corner"] = 58
	view._params["gold_badge"]["shine"] = 0
	view._params["gold_badge"]["gradient"] = 0
	var img := _gold_badge_preview_image(view)
	var pad := int(ceil(270 * 0.075))
	var face := img.get_pixel(pad + 135, pad + 135)
	var ref_tex := load(Look.kit("shared/badge_square.png")) as Texture2D
	var ref_img := ref_tex.get_image()
	var ref := ref_img.get_pixel(ref_img.get_width() / 2, ref_img.get_height() / 2)
	ok(_max_rgb_delta(face, ref) < 0.02, \
		"gold_badge flat background matches the shared icon badge face")
	view._params["gold_badge"] = prev

func _test_gold_badge_corner(view) -> void:
	ok(view._params["gold_badge"].has("corner"), "gold_badge exposes a corner Workbench control")
	ok(view._is_config("gold_badge", "corner"), "gold_badge corner is saved design config")
	view._selected = "gold_badge"
	view._rebuild_sidebar()
	ok(_has_label_text(view._sidebar_body, "Corner"), "gold_badge sidebar shows the saved Corner slider")
	var prev: Dictionary = (view._params["gold_badge"] as Dictionary).duplicate()
	view._params["gold_badge"]["px"] = 270
	view._params["gold_badge"]["inner_inset"] = 11
	view._params["gold_badge"]["shine"] = 100
	view._params["gold_badge"]["corner"] = 28
	var boxy := _gold_badge_preview_image(view)
	view._params["gold_badge"]["corner"] = 92
	var round := _gold_badge_preview_image(view)
	ok(_image_sparse_diff(boxy, round) > 20, "gold_badge corner redraws the outer rounded border")
	view._params["gold_badge"] = prev

func _test_gold_badge_inner_corner_tracks_outer(view) -> void:
	var prev: Dictionary = (view._params["gold_badge"] as Dictionary).duplicate()
	view._params["gold_badge"]["px"] = 270
	view._params["gold_badge"]["inner_inset"] = 6
	view._params["gold_badge"]["shine"] = 100
	view._params["gold_badge"]["corner"] = 28
	var img := _gold_badge_preview_image(view)
	var pad := int(ceil(270 * 0.075))
	var true_inset_curve := img.get_pixel(pad + 15, pad + 10)
	var old_overrounded_curve := img.get_pixel(pad + 14, pad + 14)
	ok(_luma(true_inset_curve) < _luma(old_overrounded_curve) - 0.015, \
		"gold_badge inner border corner follows outer corner as a true inset")
	view._params["gold_badge"] = prev

func _board_frame_image_with_badge(badge: Dictionary) -> Image:
	var opts := Kit.board_panel_opts_from_config({
		"board": {"frame_style": "badge", "shadow": false},
		"gold_badge": badge,
	})
	var board := Kit.board_panel(Vector2(220, 160), opts)
	var patches := board.find_children("*", "NinePatchRect", true, false)
	var img := ((patches[0] as NinePatchRect).texture as Texture2D).get_image() if not patches.is_empty() else Image.create(1, 1, false, Image.FORMAT_RGBA8)
	board.queue_free()
	return img

func _board_frame_image(shine: float) -> Image:
	return _board_frame_image_with_badge({"inner_inset": 11, "shine": shine})

func _info_bar_frame_image_with_badge(badge: Dictionary) -> Image:
	var opts := Kit.info_bar_opts_from_config({
		"info_bar": {},
		"gold_badge": badge,
	})
	var bar := Kit.info_bar({}, opts)
	var sb := bar.get_theme_stylebox("panel")
	var img := ((sb as StyleBoxTexture).texture as Texture2D).get_image() if sb is StyleBoxTexture else Image.create(1, 1, false, Image.FORMAT_RGBA8)
	bar.queue_free()
	return img

func _info_bar_frame_image(shine: float) -> Image:
	return _info_bar_frame_image_with_badge({"inner_inset": 11, "shine": shine})

func _map_open_frame_image(badge: Dictionary) -> Image:
	var opts := Kit.map_card_opts_from_config({"map_card": {}, "gold_badge": badge})
	var card := Kit.map_card({"open": true, "done": false, "art": "", "map_id": ""}, opts, 460.0, 160.0)
	var frame := card.find_child(Kit.MAP_FRAME_NODE, true, false)
	var img := ((frame as NinePatchRect).texture as Texture2D).get_image() if frame is NinePatchRect else Image.create(1, 1, false, Image.FORMAT_RGBA8)
	card.queue_free()
	return img

func _test_gold_badge_consumers(view) -> void:
	var prev_dirty: Dictionary = view._dirty.duplicate()
	view._dirty.clear()
	view._selected = "gold_badge"
	view._apply_edit()
	ok(view._dirty.has("board") and view._dirty.has("info_bar") and view._dirty.has("map_card"), \
		"editing gold_badge queues the board frame, info bar, and map card to rebuild")
	view._dirty = prev_dirty

	var board_dull := _board_frame_image(0)
	var board_bright := _board_frame_image(160)
	ok(_image_sparse_diff(board_dull, board_bright) > 20, \
		"the board badge frame uses the saved gold_badge shine")

	var info_dull := _info_bar_frame_image(0)
	var info_bright := _info_bar_frame_image(160)
	ok(_image_sparse_diff(info_dull, info_bright) > 20, \
		"the info bar board uses the saved gold_badge shine")

	var board_flat := _board_frame_image_with_badge({"inner_inset": 11, "shine": 0, "corner": 58, "gradient": 0})
	var board_ramp := _board_frame_image_with_badge({"inner_inset": 11, "shine": 0, "corner": 58, "gradient": 100})
	ok(_image_sparse_diff(board_flat, board_ramp) > 20, \
		"the board badge frame uses the saved gold_badge gradient")

	var info_flat := _info_bar_frame_image_with_badge({"inner_inset": 11, "shine": 0, "corner": 58, "gradient": 0})
	var info_ramp := _info_bar_frame_image_with_badge({"inner_inset": 11, "shine": 0, "corner": 58, "gradient": 100})
	ok(_image_sparse_diff(info_flat, info_ramp) > 20, \
		"the info bar board uses the saved gold_badge gradient")

	var board_boxy := _board_frame_image_with_badge({"inner_inset": 11, "shine": 100, "corner": 28})
	var board_round := _board_frame_image_with_badge({"inner_inset": 11, "shine": 100, "corner": 92})
	ok(_image_sparse_diff(board_boxy, board_round) > 20, \
		"the board badge frame uses the saved gold_badge corner")

	var info_boxy := _info_bar_frame_image_with_badge({"inner_inset": 11, "shine": 100, "corner": 28})
	var info_round := _info_bar_frame_image_with_badge({"inner_inset": 11, "shine": 100, "corner": 92})
	ok(_image_sparse_diff(info_boxy, info_round) > 20, \
		"the info bar board uses the saved gold_badge corner")

	# the MAP CARD's open frame is the SHARED gold-badge skin too: an open card wears the MapGoldFrame
	# NinePatch (a locked card does not), the opts carry the shared badge + band knob, and the frame tracks
	# the saved gold_badge corner + shine.
	var map_opts := Kit.map_card_opts_from_config({"map_card": {}, "gold_badge": {}})
	ok(map_opts.has("badge"), \
		"map_card opts carry the shared gold_badge skin BOTH card states' frame wears")
	ok(not map_opts.has("card_w_frac"), \
		"map_card opts no longer carry an obsolete width fraction; two-column layout owns card width")
	ok(not view._params["map_card"].has("card_w_frac") and not _source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"card_w_frac\""), \
		"the Workbench map-card sidebar no longer exposes a width slider")
	ok(_source_contains("res://games/grove/tools/ui_workbench_kit.gd", "static func map_select_layout") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "Kit.map_select_layout") \
		and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "Kit.map_select_layout(Vector2(PHONE_W, PHONE_H)"), \
		"Workbench and game derive map-card preview geometry from the same two-column layout helper")
	ok(_source_contains("res://games/grove/tools/ui_workbench_kit.gd", "static func map_card_art_path") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "Kit.map_card_art_path") \
		and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "Kit.map_card_art_path(Game.DATA.MAPS[0])"), \
		"Workbench and game resolve the open map-card artwork through the same helper")
	ok(map_opts.has("resident_slot_px") and map_opts.has("resident_slot_gap"), \
		"map_card opts carry saved resident rail slot size and slot gap")
	var map_slot_opts: Dictionary = map_opts.get("slot_cell", {})
	ok(map_slot_opts.has("cell_w") \
		and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "\"bag_card\": _params[\"bag_card\"]"), \
		"map_card opts carry the shared square Slot-cell style used by the Workbench right column")
	ok(view._params["map_card"].has("resident_slot_px") and view._params["map_card"].has("resident_slot_gap") \
		and view._is_config("map_card", "resident_slot_px") and view._is_config("map_card", "resident_slot_gap"), \
		"the map-card resident rail knobs are saved Workbench config")
	ok(map_opts.has("reward_shelf_w_frac") and map_opts.has("reward_shelf_h_frac") and map_opts.has("reward_shelf_y_frac"), \
		"map_card opts carry saved completed-map reward shelf size and lift knobs")
	ok(view._params["map_card"].has("reward_shelf_w_frac") and view._params["map_card"].has("reward_shelf_h_frac") \
		and view._params["map_card"].has("reward_shelf_y_frac") and view._is_config("map_card", "reward_shelf_w_frac") \
		and view._is_config("map_card", "reward_shelf_h_frac") and view._is_config("map_card", "reward_shelf_y_frac"), \
		"the completed-map reward shelf knobs are saved Workbench config")
	var shelf_part_keys := ["reward_icon_size", "reward_icon_x", "reward_icon_y", "reward_label_font", "reward_label_x", "reward_label_y", "reward_button_w", "reward_button_h", "reward_button_x", "reward_button_y", "reward_button_font", "reward_bar_h", "reward_bar_y"]
	var shelf_part_knobs_saved := true
	for k in shelf_part_keys:
		shelf_part_knobs_saved = shelf_part_knobs_saved and map_opts.has(k) and view._params["map_card"].has(k) and view._is_config("map_card", k)
	ok(shelf_part_knobs_saved, \
		"map_card opts carry saved reward shelf icon/text/button size and location knobs")
	ok(_source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"resident_slot_px\"") \
		and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"resident_slot_gap\""), \
		"the Workbench map-card sidebar exposes resident slot-size and gap sliders")
	view._selected = "map_card"
	view._rebuild_sidebar()
	ok(_slider_max(view, "Resident Slot Px") >= 148.0, \
		"the map-card resident slot-size slider can grow to double the old cap")
	ok(_source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"reward_shelf_w_frac\"") \
		and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"reward_shelf_h_frac\"") \
		and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"reward_shelf_y_frac\""), \
		"the Workbench map-card sidebar exposes completed-map reward shelf sliders")
	ok(_source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"reward_icon_size\"") \
		and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"reward_icon_x\"") \
		and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"reward_label_font\"") \
		and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"reward_label_x\"") \
		and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"reward_button_w\"") \
		and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"reward_button_x\"") \
		and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"reward_button_font\"") \
		and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"reward_bar_h\"") \
		and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"reward_bar_y\""), \
		"the Workbench map-card sidebar exposes reward shelf icon/text/button adjustment sliders")
	ok(_source_contains("res://games/grove/tools/ui_workbench_view.gd", "\"resident_preview\": true"), \
		"the Workbench map-card preview requests the resident-slot preview overlay")
	ok(_source_contains("res://games/grove/tools/ui_workbench_view.gd", "\"habitat_preview\": bool(p.open)"), \
		"the Workbench map-card preview shows the collection progress shelf for open map cards")
	var open_card := Kit.map_card({"open": true, "done": false, "art": "", "map_id": "", "title": "The Farm"}, map_opts, 460.0, 160.0)
	var locked_card := Kit.map_card({"open": false, "done": false, "art": "", "prereq": "✿ after X", "map_id": ""}, map_opts, 460.0, 160.0)
	var preview_small := Kit.map_card({"open": true, "done": false, "art": "", "map_id": "", "resident_preview": true}, \
		Kit.map_card_opts_from_config({"map_card": {"resident_slot_px": 36, "resident_slot_gap": 4}, "gold_badge": {}}), 460.0, 230.0)
	var preview_big := Kit.map_card({"open": true, "done": false, "art": "", "map_id": "", "resident_preview": true}, \
		Kit.map_card_opts_from_config({"map_card": {"resident_slot_px": 64, "resident_slot_gap": 18}, "gold_badge": {}}), 460.0, 230.0)
	var preview_oversized := Kit.map_card({"open": true, "done": false, "art": "", "map_id": "", "resident_preview": true}, \
		Kit.map_card_opts_from_config({"map_card": {"resident_slot_px": 120, "resident_slot_gap": 18}, "gold_badge": {}}), 520.0, 700.0)
	var tuned_shelf_card := Kit.map_card({"open": true, "done": false, "art": "", "map_id": "", "habitat_preview": true}, \
		Kit.map_card_opts_from_config({"map_card": {
			"reward_icon_size": 38, "reward_icon_x": 7, "reward_icon_y": -3,
			"reward_label_font": 21, "reward_label_x": 11, "reward_label_y": 4,
			"reward_button_w": 132, "reward_button_h": 36, "reward_button_x": -9, "reward_button_y": -5,
			"reward_bar_h": 18, "reward_bar_y": -7,
		}, "gold_badge": {}}), 460.0, 230.0)
	var small_rail := preview_small.find_child("MapResidentRailPreview", true, false) as Control
	var big_rail := preview_big.find_child("MapResidentRailPreview", true, false) as Control
	var tuned_shelf := tuned_shelf_card.find_child("MapHabitatRewardShelf", true, false) as Control
	var tuned_icon := tuned_shelf_card.find_child("MapHabitatRewardIcon", true, false) as Control
	var tuned_label := tuned_shelf_card.find_child("MapHabitatRewardLabel", true, false) as Label
	var tuned_collect := tuned_shelf_card.find_child("MapHabitatCollectButton", true, false) as Button
	var tuned_collect_label := tuned_shelf_card.find_child("MapHabitatCollectButtonLabel", true, false) as Label
	var tuned_collect_icon := tuned_shelf_card.find_child("MapHabitatCollectButtonIcon", true, false) as Control
	var tuned_bar := tuned_shelf_card.find_child("MapHabitatProgressBar", true, false) as Control
	var oversized_slot := preview_oversized.find_child("MapResidentRailPreviewSlot_00", true, false) as Control
	var preview_slot_count := 0
	var preview_slot_background_count := 0
	var preview_ring_count := 0
	for node in preview_small.find_children("*", "", true, false):
		if String(node.name).begins_with("MapResidentRailPreviewSlot_"):
			preview_slot_count += 1
		if String(node.name) == "SlotCellBackground":
			preview_slot_background_count += 1
		if String(node.name) == "MapResidentRailPreviewSlotRing":
			preview_ring_count += 1
	ok(small_rail != null and preview_slot_count == 8, \
		"the Workbench map-card preview shows all eight resident slots")
	ok(preview_slot_background_count == 8 and preview_ring_count == 0, \
		"the Workbench map-card preview uses standard square Slot-cell backgrounds instead of circular resident rings")
	ok(big_rail != null and small_rail != null and big_rail.size.x > small_rail.size.x and big_rail.size.y > small_rail.size.y, \
		"the resident-slot preview grows when the slot-size and gap sliders grow")
	ok(oversized_slot != null and oversized_slot.custom_minimum_size.x >= 118.0 and oversized_slot.custom_minimum_size.y >= 118.0, \
		"the resident-slot preview applies sizes beyond the old cap when the card has room")
	ok(tuned_shelf != null and tuned_icon != null and tuned_icon.custom_minimum_size == Vector2(38, 38) \
		and tuned_icon.position == Vector2(21, 5), \
		"the Workbench map-card preview applies reward icon size and location knobs")
	ok(tuned_shelf != null and tuned_label != null and int(tuned_label.get_theme_font_size("font_size")) == 21 \
		and tuned_label.position == Vector2(67, 11), \
		"the Workbench map-card preview applies reward label font and location knobs")
	ok(tuned_label != null and tuned_label.text == "5/5", \
		"the Workbench map-card preview replaces housed text with collection progress")
	ok(tuned_collect != null and tuned_collect.custom_minimum_size == Vector2(132, 36), \
		"the Workbench map-card preview applies reward button size knobs")
	ok(tuned_collect != null and tuned_collect.size == Vector2(132, 36) \
		and tuned_collect_label != null and tuned_collect_label.text == "Collect" and tuned_collect_icon == null, \
		"the Workbench map-card preview keeps the rendered reward button plain and labeled")
	ok(tuned_shelf != null and tuned_bar != null \
		and int(round(tuned_bar.custom_minimum_size.y)) == 18 \
		and tuned_bar.position.y == tuned_shelf.size.y - 38.0, \
		"the Workbench map-card preview applies progress bar height and Y knobs")
	ok(tuned_shelf != null and tuned_collect != null \
		and tuned_collect.position == Vector2(tuned_shelf.size.x - 155, tuned_shelf.size.y - 49), \
		"the Workbench map-card preview applies reward button location knobs")
	ok(tuned_shelf != null and tuned_collect != null \
		and tuned_collect.position.x >= 0 and tuned_collect.position.y >= 0 \
		and tuned_collect.position.x + tuned_collect.custom_minimum_size.x <= tuned_shelf.size.x \
		and tuned_collect.position.y + tuned_collect.custom_minimum_size.y <= tuned_shelf.size.y, \
		"the Workbench map-card preview keeps the tuned reward button inside the shelf")
	ok(open_card.find_child(Kit.MAP_FRAME_NODE, true, false) is NinePatchRect, \
		"an OPEN map card wears the shared gold-badge frame (MapGoldFrame NinePatch)")
	ok(locked_card.find_child(Kit.MAP_FRAME_NODE, true, false) is NinePatchRect, \
		"a LOCKED map card ALSO wears the shared gold-badge frame (consistent with open)")
	ok(open_card.find_child("MapCardShadow", true, false) is Control and open_card.find_child("MapCardOuterBorder", true, false) is Control, \
		"an OPEN map card has an outer shadow and dark rim behind the golden border")
	ok(open_card.find_child("MapCardTitlePlate", true, false) is Control \
		and ResourceLoader.exists(Look.kit("map/left_title_plate.png")), \
		"an OPEN map card wraps its map name in the generated leafy bordered title plate")
	ok(locked_card.find_child("MapCardShadow", true, false) is Control and locked_card.find_child("MapCardOuterBorder", true, false) is Control, \
		"a LOCKED map card has an outer shadow and dark rim behind the golden border")
	ok(ResourceLoader.exists(Look.kit("map/left_locked_preview_inner.png")), \
		"the generated left-map locked preview asset is available")
	ok(ResourceLoader.exists(Look.kit("map/left_lock_flower_soft.png")), \
		"the generated left-map lock medallion asset is available")
	var locked_preview := locked_card.find_child("MapLockedPreviewArt", true, false)
	ok(locked_preview is Control and String((locked_preview as Control).get_meta("asset_rel", "")) == "map/left_locked_preview_inner.png", \
		"a LOCKED map card uses the generated preview art under the shared frame")
	var locked_med := locked_card.find_child(Kit.MAP_LOCK_NODE, true, false)
	ok(locked_med is TextureRect and String((locked_med as TextureRect).get_meta("asset_rel", "")) == "map/left_lock_flower_soft.png", \
		"a LOCKED map card uses the generated large lock medallion")
	var prereq_row := locked_card.find_child("MapLockedPrereqRow", true, false) as Control
	var prereq_left := locked_card.find_child("MapLockedPrereqLeafLeft", true, false) as TextureRect
	var prereq_right := locked_card.find_child("MapLockedPrereqLeafRight", true, false) as TextureRect
	var prereq_label := locked_card.find_child("MapLockedPrereqLabel", true, false) as Label
	ok(prereq_left != null and prereq_right != null and prereq_label != null, \
		"a LOCKED map card wraps its prerequisite line with leaf ornaments")
	if prereq_row != null and prereq_left != null and prereq_right != null and prereq_label != null:
		var left_center_y := prereq_left.position.y + prereq_left.size.y * 0.5
		var right_center_y := prereq_right.position.y + prereq_right.size.y * 0.5
		var row_center_y := prereq_row.size.y * 0.5
		ok(prereq_left.size.x <= 32.0 and prereq_left.size.y <= 22.0 \
			and prereq_right.size.x <= 32.0 and prereq_right.size.y <= 22.0, \
			"locked prerequisite leaves stay small enough to flank the text instead of overpowering it")
		ok(absf(left_center_y - row_center_y) <= 2.0 and absf(right_center_y - row_center_y) <= 2.0, \
			"locked prerequisite leaves are vertically centered on the text row")
		ok(prereq_label.position.x >= prereq_left.position.x + prereq_left.size.x + 6.0 \
			and prereq_label.position.x + prereq_label.size.x <= prereq_right.position.x - 6.0, \
			"locked prerequisite text sits between the two leaves with a readable gap")
	ok(_source_contains("res://engine/scripts/scenes/map.gd", "MapHabitatRewardIcon") \
		and _source_contains("res://games/grove/tools/ui_workbench_kit.gd", "MapHabitatCollectButton"), \
		"completed map cards render a reward icon and named large green Collect button")
	ok(_source_contains("res://engine/scripts/scenes/map.gd", "Kit.map_reward_collect_button") \
		and _source_contains("res://games/grove/tools/ui_workbench_kit.gd", "static func map_reward_collect_button") \
		and _source_contains("res://games/grove/tools/ui_workbench_kit.gd", "\"shadow\": false") \
		and _source_contains("res://games/grove/tools/ui_workbench_kit.gd", "\"art\": false") \
		and _source_contains("res://games/grove/tools/ui_workbench_kit.gd", "\"pad_scale\": 0.62") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "reward_button_font") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "reward_button_w") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "reward_button_h"), \
		"completed map Collect button stays compact, Workbench-tuned, and avoids sprite-padding/shadow bloat")
	ok(_source_contains("res://engine/scripts/scenes/map.gd", "_spirit_cell(Kit, bag_opts") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "_empty_cell(Kit, bag_opts") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "var display_cap := maxi(cap, 8)"), \
		"completed map resident rails reuse standard square slot cells and keep eight spaces ready")
	ok(_source_contains("res://engine/scripts/scenes/map.gd", "_spirit_cell(Kit, bag_opts, String(inst.kind), int(inst.tier), orb_px") \
		and not _source_contains("res://engine/scripts/scenes/map.gd", "_resident_slot(orb_px, orb)") \
		and not _source_contains("res://engine/scripts/scenes/map.gd", "_resident_slot(orb_px)"), \
		"completed map resident rail filled slots do not render the old per-orb tier badge")
	ok(_source_contains("res://engine/scripts/scenes/map.gd", "var slot_cols := 2") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "var slot_rows := 4"), \
		"completed map resident rails arrange eight spaces as a two-column/four-row rail")
	ok(_source_contains("res://engine/scripts/scenes/map.gd", "MapResidentRailFrame") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "Kit.board_panel") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "\"draw_center\": true") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "strip.add_child(frame)") \
		and not _source_contains("res://engine/scripts/scenes/map.gd", "LEFT_MAP_HABITAT_STRIP"), \
		"completed map resident rail uses the code-drawn board background instead of baked strip art")
	ok(_source_contains("res://engine/scripts/scenes/map.gd", "MapResidentRailInset") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "resident_slot_px") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "resident_slot_gap") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "rail_w := orb_px * float(slot_cols) + sep * float(slot_cols - 1) + rail_pad * 2.0") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "rail_h := orb_px * float(slot_rows) + sep * float(slot_rows - 1) + rail_pad * 2.0"), \
		"completed map resident rail border expands and shrinks with the slot size and slot gap")
	ok(_source_contains("res://games/grove/tools/ui_workbench_kit.gd", "static func map_habitat_shelf_rect") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "Kit.map_habitat_shelf_rect") \
		and _source_contains("res://engine/scripts/scenes/map.gd", "MapHabitatRewardShelf"), \
		"completed map reward shelf placement is driven by the shared Workbench-tuned layout helper")
	ok(_source_contains("res://engine/scripts/scenes/map.gd", "LEFT_MAP_TITLE_PLATE") \
		and not _source_contains("res://engine/scripts/scenes/map.gd", "MapHabitatTitleLeafLeft") \
		and not _source_contains("res://games/grove/tools/ui_workbench_kit.gd", "MapCardTitleLeafLeft"), \
		"map title plates rely on the generated leafy plate without extra flourish overlays")
	open_card.queue_free()
	locked_card.queue_free()
	preview_small.queue_free()
	preview_big.queue_free()
	tuned_shelf_card.queue_free()

	var map_boxy := _map_open_frame_image({"inner_inset": 11, "shine": 100, "corner": 28})
	var map_round := _map_open_frame_image({"inner_inset": 11, "shine": 100, "corner": 92})
	ok(_image_sparse_diff(map_boxy, map_round) > 20, \
		"the map card's open frame uses the saved gold_badge corner")
	var map_dull := _map_open_frame_image({"inner_inset": 11, "shine": 0, "corner": 58})
	var map_bright := _map_open_frame_image({"inner_inset": 11, "shine": 160, "corner": 58})
	ok(_image_sparse_diff(map_dull, map_bright) > 20, \
		"the map card's open frame uses the saved gold_badge shine")

## The quest-giver card layout is CONFIG-DRIVEN now: the workbench SAVES the quest_card layout block and
## the board reads it via Kit.giver_lay_from_config (cfg.lay → GiverStand.make). This pins the save/read
## bridge: the layout knobs are persisted, the demo knobs are not, and the transform mirrors the shipped LAY.
func _test_quest_card_config(view) -> void:
	ok(view._sections.has("quest_card"), "the quest card is a registered gallery item")
	# the LAYOUT block is saved design config; the DEMO block (which giver / tier / size) is preview-only
	ok(view._is_config("quest_card", "card_w") and view._is_config("quest_card", "item_size") \
		and view._is_config("quest_card", "plaque_y"), "the quest-card layout knobs are saved design config")
	ok(not view._is_config("quest_card", "bust") and not view._is_config("quest_card", "stand_w") \
		and not view._is_config("quest_card", "met"), "the quest-card demo knobs are preview-only (not saved)")

	# Kit.giver_lay_from_config DEFAULTS must mirror giver_stand.LAY, so an empty config renders the SHIPPED card
	var GiverStand = load("res://engine/scripts/ui/giver_stand.gd")
	var gdf: Dictionary = Kit.giver_lay_from_config({})
	var lay_ok := true
	for k in GiverStand.LAY:
		if not (gdf.has(k) and is_equal_approx(float(gdf[k]), float(GiverStand.LAY[k]))):
			lay_ok = false
	ok(lay_ok, "giver_lay_from_config defaults mirror giver_stand.LAY (empty config == shipped card)")

	# item_size is a SINGLE uniform knob → a SQUARE item (item_w == item_h, undistorted)
	var gsq: Dictionary = Kit.giver_lay_from_config({"quest_card": {"item_size": 50}})
	ok(is_equal_approx(float(gsq.item_w), 0.50) and is_equal_approx(float(gsq.item_h), 0.50), \
		"giver_lay item_size drives item_w == item_h (square, percent → fraction)")

	# a saved block overrides ONLY the named keys (percent → fraction); every other key stays shipped
	var gov: Dictionary = Kit.giver_lay_from_config({"quest_card": {"card_w": 200, "bust_x": 40}})
	ok(is_equal_approx(float(gov.card_w), 2.0) and is_equal_approx(float(gov.bust_x), 0.40), \
		"giver_lay config overrides the named keys (percent → fraction)")
	ok(is_equal_approx(float(gov.card_h), 0.65), "giver_lay leaves un-named keys at the shipped default")

	# the 9-slice patch margins ride the lay as SOURCE PIXELS (NOT divided) — defaults bracket the wood frame
	ok(is_equal_approx(float(gdf.card_slice_l), 46.0) and is_equal_approx(float(gdf.card_slice_b), 56.0), \
		"giver_lay carries the card 9-slice margins as raw source px (not /100)")
	var gsl: Dictionary = Kit.giver_lay_from_config({"quest_card": {"card_slice_t": 30}})
	ok(is_equal_approx(float(gsl.card_slice_t), 30.0), "giver_lay slice margins are overridable (raw px)")
	# the card background is built as a NINE-SLICE so the frame corners stay crisp while the centre stretches
	var noop := func(_a: Variant, _b: Variant) -> void: pass
	var wire := func(_n: Control, _a: Callable) -> void: pass
	var qcard: Control = GiverStand.make(1, {"line": 1, "tier": 3, "reward": {"exp": 5}}, \
		{"ask_tap": noop, "stand_tap": noop, "wire_tap": wire, "stand_w": 480.0, "fence_h": 410.0, "lay": gdf}).chip
	ok(qcard.find_children("*", "NinePatchRect", true, false).size() > 0, \
		"the giver card background is a NinePatchRect (9-slice, crisp corners)")
	qcard.queue_free()

	# editing a quest-card layout slider rebuilds just the quest-card section (live preview)
	view._selected = "quest_card"
	var qid: int = _id_of(view, "quest_card")
	view._params["quest_card"]["card_w"] = 120
	view._apply_edit()
	ok(_id_of(view, "quest_card") != qid, "editing a quest-card slider rebuilds the quest-card element live")

func _test_bag_components() -> void:
	# the gold currency pill, reused for the bag's single-acorn balance, renders one icon/count pair and
	# stays on the new direct entry point.
	var one := Kit.gold_currency_pill({"icon": "gem", "count": 132, "icon_size": 40, "show_plus": false}, {"gem": 132})
	ok(one is PanelContainer and one.name == "GoldCurrencyPill" and _pill_numbers(one) == 1, \
		"gold_currency_pill renders the bag's single-currency balance")
	var water := Kit.gold_currency_pill({"icon": "water", "show_plus": true}, {"water": 128})
	ok(water is PanelContainer and water.name == "GoldCurrencyPill" and _has_label_text(water, "+"), \
		"gold_currency_pill renders the optional plus button directly")
	ok(not _source_contains("res://games/grove/tools/ui_workbench_kit.gd", "top.add_child(currency_pill("), \
		"bag_dialog uses gold_currency_pill directly for the in-game balance cell")

	# the BAG CELL — one slot tile in each of the four states (filled / empty / next / locked).
	var co := Kit.bag_card_opts_from_config({})
	for kind in ["filled", "empty", "next", "locked"]:
		ok(Kit.bag_card({"kind": kind, "icon": "leaf", "cost": 10}, co) is Control, "bag_card builds a %s tile" % kind)
	# the next (buyable) + locked tiles carry their acorn cost — now the SHARED green pill_button (cost on its text)
	ok(_has_button_text(Kit.bag_card({"kind": "next", "cost": 10}, co), "10"), "the next tile shows its acorn cost (10)")
	ok(_has_button_text(Kit.bag_card({"kind": "locked", "cost": 25}, co), "25"), "a locked tile shows its acorn cost (25)")
	# a filled tile is a tappable button that fires on_tap (the retrieve), an empty tile is inert
	var tapped := [false]
	var fc := Kit.bag_card({"kind": "filled", "icon": "leaf", "on_tap": func() -> void: tapped[0] = true}, co)
	var btn := _first_button(fc)
	ok(btn != null, "a filled tile is a tappable button")
	if btn != null:
		btn.pressed.emit()
	ok(tapped[0], "tapping a filled tile fires on_tap (retrieve)")
	ok(_first_button(Kit.bag_card({"kind": "empty"}, co)) == null, "an empty tile is inert (no button)")

	# the four states share ONE card component: every cell is exactly cell_w × cell_h (the cost rides
	# INSIDE the card now — no extra strip below the tile), so all states are the same size.
	var cwh := Vector2(float(co.cell_w), float(co.cell_h))
	var same := true
	for kind in ["filled", "empty", "next", "locked"]:
		if Kit.bag_card({"kind": kind, "icon": "leaf", "cost": 15}, co).custom_minimum_size != cwh:
			same = false
	ok(same, "every bag-cell state is exactly cell_w × cell_h (one shared card, cost inside)")
	# the NEXT (buyable) cell carries a DYNAMIC sparkle FX (engine-drawn particles); locked does not.
	ok(_has_class(Kit.bag_card({"kind": "next", "cost": 10}, co), "GPUParticles2D"), "the next cell has a dynamic sparkle FX")
	ok(not _has_class(Kit.bag_card({"kind": "locked", "cost": 25}, co), "GPUParticles2D"), "a locked cell has no sparkle FX")

	# --- the shared slot cell (bag + board): slot_cell is the unified name, bag_card a thin alias ---
	ok(Kit.slot_cell({"state": "empty"}, co) is Control, "slot_cell builds an empty cell")
	ok(Kit.bag_card({"kind": "next", "cost": 10}, co) is Control, "bag_card alias still builds")
	# a board-style LEVEL BADGE docks lower-right when d.level is set (the SAME HUD level-badge medal)
	ok(_has_label_text(Kit.slot_cell({"state": "locked", "level": 7}, co), "7"), "a cell with d.level shows the level-badge number")
	# the board's UNLOCKABLE state: highlighted (the shared sparkle), tappable, and NO cost when none given
	var unl := Kit.slot_cell({"state": "unlockable", "on_tap": func() -> void: pass}, co)
	ok(_has_class(unl, "GPUParticles2D"), "an unlockable cell carries the shared highlight sparkle")
	ok(_first_button(unl) != null, "an unlockable cell is tappable")
	ok(unl.find_children("*", "Label", true, false).is_empty(), "an unlockable cell with no cost shows no cost number")
	ok(_unlockable_border_width(unl) == 0, "an unlockable cell has no visible highlight border")
	# the unlockable accent COLOUR (glow_hue / glow_sat): default (42°, 74%) reproduces Pal.STRAW within a
	# single 8-bit level; glow_sat 0 washes it to a neutral warm white; lowering glow_hue shifts it warmer.
	var def_tint := _unlockable_tint(unl)
	ok(absf(def_tint.r - Pal.STRAW.r) < 0.01 and absf(def_tint.g - Pal.STRAW.g) < 0.01 and absf(def_tint.b - Pal.STRAW.b) < 0.01, "the default unlockable tint matches Pal.STRAW (within one level)")
	var co_white := Kit.bag_card_opts_from_config({"bag_card": {"glow_sat": 0}})
	ok(_unlockable_tint(Kit.slot_cell({"state": "unlockable"}, co_white)).s < 0.02, "glow_sat 0 desaturates the unlockable accent to a warm white")
	var co_orange := Kit.bag_card_opts_from_config({"bag_card": {"glow_hue": 20}})
	ok(_unlockable_tint(Kit.slot_cell({"state": "unlockable"}, co_orange)).h < Pal.STRAW.h, "lowering glow_hue shifts the unlockable accent toward orange")
	# the glow INTENSITY/SIZE knobs: each glow layer can be dialled all the way out. glow_shadow 0 removes
	# the rim drop-shadow (the glow hugging the cell); glow_size 0 removes the outer bloom halo.
	ok(_unlockable_shadow_size(unl) > 0, "the unlockable cell has a rim drop-shadow by default")
	var co_noshadow := Kit.bag_card_opts_from_config({"bag_card": {"glow_shadow": 0}})
	ok(_unlockable_shadow_size(Kit.slot_cell({"state": "unlockable"}, co_noshadow)) == 0, "glow_shadow 0 removes the rim drop-shadow")
	ok(_has_class(unl, "TextureRect"), "the unlockable cell carries the outer bloom halo by default")
	var co_nohalo := Kit.bag_card_opts_from_config({"bag_card": {"glow_size": 0, "next_twinkle": 0}})
	var nohalo := Kit.slot_cell({"state": "unlockable"}, co_nohalo)
	ok(_locked_placeholder(nohalo) != null and nohalo.find_children("*", "TextureRect", true, false).size() == 1, \
		"glow_size 0 removes the outer bloom halo while keeping the locked placeholder")
	# locked cells now use the code-drawn Slot-cell background — no separate lock overlay, no baked locked face.
	var locked_plain := Kit.slot_cell({"state": "locked"}, co)
	ok(locked_plain.find_child("SlotCellBackground", true, false) is Panel \
		and locked_plain.find_child("BagLock", true, false) == null, \
		"the locked cell uses the code-drawn Slot-cell background")
	var locked_placeholder := _locked_placeholder(locked_plain)
	ok(locked_placeholder != null and locked_placeholder.texture != null \
		and is_equal_approx(locked_placeholder.modulate.a, 0.30), \
		"the locked cell layers the shared placeholder sprite at 30% opacity")
	var unlockable_placeholder := _locked_placeholder(unl)
	ok(unlockable_placeholder != null and unlockable_placeholder.texture == locked_placeholder.texture \
		and is_equal_approx(unlockable_placeholder.modulate.a, 0.30), \
		"the unlockable cell uses the same locked placeholder sprite at 30% opacity")
	var locked_bg := locked_plain.find_child("SlotCellBackground", true, false) as Control
	ok(locked_plain.custom_minimum_size == cwh, "the locked slot cell owns the configured cell_w/cell_h")
	ok(locked_bg != null and locked_bg.size == cwh, "the locked background paints at the configured slot-cell size")
	ok(locked_bg != null and locked_bg.custom_minimum_size == Vector2.ZERO, \
		"the locked background is paint-only and does not expand the slot cell")
	var co_depth := Kit.bag_card_opts_from_config({"bag_card": {
		"depth": 10, "depth_alpha": 42, "cell_shadow": 55, "cell_shadow_size": 18, "cell_shadow_y": 7,
	}})
	var depth_cell := Kit.slot_cell({"state": "empty"}, co_depth)
	var depth_bg := depth_cell.find_child("SlotCellBackground", true, false) as Panel
	var depth_style: StyleBox = depth_bg.get_theme_stylebox("panel") if depth_bg != null else null
	ok(depth_style is StyleBoxFlat and (depth_style as StyleBoxFlat).border_width_bottom == 10 \
		and (depth_style as StyleBoxFlat).shadow_size > 0 \
		and (depth_style as StyleBoxFlat).shadow_color.a > 0.5 \
		and is_equal_approx((depth_style as StyleBoxFlat).shadow_offset.y, 7.0), \
		"Slot-cell depth and shadow settings affect the code-drawn background")
	var co_inset := Kit.bag_card_opts_from_config({"bag_card": {"inset": 70}})
	var inset_cell := Kit.slot_cell({"state": "empty"}, co_inset)
	var inset_dark := inset_cell.find_child("SlotCellInsetDark", true, false) as Panel
	var inset_light := inset_cell.find_child("SlotCellInsetLight", true, false) as Panel
	var inset_dark_style: StyleBox = inset_dark.get_theme_stylebox("panel") if inset_dark != null else null
	var inset_light_style: StyleBox = inset_light.get_theme_stylebox("panel") if inset_light != null else null
	ok(inset_dark != null and inset_light != null \
		and inset_dark.size == cwh and inset_light.size == cwh \
		and inset_dark.custom_minimum_size == Vector2.ZERO and inset_light.custom_minimum_size == Vector2.ZERO \
		and inset_dark_style is StyleBoxFlat and (inset_dark_style as StyleBoxFlat).border_width_top > 0 \
		and (inset_dark_style as StyleBoxFlat).border_width_left > 0 \
		and (inset_dark_style as StyleBoxFlat).border_color.a > 0.15 \
		and inset_light_style is StyleBoxFlat and (inset_light_style as StyleBoxFlat).border_width_bottom > 0 \
		and (inset_light_style as StyleBoxFlat).border_width_right > 0 \
		and (inset_light_style as StyleBoxFlat).border_color.a > 0.10, \
		"Slot-cell inset setting draws an in-cell depressed bevel without changing the cell size")
	var locked_host := Control.new()
	locked_host.custom_minimum_size = cwh
	locked_host.size = cwh
	root.add_child(locked_host)
	locked_host.add_child(locked_plain)
	await process_frame
	ok(locked_bg != null and locked_bg.get_global_rect().size == locked_plain.get_global_rect().size, \
		"the locked background stays inside the slot cell after layout")
	var unl_bg := unl.find_child("SlotCellBackground", true, false) as Control
	ok(unl.custom_minimum_size == cwh, "the unlockable slot cell owns the configured cell_w/cell_h")
	ok(unl_bg != null and unl_bg.custom_minimum_size == Vector2.ZERO, \
		"the unlockable background is paint-only and does not expand the slot cell")
	var unlockable_pop: Control = null
	for p in unl.find_children("SlotCellUnlockableHighlight", "Panel", true, false):
		unlockable_pop = p as Control
		break
	ok(unlockable_pop != null and unlockable_pop.custom_minimum_size == Vector2.ZERO, \
		"the unlockable highlight overlay is paint-only and does not expand the slot cell")
	var side_view := View.new()
	root.add_child(side_view)
	await process_frame
	side_view._selected = "bag_card"
	side_view._rebuild_sidebar()
	ok(_slider_max(side_view, "Depth") >= 24.0 and _slider_max(side_view, "Cell Shadow") >= 100.0 \
		and _slider_max(side_view, "Cell Shadow Size") >= 40.0 and _slider_min(side_view, "Cell Shadow Y") <= -20.0 \
		and _slider_max(side_view, "Inset") >= 100.0, \
		"Slot-cell sidebar exposes depth, shadow, and inset controls")
	ok(not _has_sidebar_label(side_view, "Cell art") and _slider_max(side_view, "Cell Slice") == -INF, \
		"Slot-cell sidebar hides stale art/slice controls")
	side_view.queue_free()
	# cost_y nudges the acorn-cost cluster vertically — a positive value shifts it DOWN by that many px
	var co_y := co.duplicate(); co_y["cost_y"] = 24.0
	var cost0 := (Kit.slot_cell({"state": "locked", "cost": 5}, co).find_children("*", "CenterContainer", true, false))
	var costN := (Kit.slot_cell({"state": "locked", "cost": 5}, co_y).find_children("*", "CenterContainer", true, false))
	ok(not cost0.is_empty() and not costN.is_empty(), "a cell with a cost has a cost cluster")
	ok(is_equal_approx((costN[0] as Control).offset_top - (cost0[0] as Control).offset_top, 24.0), "cost_y shifts the cost cluster down by the given pixels")
	# cost_x nudges it horizontally — a positive value shifts the cluster RIGHT by that many px
	var co_x := co.duplicate(); co_x["cost_x"] = 18.0
	var costX := (Kit.slot_cell({"state": "locked", "cost": 5}, co_x).find_children("*", "CenterContainer", true, false))
	ok(is_equal_approx((costX[0] as Control).offset_left - (cost0[0] as Control).offset_left, 18.0), "cost_x shifts the cost cluster right by the given pixels")
	# cost_scale shrinks the WHOLE cost pill (font + padding) so it FITS the card. It must shrink the real
	# FOOTPRINT (a smaller font_size + smaller min size), NOT lean on Control.scale — a CenterContainer
	# resets a managed child's scale in fit_child_in_rect, so a render scale would be silently wiped in-tree.
	var co_s := co.duplicate(); co_s["cost_scale"] = 0.6
	var btn_full := _first_button(Kit.slot_cell({"state": "locked", "cost": 5}, co))
	var btn_s := _first_button(Kit.slot_cell({"state": "locked", "cost": 5}, co_s))
	ok(btn_full != null and btn_s != null, "the cost pill is a button at any scale")
	ok(is_equal_approx(btn_s.scale.x, 1.0), "the cost pill uses NO Control.scale (a container would reset it)")
	ok(btn_s.get_theme_font_size("font_size") < btn_full.get_theme_font_size("font_size"), \
		"cost_scale shrinks the pill's font (real footprint, not a render scale)")

	# the BAG DIALOG — the shared frame + the reused pill + a grid of the slot cells.
	var entries := [
		{"kind": "filled", "icon": "leaf"}, {"kind": "empty"},
		{"kind": "next", "cost": 10}, {"kind": "locked", "cost": 15},
	]
	var bopts := Kit.bag_opts_from_config({})
	var dlg := Kit.bag_dialog(entries, 132, 560.0, bopts)
	ok(dlg is Control, "bag_dialog builds a Control")
	ok(dlg.find_child("DialogBanner", true, false) != null, "the bag dialog reuses the SHARED frame banner")
	ok(_grid_cells(dlg) == entries.size(), "the bag grid has one cell per entry (%d)" % entries.size())
	var balance_pill := dlg.find_child("GoldCurrencyPill", true, false) as Control
	ok(balance_pill != null and _pill_numbers(balance_pill) == 1, "bag_dialog renders the direct gold currency pill for the balance")
	ok(_has_label_text(dlg, "132"), "the gold currency pill shows the acorn balance (132)")

# The DISCOVERY ladder — built straight from the SHARED slot cell, with NO tier-cell component: a discovered
# tier wears the filled Slot-cell background holding its piece; an undiscovered tier uses the same
# code-drawn background (no
# acorn cost, no "?"), with a plain lower-right tier number and no level badge decoration. A marked tier
# sparkles. Asserted through the PUBLIC discovery dialog, since there is no standalone tile builder.
func _test_discovery_cell() -> void:
	var topts := Kit.tiers_opts_from_config({})
	# a tiny ladder: tier 3 discovered, tier 7 not
	var dlg := Kit.tiers_dialog([
		{"tier": 3, "seen": true, "icon": "leaf"},
		{"tier": 7, "seen": false},
	], 560.0, topts)
	ok(dlg is Control, "tiers_dialog builds the discovery ladder")

	# a DISCOVERED tier → filled Slot-cell background; an UNDISCOVERED tier → locked Slot-cell background
	ok(dlg.find_children("SlotCellBackground", "Panel", true, false).size() >= 2, \
		"discovered and undiscovered tiers both use the shared Slot-cell background")
	ok(_locked_placeholder(dlg) != null and is_equal_approx(_locked_placeholder(dlg).modulate.a, 0.30), \
		"undiscovered tiers inherit the shared locked placeholder sprite at 30% opacity")
	var tuned_cfg := {"bag_card": {"open_hue": 126, "open_sat": 78, "open_val": 52}}
	var tuned_topts := Kit.tiers_opts_from_config(tuned_cfg)
	var tuned_dlg := Kit.tiers_dialog([{"tier": 1, "seen": true, "icon": "leaf"}], 560.0, tuned_topts)
	var tuned_bg := tuned_dlg.find_child("SlotCellBackground", true, false) as Panel
	var tuned_style: StyleBox = tuned_bg.get_theme_stylebox("panel") if tuned_bg != null else null
	var expected_fill: Color = Kit.bag_card_opts_from_config(tuned_cfg).open_fill
	ok(tuned_style is StyleBoxFlat and _same_rgb((tuned_style as StyleBoxFlat).bg_color, expected_fill), \
		"tiers_dialog inherits Slot-cell background colours from bag_card settings")
	# tier cells carry a plain number, not the decorated level-badge medal.
	ok(_has_label_text(dlg, "3") and _has_label_text(dlg, "7"), "tiers_dialog shows plain tier numbers (3, 7)")
	ok(dlg.find_child("lv_num", true, false) == null, "tiers_dialog omits decorated level-badge nodes")
	ok(not _has_label_text(dlg, "?"), "the '?' cell is gone — the locked well stands in")

	# a MARKED tier (the tapped/asked one) is flagged by the engine sparkle; an unmarked ladder has none
	ok(_has_class(Kit.tiers_dialog([{"tier": 6, "seen": true, "icon": "leaf", "marked": true}], 560.0, topts), "GPUParticles2D"),
		"a marked tier is flagged by the engine sparkle")
	ok(not _has_class(Kit.tiers_dialog([{"tier": 5, "seen": true, "icon": "leaf"}], 560.0, topts), "GPUParticles2D"),
		"an unmarked ladder has no sparkle")

	# show_num off remains a compatibility path for hiding the plain tier number.
	var no_num := topts.duplicate()
	no_num["show_num"] = false
	ok(not _has_label_text(Kit.tiers_dialog([{"tier": 4, "seen": true, "icon": "leaf"}], 560.0, no_num), "4"),
		"show_num off hides the plain tier number")

# The DISCOVERY dialog uses the STANDARD shared frame, with NO bespoke chrome override: it inherits
# dialog_opts_from_config wholesale (border, banner ribbon, ✕, geometry) and adds only its CONTENT (the
# tier grid + the tier-cell look) — exactly like daily/shop. Edits on the shared Frame item flow to it.
func _test_level_badge_component(view) -> void:
	# the LAYERED level badge is a registered building block with a working preview + sidebar
	ok(view._sections.has("level_badge"), "level_badge is a registered gallery item")
	view._selected = "level_badge"
	view._params["level_badge"]["preview_level"] = 110   # final tier (the live game would show leaf+acorn+gem)
	var prev: Control = view._make_element("level_badge")
	var n := prev.find_child("lv_num", true, false) as Label
	ok(n != null and n.text == "110", "level_badge preview prints the test level (110)")
	# the preview renders ALL five parts at once so each can be positioned together
	ok(prev.find_child("lv_leaf", true, false) != null and prev.find_child("lv_flower", true, false) != null
		and prev.find_child("lv_acorn", true, false) != null and prev.find_child("lv_gem", true, false) != null
		and prev.find_child("lv_circle", true, false) != null, "the preview shows ALL parts for positioning")
	# the sidebar exposes EVERY part's X/Y/Scale at once (no dropdown), plus the number + coin controls
	view._rebuild_sidebar()
	ok(_slider_max(view, "Leaf X") >= 60.0 and _slider_max(view, "Flower X") >= 60.0
		and _slider_max(view, "Acorn X") >= 60.0 and _slider_max(view, "Gem X") >= 60.0
		and _slider_max(view, "Circle X") >= 60.0, "every part has its own X/Y/Scale sliders, all visible")
	ok(_slider_min(view, "Gem Y") <= -120.0, "Gem Y can move above the old -60 cap")
	ok(_slider_max(view, "Num Size") >= 70.0 and _slider_max(view, "Num Burn") >= 100.0,
		"sidebar exposes the number size + the engraved burn slider")
	ok(_slider_max(view, "Preview Level") >= 110.0, "sidebar exposes the test level (1..110)")
	# circle design + burn are saved config; preview_level is test-only
	ok(view._is_config("level_badge", "circle_design") and view._is_config("level_badge", "num_burn")
		and view._is_config("level_badge", "leaf_x"), "part/coin/burn knobs are saved config")
	ok(not view._is_config("level_badge", "preview_level"), "preview_level is test-only")

func _test_rush_bar_component(view) -> void:
	ok(view._sections.has("rush_bar"), "rush_bar is a registered gallery item")
	ok((view._params["rush_bar"] as Dictionary).has("burn"), "rush_bar defaults include the text burn knob")
	view._selected = "rush_bar"
	view._rebuild_sidebar()
	ok(_slider_max(view, "Burn") >= 100.0, "rush_bar sidebar exposes the engraved burn slider")
	ok(view._is_config("rush_bar", "burn"), "rush_bar burn is saved config")
	var opts := Kit.rush_bar_opts_from_config({"rush_bar": {"burn": 75}})
	ok(is_equal_approx(float(opts.get("burn", -1.0)), 0.75), "rush_bar burn config is stored as a 0..1 style value")
	var bar := Kit.rush_bar(opts, {"time": "0:58", "score": "1,250", "mult": "x2.0"})
	var score := bar.get_meta("score_label") as Label
	var caption: Label = null
	for found in bar.find_children("*", "Label", true, false):
		var l := found as Label
		if String(l.text) == "Score":
			caption = l
			break
	ok(score != null and int(score.get_theme_constant("outline_size")) > 0, \
		"rush_bar burn applies engraved styling to dynamic values")
	ok(caption != null and int(caption.get_theme_constant("outline_size")) > 0, \
		"rush_bar burn applies engraved styling to captions")

func _test_discovery_frame() -> void:
	var dopts := Kit.dialog_opts_from_config({})
	var topts := Kit.tiers_opts_from_config({})
	ok(not topts.has("banner_art"), "discovery does NOT override the banner ribbon (standard frame)")
	ok(not topts.has("close_art"), "discovery does NOT override the ✕ disc (standard frame)")
	ok(String(topts.get("border", "x")) == String(dopts.get("border", "y")),
		"discovery inherits the shared frame border (no forced twig board)")
	ok(int(topts.get("banner_font", 0)) == int(dopts.get("banner_font", -1)),
		"discovery inherits the shared frame banner font")
	ok(float(topts.get("close_size", 0)) == float(dopts.get("close_size", -1)),
		"discovery inherits the shared frame ✕ size")
	# the discovery CONTENT still differs (its own grid + tier-cell look)
	ok(topts.has("cols") and topts.has("cell_w"), "discovery still carries its own grid + cell opts")
	# and it still builds on the shared frame (the named banner overlay is present)
	var dlg := Kit.tiers_dialog(Kit.DEMO_TIERS, 620.0, topts)
	ok(dlg.find_child("DialogBanner", true, false) != null, "the discovery dialog wraps the shared frame")

func _test_rush_fx_knobs() -> void:
	var view = load("res://games/grove/tools/UiWorkbench.tscn").instantiate()
	get_root().add_child(view)
	if view.get_child_count() == 0:
		view._ready()
	# params carry every rush_fx knob, defaulted from RushFx.KNOBS
	var p: Dictionary = view._params["rush_fx"]
	for k in RushFx.KNOBS.keys():
		ok(p.has(k) and int(p[k]) == int(RushFx.KNOBS[k]), "rush_fx params include knob %s at its default" % k)
	# selecting rush_fx builds a ▶ Replay per effect + the knob sliders
	view._selected = "rush_fx"
	view._rebuild_sidebar()
	var replays: Array = view._sidebar_body.find_children("RushFxReplay_*", "Button", true, false)
	ok(replays.size() == RushFx.EFFECTS.size(), "one ▶ Replay button per effect (%d)" % RushFx.EFFECTS.size())
	var sliders: Array = view._sidebar_body.find_children("*", "HSlider", true, false)
	ok(sliders.size() == RushFx.KNOBS.size(), "one knob slider per knob (%d)" % RushFx.KNOBS.size())
	# firing one effect does not error and does not require the toggle on
	view._params["rush_fx"]["merge_burst"] = false
	view._rush_fx_play("merge_burst")
	ok(true, "per-effect replay fires without error even when the effect toggle is off")
	view.queue_free()

## The FOUR feel-verb gallery components (land/merge/launch/move): params carry the registry defaults,
## the preview stage builds + stores its ctx, the sidebar builds, and the play function fires clean.
func _test_feel_fx() -> void:
	var view = load("res://games/grove/tools/UiWorkbench.tscn").instantiate()
	get_root().add_child(view)
	if view.get_child_count() == 0:
		view._ready()
	var registries := {"land_fx": LandFx, "merge_fx": MergeFx, "launch_fx": LaunchFx, "move_fx": MoveFx}
	for id in ["land_fx", "merge_fx", "launch_fx", "move_fx"]:
		var reg = registries[id]
		var p: Dictionary = view._params[id]
		# every registry key (enabled + effect toggles + knobs) is present so from_config reads it back
		for k in reg.defaults().keys():
			ok(p.has(k), "%s params include the registry key %s" % [id, k])
		# the preview stage builds and stores its ctx (so the play function has its node refs)
		var prev: Control = view._make_element(id)
		ok(prev != null, "%s preview stage builds" % id)
		var ctx: Dictionary = view.get("_%s_ctx" % id)
		ok(not ctx.is_empty(), "%s preview stores its stage ctx" % id)
		# the sidebar builds with a master toggle + per-effect On toggles (+ a ▶ trigger button)
		view._selected = id
		view._rebuild_sidebar()
		var toggles: Array = view._sidebar_body.find_children("*", "CheckButton", true, false)
		ok(toggles.size() >= reg.EFFECTS.size() + 1, "%s sidebar has master + per-effect toggles" % id)
	# merge_fx carries the preview-only tier/combo; move_fx carries the preview-only kind — not saved
	ok(view._params["merge_fx"].has("tier") and view._params["merge_fx"].has("combo"), "merge_fx carries tier/combo")
	ok(not view._is_config("merge_fx", "tier") and not view._is_config("merge_fx", "combo"), "merge_fx tier/combo excluded from save")
	ok(view._params["move_fx"].has("kind") and not view._is_config("move_fx", "kind"), "move_fx kind is preview-only")
	# the saved block's keys are EXACTLY the registry's from_config keys (the game's read path), so the
	# saved out[id] round-trips. Every saved key is a registry default; tier/combo/kind are the only excludes.
	for id in ["land_fx", "merge_fx", "launch_fx", "move_fx"]:
		var reg2 = registries[id]
		for k in view._params[id].keys():
			# `shadow` is injected into EVERY component by _ensure_shadow_keys (like rush_fx) — from_config
			# ignores unknown keys, so it is harmless; every OTHER saved key must be a registry default.
			if view._is_config(id, k) and k != "shadow":
				ok(reg2.defaults().has(k), "%s saved key %s is a registry default (from_config reads it)" % [id, k])
	# firing each play function does not error (reads the live _params; no rebuild needed)
	view._land_fx_play()
	view._merge_fx_play()
	view._launch_fx_play()
	view._move_fx_play()
	ok(true, "all four feel-verb play functions fire without error")
	view.queue_free()
