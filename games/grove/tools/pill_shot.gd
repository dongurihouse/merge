extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): preview the sprite-based CurrencyPillSprite
## against the map sky, at a few counts, so the new pill can be eyeballed next to the concept.
##   quiet_godot.sh --path . -s res://games/grove/tools/pill_shot.gd -- /tmp/pill.png

const Pill = preload("res://engine/scripts/ui/currency_pill_sprite.gd")

const CUT := "res://games/grove/assets/_concepts/screens/cutpaper_storybook_ui_v1/ui_sprite_extraction_v1/cut/"
const ROWS := [
	{"tex": "pill_water_v1.png", "count": 100},
	{"tex": "pill_coin_v1.png", "count": 9821},
	{"tex": "pill_acorn_v1.png", "count": 1870},
]

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() >= 1 else "/tmp/pill.png"

	await create_timer(0.2).timeout
	DisplayServer.window_set_size(Vector2i(760, 460))
	await create_timer(0.2).timeout

	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(canvas)
	var bg := ColorRect.new()
	bg.color = Color("#6FA9C0")   # map sky, matches the mock backdrop
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	col.position = Vector2(40, 40)
	canvas.add_child(col)
	for r in ROWS:
		var tex := load(CUT + String(r["tex"])) as Texture2D
		var pill := Pill.build({"tex": tex, "count": int(r["count"]), "height": 96.0})
		col.add_child(pill)

	await create_timer(0.4).timeout
	# minimized windows serve a STALE/blank frame — force a fresh draw before reading the texture
	RenderingServer.force_draw()
	var img := get_root().get_texture().get_image()
	img.save_png(out)
	print("wrote ", out, " ", img.get_size())
	quit(0)
