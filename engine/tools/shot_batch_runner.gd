extends RefCounted
## Runs MANY captures in ONE Godot process. See engine/tools/shot_batch.gd for the entry point and
## the plan-file format; this file is the loop.
##
## WHY. A capture costs a fraction of a second; the BOOT in front of it costs ~1.3 s, and agents take
## on the order of 160 screenshots a session. So most of the wall-clock is boot — and every boot is a
## separate application launch, i.e. a separate chance to interrupt whoever is at the keyboard
## (engine/tools/nofocus_shim.m covers the launch that remains; this file removes the other 159).
##
## HOW. `-s` makes the tool script the SceneTree's script, and a tool's whole body is its
## `_initialize()`. So a batch re-points the LIVE SceneTree at each tool in turn — `set_script`, then
## `await tree._initialize()` — and the tool runs exactly as it does under `make shot`, on the same
## root, with the same window. Two hooks in shot_base make that safe: `Base.batch_args` feeds the
## item's arguments where the tool would have read the command line, and `Base.finish` swallows the
## per-item quit.
##
## WHY THE LOOP LIVES IN A SEPARATE OBJECT. `set_script` on the SceneTree destroys the script instance
## the driver's own `_initialize()` is suspended inside, so a loop written there never resumes past the
## first item (measured — the run hangs after the last capture with no error). This runner is a plain
## RefCounted, untouched by the tree's script changing, and it is what finally calls `tree.quit`.
##
## WHICH TOOLS. Only tools that take EVERY input through `shot_base.begin` and leave no global state
## behind can be batched, so membership is an explicit list, not a guess. The UI/FX/scene workbenches
## are deliberately absent: they read `OS.get_cmdline_user_args()` themselves and reshape the root
## viewport's content-scale and the window size for their own layout, which the next item would
## inherit. They are also the tools agents call least. Use `make shot-workbench` for those.

const Base = preload("res://engine/tools/shot_base.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const BoardScript = preload("res://engine/scripts/scenes/board.gd")
const Debug = preload("res://engine/scripts/ui/debug.gd")
const Ambient = preload("res://engine/scripts/ui/ambient.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const CascadeOutline = preload("res://engine/scripts/ui/cascade_outline.gd")

## tool name (and its `make shot TOOL=` path) → the script the batch runs for it.
const BATCHABLE := {
	"grove": "res://games/grove/tools/grove_shot.gd",
	"map": "res://games/grove/tools/map_shot.gd",
	"widget": "res://games/grove/tools/widget_shot.gd",
	"games/grove/tools/grove_shot": "res://games/grove/tools/grove_shot.gd",
	"games/grove/tools/map_shot": "res://games/grove/tools/map_shot.gd",
	"games/grove/tools/widget_shot": "res://games/grove/tools/widget_shot.gd",
}

## Keeps the runner alive: the driver's `_initialize()` frame is discarded by the first `set_script`,
## and with it the only local reference to this object.
static var keep: RefCounted

func run(tree: SceneTree) -> void:
	var argv := OS.get_cmdline_user_args()
	if argv.size() < 1:
		print("REFUSED: shot-batch needs a PLAN file — make shot-batch PLAN=/tmp/plan.txt")
		tree.quit(2)
		return
	var plan_path := String(argv[0])
	var items := _parse(plan_path)
	if items.is_empty():
		print("REFUSED: no capture requests in %s (one per line: <tool> <args...>; # comments)" % plan_path)
		tree.quit(2)
		return

	Base.batch = true
	var t0 := Time.get_ticks_msec()
	var worst := 0
	var done := 0
	for item in items:
		var tool_name: String = item["tool"]
		if not BATCHABLE.has(tool_name):
			print("REFUSED: '%s' is not batch-safe — run it with `make shot TOOL=%s`." % [tool_name, tool_name])
			print("  batchable: %s" % ", ".join(PackedStringArray(BATCHABLE.keys())))
			worst = 2
			continue
		_reset(tree)
		Base.batch_args = item["args"]
		Base.last_code = 0
		var started := Time.get_ticks_msec()
		tree.set_script(load(String(BATCHABLE[tool_name])))
		await tree._initialize()
		var code := Base.last_code
		if code != 0:
			worst = code
		done += 1
		print("BATCH item %d/%d %s %s -> code=%d %dms" % \
			[done, items.size(), tool_name, " ".join(PackedStringArray(item["args"])), code,
			Time.get_ticks_msec() - started])
	print("BATCH done items=%d worst_code=%d total=%dms" % [done, worst, Time.get_ticks_msec() - t0])
	Base.batch = false
	tree.quit(worst)

## Put the process back the way a fresh boot would have it. Everything a batchable tool touches is
## either re-established by `shot_base.begin` on the next item (RNG seed, weather, window size, the
## temp save dir) or cleared here: the scene it built, and the two statics a tool sets outside
## `begin`. A tool that starts leaving other global state behind belongs OUT of BATCHABLE, and
## games/grove/tests/grove_shot_batch_tests.gd is what catches it — it re-captures a batch and
## compares the PNGs byte for byte against the same shots taken one process each.
func _reset(tree: SceneTree) -> void:
	tree.current_scene = null
	for child in tree.root.get_children():
		tree.root.remove_child(child)
		child.queue_free()
	await tree.process_frame
	await tree.process_frame
	Audio.reset_for_batch()
	BoardScript.forced_rng_seed = -1
	Debug.force = false
	Ambient.forced_weather = ""
	CascadeOutline.forced_phase = -1.0
	# `grove cascade phase=run` freezes the clock to hold a mid-run frame still for its capture. Left
	# frozen, every `create_timer` the NEXT item awaits never fires and the batch hangs — so the clock
	# is part of the global state a reset has to put back.
	Engine.time_scale = 1.0
	# The cozy UI theme installs itself ONCE per process onto the root (ui_font.apply, latched by
	# its `_done`). A tool that never asks for it — widget_shot renders on a bare root — therefore
	# came out with the game font in a batch and the engine default on its own: MEASURED, the two
	# PNGs differed across the label row. Uninstall it so every item starts from the same root.
	UiFont._done = false
	tree.root.theme = null

## One request per line: `<tool> <arg>...`. Blank lines and `#` comments are skipped. Arguments are
## whitespace-separated — every argument the shot tools take is a path, a mode or a `key=value`, so
## there is nothing to quote, and a plan line with a space inside an argument is not supported.
func _parse(path: String) -> Array:
	var text := ""
	if FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	else:
		print("REFUSED: no plan file at %s" % path)
		return []
	var items: Array = []
	for raw in text.split("\n"):
		var line := String(raw).strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var fields := line.split(" ", false)
		var args: Array = []
		for i in range(1, fields.size()):
			args.append(String(fields[i]))
		items.append({"tool": String(fields[0]), "args": args})
	return items
