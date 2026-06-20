extends SceneTree
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Game = preload("res://engine/scripts/core/game.gd")

func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_size(Vector2i(1000, 1280))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	UiFont.apply()
	var bg := ColorRect.new(); bg.color = Game.PALETTE.BG; bg.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(bg)
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var w := 1080.0 * 0.85
	var sopts: Dictionary = Kit.shop_opts_from_config(cfg); sopts["banner_text"]="Shop"
	var shop := Kit.shop_dialog(Kit.demo_shop(), w, sopts); shop.position = Vector2(30, 20); root.add_child(shop)
	await process_frame; await process_frame
	await create_timer(0.7).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/Users/xup/dh/merge/.scratch/shopnow.png")
	quit()
