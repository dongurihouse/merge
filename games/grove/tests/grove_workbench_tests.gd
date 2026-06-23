extends SceneTree
## Headless tests for the UI workbench's SELECTIVE rebuild — editing an element rebuilds ONLY that
## element (now) plus its dependents (staggered, one per frame), never the whole 16-element gallery.
##   godot --headless -s res://games/grove/tests/grove_workbench_tests.gd

const View = preload("res://games/grove/tools/ui_workbench_view.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Pal = preload("res://games/grove/grove_palette.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const Login = preload("res://engine/scripts/core/login.gd")
const LoginMystery = preload("res://engine/scripts/ui/login_mystery.gd")

var _pass := 0
var _fail := 0

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

# Like _has_label_text but for text carried on a Button (e.g. the shared pill_button cost chip).
func _has_button_text(node: Control, text: String) -> bool:
	if node is Button and String((node as Button).text) == text:
		return true
	for b in node.find_children("*", "Button", true, false):
		if String((b as Button).text) == text:
			return true
	return false

# The first Button at or under `node` (the tappable surface), or null.
func _first_button(node: Control) -> Button:
	if node is Button:
		return node as Button
	var bs := node.find_children("*", "Button", true, false)
	return bs[0] if not bs.is_empty() else null

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

# Count the slot tiles in a bag dialog's grid (the GridContainer's children).
func _grid_cells(dialog: Control) -> int:
	var grids := dialog.find_children("*", "GridContainer", true, false)
	return (grids[0] as GridContainer).get_child_count() if not grids.is_empty() else -1

# The unlockable cell's accent colour — the border colour of its highlight pop (the StyleBoxFlat panel
# with the 4px gold rim). Returns transparent if the cell carries no such pop (not unlockable).
func _unlockable_tint(node: Control) -> Color:
	for p in node.find_children("*", "Panel", true, false):
		var sb: StyleBox = (p as Panel).get_theme_stylebox("panel")
		if sb is StyleBoxFlat and (sb as StyleBoxFlat).border_width_left >= 4:
			return (sb as StyleBoxFlat).border_color
	return Color(0, 0, 0, 0)

# The unlockable highlight pop's rim drop-shadow size (px). -1 if the cell has no such pop.
func _unlockable_shadow_size(node: Control) -> int:
	for p in node.find_children("*", "Panel", true, false):
		var sb: StyleBox = (p as Panel).get_theme_stylebox("panel")
		if sb is StyleBoxFlat and (sb as StyleBoxFlat).border_width_left >= 4:
			return (sb as StyleBoxFlat).shadow_size
	return -1

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
	var view: Control = View.new()
	root.add_child(view)
	await process_frame
	await process_frame   # _ready -> _build -> _rebuild_gallery populates _sections

	ok(view._sections.size() >= 16, "gallery built: every element section registered (%d)" % view._sections.size())

	# Let the INITIAL async-polish settle before snapshotting: an element showing a raw placeholder
	# rebuilds itself once its off-thread polish lands (the _awaiting pump). If that lands mid-test it
	# would change an "unrelated" element's id for reasons unrelated to the edit under test, so drain it.
	for _i in 60:
		await process_frame
		if view._awaiting.is_empty() and view._dirty.is_empty():
			break

	# Baseline instance ids for an edited element, a dependent, and two unrelated elements.
	var before := {}
	for k in ["button", "card", "dialog", "icon", "currency_pill"]:
		before[k] = _id_of(view, k)

	# Edit the BUTTON (selected by default). Its style flows into card + every dialog; icon + pill are unrelated.
	view._selected = "button"
	view._params["button"]["font"] = 30
	view._apply_edit()

	# Immediately: the edited element is rebuilt NOW; unrelated elements are untouched.
	ok(_id_of(view, "button") != before["button"], "edited element (button) rebuilt immediately")
	ok(_id_of(view, "icon") == before["icon"], "unrelated element (icon) NOT rebuilt")
	ok(_id_of(view, "currency_pill") == before["currency_pill"], "unrelated element (currency_pill) NOT rebuilt")
	ok(view._dirty.has("card") and view._dirty.has("dialog"), "dependents queued dirty (not rebuilt synchronously)")

	# Pump frames: the staggered queue drains, rebuilding the dependents over several frames.
	for i in 12:
		await process_frame
	ok(view._dirty.is_empty(), "dirty queue drains over frames")
	ok(_id_of(view, "card") != before["card"], "dependent (card) rebuilt after pumping")
	ok(_id_of(view, "dialog") != before["dialog"], "dependent (dialog) rebuilt after pumping")
	ok(_id_of(view, "icon") == before["icon"], "unrelated (icon) STILL untouched after pumping")

	_test_bag_components()
	_test_discovery_cell()
	_test_discovery_frame()
	_test_board_element(view)
	_test_quest_card_config(view)
	_test_new_knobs(view)
	_test_warm_shadow_port()
	_test_mystery_preview(view)

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
	ok(view._sections.has("gold_currency_pill"), "the gold currency pill is a separate registered gallery item")
	ok(_gallery_neighbors("currency_pill", "gold_currency_pill"), \
		"gold_currency_pill sits next to the existing currency_pill component")
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
	var hud_host := Control.new()
	hud_host.custom_minimum_size = Vector2(1080, 1920)
	get_root().add_child(hud_host)
	var hud := Hud.build(hud_host, {})
	ok(hud.coins is Label, "live HUD exposes the coin amount label")
	ok(_ancestor_named(hud.coins, "GoldCurrencyPill") != null, "live HUD currency pills use the gold currency pill")
	ok(hud.coin_plus is Button, "live HUD gold currency pill exposes a real plus button")
	hud_host.queue_free()
	await process_frame

	# REGRESSION: the Slot-cell preview must DEFAULT to a non-zero cost. The cost pill only renders on a
	# locked/unlockable cell WITH a cost > 0, so a zero default leaves the cost_* sliders (font/icon/x/y/
	# scale) with no pill to act on — they look broken.
	ok(int(view._params["bag_card"]["cost"]) > 0, "the Slot-cell preview defaults to a visible cost (the cost sliders have a pill to act on)")
	ok(_has_button_text(view._make_element("bag_card"), str(int(view._params["bag_card"]["cost"]))), \
		"the default Slot-cell preview actually renders the cost pill")

	for src in ["currency_pill", "bag_card", "frame"]:
		view._selected = src
		view._dirty.clear()
		view._apply_edit()
		ok(view._dirty.has("bag"), "editing %s queues the bag to rebuild" % src)

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

# The bag-screen kit pieces: the single-acorn currency pill, the bag-cell card in each state, and the
# bag dialog (shared frame + reused pill + a grid of cells). Built directly from the kit (the same
# transform the game reads), asserting structure — pixels are a screenshot job, not here.
## The merge BOARD as a workbench element: a faithful preview (frame · shared cell well · pieces) with
## two INDEPENDENT size knobs — `scale` (zoom the whole board) and `cell` (item width; the grid grows,
## the frame stays). Both enlarge the footprint; the demo-pieces toggle is preview-only.
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

	# the bottom-bar INFO BAR element: its layout knobs are read by the resolver, default to the shipped bar,
	# and are SAVED config; `filled` is preview-only. Its frame uses the shared gold badge skin and retains
	# the shared currency-pill padding as its content margin.
	var ib: Dictionary = Kit.info_bar_opts_from_config({"info_bar": {"height": 150, "inner_scale": 60, "name_font": 28, "sep": 6, "sell_font": 24, "sell_icon": 40}})
	ok(is_equal_approx(float(ib.height), 150.0) and is_equal_approx(float(ib.inner_scale), 0.60), \
		"info_bar reads height + inner_scale (0..1)")
	ok(int(ib.name_font) == 28 and int(ib.sep) == 6 and int(ib.sell_font) == 24 and is_equal_approx(float(ib.sell_icon), 0.40), \
		"info_bar reads name_font / sep / sell_font / sell_icon")
	ok(ib.has("pill") and ib.has("badge"), "info_bar reads currency-pill padding plus the shared gold_badge frame opts")
	ok(is_equal_approx(float(Kit.info_bar_opts_from_config({}).height), 130.0), \
		"default info_bar height matches the bottom-bar wells (130)")
	ok(view._is_config("info_bar", "height") and view._is_config("info_bar", "name_font") and view._is_config("info_bar", "sell_icon"), \
		"the info-bar layout knobs are saved config")
	ok(not view._is_config("info_bar", "filled"), "the filled-vs-empty preview toggle is not saved")
	ok(_has_label_text(view._make_element("info_bar"), "Hazelnut · Tier 2"), \
		"the info-bar preview shows a sample selected item")

	# currency pill: plus_size is read, defaults to Tune.PLUS_BOX (26), is saved config, and resizes the token.
	ok(int(Kit.currency_pill_opts_from_config({"currency_pill": {"plus_size": 40}}).plus_size) == 40, \
		"currency_pill reads plus_size")
	ok(int(Kit.currency_pill_opts_from_config({}).plus_size) == 26, "default plus_size mirrors Tune.PLUS_BOX (26)")
	ok(view._is_config("currency_pill", "plus_size"), "plus_size is saved config")
	var pill44: Control = Kit.currency_pill({"show_plus": true, "plus_size": 44}, {"water": 1})
	var sized := false
	for pn in pill44.find_children("*", "Panel", true, false):
		if int((pn as Panel).custom_minimum_size.x) == 44:
			sized = true
	ok(sized, "the currency pill '+' token resizes to plus_size (44)")

	# the SIDEBAR slider panel for each edited element builds without error and emits the new sliders
	# (label rows). A typo in a _slider_row key here would otherwise only surface when a human opens the tool.
	for sel in ["home_button", "currency_pill", "info_bar"]:
		view._selected = sel
		view._rebuild_sidebar()
		ok(view._sidebar_body.get_child_count() > 0, "the %s sidebar builds its slider panel" % sel)

func _test_board_element(view) -> void:
	ok(view._sections.has("board"), "the board is a registered gallery item")
	ok(view._is_config("board", "cell") and view._is_config("board", "scale"), \
		"the item-width (cell) + scale knobs are saved design config")
	ok(not view._is_config("board", "pieces"), "the demo-pieces toggle is preview-only (not saved)")

	view._selected = "board"
	view._params["board"]["scale"] = 100
	view._params["board"]["cell"] = 50
	var base: Control = view._make_element("board")
	var w0: float = base.custom_minimum_size.x
	ok(w0 > 0.0, "the board preview reports a real footprint")

	# the CELL knob = item width: wider items grow the board (the grid, not the frame thickness)
	view._params["board"]["cell"] = 80
	ok(view._make_element("board").custom_minimum_size.x > w0, \
		"a wider item-cell grows the board footprint (item-width knob)")

	# the SCALE knob zooms the WHOLE composition, independently of cell
	view._params["board"]["cell"] = 50
	view._params["board"]["scale"] = 200
	ok(view._make_element("board").custom_minimum_size.x > w0, \
		"a larger scale zooms the whole board (scale knob)")

	# editing a board slider rebuilds just the board section (live preview)
	view._params["board"]["scale"] = 100
	view._selected = "board"
	var id0: int = _id_of(view, "board")
	view._params["board"]["cell"] = 64
	view._apply_edit()
	ok(_id_of(view, "board") != id0, "editing a board slider rebuilds the board element live")

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

# The lowest modulate alpha across the reveal CARDS (PanelContainers) in a built mystery dialog — 1.0 when
# every card is fully lit ("shown"), < 1 when the "won" state dims the non-winners.
func _min_panel_alpha(node: Control) -> float:
	var lo := 1.0
	for pc in node.find_children("*", "PanelContainer", true, false):
		lo = minf(lo, (pc as Control).modulate.a)
	return lo

# The MYSTERY spin-reveal dialog as a workbench preview (T53). It is a registered gallery item built from
# the SAME engine builder the game animates (LoginMystery.build_reveal), rendered static and DETERMINISTIC
# so the capture is repeatable. Two states: "shown" (every card lit) and "won" (winners lit, rest dimmed).
func _test_mystery_preview(view) -> void:
	ok(view._sections.has("mystery"), "the mystery spin-reveal dialog is a registered gallery item")
	ok(_gallery_neighbors("daily", "mystery"), "the mystery dialog sits next to the daily calendar in the gallery")
	ok(not view._is_config("mystery", "preview"), "the mystery preview-state picker is preview-only (not saved)")
	# the engine width rule is shared (one place) and caps the dialog at 560 on a wide viewport
	ok(is_equal_approx(LoginMystery.reveal_width(2000.0), 560.0), "the reveal width caps at 560 (shared with the live dialog)")

	# the SHARED builder returns the reveal face: a dialog, one card per option, and the caption label
	var pool: Array = Login.mystery_pool(7)
	var opts := [pool[0], pool[1], pool[2]]
	var built: Dictionary = LoginMystery.build_reveal(opts, [1], LoginMystery.reveal_width(1080.0), {"frame_cfg": view._params})
	ok(built.has("dialog") and built.has("cards") and built.has("caption"), "build_reveal returns {dialog, cards, caption}")
	ok((built["cards"] as Array).size() == opts.size(), "build_reveal makes one reveal card per option")
	(built["dialog"] as Control).queue_free()

	# the day-7 pool shows 5 distinct cards with their concrete amounts (the first card pays 200 coins)
	view._params["mystery"]["preview"] = "day 7 · shown"
	var shown: Control = view._make_element("mystery")
	ok(_has_label_text(shown, "200"), "the day-7 reveal shows a concrete reward amount (200)")
	# DETERMINISTIC: a second build renders the identical cards (the preview never shuffles)
	var shown2: Control = view._make_element("mystery")
	ok(_collect_label_set(shown) == _collect_label_set(shown2), "the mystery preview is deterministic (no shuffle between builds)")
	# "shown" lights every card; "won" dims the non-winners (the landed-winner highlight)
	ok(is_equal_approx(_min_panel_alpha(shown), 1.0), "the 'shown' state lights every reveal card")
	view._params["mystery"]["preview"] = "day 7 · won"
	var won: Control = view._make_element("mystery")
	ok(_min_panel_alpha(won) < 0.9, "the 'won' state dims the non-winning cards (winner highlight)")
	ok(_has_label_text(won, "You won!"), "the 'won' state swaps the caption to the win line")
	shown.free(); shown2.free(); won.free()
	# the OTHER pool (day 4 = 3 cards / 1 win) renders too — fewer cards, one winner, the first pays 120 coins
	view._params["mystery"]["preview"] = "day 4 · won"
	var d4: Control = view._make_element("mystery")
	ok(d4.find_children("*", "PanelContainer", true, false).size() >= Login.mystery_config(4).get("show", 0), \
		"the day-4 reveal renders its 3-card pool")
	ok(_has_label_text(d4, "120"), "the day-4 reveal shows a concrete reward amount (120)")
	d4.free()
	view._params["mystery"]["preview"] = "day 7 · won"

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

func _test_gold_badge_consumers(view) -> void:
	var prev_dirty: Dictionary = view._dirty.duplicate()
	view._dirty.clear()
	view._selected = "gold_badge"
	view._apply_edit()
	ok(view._dirty.has("board") and view._dirty.has("info_bar"), \
		"editing gold_badge queues the board frame and info bar to rebuild")
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
	# the currency pill, reused for the bag's single-acorn balance: an `icons` override renders just
	# that currency, and now resolves through the gold currency pill visual.
	var one := Kit.currency_pill({"icons": [["gem", 40.0]], "show_plus": false}, {"gem": 132})
	ok(one is PanelContainer and one.name == "GoldCurrencyPill" and _pill_numbers(one) == 1, \
		"currency_pill with one icon renders as the gold currency pill")
	var water := Kit.currency_pill({"icon": "water", "show_plus": true}, {"water": 128})
	ok(water is PanelContainer and water.name == "GoldCurrencyPill" and _has_label_text(water, "+"), \
		"currency_pill default entry point is replaced by the gold currency pill")

	# the pill's BORDER is a selectable painted capsule (PILL_BORDERS) — the workbench Border picker saves
	# "border", currency_pill_style resolves it on the ART path. The default is "gold capsule" so the shipped
	# wallet is unchanged, and EVERY registered border must resolve to a real loadable capsule art at its cap.
	ok(String(Kit.currency_pill_opts_from_config({}).border) == "gold capsule", \
		"currency_pill default border == gold capsule (shipped pill)")
	var def_sb: StyleBox = Kit.currency_pill_style(Kit.currency_pill_opts_from_config({}))
	ok(def_sb is StyleBoxTexture and (def_sb as StyleBoxTexture).texture.resource_path.ends_with("panel_pill.png"), \
		"default border resolves to the shipped panel_pill capsule")
	for bname in Kit.PILL_BORDERS.keys():
		var rec: Dictionary = Kit.PILL_BORDERS[bname]
		var sb: StyleBox = Kit.currency_pill_style({"use_art": true, "border": bname})
		ok(sb is StyleBoxTexture and (sb as StyleBoxTexture).texture != null, \
			"pill border '%s' loads its capsule art (%s)" % [bname, rec.art])
		ok(int((sb as StyleBoxTexture).get_texture_margin(SIDE_LEFT)) == int(rec.cap), \
			"pill border '%s' applies its cap (%d)" % [bname, int(rec.cap)])
	# an unknown saved border falls back to the gold capsule rather than blanking the wallet
	var bad_sb: StyleBox = Kit.currency_pill_style({"use_art": true, "border": "nope"})
	ok(bad_sb is StyleBoxTexture and (bad_sb as StyleBoxTexture).texture.resource_path.ends_with("panel_pill.png"), \
		"unknown border name falls back to the gold capsule")

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
	ok(not _has_class(Kit.slot_cell({"state": "unlockable"}, co_nohalo), "TextureRect"), "glow_size 0 removes the outer bloom halo")
	# the locked cell's lock is now the board's BAKED padlock (slot_locked) — no separate lock overlay
	ok(Kit.slot_cell({"state": "locked", "cost": 5}, co).find_child("BagLock", true, false) == null, "the locked cell uses the baked board lock (no overlay node)")
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
	ok(_has_label_text(dlg, "132"), "the reused currency pill shows the acorn balance (132)")

# The DISCOVERY ladder — built straight from the SHARED slot cell, with NO tier-cell component: a discovered
# tier wears the filled well holding its piece; an undiscovered tier the locked well (baked padlock kept, no
# acorn cost, no "?"). The tier rides the gold level medal (the reused `level` badge) docked lower-right; a
# marked tier sparkles. Asserted through the PUBLIC discovery dialog, since there is no standalone tile builder.
func _test_discovery_cell() -> void:
	var topts := Kit.tiers_opts_from_config({})
	# a tiny ladder: tier 3 discovered, tier 7 not
	var dlg := Kit.tiers_dialog([
		{"tier": 3, "seen": true, "icon": "leaf"},
		{"tier": 7, "seen": false},
	], 560.0, topts)
	ok(dlg is Control, "tiers_dialog builds the discovery ladder")

	# a DISCOVERED tier → the open (filled) slot well; an UNDISCOVERED tier → the locked well (baked padlock)
	ok(_has_slot_face(dlg, "slot_tile.png"), "a discovered tier wears the open (filled) slot well")
	ok(_has_slot_face(dlg, "slot_locked.png"), "an undiscovered tier wears the locked well (baked padlock kept)")
	# each tier reads its number on the lower-right level medal; the old "?" glyph is gone
	ok(_has_label_text(dlg, "3") and _has_label_text(dlg, "7"), "each tier reads its number on the level medal (3, 7)")
	ok(not _has_label_text(dlg, "?"), "the '?' cell is gone — the locked well stands in")

	# a MARKED tier (the tapped/asked one) is flagged by the engine sparkle; an unmarked ladder has none
	ok(_has_class(Kit.tiers_dialog([{"tier": 6, "seen": true, "icon": "leaf", "marked": true}], 560.0, topts), "GPUParticles2D"),
		"a marked tier is flagged by the engine sparkle")
	ok(not _has_class(Kit.tiers_dialog([{"tier": 5, "seen": true, "icon": "leaf"}], 560.0, topts), "GPUParticles2D"),
		"an unmarked ladder has no sparkle")

	# show_num off → no tier medal (the level badge only draws when the level is set)
	var no_num := topts.duplicate()
	no_num["show_num"] = false
	ok(not _has_label_text(Kit.tiers_dialog([{"tier": 4, "seen": true, "icon": "leaf"}], 560.0, no_num), "4"),
		"show_num off hides the tier medal")

# True if any slot-cell well in `node`'s subtree wears well art whose path ends with `suffix` (slot_tile for a
# filled/discovered tier, slot_locked for a locked/undiscovered one) — lets the test assert the discovery cell's
# state without reaching into the grid's layout.
func _has_slot_face(node: Control, suffix: String) -> bool:
	for p in node.find_children("*", "Panel", true, false):
		var sb := (p as Panel).get_theme_stylebox("panel")
		if sb is StyleBoxTexture and (sb as StyleBoxTexture).texture != null and (sb as StyleBoxTexture).texture.resource_path.ends_with(suffix):
			return true
	return false

# The DISCOVERY dialog uses the STANDARD shared frame, with NO bespoke chrome override: it inherits
# dialog_opts_from_config wholesale (border, banner ribbon, ✕, geometry) and adds only its CONTENT (the
# tier grid + the tier-cell look) — exactly like daily/shop. Edits on the shared Frame item flow to it.
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
