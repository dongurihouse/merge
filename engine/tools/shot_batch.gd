extends SceneTree
## Many captures, ONE Godot launch.
##
##   make shot-batch PLAN=/tmp/plan.txt
##
## The plan is one request per line — the tool, then the arguments `make shot` would take:
##
##   # a comment
##   grove  hud    /tmp/hud.png
##   grove  played /tmp/played.png
##   map    fresh  /tmp/map.png
##   widget /tmp/w.png 104 104:glow
##
## Tool names: `grove`, `map`, `widget` (their `games/grove/tools/<name>_shot` paths work too).
## Anything else is refused by name rather than run — see BATCHABLE in shot_batch_runner.gd for
## which tools are batch-safe and why the workbenches are not.
##
## PREFER THIS over a run of `make shot-grove` calls. A capture is a fraction of a second on top of
## a ~1.3 s boot, so ten captures in one process take about a fifth of the time ten launches do, and
## they interrupt the owner once instead of ten times. The output PNGs are byte-identical to the
## one-process-each shots (games/grove/tests/grove_shot_batch_tests.gd proves it).
##
## The loop itself is in shot_batch_runner.gd, and it is deliberately NOT awaited here: the first
## `set_script` on this tree replaces the script this function belongs to, so nothing after the call
## would ever run. The runner owns the rest of the process, including the exit.

const Runner = preload("res://engine/tools/shot_batch_runner.gd")

func _initialize() -> void:
	var runner := Runner.new()
	Runner.keep = runner
	runner.run(self)
