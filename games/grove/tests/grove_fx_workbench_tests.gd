extends SceneTree
## Headless smoke tests for the Grove FX workbench.
##   godot --headless --path . -s res://games/grove/tests/grove_fx_workbench_tests.gd

const View = preload("res://games/grove/tools/fx_workbench_view.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")

const FX_IDS := ["coin_pickup", "board_refill", "stash_to_bag", "quest_payout", "accept_2x", "map_task_reward", "sale_payout"]

var _pass := 0
var _fail := 0
var _settings_path := ""

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _count_named(node: Node, name_fragment: String) -> int:
	var total := 0
	for c in node.get_children():
		if name_fragment in String(c.name):
			total += 1
		total += _count_named(c, name_fragment)
	return total

func _slider(node: Node, name_text: String) -> HSlider:
	return node.find_child(name_text, true, false) as HSlider

func fresh(name: String) -> void:
	var dir := "user://tu_grove_fx_workbench_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)
	_settings_path = dir + "ui_workbench_settings.json"
	FX.configure_reward_fx_config_for_test(_settings_path)

func _saved_fx_config() -> Dictionary:
	if not FileAccess.file_exists(_settings_path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_settings_path))
	if parsed is Dictionary and parsed.has("fx") and parsed["fx"] is Dictionary:
		return parsed["fx"]
	return {}

func _saved_fx_enabled(id: String, def := true) -> bool:
	var cfg := _saved_fx_config()
	var enabled = cfg.get("enabled", {})
	if enabled is Dictionary:
		return bool(enabled.get(id, def))
	return def

func _initialize() -> void:
	print("== Grove FX workbench tests ==")
	fresh("settings")
	var scene := load("res://games/grove/tools/FxWorkbench.tscn")
	ok(scene != null, "FX workbench scene loads")

	var view: Control = View.new()
	view.size = Vector2(1440, 920)
	root.add_child(view)
	await process_frame
	await process_frame

	ok(view.get("_preview_action") == "coin_pickup", "coin pickup is the default preview action")
	ok(view.find_child("CoinFlowPreview", true, false) != null, "workbench renders one compressed Coin Flow preview")
	ok(view.find_child("CoinFlowActionList", true, false) == null, "workbench no longer renders one list row per action")
	ok(view.find_child("FxSavedSettingsHeader", true, false) != null, "sidebar has a saved-settings section")
	ok(view.find_child("FxTestSettingsHeader", true, false) != null, "sidebar has a test-settings section")
	for id in FX_IDS:
		ok(view.find_child("FxActionToggle_%s" % id, true, false) != null, "%s has a saved on/off toggle" % id)
	ok(view.find_child("CoinFlowSource", true, false) != null, "preview renders one shared source")
	ok(view.find_child("CoinWalletTarget", true, false) != null, "preview renders a wallet target")

	for id in FX_IDS:
		view.call("_select_action", id)
		await process_frame
		view.call("_clear_runtime_fx")
		await process_frame
		view.call("_play_selected")
		await process_frame
		ok(_count_named(view, "RewardArrivalIcon") >= 1, "%s preview spawns a shared reward arrival icon" % id)
		ok(_count_named(view, "RewardArrivalFloater") >= 1, "%s preview spawns a shared reward floater" % id)
		await create_timer(0.8).timeout

	view.call("_select_action", "quest_payout")
	await process_frame
	view.call("_set_fx_enabled", "quest_payout", false)
	await process_frame
	Save.coins()
	ok(not _saved_fx_enabled("quest_payout"), "workbench toggle writes the FX flag into UI Workbench settings")
	ok(not (Save.data["settings"] as Dictionary).has("fx.quest_payout"), "workbench toggle does not write FX flags into the game save")
	view.call("_clear_runtime_fx")
	await process_frame
	view.call("_play_selected")
	await process_frame
	ok(_count_named(view, "RewardArrivalIcon") == 0, "disabled selected FX does not spawn reward-arrival icons")
	ok(view.find_child("FxDisabledBadge", true, false) != null, "disabled selected FX shows an off-state badge")

	var icon_slider := _slider(view, "IconSizeSlider")
	var trail_slider := _slider(view, "TrailCountSlider")
	var amount_slider := _slider(view, "AmountSlider")
	var source_slider := _slider(view, "CoinSizeSlider")
	var auto := view.find_child("AutoReplayToggle", true, false) as CheckButton
	ok(icon_slider != null and trail_slider != null, "saved controls expose feel sliders")
	ok(amount_slider != null and source_slider != null and auto != null, "test controls expose preview-only sliders and auto replay")

	amount_slider.value = 77
	icon_slider.value = 58
	trail_slider.value = 4
	source_slider.value = 126
	auto.set_pressed_no_signal(true)
	auto.toggled.emit(true)
	await process_frame

	var cfg := _saved_fx_config()
	ok(int(cfg.get("icon_size", 0)) == 58, "icon-size slider writes the saved UI Workbench FX icon size")
	ok(int(cfg.get("trail_count", 0)) == 4, "trail-count slider writes the saved UI Workbench FX trail count")
	ok(not cfg.has("amount"), "amount slider is test-only and not saved")
	ok(not cfg.has("source_size"), "source-size slider is test-only and not saved")
	ok(not cfg.has("auto_replay"), "auto replay is test-only and not saved")
	ok(not (Save.data["settings"] as Dictionary).has("fx.global.icon_size"), "icon-size slider does not write FX globals into the game save")
	ok(not (Save.data["settings"] as Dictionary).has("fx.global.trail_count"), "trail-count slider does not write FX globals into the game save")

	view.queue_free()
	await process_frame
	var restored: Control = View.new()
	restored.size = Vector2(1440, 920)
	root.add_child(restored)
	await process_frame
	await process_frame
	restored.call("_select_action", "quest_payout")
	await process_frame
	ok(not bool(restored.call("_is_fx_enabled", "quest_payout")), "new workbench instances read saved FX toggle state")
	ok(int(_slider(restored, "IconSizeSlider").value) == 58, "new workbench instances read saved icon size")
	ok(int(_slider(restored, "TrailCountSlider").value) == 4, "new workbench instances read saved trail count")
	ok(int(_slider(restored, "AmountSlider").value) != 77, "new workbench instances reset test-only amount")
	ok(int(_slider(restored, "CoinSizeSlider").value) != 126, "new workbench instances reset test-only source size")
	ok(not (restored.find_child("AutoReplayToggle", true, false) as CheckButton).button_pressed, "new workbench instances reset test-only auto replay")
	restored.queue_free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
