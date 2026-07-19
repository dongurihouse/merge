extends SceneTree
## Headless smoke tests for the Grove FX workbench.
##   godot --headless --path . -s res://games/grove/tests/grove_fx_workbench_tests.gd

const View = preload("res://games/grove/tools/fx_workbench_view.gd")       # the reward-flight component
const Gallery = preload("res://games/grove/tools/fx_gallery_view.gd")      # the FX workbench itself
const UiView = preload("res://games/grove/tools/ui_workbench_view.gd")
const RushFx = preload("res://engine/scripts/ui/rush_fx.gd")
const LandFx = preload("res://engine/scripts/ui/land_fx.gd")
const MergeFx = preload("res://engine/scripts/ui/merge_fx.gd")
const LaunchFx = preload("res://engine/scripts/ui/launch_fx.gd")
const MoveFx = preload("res://engine/scripts/ui/move_fx.gd")
const GrabFx = preload("res://engine/scripts/ui/grab_fx.gd")
const ComboBloom = preload("res://engine/scripts/ui/combo_bloom.gd")
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

	_test_gallery()
	_test_rush_fx_knobs()
	_test_feel_fx()
	_test_shared_settings_merge()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


## The FX workbench gallery: every FX element is registered, builds, and its inspector builds.
func _test_gallery() -> void:
	var view: Control = Gallery.new()
	get_root().add_child(view)
	if view.get_child_count() == 0:
		view._ready()
	ok(_class_count(view, "AudioStreamPlayer") == 0, "Rush FX workbench preview does not spawn sound players")
	ok(view._sections.size() == Gallery.IDS.size(), "every FX element has a gallery section (%d)" % view._sections.size())
	for id in ["rush_fx", "land_fx", "merge_fx", "launch_fx", "move_fx", "grab_fx", "fx"]:
		ok(Gallery.IDS.has(id), "%s is registered in the FX workbench" % id)
	# the FX elements are GONE from the UI workbench (they live here now)
	for id in Gallery.IDS:
		ok(not UiView.IDS.has(id), "%s no longer rides in the UI workbench" % id)
	# the reward flight embeds the shared Coin Flow component, not the standalone mini-app chrome
	ok(view.find_child("FxWorkbenchComponent", true, false) != null, "the reward flight embeds the Coin Flow component")
	ok(view.find_child("FxWorkbenchRoot", true, false) == null, "the reward flight does not embed the standalone FX mini-app")
	ok(view.find_child("CoinFlowPreview", true, false) != null, "the reward flight renders the Coin Flow preview")
	ok(view.find_child("CoinFlowSource", true, false) != null, "the reward flight preview shows the shared source")
	ok(view.find_child("CoinWalletTarget", true, false) != null, "the reward flight preview shows the wallet target")
	# the reward-flight inspector
	view._selected = "fx"
	view._rebuild_sidebar()
	ok(view._sidebar_body.find_child("WorkbenchFxSavedSettingsHeader", true, false) != null, "the reward-flight sidebar has a saved-settings section")
	ok(view._sidebar_body.find_child("WorkbenchFxTestSettingsHeader", true, false) != null, "the reward-flight sidebar has a test-settings section")
	ok(view._sidebar_body.find_child("WorkbenchFxActionToggle_coin_pickup", true, false) != null, "the reward-flight sidebar keeps per-action on/off toggles")
	ok(view._sidebar_body.find_child("WorkbenchFxIconSizeSlider", true, false) != null, "the reward-flight sidebar shows saved feel sliders")
	ok(view._sidebar_body.find_child("WorkbenchFxAmountSlider", true, false) != null, "the reward-flight sidebar shows the preview-only amount slider")
	ok(view._sidebar_body.find_child("WorkbenchFxReplayButton", true, false) != null, "the reward-flight sidebar shows replay in the test section")
	var fx_preview := view.find_child("FxWorkbenchComponent", true, false) as Control
	if fx_preview != null:
		fx_preview.get_parent().remove_child(fx_preview)
		fx_preview.queue_free()
	view._fx_set_global_setting("amount", 91)
	view._fx_set_global_setting("coin_size", 133)
	view._fx_set_auto_replay(true)
	var fallback := _saved_fx_config()
	ok(not fallback.has("amount"), "reward-flight amount stays test-only when the embedded preview is absent")
	ok(not fallback.has("source_size"), "reward-flight source size stays test-only when the embedded preview is absent")
	ok(not fallback.has("auto_replay"), "reward-flight auto replay stays test-only when the embedded preview is absent")
	view.queue_free()

## A save from ONE workbench must not drop the OTHER workbench's ids — both persist into the same file.
## Redirected at a scratch COPY of the live config, so the test never rewrites the repo's design file.
func _test_shared_settings_merge() -> void:
	var scratch := "user://tu_grove_fx_workbench_settings/merge_settings.json"
	var live := FileAccess.get_file_as_string(Gallery.SETTINGS)
	var f := FileAccess.open(scratch, FileAccess.WRITE)
	f.store_string(live)
	f.close()

	var view: Control = Gallery.new()
	view._settings_path = scratch
	get_root().add_child(view)
	if view.get_child_count() == 0:
		view._ready()
	var before = JSON.parse_string(live)
	var ui_ids := []
	for id in UiView.IDS:
		if before is Dictionary and before.has(id):
			ui_ids.append(id)
	ok(ui_ids.size() > 0, "the live settings file carries UI-workbench ids to preserve (%d)" % ui_ids.size())
	view._save_settings()
	var after = JSON.parse_string(FileAccess.get_file_as_string(scratch))
	var kept := true
	var same := true
	for id in ui_ids:
		if not (after is Dictionary and after.has(id)):
			kept = false
		elif JSON.stringify(after[id]) != JSON.stringify(before[id]):
			same = false
	ok(kept, "an FX-workbench save keeps every UI-workbench id in the shared settings file")
	ok(same, "an FX-workbench save leaves the UI-workbench blocks byte-identical")
	ok(after is Dictionary and after.has("land_fx"), "an FX-workbench save writes its own ids")
	ok(FileAccess.get_file_as_string(Gallery.SETTINGS) == live, "the test never rewrites the repo's live settings file")
	view.queue_free()

func _class_count(node: Node, klass: String) -> int:
	var total := 0
	for c in node.get_children():
		if c.get_class() == klass:
			total += 1
		total += _class_count(c, klass)
	return total

func _test_rush_fx_knobs() -> void:
	var view: Control = Gallery.new()
	get_root().add_child(view)
	if view.get_child_count() == 0:
		view._ready()
	# params carry every rush_fx knob, defaulted from RushFx.KNOBS
	var p: Dictionary = view._params["rush_fx"]
	for k in RushFx.KNOBS.keys():
		ok(p.has(k) and int(p[k]) == int(RushFx.KNOBS[k]), "rush_fx params include knob %s at its default" % k)
	# selecting rush_fx builds a ▶ Replay per effect + the knob sliders
	view._selected = "rush_fx"
	view._rebuild_sidebar()
	var replays: Array = view._sidebar_body.find_children("RushFxReplay_*", "Button", true, false)
	ok(replays.size() == RushFx.EFFECTS.size(), "one ▶ Replay button per effect (%d)" % RushFx.EFFECTS.size())
	var sliders: Array = view._sidebar_body.find_children("*", "HSlider", true, false)
	ok(sliders.size() == RushFx.KNOBS.size(), "one knob slider per knob (%d)" % RushFx.KNOBS.size())
	# firing one effect does not error and does not require the toggle on
	view._params["rush_fx"]["merge_burst"] = false
	view._rush_fx_play("merge_burst")
	ok(true, "per-effect replay fires without error even when the effect toggle is off")
	view.queue_free()

## The FIVE feel-verb gallery components (land/merge/launch/move): params carry the registry defaults,
## the preview stage builds + stores its ctx, the sidebar builds, and the play function fires clean.
func _test_feel_fx() -> void:
	var view: Control = Gallery.new()
	get_root().add_child(view)
	if view.get_child_count() == 0:
		view._ready()
	var registries := {"land_fx": LandFx, "merge_fx": MergeFx, "launch_fx": LaunchFx, "move_fx": MoveFx, "grab_fx": GrabFx}
	for id in ["land_fx", "merge_fx", "launch_fx", "move_fx", "grab_fx"]:
		var reg = registries[id]
		var p: Dictionary = view._params[id]
		# every registry key (enabled + effect toggles + knobs) is present so from_config reads it back
		for k in reg.defaults().keys():
			ok(p.has(k), "%s params include the registry key %s" % [id, k])
		if id == "merge_fx":
			ok(p.has("merge_slide_ms") and int(p["merge_slide_ms"]) == int(MergeFx.KNOBS.get("merge_slide_ms", -1)), \
				"merge_fx params include the saved merge-slide duration")
		# the preview stage builds and stores its ctx (so the play function has its node refs)
		var prev: Control = view._make_element(id)
		ok(prev != null, "%s preview stage builds" % id)
		var ctx: Dictionary = view.get("_%s_ctx" % id)
		ok(not ctx.is_empty(), "%s preview stores its stage ctx" % id)
		if id == "merge_fx":
			ok(ctx.get("bloom") is ComboBloom, "merge_fx preview stores the shared ComboBloom node")
			ok(ctx.get("bloom") != null and ctx["bloom"].get_parent() == ctx.get("field"), \
				"merge_fx preview mounts ComboBloom inside the preview field")
		# the sidebar builds with a master toggle + per-effect On toggles (+ a ▶ trigger button)
		view._selected = id
		view._rebuild_sidebar()
		var toggles: Array = view._sidebar_body.find_children("*", "CheckButton", true, false)
		ok(toggles.size() >= reg.EFFECTS.size() + 1, "%s sidebar has master + per-effect toggles" % id)
	# merge_fx carries the preview-only tier/combo; move_fx carries the preview-only kind — not saved
	ok(view._params["merge_fx"].has("tier") and view._params["merge_fx"].has("combo"), "merge_fx carries tier/combo")
	ok(not view._is_config("merge_fx", "tier") and not view._is_config("merge_fx", "combo"), "merge_fx tier/combo excluded from save")
	ok(view._params["move_fx"].has("kind") and not view._is_config("move_fx", "kind"), "move_fx kind is preview-only")
	var view_src := FileAccess.get_file_as_string("res://games/grove/tools/fx_gallery_view.gd")
	var board_src := FileAccess.get_file_as_string("res://engine/scripts/scenes/board.gd")
	ok(view_src.find("_slider_row([\"merge_slide_ms\"") != -1, "merge_fx sidebar exposes a saved merge-slide duration slider")
	ok(view_src.find("MoveFx.apply(a, a.position, merge_top, \"slide\", _params[\"move_fx\"], MergeFx.knob(p, \"merge_slide_ms\"))") != -1, \
		"merge_fx preview uses the same MoveFx slide override as the board")
	ok(view_src.find("_merge_fx_pulse_bloom") == -1, "merge_fx preview no longer uses a separate local bloom pulse")
	ok(board_src.find("MergeFx.knob(_merge_opts, \"merge_slide_ms\")") != -1, \
		"board merge slide duration reads the saved merge_fx knob")
	ok(board_src.find("MERGE_SLIDE_MS") == -1, "board no longer has a hard-coded merge slide duration constant")
	# the saved block's keys are EXACTLY the registry's from_config keys (the game's read path), so the
	# saved out[id] round-trips. Every saved key is a registry default; tier/combo/kind are the only excludes.
	for id in ["land_fx", "merge_fx", "launch_fx", "move_fx", "grab_fx"]:
		var reg2 = registries[id]
		for k in view._params[id].keys():
			if view._is_config(id, k):
				ok(reg2.defaults().has(k), "%s saved key %s is a registry default (from_config reads it)" % [id, k])
	# the GRAB panel + the LAND ripple knob are registered like the others
	ok(Gallery.IDS.has("grab_fx") and view._sections.has("grab_fx"), "grab_fx is a registered workbench panel")
	ok(view_src.find("\"ripple\": [[\"ripple_pct\"") != -1, "the Land panel exposes a saved ripple_pct slider")
	ok(view_src.find("_feel_fx_sidebar(GrabFx.EFFECTS, GRAB_FX_KNOBS)") != -1, "the Grab panel auto-builds its toggles + knobs from the registry")
	# board wiring: grab highlight on pickup + clear on drop, and the plain drop routes through LandFx
	ok(board_src.find("_grab_opts = GrabFx.from_config(") != -1, "board resolves the grab_fx config once")
	ok(board_src.find("GrabFx.grab(") != -1, "board fires the grab highlight on pickup")
	ok(board_src.find("GrabFx.release(") != -1, "board clears the grab highlight on drop")
	ok(board_src.find("LandFx.apply.bind(board_area, node, land_ctr, _land_opts, 1.0, false, _orthogonal_neighbour_nodes(b))") != -1, \
		"board's plain drop (_commit_move) routes through LandFx.apply with the cell's neighbours (squash + ripple)")
	# firing each play function does not error (reads the live _params; no rebuild needed)
	view._land_fx_play()
	view._merge_fx_play()
	view._launch_fx_play()
	view._move_fx_play()
	view._grab_fx_play()
	ok(true, "all five feel-verb play functions fire without error")
	view.queue_free()
