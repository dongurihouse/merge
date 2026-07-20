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

	# show_close: the ✕ disc is on by default and suppressed when a sheet opts out (the level screen).
	var closebody := VBoxContainer.new(); closebody.add_child(Label.new())
	var closedlg: Control = Kit.dialog_frame(closebody, 400.0, {"banner_text": "Z"})
	get_root().add_child(closedlg)
	for _i in 4:
		await process_frame
	ok(closedlg.find_child("DialogClose", true, false) != null, "dialog_frame docks the ✕ by default")
	closedlg.queue_free()
	var noclosebody := VBoxContainer.new(); noclosebody.add_child(Label.new())
	var noclosedlg: Control = Kit.dialog_frame(noclosebody, 400.0, {"banner_text": "Z", "show_close": false})
	get_root().add_child(noclosedlg)
	for _i in 4:
		await process_frame
	ok(noclosedlg.find_child("DialogClose", true, false) == null, "show_close = false drops the ✕ disc")
	noclosedlg.queue_free()

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

	# banner_burn wiring: the "Banner Burn" slider (banner_burn opt) must reach the DialogTitle carved
	# groove. burn == 0 is the flat baseline (no cream lip, no ink top-edge shadow); burn > 0 adds a
	# DialogTitleLip copy behind the ink + a dark top-edge shadow, both deepening with the slider. Guards
	# the consumer — the opt was once plumbed but silently ignored.
	var flat: Control = Kit.dialog_frame(VBoxContainer.new(), 400.0, {"banner_text": "Z", "banner_burn": 0.0})
	var mid: Control = Kit.dialog_frame(VBoxContainer.new(), 400.0, {"banner_text": "Z", "banner_burn": 0.5})
	var hot: Control = Kit.dialog_frame(VBoxContainer.new(), 400.0, {"banner_text": "Z", "banner_burn": 1.0})
	var tflat := flat.find_child("DialogTitle", true, false) as Label
	var thot := hot.find_child("DialogTitle", true, false) as Label
	var lipmid := mid.find_child("DialogTitleLip", true, false) as Label
	var liphot := hot.find_child("DialogTitleLip", true, false) as Label
	ok(tflat != null and not tflat.has_theme_color_override("font_shadow_color")
		and flat.find_child("DialogTitleLip", true, false) == null,
		"banner_burn 0 = flat title (no groove lip or top-edge shadow)")
	ok(thot != null and liphot != null and thot.get_theme_color("font_shadow_color").a > 0.0,
		"banner_burn 1 carves the groove (cream lip + ink top-edge shadow reach the header)")
	ok(lipmid != null and liphot != null and liphot.modulate.a > lipmid.modulate.a,
		"higher banner_burn deepens the groove (lip strengthens)")
	flat.queue_free(); mid.queue_free(); hot.queue_free()

	# long-title shrink: the title row's max width is the card minus the docked ✕ zone on BOTH sides,
	# so a long name auto-shrinks to fit instead of running under the disc ("WINTER BERRIES" bug).
	var tw := 400.0
	var close_size := 64.0
	var close_inset := 12.0
	var long_name := "Winter berries"
	var ldlg2: Control = Kit.dialog_frame(VBoxContainer.new(), tw, {"banner_text": long_name})
	var tlong := ldlg2.find_child("DialogTitle", true, false) as Label
	ok(tlong != null, "long-title dialog builds a DialogTitle")
	if tlong != null:
		var f: Font = tlong.get_theme_font("font")
		var fsz: int = tlong.get_theme_font_size("font_size")
		var room := tw - 2.0 * (close_inset + close_size + Kit.TITLE_CLOSE_GAP)
		var painted := f.get_string_size(long_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		ok(painted <= room + 0.5, "long title shrinks inside the ✕-bounded row (%.0f <= %.0f)" % [painted, room])
		var short_fsz: int = Kit.dialog_title_font("Mail", tw, close_inset + close_size + Kit.TITLE_CLOSE_GAP)
		ok(short_fsz == int(round(tw * Kit.DIALOG_TITLE_FONT_FRAC)), "short title keeps the full display size")
	ldlg2.queue_free()

	# the title band is centred ON THE CARD: `inner` is inset by the card's content pad while the band
	# spans the card width, so the band must sit at -pad — and the saved ribbon-era banner_x nudge is
	# ignored. Regression for the visibly off-centre "GLOW MUSHROOMS" title.
	var ndlg: Control = Kit.dialog_frame(VBoxContainer.new(), 400.0,
		{"banner_text": "N", "banner_pos": Vector2(-24, 0), "panel_pad_x": 40.0})
	get_root().add_child(ndlg)
	for _i in 4:
		await process_frame
	var ncard := ndlg.find_child("MeadowDialogPanel", true, false) as Control
	var nband := ndlg.find_child("DialogBanner", true, false) as Control
	var band_c := nband.global_position.x + nband.size.x / 2.0
	var card_c := ncard.global_position.x + ncard.size.x / 2.0
	ok(absf(band_c - card_c) < 0.5, "title band centre == card centre (%.1f vs %.1f)" % [band_c, card_c])
	ndlg.queue_free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
