extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): review one resident line's 12 tiers of art exactly
## as they render in-game (ambient.gd applies no per-tier scale/tint — the art carries the tier read).
## Draws the tiers as a 6×2 grid into an offscreen SubViewport, so it never touches the live Map scene.
##   make shot TOOL=games/grove/tools/resident_tier_shot ARGS="ember /tmp/resident_ember.png"
## args: [line_id=ember] [out_png=/tmp/resident_<line>.png]

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via engine/tools/quiet_godot.sh (born-minimized window). See ~/.claude/CLAUDE.md")
		quit(2); return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var line_id: String = String(args[0]) if args.size() >= 1 else "ember"
	var out_png: String = String(args[1]) if args.size() >= 2 else "/tmp/resident_%s.png" % line_id

	const COLS := 6
	const ROWS := 2
	const CELL := 200.0
	const SPR := 168.0
	const MARGIN := 40.0
	var w := MARGIN * 2.0 + COLS * CELL
	var h := 70.0 + ROWS * CELL

	var canvas := Control.new()
	canvas.size = Vector2(w, h)
	var bg := ColorRect.new(); bg.color = Color("#F4EFE6"); bg.size = Vector2(w, h); canvas.add_child(bg)
	canvas.add_child(_label("Resident line: %s — tiers 1 → 12 (in-game render, no scale/tint)" % line_id,
		Vector2(MARGIN, 14), 22, Color("#33312c")))

	for t in range(1, 13):
		var idx := t - 1
		var col := idx % COLS
		var rowi := idx / COLS
		var x := MARGIN + col * CELL + (CELL - SPR) / 2.0
		var y := 56.0 + rowi * CELL + (CELL - SPR) / 2.0
		var p := "res://games/grove/assets/items/resident_%s/resident_%s_%d.png" % [line_id, line_id, t]
		var tex: Texture2D = load(p) if ResourceLoader.exists(p) else null
		var spr := _sprite(tex, SPR); spr.position = Vector2(x, y); canvas.add_child(spr)
		canvas.add_child(_label("t%d" % t, Vector2(MARGIN + col * CELL + 6.0, 56.0 + rowi * CELL + 4.0), 14, Color("#8a8a8a")))

	var sv := SubViewport.new()
	sv.size = Vector2i(int(w), int(h))
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	sv.add_child(canvas)
	await create_timer(0.5).timeout
	RenderingServer.force_draw()
	await create_timer(0.1).timeout
	var img := sv.get_texture().get_image()
	var err := img.save_png(out_png)
	print("SHOT %s (err %d) %dx%d" % [out_png, err, int(w), int(h)])
	quit()

func _label(t: String, pos: Vector2, sz: int, col: Color) -> Label:
	var l := Label.new(); l.text = t; l.position = pos
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l

func _sprite(tex: Texture2D, sz: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.size = Vector2(sz, sz)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if tex != null: tr.texture = tex
	return tr
