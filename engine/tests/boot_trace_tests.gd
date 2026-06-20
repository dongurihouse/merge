extends SceneTree
## Headless tests for the boot instrumentation + splash progress math.
##   godot --headless -s res://engine/tests/boot_trace_tests.gd
## Covers BootTrace (begin/end work-span timer + table formatter) and boot.gd's pure
## progress helpers (boot_bar / boot_ready). No rendering — pure logic only.
##
## Span model (not wall-clock): each begin/end pair times ONLY the work inside it. Time
## SPENT BETWEEN spans — the deliberate splash min-duration and the fade — is measured by
## nothing, so it never pollutes the "what's taking long" table.

const BootTrace = preload("res://engine/scripts/core/boot_trace.gd")
const Boot = preload("res://engine/scripts/scenes/boot.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func approx(a: float, b: float) -> bool:
	return abs(a - b) < 0.001

func names(spans: Array) -> Array:
	var out := []
	for s in spans:
		out.append(s["name"])
	return out

func _initialize() -> void:
	print("== BootTrace tests ==")

	# --- inactive until start() ------------------------------------------------
	BootTrace._reset()
	ok(not BootTrace.active(), "no trace active before start()")
	BootTrace.begin("ignored")
	BootTrace.end("ignored")
	BootTrace.done()
	ok(BootTrace.spans().is_empty(), "begin/end/done no-op while inactive")

	# --- a closed span is recorded in close order ------------------------------
	BootTrace.start()
	ok(BootTrace.active(), "start() activates the trace")
	ok(BootTrace.spans().is_empty(), "no span recorded until one is closed")
	BootTrace.begin("a")
	BootTrace.end("a")
	var sp := BootTrace.spans()
	ok(sp.size() == 1 and sp[0]["name"] == "a", "end('a') records span 'a'")
	ok(sp.size() >= 1 and int(sp[0]["us"]) >= 0, "recorded duration is non-negative")
	BootTrace.begin("b")
	BootTrace.end("b")
	ok(names(BootTrace.spans()) == ["a", "b"], "spans accumulate in close order")

	# --- nested spans close independently (inner before outer) -----------------
	BootTrace._reset()
	BootTrace.start()
	BootTrace.begin("outer")
	BootTrace.begin("inner")
	BootTrace.end("inner")
	BootTrace.end("outer")
	ok(names(BootTrace.spans()) == ["inner", "outer"], "nested spans record in close order")

	# --- end() without a matching begin() is a no-op ---------------------------
	BootTrace._reset()
	BootTrace.start()
	BootTrace.end("never-began")
	ok(BootTrace.spans().is_empty(), "end() with no open span is a no-op")

	# --- done() closes any still-open span and ends the trace ------------------
	BootTrace._reset()
	BootTrace.start()
	BootTrace.begin("leftover")
	BootTrace.done()
	ok(names(BootTrace.spans()) == ["leftover"], "done() closes a still-open span")
	ok(not BootTrace.active(), "done() ends the trace")
	BootTrace.begin("after")
	BootTrace.end("after")
	ok(names(BootTrace.spans()) == ["leftover"], "begin/end after done() are no-ops")

	# --- format_table: pure formatting -----------------------------------------
	var table := BootTrace.format_table([
		{"name": "scene.load", "us": 268400},
		{"name": "map.open_map", "us": 96400},
	], 364800)
	ok(table.contains("scene.load"), "table lists span names")
	ok(table.contains("268.4"), "table renders ms to one decimal (268.4)")
	ok(table.contains("96.4"), "table renders the second span ms")
	ok(table.contains("total") and table.contains("364.8"), "table prints a total row")
	ok(table.count("\n") >= 3, "table is multi-line")

	# --- boot_bar: honest progress paced by a minimum duration -----------------
	ok(approx(Boot.boot_bar(0.0, 1.0, 0.0, false), 0.0), "bar starts at 0 on cold boot")
	ok(approx(Boot.boot_bar(0.5, 1.0, 0.5, false), 0.5), "bar tracks blended load progress mid-boot")
	ok(approx(Boot.boot_bar(2.0, 1.0, 1.0, false), 0.9), "bar HOLDS at 0.9 until the scene is warm")
	ok(approx(Boot.boot_bar(0.3, 1.0, 1.0, true), 0.3), "warm-but-early: bar still paced by min duration")
	ok(approx(Boot.boot_bar(1.5, 1.0, 1.0, true), 1.0), "warm-and-past-min: bar reaches full")

	# --- boot_ready: only hand off when warm AND min time elapsed ---------------
	ok(not Boot.boot_ready(2.0, 1.0, false), "not ready while the scene is still loading")
	ok(not Boot.boot_ready(0.3, 1.0, true), "not ready before the minimum splash duration")
	ok(Boot.boot_ready(1.0, 1.0, true), "ready once warm and past the minimum duration")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
