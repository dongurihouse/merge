extends SceneTree
## Headless tests for the quest-ready board affordance (board.gd + ui/piece_view.gd): a board tile a
## LIVE quest wants wears a "ReadyGlow" halo, and a SECOND tap of that already-focused tile delivers the
## quest (consume the item, complete it). Drives the live Board scene with seeded items and the board's
## OWN generated quests (so the fence + giver cards are real). The board input is driven through the
## actual _on_board_input handler (the real tap path), not a shortcut.
##   godot --headless --path . -s res://engine/tests/quest_ready_glow_tests.gd

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Quests = preload("res://engine/scripts/core/quests.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func fresh(name: String) -> void:
	var dir := "user://tu_qready_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func _board() -> Node:
	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(scn)
	if scn.board == null:
		scn._ready()
	return scn

# A real low item code NOT asked by any live quest (scanned off the asked set).
func _unasked_code(scn) -> int:
	var asked: Dictionary = scn._asked_codes()
	for line in [1, 2, 3, 4]:
		for tier in [1, 2, 3]:
			var c: int = line * 100 + tier
			if not asked.has(c):
				return c
	return 401

func _center(scn, cell: Vector2i) -> Vector2:
	return scn._cell_pos(cell) + Vector2(scn.csz, scn.csz) / 2.0

# A live ready-glow on a piece node — a glow already queued for deletion (cleared this frame) counts as
# ABSENT, so the assertions don't race the deferred queue_free.
func _has_glow(node) -> bool:
	var g = node.get_node_or_null("ReadyGlow")
	return g != null and not g.is_queued_for_deletion()

# A still tap on a board cell, driven through the REAL handler (mouse + the synthesized touch that
# emulate_touch_from_mouse delivers). Board-area-local positions — _on_board_input's gui_input space.
func _tap(scn, at: Vector2) -> void:
	var md := InputEventMouseButton.new(); md.button_index = MOUSE_BUTTON_LEFT; md.pressed = true; md.position = at
	var td := InputEventScreenTouch.new(); td.pressed = true; td.position = at
	scn._on_board_input(md); scn._on_board_input(td)
	var mu := InputEventMouseButton.new(); mu.button_index = MOUSE_BUTTON_LEFT; mu.pressed = false; mu.position = at
	var tu := InputEventScreenTouch.new(); tu.pressed = false; tu.position = at
	scn._on_board_input(mu); scn._on_board_input(tu)

func _initialize() -> void:
	print("== Quest-ready glow + tap-to-deliver tests ==")

	# --- Part A: the glow marks exactly the tiles a live quest wants ---
	fresh("glow")
	var scn = _board()
	ok(scn.board != null, "the board scene stands up")
	ok(not scn._ready_glow_opts.is_empty(), "the board resolves the workbench ready-glow opts once in _ready")
	ok(not scn.quests.is_empty(), "the fresh fence carries at least one live quest")
	var q: Dictionary = scn.quests[0]
	var it: Dictionary = G.quest_item(q)
	ok(not it.is_empty(), "the first quest asks for a concrete item")
	var code := int(it.line) * 100 + int(it.tier)
	var empties: Array = scn.board.empty_ground_cells()
	ok(empties.size() >= 2, "the fresh board has room to seed test items")
	var cell_a: Vector2i = empties[0]              # a tile the first quest WANTS
	var cell_b: Vector2i = empties[1]              # a tile nothing wants
	var other := _unasked_code(scn)
	scn.board.place(cell_a, code)
	scn.board.place(cell_b, other)
	scn._rebuild_pieces()
	scn._refresh_quest_ready_marks()
	ok(scn.piece_nodes.has(cell_a) and _has_glow(scn.piece_nodes[cell_a]),
		"a wanted item (code %d) wears the ready glow" % code)
	ok(scn.piece_nodes.has(cell_b) and not _has_glow(scn.piece_nodes[cell_b]),
		"an un-wanted item (code %d) carries no glow" % other)

	# the REAL hook: clear the glow, then drive _refresh_giver_lights — the beat EVERY board/quest change
	# runs — and confirm IT re-adds the glow (not just the direct _refresh_quest_ready_marks). Guards the
	# in-game wiring: a dropped hook call leaves the units green but the live board dark.
	scn.piece_nodes[cell_a].get_node("ReadyGlow").free()
	ok(not scn.piece_nodes[cell_a].has_node("ReadyGlow"), "glow cleared for the real-hook check")
	scn._refresh_giver_lights()
	ok(_has_glow(scn.piece_nodes[cell_a]),
		"the glow appears through the REAL _refresh_giver_lights hook, not only the direct refresh")

	# the live glow reflects the board's resolved _ready_glow_opts (the workbench tuning the board reads) —
	# guards the wiring: a dropped opts hand-off leaves the units green but the live board on shipped defaults.
	scn.piece_nodes[cell_a].get_node("ReadyGlow").free()
	scn._ready_glow_opts = {"color": Color("#FF0000"), "fill_a": 0.90, "halo_a": 0.80, "corner_frac": 0.20, "halo_frac": 0.15}
	scn._refresh_giver_lights()
	var live_sb: StyleBoxFlat = scn.piece_nodes[cell_a].get_node("ReadyGlow").get_theme_stylebox("panel")
	ok(live_sb != null and is_equal_approx(live_sb.bg_color.r, 1.0) and live_sb.bg_color.g < 0.2 \
		and is_equal_approx(live_sb.bg_color.a, 0.90), \
		"the live ready glow takes the board's resolved _ready_glow_opts (workbench tuning reaches the board)")

	# clearing: once no live quest asks for it, the glow is removed IN PLACE (the tile stays)
	for i in range(scn.quests.size() - 1, -1, -1):
		var qit := G.quest_item(scn.quests[i])
		if not qit.is_empty() and int(qit.line) * 100 + int(qit.tier) == code:
			scn.quests.remove_at(i)
	scn._refresh_quest_ready_marks()
	ok(scn.piece_nodes.has(cell_a) and not _has_glow(scn.piece_nodes[cell_a]),
		"the glow clears in place once nothing asks for the item")

	# the feature flag gates it: a FRESH wanted tile gets NO glow while the flag is off
	Features.FLAGS["quest_ready_glow"] = false
	scn.quests = [q]                               # re-ask `code`
	scn.board.take(cell_a); scn.board.place(cell_a, code); scn._rebuild_pieces()   # fresh node, no glow yet
	scn._refresh_quest_ready_marks()
	ok(scn.piece_nodes.has(cell_a) and not _has_glow(scn.piece_nodes[cell_a]),
		"flag off → no glow even when the item is wanted")
	Features.FLAGS["quest_ready_glow"] = true
	scn.free()

	# --- Part B: tap focuses, SECOND tap of the focused wanted tile delivers (consume + complete) ---
	# Taps drive the REAL _on_board_input handler and resolve synchronously, so assert right after each tap
	# (no await — a process frame lets the board's deferred intro re-deal wipe the model-seeded tile).
	fresh("deliver")
	scn = _board()
	q = scn.quests[0]
	it = G.quest_item(q)
	code = int(it.line) * 100 + int(it.tier)
	var reward_exp := int(Quests.exp(q))
	cell_a = scn.board.empty_ground_cells()[0]
	scn.board.place(cell_a, code)
	scn._rebuild_pieces()
	scn._refresh_quest_ready_marks()
	var at := _center(scn, cell_a)
	var exp_before: int = Save.exp_total()
	var quests_before: int = scn.quests.size()

	# FIRST tap (cell not yet focused) only FOCUSES — no delivery
	_tap(scn, at)
	ok(scn.board.item_at(cell_a) == code, "first tap leaves the item on the board (focus only)")
	ok(scn.quests.size() == quests_before, "first tap delivers nothing")
	ok(scn._selected_cell == cell_a, "first tap focuses the tile")

	# SECOND tap (now focused) DELIVERS — item consumed, quest gone, exp paid
	_tap(scn, at)
	ok(scn.board.item_at(cell_a) == 0, "second tap of the focused tile consumes the item")
	ok(not scn.quests.has(q), "second tap completes the delivered quest (it leaves the fence; the meter backfills)")
	ok(Save.exp_total() == exp_before + reward_exp, "delivering pays the quest's exp (+%d)" % reward_exp)
	scn.free()

	# --- Part B guard: a focused tile NOTHING wants never delivers (stays put) ---
	fresh("noask")
	scn = _board()
	var oc := _unasked_code(scn)
	var fc: Vector2i = scn.board.empty_ground_cells()[0]
	scn.board.place(fc, oc)
	scn._rebuild_pieces()
	var fat := _center(scn, fc)
	var fq: int = scn.quests.size()
	_tap(scn, fat)   # focus
	_tap(scn, fat)   # second tap — must NOT deliver (nothing wants `oc`)
	ok(scn.board.item_at(fc) == oc, "a focused tile nothing wants is never delivered")
	ok(scn.quests.size() == fq, "no quest is removed by tapping an un-wanted tile")
	scn.free()

	# --- Part D: add_ready_glow honours a workbench `hl` override; {} keeps the shipped look ---
	# The glow appearance is now workbench-tunable (the "ready_glow" section). add_ready_glow takes an
	# optional override dict; absent keys must reproduce the shipped READY_GLOW constants byte-for-byte.
	var holder := Control.new()
	get_root().add_child(holder)
	var g_default: Control = PieceView.add_ready_glow(holder, 100.0)         # no hl → shipped constants
	var sb_d: StyleBoxFlat = g_default.get_theme_stylebox("panel")
	ok(sb_d != null and sb_d.bg_color.is_equal_approx(Color(Color("#FFB12E"), 0.55)), \
		"default ready glow fills with the shipped amber at 0.55")
	ok(sb_d != null and is_equal_approx(sb_d.shadow_color.a, 0.6) \
		and sb_d.shadow_size == int(100.0 * 0.16) and sb_d.corner_radius_top_left == int(100.0 * 0.22), \
		"default ready glow keeps the shipped halo alpha / size / corner")

	var holder2 := Control.new()
	get_root().add_child(holder2)
	var g_tuned: Control = PieceView.add_ready_glow(holder2, 100.0, \
		{"color": Color("#1188FF"), "fill_a": 0.30, "halo_a": 0.90, "corner_frac": 0.10, "halo_frac": 0.25})
	var sb_t: StyleBoxFlat = g_tuned.get_theme_stylebox("panel")
	ok(sb_t != null and sb_t.bg_color.is_equal_approx(Color(Color("#1188FF"), 0.30)), \
		"a tuned ready glow takes the workbench colour + fill opacity")
	ok(sb_t != null and sb_t.shadow_color.is_equal_approx(Color(Color("#1188FF"), 0.90)), \
		"a tuned ready glow takes the workbench halo opacity + colour")
	ok(sb_t != null and sb_t.corner_radius_top_left == int(100.0 * 0.10) and sb_t.shadow_size == int(100.0 * 0.25), \
		"a tuned ready glow takes the workbench corner roundness + halo size")
	holder.free(); holder2.free()

	# --- Part E: the wanted ITEM itself breathes (a whole-tile pulse like a generator), not only its halo ---
	# board.gd breathes the piece's ItemArt sprite alongside the ReadyGlow, so the icon pulses with its halo —
	# matching the generator's whole-tile breathe (FX.breathe on the holder). Asserted through the live board.
	Features.FLAGS["breathe_cta"] = true          # FX.breathe is a no-op while this CTA-pulse flag is off
	fresh("breathe")
	scn = _board()
	q = scn.quests[0]
	it = G.quest_item(q)
	code = int(it.line) * 100 + int(it.tier)
	var bcell: Vector2i = scn.board.empty_ground_cells()[0]
	scn.board.place(bcell, code)
	scn._rebuild_pieces()                          # fresh node, no glow yet (rebuild never marks)
	var bnode: Control = scn.piece_nodes[bcell]
	# the item sprite the board breathes; headless runs may lack imported art (placeholder disc, no ItemArt),
	# so stand in a stub of the same name to exercise the wiring regardless of the art-import state.
	var bart: Control = bnode.get_node_or_null(PieceView.ART_NAME)
	if bart == null:
		bart = Control.new()
		bart.name = PieceView.ART_NAME
		bart.custom_minimum_size = Vector2(scn.csz, scn.csz)
		bnode.add_child(bart)
	scn._refresh_quest_ready_marks()
	ok(_has_glow(bnode), "the wanted tile wears the ready glow")
	ok(bart.has_meta("_fx_breathe_tween"), "the wanted ITEM sprite breathes too (whole-tile pulse like a generator)")
	# clearing: once nothing asks for it, the item's breathe stops and it settles back to its natural scale
	for i in range(scn.quests.size() - 1, -1, -1):
		var qit := G.quest_item(scn.quests[i])
		if not qit.is_empty() and int(qit.line) * 100 + int(qit.tier) == code:
			scn.quests.remove_at(i)
	scn._refresh_quest_ready_marks()
	ok(not bart.has_meta("_fx_breathe_tween"), "the item's breathe stops when the tile is no longer wanted")
	ok(bart.scale.is_equal_approx(Vector2.ONE), "the item settles back to its natural scale when cleared")
	scn.free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
