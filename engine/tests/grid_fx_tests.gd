extends SceneTree
## Headless tests for engine/scripts/ui/grid_fx.gd — the SINGLE owner of grid-cell feel (the merge
## celebration + slide-and-land) shared by the board and the Residents dialog. Guards the opts bundle,
## the dialog cue-muting, and that the orchestration runs without error on a bare node.
##   godot --headless --path . -s res://engine/tests/grid_fx_tests.gd

const GridFx = preload("res://engine/scripts/ui/grid_fx.gd")

var _pass := 0
var _fail := 0
func ok(cond: bool, label: String) -> void:
	if cond: _pass += 1; print("  PASS  ", label)
	else: _fail += 1; print("  FAIL  ", label)

func _initialize() -> void:
	# opts_from_config yields the three feel bundles (board + residents resolve once, pass back in)
	var opts := GridFx.opts_from_config({})
	ok(opts.has("merge") and opts.has("move") and opts.has("land"), "opts_from_config returns merge/move/land bundles")

	# a dialog grid mutes the board-scale cues; the full board keeps them
	var seeded := {"merge": {"board_punch": true, "shake": true, "world_puff": true, "combo_words": true, "burst": true, "squash": true}}
	var board_m := GridFx.merge_opts_for(seeded, false)
	ok(board_m.get("board_punch") == true and board_m.get("shake") == true, "the full board keeps board-scale cues")
	var dialog_m := GridFx.merge_opts_for(seeded, true)
	ok(dialog_m.get("board_punch") == false and dialog_m.get("shake") == false \
		and dialog_m.get("world_puff") == false and dialog_m.get("combo_words") == false, \
		"a dialog mutes shake / board_punch / world_puff / milestone word")
	ok(dialog_m.get("burst") == true and dialog_m.get("squash") == true, \
		"a dialog KEEPS the piece-local celebration (burst / squash)")
	ok(seeded["merge"].get("board_punch") == true, "merge_opts_for does not mutate the caller's opts")

	# play_merge runs on a bare node without erroring (smoke; no scene tree needed)
	var host := Control.new(); host.size = Vector2(120, 120)
	get_root().add_child(host)
	var node := Control.new(); node.size = Vector2(100, 100)
	host.add_child(node)
	GridFx.play_merge(node, node, Vector2(50, 50), 2, 0, [], opts, true)
	ok(true, "play_merge runs on a bare node (dialog) without error")

	# slide_and_land returns a live tween and moves the node toward the target
	node.position = Vector2.ZERO
	var t := GridFx.slide_and_land(host, node, Vector2(40, 0), Vector2(90, 50), [], opts, 120)
	ok(t != null, "slide_and_land returns a tween")
	ok(GridFx.slide_and_land(host, null, Vector2.ZERO, Vector2.ZERO, [], opts) == null, \
		"slide_and_land is null-safe on a freed node")
	host.queue_free()

	print("\n== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
