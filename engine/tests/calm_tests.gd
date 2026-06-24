extends SceneTree
## Headless tests for CALM mode (§12 "Juice Vocabulary"): calm halves particles AND
## disables `breathe` — quiets the screen without losing function.
## This suite covers the breathe half (the particle-halving is `amount_for`, exercised
## elsewhere): the `breathe_active()` gate and the no-op behaviour of breathe/breathe_once.
##   godot --headless --path . -s res://engine/tests/calm_tests.gd

const FX = preload("res://engine/scripts/ui/fx.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").FX

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _initialize() -> void:
	# The breathe flag must be ON for these assertions to isolate the calm gate.
	Features.FLAGS["breathe_cta"] = true

	# --- the pure gate: breathe_active() == (flag on) AND (calm off) -----------------
	Save.set_setting("calm", false)
	ok(FX.breathe_active(), "calm OFF + flag ON → breathe is active")

	Save.set_setting("calm", true)
	ok(not FX.breathe_active(), "calm ON → breathe is NOT active (§12: calm disables breathe)")

	Save.set_setting("calm", false)
	ok(FX.breathe_active(), "toggling calm back OFF re-activates breathe (read at fire time)")

	# the flag still gates regardless of calm
	Features.FLAGS["breathe_cta"] = false
	Save.set_setting("calm", false)
	ok(not FX.breathe_active(), "breathe flag OFF → not active even with calm off")
	Features.FLAGS["breathe_cta"] = true

	# --- calm leaves the node at rest (no lingering animation state) -----------------
	# breathe(node) under calm must NOT start a pulse and must rest scale at ~1.0.
	Save.set_setting("calm", true)
	var n := Control.new()
	n.size = Vector2(100, 100)
	n.scale = Vector2(1.5, 1.5)            # pretend a stale pulse left it mid-scale
	get_root().add_child(n)
	FX.breathe(n)
	ok(n.scale.is_equal_approx(Vector2.ONE), "calm: breathe(node) rests scale at ~1.0 (no lingering pulse)")
	ok(n.get_tree_string_pretty() != null, "calm: breathe(node) did not crash on a real node")

	# breathe_once(node) under calm: same rest, and it must NOT latch the guard meta
	# (so a later calm-off call can still start the pulse).
	var m := Control.new()
	m.size = Vector2(100, 100)
	m.scale = Vector2(1.5, 1.5)
	get_root().add_child(m)
	FX.breathe_once(m)
	ok(m.scale.is_equal_approx(Vector2.ONE), "calm: breathe_once(node) rests scale at ~1.0")
	ok(not m.has_meta("_fx_breathing"), "calm: breathe_once does NOT latch the breathing guard (so it can pulse later)")

	# callers must stay safe — a null / freed node never crashes
	FX.breathe(null)
	FX.breathe_once(null)
	ok(true, "calm: breathe/breathe_once tolerate a null node (no crash)")

	# --- sanity: with calm OFF the guard latches as before (active path) -------------
	Save.set_setting("calm", false)
	var a := Control.new()
	a.size = Vector2(100, 100)
	get_root().add_child(a)
	FX.breathe_once(a)
	ok(a.has_meta("_fx_breathing"), "calm OFF: breathe_once latches the guard (pulse started)")

	n.queue_free()
	m.queue_free()
	a.queue_free()

	# leave settings clean for any shared state
	Save.set_setting("calm", false)

	# --- squash_pop: squash & stretch (active) vs gentle overshoot (calm) ------------
	Save.set_setting("calm", false)
	var sp := Control.new(); sp.size = Vector2(80, 80); get_root().add_child(sp)
	FX.squash_pop(sp)
	ok(sp.scale.is_equal_approx(Tune.SQUASH_K[0]), "squash_pop: active path sets the squash-start pose")
	ok(sp.pivot_offset.is_equal_approx(Vector2(40, 40)), "squash_pop: scales from the node centre")

	Save.set_setting("calm", true)
	var spc := Control.new(); spc.size = Vector2(80, 80); get_root().add_child(spc)
	FX.squash_pop(spc)
	ok(not spc.scale.is_equal_approx(Tune.SQUASH_K[0]), "squash_pop: calm uses the gentle overshoot, not the squash pose")
	FX.squash_pop(null)
	ok(true, "squash_pop: tolerates a null node (no crash)")
	Save.set_setting("calm", false)
	sp.queue_free(); spc.queue_free()

	# --- flash: a brief white overlay (gated on merge_impact, off under calm) --------
	Features.FLAGS["merge_impact"] = true
	Save.set_setting("calm", false)
	var fh := Control.new(); fh.size = Vector2(200, 200); get_root().add_child(fh)
	FX.flash(fh, Vector2(100, 100), 64.0)
	ok(fh.get_child_count() == 1, "flash: active path adds a white overlay child")

	Save.set_setting("calm", true)
	var fh2 := Control.new(); fh2.size = Vector2(200, 200); get_root().add_child(fh2)
	FX.flash(fh2, Vector2(100, 100), 64.0)
	ok(fh2.get_child_count() == 0, "flash: calm adds nothing")

	Save.set_setting("calm", false)
	Features.FLAGS["merge_impact"] = false
	var fh3 := Control.new(); fh3.size = Vector2(200, 200); get_root().add_child(fh3)
	FX.flash(fh3, Vector2(100, 100), 64.0)
	ok(fh3.get_child_count() == 0, "flash: flag OFF adds nothing")
	Features.FLAGS["merge_impact"] = true
	fh.queue_free(); fh2.queue_free(); fh3.queue_free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
