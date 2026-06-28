extends SceneTree
## Headless tests for the merge-impact juice helpers in fx.gd (squash_pop / flash / shake /
## hitstop / gen_charge). An ACTIVE suite so the FX vocabulary is guarded in the normal `make test`
## loop. Each helper is checked on its active path and its flag-off / null-safe path.
##   godot --headless --path . -s res://engine/tests/fx_juice_tests.gd

const FX = preload("res://engine/scripts/ui/fx.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
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
	# --- squash_pop: squash & stretch (active path) ----------------------------------
	var sp := Control.new(); sp.size = Vector2(80, 80); get_root().add_child(sp)
	FX.squash_pop(sp)
	ok(sp.scale.is_equal_approx(Tune.SQUASH_K[0]), "squash_pop: active path sets the squash-start pose")
	ok(sp.pivot_offset.is_equal_approx(Vector2(40, 40)), "squash_pop: scales from the node centre")
	FX.squash_pop(null)
	ok(true, "squash_pop: tolerates a null node (no crash)")
	sp.queue_free()

	# --- flash: a brief white overlay (gated on merge_impact) ------------------------
	Features.FLAGS["merge_impact"] = true
	var fh := Control.new(); fh.size = Vector2(200, 200); get_root().add_child(fh)
	FX.flash(fh, Vector2(100, 100), 64.0)
	ok(fh.get_child_count() == 1, "flash: active path adds a white overlay child")

	Features.FLAGS["merge_impact"] = false
	var fh3 := Control.new(); fh3.size = Vector2(200, 200); get_root().add_child(fh3)
	FX.flash(fh3, Vector2(100, 100), 64.0)
	ok(fh3.get_child_count() == 0, "flash: flag OFF adds nothing")
	Features.FLAGS["merge_impact"] = true
	fh.queue_free(); fh3.queue_free()

	# --- shake: a decaying positional thunk (active path) ----------------------------
	var sk := Control.new(); sk.size = Vector2(60, 60); get_root().add_child(sk)
	FX.shake(sk)
	ok(is_instance_valid(sk), "shake: active path runs on a real in-tree node (no crash)")
	FX.shake(null)
	ok(true, "shake: tolerates a null node")
	sk.queue_free()

	# --- hitstop: wanted-gate is testable; the full gate + effect are off in headless --
	Features.FLAGS["merge_hitstop"] = true
	ok(FX.hitstop_wanted(), "hitstop: flag ON → wanted")
	Features.FLAGS["merge_hitstop"] = false
	ok(not FX.hitstop_wanted(), "hitstop: flag OFF → not wanted")
	Features.FLAGS["merge_hitstop"] = true
	ok(not FX.hitstop_enabled(), "hitstop: NEVER enabled in headless (protects the test clock)")
	var before := Engine.time_scale
	FX.hitstop(0.05)
	ok(Engine.time_scale == before, "hitstop: a call in headless does not touch Engine.time_scale")

	# --- gen_charge: anticipation pose (flag on) vs plain pop fallback (flag off) -----
	Features.FLAGS["gen_anticipation"] = true
	var gc := Control.new(); gc.size = Vector2(90, 90); get_root().add_child(gc)
	FX.gen_charge(gc)
	ok(gc.scale.is_equal_approx(Tune.GEN_CHARGE_K[0]), "gen_charge: active path sets the crouch pose")
	Features.FLAGS["gen_anticipation"] = false
	var gc2 := Control.new(); gc2.size = Vector2(90, 90); get_root().add_child(gc2)
	FX.gen_charge(gc2)
	ok(not gc2.scale.is_equal_approx(Tune.GEN_CHARGE_K[0]), "gen_charge: flag OFF falls back to plain pop (no crouch pose)")
	FX.gen_charge(null)
	ok(true, "gen_charge: tolerates a null node")
	Features.FLAGS["gen_anticipation"] = true
	gc.queue_free(); gc2.queue_free()

	# --- generator highlight: workbench-tuned halo + sparkle -----------------------
	Features.FLAGS["item_backing"] = true
	var gen := PieceView.make_generator("seed_satchel", 100.0, {
		"glow_scale": 1.35,
		"glow_a": 0.72,
		"glow_color": Color("#77CCFF"),
		"sparkle_color": Color("#FF66CC"),
		"sparkle_size": 1.8,
		"sparkle_count": 6,
		"sparkle_speed": 1.1,
		"outline_color": Color("#33EE88"),
		"outline_w": 0.05,
		"outline_blur": 0.04,
	})
	var tuned_glow := gen.find_child("GenGlow", true, false) as TextureRect
	ok(tuned_glow != null and tuned_glow.modulate.is_equal_approx(Color("#77CCFF", 0.72)) \
		and is_equal_approx(tuned_glow.size.x, 135.0), \
		"generator glow consumes the workbench-tuned color, alpha, and scale")
	var halo_falloff_ok := false
	if tuned_glow != null and tuned_glow.texture != null:
		var glow_img := tuned_glow.texture.get_image()
		var edge_px := Vector2i(int(round(float(glow_img.get_width() - 1) * 0.88)), glow_img.get_height() / 2)
		halo_falloff_ok = glow_img.get_pixelv(edge_px).a >= 0.16
	ok(halo_falloff_ok, "generator glow texture keeps enough outer alpha to read as a halo")
	var tuned_sparkle := gen.find_child("GenSparkle", true, false) as Control
	var sparkle_tint_ok := false
	var sparkle_size_ok := false
	if tuned_sparkle != null:
		var tint_v = tuned_sparkle.get("tint")
		var size_v = tuned_sparkle.get("size_mult")
		sparkle_tint_ok = tint_v is Color and (tint_v as Color).is_equal_approx(Color("#FF66CC"))
		sparkle_size_ok = (size_v is float or size_v is int) and is_equal_approx(float(size_v), 1.8)
	ok(tuned_sparkle != null and sparkle_tint_ok and sparkle_size_ok, \
		"generator sparkle consumes the workbench-tuned color and size")
	var tuned_outline := gen.find_child("GenOutline", true, false) as Control
	var outline_color_ok := false
	var outline_blur_ok := false
	if tuned_outline != null:
		var ocol_v = tuned_outline.get("color")
		var oblur_v = tuned_outline.get("blur")
		outline_color_ok = ocol_v is Color and (ocol_v as Color).is_equal_approx(Color("#33EE88"))
		# outline_blur is a fraction of the cell (0.04 × 100 px = 4 px of feather)
		outline_blur_ok = (oblur_v is float or oblur_v is int) and is_equal_approx(float(oblur_v), 4.0)
	ok(tuned_outline != null and outline_color_ok and outline_blur_ok, \
		"generator outline consumes the workbench-tuned color and blur")

	# --- squash_pop strength scales the impact pose (default 1.0 unchanged) -----------
	var sps := Control.new(); sps.size = Vector2(80, 80); get_root().add_child(sps)
	FX.squash_pop(sps, 1.0)
	ok(sps.scale.is_equal_approx(Tune.SQUASH_K[0]), "squash_pop: strength 1.0 keeps the default squash pose")
	var sph := Control.new(); sph.size = Vector2(80, 80); get_root().add_child(sph)
	FX.squash_pop(sph, 0.5)
	var half := Vector2.ONE + (Tune.SQUASH_K[0] - Vector2.ONE) * 0.5
	ok(sph.scale.is_equal_approx(half), "squash_pop: strength 0.5 halves the deviation from rest")
	sps.queue_free(); sph.queue_free()
	var sp0 := Control.new(); sp0.size = Vector2(80, 80); get_root().add_child(sp0)
	FX.squash_pop(sp0, 0.0)
	ok(sp0.scale.is_equal_approx(Vector2.ONE), "squash_pop: strength 0.0 leaves the node at rest")
	sp0.queue_free()

	# --- tick accepts a duration param; flag-off path snaps regardless --------------
	Features.FLAGS["wallet_tick"] = false
	var tl := Label.new(); tl.text = "0"; get_root().add_child(tl)
	FX.tick(tl, 1250, 0.2)
	ok(tl.text == "1250", "tick: flag off snaps to the value (custom dur accepted, no crash)")
	tl.queue_free()
	# tick flag ON builds the count tween with the custom dur (not snapped before any frame)
	Features.FLAGS["wallet_tick"] = true
	var tl2 := Label.new(); tl2.text = "0"; get_root().add_child(tl2)
	FX.tick(tl2, 1250, 0.2)
	ok(tl2.text == "0", "tick: flag on defers to the count tween (custom dur, no immediate snap)")
	tl2.queue_free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
