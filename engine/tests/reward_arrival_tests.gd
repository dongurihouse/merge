extends SceneTree
## Headless tests for the shared reward-arrival FX spine.
##   godot --headless --path . -s res://engine/tests/reward_arrival_tests.gd

const FX = preload("res://engine/scripts/ui/fx.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Save = preload("res://engine/scripts/core/save.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func fresh(name: String) -> void:
	var dir := "user://tu_reward_arrival_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func _count_named(node: Node, name_fragment: String) -> int:
	var total := 0
	for c in node.get_children():
		if name_fragment in String(c.name):
			total += 1
		total += _count_named(c, name_fragment)
	return total

func _initialize() -> void:
	print("== Reward arrival FX tests ==")
	fresh("basic")
	Features.FLAGS["floaters"] = true
	Features.FLAGS["celebrate_bursts"] = true
	Features.FLAGS["fly_to_wallet"] = true

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	await process_frame

	var wallet := PanelContainer.new()
	wallet.name = "WalletTarget"
	wallet.position = Vector2(320, 64)
	wallet.size = Vector2(110, 52)
	host.add_child(wallet)

	var arrived := {"called": false}
	var spawned: Array = FX.reward_arrival(host, Vector2(80, 220), "coin", 7, Color("#E3B23C"), wallet, func() -> void:
		arrived.called = true)

	ok(spawned.size() >= 4, "reward_arrival returns the floater, main icon, and trail icons")
	ok(_count_named(host, "RewardArrivalFloater") == 1, "reward_arrival creates one named reward floater")
	ok(_count_named(host, "RewardArrivalIcon") == 1, "reward_arrival creates one named travel icon")
	ok(_count_named(host, "RewardArrivalTrail") >= 2, "reward_arrival creates delayed trail icons")

	await create_timer(0.75).timeout
	ok(bool(arrived.called), "reward_arrival calls the arrival callback after the icon reaches the wallet")
	ok(_count_named(host, "RewardArrivalIcon") == 0, "reward_arrival cleans up the main travel icon")

	host.queue_free()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
