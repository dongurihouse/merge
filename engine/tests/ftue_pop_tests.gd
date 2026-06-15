extends SceneTree
## Headless tests for the FTUE free-pop intro × burst interaction (Core §4 / §6, T33).
##   godot --headless --path . -s res://engine/tests/ftue_pop_tests.gd
##
## §4 "FTUE free pops": the first 10 pops cost no energy and are uncounted
## (`ftue_free_pops`) — "the opening minute is pure frictionless merging". §6: a tap
## normally pops a BURST of 1–3 items. The bug (audit 2026-06-15): burst applied
## DURING the free-pop phase and each burst item bumped the same `pops` odometer, so a
## single 3-item tap spent 3 of the 10 free pops — the intro could end in ~4 taps and
## overshoot 10 mid-burst. The fix: while the free pops remain, a tap pops EXACTLY ONE
## item (≈10 deliberate frictionless taps); after the budget is spent, burst kicks in
## normally. This suite drives the REAL board/pop path (Board.tscn + _pop_seed) with a
## seeded rng and a guaranteed-≥2 burst-upgrade level, so "exactly 1 during FTUE" can
## only be the suppression — not a lucky 1-roll.

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Features = preload("res://engine/scripts/core/features.gd")

const FREE_POPS := 10            # §4 free-pop budget (mirrors board._ftue_pops_done)

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# A clean per-case save (fresh user:// dir → default save, pops = 0 = the FTUE intro).
func _fresh(name: String) -> void:
	var dir := "user://tu_test_ftue_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

# Spin up a real board scene, force a wide-open playfield (every cell open + empty, so a
# burst always has room to land its items), a brimming water bar, a seeded rng, and a HIGH
# burst-upgrade so burst_count is deterministically ≥ 2 the moment burst is allowed.
func _board() -> Node:
	var s = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s)
	await process_frame                       # let the scene enter the tree + lay out
	if s.board == null:
		s._ready()
	s.rng.seed = 1234                         # deterministic spawn rolls
	# open + empty every non-generator cell → the whole 7×9 board is free ground for bursts
	for x in range(G.ROWS):
		for y in range(G.COLS):
			var cell := Vector2i(x, y)
			if s.board.is_gen(cell):
				continue
			s.board.terrain[s.board.idx(cell)] = 0   # shed any bramble (open the cell)
			s.board.items[s.board.idx(cell)] = 0      # clear any item
	s._rebuild_pieces()
	s.water = G.WATER_CAP
	Save.grove()["burst_lvl"] = 2             # base(≥1)+2 ⇒ burst_count ≥ 3 whenever burst is live
	return s

# Count items on the board model (coins excluded — a generator pop never drops a coin;
# coins come from merges only, §6 — but exclude defensively so the count is the burst).
func _item_count(s: Node) -> int:
	var n := 0
	for v in s.board.items:
		if v > 0 and not G.is_coin(v):
			n += 1
	return n

# Pop once and return how many items the tap added to the board.
func _pop_once(s: Node) -> int:
	var before := _item_count(s)
	s._pop_seed()
	await create_timer(0.05).timeout
	return _item_count(s) - before

func _initialize() -> void:
	print("== FTUE pop tests ==")

	# Guard the premise: with burst_lvl=2 at map 0, burst_count is ALWAYS ≥ 2 — so any
	# "1 item" result below is the FTUE suppression, never a lucky base roll.
	var grng := RandomNumberGenerator.new()
	grng.seed = 99
	var min_live := 99
	for _i in 200:
		min_live = mini(min_live, G.burst_count(0, 2, grng))
	ok(min_live >= 2, "premise: at burst_lvl 2 a live burst is always ≥ 2 (so '1' can only be FTUE suppression)")

	# --- 1. during the FTUE free phase, EVERY pop yields exactly 1 item (no burst) ---
	_fresh("phase")
	var s = await _board()
	ok(int(Save.grove().get("pops", 0)) == 0, "a fresh save opens in the FTUE free-pop phase (pops = 0)")
	ok(not s._ftue_pops_done(), "the FTUE intro is not done at pops = 0")
	var all_one := true
	var pops_done := 0
	# pop through the WHOLE free budget; each free tap must add exactly one item
	for i in FREE_POPS:
		ok(not s._ftue_pops_done(), "still in the free phase before free pop #%d" % (i + 1))
		var added: int = await _pop_once(s)
		if added != 1:
			all_one = false
			print("    (free pop #%d added %d items — expected 1)" % [i + 1, added])
		pops_done = int(Save.grove().get("pops", 0))
	ok(all_one, "every FTUE free pop yields EXACTLY 1 item — burst is suppressed (pure frictionless merging)")

	# --- 2. the boundary is exact: 10 free taps land pops at exactly 10, no overshoot ---
	ok(pops_done == FREE_POPS, "10 free taps bring the pop counter to EXACTLY %d (no mid-burst overshoot)" % FREE_POPS)
	ok(s._ftue_pops_done(), "the FTUE intro is done after the %dth free pop" % FREE_POPS)
	ok(s.water == G.WATER_CAP, "the FTUE free pops cost no energy (water untouched through the intro)")

	# --- 3. once the budget is spent, a pop CAN yield > 1 (burst is active) ---
	# rng was advanced by the free pops; with burst_lvl=2 the very next live pop is ≥ 2.
	var post: int = await _pop_once(s)
	ok(post >= 2, "the first post-FTUE pop bursts (> 1 item) — the burst economy resumes after the intro")
	ok(s.water == G.WATER_CAP - post * G.POP_COST, "each post-FTUE burst item costs exactly one energy")
	s.queue_free()

	# --- 4. the boundary holds with the feature flag OFF (no FTUE → burst from tap 1) ---
	_fresh("flagoff")
	Features.FLAGS["ftue_free_pops"] = false
	var s2 = await _board()
	ok(s2._ftue_pops_done(), "with ftue_free_pops OFF the intro is considered already done")
	var first: int = await _pop_once(s2)
	ok(first >= 2, "flag OFF: the very first pop already bursts (no free-pop suppression)")
	Features.FLAGS["ftue_free_pops"] = true
	s2.queue_free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
