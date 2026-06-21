extends SceneTree
## Headless tests for the UI workbench's SELECTIVE rebuild — editing an element rebuilds ONLY that
## element (now) plus its dependents (staggered, one per frame), never the whole 16-element gallery.
##   godot --headless -s res://games/grove/tests/grove_workbench_tests.gd

const View = preload("res://games/grove/tools/ui_workbench_view.gd")
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

# Count the currency-number labels inside a pill (one per currency pair).
func _pill_numbers(pill: Control) -> int:
	return pill.find_children("*", "Label", true, false).size()

# True if any Label in `node`'s subtree has exactly `text`.
func _has_label_text(node: Control, text: String) -> bool:
	for l in node.find_children("*", "Label", true, false):
		if String((l as Label).text) == text:
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

	# the bag dialog + bag cell are registered gallery items, and the bag depends on the frame, the
	# bag cell, AND the currency pill — editing any of those rebuilds the bag (the §reuse wiring).
	ok(view._sections.has("bag") and view._sections.has("bag_card"), "the bag dialog + bag cell are registered gallery items")
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
	# the next (buyable) + locked tiles carry their acorn cost number
	ok(_has_label_text(Kit.bag_card({"kind": "next", "cost": 10}, co), "10"), "the next tile shows its acorn cost (10)")
	ok(_has_label_text(Kit.bag_card({"kind": "locked", "cost": 25}, co), "25"), "a locked tile shows its acorn cost (25)")
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
	# the locked cell's lock is now the board's BAKED padlock (slot_locked) — no separate lock overlay
	ok(Kit.slot_cell({"state": "locked", "cost": 5}, co).find_child("BagLock", true, false) == null, "the locked cell uses the baked board lock (no overlay node)")

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

# The DISCOVERY (tier) cell — now the SHARED slot cell: a discovered tier wears the filled well holding its
# piece; an undiscovered tier wears the locked well (the baked padlock kept, no acorn cost, no "?"). The
# tier rides the gold level medal (the reused `level` badge) docked lower-right; a marked tier sparkles.
func _test_discovery_cell() -> void:
	var to := Kit.tiers_card_opts_from_config({})

	# a DISCOVERED tier → the open (filled) slot well, holding its piece, tier on the lower-right medal
	var seen_cell := Kit.tiers_card({"tier": 3, "seen": true, "icon": "leaf"}, to)
	ok(seen_cell is Control, "tiers_card builds a discovered tile")
	ok(_slot_face_tex(seen_cell).ends_with("slot_tile.png"), "a discovered tier wears the open (filled) slot well")
	ok(_has_label_text(seen_cell, "3"), "the discovered tier's number reads on the level medal (3)")

	# an UNDISCOVERED tier → the locked well (slot_locked, baked padlock kept), no "?", tier still shown
	var unseen_cell := Kit.tiers_card({"tier": 7, "seen": false}, to)
	ok(_slot_face_tex(unseen_cell).ends_with("slot_locked.png"), "an undiscovered tier wears the locked well (baked padlock kept)")
	ok(not _has_label_text(unseen_cell, "?"), "the '?' cell is gone — the locked well stands in")
	ok(_has_label_text(unseen_cell, "7"), "an undiscovered tier still reads its tier number (7)")

	# a MARKED tier (the tapped/asked one) keeps the engine sparkle; an unmarked one has none
	ok(_has_class(Kit.tiers_card({"tier": 6, "seen": true, "icon": "leaf", "marked": true}, to), "GPUParticles2D"),
		"a marked tier is flagged by the engine sparkle")
	ok(not _has_class(Kit.tiers_card({"tier": 5, "seen": true, "icon": "leaf"}, to), "GPUParticles2D"),
		"an unmarked tier has no sparkle")

	# show_num off → no tier medal (the level badge only draws when the level is set)
	var no_num_opts := to.duplicate()
	no_num_opts["show_num"] = false
	ok(not _has_label_text(Kit.tiers_card({"tier": 4, "seen": true, "icon": "leaf"}, no_num_opts), "4"),
		"show_num off hides the tier medal")

# The face texture path on a slot-cell tile (its first Panel with a StyleBoxTexture "panel"), so the test
# can assert which well art — slot_tile (filled) vs slot_locked (locked) — the discovery cell is wearing.
func _slot_face_tex(cell: Control) -> String:
	for p in cell.find_children("*", "Panel", true, false):
		var sb := (p as Panel).get_theme_stylebox("panel")
		if sb is StyleBoxTexture and (sb as StyleBoxTexture).texture != null:
			return (sb as StyleBoxTexture).texture.resource_path
	return ""
