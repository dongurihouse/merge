extends SceneTree
const Kit := preload("res://games/grove/tools/ui_workbench_kit.gd")
func _initialize() -> void:
	var bg := ColorRect.new(); bg.color = Color(0.16, 0.15, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(bg)
	var opts := {
		"card_art": true, "card_slice_l": 40.0, "card_slice_t": 40.0, "card_slice_r": 40.0, "card_slice_b": 40.0,
		"card_h_stretch": 0, "card_v_stretch": 0,
		"banner_font": 32, "banner_h": 92.0, "banner_icon": 54.0, "banner_icon_on": true,
		"banner_text_x": 0.0, "banner_burn": true,
		"banner_pos": Vector2.ZERO, "banner_icon_pos": Vector2(130, 19),
		"close_size": 64.0, "close_poke": Vector2(12, 12),
		"entries_count": 8, "list_max_h": 380.0, "btn": {"bg": "green", "icon": "acorn", "enabled": true, "font": 22, "corner": 16, "art": true},
	}
	var d := Kit.mail_dialog(Kit.DEMO_MAIL, 560.0, opts)
	var center := CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center); center.add_child(d)
	await process_frame
	await create_timer(0.6).timeout
	var scroll := d.find_child("DialogScroll", true, false) as ScrollContainer
	if scroll == null:
		for n in d.find_children("*", "ScrollContainer", true, false):
			scroll = n; break
	if scroll: scroll.scroll_vertical = 120
	await create_timer(0.3).timeout
	var img := get_root().get_texture().get_image()
	img.save_png("/tmp/dlg.png")
	print("SHOT done scroll=%s size=%s" % [str(scroll != null), str(d.size)])
	quit()
