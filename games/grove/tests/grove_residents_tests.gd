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
	finish()

func _open_spots(z: int) -> void:
	var g := Save.grove()
	if not g.has("unlocks"):
		g["unlocks"] = {}
	for sp in G.MAPS[z].spots:
		g["unlocks"][String(sp.id)] = true
	Save.grove_write()

# --- cells come ONLY from completed maps (no per-map rosters, no coin capacity sink) ---------------
func _test_cells_from_completion() -> void:
	fresh("bucket_cells")
	ok(Bucket.cells_total() == 0, "a fresh save has 0 cells")
	Bucket.hand_add("coin", 1)
	ok(not Bucket.place(0), "placement is refused before any map completes")
	_open_spots(0)
	ok(Bucket.cells_total() == int(Data.BUCKET_CELL_GRANTS[0]), "completing map 0 grants its cells")
	ok(Bucket.place(0), "placement works once completion granted cells")
	for z in G.MAPS.size():
		_open_spots(z)
	var want := 0
	for grant in Data.BUCKET_CELL_GRANTS:
		want += int(grant)
	ok(Bucket.cells_total() == want, "all five maps grant the full bucket")

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
	ok(chip != null and chip.find_child("BucketCollectBadges", true, false) != null, "the Collect chip carries per-line ready badges")
	ok(hx.content.find_child("BucketExpeditionButton", true, false) != null, "the dock exposes the Expedition entry")

	# collect through the chip: credits coins, keeps the fraction
	var coins_before := Save.coins()
	chip.pressed.emit()
	await create_timer(0.06).timeout
	ok(Save.coins() == coins_before + 3, "pressing Collect credits the coin line")
	chip = hx.content.find_child("BucketCollectChip", true, false) as Button
	ok(chip != null and chip.disabled, "after the collect the chip goes quiet (only a fraction banked)")

	# drag the hand spirit onto the cells grid → it takes a free cell
	var hand_orb := _hand_orb_at_index(hx, 0)
	cells = hx.content.find_child("BucketCellsGrid", true, false) as GridContainer
	ok(hand_orb != null and cells != null, "the place drag test has a hand orb and the grid")
	if hand_orb != null and cells != null:
		var free_cell := cells.get_child(cells.get_child_count() - 1) as Control
		_drag_select(hx, _hit_center(hand_orb), _hit_center(free_cell))
		await create_timer(0.06).timeout
		ok(Bucket.placed().size() == 2 and Bucket.hand().is_empty(), "dropping on the cells grid places into a free cell")

	# drag a placed spirit onto the hand board → it comes back out
	await create_timer(0.05).timeout
	var placed_orb := _placed_orb_at_index(hx, 1)
	var hand_grid := hx.content.find_child("HandClip", true, false) as Control
	ok(placed_orb != null and hand_grid != null, "the unplace drag test has a placed orb and the hand board")
	if placed_orb != null and hand_grid != null:
		_drag_select(hx, _hit_center(placed_orb), _hit_center(hand_grid))
		await create_timer(0.06).timeout
		ok(Bucket.placed().size() == 1 and Bucket.hand().size() == 1, "dropping a placed spirit on the hand board brings it out")
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
