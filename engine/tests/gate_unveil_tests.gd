extends SceneTree
## Headless tests for the §8 gate-unveil POINTER — the wordless map→board handoff.
## Completing a map's spots unveils its gate quest, which now waits on the BOARD as the
## lone fence stand (§7). That cross-screen handoff was silent (against the no-required-
## reading pillar, §13); the map now ARMS Save.gate_pointer on completion and the board
## CONSUMES it on open, pulsing the gate stand wordlessly.
##
## These assert the SEAM (the cue's trigger + the flag lifecycle), never pixels — the
## headless dummy renderer can't capture images. Three layers:
##   A · Save accessors: arm / read / take-and-clear / no-op on empty (pure, no scene).
##   B · map.gd ARMS on completion: the completing purchase sets the pointer; a non-
##       completing one does not; an already-delivered gate does not re-arm.
##   C · board.gd CONSUMES + decides the cue: a pending pointer for the frontier fires the
##       cue and clears; no pointer does nothing; a stale pointer is consumed silently.
##   godot --headless --path . -s res://engine/tests/gate_unveil_tests.gd

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# A clean per-case temp save dir, redirected so tests never touch the real save.
func fresh(name: String) -> void:
	var dir := "user://tu_test_gate_unveil_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

# Fill every spot of zones [0..upto) into an unlocks dict (whole maps spot-restored).
func _unlock_zones(upto: int) -> Dictionary:
	var ul := {}
	for z in upto:
		for sp in G.ZONES[z].spots:
			ul[String(sp.id)] = true
	return ul

# Unlock all of zone 0 EXCEPT its last spot — one purchase away from complete.
func _zone0_minus_last() -> Dictionary:
	var ul := {}
	var spots: Array = G.ZONES[0].spots
	for k in spots.size() - 1:
		ul[String(spots[k].id)] = true
	return ul

func _initialize() -> void:
	print("== Gate-unveil pointer tests ==")

	# ---------------------------------------------------------------------------
	# A · the Save seam: arm / read / take-and-clear / no-op on empty.
	# ---------------------------------------------------------------------------
	fresh("save_seam")
	ok(Save.gate_pointer() == -1, "A: a fresh save has no pointer armed (-1)")
	ok(Save.take_gate_pointer() == -1, "A: taking an unarmed pointer returns -1 (no-op)")

	Save.set_gate_pointer(2)
	ok(Save.gate_pointer() == 2, "A: set_gate_pointer arms the pointer (reads back the zone)")
	# survives a cold reload (it lives in the persisted grove blob)
	Save._loaded = false
	Save.data = {}
	ok(Save.gate_pointer() == 2, "A: the armed pointer persists across a cold load")

	ok(Save.take_gate_pointer() == 2, "A: take returns the armed zone")
	ok(Save.gate_pointer() == -1, "A: ...and take CLEARS it (a second read is -1)")
	ok(Save.take_gate_pointer() == -1, "A: a second take returns -1 (fires exactly once)")

	Save.set_gate_pointer(1)
	Save.clear_gate_pointer()
	ok(Save.gate_pointer() == -1, "A: clear_gate_pointer disarms")

	# ---------------------------------------------------------------------------
	# B · map.gd ARMS the pointer when a purchase completes the map's spots.
	# ---------------------------------------------------------------------------
	# B1 — the completing purchase arms the pointer for that zone.
	fresh("map_arms")
	var gb := Save.grove()
	gb["unlocks"] = _zone0_minus_last()
	gb["stars_earned"] = 200                      # high Level clears every spot's level gate
	gb["gates"] = []                              # zone 0's gate not yet delivered
	Save.grove_write()
	Save.add_stars(50)                            # plenty to afford the last spot
	var h = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h)
	if h.content == null:                         # headless: _ready may run out of tree
		h._ready()
	h.unlocks = Save.grove().get("unlocks", {})
	ok(Save.gate_pointer() == -1, "B1: no pointer before the completing purchase")
	var last_k: int = G.ZONES[0].spots.size() - 1
	h._on_spot_tap(0, last_k, Button.new(), Vector2(300, 300))
	ok(h.zone_complete(0), "B1: the purchase completed zone 0's spots (precondition)")
	ok(Save.gate_pointer() == 0, "B1: completing the map's spots ARMS the gate pointer for that zone")
	h.queue_free()

	# B2 — a NON-completing purchase (map still has spots left) does NOT arm.
	fresh("map_noarm")
	var gb2 := Save.grove()
	var ul_partial := {}                          # zone 0 with only its FIRST two spots owned
	ul_partial[String(G.ZONES[0].spots[0].id)] = true
	ul_partial[String(G.ZONES[0].spots[1].id)] = true
	gb2["unlocks"] = ul_partial
	gb2["stars_earned"] = 200
	gb2["gates"] = []
	Save.grove_write()
	Save.add_stars(50)
	var h2 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h2)
	if h2.content == null:
		h2._ready()
	h2.unlocks = Save.grove().get("unlocks", {})
	h2._on_spot_tap(0, 2, Button.new(), Vector2(300, 300))   # buy a 3rd spot — still incomplete
	ok(not h2.zone_complete(0), "B2: zone 0 still has spots left after the purchase (precondition)")
	ok(Save.gate_pointer() == -1, "B2: a non-completing purchase does NOT arm the pointer")
	h2.queue_free()

	# B3 — completing a map whose gate is ALREADY delivered does not re-arm.
	fresh("map_gatedone")
	var gb3 := Save.grove()
	gb3["unlocks"] = _zone0_minus_last()
	gb3["stars_earned"] = 200
	gb3["gates"] = [0]                            # zone 0's gate already delivered
	Save.grove_write()
	Save.add_stars(50)
	var h3 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h3)
	if h3.content == null:
		h3._ready()
	h3.unlocks = Save.grove().get("unlocks", {})
	h3._on_spot_tap(0, last_k, Button.new(), Vector2(300, 300))
	ok(h3.zone_complete(0), "B3: zone 0 spots complete (precondition)")
	ok(Save.gate_pointer() == -1, "B3: an already-delivered gate does NOT re-arm the pointer")
	h3.queue_free()

	# ---------------------------------------------------------------------------
	# C · board.gd CONSUMES the pointer on open and decides whether to cue.
	#     _take_gate_cue_zone() is the cue's trigger: it returns the zone to cue
	#     (and clears the flag) only when pending+frontier; -1 otherwise (still
	#     clearing any stale flag). We assert on that seam, not on pixels.
	# ---------------------------------------------------------------------------
	# C1 — a pending pointer for the frontier map FIRES the cue and CLEARS the flag.
	fresh("board_fire")
	var gc := Save.grove()
	gc["unlocks"] = _unlock_zones(1)              # zone 0 fully spot-restored → its gate is the lone stand
	gc["gates"] = []                              # ...and not yet delivered → gate pending on the board
	gc["stars_earned"] = 200
	gc["board"] = BoardModel.new().to_dict()
	Save.grove_write()
	Save.set_gate_pointer(0)                      # the map armed the pointer on completion
	var s = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s)
	if s.board == null:
		s._ready()
	await create_timer(0.05).timeout             # let the fence build
	ok(s._quest_zone() == 0 and s._gate_pending(), "C1: the board's frontier is zone 0 with its gate pending (precondition)")
	ok(s.quests.size() == 1 and bool(s.quests[0].get("gate", false)), "C1: the lone fence stand is the gate quest (precondition)")
	# the board's _ready already consumed the pointer; the cue's decision is recorded by the clear.
	ok(Save.gate_pointer() == -1, "C1: opening the board with a pending pointer CONSUMED (cleared) it")
	# and the trigger seam, re-driven on a freshly-armed pointer, returns the zone to cue.
	Save.set_gate_pointer(0)
	ok(s._take_gate_cue_zone() == 0, "C1: _take_gate_cue_zone() returns the zone to cue when pending+frontier")
	ok(Save.gate_pointer() == -1, "C1: ...and that decision cleared the flag (fires once)")
	# the cue itself runs without error on the live (gate-pending) fence — giver_chips[0] is the stand.
	ok(not s.giver_chips.is_empty() and bool(s.quests[0].get("gate", false)), "C1: a gate stand exists to point at")
	s._play_gate_cue()
	ok(true, "C1: _play_gate_cue() runs on the live gate stand without error")
	s.queue_free()

	# C2 — opening the board with NO pointer armed does nothing.
	fresh("board_none")
	var gc2 := Save.grove()
	gc2["unlocks"] = _unlock_zones(1)
	gc2["gates"] = []
	gc2["stars_earned"] = 200
	gc2["board"] = BoardModel.new().to_dict()
	Save.grove_write()                            # no set_gate_pointer — nothing armed
	var s2 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s2)
	if s2.board == null:
		s2._ready()
	await create_timer(0.05).timeout
	ok(s2._gate_pending(), "C2: the gate is pending on this board (precondition)")
	ok(Save.gate_pointer() == -1, "C2: no pointer was armed")
	ok(s2._take_gate_cue_zone() == -1, "C2: with no pointer armed, the cue does NOT fire (-1)")
	s2.queue_free()

	# C3 — a STALE pointer (armed, but its gate is NOT pending) is consumed silently:
	# no cue fires, AND the stale flag is cleared so it can never fire later.
	fresh("board_stale")
	var gc3 := Save.grove()
	gc3["unlocks"] = _unlock_zones(1)
	gc3["gates"] = [0]                            # zone 0's gate ALREADY delivered → NOT pending
	gc3["stars_earned"] = 200
	gc3["board"] = BoardModel.new().to_dict()
	Save.grove_write()
	Save.set_gate_pointer(0)                      # stale: points at a gate that's already done
	var s3 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s3)
	if s3.board == null:
		s3._ready()
	await create_timer(0.05).timeout
	ok(not (s3._quest_zone() == 0 and s3._gate_pending()), "C3: zone 0's gate is no longer pending (stale precondition)")
	ok(Save.gate_pointer() == -1, "C3: a stale pointer is consumed (cleared) on open — never fires later")
	# re-arm a stale pointer and confirm the trigger seam returns -1 (no cue) yet still clears it.
	Save.set_gate_pointer(0)
	ok(s3._take_gate_cue_zone() == -1, "C3: _take_gate_cue_zone() returns -1 for a stale pointer (no cue)")
	ok(Save.gate_pointer() == -1, "C3: ...and clears the stale flag anyway (consumed silently)")
	s3.queue_free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
