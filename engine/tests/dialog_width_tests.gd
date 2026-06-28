extends SceneTree
## Tests for the global dialog-width model: the single frame.width_pct, the per-dialog
## design baselines, the derived content scale, and dialog_frame wiring it through.
##   godot --headless --path . -s res://engine/tests/dialog_width_tests.gd

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")

var _pass := 0
var _fail := 0
func ok(c: bool, l: String) -> void:
	if c:
		_pass += 1
		print("  PASS  ", l)
	else:
		_fail += 1
		print("  FAIL  ", l)

func _find_scaler(n: Node) -> Node:
	if n is Container and ("scale_factor" in n):
		return n
	for c in n.get_children():
		var r := _find_scaler(c)
		if r != null:
			return r
	return null

func _initialize() -> void:
	print("== dialog width helpers ==")

	# default global width = 75 when no config present
	ok(is_equal_approx(Kit.frame_width_pct({}), 75.0), "default global width_pct = 75")
	# the frame block supplies the global; it is clamped to [30,100]
	ok(is_equal_approx(Kit.frame_width_pct({"frame": {"width_pct": 60}}), 60.0), "frame.width_pct read")
	ok(is_equal_approx(Kit.frame_width_pct({"frame": {"width_pct": 5}}), 30.0), "global width clamped to >= 30")

	# design baselines exist for every dialog id
	for id in ["dialog", "daily", "bag", "shop", "tiers", "vault", "settings", "level", "info"]:
		ok(Kit.DIALOG_DESIGN_PCT.has(id) and float(Kit.DIALOG_DESIGN_PCT[id]) > 0.0, "design_pct for %s" % id)

	# content scale = global / design
	ok(is_equal_approx(Kit.dialog_content_scale({"frame": {"width_pct": 75}}, "shop"), 75.0 / 85.0), "shop scale = 75/85")
	ok(is_equal_approx(Kit.dialog_content_scale({"frame": {"width_pct": 75}}, "dialog"), 1.0), "mail scale = 1.0 (design 75)")
	ok(is_equal_approx(Kit.dialog_content_scale({"frame": {"width_pct": 75}}, "settings"), 1.5), "settings scale = 75/50 = 1.5")

	# dialog_frame: chrome sized to design_width * content_scale (the real on-screen width),
	# while the content is wrapped in a ScaleContainer that scales it to fill.
	var body := VBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "hello"
	body.add_child(lbl)
	var design_w := 400.0
	var dlg: Control = Kit.dialog_frame(body, design_w, {"content_scale": 1.5, "banner_text": "X"})
	get_root().add_child(dlg)
	for _i in 6:
		await process_frame
	var card := dlg.get_child(0) as Control   # the PanelContainer
	ok(card != null and card.custom_minimum_size.x >= design_w * 1.5 - 1.0, "chrome width = design x content_scale (target)")
	var scaler := _find_scaler(dlg)
	ok(scaler != null, "content wrapped in a ScaleContainer")
	ok(scaler != null and is_equal_approx(float(scaler.scale_factor), 1.5), "scaler uses content_scale")
	dlg.queue_free()
	await process_frame

	# content_scale == 1.0 (default) is a pass-through: no ScaleContainer inserted.
	var body2 := VBoxContainer.new()
	body2.add_child(Label.new())
	var dlg2: Control = Kit.dialog_frame(body2, 400.0, {"banner_text": "Y"})
	get_root().add_child(dlg2)
	for _i in 4:
		await process_frame
	ok(_find_scaler(dlg2) == null, "identity content_scale inserts no ScaleContainer")
	dlg2.queue_free()

	# level_frame mirrors dialog_frame: crisp chrome at target, content scaled.
	var lbody := VBoxContainer.new()
	lbody.add_child(Label.new())
	var ldlg: Control = Kit.level_frame(lbody, 400.0, {"content_scale": 1.5})
	get_root().add_child(ldlg)
	for _i in 6:
		await process_frame
	var lcard := ldlg.get_child(0) as Control
	ok(lcard != null and lcard.custom_minimum_size.x >= 400.0 * 1.5 - 1.0, "level_frame chrome width = design x content_scale")
	var lscaler := _find_scaler(ldlg)
	ok(lscaler != null and is_equal_approx(float(lscaler.scale_factor), 1.5), "level_frame wraps content in a ScaleContainer")
	ldlg.queue_free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
