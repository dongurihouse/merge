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

# The first Button anywhere under `node` (the tappable surface), or null.
func _first_button(node: Control) -> Button:
	var bs := node.find_children("*", "Button", true, false)
	return bs[0] if not bs.is_empty() else null

# Count the slot tiles in a bag dialog's grid (the GridContainer's children).
func _grid_cells(dialog: Control) -> int:
	var grids := dialog.find_children("*", "GridContainer", true, false)
	return (grids[0] as GridContainer).get_child_count() if not grids.is_empty() else -1

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
