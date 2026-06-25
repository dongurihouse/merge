extends SceneTree
## Headless smoke tests for the Grove FX workbench.
##   godot --headless --path . -s res://games/grove/tests/grove_fx_workbench_tests.gd

const View = preload("res://games/grove/tools/fx_workbench_view.gd")
const Save = preload("res://engine/scripts/core/save.gd")

const FX_IDS := ["coin_pickup", "board_refill", "stash_to_bag", "quest_payout", "accept_2x", "map_task_reward", "sale_payout"]
const FX_LABELS := ["Coin pickup", "Board refill", "Stash to bag", "Quest payout", "2x reward accept", "Map task reward", "Sale payout"]

var _pass := 0
var _fail := 0

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

func _has_button_text(node: Node, text: String) -> bool:
	if node is Button and String((node as Button).text) == text:
		return true
	for b in node.find_children("*", "Button", true, false):
		if String((b as Button).text) == text:
			return true
	return false

func _is_list_button_disabled(node: Node, text: String) -> bool:
	for b in node.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn != null and String(btn.text) == text:
			return btn.disabled
	return true

func fresh(name: String) -> void:
	var dir := "user://tu_grove_fx_workbench_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

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

	ok(view.get("_selected_fx") == "coin_pickup", "coin pickup is selected by default")
	for i in FX_LABELS.size():
		ok(_has_button_text(view, FX_LABELS[i]), "sidebar exposes %s as a list item" % FX_LABELS[i])
		ok(not _is_list_button_disabled(view, FX_LABELS[i]), "%s is selectable from the list" % FX_LABELS[i])
		ok(view.find_child("FxToggle_%s" % FX_IDS[i], true, false) != null, "%s has an on/off toggle" % FX_LABELS[i])
	ok(_has_button_text(view, "Replay"), "sidebar exposes a replay command")
	ok(view.find_child("CoinPickupPiece", true, false) != null, "board preview renders a clickable coin")
	ok(view.find_child("CoinWalletTarget", true, false) != null, "board preview renders a wallet target")

	for id in FX_IDS:
		view.call("_select_fx", id)
		await process_frame
		view.call("_clear_runtime_fx")
		await process_frame
		view.call("_play_selected")
		await process_frame
		ok(_count_named(view, "RewardArrivalIcon") >= 1, "%s preview spawns a shared reward arrival icon" % id)
		ok(_count_named(view, "RewardArrivalFloater") >= 1, "%s preview spawns a shared reward floater" % id)
		await create_timer(0.8).timeout

	view.call("_select_fx", "quest_payout")
	await process_frame
	view.call("_set_fx_enabled", "quest_payout", false)
	await process_frame
	ok(not Save.get_setting("fx.quest_payout", true), "workbench toggle writes the saved FX setting")
	view.call("_clear_runtime_fx")
	await process_frame
	view.call("_play_selected")
	await process_frame
	ok(_count_named(view, "RewardArrivalIcon") == 0, "disabled selected FX does not spawn reward-arrival icons")
	ok(view.find_child("FxDisabledBadge", true, false) != null, "disabled selected FX shows an off-state badge")

	view.queue_free()
	await process_frame
	var restored: Control = View.new()
	restored.size = Vector2(1440, 920)
	root.add_child(restored)
	await process_frame
	await process_frame
	restored.call("_select_fx", "quest_payout")
	await process_frame
	ok(not bool(restored.call("_is_fx_enabled", "quest_payout")), "new workbench instances read saved FX toggle state")
	restored.queue_free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
