extends SceneTree
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Game = preload("res://engine/scripts/core/game.gd")

func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_size(Vector2i(1700, 1280))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	UiFont.apply()
	var bg := ColorRect.new(); bg.color = Game.PALETTE.BG; bg.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(bg)
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)

	# 2x daily-card previews with ribbons (verify ribbon ON TOP of border) + info icon
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 26); row.position = Vector2(30, 30); root.add_child(row)
	for spec in [{"day":4,"label":"Day 4","reward":{"coins":150},"state":"today","ribbon":"Popular"},
				 {"icon":"gem","count":500,"price":"$4.99","ribbon":"Best value"}]:
		var co: Dictionary = Kit.daily_card_opts_from_config(cfg)
		var z := 2.0
		co["cell_w"]=float(co["cell_w"])*z; co["cell_h"]=float(co["cell_h"])*z
		co["cell_font"]=int(15*z); co["claim_font"]=int(15*z); co["count_font"]=int(17*z)
		co["label_y"]=float(co.get("label_y",12))*z; co["claim_y"]=float(co.get("claim_y",14))*z
		co["ribbon_scale"]=float(co.get("ribbon_scale",1.0))*z; co["ribbon_y"]=float(co.get("ribbon_y",-10))*z
		co["info_icon"]=true
		row.add_child(Kit.daily_card(spec, co))

	# shop dialog (centered-title dividers) + daily dialog (aspect ratio) side by side, at 85% of 1080
	var w := 1080.0 * 0.85
	var sopts: Dictionary = Kit.shop_opts_from_config(cfg); sopts["banner_text"]="Shop"
	var shop := Kit.shop_dialog(Kit.demo_shop(), w, sopts); shop.position = Vector2(30, 360); root.add_child(shop)
	var dopts: Dictionary = Kit.daily_opts_from_config(cfg); dopts["banner_text"]="Daily"
	var daily := Kit.daily_dialog(Kit.DEMO_DAILY, w, dopts); daily.position = Vector2(980, 360); root.add_child(daily)

	await process_frame; await process_frame
	await create_timer(0.7).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/Users/xup/dh/merge/.scratch/check.png")
	quit()
