extends SceneTree
## Headless tests for the UI workbench's SELECTIVE rebuild — editing an element rebuilds ONLY that
## element (now) plus its dependents (staggered, one per frame), never the whole 16-element gallery.
##   godot --headless -s res://games/grove/tests/grove_workbench_tests.gd

const View = preload("res://games/grove/tools/ui_workbench_view.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Pal = preload("res://games/grove/grove_palette.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# Count the currency-number labels inside a pill (one per currency pair).
func _pill_numbers(pill: Control) -> int:
	return pill.find_children("*", "Label", true, false).size()

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

	# the bag dialog + bag cell are registered gallery items, and the bag depends on the frame, the
	# bag cell, AND the currency pill — editing any of those rebuilds the bag (the §reuse wiring).
	ok(view._sections.has("bag") and view._sections.has("bag_card"), "the bag dialog + bag cell are registered gallery items")

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
	# and are SAVED config; `filled` is preview-only. Its frame borrows the shared currency-pill capsule.
	var ib: Dictionary = Kit.info_bar_opts_from_config({"info_bar": {"height": 150, "inner_scale": 60, "name_font": 28, "sep": 6, "sell_font": 24, "sell_icon": 40}})
	ok(is_equal_approx(float(ib.height), 150.0) and is_equal_approx(float(ib.inner_scale), 0.60), \
		"info_bar reads height + inner_scale (0..1)")
	ok(int(ib.name_font) == 28 and int(ib.sep) == 6 and int(ib.sell_font) == 24 and is_equal_approx(float(ib.sell_icon), 0.40), \
		"info_bar reads name_font / sep / sell_font / sell_icon")
	ok(ib.has("pill"), "info_bar borrows the shared currency-pill frame opts")
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
	var rect_shadow := Look.drop_shadow(40.0, 0.0, 10.0, 0.0, 0.0, 14.0, 0.34)
	var rect_style := rect_shadow.get_theme_stylebox("panel") as StyleBoxFlat
	ok(rect_style != null and _is_warm_shadow(rect_style.shadow_color), \
		"rect badge shadows use the warm reference shadow tint")

	var pill_style := Kit.currency_pill_style({
		"use_art": false, "shadow_alpha": 34.0, "shadow_top": 0.0, "shadow_bottom": 10.0,
		"shadow_left": 0.0, "shadow_right": 0.0, "shadow_size": 14.0
	}) as StyleBoxFlat
	ok(pill_style != null and _is_warm_shadow(pill_style.shadow_color), \
		"code-drawn currency pill shadows use the warm reference shadow tint")

	var board := Kit.board_panel(Vector2(220.0, 160.0), {"shadow_size": 14, "shadow_alpha": 34})
	var board_warm := false
	for p in board.find_children("*", "Panel", true, false):
		var sb := (p as Panel).get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null and sb.shadow_size > 0:
			board_warm = _is_warm_shadow(sb.shadow_color)
			break
	ok(board_warm, "board frame shadows use the warm reference shadow tint")

	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var with_shadow := Kit.add_drop_shadow(img, {
		"shadow_alpha": 1.0, "shadow_offset": Vector2(4.0, 4.0), "shadow_blur": 0.0, "shadow_pad": 8
	})
	ok(_is_warm_shadow(with_shadow.get_pixel(18, 18)), \
		"baked icon/badge shadows use the warm reference shadow tint")

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
	# that currency. The default call still renders the three-currency wallet (backward-compat pin).
	var one := Kit.currency_pill({"icons": [["gem", 40.0]]}, {"gem": 132})
	ok(one is Control and _pill_numbers(one) == 1, "currency_pill with one icon renders a single acorn count")
	var three := Kit.currency_pill({}, {"star": 1, "coin": 2, "gem": 3})
	ok(three is Control and _pill_numbers(three) == 3, "currency_pill default still renders the 3-currency wallet")

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
