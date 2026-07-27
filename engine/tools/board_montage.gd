extends SceneTree
## Dev tool (REAL renderer; run via engine/tools/quiet_godot.sh): renders a DETERMINISTIC
## montage of the board's view-builders — make_piece / make_bramble / make_generator /
## make_board_mat / bust / make_giver_stand — to a PNG. The prologue is shot_base.begin, so the
## run is pinned: forced window size (the macOS height race), seeded global RNG, pinned weather,
## wiped temp save. Two runs are then pixel-identical iff the builders produce identical node
## trees. This is the before/after gate for a board/view refactor: capture before extraction,
## extract, capture after, `cmp` the two PNGs.
##   engine/tools/quiet_godot.sh --path . -s res://engine/tools/board_montage.gd -- /tmp/out.png
##
## The board script is used as a BUILDER BAG — never added to the tree — so `board` (the model
## the frontier/gate checks read) is assigned by hand; a fresh BoardModel is pure G-table data,
## which is what keeps the bramble row reproducible.

const Base = preload("res://engine/tools/shot_base.gd")
const G = preload("res://engine/scripts/core/content.gd")
const BoardScript = preload("res://engine/scripts/scenes/board.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const Bust = preload("res://engine/scripts/ui/bust.gd")

const W := 1000
const H := 1160

func _initialize() -> void:
	# The montage sheet is its own 1000x1160 canvas, not the design viewport. Without this the
	# project's canvas_items stretch drew the whole sheet at min(1000/1080, 1160/1920) = 0.604 into
	# the top-left corner and left 60% of the PNG empty — a resample that hides exactly the
	# sub-pixel builder differences this gate exists to catch. 1:1, and root.size can then match
	# the window so begin()'s _apply_size retry converges.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var ctx := await Base.begin(self, {"tool": "board_montage", "size": Vector2i(W, H),
		"default_out": "/tmp/board_montage.png", "save_dir": "/tmp/tu_board_montage/"})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var out: String = ctx["out"]

	BoardScript.forced_rng_seed = Base.RNG_SEED   # pin the board's own stream too (shot_base header)
	var b: Control = BoardScript.new()
	b.csz = 86.0
	b.board = BoardModel.new()        # the builder bag never runs _load_state — hand it the model

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

	# row 5: giver busts (0/1/2). board.gd's `_bust` wrapper is gone; ui/bust.gd IS the builder
	# it forwarded to, and `_mini_item`'s PieceView.mini_item was retired with it.
	for i in 3:
		var n: Control = Bust.make(i, 124.0)
		n.position = Vector2(12 + i * 134, 414)
		page.add_child(n)

	# the garden-bed mat (compact: shrink csz just for this call) ------------------------
	b.csz = 24.0
	var mat: Control = b._make_board_mat()
	mat.position = Vector2(660, 520)   # clear of the giver stands below (8..648) — no builder occludes another
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

	# row 8: the bag WELL preview (_rebuild_bag swaps the most-recent stashed item into the
	# bottom-nav disc; the old bag_bar HBox builder is gone with the bar itself)
	var bag_well := CenterContainer.new()
	bag_well.position = Vector2(8, 1030)
	bag_well.size = Vector2(96, 96)
	page.add_child(bag_well)
	b.bag_content = bag_well
	b.bag = [101, 305]
	b._rebuild_bag()

	await create_timer(0.4).timeout
	RenderingServer.force_draw()      # warm-up draw: a minimized window's FIRST read can be stale
	await create_timer(0.1).timeout
	var err := Base.capture(self, out, ctx["args"])
	print("MONTAGE saved=%s err=%d size=%dx%d" % [out, err, W, H])
	quit()
