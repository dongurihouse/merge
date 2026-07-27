extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot an Explore screen.
##   quiet_godot.sh --path . -s res://games/grove/tools/explore_shot.gd -- <loadout|rush|trade> <out.png>
##   quiet_godot.sh --path . -s res://games/grove/tools/explore_shot.gd -- trade <out.png> revealed=12
## Seeds a completed map (so the spirit pool is non-empty), coins, and a run; for `rush` it lets the board
## fill for a couple of seconds before capturing. Mirrors residents_screen_shot.gd's quiet header
## (REFUSES unless override.cfg exists — the born-minimized window must come from quiet_godot.sh).
## Parallel-safe (own temp save).

const Base = preload("res://engine/tools/shot_base.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Explore = preload("res://engine/scripts/core/explore.gd")
const ExploreReward = preload("res://engine/scripts/ui/explore_reward.gd")

func _initialize() -> void:
	var ctx := await Base.begin(self, {
		"tool": "explore",
		"default_mode": "rush",       # rush | trade (Load out is now a map dialog)
		"default_out": "/tmp/explore_%s.png",
		"save_dir": "/tmp/tu_exploreshot_%s/",
	})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var args: Array = ctx["args"]
	var which: String = ctx["mode"]
	var out: String = ctx["out"]
	var revealed := int(Base.opt(args, "revealed", "0"))

	# unlock EVERY map so the spirit pool spans all kinds (a richer, more representative reward shot), plus a
	# fat wallet for the loadout
	var g := Save.grove()
	var unl := {}
	var gates := []
	for zz in G.MAPS.size():
		gates.append(zz)
		for sp in G.MAPS[zz].spots:
			unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = gates
	Save.grove_write()
	Save.add_coins(2000)

	var path := "res://engine/scenes/ExploreRush.tscn"
	match which:
		"trade":
			Explore.begin_run({})
			path = "res://engine/scenes/ExploreRush.tscn"   # the reward is now an overlay ON the board
		_:
			Explore.begin_run({"time": true, "drops": true})
			path = "res://engine/scenes/ExploreRush.tscn"

	var scn = load(path).instantiate()
	root.add_child(scn)
	current_scene = scn
	if which == "trade":
		scn.set_process(false)                   # freeze the board as a static backdrop behind the overlay
		Explore.add_score((revealed if revealed > 0 else 7) * Explore.TRADE_RATE)  # set after the board's _ready, before the overlay reads it
		ExploreReward.open(scn, {"on_done": func() -> void: pass})
		await create_timer(3.9).timeout          # let the reel cascade land (SPIN_CFG total_cap 3.5)
		var et := Base.capture(self, out, args)
		print("SHOT explore/trade=%s (err %d)" % [out, et])
		quit()
		return
	# midfall=1: clear the board, force-spawn one tile, capture it part-way through its drop (a guaranteed
	# mid-fall frame, since random sequence captures keep landing on settled tiles).
	if which == "rush" and Base.flag(args, "midfall"):
		await create_timer(0.4).timeout
		scn.set_process(false)
		_clear_grid(scn)
		scn._spawn()
		await create_timer(0.12).timeout           # let the fall tween run part-way
		var em := Base.capture(self, out, args)
		print("SHOT explore/rush midfall=%s (err %d)" % [out, em])
		quit()
		return
	if which == "rush" and Base.flag(args, "fling"):
		# clear the board, drop a lone tile at column 0, tap it (no match -> fling), capture mid-arc
		await create_timer(0.4).timeout
		scn.set_process(false)
		_clear_grid(scn)
		var ft = scn._make_tile(1, 1, G.ROWS - 1, 0)
		scn._grid[G.ROWS - 1][0] = {"kind": 1, "tier": 1, "node": ft}
		await create_timer(0.45).timeout           # let the spawn-fall finish
		scn._on_tile(ft)                           # fling
		await create_timer(0.18).timeout           # catch it mid-arc
		var ef := Base.capture(self, out, args)
		print("SHOT explore/rush fling=%s (err %d)" % [out, ef])
		quit()
		return
	# seq=N: dump N frames at ~0.12s intervals (catches tiles mid-fall to show the drop). Else one frame.
	var seq := int(Base.opt(args, "seq", "0"))
	if seq > 0:
		var base := out.trim_suffix(".png")
		await create_timer(0.6).timeout                 # let a couple of tiles spawn first
		for i in seq:
			Base.capture(self, "%s_%02d.png" % [base, i])
			await create_timer(0.12).timeout
		print("SHOT explore/%s seq=%d base=%s" % [which, seq, base])
		quit()
		return
	# rush needs a few seconds of frames to drop tiles; the others just need a layout pass
	var wait := 2.4 if which == "rush" else 0.7
	await create_timer(wait).timeout
	var e := Base.capture(self, out, args)
	print("SHOT explore/%s=%s (err %d)" % [which, out, e])
	quit()

# Empty the rush grid so a fixture can stage exactly the tiles it wants to show.
func _clear_grid(scn) -> void:
	for r in G.ROWS:
		for c in G.COLS:
			if scn._grid[r][c] != null:
				(scn._grid[r][c].node as Node).queue_free()
				scn._grid[r][c] = null
