extends SceneTree
## Headless smoke tests for engine/scripts/ui/feel.gd — the shared FEEL VERBS module. At
## Phase 0 the verbs are stubs; this just proves the module loads and its no-op helpers run.
##   godot --headless --path . -s res://engine/tests/feel_tests.gd

const Feel = preload("res://engine/scripts/ui/feel.gd")

var _pass := 0
var _fail := 0
func ok(cond: bool, label: String) -> void:
	if cond: _pass += 1; print("  PASS  ", label)
	else: _fail += 1; print("  FAIL  ", label)

func _initialize() -> void:
	# the module loads + exposes its shared palette
	ok(Feel != null, "feel module loads")
	ok(Feel.LEAF is Color, "feel exposes the LEAF palette colour")
	# the haptic stub is a no-op — calling it must not error
	Feel.haptic("tick")
	ok(true, "haptic('tick') is a no-op stub that runs without error")
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
