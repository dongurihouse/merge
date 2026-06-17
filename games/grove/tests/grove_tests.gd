extends SceneTree
## Headless tests for the Grove P1 core: board model, content sanity, dispenser
## policy, chapter gate math, persistence.
##   godot --headless --path . -s res://games/grove/tests/grove_tests.gd

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Vault = preload("res://engine/scripts/core/vault.gd")   # T44 — the piggy bank skims earned premium
const Login = preload("res://engine/scripts/core/login.gd")   # T44 — the forgiving daily-login ladder
const VaultUI = preload("res://engine/scripts/ui/vault.gd")   # T44 — the diegetic piggy-bank jar surface
const LoginUI = preload("res://engine/scripts/ui/login.gd")   # T44 — the diegetic login-calendar surface

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# --- R3: pixel-right asserts (eng rule 14) -------------------------------------
# Composited UI (panel + icon + label + offsets) is where 10px misalignment hides
# at full-screen scale. These ASSERT the composition headlessly. Call after the
# host is in-tree and laid out (await a frame) so global rects are real.

# `panel` fully contains `content` with at least `minpad` on every side (nothing
# pokes out) AND symmetric gaps — left≈right, top≈bottom within tol (even, not
# lopsided). H and V padding may differ (a pill is fine); each axis must match
# itself. Returns true/logs.
func assert_wraps(panel: Control, content: Control, minpad: float, tol: float, label: String) -> bool:
	var p := panel.get_global_rect()
	var c := content.get_global_rect()
	var left := c.position.x - p.position.x
	var right := p.end.x - c.end.x
	var top := c.position.y - p.position.y
	var bottom := p.end.y - c.end.y
	var bad := ""
	for pair in [["left", left], ["right", right], ["top", top], ["bottom", bottom]]:
		if float(pair[1]) < minpad - tol:
			bad += " %s=%.1f<%.0f" % [pair[0], pair[1], minpad]
	if absf(left - right) > tol:
		bad += " L/R asym %.1f/%.1f" % [left, right]
	if absf(top - bottom) > tol:
		bad += " T/B asym %.1f/%.1f" % [top, bottom]
	ok(bad == "", "%s — plank wraps content (≥%.0f, symmetric ±%.0f)%s" % [label, minpad, tol, bad])
	return bad == ""

# `content`'s center sits on `box`'s center within tol, on the requested axes.
func assert_centered(box: Control, content: Control, axes: String, tol: float, label: String) -> bool:
	var b := box.get_global_rect().get_center()
	var c := content.get_global_rect().get_center()
	var bad := ""
	if "h" in axes and absf(b.x - c.x) > tol:
		bad += " dx=%.1f" % (c.x - b.x)
	if "v" in axes and absf(b.y - c.y) > tol:
		bad += " dy=%.1f" % (c.y - b.y)
	ok(bad == "", "%s — content centered (%s, ±%.0f)%s" % [label, axes, tol, bad])
	return bad == ""

# The map's single-input-surface invariant: every Control under `node` must
# IGNORE the mouse, or it silently eats taps before clip.gui_input (bug class ×3).
func _all_ignore(node: Node) -> bool:
	for child in node.get_children():
		if child is Control and (child as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			print("    offender: %s (%s)" % [child.get_path(), child.get_class()])
			return false
		if not _all_ignore(child):
			return false
	return true

# A still-tap (press+release, no drift) straight into the map's single input
# surface (content.gui_input → _on_input). `at` is a global point; content is a
# full-rect Control at the origin, so gui_input positions equal globals.
func _map_tap_at(h, at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	h._on_input(down)
	var up := down.duplicate()
	up.pressed = false
	h._on_input(up)

# The global-rect center of a hit node (spot/card) — where a player would tap.
func _hit_center(node: Control) -> Vector2:
	return node.get_global_rect().get_center()

# W2: a tap through the BOARD input surface (the animating gate lives here) — used
# to prove rapid generator taps are no longer dropped mid spawn-flight.
func _tap_board(h, at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	h._on_board_input(down)
	var up := down.duplicate()
	up.pressed = false
	h._on_board_input(up)

# Count the purchasable cards of the MOST RECENT shop overlay (meta shop_buy) —
# a UI-shape smoke that survives storefront restyles.
func _shop_rows(host: Control) -> int:
	var overlay: Control = host.get_child(host.get_child_count() - 1)
	var n := 0
	for b in overlay.find_children("*", "Button", true, false):
		if b.has_meta("shop_buy"):
			n += 1
	return n

# Direct Panel children of board_area = the ground tiles (mat/brambles/pieces
# are Control holders) — the J-bug parity counter.
func _panel_count(area: Control) -> int:
	var n := 0
	for c in area.get_children():
		if c is Panel:
			n += 1
	return n

func fresh(name: String) -> void:
	var dir := "user://tu_test_grove_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func _initialize() -> void:
	print("== Grove tests ==")

	# 1. board genesis
	var b: BoardModel = BoardModel.new()
	ok(b.is_open(G.GEN_CELL) and b.item_at(G.GEN_CELL) == 0, "generator cell open and empty")
	ok(b.is_open(Vector2i(3, 2)) and b.is_open(Vector2i(5, 4)), "center 3x3 starts open")
	ok(b.is_bramble(Vector2i(0, 0)) and b.is_bramble(Vector2i(8, 6)), "edges start brambled")
	# §4 per-cell LEVEL gate (replaces the old tier-ring encoding): G.cell_min_level. MIN_LEVEL is the
	# owner's feel dial (T37 — re-tuned to open an L1 frontier), so these assert the MECHANISM
	# (gradient-agnostic, derived from cell_min_level), not fixed table values.
	var g_inner := G.cell_min_level(Vector2i(2, 3))    # a center-adjacent frontier cell
	var g_next := G.cell_min_level(Vector2i(1, 3))     # one ring further out
	var g_corner := G.cell_min_level(Vector2i(0, 0))   # a far corner
	ok(G.cell_min_level(G.GEN_CELL) == 0 and G.cell_min_level(Vector2i(3, 2)) == 0, \
		"the center 3x3 + generator are open at start (min_level 0)")
	ok(g_inner >= 1, "the inner frontier is sealed but reachable early (gates at L%d)" % g_inner)
	ok(g_next > g_inner and g_corner > g_next, \
		"the gradient rises strictly outward (inner L%d < ring L%d < corner L%d)" % [g_inner, g_next, g_corner])
	ok(b.terrain[BoardModel.idx(Vector2i(2, 3))] != 0 and b.terrain[BoardModel.idx(Vector2i(0, 0))] != 0, \
		"a sealed cell's terrain is non-zero (inspectable; the gate reads the static table, not this value)")
	ok(BoardModel.line_of(G.bramble_contents(Vector2i(0, 0))) in [1, 2], \
		"an opened cell reveals a positional anchor-line (1-2) seed")
	ok(b.item_at(Vector2i(3, 2)) == 101, "starter items placed")

	# 2. merge rules
	ok(b.can_merge(Vector2i(3, 2), Vector2i(3, 4)), "same code merges")
	ok(not b.can_merge(Vector2i(3, 2), Vector2i(5, 2)), "different lines never merge")
	var produced := b.merge(Vector2i(3, 2), Vector2i(3, 4))
	ok(produced == 102 and b.item_at(Vector2i(3, 2)) == 0 and b.item_at(Vector2i(3, 4)) == 102, \
		"merge consumes src and bumps dst")
	b.place(Vector2i(3, 2), 108)
	b.place(Vector2i(4, 2), 108)
	ok(not b.can_merge(Vector2i(3, 2), Vector2i(4, 2)), "top tier (t8) never merges")
	ok(b.top_tier_cells().size() == 2, "top tiers visible to the merchant")

	# 3. move / the §4 level gate (merge-openable once the player's Level reaches the cell's min)
	b.move(Vector2i(3, 4), Vector2i(3, 3))
	ok(b.item_at(Vector2i(3, 3)) == 102 and b.item_at(Vector2i(3, 4)) == 0, "move relocates an item")
	# (2,3) is (3,3)'s sealed neighbour, gating at g_inner: a merge there opens it AT g_inner.
	ok(b.openable_brambles(Vector2i(3, 3), g_inner).has(Vector2i(2, 3)), \
		"at the cell's min_level (L%d), any adjacent merge opens it (no tier/line requirement)" % g_inner)
	if g_inner >= 2:
		ok(not b.openable_brambles(Vector2i(3, 3), g_inner - 1).has(Vector2i(2, 3)), \
			"below the cell's min_level, an adjacent merge opens nothing")
	var contents := b.open_bramble(Vector2i(2, 3))
	ok(b.is_open(Vector2i(2, 3)) and b.item_at(Vector2i(2, 3)) == contents and contents == G.bramble_contents(Vector2i(2, 3)), \
		"opening a cell reveals its deterministic contents")
	# the gradient holds outward: (1,3) gates at g_next > g_inner — sealed just below it, opens at it
	b.place(Vector2i(2, 3), 102)              # an item on the freshly-opened cell
	ok(not b.openable_brambles(Vector2i(2, 3), g_next - 1).has(Vector2i(1, 3)), \
		"the outer cell (1,3) stays sealed at L%d (below its L%d gate)" % [g_next - 1, g_next])
	ok(b.openable_brambles(Vector2i(2, 3), g_next).has(Vector2i(1, 3)), \
		"the outer cell (1,3) opens once the player reaches its gate (L%d)" % g_next)

	# 4. pigeonhole helper
	ok(b.any_pair_exists() == false or b.any_pair_exists(), "pair query runs")
	var b2: BoardModel = BoardModel.new()
	ok(b2.any_pair_exists(), "fresh board has mergeable pairs")

	# 5. persistence roundtrip
	var d := b.to_dict()
	var b3: BoardModel = BoardModel.new()
	b3.from_dict(d)
	ok(Array(b3.items) == Array(b.items) and Array(b3.terrain) == Array(b.terrain), \
		"board roundtrips through to_dict/from_dict")

	# 6. The §7 GENERATED-quest model — asks, the capped stars+coins reward, the metered fence,
	# and the gate quest — is covered by quest_tests (engine) + the gate/grant/delivery tests
	# above. The old deterministic per-chapter ramp + its byte-for-byte affordability proof are
	# RETIRED (chapters()/ZONE_RAMP/_quest_stars gone); the no-strand guarantee now rests on the
	# guardrails (every ask producible) + the Monte-Carlo sim (games/grove/tools/grove_sim.gd).

	# 6c. generators arrive PER MAP (§6). Map 0 grants both starters (satchel + compost);
	# the surplus generator's cell (6,5) reveals only when the player enters map 1.
	var z1_chapter: int = G.MAPS[0].spots.size()  # first chapter of map 1 (all map-0 spots bought)
	var bg: BoardModel = BoardModel.new()
	bg.set_active_gens(0)
	ok(bg.is_gen(Vector2i(4, 3)) and bg.is_gen(Vector2i(2, 1)), "map 0 grants both starters (satchel + compost)")
	ok(not bg.is_gen(Vector2i(6, 5)), "the map-1 surplus generator waits for its own map")
	# 6d. entering map 1 reveals the surplus generator at (6,5) — and an item caught on
	# that cell hops away safely (never destroyed).
	var bh: BoardModel = BoardModel.new()
	bh.set_active_gens(0)
	bh.terrain[BoardModel.idx(Vector2i(6, 5))] = 0
	bh.place(Vector2i(6, 5), 204)              # a player item parked on the future generator cell
	var before_count := 0
	for v in bh.items:
		if v == 204:
			before_count += 1
	var fresh_hive: Array = bh.set_active_gens(z1_chapter)
	ok(fresh_hive.has(Vector2i(6, 5)) and bh.is_gen(Vector2i(6, 5)), "entering map 1 reveals the surplus generator")
	var after_count := 0
	for v in bh.items:
		if v == 204:
			after_count += 1
	ok(after_count == before_count and bh.item_at(Vector2i(6, 5)) == 0, \
		"an item on the revealing generator's cell relocates, never vanishes")

	# 7. dispenser odds well-formed
	var total := 0.0
	for p in G.TIER_ODDS:
		total += p
	ok(absf(total - 1.0) < 0.001, "tier odds sum to 1")
	ok(G.TIER_ODDS[0] > G.TIER_ODDS[1] and G.TIER_ODDS[1] > G.TIER_ODDS[2], "tier odds decay")

	# 8. starter economy: each line's starters can produce a t2 (first quests achievable)
	var counts := {}
	for cell in G.STARTER_ITEMS:
		var k: int = G.STARTER_ITEMS[cell]
		counts[k] = int(counts.get(k, 0)) + 1
	ok(int(counts.get(101, 0)) >= 2 and int(counts.get(201, 0)) >= 2, "starters give each line a pair")

	# 9. stars currency (Save)
	fresh("stars")
	ok(Save.stars() == 0, "stars default 0")
	Save.add_stars(3)
	ok(Save.stars() == 3, "add_stars banks")
	ok(Save.spend_stars(3) and Save.stars() == 0, "spend_stars deducts")
	ok(not Save.spend_stars(1), "spend_stars refuses when broke")

	# 10. the SCENE stands up and plays headless (merge → bramble → deliver → gate)
	fresh("scene")
	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(scn)
	if scn.board == null:
		scn._ready()
	ok(scn.board != null and scn.board.bramble_count() > 0, "grove scene builds with a brambled board")
	var half: Vector2 = Vector2(scn.csz, scn.csz) / 2.0
	Save.grove()["stars_earned"] = G.stars_at_level(2)   # §4: reach Lv2 (level clock only) so the L2 frontier cell (2,4) can open
	scn._on_press(scn._cell_pos(Vector2i(3, 2)) + half)
	scn._on_release(scn._cell_pos(Vector2i(3, 4)) + half)
	ok(scn.board.item_at(Vector2i(3, 4)) == 102, "drag-merge grows t1+t1 into t2")
	await create_timer(0.35).timeout
	ok(scn.board.is_open(Vector2i(2, 4)), "at Lv2 the merge cleared the adjacent L2 frontier cell")
	ok(scn.board.item_at(Vector2i(2, 4)) > 0, "the cleared bramble revealed its contents")

	var items_before := 0
	for v in scn.board.items:
		if v > 0:
			items_before += 1
	scn._pop_seed()
	await create_timer(0.3).timeout
	var items_after := 0
	for v in scn.board.items:
		if v > 0:
			items_after += 1
	ok(items_after >= items_before + 1, "the satchel pops a burst (≥1 item) onto the board")

	# deliver: chapter 1's first quest wants flower t2 (code 102) — we just made one
	ok(not scn.giver_chips.is_empty(), "givers are on duty")

	# AB5: frameless fence anatomy — the ask rides a content-sized pill (no
	# band-filling parchment card), the pill sits BELOW the bust, and the
	# ready-check is present but hidden (the old border ring is gone).
	await create_timer(0.05).timeout
	for e in scn.giver_chips:
		var gstand: Control = e.chip
		var gpills := gstand.find_children("*", "PanelContainer", true, false)
		ok(gpills.size() >= 1, "AB: the giver ask rides a pill")
		if not gpills.is_empty():
			var gpill: Control = gpills[0]
			var ghb := gpill.find_children("*", "HBoxContainer", true, false)
			if not ghb.is_empty():
				assert_wraps(gpill, ghb[0], 6.0, 8.0, "AB ask pill hugs its content")
			ok(gpill.get_rect().position.y >= 100.0, "AB pill rides below the bust, on the fence")
		# AB3: the check is the ONLY ready affordance (the border ring is deleted);
		# its visibility is driven by board state, so assert presence, not momentary vis.
		var gck: Control = e.check
		ok(gck != null and is_instance_valid(gck) and gck is Panel, "AB ready-check node present (ring deleted)")
	var qi: int = scn.giver_chips[0].qi
	var dq: Dictionary = scn.quests[qi]
	# clear the open board first so EVERY ask fits regardless of prior test state
	# (determinism: a crowded board could otherwise starve a multi-ask delivery)
	for ci in scn.board.items.size():
		if scn.board.items[ci] > 0 and not G.is_coin(scn.board.items[ci]):
			scn.board.items[ci] = 0
	var demp: Array = scn.board.empty_ground_cells()
	var dei := 0
	for ask in G.quest_asks(dq):
		var ac: int = int(ask.line) * 100 + int(ask.tier)
		for n in int(ask.count):
			if dei < demp.size():
				scn.board.place(demp[dei], ac)
				dei += 1
	scn._rebuild_pieces()
	var stars_before := Save.stars()
	var dlv_coins_before := Save.coins()
	var n_before: int = scn.quests.size()
	scn._on_giver_tap(qi, scn.giver_chips[0].chip)
	ok(Save.stars() > stars_before, "§7: delivery pays stars (all asks satisfied)")
	ok(Save.coins() >= dlv_coins_before, "§7: delivery pays any coin overflow (the quest coin faucet)")
	ok(scn.quests.size() <= n_before, "§7: the delivered quest leaves the live fence")

	# §7 soft gate: the fence is METERED to the next unlock — with enough banked stars + level
	# the next spot is affordable, so the fence EMPTIES (the wordless "go restore" signal).
	var gg := Save.grove()
	gg["stars_earned"] = 300
	Save.grove_write()
	Save.add_stars(300)
	scn._rebuild_givers()
	scn._update_hud()
	ok(scn._gate_ready(), "§7: the next unlock is affordable (gate ready)")
	ok(scn.quests.is_empty(), "§7: the metered fence empties once the next unlock is affordable")
	ok(scn.gate_btn.visible, "§7: the restore CTA appears when affordable")
	# the CTA's reserved slot never covers a giver/merchant pill (any population)
	var aa_gate: Rect2 = scn.gate_btn.get_global_rect()
	var aa_clear := true
	for e in scn.giver_chips:
		if aa_gate.intersects((e.chip as Control).get_global_rect()):
			aa_clear = false
	if scn.merchant_chip != null and is_instance_valid(scn.merchant_chip):
		if aa_gate.intersects(scn.merchant_chip.get_global_rect()):
			aa_clear = false
	ok(aa_clear, "the restore CTA's reserved slot covers no giver/merchant")
	# buying a home spot advances the board's progress: it derives from unlocks
	var ch_before: int = scn._chapter_idx()
	var gu := Save.grove()
	var first_spot: String = G.MAPS[0].spots[0].id
	gu["unlocks"] = {first_spot: true}
	Save.grove_write()
	ok(scn._chapter_idx() == ch_before + 1, "a home purchase advances the board's progress (unlocks)")

	# persistence: a fresh scene resumes the same board + progress
	var snapshot := Array(scn.board.items)
	var scn2 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(scn2)
	if scn2.board == null:
		scn2._ready()
	ok(Array(scn2.board.items) == snapshot and scn2._chapter_idx() == scn._chapter_idx(), \
		"a fresh scene resumes the persisted board and progress")

	# 10g. §7 GATE quest: restoring all of map 1's spots unveils the great-spirit's gate on the
	# fence; delivering its top-tier asks records the gate, grants the next map's generators, and
	# opens map 2 (the completion chain). All engine-side; the grove only supplies the tunables.
	fresh("gatequest")
	var sg = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sg)
	if sg.board == null:
		sg._ready()
	var sgg := Save.grove()
	sgg["stars_earned"] = 300                 # level past map 1's spot gates
	var gate_ul := {}
	for sp in G.MAPS[0].spots:
		gate_ul[String(sp.id)] = true         # all of map 1 spot-restored
	sgg["unlocks"] = gate_ul
	sgg["gates"] = []
	Save.grove_write()
	sg._init_quests()
	sg._rebuild_givers()
	ok(sg.quests.size() == 1 and bool(sg.quests[0].get("gate", false)), "§7: a fully-restored map shows the lone gate quest")
	var gateq: Dictionary = sg.quests[0]
	for ci in sg.board.items.size():
		if sg.board.items[ci] > 0 and not G.is_coin(sg.board.items[ci]):
			sg.board.items[ci] = 0
	var gemp: Array = sg.board.empty_ground_cells()
	var gix := 0
	for ask in G.quest_asks(gateq):
		var gcode: int = int(ask.line) * 100 + int(ask.tier)
		for _n in int(ask.count):
			if gix < gemp.size():
				sg.board.place(gemp[gix], gcode)
				gix += 1
	sg._rebuild_pieces()
	var gate_stars_b := Save.stars()
	sg._on_giver_tap(0, sg.giver_chips[0].chip)
	ok(Save.grove().get("gates", []).has(0), "§7: delivering the gate records it for map 1")
	ok(G.map_unlocked(1, Save.grove().get("unlocks", {}), Save.grove().get("gates", [])), "§7: map 2 unlocks once the gate is delivered")
	ok(Save.stars() > gate_stars_b, "§7: the gate pays its large authored reward")
	ok(sg.board.gen_id_at(Vector2i(6, 5)) == "dairy_stall", "§7: the next map's SURPLUS generator appears outright (dairy stall)")
	ok(sg.board.gen_id_at(Vector2i(4, 3)) == "seed_satchel" and sg.board.gen_id_at(Vector2i(2, 1)) == "pantry_crock", "§7: the anchor satchel stays; the pantry crock waits to be handed in")
	# the new map opens with its generator-grant hand-in(s) on the fence (§6)
	var grant_qi := -1
	for gqi in sg.quests.size():
		if sg.quests[gqi].has("grant") and String(sg.quests[gqi].grant.grants) == "hen_coop":
			grant_qi = gqi
	ok(grant_qi >= 0, "§7: the new map opens with the hen coop's grant quest (hand in the pantry crock)")
	sg._on_giver_tap(grant_qi, sg.giver_chips[grant_qi].chip)
	ok(sg.board.gen_id_at(Vector2i(2, 1)) == "hen_coop", "§7: handing the pantry crock in installs the hen coop — the new line goes live")
	sg.queue_free()

	# 11. P2 — water economy + coins
	fresh("p2")
	var s2 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s2)
	if s2.board == null:
		s2._ready()
	ok(s2.water == G.WATER_CAP, "fresh grove starts at the water cap")
	Save.grove()["pops"] = 10                 # past the FTUE free pops (tested in P5)
	var w0: int = s2.water
	var pop_items_b := 0
	for v in s2.board.items:
		if v > 0:
			pop_items_b += 1
	s2._pop_seed()
	await create_timer(0.3).timeout
	var pop_burst := -pop_items_b
	for v in s2.board.items:
		if v > 0:
			pop_burst += 1
	ok(pop_burst >= 1, "a tap pops a burst of at least one item")
	ok(s2.water == w0 - pop_burst * G.POP_COST, "each item in the burst costs one energy")

	s2.water = 0
	var pieces_before := 0
	for v in s2.board.items:
		if v > 0:
			pieces_before += 1
	s2._pop_seed()
	await create_timer(0.25).timeout
	var pieces_after := 0
	for v in s2.board.items:
		if v > 0:
			pieces_after += 1
	ok(pieces_after == pieces_before, "no water → the satchel pops nothing")
	s2._update_water_hud()
	ok(s2.refill_btn.visible, "the free-refill offer appears on empty")
	s2._on_refill()
	ok(s2.water == G.WATER_CAP and s2.refills_used == 1, "free refill fills to cap, once counted")

	# regen: 10 simulated minutes → +5
	s2.water = 50
	s2._regen_ts = Time.get_unix_time_from_system() - 600.0
	s2._tick_water()
	ok(s2.water == 55, "regen pays +1 per 2 minutes (offline math)")

	# the chapter water gift now pays on the HOME spot purchase (tested in 14b)

	# the burst pops above may have filled the virgin board — clear the playfield so the coin lands
	for ci in s2.board.items.size():
		if s2.board.items[ci] > 0 and not G.is_coin(s2.board.items[ci]):
			s2.board.items[ci] = 0
	s2._rebuild_pieces()

	# coins: drop → tap-collect → wallet
	var coins0 := Save.coins()
	s2._drop_coin_near(Vector2i(4, 3))
	await create_timer(0.3).timeout
	var coin_cell := Vector2i(-1, -1)
	for i in s2.board.items.size():
		if s2.board.items[i] > 0 and G.is_coin(s2.board.items[i]):
			coin_cell = BoardModel.cell_of(i)
			break
	ok(coin_cell != Vector2i(-1, -1), "a coin dropped onto the board")
	var chalf: Vector2 = Vector2(s2.csz, s2.csz) / 2.0
	s2._on_press(s2._cell_pos(coin_cell) + chalf)
	s2._on_release(s2._cell_pos(coin_cell) + chalf)
	ok(Save.coins() == coins0 + 1, "tapping a coin pockets its value")
	ok(s2.board.item_at(coin_cell) == 0, "the collected coin left the board")

	# coin merge rules (model): c1+c1 merges, c3 is capped
	var bc: BoardModel = BoardModel.new()
	bc.place(Vector2i(3, 2), 901)
	bc.place(Vector2i(3, 4), 901)
	ok(bc.can_merge(Vector2i(3, 2), Vector2i(3, 4)), "coins merge with coins")
	bc.place(Vector2i(5, 2), 903)
	bc.place(Vector2i(5, 4), 903)
	ok(not bc.can_merge(Vector2i(5, 2), Vector2i(5, 4)), "top coin (25) never merges")
	ok(bc.top_tier_cells().is_empty(), "coins are never merchant goods")

	# 11b. BURST-POP (§6) + the burst-upgrade COIN SINK — both engine-side; the grove only sets the
	# odds/scale/cost dials. One tap throws a burst that scales with the map + the paid upgrade, each
	# item costing one energy. The upgrade spends coins, raises the burst, persists, and caps.
	fresh("burst")
	var sbp = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sbp)
	if sbp.board == null:
		sbp._ready()
	Save.grove()["pops"] = 50                 # well past the FTUE — the energy meter is on
	ok(sbp._gen_burst_level() == 0, "the burst-upgrade starts at level 0")
	Save.add_coins(10000)
	var bu_c0 := Save.coins()
	ok(sbp._upgrade_gen_burst(), "the burst-upgrade buys with coins")
	ok(Save.coins() == bu_c0 - G.burst_upgrade_cost(0), "the burst-upgrade spends coins (the sink)")
	ok(sbp._gen_burst_level() == 1, "the burst-upgrade raises the burst level")
	ok(sbp._upgrade_gen_burst() and sbp._gen_burst_level() == 2, "a second burst-upgrade stacks")
	# clear a wide-open area so the burst is bounded only by its own size (not by board space)
	for ci in sbp.board.items.size():
		if sbp.board.items[ci] > 0 and not G.is_coin(sbp.board.items[ci]):
			sbp.board.items[ci] = 0
	sbp._rebuild_pieces()
	sbp.water = G.WATER_CAP
	var bw0: int = sbp.water
	var bb := 0
	for v in sbp.board.items:
		if v > 0:
			bb += 1
	sbp._pop_seed()
	await create_timer(0.3).timeout
	var burst_got := -bb
	for v in sbp.board.items:
		if v > 0:
			burst_got += 1
	ok(burst_got >= 3, "with the upgrade a single tap throws a burst of ≥3 items (map 1, level 2)")
	ok(sbp.water == bw0 - burst_got * G.POP_COST, "each burst item costs one energy")
	# the sink caps: drive to the max level, then the upgrade refuses
	while sbp._gen_burst_level() < G.burst_upgrade_max():
		sbp._upgrade_gen_burst()
	ok(not sbp._upgrade_gen_burst(), "the burst-upgrade caps — no buy past the max level")
	# the burst level rides the save
	var saved_lvl: int = sbp._gen_burst_level()
	var sbp2 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sbp2)
	if sbp2.board == null:
		sbp2._ready()
	ok(sbp2._gen_burst_level() == saved_lvl, "the burst-upgrade level persists across scenes")
	sbp.queue_free()
	sbp2.queue_free()

	# 11c. The on-board burst BUY PILL (§6 coin sink UI): the pill renders on the generator, its tap
	# handler spends coins + raises the level, refuses when broke (no debt) and past the cap. The
	# logic under the pill (_try_buy_burst) is unit-tested directly; the pill's look is a Dev eyeball.
	fresh("burst_chip")
	var sbc = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sbc)
	if sbc.board == null:
		sbc._ready()
	ok(sbc.burst_chip != null, "the burst buy pill renders (a generator is on the board)")
	ok(sbc._gen_burst_level() == 0 and Save.coins() == 0, "fresh: burst level 0, no coins")
	sbc._try_buy_burst()
	ok(sbc._gen_burst_level() == 0 and Save.coins() == 0, "tapping the pill broke is refused — no level, no debt")
	Save.add_coins(10000)
	var cc0 := Save.coins()
	sbc._try_buy_burst()
	ok(sbc._gen_burst_level() == 1, "tapping the pill with coins raises the burst level")
	ok(Save.coins() == cc0 - G.burst_upgrade_cost(0), "tapping the pill spends the ladder cost (the sink)")
	while sbc._gen_burst_level() < G.burst_upgrade_max():
		sbc._try_buy_burst()
	var pill_maxed: int = sbc._gen_burst_level()
	var coins_at_max := Save.coins()
	sbc._try_buy_burst()
	ok(sbc._gen_burst_level() == pill_maxed and Save.coins() == coins_at_max, "the pill refuses past the max level (no overspend)")
	sbc.queue_free()

	# 12. win-back: away 3 days with low water → full cap on return
	fresh("winback")
	var gw := Save.grove()
	gw["board"] = BoardModel.new().to_dict()
	gw["water"] = 10
	gw["regen_ts"] = Time.get_unix_time_from_system() - 3 * 86400.0
	gw["last_seen"] = Time.get_unix_time_from_system() - 3 * 86400.0
	Save.grove_write()
	var s3 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s3)
	if s3.board == null:
		s3._ready()
	ok(s3.water == G.WATER_CAP, "returning after days away finds full water")

	# 12b. a cold load mid-game draws EVERY live generator of the CURRENT map (§6), not just
	# one — completing maps 1+2 puts the player in map 3/Pond (2 generators: reed bed + creel;
	# the anchor satchel's cold-load persistence is the parked engine follow-up, BACKLOG).
	fresh("twogens")
	var gtg := Save.grove()
	var ul16 := {}
	for z in 2:
		for sp in G.MAPS[z].spots:
			ul16[String(sp.id)] = true
	gtg["unlocks"] = ul16
	Save.grove_write()
	var s4 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s4)
	if s4.board == null:
		s4._ready()
	ok(s4.gen_nodes.size() == 2, "a cold load in map 3/Pond draws both of the map's generators (reed bed + creel)")
	ok(s4.gen_node != null and s4.gen_nodes.values().has(s4.gen_node), "gen_node points at a live generator (not the stale index-0 satchel)")

	# 12c. generators are MOVABLE (#1) and arrive by GRANT HAND-IN (#2) on the live board,
	# and the scene re-renders both (§6). A fresh board is map 1: seed satchel (4,3) + pantry crock (2,1).
	fresh("genmech")
	var s4c = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s4c)
	if s4c.board == null:
		s4c._ready()
	ok(s4c.board.gen_id_at(Vector2i(4, 3)) == "seed_satchel" and s4c.board.gen_id_at(Vector2i(2, 1)) == "pantry_crock", "12c: a fresh board seeds the map-0 generators")
	s4c.board.items[BoardModel.idx(Vector2i(4, 4))] = 0       # clear the destination
	ok(s4c.board.move_gen(Vector2i(4, 3), Vector2i(4, 4)), "12c: the satchel moves to an empty cell (#1)")
	s4c._rebuild_all()
	ok(s4c.gen_nodes.has(Vector2i(4, 4)) and not s4c.gen_nodes.has(Vector2i(4, 3)), "12c: the moved generator re-renders at its new cell")
	ok(s4c.board.grant_gen("hen_coop"), "12c: a generator-grant quest hands the pantry crock in for the hen coop (#2)")
	s4c._rebuild_all()
	ok(s4c.board.gen_id_at(Vector2i(2, 1)) == "hen_coop" and s4c.board.gen_id_at(Vector2i(4, 4)) == "seed_satchel" and s4c.board.gens.size() == 2, "12c: granted — hen coop at the crock's cell; the moved anchor satchel untouched")
	ok(s4c.gen_nodes.has(Vector2i(2, 1)) and s4c.gen_nodes.has(Vector2i(4, 4)), "12c: the re-render reflects the grant + the moved anchor")
	s4c.queue_free()

	# 12b2. a runtime-opened cell's ground tile sits ABOVE the mat (owner's
	# "no border" bug: move_child(slot, 0) hid the tile behind the moss)
	fresh("opentile")
	var s4b = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s4b)
	if s4b.board == null:
		s4b._ready()
	var mat_ref: Node = s4b.board_area.get_child(0)
	var slots_before: int = _panel_count(s4b.board_area)
	s4b._open_bramble(Vector2i(2, 3))          # the first frontier
	ok(s4b.board_area.get_child(0) == mat_ref, "the mat stays child 0 after a runtime open")
	var new_slot: Control = s4b.slot_nodes[Vector2i(2, 3)]
	ok(new_slot.get_index() >= 1, "the freed cell's tile sits ABOVE the mat (index >= 1)")
	ok(_panel_count(s4b.board_area) == slots_before + 1, "exactly one new ground tile")
	var live_slots: int = _panel_count(s4b.board_area)
	s4b._rebuild_all()
	await create_timer(0.1).timeout            # let the rebuild's queue_frees flush
	ok(_panel_count(s4b.board_area) == live_slots, \
		"runtime tiles match a fresh rebuild of the same board (parity)")

	# 12c. the idle wiggle hint finds a real mergeable pair (starters pair up)
	var hint: Array = s3._hint_pair()
	ok(hint.size() == 2 and s3.board.item_at(hint[0]) == s3.board.item_at(hint[1]) \
		and s3.board.can_merge(hint[0], hint[1]), "the idle hint wiggles a true mergeable pair")

	# 12d. §7: the fence is METERED to the next unlock — it seats exactly active_giver_count
	# stands (shrinking as stars bank, capped at MAX_GIVERS), not a fixed pool.
	var s3_nxt: int = G.cheapest_spot_cost(Save.grove().get("unlocks", {}), G.level_for_stars(int(Save.grove().get("stars_earned", 0))))
	ok(s3.giver_chips.size() == G.active_giver_count(Save.stars(), s3_nxt), "§7: the fence seats exactly the metered giver count (%d shown)" % s3.giver_chips.size())
	ok(s3.giver_chips.size() <= int(G.MAX_GIVERS), "§7: the fence never exceeds MAX_GIVERS stands")

	# 13. P3 — maps/spots content sanity + level math
	var maps_ok := true
	for z in G.MAPS.size():
		var n: int = G.MAPS[z].spots.size()
		if n < 8 or n > 10:
			maps_ok = false
		var seen_ids := {}
		for s in G.MAPS[z].spots:
			if int(s.cost) < 3 or int(s.cost) > 5:
				maps_ok = false
			seen_ids[String(s.id)] = true
		if seen_ids.size() != n:
			maps_ok = false
	ok(maps_ok, "every map has 8-10 unique spots costing 3-5 stars (owner pacing)")
	# 13c. the stars-driven level clock (one uncapped Level, driven by stars EARNED)
	ok(G.level_for_stars(0) == 1 and G.level_for_stars(5) == 1 and G.level_for_stars(6) == 2, \
		"level_for_stars maps cumulative-earned thresholds")
	ok(G.level_for_stars(126) == 10, "L10 lands at 126 earned stars (= the old L10 exp/10)")
	ok(G.level_for_stars(126 + G.LEVEL_STARS_TAIL) == 11 and G.level_for_stars(100000) > 50, \
		"the level clock is UNCAPPED — a flat tail past the table")
	ok(G.stars_at_level(1) == 0 and G.stars_at_level(2) == 6 and G.stars_at_level(10) == 126 \
		and G.stars_at_level(11) == 126 + G.LEVEL_STARS_TAIL, "stars_at_level inverts the curve")
	# earn_stars bumps the spendable balance AND the earned clock; a level-up gifts water+gems
	fresh("earn")
	var ge := Save.grove()
	ge["stars_earned"] = 5
	ge["water"] = 10
	var gained := G.earn_stars(2)              # 5 -> 7 crosses the L2 line (6)
	ok(gained == 1, "earn_stars returns the number of levels gained")
	ok(int(Save.grove()["stars_earned"]) == 7 and Save.stars() == 2, \
		"earn_stars accrues BOTH the earned clock and the spendable balance")
	ok(int(Save.grove()["water"]) == 10 + G.LEVEL_WATER_GIFT and Save.diamonds() == G.LEVEL_DIAMONDS, \
		"a level-up gifts water + diamonds, once per level")
	ok(G.earn_stars(1) == 0, "earning within a level gains no level (no extra gift)")

	# 14. P3 — the HOME scene (NEW map model): a map IS one image with restoration
	# SPOTS placed on it; discrete maps via the map-select. boot → buy → gate → resume.
	fresh("home")
	var h = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h)
	if h.content == null:
		h._ready()
	await create_timer(0.05).timeout
	# boot lands ON a map: the frontier (fresh save → the hub, map 0), every spot live
	ok(h._view == "map" and h._map_idx == G.hub_map(), "boot opens the frontier map (fresh → the hub)")
	ok(h.content != null, "the single input surface exists")
	ok(h.spot_hits.size() == G.MAPS[h._map_idx].spots.size(), "the open map seats every spot as a hit")
	# the single-input-surface rule (3rd input-swallow bug): EVERY descendant of
	# content IGNOREs the mouse — only content's gui_input resolves taps
	ok(_all_ignore(h.content), "every content descendant IGNOREs mouse (single input surface)")
	ok(h.map_unlocked(0) and not h.map_unlocked(1), "farmhouse open, barn locked, on a fresh save")

	# a spot BUY, driven through the REAL spot node: give stars, tap an
	# affordable + level-ok spot (k=0 fh_hearth, L1, 3★) → owned, stars debited,
	# the view stays a map (no takeover/scene change).
	Save.add_stars(100)
	# level gates derive from rank: k=0 is L1 (buyable now), k=2 wants L2 (greyed)
	ok(G.spot_level_req(0, 0) == 1 and G.spot_level_req(0, 2) == 2, "spot gates derive from rank")
	var stars0 := Save.stars()
	var locked_node: Control = h.spot_hits[2].node
	h._on_spot_tap(0, 2, locked_node, _hit_center(locked_node))
	ok(not h.spot_owned(String(G.MAPS[0].spots[2].id)) and Save.stars() == stars0, \
		"a level-locked spot refuses the purchase (greyed, no stars move)")
	var hearth_id: String = G.MAPS[0].spots[0].id
	var buy_node: Control = h.spot_hits[0].node
	h._on_spot_tap(0, 0, buy_node, _hit_center(buy_node))
	ok(h.spot_owned(hearth_id), "buying a spot records the unlock")
	ok(Save.stars() == stars0 - int(G.MAPS[0].spots[0].cost), "the spot's stars were spent")
	ok(G.level_for_stars(int(Save.grove().get("stars_earned", 0))) == 1, \
		"buying a spot does NOT raise Level (Level rides stars EARNED, not spent)")
	ok(h._view == "map", "the view stays a map across a purchase (no takeover)")

	# the customize strip: opening the inline variant strip on an OWNED spot keeps
	# the single-input-surface rule and stays in map view (no modal, no veil)
	h._customize_spot = hearth_id
	h._build_map()
	ok(h.variant_hits.size() == 3, "the owned spot's inline strip exposes all 3 variants as chips")
	ok(_all_ignore(h.content), "the strip keeps the single-input-surface rule")
	ok(h._view == "map", "customizing keeps you on the map")
	h._customize_spot = ""
	h._build_map()

	# the MAP-SELECT view: every map is a card. an UNLOCKED card opens that map; a
	# LOCKED card stays put (wobble). drive taps through the real input surface.
	h._open_select()
	ok(h._view == "select", "the atlas button opens the map-select view")
	ok(h.select_hits.size() == G.MAPS.size(), "the select view seats one card per map")
	ok(_all_ignore(h.content), "every select descendant IGNOREs mouse (single input surface)")
	await create_timer(0.05).timeout
	# tapping the LOCKED barn card (z=1) does nothing — still in select
	var locked_card: Control = null
	for hit in h.select_hits:
		if int(hit.z) == 1:
			locked_card = hit.node
	_map_tap_at(h, _hit_center(locked_card))
	ok(h._view == "select", "tapping a LOCKED map card stays in the select view")
	# tapping the UNLOCKED farmhouse card (z=0) opens that map
	var open_card: Control = null
	for hit in h.select_hits:
		if int(hit.z) == 0:
			open_card = hit.node
	_map_tap_at(h, _hit_center(open_card))
	ok(h._view == "map" and h._map_idx == 0, "tapping an UNLOCKED map card opens that map")

	# the completion chain: spot-restoring map 0 does NOT open map 1 — its gate
	# quest must land first. buy all of map 0 (earn past its L-gates), then inject
	# gates=[0] (gate delivery really happens on the board; here we simulate it).
	Save.grove()["stars_earned"] = G.stars_at_level(3)   # clear the farmhouse's L-gates
	for i in G.MAPS[0].spots.size():
		var sid: String = G.MAPS[0].spots[i].id
		if not h.spot_owned(sid):
			h._on_spot_tap(0, i, h.spot_hits[i].node, _hit_center(h.spot_hits[i].node))
	ok(h.map_spots_done(0), "all farmhouse spots restored")
	ok(not h.map_unlocked(1), "§7: spot-completing a map does NOT open the next — its gate quest must land first")
	var gg2 := Save.grove()
	var gt2: Array = gg2.get("gates", [])
	gt2.append(0)                             # the great-spirit's gate, delivered
	gg2["gates"] = gt2
	Save.grove_write()
	ok(h.map_unlocked(1), "§7: delivering the map's gate opens the next (the completion chain)")
	h._persist()

	# 14a2. customization values: each owned spot offers a coin + a diamond look, and
	# a chosen variant persists + resolves; applying it pays and stays on the map.
	var vars0: Array = G.spot_variants(0, 0)
	ok(vars0.size() == 3 and String(vars0[1].currency) == "coins" and String(vars0[2].currency) == "diamonds" \
		and int(vars0[1].cost) > 0 and int(vars0[2].cost) > 0, "each spot offers a coin and a diamond variant")
	Save.grove()["custom"] = {hearth_id: "gem"}
	ok(String(h._spot_variant(0, 0).id) == "gem", "the chosen variant persists and resolves")
	Save.add_coins(100)
	var coins_v0 := Save.coins()
	var coin_vid := ""
	var coin_cost := 0
	for v in G.spot_variants(0, 0):
		if String(v.currency) == "coins":
			coin_vid = String(v.id)
			coin_cost = int(v.cost)
	h._apply_variant(0, 0, coin_vid, Vector2(300, 300))
	ok(String(h._spot_variant(0, 0).id) == coin_vid and Save.coins() == coins_v0 - coin_cost, \
		"a swatch tap pays coins and dresses the item in place")
	ok(h.variant_hits.is_empty() and h._customize_spot == "", "the strip tucks away after applying")
	ok(h._view == "map", "customizing keeps you on the map")

	# 14a3. Q save migration: a pre-Q save (old spot ids) renames in place on the
	# shared grove() accessor — ownership AND chosen variant survive, counts intact.
	# Old ids are sourced from the rename map itself (no stale literals in tests).
	fresh("qmig")
	var ren: Dictionary = Save._SPOT_ID_RENAMES
	var first_old: String = ren.keys()[0]
	var gm := Save.grove()
	var u_seed := {}
	for old in ren:
		u_seed[old] = true
	gm["unlocks"] = u_seed
	gm["custom"] = {first_old: "gem"}
	Save.grove()                              # the accessor migrates on read
	var um: Dictionary = Save.grove().get("unlocks", {})
	var cm: Dictionary = Save.grove().get("custom", {})
	var all_renamed := true
	for old in ren:
		if um.has(old) or not um.has(String(ren[old])):
			all_renamed = false
	ok(all_renamed, "Q migration renames ALL unlock ids old→new (ownership survives)")
	ok(um.size() == ren.size(), "migration preserves the unlock COUNT (chapters/stars intact)")
	ok(String(cm.get(String(ren[first_old]), "")) == "gem" and not cm.has(first_old), \
		"Q migration renames custom old→new (chosen look survives)")
	Save.grove()                              # idempotent: a second pass changes nothing
	ok(Save.grove().get("unlocks", {}).size() == ren.size() and not Save.grove().get("unlocks", {}).has(first_old), \
		"Q migration is idempotent")

	# 14b. §7: buying a spot grants NO per-spot water — the old per-chapter gift is retired
	# (water comes from level-ups only), so the purchase leaves water unchanged.
	var gw2 := Save.grove()
	var ul24 := {}
	for z4 in 3:                             # maps 1-3 (maps 0-2) fully spot-restored
		for sp in G.MAPS[z4].spots:
			ul24[String(sp.id)] = true
	gw2["unlocks"] = ul24
	h.unlocks = ul24
	gw2["water"] = 50
	gw2["stars_earned"] = 200                # high Level clears the orchard gates
	gw2["gates"] = [0, 1, 2]                  # §7: maps 1-3 gated through → map 4 spots are buyable
	Save.add_stars(10)
	h._on_spot_tap(3, 0, Button.new(), Vector2(300, 300))
	ok(int(Save.grove().get("water", 0)) == 50, "§7: a home purchase grants no per-spot water (water is level-ups only)")

	# 14c. the pigeonhole proof in motion: worst-case cheapest-first buying is
	# NEVER stranded by a level gate, all the way to the end of the map
	var sim_ul := {}
	var sim_earned := 0
	var strand := false
	var all_spots := 0
	for zc in G.MAPS.size():
		all_spots += G.MAPS[zc].spots.size()
	while sim_ul.size() < all_spots:
		var lvl_now := G.level_for_stars(sim_earned)
		var pick_z := -1
		var pick_k := -1
		var pick_cost := 99
		for z5 in G.MAPS.size():
			var map_missing := false
			for k5 in G.MAPS[z5].spots.size():
				if sim_ul.has(String(G.MAPS[z5].spots[k5].id)):
					continue
				map_missing = true
				if G.spot_level_req(z5, k5) <= lvl_now and int(G.MAPS[z5].spots[k5].cost) < pick_cost:
					pick_cost = int(G.MAPS[z5].spots[k5].cost)
					pick_z = z5
					pick_k = k5
			if map_missing:
				break                          # maps open sequentially
		if pick_z < 0:
			strand = true
			break
		sim_ul[String(G.MAPS[pick_z].spots[pick_k].id)] = true
		sim_earned += pick_cost                  # worst case: earn exactly what you spend
	ok(not strand, "level gates never strand the map (worst-case order, earn==spend, all 40 spots)")

	# a fresh Home resumes the same progress
	var h2 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h2)
	if h2.content == null:
		h2._ready()
	ok(h2.map_spots_done(0), "home progress persists across scenes")

	# 15. P5 — sell anything, diamonds, FTUE staging
	fresh("p5")
	var s5 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s5)
	if s5.board == null:
		s5._ready()
	# FTUE: the intro pops are free; once they're spent the meter begins. A tap now throws a
	# BURST (1-3 items), so drive the boundary by the pop count and assert the charge tracks the
	# burst size — each popped item is one energy. Clear a few cells for the burst to fill.
	for cc in [Vector2i(3, 2), Vector2i(3, 4), Vector2i(3, 3), Vector2i(4, 2), Vector2i(2, 2)]:
		s5.board.take(cc)
	s5._rebuild_pieces()
	Save.grove()["pops"] = 0
	s5.water = G.WATER_CAP
	s5._pop_seed()                            # an intro pop — still free
	await create_timer(0.25).timeout
	ok(s5.water == G.WATER_CAP, "the FTUE intro pops are free (the verb before the meter)")
	Save.grove()["pops"] = 20                 # well past the 10 free intro pops → the meter is on
	s5.water = G.WATER_CAP
	var ftue_b := 0
	for v in s5.board.items:
		if v > 0:
			ftue_b += 1
	s5._pop_seed()
	await create_timer(0.25).timeout
	var ftue_n := -ftue_b
	for v in s5.board.items:
		if v > 0:
			ftue_n += 1
	ok(ftue_n >= 1 and s5.water == G.WATER_CAP - ftue_n * G.POP_COST, "past the FTUE the meter charges one energy per burst item")
	ok(s5.merchant_chip == null, "the merchant waits for the first spot (chapter 1)")

	# sell anything: a t3 flower pays 3 coins and leaves the board
	Save.grove()["unlocks"] = {String(G.MAPS[0].spots[0].id): true}
	Save.grove_write()
	s5._rebuild_givers()
	ok(s5.merchant_chip != null, "the merchant arrives with chapter 1")
	s5.board.place(Vector2i(3, 3), 103)
	s5._rebuild_pieces()
	var c0 := Save.coins()
	s5._sell_item(Vector2i(3, 3), s5.piece_nodes.get(Vector2i(3, 3)))
	ok(Save.coins() == c0 + 3 and s5.board.item_at(Vector2i(3, 3)) == 0, \
		"selling a t3 pays 3 coins and clears the cell")
	ok(G.sell_value(108) == 8 and G.sell_value(201) == 1, "sell value scales with tier")

	# T39: per-map sell COIN band (§6/§9) — later maps sell t1–t7 for more coins; t8 stays a
	# flat 1💎 on EVERY map (the 32× anti-arbitrage pinnacle). Only the t1–t7 coin reward scales.
	# The band is a grove number (owner/sim-tuned), keyed by the item's map (0-indexed maps 1–5).
	var band := G.SELL_MAP_BAND
	ok(band.size() == G.MAPS.size(), "T39: the sell band has one entry per map (%d)" % G.MAPS.size())
	var band_mono := true
	for bi in range(1, band.size()):
		if float(band[bi]) <= float(band[bi - 1]):
			band_mono = false
	ok(band_mono and float(band[0]) >= 1.0, "T39: the per-map band rises monotonically across maps 1–5 (≥1.0 at map 1)")
	# map resolution: code → line → generator → its map. Sample lines spanning maps 0..4.
	ok(G.map_for_line(1) == 0 and G.map_for_line(4) == 0, "T39: map-1 lines (Wildflower/Honey) resolve to map 0")
	ok(G.map_for_line(5) == 1 and G.map_for_line(8) == 1, "T39: map-2 lines (Egg/Wool) resolve to map 1")
	ok(G.map_for_line(12) == 2, "T39: a map-3 line (Fish) resolves to map 2")
	ok(G.map_for_line(16) == 3 and G.map_for_line(24) == 4, "T39: map-4/5 lines (Plum/Poppy) resolve to maps 3/4")
	ok(G.map_for_code(1205) == 2, "T39: map_for_code derives the line then the map (Fish t5 → map 2)")
	# t1–t7 reward == round(tier_coins × band[map]); checked across every line, every sub-top tier.
	var band_ok := true
	var t8_flat := true
	for line in G.LINES:
		var lm: int = G.map_for_line(int(line))
		var lb: float = float(band[lm])
		for tier in range(1, G.TOP_TIER):
			var code: int = int(line) * 100 + tier
			var want_coins: int = int(round(maxi(1, tier) * lb))
			var rw: Vector2i = G.sell_reward(code)
			if rw != Vector2i(want_coins, 0):
				band_ok = false
		var top_rw: Vector2i = G.sell_reward(int(line) * 100 + G.TOP_TIER)
		if top_rw != Vector2i(0, 1):
			t8_flat = false
	ok(band_ok, "T39: every t1–t7 reward == round(tier coins × the line's map band)")
	ok(t8_flat, "T39: a t8 sells for EXACTLY 1💎 (no coins) on every line/map — the flat pinnacle (32× proof)")
	# concrete worked examples (map 0 band == 1.0 keeps the FTUE-era proofs exact)
	ok(G.sell_reward(103) == Vector2i(3, 0), "T39: a map-1 t3 (band 1.0) still sells for exactly 3🪙")
	ok(G.sell_reward(105) == Vector2i(5, 0), "T39: a map-1 t5 (band 1.0) still sells for exactly 5🪙")
	ok(G.sell_reward(2405) == Vector2i(int(round(5 * float(band[4]))), 0), \
		"T39: a map-5 t5 (band %.1f) sells for %d🪙 (later map → more coins)" % [float(band[4]), int(round(5 * float(band[4])))])

	# diamonds: accessors + paid rain once the freebies are spent
	ok(Save.diamonds() == 0, "diamonds default 0")
	Save.add_diamonds(30)
	s5.refills_used = G.FREE_REFILLS
	s5.water = 0
	s5._update_water_hud()
	ok(s5.refill_btn.visible, "paid rain offered when diamonds suffice")
	s5._on_refill()
	ok(s5.water == G.WATER_CAP and Save.diamonds() == 30 - G.REFILL_DIAMOND_COST, \
		"paid rain fills the cap and spends diamonds")

	# §5 bag: 6 owned slots at start, +1 per 💎 buy up to 18. The bar renders one button per owned
	# slot PLUS a trailing "+slot" buy affordance while below the cap (so owned 6 → 7 buttons).
	ok(s5._bag_capacity() == 6, "the bag starts at six owned slots")
	ok(s5.bag_slots_ui.size() == 7, "the bar renders the 6 owned slots plus the +slot buy button")
	var slots0 := Save.bag_slots()
	var price := G.next_bag_slot_price(slots0)
	Save.add_diamonds(price)
	var dia0 := Save.diamonds()
	s5._buy_bag_slot()
	ok(Save.bag_slots() == slots0 + 1 and Save.diamonds() == dia0 - price, \
		"buying the 7th slot grows the owned count and spends its 💎 price")
	ok(s5._bag_capacity() == 7 and s5.bag_slots_ui.size() == 8, \
		"the bought slot shows up in the capacity and the rebuilt bar (7 owned + buy)")
	# a broke buy is refused — no slot, no charge
	Save.spend_diamonds(Save.diamonds())      # drain the wallet
	var slots1 := Save.bag_slots()
	s5._buy_bag_slot()
	ok(Save.bag_slots() == slots1, "a broke slot-buy is refused (premium is convenience, never a wall)")

	# at the 18 cap the +slot affordance is gone: 18 buttons, no trailing buy slot.
	Save.set_bag_slots(18)
	s5._build_bag_bar()
	ok(s5.bag_slots_ui.size() == 18 and not s5._bag_has_buy_slot(), \
		"at the 18-slot cap the bar shows 18 slots and drops the +slot buy affordance")
	Save.set_bag_slots(6)                      # restore for the drag-back check below
	s5._build_bag_bar()

	# §5 drag-back retrieve: a bagged item returns to the board by being dropped on a cell.
	s5.bag = [104]                            # one t4 flower waiting in the bag
	s5._rebuild_bag()
	var dest := Vector2i(3, 3)
	s5.board.take(dest)                       # make sure the target cell is empty ground
	s5._rebuild_pieces()
	s5._retrieve_from_bag(0, dest)
	ok(s5.board.item_at(dest) == 104 and s5.bag.is_empty(), \
		"dragging a bagged item onto an empty cell places it and empties that bag slot")

	# home grants: a level-up pays diamonds too
	var h5 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h5)
	if h5.content == null:
		h5._ready()
	var d0 := Save.diamonds()
	var vault0 := Vault.balance() * Vault.skim_den() + Save.vault_carry()   # total skimmed-units before
	Save.grove()["stars_earned"] = G.stars_at_level(2) - 1     # one star short of L2
	G.earn_stars(1)                                            # crosses into L2
	ok(Save.diamonds() == d0 + G.LEVEL_DIAMONDS, "a level-up pays diamonds")
	# T44 SKIM-SITE wiring (content.earn_stars): the piggy bank skimmed a slice of the
	# level-up premium — the banked-units pool advanced by exactly LEVEL_DIAMONDS × num.
	var vault1 := Vault.balance() * Vault.skim_den() + Save.vault_carry()
	ok(vault1 - vault0 == G.LEVEL_DIAMONDS * Vault.skim_num(), "a level-up SKIMS its premium into the piggy bank (§10)")

	# 16. the discovery log + the upgrade-path card (tap an item → its ladder;
	# unseen tiers stay "?")
	fresh("ladder")
	var s6 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s6)
	if s6.board == null:
		s6._ready()
	var lad: Array = s6._ladder_entries(1)
	ok(lad.size() == G.TOP_TIER, "the ladder lists every tier of the line")
	ok(bool(lad[0].seen) and not bool(lad[1].seen), "starters are known; tier 2 still a mystery")
	var h6: Vector2 = Vector2(s6.csz, s6.csz) / 2.0
	s6._on_press(s6._cell_pos(Vector2i(3, 2)) + h6)
	s6._on_release(s6._cell_pos(Vector2i(3, 4)) + h6)
	await create_timer(0.3).timeout
	ok(bool(s6._ladder_entries(1)[1].seen), "merging writes the produced tier into the log")
	ok(not bool(s6._ladder_entries(3)[0].seen), "an undebuted line stays fully unknown")
	var kids0: int = s6.get_child_count()
	s6._open_ladder(1, 2)
	ok(s6.get_child_count() == kids0 + 1, "the upgrade-path card opens over the board")
	var persisted: Dictionary = Save.grove().get("seen", {})
	ok(persisted.has("102"), "the discovery log persists in the save")

	# 17. the Shop: diamond packs grant, cash confirm grants directly (no rails yet)
	fresh("shop")
	var Shop = load("res://engine/scripts/ui/shop.gd")
	ok(not Shop.buy_coin_pack(), "the coin pack refuses without diamonds")
	Save.add_diamonds(30)
	var coins_before := Save.coins()
	ok(Shop.buy_coin_pack(), "the coin pack sells")
	ok(Save.coins() == coins_before + Shop.COIN_PACK and Save.diamonds() == 30 - Shop.COIN_PACK_GEM_COST, \
		"coin pack: -%d💎 +%d🪙" % [Shop.COIN_PACK_GEM_COST, Shop.COIN_PACK])
	# T43: the FIRST ladder pack is doubled (first-purchase offer — covered in order-T);
	# spend it first so this asserts the STEADY-STATE direct grant (×1).
	Save.set_first_purchase_made()
	var gems_before := Save.diamonds()
	Shop.grant_cash_pack(0)
	ok(Save.diamonds() == gems_before + int(Shop.CASH_PACKS[0].gems), \
		"confirming a cash pack adds the diamonds directly")
	ok(Shop.buy_water() and Save.diamonds() == gems_before + int(Shop.CASH_PACKS[0].gems) - G.REFILL_DIAMOND_COST, \
		"the water purchase spends its diamonds (price = G.REFILL_DIAMOND_COST)")
	var s7 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s7)
	if s7.board == null:
		s7._ready()
	var kids7: int = s7.get_child_count()
	Shop.open(s7, {})
	ok(s7.get_child_count() == kids7 + 1, "the storefront opens over the board")
	# the water row appears ONLY when the host can grant water
	var rows_plain := _shop_rows(s7)
	Shop.open(s7, {"water_grant": func() -> void: pass})
	var rows_water := _shop_rows(s7)
	ok(rows_water == rows_plain + 1, "the water row appears only with a water_grant (%d -> %d)" % [rows_plain, rows_water])
	# T40: the storefront now carries the Featured rotation band — its pressable offer
	# cards are part of the buy-card count (coin pouch + SHOP_ROTATION_COUNT featured +
	# the cash packs), so the storefront is no longer a fixed water+coin+cash layout.
	var DataUi = load("res://games/active.gd").DATA
	ok(rows_plain >= int(DataUi.SHOP_ROTATION_COUNT) + 1, \
		"the storefront features the rotating offers band (%d cards ≥ %d featured + pouch)" % \
		[rows_plain, int(DataUi.SHOP_ROTATION_COUNT)])

	# 18. the HUD module: same labels, same pixels, in BOTH scenes
	var h7 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h7)
	if h7.content == null:
		h7._ready()
	var kids_h7: int = h7.get_child_count()
	Shop.open(h7, {})
	ok(h7.get_child_count() == kids_h7 + 1, "the storefront opens over the home map too")
	ok(s7.stars_label != null and s7.coins_label != null and s7.diamonds_label != null, \
		"the board's HUD labels exist")
	ok(h7.stars_label != null and h7.coins_label != null, "home's HUD labels exist")
	Save.add_stars(3)
	h7._update_hud()
	await create_timer(0.6).timeout            # numbers TICK toward the target (§6)
	ok(h7.stars_label.text == str(Save.stars()), "the module refresh keeps the wallet live (ticked)")
	var p_grove: Control = s7.stars_label.get_parent().get_parent()
	var p_home: Control = h7.stars_label.get_parent().get_parent()
	ok(p_grove.offset_top == p_home.offset_top and p_grove.offset_right == p_home.offset_right, \
		"the wallet panel sits at IDENTICAL offsets in both scenes")
	# R1: the plank wraps the WHOLE cluster — even (symmetric) padding, the row
	# (store basket + ★/🪙/💧) fully inside (rect guard; the crop is the eye proof)
	await create_timer(0.05).timeout            # let the panel lay out
	var row_home: Control = h7.stars_label.get_parent()
	assert_wraps(p_home, row_home, 10.0, 4.0, "R1 wallet")
	var store_btn: Control = row_home.get_child(0)
	ok(p_home.get_global_rect().grow(-4.0).encloses(store_btn.get_global_rect()), \
		"R1: the store button sits fully inside the plank")

	# 19. order L — ambient life + weather
	fresh("ambient")
	var Ambient = load("res://engine/scripts/ui/ambient.gd")
	ok(G.completed_maps({}) == 0, "no maps done on a fresh save")
	var full0 := {}
	for sp0 in G.MAPS[0].spots:
		full0[String(sp0.id)] = true
	ok(G.completed_maps(full0) == 1 and G.character_count(full0) == 2, \
		"character count = 1 + completed maps")
	var alayer: Control = Ambient.build_layer(Vector2(1000, 1000), G.character_count(full0))
	ok(alayer.get_child_count() == 2, "the layer carries that many characters")
	ok(_all_ignore(alayer), "spirits never eat input")
	alayer.free()
	var ga := Save.grove()
	ga["winback_until"] = Time.get_unix_time_from_system() + 60.0
	ok(Ambient.weather_now(false) == "rain", "the win-back minute rains")
	ok(Ambient.weather_now(true) == "breeze", "calm mode WINS: breeze, never rain")
	Ambient.forced_weather = "snow"
	ok(Ambient.weather_now(true) == "snow", "shot tools can force a state")
	Ambient.forced_weather = ""
	var h8 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h8)
	if h8.content == null:
		h8._ready()
	ok(h8.content.get_node_or_null("AmbientLayer") != null, "the map carries the spirit layer")
	ok(h8.get_node_or_null("WeatherLayer") != null, "the map carries the weather layer")
	ok(_all_ignore(h8.content), "the map guard stays green with spirits wandering")
	var s8 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s8)
	if s8.board == null:
		s8._ready()
	ok(s8.get_node_or_null("AmbientLayer") != null and s8.get_node_or_null("WeatherLayer") != null, \
		"the board carries both layers (sparse band)")

	# 20. order N — feature flags: all-ON is proven by the whole sweep (zero
	# behavior change); two flip smokes prove the guards actually disconnect
	var Features = load("res://engine/scripts/core/features.gd")
	ok(Features.on("idle_hint") and Features.on("nonexistent_flag_xyz"), \
		"known flags read true; unknown ids warn + default ON (typo-proof)")
	Features.FLAGS["idle_hint"] = false
	ok(s8._hint_pair().is_empty(), "idle_hint OFF: _hint_pair returns [] and wiggles nothing")
	Features.FLAGS["idle_hint"] = true
	fresh("flagpop")
	Features.FLAGS["ftue_free_pops"] = false
	var s9 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s9)
	if s9.board == null:
		s9._ready()
	s9.board.take(Vector2i(3, 2))             # a virgin board has 2 empties — make room
	s9._rebuild_pieces()
	var s9b := 0
	for v in s9.board.items:
		if v > 0:
			s9b += 1
	s9._pop_seed()
	await create_timer(0.25).timeout
	var s9n := -s9b
	for v in s9.board.items:
		if v > 0:
			s9n += 1
	ok(s9n >= 1 and s9.water == G.WATER_CAP - s9n * G.POP_COST, "ftue_free_pops OFF: the FIRST pop costs water (no free intro)")
	Features.FLAGS["ftue_free_pops"] = true

	# 21. R4 — sweep the composited UI with the pixel-right asserts. Each element
	# now has PERMANENT rect coverage (the law's durable value); a failure here is
	# a real misalignment to fix. (wallet was R1; map pin R2.)
	fresh("r4")
	# water chip (board, top-left) — reveal past the FTUE stage, then assert it wraps
	var sb4 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sb4)
	if sb4.board == null:
		sb4._ready()
	Save.grove()["pops"] = 10                 # FTUE done → the water chip shows
	sb4._update_water_hud()
	await create_timer(0.05).timeout
	var wchip: Control = sb4.water_label.get_parent().get_parent()
	var wrow: Control = sb4.water_label.get_parent()
	assert_wraps(wchip, wrow, 5.0, 4.0, "R4 water chip")
	# level chip (home, top-left)
	var h4 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h4)
	if h4.content == null:
		h4._ready()
	await create_timer(0.05).timeout
	# the level number now nests inside a sprout-avatar Control, so walk up to the
	# pill (PanelContainer) and assert it wraps its content row evenly.
	var lchip: Control = h4.level_label
	while lchip != null and not (lchip is PanelContainer):
		lchip = lchip.get_parent()
	var lrow4: Control = lchip.get_child(0)
	assert_wraps(lchip, lrow4, 5.0, 2.0, "R4 level chip")     # ±2: catches lopsided margins
	# map spot pin (an unowned, fresh-save spot) — the price pin wraps its row (S7
	# nests pins in a centered stack, so search the subtree, and FAIL loudly if absent)
	await create_timer(0.05).timeout
	var pin_panel: Control = null
	for hit in h4.spot_hits:
		var node: Control = hit.node
		var found: Array = node.find_children("*", "PanelContainer", true, false)
		if not found.is_empty():
			pin_panel = found[0]
			break
	ok(pin_panel != null and pin_panel.get_child_count() > 0, "R4/S7: a map spot price pin exists")
	if pin_panel != null and pin_panel.get_child_count() > 0:
		assert_wraps(pin_panel, pin_panel.get_child(0), 4.0, 4.0, "R4 spot pin")

	# 22. U1 — item backing (contrast): ON puts a soft dark ellipse UNDER the item
	# (first child = bottom); OFF leaves the item bare. Flag item_backing.
	Features.FLAGS["item_backing"] = true
	var pc_on: Control = sb4._make_piece(101, 100.0)
	ok(pc_on.get_child(0) is TextureRect and pc_on.get_child(0).modulate.a < 0.5, \
		"item_backing ON: a soft low-alpha ellipse sits under the item")
	ok(_all_ignore(pc_on), "U1: the backing never eats input")
	Features.FLAGS["item_backing"] = false
	var pc_off: Control = sb4._make_piece(101, 100.0)
	ok(pc_off.get_child(0).modulate.a > 0.9, "item_backing OFF: the item is bare (no backing)")
	Features.FLAGS["item_backing"] = true   # AF3: ON is the default (now a contact shadow)

	# 23. P — drag-to-swap two unlocked items (flag drag_swap)
	# P1: the model — swap trades codes, a coin swaps like anything, it persists
	var pb := BoardModel.new()
	var pa := Vector2i(4, 4)
	var pbc := Vector2i(4, 5)
	pb.terrain[BoardModel.idx(pa)] = 0
	pb.terrain[BoardModel.idx(pbc)] = 0
	pb.place(pa, 101)
	pb.place(pbc, 203)
	pb.swap(pa, pbc)
	ok(pb.item_at(pa) == 203 and pb.item_at(pbc) == 101, "P1: swap trades two item codes")
	var pcoin := G.COIN_LINE * 100 + 1
	pb.place(pa, pcoin)
	pb.swap(pa, pbc)                          # pbc held 101
	ok(pb.item_at(pa) == 101 and pb.item_at(pbc) == pcoin, "P1: a coin swaps like any item")
	var pb2 := BoardModel.new()
	pb2.from_dict(pb.to_dict())
	ok(pb2.item_at(pa) == 101 and pb2.item_at(pbc) == pcoin, "P1: to_dict/from_dict preserves the swapped board")

	# P2: the drop chain (real _on_press → _on_release drives)
	fresh("pswap")
	Features.FLAGS["drag_swap"] = true
	var sp = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sp)
	if sp.board == null:
		sp._ready()
	var phalf: Vector2 = Vector2(sp.csz, sp.csz) / 2.0
	var es: Array = sp.board.empty_ground_cells()
	var c1 := Vector2i(es[0])
	var c2 := Vector2i(es[1])
	# occupied-different → swap; BOTH piece_nodes update
	sp.board.place(c1, 101)
	sp.board.place(c2, 203)
	sp._rebuild_pieces()
	sp._on_press(sp._cell_pos(c1) + phalf)
	sp._on_release(sp._cell_pos(c2) + phalf)
	ok(sp.board.item_at(c1) == 203 and sp.board.item_at(c2) == 101, "P2: occupied-different target → swap")
	ok(sp.piece_nodes.has(c1) and sp.piece_nodes.has(c2), "P2: piece_nodes updated for BOTH cells")
	# same-code → MERGE keeps precedence (never swaps)
	sp.board.place(c1, 101)
	sp.board.place(c2, 101)
	sp._rebuild_pieces()
	sp._on_press(sp._cell_pos(c1) + phalf)
	sp._on_release(sp._cell_pos(c2) + phalf)
	ok(sp.board.item_at(c2) == 102 and sp.board.item_at(c1) == 0, "P2: same-code drop MERGES (precedence over swap)")
	# flag OFF → snap-back, nothing swaps
	Features.FLAGS["drag_swap"] = false
	sp.board.place(c1, 101)
	sp.board.place(c2, 203)
	sp._rebuild_pieces()
	sp._on_press(sp._cell_pos(c1) + phalf)
	sp._on_release(sp._cell_pos(c2) + phalf)
	ok(sp.board.item_at(c1) == 101 and sp.board.item_at(c2) == 203, "P2: drag_swap OFF → snap-back (no swap)")
	Features.FLAGS["drag_swap"] = true
	# drop on a generator cell → snap-back (never swaps with a generator)
	var gcell := Vector2i(G.GEN_CELL)
	sp.board.place(c1, 101)
	sp._rebuild_pieces()
	sp._on_press(sp._cell_pos(c1) + phalf)
	sp._on_release(sp._cell_pos(gcell) + phalf)
	ok(sp.board.item_at(c1) == 101, "P2: drop on a generator cell → snap-back")

	# 24. T — the Decorate jump goes to the MAP the player was decorating (NEW model:
	# decorate_map opens that MAP, not an interior). Boot lands ON a map view.
	var HomeScript = load("res://engine/scripts/scenes/map.gd")
	# T1: opening a map persists last_map
	fresh("tlast")
	var ht = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(ht)
	if ht.content == null:
		ht._ready()
	ht._open_map(0)
	ok(String(Save.grove().get("last_map", "")) == "farmhouse", "T1: opening a map persists last_map")
	# T1: sanitize — an unknown last_map never survives a boot. _load_state drops it,
	# then the boot opens the frontier and re-records a VALID map id in its place.
	Save.grove()["last_map"] = "atlantis"
	var ht2 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(ht2)
	if ht2.content == null:
		ht2._ready()
	ok(G.map_for_id(String(Save.grove().get("last_map", ""))) >= 0, \
		"T1: an unknown last_map is scrubbed on load (boot re-records a valid map)")
	ok(ht2._view == "map", "T1: fresh arrival (no jump request) lands on a map view")
	# T2: the Decorate jump — opens the named map directly, NO map-select flash
	# (asserted before any frame), and the request is one-shot
	HomeScript.decorate_map = "farmhouse"
	var ht3 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(ht3)
	if ht3.content == null:
		ht3._ready()
	ok(ht3._view == "map" and ht3._map_idx == 0, \
		"T2: Decorate opens the named map directly (asserted pre-frame: no select flash)")
	ok(HomeScript.decorate_map == "", "T2: the jump request is one-shot (consumed)")
	# T2: an unknown jump request falls through to the frontier map
	HomeScript.decorate_map = "atlantis"
	var ht4 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(ht4)
	if ht4.content == null:
		ht4._ready()
	ok(ht4._view == "map", "T2: an unknown jump request falls through to the frontier map")

	# 25. order O — music degrades SILENTLY on a BARE engine. Audio is skin and the
	# real takes are archived, so ensure() must be a quiet no-op (never create a
	# player to crash on). The full A/B playlist-alternation logic ships + is tested
	# WITH the audio skin (needs takes on disk); here we only guard the engine never
	# crashes/hangs without it. (T16: this test used to assume real music on disk.)
	var Music = load("res://engine/scripts/core/music.gd")
	fresh("omusic")
	Music.stop()
	Music.ensure()
	ok(Music._player == null or not Music._player.playing, "O: no audio skin → ensure() is a silent no-op (no crash/hang)")
	Save.set_setting("music", false)
	Music.refresh()
	ok(Music._player == null or not Music._player.playing, "O: music Off → refresh() leaves the bed silent")
	Save.set_setting("music", true)
	Music.stop()
	Music.take_dir = "res://assets/nonexistent/"
	Music.ensure()
	ok(Music._player == null or not Music._player.playing, "O: zero takes on disk → ensure() is a silent no-op (no crash)")
	Music.take_dir = "res://assets/music/"
	ok(Music._takes().size() == 0, "O: audio skin archived → no takes resolve (bare engine)")

	# 26. order S — placement asserts (S1 bottom bar · S4 chips never clip)
	fresh("sui")
	var ss = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(ss)
	if ss.board == null:
		ss._ready()
	await create_timer(0.05).timeout
	var vp: Rect2 = ss.get_viewport_rect()
	ok(vp.encloses(ss.bottom_bar.get_global_rect()), "S1: the bottom bar sits fully on-screen")
	var bb_row: Control = ss.bottom_bar.get_child(0)
	var bb_home: Control = bb_row.get_child(0)
	ok(ss.bottom_bar.get_global_rect().grow(-2.0).encloses(bb_home.get_global_rect()), \
		"S1: the Home button sits fully inside the plank (was half-clipped)")
	var bb_shop: Control = bb_row.get_child(1)
	ok(ss.bottom_bar.get_global_rect().grow(-2.0).encloses(bb_shop.get_global_rect()), \
		"S1: the shop button sits fully inside the plank")
	assert_wraps(ss.bottom_bar, bb_row, 6.0, 4.0, "S1 bottom bar")
	# S4: every chip fully on-screen, both scenes (refill asserts when visible)
	Save.grove()["pops"] = 10
	ss._update_water_hud()
	await create_timer(0.05).timeout
	var wchip4: Control = ss.water_label.get_parent().get_parent()
	ok(vp.encloses(wchip4.get_global_rect()), "S4: the water chip sits fully on-screen (board)")
	ok(vp.encloses(ss.stars_label.get_parent().get_parent().get_global_rect()), \
		"S4: the wallet sits fully on-screen (board)")
	ok(vp.encloses(ss.level_label.get_parent().get_parent().get_global_rect()), \
		"S4/S10: the Lv chip sits fully on-screen (board — the module ships it to BOTH scenes)")
	ok(not wchip4.get_global_rect().intersects(ss.level_label.get_parent().get_parent().get_global_rect()), \
		"S4: the water chip and the Lv chip do NOT overlap (owner 2026-06-12)")
	var hs = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hs)
	if hs.content == null:
		hs._ready()
	await create_timer(0.05).timeout
	ok(hs.get_viewport_rect().encloses(hs.level_label.get_parent().get_parent().get_global_rect()), \
		"S4: the Lv chip sits fully on-screen (home)")
	ok(hs.get_viewport_rect().encloses(hs.stars_label.get_parent().get_parent().get_global_rect()), \
		"S4: the wallet sits fully on-screen (home)")

	# S2: the chapter title rides a CENTERED ribbon chip (was floating plain text)
	var s2_ribbon: Control = ss.chapter_label.get_parent()
	ok(absf(s2_ribbon.get_global_rect().get_center().x - vp.get_center().x) <= 6.0, \
		"S2: the chapter ribbon is centered on screen (dx=%.1f)" % (s2_ribbon.get_global_rect().get_center().x - vp.get_center().x))
	assert_centered(s2_ribbon, ss.chapter_label, "h", 4.0, "S2 chapter label on its ribbon")

	# S2/S6 regression guards: the chapter chip AND buttons must be SOLID pills —
	# the kit nine-patches (ribbon_title / btn_leaf) collapse invisibly at chip and
	# button heights (margins > the rect), which is how both shipped as floating text.
	ok(s2_ribbon.get_theme_stylebox("panel") is StyleBoxFlat, \
		"S2: the chapter chip is a solid pill (not the collapsing ribbon_title nine-patch)")
	var _skin = load("res://engine/scripts/ui/skin.gd")
	var _pbtn: Button = _skin.button("X", Callable(), true)
	ok(_pbtn.get_theme_stylebox("normal") is StyleBoxFlat, \
		"S6: primary buttons are solid pills (not the collapsing btn_leaf nine-patch)")
	ok(_pbtn.get_theme_constant("outline_size") == 0, \
		"S6: button labels carry no world-outline on the solid pill (panel-text law)")
	_pbtn.queue_free()
	var _sbtn: Button = _skin.button("Y", Callable(), false)
	ok(_sbtn.get_theme_stylebox("normal") is StyleBoxFlat, "S6: secondary buttons are solid pills too")
	ok(_sbtn.alignment == HORIZONTAL_ALIGNMENT_CENTER, "S6: button labels center in the pill")
	_sbtn.queue_free()

	# S4: the rain-refill chip never clips (it shipped as a half-off-screen sliver)
	ss.water = 0
	ss._update_water_hud()
	await create_timer(0.05).timeout
	ok(ss.refill_btn.visible, "S4: the refill offer shows when water is empty")
	ok(vp.encloses(ss.refill_btn.get_global_rect()), "S4: the refill button sits fully on-screen (was a sliver)")
	ss.water = G.WATER_CAP
	ss._update_water_hud()

	# S1: nothing clips at the TALLER aspect either (owner named 1080×1920 + 1080×2340)
	get_root().size = Vector2i(1080, 2340)
	await create_timer(0.06).timeout
	var vp2: Rect2 = ss.get_viewport_rect()
	ok(absf(vp2.size.y - 2340.0) < 2.0, "S1: viewport actually grew to the tall aspect (got %.0f)" % vp2.size.y)
	ok(vp2.encloses(ss.bottom_bar.get_global_rect()), "S1: bottom bar fully on-screen at 1080×2340")
	ok(ss.bottom_bar.get_global_rect().grow(-2.0).encloses(ss.bottom_bar.get_child(0).get_child(1).get_global_rect()), \
		"S1: the shop button stays inside the plank at 1080×2340")
	get_root().size = Vector2i(1080, 1920)
	await create_timer(0.06).timeout

	# --- order W: board feel ----------------------------------------------------
	var ws = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(ws)
	if ws.board == null:
		ws._ready()
	await create_timer(0.05).timeout
	# W1: the idle merge hint comes SOONER and rocks gently (was 7s + a fast shake)
	ok(absf(float(ws.IDLE_HINT_SECS) - 4.5) < 0.01, "W1: first idle hint at 4.5s (was 7)")
	ok(int(ws.HINT_ROCK_CYCLES) >= 2 and float(ws.HINT_ROCK_DEG) <= 10.0, \
		"W1: the hint is a gentle multi-cycle rock, not a one-off fast shake")
	for cc in [Vector2i(1, 3), Vector2i(2, 3)]:
		ws.board.terrain[BoardModel.idx(cc)] = 0
		ws.board.place(cc, 101)
	ws._rebuild_pieces()
	ok(not ws._hint_pair().is_empty(), "W1: _hint_pair finds a mergeable pair to rock")
	# W2: rapid generator taps must NEVER be dropped by the animating gate. Open a
	# comfortable region, fire 5 board taps WITHOUT awaiting the 0.22s spawn flight.
	for wy in [1, 2, 4, 5]:                    # open a wide region so 5 bursts can never fill the board
		for wx in range(1, 8):
			var wc := Vector2i(wx, wy)
			ws.board.terrain[BoardModel.idx(wc)] = 0
			ws.board.items[BoardModel.idx(wc)] = 0
	ws._rebuild_pieces()
	var w_before := 0
	for v in ws.board.items:
		if v > 0:
			w_before += 1
	var ghalf := Vector2(ws.csz, ws.csz) / 2.0
	var gpos: Vector2 = ws._cell_pos(Vector2i(G.GEN_CELL)) + ghalf
	for i in 5:
		_tap_board(ws, gpos)
	var w_after := 0
	for v in ws.board.items:
		if v > 0:
			w_after += 1
	ok(w_after - w_before >= 5, \
		"W2: 5 rapid generator taps each land a burst — none eaten by the animating gate (≥5 items) — got %d" % (w_after - w_before))
	# W3: sell discoverability. (a) the first MAX-TIER item floats a one-time hint.
	var top_code := 100 + G.TOP_TIER
	Save.grove().erase("seen_sell_hint")
	var lbls0: int = ws.find_children("*", "Label", true, false).size()
	ws._note_item_landed(top_code)
	ok(bool(Save.grove().get("seen_sell_hint", false)), "W3: a max-tier landing sets the persisted seen flag")
	var lbls1: int = ws.find_children("*", "Label", true, false).size()
	ok(lbls1 > lbls0, "W3: the one-time sell hint floater appears on the first max-tier item")
	ws._note_item_landed(top_code)
	ok(ws.find_children("*", "Label", true, false).size() == lbls1, "W3: the sell hint never fires twice")
	# (b) the merchant brightens + shows a live +N🪙 tag while an item is dragged
	var Feat = load("res://engine/scripts/core/features.gd")
	Feat.FLAGS["ftue_staged_chrome"] = false
	ws._rebuild_givers()
	await create_timer(0.05).timeout
	ok(ws.merchant_chip != null, "W3: merchant present for the affordance test")
	ws._show_sell_affordance(top_code)
	ok(ws.merchant_sell_tag.visible and ws.merchant_chip.modulate.a >= 0.99, \
		"W3: dragging brightens the stall + shows the sell tag")
	# §13 (T32): the t8 reward reads as "+1" (pure ASCII, no emoji) beside a gem ICON
	# sprite — the currency is the swapped Look.icon, never a glyph baked into the text.
	ok(String(ws.merchant_sell_tag_label.text) == "+1", \
		"W3/Y1: the t8 sell tag number is pure-ASCII +1 (no emoji)")
	ok(ws.merchant_sell_tag_icon != null and ws.merchant_sell_tag_icon.has_meta("icon_id") \
		and String(ws.merchant_sell_tag_icon.get_meta("icon_id")) == "gem", \
		"W3/Y1: the t8 sell tag's currency sprite is swapped to the gem icon")
	ws._hide_sell_affordance()
	ok(not ws.merchant_sell_tag.visible, "W3: releasing the drag hides the sell tag")
	# T39 (§9): drag is the ONLY sell verb — the tap-sell path is GONE. The board no longer
	# defines _on_merchant_tap; tapping the stall does nothing (the basket buy-back + the
	# treat keep their own taps; drag-to-stall selling stays the live verb).
	ok(not ws.has_method("_on_merchant_tap"), "T39: tap-sell is removed — board has no _on_merchant_tap")
	# T39: the merchant pill reflects the REAL top-tier reward (t8 = 1💎), not a stale flat coin
	# count. The pill carries a gem icon + "+1", and shows no coin figure (MERCHANT_COINS is gone).
	var mp_lbls: Array = ws.merchant_chip.find_children("*", "Label", true, false)
	var mp_has_one := false
	for mpl in mp_lbls:
		if String((mpl as Label).text).find("1") != -1 and String((mpl as Label).text).find("25") == -1:
			mp_has_one = true
	ok(mp_has_one, "T39: the merchant pill reads the top-tier reward (+1), not the stale flat 25")
	var mp_has_gem := false
	for mpn in ws.merchant_chip.find_children("*", "", true, false):
		if mpn.has_meta("icon_id") and String(mpn.get_meta("icon_id")) == "gem":
			mp_has_gem = true
	ok(mp_has_gem, "T39: the merchant pill carries the gem pinnacle icon (icon_id=gem), not a coin")
	# X3: the giver pill renders one [item icon + n/m] pair PER ASK (1-3), no second card
	var x3_3: Dictionary = ws._make_giver_stand(0, {"asks": [
		{"line": 1, "tier": 3, "count": 1}, {"line": 2, "tier": 4, "count": 1},
		{"line": 3, "tier": 3, "count": 1}], "stars": 3})
	ok(x3_3.asks.size() == 3, "X3: a 3-ask quest renders 3 item pairs in one pill")
	var x3_1: Dictionary = ws._make_giver_stand(1, {"asks": [{"line": 1, "tier": 2, "count": 1}], "stars": 1})
	ok(x3_1.asks.size() == 1, "X3: a single-ask quest renders 1 pair")
	x3_3.chip.queue_free()
	x3_1.chip.queue_free()

	# XB (Tier 2 §2): the idle-bob carries readiness — ONLY a deliverable giver bobs.
	# A pure, asserted predicate (_giver_is_payable) gates both the ✓ and the bob, and
	# the gate is REACTIVE: it flips as the board gains/loses the asked items. We assert
	# the decision (the boolean) AND the effect (the live loop tween in the bob_tw meta).
	var xb_feat = load("res://engine/scripts/core/features.gd")
	xb_feat.FLAGS["giver_bob"] = true             # the bob is the thing under test
	# a clean board: clear every item, then build a single-ask giver wanting 2× code 102
	for r in G.ROWS:
		for c in G.COLS:
			if ws.board.is_open(Vector2i(r, c)):
				ws.board.place(Vector2i(r, c), 0)
	var xb_giver: Dictionary = ws._make_giver_stand(7, {"asks": [{"line": 1, "tier": 2, "count": 2}], "stars": 1})
	ws.add_child(xb_giver.chip)                    # in-tree so the bob can start immediately
	ws.giver_chips = [xb_giver]
	var bob_bust: Control = xb_giver.bust
	# helper: is a live (valid, running) loop tween parked on the bust?
	var bobbing := func(b: Control) -> bool:
		var tw: Variant = b.get_meta("bob_tw") if b.has_meta("bob_tw") else null
		return tw is Tween and (tw as Tween).is_valid()
	# (1) NOT payable (board holds zero 102) → no bob, ✓ hidden
	ws._refresh_giver_lights()
	ok(ws.board.count_of(102) == 0, "XB: board set up with the ask UNMET (0×102)")
	ok(not ws._giver_is_payable(xb_giver), "XB: an unmet quest is NOT payable")
	ok(not bobbing.call(bob_bust), "XB: a giver whose quest is NOT payable does NOT bob")
	ok(not xb_giver.check.visible, "XB: the ready ✓ is hidden while not payable (same predicate)")
	# (2) becomes payable (place the 2 asked items) → bob starts, ✓ shows
	var free_cells: Array = ws.board.empty_ground_cells()
	ws.board.place(free_cells[0], 102)
	ws.board.place(free_cells[1], 102)
	ws._refresh_giver_lights()
	ok(ws._giver_is_payable(xb_giver), "XB: the quest is payable once both asked items are present")
	ok(bobbing.call(bob_bust), "XB: a giver whose quest IS payable bobs (bob tween live)")
	ok(xb_giver.check.visible, "XB: the ready ✓ shows on the same payable transition")
	# (3) payable → unmet again (remove one item) → bob STOPS (reactive, not one-way)
	ws.board.place(free_cells[0], 0)
	ws._refresh_giver_lights()
	ok(not ws._giver_is_payable(xb_giver), "XB: removing an asked item makes it un-payable again")
	ok(not bobbing.call(bob_bust), "XB: the bob stops when the giver is no longer deliverable")
	xb_giver.chip.queue_free()
	ws.giver_chips = []

	Feat.FLAGS["ftue_staged_chrome"] = true
	ws.queue_free()

	# V1 (the locked-generator "after N spots" preview) is PARKED with T17: it was keyed on
	# the old per-chapter `appears_at`; under per-map generators the next set arrives on map
	# COMPLETION, so the preview needs redefining alongside §6/§7. Test removed with the feature.

	# --- order Y: selling v2 — the diamond pinnacle + the porter's basket --------
	fresh("y")
	var Feat2 = load("res://engine/scripts/core/features.gd")
	Feat2.FLAGS["ftue_staged_chrome"] = false   # merchant + basket present on a fresh board
	Feat2.FLAGS["porter_collect"] = false        # test the MECHANICS, not the drift animation
	var ys = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(ys)
	if ys.board == null:
		ys._ready()
	await create_timer(0.05).timeout
	ys._rebuild_givers()
	await create_timer(0.05).timeout
	ok(ys.basket_chip != null, "Y2: the merchant has a collection basket")
	# Y1: a t8 sells for exactly 1💎 (no coins); a t5 for 5🪙
	var yt8 := 100 + G.TOP_TIER
	var yd0: int = Save.diamonds()
	var yc0: int = Save.coins()
	ys._grant_sale(yt8, null)
	ok(Save.diamonds() == yd0 + 1 and Save.coins() == yc0, "Y1: a t8 sells for exactly 1💎, no coins")
	ys._grant_sale(105, null)
	ok(Save.coins() == yc0 + 5, "Y1: a t5 sells for 5🪙")
	ok(ys.basket.size() == 2, "Y2: sales land in the basket")
	# Y2: buy back the t8 — EXACT refund (the 1💎 returns), item back on a free cell
	var yd1: int = Save.diamonds()
	var yopen0: int = ys.board.empty_ground_cells().size()
	ys._buy_back(0)
	ok(Save.diamonds() == yd1 - 1, "Y2: buy-back refunds EXACTLY the 1💎 granted (no arbitrage)")
	ok(ys.board.empty_ground_cells().size() == yopen0 - 1, "Y2: the bought-back item returns to a free cell")
	ok(ys.basket.size() == 1, "Y2: the sale leaves the basket on buy-back")
	# Y2: a FULL board blocks buy-back (wobble, no refund, sale kept)
	for yfc in ys.board.empty_ground_cells():
		ys.board.place(yfc, 101)
	var ycfull: int = Save.coins()
	ys._buy_back(0)
	ok(Save.coins() == ycfull and ys.basket.size() == 1, "Y2: full-board buy-back is blocked (no refund, sale kept)")
	# Y2/Y3: a 4th sale overflows cap-3 → the porter collects at once
	ys.basket.clear()
	ys._rebuild_basket()
	for yi4 in 4:
		ys._record_sale(105, Vector2i(5, 0))
	ok(ys.basket.is_empty(), "Y2/Y3: a 4th sale overflows cap-3 → the porter collects (basket emptied)")
	# Y3: the timer collects after ~3 min (buy-back window closes)
	ys._record_sale(105, Vector2i(5, 0))
	ok(ys.basket.size() == 1, "Y3: a sale arms the porter timer")
	ys._porter_tick(ys.PORTER_SECS + 1.0)
	ok(ys.basket.is_empty(), "Y3: the porter collects the basket after ~3 min")
	Feat2.FLAGS["ftue_staged_chrome"] = true
	Feat2.FLAGS["porter_collect"] = true
	ys.queue_free()
	# Y4 invariant: the water↔diamond round trip loses >=10x — never a water pump
	ok(G.water_to_earn_diamond() >= 10 * G.water_a_diamond_buys(), \
		"Y4: water to EARN 1💎 (%d) >= 10x the water 1💎 BUYS (%d)" % [G.water_to_earn_diamond(), G.water_a_diamond_buys()])

	# --- order Z: the coin sink — spirit treats -----------------------------------
	# (Z1/Z2 wayside on-map decorations are RETIRED with the old free-pan overworld:
	# the NEW map model is one image with restoration spots, no on-map wayside plots —
	# G.waysides()/wayside_available/buy_wayside/_on_map_tap no longer exist.)
	var Feat3 = load("res://engine/scripts/core/features.gd")
	# Z3: spirit treats — a 10🪙 recurring sink. Spend deducts exactly, rapid-buy is
	# independent (graceful), and you can't overspend.
	fresh("z3")
	Feat3.FLAGS["spirit_treats"] = true
	var z3 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(z3)
	if z3.board == null:
		z3._ready()
	await create_timer(0.05).timeout
	Save.add_coins(40)
	var z3c0: int = Save.coins()
	z3._buy_treat()
	ok(Save.coins() == z3c0 - z3.TREAT_COST, "Z3: a treat costs exactly 10🪙")
	z3._buy_treat()
	z3._buy_treat()
	ok(Save.coins() == z3c0 - 3 * z3.TREAT_COST, "Z3: rapid treats each deduct independently (graceful)")
	Save.spend(Save.coins())                 # drain to 0
	z3._buy_treat()
	ok(Save.coins() == 0, "Z3: no treat without coins (no overspend)")
	z3.queue_free()

	# --- order S (T40): the Shop buy-side sinks — item-shortcuts, cosmetics, rotation ---
	# §10: the Shop sells item-shortcuts (buy a mid-tier piece to skip the grind),
	# cosmetics (looks), behind a FEW deterministically-rotating offers. Pure grant
	# funcs spend correctly, grant, and refuse when broke; rotation is seeded (testable).
	var ShopS = load("res://engine/scripts/ui/shop.gd")
	var Data = load("res://games/active.gd").DATA

	# S-A: the stock tables exist and are well-formed (owner-tunable grove numbers).
	fresh("shop_stock")
	ok(Data.SHOP_ITEM_OFFERS.size() >= 2, "the shop stocks item-shortcut offers")
	ok(Data.SHOP_COSMETICS.size() >= 2, "the shop stocks a cosmetic catalogue")
	ok(Data.SHOP_ROTATION_COUNT >= 1 and Data.SHOP_ROTATION_COUNT <= \
		Data.SHOP_ITEM_OFFERS.size() + Data.SHOP_COSMETICS.size(), \
		"the rotation shows a FEW offers (1..pool size)")
	for off in Data.SHOP_ITEM_OFFERS:
		var t := int(off.code) % 100
		ok(int(off.code) > 0 and t >= 2 and t < Data.TOP_TIER, \
			"item offer %s is a mid-tier piece (t%d, never a gate-only pinnacle)" % [off.id, t])
		var cur := String(off.currency)
		ok((cur == "coins" or cur == "diamonds") and int(off.cost) > 0, \
			"item offer %s costs %d %s" % [off.id, int(off.cost), cur])
	for cos in Data.SHOP_COSMETICS:
		ok(String(cos.id) != "" and int(cos.cost) > 0 and \
			(String(cos.currency) == "coins" or String(cos.currency) == "diamonds"), \
			"cosmetic %s costs %d %s" % [cos.id, int(cos.cost), cos.currency])

	# S-B: item-shortcut grant — spends the right currency, drops the piece into the
	# bag blob (the board drains it on open), and refuses when the wallet is short.
	fresh("shop_item_coin")
	var ci := -1
	for i in Data.SHOP_ITEM_OFFERS.size():
		if String(Data.SHOP_ITEM_OFFERS[i].currency) == "coins":
			ci = i
			break
	ok(ci >= 0, "there is a coin-priced item-shortcut (low tiers are coins, §10)")
	var coff: Dictionary = Data.SHOP_ITEM_OFFERS[ci]
	ok(not ShopS.buy_item_offer(ci), "the item-shortcut refuses when broke")
	ok(ShopS.pending_pieces().is_empty(), "...and grants no piece when it refuses")
	Save.add_coins(int(coff.cost) + 50)
	var coins_b := Save.coins()
	ok(ShopS.buy_item_offer(ci), "the coin item-shortcut sells once affordable")
	ok(Save.coins() == coins_b - int(coff.cost), "...spending exactly its coin cost")
	ok(ShopS.pending_pieces() == [int(coff.code)], "...and queues the piece into the bag blob")

	# a gem-priced (higher-tier) item-shortcut spends diamonds, never coins.
	fresh("shop_item_gem")
	var gi := -1
	for i in Data.SHOP_ITEM_OFFERS.size():
		if String(Data.SHOP_ITEM_OFFERS[i].currency) == "diamonds":
			gi = i
			break
	ok(gi >= 0, "there is a premium (gem) item-shortcut for higher tiers (§10)")
	var goff: Dictionary = Data.SHOP_ITEM_OFFERS[gi]
	ok(not ShopS.buy_item_offer(gi), "the gem item-shortcut refuses without diamonds")
	Save.add_diamonds(int(goff.cost) + 5)
	var gem_b := Save.diamonds()
	var gc0 := Save.coins()
	ok(ShopS.buy_item_offer(gi), "the gem item-shortcut sells with diamonds")
	ok(Save.diamonds() == gem_b - int(goff.cost) and Save.coins() == gc0, \
		"...spending diamonds only (premium buys speed, never coins)")

	# the live board drains the queued shortcut onto open ground on its next open.
	fresh("shop_item_board")
	Save.add_coins(int(coff.cost) + 10)
	ShopS.buy_item_offer(ci)
	var sb = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sb)
	if sb.board == null:
		sb._ready()
	ok(sb.bag.has(int(coff.code)), "the board picks the queued shortcut up into the bag on open")
	ok(ShopS.pending_pieces().is_empty(), "...and the pending queue is drained")
	sb.queue_free()

	# S-C: cosmetic grant — spends, unlocks the look, and refuses a second buy (own-once).
	fresh("shop_cosmetic")
	var cos0: Dictionary = Data.SHOP_COSMETICS[0]
	var cid := String(cos0.id)
	ok(not ShopS.cosmetic_owned(cid), "a cosmetic starts unowned")
	ok(not ShopS.buy_cosmetic(cid), "the cosmetic refuses when broke")
	if String(cos0.currency) == "coins":
		Save.add_coins(int(cos0.cost) + 5)
	else:
		Save.add_diamonds(int(cos0.cost) + 5)
	var cwc := Save.coins()
	var cwg := Save.diamonds()
	ok(ShopS.buy_cosmetic(cid), "the cosmetic sells once affordable")
	var spent_c := cwc - Save.coins()
	var spent_g := cwg - Save.diamonds()
	ok((spent_c == int(cos0.cost) and spent_g == 0) if String(cos0.currency) == "coins" \
		else (spent_g == int(cos0.cost) and spent_c == 0), "...spending exactly its price in its currency")
	ok(ShopS.cosmetic_owned(cid), "...and the look is now unlocked (persisted in grove)")
	var afterc := Save.coins()
	var afterg := Save.diamonds()
	ok(not ShopS.buy_cosmetic(cid), "buying an owned cosmetic is refused (own-once, no double-charge)")
	ok(Save.coins() == afterc and Save.diamonds() == afterg, "...and charges nothing the second time")

	# S-D: rotation determinism — same seed → same offers; advancing rotates them.
	fresh("shop_rotation")
	var r_a: Array = ShopS.rotation_offers(7)
	var r_a2: Array = ShopS.rotation_offers(7)
	ok(r_a.size() == Data.SHOP_ROTATION_COUNT, "the rotation surfaces exactly SHOP_ROTATION_COUNT offers")
	ok(_offer_ids(r_a) == _offer_ids(r_a2), "the same seed yields the SAME offers (deterministic, no randi)")
	# every rotated offer is a real stock entry (item or cosmetic), no duplicates.
	var ids_a := _offer_ids(r_a)
	ok(ids_a.size() == _uniq(ids_a).size(), "a rotation has no duplicate offers")
	# advancing the seed across a window of days rotates the featured set at least once.
	var changed := false
	for day in range(8, 40):
		if _offer_ids(ShopS.rotation_offers(day)) != ids_a:
			changed = true
			break
	ok(changed, "advancing the seed (day/refresh) rotates the featured offers")
	# the live storefront wires the rotation in (a new featured band of pressable cards).
	var s_seed: int = ShopS.rotation_seed()
	ok(s_seed >= 0, "the rotation seed is a non-negative day/refresh index")

	# T42 · §8/§10 home-hub yield + upgrade-levels (the v1 KEYSTONE coin loop) — own scope.
	_test_hub_yield()
	# T45 · the integration wiring: the 2×-collect doubler, the piggy-vault chrome entry, the
	# daily-login auto-popup — driven through the real Map scene. Own scope (its own fn).
	await _test_t45_wiring()
	# --- order T (T43): live-IAP ladder + starter + first-buy doubler + rewarded ads +
	# --- the out-of-water triggered offer. §4 law: premium & ads buy SPEED + LOOKS, never
	# --- POSSIBILITY — every wall is free-passable (slower); ads/offers are capped+cooled.
	var Ads = load("res://engine/scripts/core/ads.gd")

	# T-A: the cash ladder is a real, well-formed escalating curve up to a $49.99/$99.99
	# top, with 💎-per-dollar RISING up the ladder (the whale always gets the best rate).
	fresh("iap_ladder")
	ok(Data.CASH_PACKS.size() >= 5, "the cash ladder has many tiers (entry → whale ceiling)")
	var prev_rate := -1.0
	var top_price := 0.0
	for pk in Data.CASH_PACKS:
		var usd := float(String(pk.usd).substr(1))   # "$4.99" → 4.99
		var rate := float(int(pk.gems)) / usd
		ok(int(pk.gems) > 0 and usd > 0.0, "ladder tier %s grants %d💎" % [pk.usd, int(pk.gems)])
		ok(rate > prev_rate - 0.001, "ladder 💎/$ rises at %s (%.1f ≥ prev)" % [pk.usd, rate])
		prev_rate = rate
		top_price = maxf(top_price, usd)
	ok(top_price >= 49.99, "the ladder reaches a $49.99+/$99.99-class whale tier (%.2f)" % top_price)

	# T-B: each ladder tier grants exactly its 💎 (once the first-buy doubler is spent).
	fresh("iap_grant")
	Save.set_first_purchase_made()       # past the doubler — steady-state grants
	for ti in Data.CASH_PACKS.size():
		var before := Save.diamonds()
		var got: int = ShopS.grant_cash_pack(ti)
		ok(got == int(Data.CASH_PACKS[ti].gems), "tier %s grants exactly %d💎" % [Data.CASH_PACKS[ti].usd, int(Data.CASH_PACKS[ti].gems)])
		ok(Save.diamonds() == before + int(Data.CASH_PACKS[ti].gems), "...and the wallet ticks up by that much")

	# T-C: the first-purchase DOUBLER doubles the first ladder pack EXACTLY once, then stops.
	fresh("iap_first_buy")
	ok(ShopS.first_buy_doubled(), "a fresh player's first pack is doubled (the offer is live)")
	var fb_before := Save.diamonds()
	var fb_got: int = ShopS.grant_cash_pack(0)
	ok(fb_got == int(Data.CASH_PACKS[0].gems) * int(Data.FIRST_BUY_MULT), \
		"the FIRST pack grants ×%d (%d💎)" % [int(Data.FIRST_BUY_MULT), fb_got])
	ok(Save.diamonds() == fb_before + fb_got, "...credited in full")
	ok(not ShopS.first_buy_doubled(), "the doubler is now spent")
	var fb2_before := Save.diamonds()
	var fb2_got: int = ShopS.grant_cash_pack(0)
	ok(fb2_got == int(Data.CASH_PACKS[0].gems), "the SECOND pack grants ×1 (doubler does not re-fire)")
	ok(Save.diamonds() == fb2_before + int(Data.CASH_PACKS[0].gems), "...the steady-state amount")

	# T-D: the STARTER PACK is claimable exactly ONCE — grants 💎 + banks the water credit.
	fresh("iap_starter")
	ok(ShopS.starter_available(), "the starter pack is offered to a new player")
	var st_gem_b := Save.diamonds()
	var st_got: int = ShopS.grant_starter()
	ok(st_got == int(Data.STARTER_PACK.gems) and Save.diamonds() == st_gem_b + int(Data.STARTER_PACK.gems), \
		"the starter grants its %d💎" % int(Data.STARTER_PACK.gems))
	ok(Save.water_pending() == int(Data.STARTER_PACK.water), "...and banks its water credit for the board")
	ok(not ShopS.starter_available(), "the starter is claimed (own-once)")
	var st_after := Save.diamonds()
	ok(ShopS.grant_starter() == 0 and Save.diamonds() == st_after, "a second starter claim grants nothing")
	# the board applies the banked water credit on open, then clears it.
	ok(Save.take_water_pending() == int(Data.STARTER_PACK.water), "the board drains the banked water credit")
	ok(Save.water_pending() == 0, "...and the credit is cleared (applied exactly once)")

	# T-E: rewarded ads — a watch grants the reward, then the type is REFUSED until its
	# cooldown elapses AND under its daily cap; the per-type daily cap holds.
	fresh("ads_refill")
	ok(Ads.can_show("refill_water"), "a fresh refill ad is offerable")
	var rr: Dictionary = Ads.claim("refill_water")
	ok(bool(rr.ok) and int(rr.water) == G.WATER_CAP, "watching the refill ad yields a full can (%d💧)" % G.WATER_CAP)
	ok(not Ads.can_show("refill_water"), "...and the ad is refused immediately after (cooldown)")
	ok(not bool(Ads.claim("refill_water").ok), "a claim during cooldown is refused (no over-grant)")
	# backdate the last-watch to simulate the cooldown elapsing → offerable again.
	Save.grove()["ad_ledger"]["refill_water"]["last"] = Time.get_unix_time_from_system() - Data.ADS.refill_water.cooldown - 1.0
	ok(Ads.can_show("refill_water"), "past the cooldown the refill ad is offerable again")
	# exhaust the daily cap (clearing cooldown each time) → refused for the rest of the day.
	var cap_n := int(Data.ADS.refill_water.cap)
	for k in range(Ads.remaining_today("refill_water")):
		Save.grove()["ad_ledger"]["refill_water"]["last"] = 0.0   # ignore cooldown for the cap probe
		ok(bool(Ads.claim("refill_water").ok), "refill watch within the daily cap")
	ok(Save.ad_used_today("refill_water") == cap_n, "the daily cap is reached (%d/day)" % cap_n)
	Save.grove()["ad_ledger"]["refill_water"]["last"] = 0.0
	ok(not Ads.can_show("refill_water"), "the per-type DAILY CAP refuses further watches")
	ok(not bool(Ads.claim("refill_water").ok), "...and a capped claim grants nothing")
	# a NEW day resets the cap (the day-rollover in the ledger).
	Save.grove()["ad_ledger"]["refill_water"]["day"] = int(Time.get_unix_time_from_system() / 86400.0) - 1
	Save.grove()["ad_ledger"]["refill_water"]["last"] = 0.0
	ok(Ads.can_show("refill_water") and Save.ad_used_today("refill_water") == 0, "a new day resets the daily cap")

	# T-F: the 2×-collection ad ARMS a flag the hub-collect (T42) reads, capped+cooled,
	# and consume_2x() spends it. The ad grants no currency directly.
	fresh("ads_2x")
	ok(Ads.collect_multiplier() == 1, "no bonus collect by default (×1)")
	var x2: Dictionary = Ads.claim("collect_2x")
	ok(bool(x2.ok) and Ads.collect_2x_armed(), "watching the 2× ad arms the next collect")
	ok(Ads.collect_multiplier() == int(Data.ADS.collect_2x.mult), "...so the next collect reads ×%d" % int(Data.ADS.collect_2x.mult))
	Ads.consume_2x()
	ok(not Ads.collect_2x_armed() and Ads.collect_multiplier() == 1, "consuming the bonus returns to ×1")

	# T-G: the free-reroll ad advances the Shop rotation seed (reuses the T40 shop_reroll hook).
	fresh("ads_reroll")
	var seed_b: int = ShopS.rotation_seed()
	ok(bool(Ads.claim("shop_reroll").ok), "the free-reroll ad watches")
	ok(ShopS.rotation_seed() == seed_b + 1, "...advancing the rotation seed by one (fresh featured band)")

	# T-G2 (§10 + §13): the Featured band exposes the rewarded "free reroll" as a player-facing
	# TRIGGER SURFACE — gated by Ads.can_show, and pressing it watches the ad + slides the band.
	fresh("shop_reroll_ui")
	var rr_host := Control.new()
	get_root().add_child(rr_host)
	ShopS.open(rr_host)
	var rr_btn := rr_host.find_child("RerollFeatured", true, false)
	ok(rr_btn != null, "the Featured band shows a 'free reroll' watch-ad button when Ads.can_show")
	if rr_btn != null:
		var seed_before: int = ShopS.rotation_seed()
		(rr_btn as Button).pressed.emit()
		ok(ShopS.rotation_seed() == seed_before + 1, "pressing the reroll watches the ad and advances the featured band")
	rr_host.queue_free()

	# T-H: the event top-up ad grants a small 💎, capped at 1/day.
	fresh("ads_event")
	var ev_b := Save.diamonds()
	var ev: Dictionary = Ads.claim("event_topup")
	ok(bool(ev.ok) and Save.diamonds() == ev_b + int(Data.ADS.event_topup.gems), \
		"the event top-up grants +%d💎" % int(Data.ADS.event_topup.gems))
	ok(not Ads.can_show("event_topup"), "the event top-up is 1/day (capped after one watch)")

	# T-I: the OUT-OF-WATER triggered offer — fires inside its low cap + cooldown, refuses
	# past the cap; cozy by construction (a single gentle top-up, no countdown state here).
	fresh("oow_offer")
	var oc := int(Data.OOW_OFFER.cap)
	var ocd := float(Data.OOW_OFFER.cooldown)
	ok(Save.oow_can_show(oc, ocd), "the out-of-water offer may fire at the wall (within cap/cooldown)")
	Save.oow_record()
	ok(not Save.oow_can_show(oc, ocd), "...then it's on cooldown (no repeat shakedown)")
	# exhaust the daily cap, clearing the cooldown between probes.
	while Save.oow_used_today() < oc:
		var g_oow: Dictionary = Save.grove()["oow_offer"]
		g_oow["last"] = 0.0
		if Save.oow_can_show(oc, ocd):
			Save.oow_record()
	Save.grove()["oow_offer"]["last"] = 0.0
	ok(Save.oow_used_today() == oc, "the offer reaches its low daily cap (%d/day)" % oc)
	ok(not Save.oow_can_show(oc, ocd), "...and is refused past the cap (a low, cozy ceiling)")
	# the offer's discount is real value: a full can PLUS premium for the entry price.
	ok(int(Data.OOW_OFFER.water) > 0 and int(Data.OOW_OFFER.gems) > 0, \
		"the offer bundles water + a little 💎 (a gentle discount, §10)")

	# T-J: the live board surfaces the empty-water stack — the ad refill + the offer button
	# exist and the starter water credit is drained on open (the energy-wall wiring, §10).
	fresh("oow_board")
	Save.add_water_pending(int(Data.STARTER_PACK.water))
	var bw = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(bw)
	if bw.board == null:
		bw._ready()
	ok(bw.ad_refill_btn != null and bw.oow_offer_btn != null, "the board builds the watch-ad + offer surfaces")
	ok(Save.water_pending() == 0 and bw.water >= int(Data.STARTER_PACK.water), \
		"the board applies the banked starter water on open")
	# drive to empty and surface the stack (water<=0 reveals the refill stack).
	bw.water = 0
	bw._update_water_hud()
	ok(bw._refill_stack.visible, "at empty the refill stack is shown (the friction point)")
	bw.queue_free()
	# ── T44 · the diegetic return surfaces build + drive (§10/§13 · §18) ─────────
	# Both surfaces are world objects (parchment cards), not bare chrome. Open them on a
	# REAL tree-attached host so the kit + viewport resolve, then drive the actual buttons
	# end-to-end: the piggy-bank Claim→Confirm cracks the jar; the calendar Collect claims.
	fresh("vault_surface")
	var vhost = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(vhost)
	if vhost.has_method("_ready") and vhost.content == null:
		vhost._ready()
	# fill the jar past the threshold, open the surface, and assert it framed a parchment card.
	Vault.skim(Vault.claim_min() * Vault.skim_den() * 4)   # well past claimable
	var v_before := Save.diamonds()
	var v_banked := Vault.balance()
	VaultUI.open(vhost)
	var v_overlay: Control = vhost.get_child(vhost.get_child_count() - 1)
	ok(v_overlay.find_children("*", "PanelContainer", true, false).size() >= 1, \
		"the piggy bank opens as a framed parchment card (diegetic, §13)")
	# press Claim → then Confirm on the spawned confirm overlay → the jar cracks.
	ok(_press_label(v_overlay, "Claim"), "the piggy bank shows a Claim button")
	var v_confirm: Control = vhost.get_child(vhost.get_child_count() - 1)
	ok(_press_label(v_confirm, "Confirm"), "the crack confirm shows a Confirm button")
	ok(Save.diamonds() == v_before + v_banked and Vault.balance() == 0, \
		"cracking the jar through the surface grants the banked 💎 and empties it")
	vhost.queue_free()

	fresh("login_surface")
	var lhost = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(lhost)
	if lhost.has_method("_ready") and lhost.content == null:
		lhost._ready()
	var l_coins := Save.coins()
	var l_streak := Login.streak()
	LoginUI.open(lhost)
	var l_overlay: Control = lhost.get_child(lhost.get_child_count() - 1)
	ok(l_overlay.find_children("*", "PanelContainer", true, false).size() >= 8, \
		"the calendar opens as a framed card with a week of reward cells (diegetic, §13)")
	ok(_press_label(l_overlay, "Collect"), "the calendar shows a Collect button")
	ok(Login.streak() == l_streak + 1 and Save.coins() >= l_coins, \
		"collecting through the surface claims today's rung and bumps the streak")
	lhost.queue_free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)

# ── T42 · the home-hub yield + upgrade-levels keystone (own fn = its own scope) ───────────
# The hub map (Farmhouse, map 0) splits 4 yield buildings + 4 décor; a yield building restored
# to L1 accrues coins over time to a per-building cap, upgrades L1→L5 for more yield + look, and
# the whole hub sweeps in one collect-on-return beat. All math is data-driven (HUB_* tables).
func _test_hub_yield() -> void:
	var hub := G.hub_map()
	ok(hub == 0, "hub map is the Farmhouse (map 0)")

	# 1. the `kind` seam — spot_is_yield reads it; only the 4 yield buildings are yield.
	ok(G.spot_is_yield(hub, "fh_hearth"), "Hearth is a yield building (kind:yield)")
	ok(G.spot_is_yield(hub, "fh_well"), "Well is a yield building")
	ok(not G.spot_is_yield(hub, "fh_porch"), "Porch is décor, NOT yield (kind:decor)")
	ok(not G.spot_is_yield(hub, "fh_fence"), "Garden fence is décor, NOT yield")
	ok(not G.spot_is_yield(1, "bn_bales"), "a plain non-hub spot (Barn) is not yield")
	ok(G.spot_kind(hub, "fh_hearth") == "yield" and G.spot_kind(hub, "fh_porch") == "decor", "spot_kind exposes the raw seam")
	var n_yield := 0
	for hsp in G.MAPS[hub].spots:
		if G.spot_is_yield(hub, String(hsp.id)):
			n_yield += 1
	ok(n_yield == 4, "the hub has exactly 4 yield buildings (grove_spec §3)")

	# 2. accrual = rate × elapsed, FLOORED to whole coins, CAPPED at the per-building cap. Asserts the
	#    MECHANISM against the HUB_* tables (so re-tuning the dials never breaks the test), plus the
	#    invariant shape: rate>0 and cap>0 at L1, rate 0 at L0, monotonic, and the cap binds.
	ok(G.hub_yield_rate(1) > 0.0, "L1 yield rate is positive (a restored building drips coins)")
	ok(G.hub_yield_rate(0) == 0.0, "an unrestored (L0) building has 0 yield rate")
	# accrual below the cap == floor(rate_per_sec × elapsed): 4h at L1 reads the table, never hardcoded.
	var lvl1_4h: int = int(floor(G.hub_yield_rate(1) / 3600.0 * 4.0 * 3600.0))
	ok(G.hub_spot_ready(1, 4.0 * 3600.0) == lvl1_4h, "L1 accrues floor(rate × elapsed) below the cap")
	# a huge elapsed CAPS at the per-building cap (≈ a day's worth) — the anti-pile-up guard.
	ok(G.hub_spot_ready(1, 1000.0 * 3600.0) == G.hub_yield_cap(1), "L1 accrual CAPS at the per-building cap")
	ok(G.hub_spot_ready(5, 1000.0 * 3600.0) == G.hub_yield_cap(5), "L5 accrual CAPS at the L5 per-building cap")
	ok(G.hub_yield_cap(1) > 0 and G.hub_yield_cap(5) > G.hub_yield_cap(1), "caps are positive and rise with level (richer building holds more)")
	# 0 elapsed and an L0 building both accrue nothing.
	ok(G.hub_spot_ready(1, 0.0) == 0, "zero elapsed accrues 0")
	ok(G.hub_spot_ready(0, 1000.0 * 3600.0) == 0, "an L0 (unrestored) building accrues 0 regardless of time")

	# 3. hub_coins_ready sums ONLY restored yield spots; an unrestored or décor spot adds nothing.
	fresh("hub_ready")
	Save.set_hub_collected_at(0.0)
	var unl := {}
	Save.set_spot_level("fh_hearth", 1); unl["fh_hearth"] = true
	Save.set_spot_level("fh_porch", 1);  unl["fh_porch"] = true     # décor — restored but yields 0
	var t10h := 10.0 * 3600.0
	ok(G.hub_coins_ready(unl, t10h) == G.hub_spot_ready(1, t10h), "ready = the one L1 yield building (décor adds 0)")
	Save.set_spot_level("fh_well", 3)                              # level set but NOT in unlocks → unrestored
	ok(G.hub_coins_ready(unl, t10h) == G.hub_spot_ready(1, t10h), "an unrestored yield spot (not owned) yields 0")
	unl["fh_well"] = true                                         # now restore it → the total is the SUM
	ok(G.hub_coins_ready(unl, t10h) == G.hub_spot_ready(1, t10h) + G.hub_spot_ready(3, t10h), "ready SUMS over restored yield buildings")

	# 4. the collect BEAT: add the summed yield to coins AND reset hub_collected_at to `now`.
	fresh("hub_collect")
	Save.set_hub_collected_at(0.0)
	var unl2 := {"fh_hearth": true, "fh_kitchen": true}
	Save.set_spot_level("fh_hearth", 2)
	Save.set_spot_level("fh_kitchen", 1)
	var coins0 := Save.coins()
	var t8h := 8.0 * 3600.0
	var want := G.hub_spot_ready(2, t8h) + G.hub_spot_ready(1, t8h)
	ok(G.hub_collect(unl2, t8h) == want and want > 0, "collect returns the summed ready yield (%d🪙)" % want)
	ok(Save.coins() == coins0 + want, "collect ADDS the summed yield to the wallet")
	ok(Save.hub_collected_at() == t8h, "collect RESETS hub_collected_at to now")
	ok(G.hub_coins_ready(unl2, t8h) == 0, "right after a collect, nothing is ready (clock reset)")
	var coins1 := Save.coins()
	ok(G.hub_collect(unl2, t8h + 1.0) == 0 and Save.coins() == coins1, "a no-yield re-collect adds 0🪙")

	# 5. upgrade raises BOTH the level and the next yield rate; cost escalates; refused at max / below L1.
	ok(G.hub_max_level() == 5, "hub max level is L5 (L1 restore → 4 coin upgrades)")
	ok(G.hub_yield_rate(2) > G.hub_yield_rate(1), "an upgrade (L1→L2) raises the yield rate")
	ok(G.hub_yield_rate(5) > G.hub_yield_rate(4), "each level keeps raising the yield (L4→L5)")
	ok(G.hub_upgrade_cost(1) == 150, "L1→L2 upgrade costs 150🪙")
	ok(G.hub_upgrade_cost(2) > G.hub_upgrade_cost(1), "the upgrade ladder escalates (L2→L3 dearer than L1→L2)")
	ok(G.hub_upgrade_cost(5) == -1, "no upgrade at the max level (L5) → -1")
	ok(G.hub_upgrade_cost(0) == -1, "L0→L1 is the Stars RESTORE, not a coin upgrade → -1")
	# the spend path: a restored yield building's stored level rises by 1 on a coin upgrade.
	fresh("hub_upgrade")
	Save.set_spot_level("fh_hearth", 1)
	ok(Save.spot_level("fh_hearth") == 1, "a restored yield building sits at L1")
	Save.set_spot_level("fh_hearth", Save.spot_level("fh_hearth") + 1)
	ok(Save.spot_level("fh_hearth") == 2, "a coin upgrade raises the stored level to L2")

	# the keystone INVARIANT bound (data-driven): max daily faucet = #yield × top cap, ≪ the coin
	# SINK it funds — so the hub can never self-sustain (a MONTH of max yield can't even buy the ladder).
	var max_daily := G.hub_max_daily_yield()
	ok(max_daily == n_yield * G.hub_yield_cap(G.hub_max_level()), "max daily hub yield = #yield-buildings × the top-level cap")
	var hub_sink := 0
	for lv in range(1, G.hub_max_level()):
		hub_sink += G.hub_upgrade_cost(lv)
	hub_sink *= n_yield                                           # all 4 buildings, L1→L5
	ok(hub_sink == 8600, "the hub-upgrade ladder is an 8,600🪙 coin sink (4 × 2,150)")
	ok(max_daily * 30 < hub_sink, "a full month of max yield < the hub-upgrade ladder alone — extend, never self-sustain")
	var burst_sink := 0
	for c in G.BURST_UPGRADE_COSTS:
		burst_sink += int(c)
	ok(max_daily * 7 < burst_sink, "a week of max yield < the standing burst-ladder sink — the late-game ongoing sink outpaces the standing yield")
	print("  [T42 hub-yield bound] max daily faucet=%d🪙 · hub-upgrade sink=%d🪙 · burst sink=%d🪙" % \
		[max_daily, hub_sink, burst_sink])

# ── T45 · the INTEGRATION wiring (drives the real Map scene) ──────────────────────────────
# The three monetization engines (2×-collect ad, piggy vault, daily-login calendar) merged
# tested but UNREACHABLE; this proves their entry points are now live:
#   1. a hub auto-collect of N coins surfaces an opt-in 2× DOUBLER that credits exactly a
#      second N and consumes the arm (and does NOT appear when the ad isn't offerable),
#   2. the piggy-bank button lives in the map chrome, opens the jar, and lights its pip when
#      the vault is claimable,
#   3. the daily-login calendar auto-pops on a fresh (unclaimed) day past the FTUE, and stays
#      shut when already claimed today.
func _test_t45_wiring() -> void:
	var Ads := load("res://engine/scripts/core/ads.gd")
	var Feat := load("res://engine/scripts/core/features.gd")
	var hub := G.hub_map()
	var hub_id := String(G.MAPS[hub].spots[0].id)   # a real hub spot to restore as a yield building

	# isolate the 2× tests: the login auto-popup is exercised in section 3 — keep it OFF here so the
	# ONLY deferred overlay is the doubler card (the calendar opening grants nothing, but this keeps
	# the surface unambiguous). Restored before section 3.
	Feat.FLAGS["daily_login_popup"] = false

	# 1a. THE 2× DOUBLER. Stand up the hub with a restored yield building and a long-elapsed collect
	# clock so the auto-collect-on-open sweeps a real N>0 (the scene collects at real `now`, so we
	# MEASURE the actual swept amount from the wallet delta rather than predicting it). The offer
	# card then appears (the ad is fresh); pressing "Double" must credit EXACTLY that same N again.
	fresh("t45_2x")
	Save.set_hub_collected_at(0.0)                    # long-ago clock → the open sweeps the per-building cap
	var unl := {hub_id: true}
	Save.set_spot_level(hub_id, 1)
	var g2 := Save.grove()
	g2["unlocks"] = unl
	Save.grove_write()
	ok(Ads.can_show("collect_2x"), "the 2× ad is offerable (fresh)")
	var coins_before_open: int = Save.coins()
	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	if hx.content == null:
		hx._ready()
	var got_actual: int = Save.coins() - coins_before_open   # the amount the auto-collect-on-open swept
	ok(got_actual > 0, "the hub auto-collect on open swept N>0 coins (%d🪙)" % got_actual)
	var coins_after_collect: int = Save.coins()
	# the deferred collect FX + offer build a frame later — let them run (the timer spans frames).
	await create_timer(0.15).timeout
	ok(hx._2x_offer != null and is_instance_valid(hx._2x_offer), "the post-collect 2× DOUBLER card appears (opt-in, near the FX)")
	# the card carries a "Double" CTA — press it; it credits a SECOND N and consumes the arm.
	var pressed_double := _press_label(hx._2x_offer, "Double")
	ok(pressed_double, "the 2× card shows a Double CTA")
	ok(Save.coins() == coins_after_collect + got_actual, "accepting the 2× credits EXACTLY a second %d🪙 (the doubled half)" % got_actual)
	ok(not Ads.collect_2x_armed() and Ads.collect_multiplier() == 1, "...and consumes the arm (back to ×1)")
	ok(hx._2x_offer == null, "the offer card dismisses after accept")
	hx.queue_free()

	# 1b. NO offer when the ad is not offerable — exhaust the daily cap, then re-open: a collect with
	# yield must NOT surface the card (the doubler is gated on Ads.can_show, never forced).
	fresh("t45_2x_capped")
	Save.set_hub_collected_at(0.0)
	var unl_c := {hub_id: true}
	Save.set_spot_level(hub_id, 1)
	var gc := Save.grove()
	gc["unlocks"] = unl_c
	Save.grove_write()
	# burn the collect_2x daily cap (clear cooldown between claims) so can_show goes false.
	for _i in range(Ads.remaining_today("collect_2x")):
		Save.grove()["ad_ledger"]["collect_2x"]["last"] = 0.0
		Ads.claim("collect_2x")
	Ads.consume_2x()
	Save.grove()["ad_ledger"]["collect_2x"]["last"] = 0.0
	ok(not Ads.can_show("collect_2x"), "the 2× ad is capped out for the day")
	Save.set_hub_collected_at(0.0)
	var hxc = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hxc)
	if hxc.content == null:
		hxc._ready()
	await create_timer(0.15).timeout
	ok(hxc._2x_offer == null, "a capped-out 2× ad surfaces NO offer card (gated, never forced)")
	hxc.queue_free()

	# 2. THE PIGGY-VAULT CHROME ENTRY. The map chrome carries a piggy button that opens the jar;
	# its ready-pip reflects Vault.claimable(). Drive _open_vault() → a parchment overlay appears.
	fresh("t45_vault")
	var hv = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hv)
	if hv.content == null:
		hv._ready()
	# a sub-threshold jar → the pip is dark; fill it past the claim min → the pip lights.
	hv._refresh_piggy_pip()
	ok(hv._piggy_pip != null and not hv._piggy_pip.visible, "the piggy ready-pip is dark while the jar is below the claim threshold")
	Vault.skim(Vault.claim_min() * Vault.skim_den() * 4)   # well past claimable
	hv._refresh_piggy_pip()
	ok(Vault.claimable() and hv._piggy_pip.visible, "the piggy ready-pip LIGHTS once the jar is claimable")
	var ov_before: int = hv.get_child_count()
	hv._open_vault()
	ok(hv.get_child_count() == ov_before + 1, "tapping the piggy button opens a surface overlay")
	var vov: Control = hv.get_child(hv.get_child_count() - 1)
	ok(vov.find_children("*", "PanelContainer", true, false).size() >= 1, "the vault opens as a framed parchment jar card (diegetic, §13)")
	ok(_press_label(vov, "Claim"), "the opened vault shows a Claim button (the jar surface, reachable from the hub)")
	hv.queue_free()

	# 3. THE DAILY-LOGIN AUTO-POPUP. Past the FTUE (a spot owned) and unclaimed today, the day's
	# first hub open auto-shows the calendar ONCE; already-claimed → it stays shut.
	Feat.FLAGS["daily_login_popup"] = true            # restore the flag the 2× section turned off
	fresh("t45_login_fresh")
	# mark the FTUE shop spotlight as already seen so it doesn't compete for the overlay slot.
	Save.mark_spotlight_seen("shop")
	var gl := Save.grove()
	gl["unlocks"] = {hub_id: true}                    # past the cold FTUE (a rewarding beat happened)
	Save.grove_write()
	ok(not Login.claimed_today(), "today is unclaimed (the day's first open)")
	var hl = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hl)
	if hl.content == null:
		hl._ready()
	await create_timer(0.2).timeout                   # the popup is deferred two frames; the timer spans them
	var login_up := _find_calendar_overlay(hl)
	ok(login_up != null, "the daily-login calendar AUTO-POPS on the day's first hub open (past the FTUE)")
	ok(_press_label(login_up, "Collect"), "the auto-popped calendar shows a Collect button")
	hl.queue_free()

	# 3b. ALREADY CLAIMED today → no auto-popup (it fired its once; never nags).
	fresh("t45_login_claimed")
	Save.mark_spotlight_seen("shop")
	var gl2 := Save.grove()
	gl2["unlocks"] = {hub_id: true}
	Save.grove_write()
	ok(Login.claim_today(), "claim today's rung up front")
	ok(Login.claimed_today(), "today now reads claimed")
	var hl2 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hl2)
	if hl2.content == null:
		hl2._ready()
	await create_timer(0.2).timeout
	ok(_find_calendar_overlay(hl2) == null, "an already-claimed day shows NO calendar popup (fires once, never nags)")
	hl2.queue_free()

	# 3c. the cold FTUE session (no spots owned) is SKIPPED — §18 "after a reward, not a cold open".
	fresh("t45_login_ftue")
	Save.mark_spotlight_seen("shop")                  # isolate the FTUE gate from the spotlight gate
	var hf = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hf)
	if hf.content == null:
		hf._ready()
	await create_timer(0.2).timeout
	ok(_find_calendar_overlay(hf) == null, "the cold first FTUE session (no spots owned) skips the calendar (§18)")
	hf.queue_free()

# Find a live login-calendar overlay on `host`: the LoginUI roots a full-rect Control whose
# subtree carries a "Daily visit" title and a "Collect"/"Come back" CTA. Returns it or null.
func _find_calendar_overlay(host: Control) -> Control:
	for c in host.get_children():
		if not (c is Control):
			continue
		for b in (c as Control).find_children("*", "Button", true, false):
			var t := String((b as Button).text)
			if t.findn("Collect") != -1 or t.findn("tomorrow") != -1:
				return c as Control
	return null
# T44: press the first Button whose text contains `frag` inside `overlay`. Returns whether
# one was found+pressed (so a test asserts the control exists AND fires its action).
func _press_label(overlay: Control, frag: String) -> bool:
	for b in overlay.find_children("*", "Button", true, false):
		if String((b as Button).text).findn(frag) != -1:
			(b as Button).pressed.emit()
			return true
	return false

# T40 helpers: pull the id list out of a rotation, and a uniq pass.
func _offer_ids(offers: Array) -> Array:
	var out: Array = []
	for o in offers:
		out.append(String(o.id))
	return out

func _uniq(arr: Array) -> Array:
	var seen := {}
	var out: Array = []
	for v in arr:
		if not seen.has(v):
			seen[v] = true
			out.append(v)
	return out
