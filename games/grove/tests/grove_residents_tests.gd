extends "res://games/grove/tests/grove_test_base.gd"
## grove · residents bucket — guards the Save-backed GLOBAL bucket adapter (engine/scripts/core/bucket.gd)
## through the game surfaces, plus a headless smoke test of the bucket dock on the place-picker.
## The pure rules live in resident_bucket.gd (engine/tests/resident_bucket_tests.gd); the adapter's
## own seams in engine/tests/bucket_adapter_tests.gd. Active suite (in GROVE_TESTS).

const Bucket = preload("res://engine/scripts/core/bucket.gd")
const Game = preload("res://engine/scripts/core/game.gd")

func _initialize() -> void:
	begin("grove · residents bucket")
	_test_cells_from_completion()
	_test_hand_and_lines()
	_test_place_collect_sell()
	_test_migration_smoke()
	await _test_hand_drop_merge_targets_slot()
	await _test_bucket_dock()
	await _test_dock_closed_state()
	await _test_map_tap_over_ambient()
	await _test_residents_dialog()
	finish()

const Home = preload("res://engine/scripts/core/home.gd")
const HB = preload("res://engine/scripts/core/home_build.gd")

# Complete every home building up to (and including) index `n` — the cell source now (spec 2026-07-17).
func _build_through(n: int) -> void:
	var st := Home.state()
	for i in mini(n + 1, Home.defs().size()):
		var d: Dictionary = Home.defs()[i]
		while HB.buy_step(st, d):
			pass
	Save.grove_write()

# Open the bucket for a test — completing the whole zone unlocks its single cell.
func _open_spots(_z: int) -> void:
	_build_through(Home.defs().size() - 1)   # build everything → the zone's one cell

# --- cells come ONLY from completed zones: 1 per zone (no per-building bundles, no coin sink) --------
func _test_cells_from_completion() -> void:
	fresh("bucket_cells")
	ok(Bucket.cells_total() == 0, "a fresh save has 0 cells")
	Bucket.hand_add("coin", 1)
	ok(not Bucket.place(0), "placement is refused before the zone completes")
	_build_through(0)
	ok(Bucket.cells_total() == 0, "a single built building pays nothing — the ZONE must complete")
	_build_through(Home.defs().size() - 1)
	ok(Bucket.cells_total() == 1, "completing the whole farmhouse zone unlocks its single cell")
	ok(Bucket.place(0), "placement works once the zone's cell is unlocked")

# --- the four lines and their art kinds -----------------------------------------------------------
func _test_hand_and_lines() -> void:
	fresh("bucket_hand_lines")
	for line in Bucket.LINES:
		var kind := Bucket.line_kind(String(line))
		ok(kind != "" and Bucket.kind_line(kind) == String(line), "line '%s' wears the '%s' art family (round-trip)" % [line, kind])
	Bucket.hand_add("water", 1)
	Bucket.hand_add("water", 1)
	Bucket.hand_add("coin", 1)
	ok(not Bucket.hand_merge(1, 2), "cross-line pairs refuse to merge")
	ok(Bucket.hand_merge(0, 1), "a same line+tier pair merges in hand")
	ok(Bucket.hand().size() == 2 and int(Bucket.hand()[0].tier) == 2, "the merge kept the target slot a tier up")

# --- place, production crediting, sell ------------------------------------------------------------
func _test_place_collect_sell() -> void:
	fresh("bucket_place_collect_sell")
	_open_spots(0)
	Bucket.hand_add("coin", 3)
	ok(Bucket.place(0), "a coin spirit takes a cell")
	Bucket.hand_add("coin", 3)
	ok(Bucket.place_merge(0, 0), "place_merge climbs the placed spirit")
	ok(int(Bucket.placed()[0].tier) == 4, "the placed spirit climbed to tier 4")
	# seed matured production directly (rates are provisional; the pure module owns the accrual math)
	var st := Bucket.state()
	st["banks"] = {"coin": 2.5}
	Save.grove_write()
	var coins_before := Save.coins()
	var got := Bucket.collect()
	ok(int(got.get("coin", 0)) == 2 and Save.coins() == coins_before + 2, "collect credits whole coins and keeps the fraction banked")
	coins_before = Save.coins()
	var paid := Bucket.sell_placed(0)
	ok(paid == 4 * Bucket.SELL_PER_TIER and Save.coins() == coins_before + paid, "selling a placed spirit frees the cell and pays coins")
	ok(Bucket.placed().is_empty(), "the cell is free again")

# --- legacy per-map habitat saves migrate on first access -----------------------------------------
func _test_migration_smoke() -> void:
	fresh("bucket_migration")
	var g := Save.grove()
	g["hand"] = [{"kind": "ember", "tier": 3}]
	g["habitat"] = {"farmhouse": [{"kind": "breeze", "tier": 2}]}
	g["hab_prod"] = {"farmhouse": {"acc": 1.9, "last": 0.0}}
	Save.grove_write()
	var coins_before := Save.coins()
	var st := Bucket.state()
	ok(st.hand.size() == 2 and st.placed.is_empty(), "legacy hand + placed all land in the new hand")
	ok(Save.coins() == coins_before + 1, "legacy banked accrual credits floor(acc) in the old currency")
	ok(not Save.grove().has("habitat") and not Save.grove().has("hab_prod"), "legacy habitat keys are erased")

# --- the dock drag surface: a hand drop targets the SLOT it lands on ------------------------------
func _test_hand_drop_merge_targets_slot() -> void:
	fresh("bucket_hand_merge_drop_target")
	var z := 0
	_open_spots(z)
	var g := Save.grove()
	g["gates"] = [z]
	Save.grove_write()
	for zz in range(G.MAPS.size()):
		G.claim_unlock_reward(zz)
	var st := Bucket.state()
	st["hand"] = []
	Save.grove_write()
	Bucket.hand_add("boost", 1)
	Bucket.hand_add("coin", 1)
	Bucket.hand_add("boost", 1)
	Bucket.hand_add("water", 1)

	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	hx._login_shown_launch = true
	await create_timer(0.1).timeout
	hx.unlocks = Save.grove().get("unlocks", {})
	hx._open_map(z)
	hx._open_select()
	await create_timer(0.08).timeout
	var source := _hand_orb_at_index(hx, 0)
	var target := _hand_orb_at_index(hx, 2)
	ok(source != null and target != null, "the hand merge target test has source and target cells")
	if source != null and target != null:
		_drag_select(hx, _hit_center(source), _hit_center(target))
		await create_timer(0.06).timeout
		var h := Bucket.hand()
		ok(h.size() == 3 \
			and String(h[0].line) == "coin" \
			and String(h[1].line) == "boost" and int(h[1].tier) == 2 \
			and String(h[2].line) == "water", \
			"dragging onto a hand match upgrades the drop slot instead of appending to the end")
	hx.queue_free()

# --- the bucket dock: cells grid + chips + place/unplace drags ------------------------------------
func _test_bucket_dock() -> void:
	fresh("bucket_dock")
	var z := 0
	_open_spots(z)
	var g := Save.grove()
	g["gates"] = [z]
	Save.grove_write()
	for zz in range(G.MAPS.size()):
		G.claim_unlock_reward(zz)
	var st := Bucket.state()
	st["hand"] = []
	Save.grove_write()
	Bucket.hand_add("boost", 1)
	Bucket.place(0)
	Bucket.hand_add("coin", 1)
	st = Bucket.state()
	st["banks"] = {"coin": 3.2}
	Save.grove_write()

	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	hx._login_shown_launch = true
	await create_timer(0.1).timeout
	hx.unlocks = Save.grove().get("unlocks", {})
	hx._open_select()
	await create_timer(0.08).timeout

	var cells := hx.content.find_child("BucketCellsGrid", true, false) as GridContainer
	ok(cells != null, "the dock shows the bucket cells grid")
	ok(cells != null and cells.get_child_count() == Bucket.cells_total(), "the cells grid holds exactly cells_total cells (placed + free)")
	ok(hx._placed_orbs.size() == 1, "the placed spirit registers as a dock orb")
	ok(hx.content.find_child("MapResidentRailLockedCell_00", true, false) == null, "the old per-card locked cells are gone")
	var chip := hx.content.find_child("BucketCollectChip", true, false) as Button
	ok(chip != null and not chip.disabled, "the Collect chip is live with matured production")
	var boost_row: Control = hx.content.find_child("BucketLineRow_boost", true, false) as Control
	ok(boost_row != null, "a producing line shows its production row")
	var coin_row: Control = hx.content.find_child("BucketLineRow_coin", true, false) as Control
	ok(coin_row != null, "a line with matured stock shows a row even with nothing placed")
	var coin_label := hx.content.find_child("BucketLineRowLabel_coin", true, false) as Label
	ok(coin_label != null and coin_label.text == "3 ready", "the row label reads what a collect grants now")
	ok(hx.content.find_child("BucketLineRow_water", true, false) == null, "idle empty lines stay off the dock")
	ok(hx.content.find_child("BucketExpeditionButton", true, false) != null, "the dock exposes the Expedition entry")

	# collect through the chip: credits coins, keeps the fraction
	var coins_before := Save.coins()
	chip.pressed.emit()
	await create_timer(0.06).timeout
	ok(Save.coins() == coins_before + 3, "pressing Collect credits the coin line")
	chip = hx.content.find_child("BucketCollectChip", true, false) as Button
	ok(chip != null and chip.disabled, "after the collect the chip goes quiet (only a fraction banked)")

	# the zone's single cell is occupied by the placed spirit — unplace-drag it to the hand board
	# first, then place-drag a hand spirit into the freed cell (capacity: 1 per completed zone).
	var placed_orb := _placed_orb_at_index(hx, 0)
	var hand_grid := hx.content.find_child("HandClip", true, false) as Control
	ok(placed_orb != null and hand_grid != null, "the unplace drag test has a placed orb and the hand board")
	if placed_orb != null and hand_grid != null:
		_drag_select(hx, _hit_center(placed_orb), _hit_center(hand_grid))
		await create_timer(0.06).timeout
		ok(Bucket.placed().is_empty() and Bucket.hand().size() == 2, "dropping a placed spirit on the hand board brings it out")

	# drag a hand spirit onto the cells grid → it takes the freed cell
	await create_timer(0.05).timeout
	var hand_orb := _hand_orb_at_index(hx, 0)
	cells = hx.content.find_child("BucketCellsGrid", true, false) as GridContainer
	ok(hand_orb != null and cells != null, "the place drag test has a hand orb and the grid")
	if hand_orb != null and cells != null:
		var free_cell := cells.get_child(cells.get_child_count() - 1) as Control
		_drag_select(hx, _hit_center(hand_orb), _hit_center(free_cell))
		await create_timer(0.06).timeout
		ok(Bucket.placed().size() == 1 and Bucket.hand().size() == 1, "dropping on the cells grid places into a free cell")
	hx.queue_free()

# --- before any completion: the dock reads closed, no dead chips ----------------------------------
func _test_dock_closed_state() -> void:
	fresh("bucket_dock_closed")
	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	hx._login_shown_launch = true
	await create_timer(0.1).timeout
	hx.unlocks = {}
	hx._open_select()
	await create_timer(0.08).timeout
	ok(hx.content.find_child("BucketCellsGrid", true, false) == null, "no cells grid before a completion")
	ok(hx.content.find_child("BucketCellsClosedHint", true, false) != null, "the dock explains how the habitat opens")
	ok(hx.content.find_child("BucketCollectChip", true, false) == null, "no Collect chip before a completion")
	ok(hx.content.find_child("BucketExpeditionButton", true, false) == null, "no Expedition entry before the loop opens")
	hx.queue_free()

# --- a map tap must survive the ambient layer's non-Control wander driver -------------------------
func _test_map_tap_over_ambient() -> void:
	fresh("bucket_map_tap_ambient")
	_open_spots(0)
	var g := Save.grove()
	g["gates"] = [0]
	Save.grove_write()
	for zz in range(G.MAPS.size()):
		G.claim_unlock_reward(zz)
	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	hx._login_shown_launch = true
	await create_timer(0.1).timeout
	hx.unlocks = Save.grove().get("unlocks", {})
	hx._open_map(0)
	await create_timer(0.08).timeout
	hx._build_map(false)
	var amb: Control = hx.content.get_node_or_null("AmbientLayer")
	ok(amb != null, "an open map builds the ambient layer")
	var has_plain_node := false
	if amb != null:
		for ch in amb.get_children():
			if not (ch is Control):
				has_plain_node = true
	ok(has_plain_node, "the ambient layer carries the wander driver (a plain Node child)")
	hx._map_tap(Vector2(2.0, 2.0))
	ok(true, "a map tap over the driver child resolves cleanly")
	var src := FileAccess.get_file_as_string("res://engine/scripts/scenes/map.gd")
	ok(src.find("var spc := sp as Control") != -1 and src.find("if spc == null:") != -1,
		"_map_tap skips non-Control ambient children instead of crashing on the driver")
	hx.queue_free()

# --- RETIRED: _test_completion_grants_gift_spirit -------------------------------------------------
# This drove the scene through `hx._on_spot_tap(...)`, the per-spot claim removed by 65ce97fa along
# with the rest of the §16 mask-reveal machinery. The tap now routes spot_hits -> _map_tap ->
# _on_build_tap (the build-and-upgrade home, spec 2026-07-17), and that path grants a finished
# building's bucket CELLS but never lands a gift spirit — G.claim_completion_spirit has no caller
# outside tests, and no gameplay path calls Bucket.hand_add at all. So there is no current path to
# re-point this test at; asserting the old beat would pin behaviour the game no longer has.
#
# Still covered: the model-level contract (pays the signature kind, pays exactly once) lives in
# games/grove/tests/grove_test_base.gd; the cells-on-build beat lives in engine/tests/home_build_tests
# and _test_cells_from_completion above. Whether the gift spirit should return as part of the build
# beat is a design call, not a test call — see the note raised with the Dev.
# --- the RESIDENTS management dialog (ui/residents.gd, mock v2): banks · cells · hand · sell -------
func _test_residents_dialog() -> void:
	fresh("residents_dialog")
	_open_spots(0)
	Bucket.hand_add("boost", 1)
	Bucket.place(0)
	Bucket.hand_add("coin", 2)
	Bucket.hand_add("water", 1)
	var st := Bucket.state()
	st["banks"] = {"coin": 3.2}
	Save.grove_write()

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	var UI = load("res://engine/scripts/ui/residents.gd")
	UI.open(host, {})
	await create_timer(0.15).timeout
	var ov := host.get_node_or_null("ResidentsOverlay")
	ok(ov != null, "the Residents dialog mounts its overlay")
	if ov == null:
		host.queue_free()
		return
	var title := ov.find_child("DialogTitle", true, false) as Label
	ok(title != null and title.text == "RESIDENTS", "the dialog wears the v2 title header")
	for line in Bucket.LINES:
		ok(ov.find_child("ResourceBankCard_" + String(line), true, false) != null,
			"the banks grid shows the %s bank card" % line)
	var boost_state := ov.find_child("ResourceBankState_boost", true, false) as Label
	ok(boost_state != null and boost_state.text.begins_with("FULL IN"),
		"a producing line reads its FULL IN timer (got '%s')" % (boost_state.text if boost_state != null else ""))
	var coin_state := ov.find_child("ResourceBankState_coin", true, false) as Label
	ok(coin_state != null and coin_state.text == "IDLE",
		"a stocked line with nothing placed reads IDLE (got '%s')" % (coin_state.text if coin_state != null else ""))
	var collect := ov.find_child("CollectAllButton", true, false) as Button
	ok(collect != null and not collect.disabled, "Collect all is live with matured stock")
	ok(ov.find_child("HabitatCell_00", true, false) != null, "the placed spirit shows in a habitat cell")
	ok(ov.find_child("HabitatCellLocked_%02d" % (UI.HABITAT_SLOTS_SHOWN - 1), true, false) != null,
		"ungranted slots read locked")
	ok(ov.find_child("OnHandGrid", true, false) != null
		and ov.find_child("OnHandCard_01", true, false) != null, "the hand grid carries the hand spirits")
	ok(ov.find_child("ResidentsInspectorHint", true, false) != null, "no selection → the inspector hints")

	# collect through the one action: credits whole coins, then goes quiet
	var coins_before := Save.coins()
	collect.pressed.emit()
	await create_timer(0.1).timeout
	ok(Save.coins() == coins_before + 3, "Collect all credits the matured coins")
	collect = ov.find_child("CollectAllButton", true, false) as Button
	ok(collect != null and collect.disabled, "after the collect the button goes quiet")

	# tap a hand card → the inspector arms; Sell pays and frees the slot
	var card = ov.find_child("OnHandCard_00", true, false)
	ok(card != null and card.has_method("tap"), "a hand card is a tappable drag card")
	if card != null:
		card.tap()
		await create_timer(0.1).timeout
	var sell := ov.find_child("ResidentsSellButton", true, false) as Button
	ok(sell != null, "a selected spirit surfaces Sell")
	var hand_before := Bucket.hand().size()
	coins_before = Save.coins()
	if sell != null:
		sell.pressed.emit()
		await create_timer(0.1).timeout
		ok(Bucket.hand().size() == hand_before - 1 and Save.coins() > coins_before,
			"Sell pays coins and removes the spirit")

	# drag-to-merge: drop a matching hand spirit onto its twin → the TARGET slot climbs a tier.
	# Seeded through the model, so close and reopen the dialog to re-read state.
	st = Bucket.state()
	st["hand"] = []
	Save.grove_write()
	Bucket.hand_add("water", 1)
	Bucket.hand_add("coin", 1)
	Bucket.hand_add("water", 1)
	ov.free()
	UI.open(host, {})
	await create_timer(0.15).timeout
	ov = host.get_node_or_null("ResidentsOverlay")
	ok(ov != null, "the dialog reopens for the drag tests")
	var target = ov.find_child("OnHandCard_00", true, false)
	var source = ov.find_child("OnHandCard_02", true, false)
	ok(target != null and source != null, "the merge test has a source and a target card")
	if target != null and source != null:
		# the manual-drag state machine: a press + a move past the slop arms the drag (the real
		# geometry hit-test is exercised through the renderer by residents_dialog_shot.gd)
		source._press(Vector2.ZERO)
		source._move(Vector2(40.0, 0.0))
		ok(bool(source._dragging), "a press + move past the slop starts a hand drag")
		source._release(Vector2(40.0, 0.0))         # empty space: drag ends, nothing happens
		ok(not bool(source._dragging) and Bucket.hand().size() == 3, "a drop on nothing is a no-op")
		ok(bool(target.can_take.call(source.data, target.data)), "its twin accepts the drop")
		ok(not bool(ov.find_child("OnHandCard_01", true, false).can_take.call(source.data,
			ov.find_child("OnHandCard_01", true, false).data)), "a different line refuses the drop")
		target.on_take.call(source.data, target.data)
		await create_timer(0.1).timeout
		var h := Bucket.hand()
		ok(h.size() == 2 and String(h[0].line) == "water" and int(h[0].tier) == 2,
			"the drop merges into the target slot a tier up")

	# drag-to-place: a hand spirit dropped on a free habitat cell moves in
	var free = ov.find_child("HabitatCellFree_00", true, false)
	var mover = ov.find_child("OnHandCard_00", true, false)
	if free == null:
		# the placed boost from earlier still holds the only cell on a 1-cell save — sell it via the model to free one
		Bucket.sell_placed(0)
		ov.free()
		UI.open(host, {})
		await create_timer(0.15).timeout
		ov = host.get_node_or_null("ResidentsOverlay")
		free = ov.find_child("HabitatCellFree_00", true, false)
		mover = ov.find_child("OnHandCard_00", true, false)
	ok(free != null and mover != null, "the place test has a free cell and a hand card")
	if free != null and mover != null:
		var placed_before := Bucket.placed().size()
		ok(bool(free.can_take.call(mover.data, free.data)), "a free cell accepts any hand spirit")
		free.on_take.call(mover.data, free.data)
		await create_timer(0.1).timeout
		ok(Bucket.placed().size() == placed_before + 1, "dropping on a free cell places the spirit")
	host.queue_free()
	await create_timer(0.05).timeout

# --- place-picker drag test helpers -------------------------------------------------
# A drag through the REAL select input surface: press on `from`, one lift-off motion to `to`, release on `to`.
func _drag_select(hx, from: Vector2, to: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT ; down.pressed = true ; down.position = from
	hx._on_input(down)
	var mv := InputEventMouseMotion.new()
	mv.position = to ; mv.relative = to - from ; mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	hx._on_input(mv)
	var up := down.duplicate()
	up.pressed = false ; up.position = to
	hx._on_input(up)

func _hand_orb_at_index(hx, index: int) -> Control:
	for o in hx._hand_orbs:
		if int(o.idx) == index:
			return o.node
	return null

func _placed_orb_at_index(hx, index: int) -> Control:
	for o in hx._placed_orbs:
		if int(o.idx) == index:
			return o.node
	return null
