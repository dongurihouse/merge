extends SceneTree
## Dev tool (real renderer; run via engine/tools/quiet_godot.sh): screenshot the Explore Rush
## with the rush-start teaching popup ("Tap to Merge!") + the always-on bottom hint.
##   quiet_godot.sh --path . -s res://games/grove/tools/rush_shot.gd -- <mode> <out.png> [WxH]
## modes: intro (default — popup mid-HOLD + bottom hint) | retired (4th rush: bottom hint only, no popup)
##        | treefall (retired + a telegraphed treefall at ~4s — the warning pill + danger column)
##        | merge_hint (retired + the FTUE hand teach on a seeded mergeable pair)
## In treefall + merge_hint the FTUE hand hint (engine/scripts/ui/hand_hint.gd) is forced on so the
## shot captures the teaching hand.

const Base = preload("res://engine/tools/shot_base.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Explore = preload("res://engine/scripts/core/explore.gd")
const G = preload("res://engine/scripts/core/content.gd")

func _initialize() -> void:
	var ctx := await Base.begin(self, {
		"tool": "rush",
		"default_mode": "intro",
		"default_out": "/tmp/rush_%s.png",
		"save_dir": "/tmp/tu_rushshot_%s/",
	})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var args: Array = ctx["args"]
	var mode: String = ctx["mode"]
	var out: String = ctx["out"]
	if mode == "retired" or mode == "treefall" or mode == "merge_hint":
		for _i in Explore.RUSH_INTRO_SHOWS:        # spend the popup gate → only the bottom hint should remain
			Save.mark_rush_intro_seen()
	Explore.begin_run({})

	var scn = load("res://engine/scenes/ExploreRush.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.12).timeout               # let _ready build the board + kick off the popup tween
	if mode == "merge_hint":                        # a deterministic board with a guaranteed mergeable pair
		var br: int = int(G.ROWS) - 1
		scn._grid[br][0] = {"kind": 1, "tier": 1, "node": scn._make_tile(1, 1, br, 0)}
		scn._grid[br][1] = {"kind": 1, "tier": 1, "node": scn._make_tile(1, 1, br, 1)}
		scn._grid[br][3] = {"kind": 2, "tier": 1, "node": scn._make_tile(2, 1, br, 3)}   # a non-matching decoy
		scn._grid[br][5] = {"kind": 3, "tier": 2, "node": scn._make_tile(3, 2, br, 5)}   # another decoy
	else:
		for _i in 6:                                # seed a few tiles so the board reads as a live rush
			scn._spawn()
	await create_timer(0.4).timeout                 # tiles settle; the popup sits in its ~0.9s HOLD window
	if mode == "treefall":                          # telegraph a treefall mid-countdown (~4s remaining)
		scn._tf = {"ph": "tele", "t": maxf(0.0, float(Explore.WARN) - 4.0), "col": 3, "next": 9.0}
		if Explore.bottom_filled(scn._grid, 3) < 0:   # guarantee the doomed column has a tile to point at
			var br3: int = scn._bottom_empty(3)
			if br3 >= 0:
				scn._grid[br3][3] = {"kind": 2, "tier": 1, "node": scn._make_tile(2, 1, br3, 3)}
		scn._apply_treefall_visual()
		scn._refresh_readouts()
		await create_timer(0.1).timeout
	if mode == "treefall" or mode == "merge_hint":  # force the FTUE teach so the shot captures the hand
		scn._refresh_hand_hint()
		await create_timer(0.2).timeout

	var err := Base.capture(self, out, args)
	var popup: Node = scn.find_child("RushTapHint", true, false)
	print("SHOT saved=%s err=%d mode=%s intro_seen=%d popup_present=%s" % \
		[out, err, mode, Save.rush_intro_seen(), popup != null])
	quit()
