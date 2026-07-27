extends SceneTree
## Dev tool: measure the REAL cap-height/font_size ratio of the live UI face, by rendering
## caps at a known font_size through the same theme the game installs (UiFont) and saving a PNG
## for a pixel measurement. The concept mocks are 1:1 with the 1080x1920 canvas, so a cap height
## measured off a mock converts to a font_size with this ratio — no assumed 0.7 fudge.
##   engine/tools/quiet_godot.sh --path . -s res://games/grove/tools/font_calibrate_shot.gd -- /tmp/cal.png
##   (needs the REAL renderer: get_image() returns null under --headless)

const Base = preload("res://engine/tools/shot_base.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")

const PROBE := "HOME"          # all-caps: bbox height IS the cap height
const SIZES := [16, 24, 32, 40, 56, 72, 96, 128]   # a spread -> fit a LINE; the slope is the true
                                                  # ratio (a constant AA bias lands in the intercept)

func _initialize() -> void:
	var ctx := await Base.begin(self, {"tool": "font_calibrate", "default_out": "/tmp/font_cal.png", "save": false})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var out: String = ctx["out"]
	var root := get_root()
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var theme := UiFont.make()
	var y := 20.0
	for s in SIZES:
		var l := Label.new()
		l.theme = theme
		l.text = PROBE
		l.add_theme_font_size_override("font_size", int(s))
		l.add_theme_color_override("font_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 0)   # outline would inflate the ink bbox
		l.position = Vector2(20, y)
		root.add_child(l)
		y += float(s) * 1.7 + 12.0
	await process_frame
	await process_frame
	var err := Base.capture(self, out, ctx["args"])
	if err != OK:
		print("FAIL: no image (run through quiet_godot.sh, not --headless)")
		quit(1)
		return
	print("sizes=", SIZES, " probe=", PROBE, " -> ", out)
	quit(0)
