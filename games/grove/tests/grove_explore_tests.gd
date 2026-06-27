extends "res://games/grove/tests/grove_test_base.gd"
## grove · explore — guards engine/scripts/core/explore.gd (the acquire model: loadout costs/cfg,
## Rush scoring, grid helpers, the box/unlocked-pool seam, and cross-scene run state). Pure-model
## coverage; the real-time Rush *feel* needs an interactive run. Active suite (in GROVE_TESTS).

const Explore = preload("res://engine/scripts/core/explore.gd")
const Habitat = preload("res://engine/scripts/core/habitat.gd")
const ExploreReward = preload("res://engine/scripts/ui/explore_reward.gd")

func _initialize() -> void:
	begin("grove · explore acquire")
	_test_loadout()
	_test_rush_lines()
	_test_scoring()
	_test_grid()
	_test_pool_and_box()
	_test_run_state()
	_test_trade_count()
	_test_slot_reel()
	_test_rush_intro_hint()
	_test_screens()
	await _test_rush_resize()
	_test_trade_reward_dialog_layout()
	_test_reward_row_cap()
	_test_loadout_uses_toggle_card_callback()
	await _test_loadout_toggle_updates_in_place()
	await _test_loadout_keeps_unaffordable_choices_visible()
	_test_rush_fx_knob_forwarding()
	finish()

# a rows×cols grid of empty cells (the Rush tile grid: null or {kind,tier})
func _grid(rows: int, cols: int) -> Array:
	var g := []
	for _r in rows:
		var row := []
		for _c in cols:
			row.append(null)
		g.append(row)
	return g

func _button_text_with_prefix(node: Control, prefix: String) -> String:
	if node is Button and String((node as Button).text).begins_with(prefix):
		return String((node as Button).text)
	for b in node.find_children("", "Button", true, false):
		var text := String((b as Button).text)
		if text.begins_with(prefix):
			return text
	return "<missing>"

func _switch_for_label(node: Control, text: String) -> Button:
	for l in node.find_children("", "Label", true, false):
		if String((l as Label).text) != text:
			continue
		var p: Node = l
		while p != null and p != node:
			if p is PanelContainer:
				for b in (p as Control).find_children("", "Button", true, false):
					if (b as Button).has_meta("on"):
						return b as Button
			p = p.get_parent()
	return null

func _card_for_label(node: Control, text: String) -> PanelContainer:
	for l in node.find_children("", "Label", true, false):
		if String((l as Label).text) != text:
			continue
		var p: Node = l
		while p != null and p != node:
			if p is PanelContainer:
				return p as PanelContainer
			p = p.get_parent()
	return null

func _button_with_text(node: Control, text: String) -> Button:
	if node is Button and String((node as Button).text) == text:
		return node as Button
	for b in node.find_children("", "Button", true, false):
		if String((b as Button).text) == text:
			return b as Button
	return null

func _source_contains(path: String, needle: String) -> bool:
	return FileAccess.get_file_as_string(path).find(needle) != -1

func _push_tap(gpos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = gpos
	down.global_position = gpos
	get_root().push_input(down, true)
	var up := down.duplicate()
	up.pressed = false
	get_root().push_input(up, true)

# --- loadout: coin cost + the Rush cfg the boosts resolve to ----------------------
func _test_loadout() -> void:
	fresh("explore_loadout")
	ok(Explore.loadout_cost({}) == 0, "an empty loadout costs nothing")
	ok(Explore.loadout_cost({"time": true, "drops": true}) == 120 + 100, "loadout cost sums the equipped boosts")

	# §1 an expedition has a DEFAULT MINIMUM cost (MIN_COST) — the acquisition coin sink — and boosts add on top.
	ok(Explore.start_cost({}) == Explore.MIN_COST, "an empty expedition still costs the default MIN_COST")
	ok(Explore.start_cost({"drops": true}) == Explore.MIN_COST + 100, "boosts add ON TOP of the base minimum")
	Save.spend(Save.coins())               # zero the wallet, then set a known balance
	Save.add_coins(300)
	ok(Explore.can_start({}), "can set off with the base minimum covered (300 ≥ 150)")
	ok(Explore.can_start({"drops": true}), "can set off when coins (300) cover base+boost (250)")
	ok(not Explore.can_start({"focus": true}), "cannot set off when base+boost (350) exceeds coins (300)")

	var base: Dictionary = Explore.rush_cfg({})
	ok(base.time == Explore.BASE_TIME, "no-boost run length is BASE_TIME")
	ok(base.spawn_mul == 1.0 and base.calm_mul == 1.0 and base.t2 == 0.0, "no-boost cfg is the neutral baseline")
	ok((base.lines as Array).size() == Explore.RUSH_LINES.size(), "all lines are in play without the focus boost")
	var full: Dictionary = Explore.rush_cfg({"time": true, "drops": true, "calm": true, "lucky": true, "focus": true})
	ok(full.time == Explore.BASE_TIME + 15.0, "the time boost adds 15s")
	ok(full.spawn_mul < 1.0, "the drops boost shortens the spawn interval")
	ok(full.calm_mul > 1.0, "the calm boost rarefies treefalls")
	ok(full.t2 > 0.0, "the lucky boost enables tier-2 drops")
	ok((full.lines as Array).size() == 2, "the focus boost restricts play to 2 lines")

# --- Rush lines: drawn from the lines the player has SEEN, 3 picked per run -------
func _test_rush_lines() -> void:
	# seen_lines derives distinct merge lines from the saved `seen` set (code = line*100 + tier).
	ok(Explore.seen_lines({}).is_empty(), "no seen items → no seen lines")
	ok(Explore.seen_lines({"101": true, "207": true, "201": true, "301": true}) == [1, 2, 3],
		"seen codes collapse to their sorted, deduped lines")
	ok(Explore.seen_lines({"7105": true}) == [71], "a seen treat line counts too (any line ever seen)")

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	# Empty pool falls back to RUSH_LINES so a brand-new player still gets a board.
	ok(Explore.pick_rush_lines([], 3, rng) == Explore.RUSH_LINES, "an empty seen pool falls back to RUSH_LINES")
	ok(Explore.pick_rush_lines([5], 3, rng) == [5], "a pool smaller than the pick count plays in full")
	var picked: Array = Explore.pick_rush_lines([1, 2, 3, 4, 5], 3, rng)
	ok(picked.size() == 3, "three lines are picked from a larger pool")
	var distinct := {}
	var all_in_pool := true
	for ln in picked:
		distinct[ln] = true
		if not [1, 2, 3, 4, 5].has(ln):
			all_in_pool = false
	ok(distinct.size() == 3 and all_in_pool, "the picked lines are distinct and all come from the pool")

	# rush_cfg threads the seen set through: 3 lines normally, 2 with the focus boost.
	var seen5 := {"101": true, "201": true, "301": true, "401": true, "501": true}
	var cfg: Dictionary = Explore.rush_cfg({}, seen5, rng)
	ok((cfg.lines as Array).size() == 3, "rush_cfg draws 3 lines from the seen pool")
	var focus_cfg: Dictionary = Explore.rush_cfg({"focus": true}, seen5, rng)
	ok((focus_cfg.lines as Array).size() == 2, "the focus boost narrows the seen draw to 2 lines")

# --- Rush scoring: non-linear value, combo, multiplier, spawn cadence -------------
func _test_scoring() -> void:
	ok(Explore.merge_base(1) == 10, "a t1 merge is worth 10 base")
	ok(Explore.merge_base(2) == 20 and Explore.merge_base(3) == 40, "base value doubles per tier (non-linear)")
	ok(Explore.merge_points(3, 2.0) == Explore.merge_base(3) * 2, "points scale by the live multiplier")

	ok(Explore.combo_after(2, 0.5) == 3, "a merge within the window climbs the combo")
	ok(Explore.combo_after(5, 2.0) == 1, "a merge after the window restarts the combo at 1")

	ok(absf(Explore.mult_after_merge(1.0, 1) - 1.12) < 0.001, "each merge nudges the multiplier up")
	ok(Explore.mult_after_merge(1.0, 4) > Explore.mult_after_merge(1.0, 1), "building a high tier bumps it more")
	ok(Explore.mult_after_merge(Explore.MULT_CAP, 4) == Explore.MULT_CAP, "the multiplier is capped at MULT_CAP")
	ok(Explore.mult_decay(2.0, 0.1, 0.0) == 2.0, "the multiplier holds steady inside the post-merge grace window")
	ok(Explore.mult_decay(2.0, 0.1, Explore.MULT_GRACE + 0.5) < 2.0, "the multiplier bleeds once the grace window passes")
	ok(absf(Explore.mult_decay(2.0, 1.0, 5.0) - (2.0 - Explore.MULT_DECAY)) < 0.001, "past the grace window it bleeds at MULT_DECAY per second")
	ok(Explore.mult_decay(1.0, 5.0, 9.0) == 1.0, "the multiplier never decays below 1")
	ok(Explore.clean_dodge_mult(1.0) > 1.0, "a clean dodge bumps the multiplier")

	ok(Explore.spawn_interval(0.0, 1.0) > Explore.spawn_interval(1.0, 1.0), "drops accelerate as the run progresses")
	ok(Explore.spawn_interval(0.0, 0.72) < Explore.spawn_interval(0.0, 1.0), "the drops boost shortens the interval")

# --- grid helpers: match, gravity, fill, fling, timber, full ---------------------
func _test_grid() -> void:
	var g := _grid(3, 3)
	g[2][0] = {"kind": "leaf", "tier": 1}
	g[2][1] = {"kind": "leaf", "tier": 1}
	ok(Explore.neighbor_match(g, 2, 0) == Vector2i(2, 1), "neighbor_match finds an adjacent same kind+tier")
	g[2][1] = {"kind": "petal", "tier": 1}
	ok(Explore.neighbor_match(g, 2, 0) == Vector2i(-1, -1), "no match when the neighbour's kind differs")
	g[2][1] = {"kind": "leaf", "tier": 2}
	ok(Explore.neighbor_match(g, 2, 0) == Vector2i(-1, -1), "no match when the neighbour's tier differs")
	# the Rush uses INTEGER line indices as kinds (RUSH_LINES = [1,2,3]); neighbor_match must handle them
	# (str(), not String() — String(int) has no constructor and crashed every tap-merge in the Rush)
	var gi := _grid(3, 3)
	gi[2][0] = {"kind": 1, "tier": 1}
	gi[2][1] = {"kind": 1, "tier": 1}
	ok(Explore.neighbor_match(gi, 2, 0) == Vector2i(2, 1), "neighbor_match matches integer (line-index) kinds")
	gi[2][1] = {"kind": 2, "tier": 1}
	ok(Explore.neighbor_match(gi, 2, 0) == Vector2i(-1, -1), "no match when integer kinds differ")

	var g2 := _grid(3, 3)
	g2[0][1] = {"kind": "leaf", "tier": 1}
	Explore.gravity(g2)
	ok(g2[2][1] != null and g2[0][1] == null, "gravity drops a floating tile to the bottom")
	ok(Explore.column_fill(g2, 1) == 1, "column_fill counts a column's tiles")

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var g3 := _grid(2, 3)
	g3[1][0] = {"kind": "leaf", "tier": 1}
	ok(Explore.fling_target(g3, 0, 1, rng) == 2, "fling_target avoids the source and the danger column")

	var g4 := _grid(3, 2)
	g4[2][0] = {"kind": "leaf", "tier": 1}
	g4[1][0] = {"kind": "leaf", "tier": 2}
	ok(Explore.timber_hits(g4, 0) == 2 and Explore.timber_hits(g4, 1) == 0, "timber_hits counts a column (0 = a clean dodge)")

	var g5 := _grid(1, 2)
	ok(not Explore.board_full(g5), "a board with an empty cell is not full")
	g5[0][0] = {"kind": "leaf", "tier": 1}
	g5[0][1] = {"kind": "leaf", "tier": 1}
	ok(Explore.board_full(g5), "board_full is true when every cell is occupied")

# --- the box seam: unlocked pool + roll ------------------------------------------
func _test_pool_and_box() -> void:
	fresh("explore_pool")
	ok(Explore.unlocked_pool({}, []).is_empty(), "the box pool is empty with no completed map")

	var z := 0
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	ok(G.can_populate(z, unl, [z]), "map 0 complete (the pool precondition)")
	var pool: Array = Explore.unlocked_pool(unl, [z])
	ok(not pool.is_empty(), "a completed map fills the box pool")
	var want := {}
	for ln in G.resident_lines(z):
		want[String(ln.id)] = true
	var all_in := true
	for k in pool:
		if not want.has(k):
			all_in = false
	ok(all_in and pool.size() == want.size(), "the pool is exactly the completed map's offered kinds")

	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	ok(pool.has(Explore.roll_kind(pool, rng)), "roll_kind returns a kind from the pool")
	ok(Explore.roll_kind([], rng) == "", "rolling an empty pool yields the empty string")

# --- run state: carried across the three scenes, score spent on boxes ------------
func _test_run_state() -> void:
	Explore.begin_run({"drops": true})
	ok(Explore.score() == 0, "a fresh run starts at score 0")
	ok(bool(Explore.run().equip.get("drops", false)), "the run carries the chosen loadout")
	Explore.add_score(250)
	ok(Explore.score() == 250, "add_score accrues the run score")

func _test_trade_count() -> void:
	ok(Explore.trade_count(0) == 0, "no score yields no spirits")
	ok(Explore.trade_count(150) == 1, "a sub-rate score still yields one spirit (min 1)")
	ok(Explore.trade_count(199) == 1, "just under the rate yields one spirit")
	ok(Explore.trade_count(200) == 1, "exactly the rate yields one spirit")
	ok(Explore.trade_count(400) == 2, "double the rate yields two spirits")
	ok(Explore.trade_count(852) == 4, "852 converts to four spirits (remainder discarded)")

func _test_slot_reel() -> void:
	var SlotReel: GDScript = load("res://engine/scripts/ui/slot_reel.gd")
	var mk := func(_sym, w: float, h: float) -> Control:
		var c := Control.new()
		c.custom_minimum_size = Vector2(w, h)
		return c
	# a built reel sits landed on its target tile
	var reel: Control = SlotReel.build_reel(["a", "b", "c"], "c", 80.0, 84.0, 0, mk, true)
	var tile_h: float = float(reel.get_meta("tile_h"))
	var n_syms: int = int(reel.get_meta("n_syms"))
	var band: Control = reel.get_meta("band")
	ok(is_equal_approx(band.position.y, -tile_h * float(n_syms - 1)), "a built reel is landed on its target tile")
	ok(bool(reel.get_meta("shine")) == true, "build_reel records the shine flag")
	# spinning zero reels lands immediately
	var fired := {"v": false}
	SlotReel.spin_reels(self, [], null, func() -> void: fired.v = true)
	ok(fired.v, "spinning zero reels fires on_all_landed at once")
	# finish() snaps every band to its landed tile and fires on_all_landed exactly once
	var host := Control.new()
	get_root().add_child(host)
	var r0: Control = SlotReel.build_reel(["a", "b"], "b", 80.0, 84.0, 0, mk, false)
	var r1: Control = SlotReel.build_reel(["a", "b"], "a", 80.0, 84.0, 1, mk, false)
	host.add_child(r0)
	host.add_child(r1)
	(r0.get_meta("band") as Control).position.y = 0.0
	(r1.get_meta("band") as Control).position.y = 0.0
	var done := {"n": 0}
	var handle: Dictionary = SlotReel.spin_reels(host, [r0, r1], null, func() -> void: done.n += 1)
	(handle["finish"] as Callable).call()
	var b0: Control = r0.get_meta("band")
	ok(is_equal_approx(b0.position.y, -float(r0.get_meta("tile_h")) * float(int(r0.get_meta("n_syms")) - 1)), "finish() snaps a reel to its landed tile")
	ok(done.n == 1, "finish() fires on_all_landed exactly once")
	host.queue_free()

# --- the rush-start teaching popup: first-3 gate + the always-on bottom hint ------
# The "Tap to Merge!" popup teaches the core verb on the player's first few rushes, then
# retires (gated on a saved counter). The fling/treefall bottom hint stays on EVERY rush.
func _test_rush_intro_hint() -> void:
	# the pure gate: shown on the first three rushes, retired from the fourth on
	ok(Explore.rush_intro_should_show(0), "the tap-to-merge popup shows on the first rush")
	ok(Explore.rush_intro_should_show(2), "the popup still shows on the third rush")
	ok(not Explore.rush_intro_should_show(3), "the popup retires once three rushes have shown it")
	ok(not Explore.rush_intro_should_show(9), "the popup stays retired beyond three")

	# the seen-counter persists in the save, defaulted to 0 on a fresh save (no migration)
	fresh("rush_intro_seen")
	ok(Save.rush_intro_seen() == 0, "a fresh save has shown the popup zero times")
	Save.mark_rush_intro_seen()
	ok(Save.rush_intro_seen() == 1, "marking the popup seen bumps the saved counter")

	# the scene wiring: the popup appears on the first three rushes and bumps the counter;
	# the bottom fling hint is present on EVERY rush regardless of the popup gate
	fresh("rush_intro_scene")
	Explore.begin_run({})
	for i in 3:
		var s = load("res://engine/scenes/ExploreRush.tscn").instantiate()
		get_root().add_child(s)
		if s.get_child_count() == 0:
			s._ready()
		ok(s.find_child("RushTapHint", true, false) != null, "rush %d shows the Tap to Merge popup" % (i + 1))
		var strip := s.find_child("RushBottomHintStrip", true, false) as Control
		var hint := s.find_child("RushBottomHint", true, false) as Label
		ok(hint != null, "rush %d shows the always-on bottom hint" % (i + 1))
		ok(hint != null and String(hint.text).to_lower().find("fling") != -1, "rush %d bottom hint explains the fling tap" % (i + 1))
		ok(strip != null and String(strip.get_meta("slice_mode", "")) == "three", \
			"rush %d bottom hint uses 3-slice art, not a 9-slice/flat panel" % (i + 1))
		ok(strip != null \
			and strip.find_child("RushBottomHintLeftCap", true, false) is TextureRect \
			and strip.find_child("RushBottomHintCenterSlice", true, false) is TextureRect \
			and strip.find_child("RushBottomHintRightCap", true, false) is TextureRect, \
			"rush %d bottom hint preserves fixed side caps with a stretchable centre" % (i + 1))
		ok(Save.rush_intro_seen() == i + 1, "rush %d bumps the intro-seen counter to %d" % [i + 1, i + 1])
		s.queue_free()
	# the fourth rush: the popup is retired, the bottom hint stays, the counter holds at 3
	var s4 = load("res://engine/scenes/ExploreRush.tscn").instantiate()
	get_root().add_child(s4)
	if s4.get_child_count() == 0:
		s4._ready()
	ok(s4.find_child("RushTapHint", true, false) == null, "the popup is gone on the fourth rush")
	ok(s4.find_child("RushBottomHint", true, false) != null, "the bottom hint stays on the fourth rush")
	ok(Save.rush_intro_seen() == 3, "a retired popup does not bump the counter further")
	s4.queue_free()

# --- the Rush screen + the reward overlay: build smoke + the score→hand seam ------
func _test_screens() -> void:
	fresh("explore_screens")
	# (Load out is now an overlay dialog on the map — map.gd::_open_expedition — not a scene.)
	for path in ["res://engine/scenes/ExploreRush.tscn"]:
		var s = load(path).instantiate()
		get_root().add_child(s)
		if s.get_child_count() == 0:        # headless -s defers _ready a frame; build it now
			s._ready()
		ok(s.get_child_count() > 0, "%s builds a non-empty tree" % String(path).get_file())
		s.queue_free()

	# the seam: opening the reward OVERLAY converts the run score DIRECTLY into hand spirits
	fresh("explore_reward_seam")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	Save.grove_write()
	Explore.begin_run({})
	Explore.add_score(400)                          # 400 / 200 = 2 spirits
	var pool: Array = Explore.unlocked_pool(unl, [z])
	var hand_before := Habitat.hand().size()
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	ExploreReward.open(host, {"on_done": func() -> void: pass})
	ok(Habitat.hand().size() == hand_before + 2, "opening the reward overlay grants floor(score / RATE) spirits to the hand")
	var last: Dictionary = Habitat.hand()[Habitat.hand().size() - 1]
	ok(pool.has(String(last.kind)), "a granted spirit's kind comes from the unlocked pool")
	ok(int(last.tier) >= 1 and int(last.tier) <= 4, "a granted spirit rolls a generator tier (1–4)")
	ok(host.find_child("ExploreRewardOverlay", true, false) != null, "the reward mounts as a modal overlay (not a separate scene)")
	ok(host.find_child("RewardDialog", true, false) != null, "the reward uses the shared framed dialog")
	var grid := host.find_child("RewardReels", true, false)
	ok(grid != null and grid.get_child_count() == 2, "the reveal builds one reel per granted spirit")
	var piglet_icon: Control = ExploreReward._spirit_icon("piglet", 72.0)
	ok(piglet_icon.find_child("SpiritEye0", true, false) != null and piglet_icon.find_child("SpiritEye1", true, false) != null,
		"an unarted spirit reveal shows placeholder face details instead of a blank disc")
	host.queue_free()


# S-RESIZE: the Rush screen must re-fit on a live viewport resize (drag the window wider / rotate), like the
# home map and the board action bar — it was built once from the startup size and stayed pinned. Drive two
# known widths and assert the board re-centres + re-fits, the activity bar tracks the width, and the bottom
# hint follows (deferred one-frame coalesce → wait two frames). Also guards the treefall warning toggle.
func _test_rush_resize() -> void:
	fresh("rush_resize")
	Explore.begin_run({})
	var s = load("res://engine/scenes/ExploreRush.tscn").instantiate()
	get_root().add_child(s)
	if s.get_child_count() == 0:
		s._ready()
	# let the engine run the in-tree _ready (it connects size_changed — the manual one above ran out of tree)
	await create_timer(0.06).timeout
	get_root().size = Vector2i(1080, 1920)
	await create_timer(0.06).timeout
	await create_timer(0.06).timeout
	var cx1080: float = s._board.position.x + s._board.size.x * 0.5
	var bx1080: float = s._board.position.x
	ok(absf(cx1080 - 540.0) < 3.0, "S-RESIZE: the rush board re-centres to the 1080 width (cx=%.0f)" % cx1080)
	ok(s._board.position.x + s._board.size.x <= 1082.0, "S-RESIZE: the board fits within the 1080 width")
	ok(absf(s._activity.size.x - 1080.0 * 0.9) < 3.0, "S-RESIZE: the activity bar tracks the 1080 width (w=%.0f)" % s._activity.size.x)
	get_root().size = Vector2i(1600, 1920)
	await create_timer(0.06).timeout
	await create_timer(0.06).timeout
	var cx1600: float = s._board.position.x + s._board.size.x * 0.5
	ok(absf(cx1600 - 800.0) < 3.0, "S-RESIZE: the rush board re-centres on a live resize to 1600 (cx=%.0f)" % cx1600)
	ok(s._board.position.x + s._board.size.x <= 1602.0, "S-RESIZE: the re-fitted board fits within the 1600 width")
	ok(absf(s._activity.size.x - 1600.0 * 0.9) < 3.0, "S-RESIZE: the activity bar re-fits to the new width (w=%.0f)" % s._activity.size.x)
	ok(absf(s._board.position.x - bx1080) > 10.0, "S-RESIZE: the board actually moved on the resize (not pinned to the old width)")
	ok(s._hint != null and absf((s._hint.position.x + s._hint.size.x * 0.5) - 800.0) < 8.0, "S-RESIZE: the bottom hint re-centres to the new width")
	var hint_label := s._hint.find_child("RushBottomHint", true, false) as Label if s._hint != null else null
	var hint_label_delta := 0.0
	if hint_label != null:
		hint_label_delta = (hint_label.position.y + hint_label.size.y * 0.5) - s._hint.size.y * 0.5
	ok(hint_label != null and hint_label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER \
		and hint_label_delta >= 3.0 and hint_label_delta <= 5.5, \
		"S-RESIZE: the bottom hint compensates font ink centering (delta=%.1f)" % hint_label_delta)
	var bottom_gap: float = 1920.0 - (s._hint.position.y + s._hint.size.y) if s._hint != null else 0.0
	ok(bottom_gap >= 1920.0 * 0.05 - 1.0, "S-RESIZE: the bottom hint clears the bottom edge by 5%% (gap=%.0f)" % bottom_gap)
	# the treefall telegraph flips the activity bar to its warning state (and aims the chevron)
	s._tf = {"ph": "tele", "t": 0.0, "col": 3, "next": 9.0}
	s._apply_treefall_visual()
	ok(s._act_warn.visible and not s._act_idle.visible, "S-RESIZE: telegraphing a treefall shows the warning strip, hides the idle rail")
	s._tf = {"ph": "idle", "t": 0.0, "col": 0, "next": 9.0}
	s._apply_treefall_visual()
	ok(s._act_idle.visible and not s._act_warn.visible, "S-RESIZE: clearing the treefall returns to the idle rail")
	get_root().size = Vector2i(1080, 1920)
	await create_timer(0.06).timeout
	s.queue_free()
	await create_timer(0.05).timeout

func _test_trade_reward_dialog_layout() -> void:
	fresh("reward_overlay_layout")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	Save.grove_write()
	Explore.begin_run({})
	Explore.add_score(800)                          # 800 / 200 = 4 reels
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	ExploreReward.open(host, {"on_done": func() -> void: pass})
	ok(host.find_child("RewardDialog", true, false) != null, "the reward mounts the shared framed dialog on the board")
	var grid := host.find_child("RewardReels", true, false)
	ok(grid != null and grid.get_child_count() == 4, "an 800-point run reveals four reels")
	host.queue_free()

# a huge haul is row-capped: only MAX_ROWS rows reveal, the rest fold into a "+N more" tile — but every
# granted spirit still lands in the hand (the reveal is cosmetic).
func _test_reward_row_cap() -> void:
	fresh("reward_row_cap")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	Save.grove_write()
	Explore.begin_run({})
	Explore.add_score(6000)                         # 6000 / 200 = 30 spirits — well past the row cap
	var hand_before := Habitat.hand().size()
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	ExploreReward.open(host, {"on_done": func() -> void: pass})
	ok(Habitat.hand().size() == hand_before + 30, "every granted spirit lands in the hand even past the reveal cap")
	var grid := host.find_child("RewardReels", true, false) as GridContainer
	ok(grid != null, "the reveal grid is built")
	ok(grid.get_child_count() <= 4 * ExploreReward.MAX_ROWS, "the reveal never exceeds the row cap (≤ 4 × MAX_ROWS cells)")
	ok(grid.get_child_count() == grid.columns * ExploreReward.MAX_ROWS, "a big haul fills exactly the capped rows")
	ok(host.find_child("RewardMore", true, false) != null, "the overflow folds into a +N more tile")
	host.queue_free()

func _test_loadout_uses_toggle_card_callback() -> void:
	var map_src := "res://engine/scripts/scenes/map.gd"
	ok(_source_contains(map_src, "\"on_toggle\": make_loadout_toggle.call(id)"),
		"loadout rows use toggle_card's on_toggle callback as the single toggle path")
	ok(not _source_contains(map_src, "sw.pressed.connect(on_switch_pressed"),
		"loadout rows do not add a second switch pressed handler")

func _test_loadout_toggle_updates_in_place() -> void:
	fresh("explore_loadout_overlay")
	Save.spend(Save.coins())
	Save.add_coins(1000)
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_expedition()
	await process_frame
	var overlay := map.get_node_or_null("ExpeditionOverlay") as Control
	ok(overlay != null, "the map opens the expedition loadout overlay")
	if overlay == null:
		map.queue_free()
		await process_frame
		return
	var cc := overlay.get_child(1) as CenterContainer
	var dialog_before := cc.get_child(0) as Control
	var sw: Button = _switch_for_label(dialog_before, "Lantern")
	ok(sw != null, "the Lantern loadout row has a switch to toggle")
	if sw == null:
		map.queue_free()
		await process_frame
		return
	ok(sw.get_global_rect().size.x > 0.0 and sw.get_global_rect().size.y > 0.0,
		"the Lantern switch has a real hit rect")
	_push_tap(_hit_center(sw))
	await process_frame
	ok(cc.get_child_count() == 1, "toggling a boost does not queue a replacement dialog")
	ok(cc.get_child(0) == dialog_before, "the same loadout dialog instance remains after a toggle")
	var cost_after := _button_text_with_prefix(dialog_before, "Cost")
	ok(cost_after == "Cost 270", "the total cost chip updates in place after toggling Lantern (%s)" % cost_after)
	ok(bool(sw.get_meta("on")), "a real tap leaves the Lantern switch on after an affordable toggle")
	_push_tap(_hit_center(sw))
	await process_frame
	ok(not bool(sw.get_meta("on")), "a second real tap toggles Lantern back off")
	var cost_off := _button_text_with_prefix(dialog_before, "Cost")
	ok(cost_off == "Cost 150", "the total cost chip returns to base cost after toggling Lantern off (%s)" % cost_off)
	var card := _card_for_label(dialog_before, "Lantern")
	ok(card != null, "the Lantern loadout row has a mail-style card tap target")
	if card != null:
		_push_tap(_hit_center(card))
		await process_frame
		ok(is_instance_valid(dialog_before), "tapping the loadout row keeps the dialog open")
		if is_instance_valid(dialog_before):
			ok(bool(sw.get_meta("on")), "tapping the mail-style row toggles Lantern on")
			var row_cost := _button_text_with_prefix(dialog_before, "Cost")
			ok(row_cost == "Cost 270", "row-tapping Lantern updates the total cost (%s)" % row_cost)
	await process_frame
	ok(cc.get_child_count() == 1 and cc.get_child(0) == dialog_before, "the original loadout dialog survives the next frame")
	map.queue_free()
	await process_frame

func _test_loadout_keeps_unaffordable_choices_visible() -> void:
	fresh("explore_loadout_unaffordable")
	Save.spend(Save.coins())
	Save.add_coins(300)
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_expedition()
	await process_frame
	var overlay := map.get_node_or_null("ExpeditionOverlay") as Control
	ok(overlay != null, "the low-wallet loadout overlay opens")
	if overlay == null:
		map.queue_free()
		await process_frame
		return
	var cc := overlay.get_child(1) as CenterContainer
	var dialog := cc.get_child(0) as Control
	var focus_sw: Button = _switch_for_label(dialog, "Focus totem")
	var go := _button_with_text(dialog, "Set off")
	ok(focus_sw != null, "the Focus totem row has a switch")
	ok(go != null, "the loadout dialog has a Set off button")
	if focus_sw == null or go == null:
		map.queue_free()
		await process_frame
		return
	_push_tap(_hit_center(focus_sw))
	await process_frame
	var cost_after := _button_text_with_prefix(dialog, "Cost")
	ok(bool(focus_sw.get_meta("on")), "an unaffordable boost still stays visibly selected")
	ok(cost_after == "Cost 350", "the total cost still shows the selected unaffordable boost (%s)" % cost_after)
	ok(go.disabled, "Set off is disabled while the selected total exceeds the wallet")
	_push_tap(_hit_center(focus_sw))
	await process_frame
	var cost_off := _button_text_with_prefix(dialog, "Cost")
	ok(not bool(focus_sw.get_meta("on")), "tapping the unaffordable boost again turns it off")
	ok(cost_off == "Cost 150", "turning it off returns to the base cost (%s)" % cost_off)
	ok(not go.disabled, "Set off is re-enabled once the selected total is affordable")
	map.queue_free()
	await process_frame

func _test_rush_fx_knob_forwarding() -> void:
	# the resolved opts the scene reads carry the knobs (overrides honoured)
	var RushFx = load("res://engine/scripts/ui/rush_fx.gd")
	var opts: Dictionary = RushFx.from_config({"rush_fx": {"treefall_shake": 33}})
	ok(RushFx.knob(opts, "treefall_shake") == 33, "from_config carries a saved knob the scene can read")
	# each gated call site forwards a knob value (guards the wiring without a live grid).
	# merge_burst_count is no longer forwarded by the live scene — the merge burst routes through
	# Feel.merge now (merge_burst stays a workbench-preview-only effect), so it is not in this list.
	var src := FileAccess.get_file_as_string("res://engine/scripts/scenes/explore_rush.gd")
	for needle in [
		"RushFx.knob(_fx, \"score_tick_ms\")",
		"RushFx.knob(_fx, \"score_pulse_pct\")",
		"RushFx.knob(_fx, \"mult_pop_pct\")",
		"RushFx.knob(_fx, \"combo_heat_size\")",
		"RushFx.knob(_fx, \"timer_low_secs\")",
		"RushFx.knob(_fx, \"treefall_debris\")",
		"RushFx.knob(_fx, \"treefall_shake\")",
		"RushFx.knob(_fx, \"treefall_hitstop_ms\")",
	]:
		ok(src.find(needle) != -1, "explore_rush forwards %s" % needle)
	# the merge impact now routes through the unified verb (gate 2 keeps low-combo merges snappy)
	ok(src.find("Feel.merge(self, node, ctr, int(win.tier), _combo, 1.0, 2)") != -1, "explore_rush routes the merge through Feel.merge (gate 2)")
	ok(src.find("RushFx.merge_burst(") == -1, "explore_rush no longer calls RushFx.merge_burst in the live merge")
