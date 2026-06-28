extends SceneTree
## Dev tool (real renderer; via engine/tools/quiet_godot.sh): render board WIDGETS in ISOLATION on the
## board's cream field — no board, no wells, no layout settling — so a UI change's ACTUAL pixels are
## unambiguous. Far cheaper + more reliable than capturing the live board (which fights you with crop
## math, stale wells, and layout timing). Use it to SEE a change before calling it done.
##
##   make shot-widget OUT=/tmp/w.png TILES="104 104:glow"
##   make shot TOOL=games/grove/tools/widget_shot ARGS="/tmp/w.png 104 104:glow 6104 6104:glow"
##
## Each TILE is `CODE[:MOD]`, rendered in a labelled row (CODE = line*100 + tier):
##   104          a plain board item
##   104:glow     the item wearing the quest-ready glow (PieceView.add_ready_glow)
##   104:lift     the item in its picked-up (lifted) pose (PieceView.set_lifted)
## Pass a plain CODE and its `:MOD` side by side for a built-in before/after. Items only today; extend
## the `match mod` below for new widgets as the need arises (grow tools incrementally).
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus). See ~/.claude/CLAUDE.md")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() >= 1 else "/tmp/widget.png"
	var tiles: Array = args.slice(1)
	if tiles.is_empty():
		tiles = ["104", "104:glow"]                       # default: plain vs quest-ready (a before/after)

	var n := tiles.size()
	# size tiles to FIT the ~1080-wide framebuffer: total = (0.5 + 1.4n)*s ≤ 1040 (cap at 200 so a 1–2
	# tile shot isn't huge). Keeps every tile fully on-screen no matter how many are requested.
	var s := minf(200.0, 1040.0 / (0.5 + 1.4 * float(n)))
	var pad := s * 0.45
	var gap := s * 0.4
	var label_h := s * 0.3
	var content := Vector2(pad * 2.0 + n * s + maxf(0.0, n - 1) * gap, pad * 2.0 + s + label_h)
	var bg := ColorRect.new()
	bg.color = Color("#ECDFC2")                           # the board's cream field
	bg.size = Vector2(4000, 4000)                         # cover the whole window so the crop is never dark
	root.add_child(bg)

	for i in n:
		var spec := String(tiles[i])
		var parts := spec.split(":")
		var code := int(parts[0])
		var mod := String(parts[1]) if parts.size() > 1 else ""
		var x := pad + i * (s + gap)
		var piece := PieceView.make_piece(code, s)
		piece.position = Vector2(x, pad)
		bg.add_child(piece)
		match mod:
			"glow":
				var g := PieceView.add_ready_glow(piece, s)
				if g != null:
					FX.breathe(g)
			"lift":
				PieceView.set_lifted(piece, true)
			"":
				pass
			_:
				print("widget_shot: unknown modifier '%s' (use glow|lift)" % mod)
		var lbl := Label.new()
		lbl.text = spec
		lbl.position = Vector2(x, pad + s + s * 0.04)
		lbl.size = Vector2(s, label_h)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color("#5A4A33"))
		lbl.add_theme_font_size_override("font_size", int(s * 0.13))
		bg.add_child(lbl)

	await create_timer(0.4).timeout
	RenderingServer.force_draw()
	var fb := root.get_texture().get_image()                  # frame to the content (bg covers the rest in cream)
	var img := fb.get_region(Rect2i(0, 0, mini(int(content.x), fb.get_width()), mini(int(content.y), fb.get_height())))
	var err := img.save_png(out)
	print("WIDGET saved=%s err=%d tiles=%s" % [out, err, str(tiles)])
	quit()
