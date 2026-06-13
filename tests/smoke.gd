extends SceneTree
## Headless smoke test: instantiate Main.tscn, run _ready (build the board UI,
## load level 1), confirm it stands up without errors.
##   godot --headless -s res://tests/smoke.gd

const Save = preload("res://scripts/save.gd")
const Board = preload("res://scripts/board.gd")

func _initialize() -> void:
	# never touch the real save (Main pays coins on _play_zero; Jobs auto-collects lumps)
	var dir := "user://tu_test_smoke/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	var ps := load("res://scenes/Main.tscn")
	if ps == null:
		print("FAIL: could not load Main.tscn")
		quit(1)
		return
	var inst = ps.instantiate()
	get_root().add_child(inst)
	if inst.title_label == null:   # _ready may not auto-fire under -s; do it explicitly
		inst._ready()
	var slots: int = inst.slot_nodes.size()
	var pieces: int = inst.piece_nodes.size()
	var ok: bool = inst.board != null and inst.board.rows == 3 and slots == 9 and pieces == 2
	var title: String = inst.title_label.text if inst.title_label else "(none)"
	print("SMOKE: board=%s slots=%d pieces=%d level='%s' -> %s" % [str(inst.board != null), slots, pieces, title, "OK" if ok else "FAIL"])

	# Generated item art: importable AND actually placed on tiles (level 1 = clothes_1).
	var art_importable: bool = ResourceLoader.exists("res://assets/items/clothes_1.png")
	var uses_art := false
	for cell in inst.piece_nodes:
		for ch in inst.piece_nodes[cell].get_children():
			if ch is TextureRect:
				uses_art = true
	print("ART: clothes_1 importable=%s, tiles show textures=%s -> %s" % [str(art_importable), str(uses_art), "OK" if (art_importable and uses_art) else "FAIL"])
	ok = ok and art_importable and uses_art

	# Drag-any-to-any: level 1 = two T1 socks (same code) at (1,1),(1,2), top=1. Press (1,1),
	# release on the matching sock (1,2) → merge → showcase → board cleared (sync in _commit).
	inst._on_press(Vector2(266, 266))    # cell (row 1, col 1) center
	inst._on_release(Vector2(448, 266))  # cell (row 1, col 2) center — a MATCHING item
	var drag_ok: bool = inst.board.is_cleared()
	print("MERGE: drag-any-to-any cleared board = %s -> %s" % [str(drag_ok), "OK" if drag_ok else "FAIL"])
	ok = ok and drag_ok

	# Exercise the ZERO catharsis + particle path (only runs on a board clear, so the
	# load-only check above never touches it). Force an empty board and play the screen.
	var cleared := []
	for k in inst.board.rows * inst.board.cols:
		cleared.append(0)
	inst.board.grid = cleared
	var before: int = inst.get_child_count()
	inst._play_zero()
	var zero_ok: bool = inst.get_child_count() > before
	print("ZERO: overlay created = %s -> %s" % [str(zero_ok), "OK" if zero_ok else "FAIL"])

	# Menu scene compiles & builds.
	var menu_ok := false
	var menu_ps := load("res://scenes/Menu.tscn")
	if menu_ps:
		var minst = menu_ps.instantiate()
		get_root().add_child(minst)
		if minst.get_child_count() == 0:
			minst._ready()
		menu_ok = minst.get_child_count() > 0
	print("MENU: built = %s -> %s" % [str(menu_ok), "OK" if menu_ok else "FAIL"])

	# Bedroom restoration scene compiles & builds.
	var room_ok := false
	var room_ps := load("res://scenes/Room.tscn")
	if room_ps:
		var rinst = room_ps.instantiate()
		get_root().add_child(rinst)
		if rinst.get_child_count() == 0:
			rinst._ready()
		room_ok = rinst.get_child_count() > 0
	print("ROOM: built = %s -> %s" % [str(room_ok), "OK" if room_ok else "FAIL"])

	# No-move rescue: a dead board (no legal merge, drawers still locked) shakes
	# itself loose instead of soft-locking the player into Restart.
	inst._load_level(2)                       # tidy_03 — the drawers level (5x5)
	var g := []
	for k in inst.board.rows * inst.board.cols:
		g.append(0)
	g[0] = 101                                # two lone pieces with no partner…
	g[24] = 201
	g[18] = Board.DRAWER                      # …and two locked drawers out of reach
	g[20] = Board.DRAWER
	inst.board.grid = g
	inst.drawer_contents = {18: 101, 20: 201}
	inst._rebuild_pieces()
	inst._rescue_if_stuck()
	var rescue_ok: bool = inst.board.at(3, 3) == 101 and inst.board.at(4, 0) == 201 \
		and inst.drawer_contents.is_empty()
	print("RESCUE: dead board shakes loose = %s -> %s" % [str(rescue_ok), "OK" if rescue_ok else "FAIL"])
	ok = ok and rescue_ok

	# Jobs map scene compiles & builds (district cards, pins, lock veils).
	var jobs_ok := false
	var jobs_ps := load("res://scenes/Jobs.tscn")
	if jobs_ps:
		var jinst = jobs_ps.instantiate()
		get_root().add_child(jinst)
		if jinst.get_child_count() == 0:
			jinst._ready()
		jobs_ok = jinst.get_child_count() > 0 and jinst.card_hosts.size() == 3
	print("JOBS: built = %s -> %s" % [str(jobs_ok), "OK" if jobs_ok else "FAIL"])

	# Grove (v2 P1) scene compiles & builds with a persistent brambled board.
	var grove_ok := false
	var grove_ps := load("res://scenes/Grove.tscn")
	if grove_ps:
		var ginst = grove_ps.instantiate()
		get_root().add_child(ginst)
		if ginst.board == null:
			ginst._ready()
		grove_ok = ginst.board != null and ginst.board.bramble_count() > 0 and not ginst.giver_chips.is_empty()
	print("GROVE: built = %s -> %s" % [str(grove_ok), "OK" if grove_ok else "FAIL"])

	# Home (v2 P3 — the boot scene) builds with its zones.
	var home_ok := false
	var home_ps := load("res://scenes/Home.tscn")
	if home_ps:
		var hinst = home_ps.instantiate()
		get_root().add_child(hinst)
		if hinst.vista == null:
			hinst._ready()
		home_ok = hinst.vista != null and hinst.zone_nodes.size() == 5 and hinst.zone_unlocked(0)
	print("HOME: built = %s -> %s" % [str(home_ok), "OK" if home_ok else "FAIL"])

	quit(0 if ok and zero_ok and menu_ok and room_ok and jobs_ok and grove_ok and home_ok else 1)
