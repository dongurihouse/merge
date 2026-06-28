extends "res://games/grove/tests/grove_test_base.gd"
## grove · explore — guards engine/scripts/core/explore.gd (the acquire model: loadout costs/cfg,
## Rush scoring, grid helpers, the box/unlocked-pool seam, and cross-scene run state). Pure-model
## coverage; the real-time Rush *feel* needs an interactive run. Active suite (in GROVE_TESTS).

const Explore = preload("res://engine/scripts/core/explore.gd")
const Habitat = preload("res://engine/scripts/core/habitat.gd")
const ExploreReward = preload("res://engine/scripts/ui/explore_reward.gd")
const ComboBloom = preload("res://engine/scripts/ui/combo_bloom.gd")
const Ambient = preload("res://engine/scripts/ui/ambient.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").FX

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
	await _test_home_expedition_rail_chrome()
	_test_loadout_uses_toggle_card_callback()
	await _test_loadout_toggle_updates_in_place()
	await _test_loadout_keeps_unaffordable_choices_visible()
	_test_rush_fx_knob_forwarding()
	_test_combo_bloom()
	await _test_mote_puff()
	finish()

# Bundle D: the combo screen-bloom overlay. The strength/target math is PURE (_bump_target /
# _advance / _visible_strength) so it tests without a frame loop; the scene wiring is a source check.
func _test_combo_bloom() -> void:
	# bump raises the target, scaled by the streak, never above COMBO_BLOOM_MAX.
	ok(approx(ComboBloom._bump_target(0.0, 0), 0.0), "bloom: a combo-0 bump adds nothing")
	ok(ComboBloom._bump_target(0.0, 3) > ComboBloom._bump_target(0.0, 1), "bloom: a longer streak raises the target more")
	ok(ComboBloom._bump_target(0.0, 99) <= Tune.COMBO_BLOOM_MAX + 0.0001, "bloom: the target is clamped to COMBO_BLOOM_MAX")
	ok(approx(ComboBloom._bump_target(Tune.COMBO_BLOOM_MAX, 5), Tune.COMBO_BLOOM_MAX), "bloom: already-maxed stays at the ceiling")
	# _advance eases strength TOWARD the target (rising) and never overshoots in one step.
	var s := ComboBloom._advance(0.0, Tune.COMBO_BLOOM_MAX, 0.016)
	ok(s > 0.0 and s < Tune.COMBO_BLOOM_MAX, "bloom: one ease step moves toward the target without overshooting")
	ok(ComboBloom._advance(0.2, 0.0, 0.016) < 0.2, "bloom: with target below, the live strength eases down")
	# target decays over time (no bumps) at ~COMBO_BLOOM_DECAY/sec — checked via the _process bleed math.
	ok(Tune.COMBO_BLOOM_DECAY > 0.0, "bloom: the target bleeds off when the streak lapses (decay > 0)")
	# scene wiring: both merge scenes own ONE bloom child (freed with the scene) and bump it after Feel.merge.
	var board_src := FileAccess.get_file_as_string("res://engine/scripts/scenes/board.gd")
	ok(board_src.find("ComboBloom") != -1, "board owns a ComboBloom overlay")
	ok(board_src.find("_combo_bloom.bump(combo,") != -1, "board bumps the bloom after the merge (gated + scaled by merge_fx)")
	var rush_src := FileAccess.get_file_as_string("res://engine/scripts/scenes/explore_rush.gd")
	ok(rush_src.find("ComboBloom") != -1, "rush owns a ComboBloom overlay")
	ok(rush_src.find("_combo_bloom.bump(_combo)") != -1, "rush bumps the bloom after the merge")

# Bundle D: the reactive ambient motes (Ambient.puff). Puff is a graceful
# no-op when there's no layer (Rush / weather off); the board reaches its WeatherLayer and puffs.
func _test_mote_puff() -> void:
	# the puff count is positive (motes fly) and never exceeds the base MOTE_PUFF_COUNT.
	ok(Ambient._puff_count() > 0, "puff: a merge flings at least one mote")
	ok(Ambient._puff_count() <= Tune.MOTE_PUFF_COUNT, "puff: the count never exceeds the MOTE_PUFF_COUNT base")
	# GRACEFUL no-op: a null layer must not error (Rush / weather off path).
	Ambient.puff(null, Vector2(10, 10))
	ok(true, "puff: a null ambient layer is a safe no-op (Rush / weather off)")
	# with a real layer + weather on, the puff adds a one-shot particle child that frees itself.
	var layer := Control.new()
	layer.size = Vector2(400, 400)
	get_root().add_child(layer)
	await create_timer(0.05).timeout
	var before := layer.get_child_count()
	Ambient.puff(layer, Vector2(200, 200))
	ok(layer.get_child_count() > before, "puff: a real ambient layer gains a one-shot mote burst")
	layer.queue_free()
	# scene wiring: the merge "world reaction" puff is no longer the giant Ambient.puff — it fires as the
	# merge_fx `world_puff` cue inside MergeFx.apply (a small grove-scale FX.burst). The board no longer
	# calls Ambient.puff for the merge reaction; merge_fx owns the cue + its size knob.
	var board_src := FileAccess.get_file_as_string("res://engine/scripts/scenes/board.gd")
	ok(board_src.find("Ambient.puff(") == -1, "board no longer fires the giant Ambient.puff on a merge")
	var merge_fx_src := FileAccess.get_file_as_string("res://engine/scripts/ui/merge_fx.gd")
	ok(merge_fx_src.find("world_puff") != -1, "merge_fx carries the world_puff cue (the small merge-reaction puff)")

func approx(a: float, b: float, eps := 0.0001) -> bool:
	return absf(a - b) <= eps

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

func _button_has_label(node: Button, text: String) -> bool:
	for l in node.find_children("*", "Label", true, false):
		if String((l as Label).text) == text:
			return true
	return false

func _home_chrome_button(node: Control, label: String) -> Button:
	for b in node.find_children("*", "Button", true, false):
		var btn := b as Button
		if not btn.is_visible_in_tree():
			continue
		if btn.tooltip_text == label or _button_has_label(btn, label):
			return btn
	return null

func _button_has_visible_text(btn: Button) -> bool:
	if String(btn.text).strip_edges() != "":
		return true
	for l in btn.find_children("*", "Label", true, false):
		var label := l as Label
		if label.get_parent() is PanelContainer and label.get_parent().get_parent() == btn:
			continue
		if label.is_visible_in_tree() and String(label.text).strip_edges() != "":
			return true
	return false

func _button_icon_node(btn: Button) -> Control:
	var wrap := btn.get_meta("icon_wrap", null) as Control
	if wrap == null:
		return null
	if wrap.get_child_count() == 0:
		return wrap
	return wrap.get_child(0) as Control

func _button_icon_is_centered(btn: Button) -> bool:
	var icon := _button_icon_node(btn)
	if icon == null:
		return false
	var b := btn.get_global_rect().get_center()
	var c := icon.get_global_rect().get_center()
	return absf(b.x - c.x) <= 3.0 and absf(b.y - c.y) <= 3.0

func _button_icon_is_large(btn: Button) -> bool:
	if not btn.has_meta("icon_px"):
		return false
	return float(btn.get_meta("icon_px")) >= btn.custom_minimum_size.x * 0.68

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

func _test_home_expedition_rail_chrome() -> void:
	fresh("home_expedition_rail_chrome")
	var z := G.hub_map()
	var locked_g := Save.grove()
	locked_g["unlocks"] = {}
	locked_g["gates"] = []
	locked_g["last_map"] = String(G.MAPS[z].id)
	Save.grove_write()

	var locked = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(locked)
	if locked.content == null:
		locked._ready()
	locked.unlocks = {}
	locked._open_map(z)
	await create_timer(0.05).timeout

	var locked_exp := _home_chrome_button(locked, "Expedition")
	ok(locked_exp == null, "locked map hides Expedition without leaving a visible rail button")
	var settings := _home_chrome_button(locked, "Settings")
	var daily := _home_chrome_button(locked, "Daily")
	ok(settings != null, "locked rail still shows Settings")
	ok(daily != null, "locked rail still shows Daily")
	if settings != null and daily != null:
		var y_step := daily.get_global_rect().position.y - settings.get_global_rect().position.y
		var max_packed_step := maxf(settings.get_global_rect().size.y, daily.get_global_rect().size.y) + 36.0
		ok(y_step <= max_packed_step,
			"locked rail packs Daily directly below Settings (step %.1f <= %.1f)" % [y_step, max_packed_step])
	locked.queue_free()

	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	var g := Save.grove()
	g["unlocks"] = unl
	g["gates"] = [z]
	g["last_map"] = String(G.MAPS[z].id)
	Save.grove_write()

	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	if hx.content == null:
		hx._ready()
	hx.unlocks = unl
	hx._open_map(z)
	await create_timer(0.05).timeout

	var exp := _home_chrome_button(hx, "Expedition")
	ok(exp != null, "home chrome keeps an Expedition entry point")
	if exp != null:
		var er := exp.get_global_rect()
		var vs: Vector2 = hx.get_viewport_rect().size
		ok(er.position.x > vs.x * 0.72 and er.position.y < vs.y * 0.78, "Expedition lives in the right side rail, not the bottom nav")
		ok(String(exp.get_meta("icon_id", "")) == "1512", "Expedition uses icon id 1512")

	var labels := ["Map", "Settings", "Daily", "Vault", "Expedition"]
	if _home_chrome_button(hx, "Inbox") != null:
		labels.append("Inbox")
	for label in labels:
		var btn := _home_chrome_button(hx, label)
		ok(btn != null, "%s button is present" % label)
		if btn == null:
			continue
		ok(not _button_has_visible_text(btn), "%s button has no visible text" % label)
		ok(_button_icon_is_large(btn), "%s icon fills the button footprint" % label)
		ok(_button_icon_is_centered(btn), "%s icon is centered on both axes" % label)
	hx.queue_free()

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
	var reel: Control = SlotReel.build_reel(["a", "b", "c"], "c", 80.0, 84.0, 0, mk)
	var tile_h: float = float(reel.get_meta("tile_h"))
	var n_syms: int = int(reel.get_meta("n_syms"))
	var band: Control = reel.get_meta("band")
	ok(is_equal_approx(band.position.y, -tile_h * float(n_syms - 1)), "a built reel is landed on its target tile")
	# spinning zero reels lands immediately
	var fired := {"v": false}
	SlotReel.spin_reels(self, [], null, func() -> void: fired.v = true)
	ok(fired.v, "spinning zero reels fires on_all_landed at once")
	# finish() snaps every band to its landed tile and fires on_all_landed exactly once
	var host := Control.new()
	get_root().add_child(host)
	var r0: Control = SlotReel.build_reel(["a", "b"], "b", 80.0, 84.0, 0, mk)
	var r1: Control = SlotReel.build_reel(["a", "b"], "a", 80.0, 84.0, 1, mk)
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

# --- the rush-start tutorial image: first-run gate + the always-on bottom hint ----
# The tutorial image teaches tap/merge/fling/treefall on the player's first Rush, then
# retires (gated on a saved counter). The fling/treefall bottom hint stays on EVERY rush.
func _test_rush_intro_hint() -> void:
	# the pure gate: shown on the first Rush, retired from the second on
	ok(Explore.rush_intro_should_show(0), "the Rush tutorial image shows on the first rush")
	ok(not Explore.rush_intro_should_show(1), "the Rush tutorial image retires after the first showing")
	ok(not Explore.rush_intro_should_show(9), "the Rush tutorial image stays retired after that")

	# the seen-counter persists in the save, defaulted to 0 on a fresh save (no migration)
	fresh("rush_intro_seen")
	ok(Save.rush_intro_seen() == 0, "a fresh save has shown the tutorial zero times")
	Save.mark_rush_intro_seen()
	ok(Save.rush_intro_seen() == 1, "marking the tutorial seen bumps the saved counter")

	# the scene wiring: the image tutorial appears on the first Rush and bumps the counter;
	# the bottom hint + replay info button stay on every Rush.
	fresh("rush_intro_scene")
	Explore.begin_run({})
	var s = load("res://engine/scenes/ExploreRush.tscn").instantiate()
	get_root().add_child(s)
	if s.get_child_count() == 0:
		s._ready()
	ok(s.find_child("RushTutorialOverlay", true, false) != null, "the first Rush shows the image tutorial")
	ok(s.find_child("RushTapHint", true, false) == null, "the old transient Tap to Merge popup is gone")
	var strip := s.find_child("RushBottomHintStrip", true, false) as Control
	var hint := s.find_child("RushBottomHint", true, false) as Label
	ok(hint != null, "the first Rush shows the always-on bottom hint")
	ok(hint != null and String(hint.text).to_lower().find("fling") != -1, "the bottom hint explains the fling tap")
	ok(strip != null and String(strip.get_meta("slice_mode", "")) == "three", \
		"the bottom hint uses 3-slice art, not a 9-slice/flat panel")
	ok(strip != null \
		and strip.find_child("RushBottomHintLeftCap", true, false) is TextureRect \
		and strip.find_child("RushBottomHintCenterSlice", true, false) is TextureRect \
		and strip.find_child("RushBottomHintRightCap", true, false) is TextureRect, \
		"the bottom hint preserves fixed side caps with a stretchable centre")
	ok(Save.rush_intro_seen() == 1, "the first Rush marks the tutorial seen once")
	var first_overlay: Node = s.find_child("RushTutorialOverlay", true, false)
	if first_overlay != null:
		first_overlay.queue_free()
		await process_frame
	hint = s.find_child("RushBottomHint", true, false) as Label
	var replay := s.find_child("RushInfoButton", true, false) as Button
	ok(replay != null and replay.visible and not replay.disabled, "Rush has an info button to replay the tutorial")
	var replay_glyph := replay.find_child("RushInfoGlyph", true, false) as Label if replay != null else null
	# the info button + the caption both centre on the BAR — the button geometrically, the caption via its
	# small optical nudge (its rect centre is offset from its ink centre by that nudge, so compare the
	# button to the strip centre rather than to the label rect).
	var strip2 := replay.get_parent() as Control if replay != null else null
	var replay_center_y := replay.get_global_rect().get_center().y if replay != null else -9999.0
	var strip_center_y := strip2.get_global_rect().get_center().y if strip2 != null else 9999.0
	var replay_strip_delta := replay_center_y - strip_center_y
	ok(replay != null and strip2 != null and absf(replay_strip_delta) <= 1.5, \
		"Rush info button is vertically centered in the bottom hint bar (delta=%.1f)" % replay_strip_delta)
	ok(replay_glyph != null and replay_glyph.vertical_alignment == VERTICAL_ALIGNMENT_CENTER \
		and absf(replay_glyph.get_global_rect().get_center().y - replay_center_y) <= 1.0, \
		"Rush info glyph is vertically centered inside the info button")
	if replay != null:
		replay.pressed.emit()
		await process_frame
	ok(s.find_child("RushTutorialOverlay", true, false) != null, "the Rush info button reopens the tutorial")
	s._time = 30.0
	s._elapsed = 1.0
	s._spawn_acc = 0.25
	s._tf.t = 2.0
	var paused_time := float(s._time)
	var paused_elapsed := float(s._elapsed)
	var paused_spawn := float(s._spawn_acc)
	var paused_treefall := float(s._tf.t)
	s._process(0.5)
	ok(is_equal_approx(float(s._time), paused_time) \
		and is_equal_approx(float(s._elapsed), paused_elapsed) \
		and is_equal_approx(float(s._spawn_acc), paused_spawn) \
		and is_equal_approx(float(s._tf.t), paused_treefall), \
		"Rush info tutorial pauses timer, spawn clock, and treefall")
	var replay_overlay: Node = s.find_child("RushTutorialOverlay", true, false)
	if replay_overlay != null:
		replay_overlay.queue_free()
		await process_frame
	s._process(0.5)
	ok(float(s._time) < paused_time and float(s._elapsed) > paused_elapsed, \
		"Rush timer resumes after the info tutorial closes")
	s.queue_free()
	await process_frame
	# the second Rush: the first-run tutorial is retired, the bottom hint and replay button stay.
	var s2 = load("res://engine/scenes/ExploreRush.tscn").instantiate()
	get_root().add_child(s2)
	if s2.get_child_count() == 0:
		s2._ready()
	ok(s2.find_child("RushTutorialOverlay", true, false) == null, "the image tutorial is gone on the second Rush")
	ok(s2.find_child("RushBottomHint", true, false) != null, "the bottom hint stays on the second Rush")
	ok(s2.find_child("RushInfoButton", true, false) != null, "the tutorial replay info button stays on the second Rush")
	ok(Save.rush_intro_seen() == 1, "a retired Rush tutorial does not bump the counter further")
	s2.queue_free()

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
	ok(absf(s._activity.size.x - (s._board.size.x + 2.0 * float(s.FRAME_OUT))) < 3.0, "S-RESIZE: the activity bar matches the board width at 1080 (w=%.0f)" % s._activity.size.x)
	get_root().size = Vector2i(1600, 1920)
	await create_timer(0.06).timeout
	await create_timer(0.06).timeout
	var cx1600: float = s._board.position.x + s._board.size.x * 0.5
	ok(absf(cx1600 - 800.0) < 3.0, "S-RESIZE: the rush board re-centres on a live resize to 1600 (cx=%.0f)" % cx1600)
	ok(s._board.position.x + s._board.size.x <= 1602.0, "S-RESIZE: the re-fitted board fits within the 1600 width")
	ok(absf(s._activity.size.x - (s._board.size.x + 2.0 * float(s.FRAME_OUT))) < 3.0, "S-RESIZE: the activity bar re-fits to the board width at 1600 (w=%.0f)" % s._activity.size.x)
	ok(absf(s._board.position.x - bx1080) > 10.0, "S-RESIZE: the board actually moved on the resize (not pinned to the old width)")
	ok(s._hint != null and absf((s._hint.position.x + s._hint.size.x * 0.5) - 800.0) < 8.0, "S-RESIZE: the bottom hint re-centres to the new width")
	var hint_label := s._hint.find_child("RushBottomHint", true, false) as Label if s._hint != null else null
	# the caption box FILLS the strip (symmetric centring — no top-only pad that shoved the text low) and
	# carries only a small optical-centre nudge; valign CENTER then sits it on the pill centre.
	var hint_label_nudge := hint_label.position.y if hint_label != null else 999.0
	ok(hint_label != null and hint_label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER \
		and absf(hint_label.size.y - s._hint.size.y) < 1.0 \
		and absf(hint_label_nudge) <= s._hint.size.y * 0.06, \
		"S-RESIZE: the bottom hint caption fills the bar and is centred (nudge=%.1f)" % hint_label_nudge)
	# the info bar sits at the vertical CENTRE of the bottom section (board frame bottom → screen bottom):
	# equal breathing above and below, both clear.
	var board_fb: float = s._board.position.y + s._board.size.y + float(s.FRAME_OUT) if s._board != null else 0.0
	var margin_above: float = s._hint.position.y - board_fb if s._hint != null else 0.0
	var margin_below: float = 1920.0 - (s._hint.position.y + s._hint.size.y) if s._hint != null else 0.0
	ok(s._hint != null and margin_above > 4.0 and margin_below > 4.0 and absf(margin_above - margin_below) < 6.0, \
		"S-RESIZE: the bottom hint is centred in the bottom section (above=%.0f below=%.0f)" % [margin_above, margin_below])
	get_root().size = Vector2i(1600, 1400)
	await create_timer(0.06).timeout
	await create_timer(0.06).timeout
	var board_frame_bottom: float = s._board.position.y + s._board.size.y + float(s.FRAME_OUT)
	var hint_top: float = s._hint.position.y if s._hint != null else 0.0
	ok(board_frame_bottom <= hint_top - 8.0, \
		"S-RESIZE: the rush board frame clears the bottom hint on wide/short screens (frame bottom=%.0f hint top=%.0f)" % [board_frame_bottom, hint_top])
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
	# the merge impact now routes through the workbench-tuned MergeFx applier (gate 2 keeps low-combo merges
	# snappy). The ripple + board punch fire INSIDE the applier — the win-cell neighbours (skipping the
	# falling lose column) + the board are passed in, with NO separate scene-side ripple/board_punch calls.
	ok(src.find("MergeFx.apply(self, node, ctr, int(win.tier), _combo, _orthogonal_neighbour_nodes(win_rc.x, win_rc.y, lose_rc.y, lose_rc.x), _board, _merge_opts, 1.0, 2)") != -1, "explore_rush routes the merge through MergeFx.apply (gate 2, neighbours + board passed in)")
	ok(src.find("RushFx.merge_burst(") == -1, "explore_rush no longer calls RushFx.merge_burst in the live merge")
	ok(src.find("_merge_opts = MergeFx.from_config(") != -1, "explore_rush resolves the merge_fx config once")
	# the applier owns the ripple + board punch — the scene no longer calls Feel.ripple/board_punch around
	# the merge (double-firing would be a bug).
	ok(src.find("Feel.ripple(_orthogonal_neighbour_nodes(win_rc.x") == -1, "explore_rush no longer ripples the merge scene-side (MergeFx.apply owns it)")
	ok(src.find("Feel.board_punch(_board") == -1, "explore_rush no longer punches the board scene-side (MergeFx.apply owns it)")
	# the fling touchdown ALSO ripples its settled neighbours (this stays scene-side — LandFx has no ripple);
	# the bulk gravity settle does NOT ripple.
	ok(src.find("Feel.ripple(_orthogonal_neighbour_nodes(fc.x, fc.y), lc, 0.8)") != -1, "explore_rush ripples the fling touchdown's neighbours")
	ok(src.find("func _settle") != -1 and src.find("Explore.gravity(_grid)") != -1, "explore_rush still has the bulk settle (which must NOT ripple)")
	# guard: _settle (the bulk gravity path) carries no Feel.ripple — only discrete impacts ripple.
	var settle_seg := src.substr(src.find("func _settle"), 400)
	ok(settle_seg.find("Feel.ripple") == -1, "the bulk gravity settle does NOT ripple (only discrete merge/land impacts do)")
