extends "res://engine/tests/test_base.gd"
## Headless coverage for piece fly-away primitives: callbacks fire exactly once even when
## animation is skipped, pieces leave clipped parents without jumping, and sweep staggering
## stays capped for large batches.
##   godot --headless --path . -s res://engine/tests/fx_flight_tests.gd

const FX = preload("res://engine/scripts/ui/fx.gd")
const Features = preload("res://engine/scripts/core/features.gd")

func _initialize() -> void:
	print("== FX flight tests ==")
	var old_fly := bool(Features.FLAGS.get("fly_to_wallet", true))
	FX.configure_reward_fx_config_for_test("user://tu_fx_flight_cfg.json")
	Features.FLAGS["fly_to_wallet"] = true
	await _test_fly_pieces_away_callbacks_with_animation()
	await _test_fly_pieces_away_callbacks_when_fx_id_disabled()
	await _test_fly_pieces_away_callbacks_when_flight_feature_off()
	await _test_fly_pieces_away_callbacks_when_host_is_gone()
	await _test_fly_piece_to_reparents_without_jumping()
	_test_sweep_stagger_uses_cap_for_large_batches()
	await _test_keepsake_fade_frees_and_calls_once()
	Features.FLAGS["fly_to_wallet"] = old_fly
	FX.configure_reward_fx_config_for_test("")
	finish()

func _host(name: String) -> Control:
	var h := Control.new()
	h.name = name
	h.position = Vector2(20, 30)
	h.size = Vector2(640, 960)
	get_root().add_child(h)
	return h

func _target(parent: Control) -> Control:
	var t := Control.new()
	t.name = "WalletTarget"
	t.position = Vector2(420, 80)
	t.size = Vector2(90, 50)
	parent.add_child(t)
	return t

func _piece(parent: Control, idx: int = 0) -> Control:
	var n := ColorRect.new()
	n.name = "FlightPiece%d" % idx
	n.position = Vector2(40 + idx * 8, 160 + idx * 5)
	n.size = Vector2(48, 48)
	n.color = Color(1, 0.8, 0.2, 1)
	parent.add_child(n)
	return n

func _flight_opts() -> Dictionary:
	return {
		"t_up": 0.01,
		"t_down": 0.01,
		"arc": Vector2(0, -12),
		"scale": Vector2(0.5, 0.5),
	}

func _run_batch(host: Control, count: int, opts: Dictionary = {}) -> Dictionary:
	var target := _target(host) if host != null and is_instance_valid(host) else null
	var flights: Array = []
	for i in count:
		var node := _piece(host, i) if host != null and is_instance_valid(host) else Control.new()
		flights.append({"node": node, "payout": i + 1})
	var each: Array = []
	var all_done := [0]
	FX.fly_pieces_away(host, flights, target, opts, func(payout: int) -> void:
		each.append(payout), func() -> void:
		all_done[0] = int(all_done[0]) + 1)
	await create_timer(0.35).timeout
	return {"each": each, "all_done": int(all_done[0]), "flights": flights}

func _test_fly_pieces_away_callbacks_with_animation() -> void:
	var h := _host("FlightBatchHost")
	var out := await _run_batch(h, 3, _flight_opts())
	ok(out.each == [1, 2, 3], "fly_pieces_away calls then_each once per animated landing")
	ok(int(out.all_done) == 1, "fly_pieces_away calls all_done once after animated batch")
	await drop(h)

func _test_fly_pieces_away_callbacks_when_fx_id_disabled() -> void:
	FX.set_reward_fx_enabled("farewell_sweep", false)
	var h := _host("FlightDisabledHost")
	var opts := _flight_opts()
	opts["fx_id"] = "farewell_sweep"
	var out := await _run_batch(h, 3, opts)
	ok(out.each == [1, 2, 3], "disabled farewell_sweep still pays every flight once")
	ok(int(out.all_done) == 1, "disabled farewell_sweep still calls all_done once")
	FX.set_reward_fx_enabled("farewell_sweep", true)
	await drop(h)

func _test_fly_pieces_away_callbacks_when_flight_feature_off() -> void:
	var old_fly := bool(Features.FLAGS.get("fly_to_wallet", true))
	Features.FLAGS["fly_to_wallet"] = false
	var h := _host("FeatureOffHost")
	var out := await _run_batch(h, 3, _flight_opts())
	ok(out.each == [1, 2, 3], "fly_to_wallet off still pays every flight once")
	ok(int(out.all_done) == 1, "fly_to_wallet off still calls all_done once")
	Features.FLAGS["fly_to_wallet"] = old_fly
	await drop(h)

func _test_fly_pieces_away_callbacks_when_host_is_gone() -> void:
	var h := _host("GoneHost")
	var flights: Array = []
	for i in 2:
		flights.append({"node": _piece(h, i), "payout": i + 4})
	h.queue_free()
	await process_frame
	var each: Array = []
	var all_done := [0]
	FX.fly_pieces_away(h, flights, null, _flight_opts(), func(payout: int) -> void:
		each.append(payout), func() -> void:
		all_done[0] = int(all_done[0]) + 1)
	await process_frame
	ok(each == [4, 5], "freed host still pays every flight once")
	ok(int(all_done[0]) == 1, "freed host still calls all_done once")

func _test_fly_piece_to_reparents_without_jumping() -> void:
	var h := _host("ReparentHost")
	var clipped := Control.new()
	clipped.name = "ClippedBoardArea"
	clipped.position = Vector2(90, 140)
	clipped.size = Vector2(120, 120)
	h.add_child(clipped)
	var node := _piece(clipped, 7)
	var before := node.global_position
	var target := _target(h)
	FX.fly_piece_to(h, node, target, _flight_opts(), Callable())
	ok(node.get_parent() == h, "fly_piece_to reparents the piece to the unclipped host")
	ok(node.global_position.is_equal_approx(before), "fly_piece_to preserves global position on reparent")
	await create_timer(0.1).timeout
	await drop(h)

func _test_sweep_stagger_uses_cap_for_large_batches() -> void:
	var spacing := float(FX.sweep_launch_spacing(24))
	ok(is_equal_approx(spacing, 0.90 / 24.0),
		"sweep launch spacing uses the cap once a large batch would exceed it")

func _test_keepsake_fade_frees_and_calls_once() -> void:
	var h := _host("KeepsakeHost")
	var node := _piece(h, 9)
	var called := [0]
	FX.keepsake_fade(node, func() -> void:
		called[0] = int(called[0]) + 1)
	await create_timer(0.65).timeout
	ok(int(called[0]) == 1, "keepsake_fade calls then once")
	ok(not is_instance_valid(node), "keepsake_fade frees the generator node")
	await drop(h)
