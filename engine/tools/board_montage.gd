extends SceneTree
## Dev tool (REAL renderer; run via engine/tools/quiet_godot.sh): renders a DETERMINISTIC
## montage of the board's view-builders — make_piece / make_bramble / make_generator /
## make_board_mat / bust / mini_item — to a PNG. No rng, no ambient, no weather, no time, so
## two runs are pixel-identical iff the builders produce identical node trees. This is the
## before/after gate for the board-decomposition Wave 2 (docs/design/board_decomposition.md):
## capture before extraction, extract, capture after, `cmp` the two PNGs.
##   engine/tools/quiet_godot.sh --path . -s res://engine/tools/board_montage.gd -- /tmp/out.png

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const BoardScript = preload("res://engine/scripts/scenes/board.gd")

const W := 1000
const H := 1040

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via engine/tools/quiet_godot.sh (born-minimized, no-focus window).")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var uargs := OS.get_cmdline_user_args()
	var out: String = String(uargs[0]) if uargs.size() >= 1 else "/tmp/board_montage.png"

	var dir := "/tmp/tu_board_montage/"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	await create_timer(0.2).timeout
	DisplayServer.window_set_size(Vector2i(W, H))
	await create_timer(0.2).timeout

	var b: Control = BoardScript.new()
	b.csz = 86.0

	var page := Control.new()
	page.size = Vector2(W, H)
	var bg := ColorRect.new()
	bg.color = Color("#2A2A1E")
	bg.size = Vector2(W, H)
	page.add_child(bg)
	root.add_child(page)

	# rows 1-2: make_piece across lines/tiers, plus a coin (coin branch) ----------------
	var codes := [101, 102, 103, 104, 105, 106, 107, 108, 201, 301, 401, G.COIN_LINE * 100 + 1]
	for i in codes.size():
		var n: Control = b._make_piece(int(codes[i]), 86.0)
		n.position = Vector2(12 + (i % 8) * 92, 12 + (i / 8) * 98)
		page.add_child(n)

	# row 3: make_bramble for cells with different level gates → different ring art -------
	var cells := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(0, 6)]
	for i in cells.size():
		var n: Control = b._make_bramble(cells[i])
		n.position = Vector2(12 + i * 96, 210)
		page.add_child(n)

	# row 4: make_generator for the map-0 generators -----------------------------------
	var gens: Dictionary = G.live_gen_state(G.GENERATORS, 0)
	var gi := 0
	for cell in gens:
		var n: Control = b._make_generator(String(gens[cell]))
		n.position = Vector2(12 + gi * 96, 312)
		page.add_child(n)
		gi += 1

	# row 5: busts (0/1/2) + a mini_item ------------------------------------------------
	for i in 3:
		var n: Control = b._bust(i, 124.0)
		n.position = Vector2(12 + i * 134, 414)
		page.add_child(n)
	var mi: Control = b._mini_item(101)
	mi.position = Vector2(430, 444)
	page.add_child(mi)

	# the garden-bed mat (compact: shrink csz just for this call) ------------------------
	b.csz = 24.0
	var mat: Control = b._make_board_mat()
	mat.position = Vector2(560, 520)
	page.add_child(mat)

	# row 6: giver stands via _make_giver_stand (fence slice-1 builder; a normal + a featured stand)
	var q_norm := {"asks": [{"line": 1, "tier": 2, "count": 1}], "reward": {"stars": 2, "coins": 0}}
	var q_feat := {"asks": [{"line": 2, "tier": 1, "count": 1}, {"line": 3, "tier": 2, "count": 2}], "reward": {"stars": 1, "coins": 0, "gems": 1}, "featured": true}
	var st0: Dictionary = b._make_giver_stand(0, q_norm)
	st0.chip.position = Vector2(8, 558)
	page.add_child(st0.chip)
	var st1: Dictionary = b._make_giver_stand(1, q_feat)
	st1.chip.position = Vector2(348, 558)
	page.add_child(st1.chip)

	# row 7: the merchant stall (merchant-slice builder) ---------------------------------
	var ms: Control = b._make_merchant_stand()
	ms.position = Vector2(8, 826)
	page.add_child(ms)

	await create_timer(0.4).timeout
	RenderingServer.force_draw()
	await create_timer(0.1).timeout
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	print("MONTAGE saved=%s err=%d size=%dx%d" % [out, err, img.get_width(), img.get_height()])
	quit()
