extends SceneTree
const Kit := preload("res://games/grove/tools/ui_workbench_kit.gd")
const View := preload("res://games/grove/tools/ui_workbench_view.gd")

func _initialize() -> void:
	var bg := ColorRect.new(); bg.color = Color(0.16, 0.15, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(bg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	col.position = Vector2(40, 30)
	root.add_child(col)

	# (4) three buttons, same text + icon_size, different icons → widths must be EQUAL (constant box)
	var brow := HBoxContainer.new(); brow.add_theme_constant_override("separation", 18)
	col.add_child(brow)
	var bs := []
	for ic in ["gem", "water", "leaf"]:
		var b := Kit.pill_button("Claim", {"bg": "green", "art": true, "font": 22, "icon": ic, "icon_size": 28})
		brow.add_child(b); bs.append(b)

	# (1) banner dragged UP (banner_y=-40) with 0 top pad → row 1 should sit just under the banner.
	# (3) cards show the disc-badge plated icon.  (2) narrow-ish width with long content → no overflow.
	var opts := {
		"card_art": true, "card_slice_l": 48.0, "card_slice_t": 48.0, "card_slice_r": 48.0, "card_slice_b": 48.0,
		"card_title": 20, "card_body": 15,
		"banner_font": 32, "banner_h": 92.0, "banner_icon": 54.0, "banner_icon_on": true,
		"banner_burn": 0.7, "banner_pos": Vector2(0, -40), "banner_icon_pos": Vector2(130, 19),
		"close_size": 64.0, "close_poke": Vector2(12, 12),
		"entries_count": 5, "list_max_h": 360.0, "list_top_pad": 0.0,
		"btn": {"bg": "green", "icon": "", "art": true, "font": 22},
	}
	var d := Kit.mail_dialog(Kit.DEMO_MAIL, 700.0, opts)   # the user's real width
	col.add_child(d)

	await process_frame
	await create_timer(0.5).timeout
	var ws := []
	for b in bs: ws.append(b.size.x)
	print("BUTTON WIDTHS (want equal) = %s" % str(ws))
	print("CARD0 width=%s dlg=%s" % [str(d.find_children("*", "PanelContainer", true, false).size()), str(d.size)])
	var img := get_root().get_texture().get_image()
	img.save_png("/tmp/dlg.png")
	print("SHOT done view=%s" % str(View != null))
	quit()
