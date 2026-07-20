extends SceneTree
const U = preload("res://games/grove/tools/ui_workbench_view.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
func _initialize() -> void:
	UiFont.apply()
	var v: Control = U.new(); v.size = Vector2(1200, 1600); get_root().add_child(v)
	await process_frame; await process_frame
	v._params["level"]["med_size"] = 70
	v._params["level"]["earned_dy"] = 40
	v._params["level"]["bar_size"] = 130
	v._selected = "level"; v.set("_focus_only", "level"); v._build()
	await process_frame; await process_frame
	await create_timer(0.3).timeout
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png("/private/tmp/claude-501/-Users-xup-dh-merge/386ec5db-e272-4580-9fd4-b26ecc56e024/scratchpad/level_tweak.png")
	quit()
