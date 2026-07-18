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
	await _test_completion_grants_gift_spirit()
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

# Grant "enough cells for this test" — completing the first building yields the first grant.
func _open_spots(_z: int) -> void:
	_build_through(Home.defs().size() - 1)   # build everything → the full bucket

# --- cells come ONLY from completed home buildings (no per-map rosters, no coin capacity sink) -------
func _test_cells_from_completion() -> void:
	fresh("bucket_cells")
	ok(Bucket.cells_total() == 0, "a fresh save has 0 cells")
	Bucket.hand_add("coin", 1)
	ok(not Bucket.place(0), "placement is refused before any building completes")
	_build_through(0)
	ok(Bucket.cells_total() == int(Home.defs()[0].cells), "completing the first building grants its cells")
	ok(Bucket.place(0), "placement works once a building granted cells")
	_build_through(Home.defs().size() - 1)
	var want := 0
	for d in Home.defs():
		want += int(d.cells)
	ok(Bucket.cells_total() == want, "completing every building grants the full bucket")

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

# --- completing a map lands its gift spirit in the bucket hand, same beat as the cells ------------
func _test_completion_grants_gift_spirit() -> void:
	fresh("bucket_completion_gift")
	var g := Save.grove()
	g["exp"] = 999999
	var unl := {}
	for i in range(G.MAPS[0].spots.size() - 1):
		unl[String(G.MAPS[0].spots[i].id)] = true          # every farm spot but the last
	g["unlocks"] = unl
	Save.grove_write()
	G.claim_unlock_reward(0)                               # consume the unlock beat (coins/gems only now)
	var hand_before := Bucket.hand().size()

	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	hx._login_shown_launch = true
	await create_timer(0.1).timeout
	hx.unlocks = unl
	hx._open_map(0)
	await create_timer(0.08).timeout
	var dummy := Control.new()
	get_root().add_child(dummy)
	await hx._on_spot_tap(0, G.MAPS[0].spots.size() - 1, dummy, Vector2(60.0, 60.0))
	await create_timer(0.05).timeout
	var h := Bucket.hand()
	ok(h.size() == hand_before + 1, "completing a map lands its gift spirit in the bucket hand")
	ok(h.size() > 0 and String(h[h.size() - 1].line) == Bucket.kind_line("ember"), "the farm's gift is its signature kind on its line")
	ok(G.claim_completion_spirit(0) == "", "the completion gift pays exactly once")
	ok(Bucket.cells_total() > 0, "the same beat grants the cells that house it")
	dummy.queue_free()
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
