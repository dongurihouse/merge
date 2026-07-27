extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): prove the code-drawn CutPaperPanel scales to any size
## with no stretch — render several very different rectangles side by side on the sky.
##   quiet_godot.sh --path . -s res://games/grove/tools/cutpaper_shot.gd -- /tmp/cutpaper.png

const Base = preload("res://engine/tools/shot_base.gd")
const CutPaper = preload("res://engine/scripts/ui/cut_paper.gd")
const Pal = preload("res://engine/scripts/core/game.gd").PALETTE
const TILE := "res://games/grove/assets/ui/dialogs/paper_tile_cream.png"

const CANVAS := Vector2i(1000, 900)

func _initialize() -> void:
	var ctx := await Base.begin(self, {
		"tool": "cutpaper",
		"default_out": "/tmp/cutpaper.png",
		"size": CANVAS,
		"save": false,
	})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var out: String = ctx["out"]

	var root := get_root()
	var bg := ColorRect.new()
	bg.color = Pal.SCREEN_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var tile := load(TILE) as Texture2D
	# same code, different shapes AND sizes — nothing is stretched
	var panels := [
		{"pos": Vector2(40, 40), "size": Vector2(360, 560), "shape": "rect"},
		{"pos": Vector2(440, 40), "size": Vector2(520, 150), "shape": "rect"},
		{"pos": Vector2(440, 240), "size": Vector2(240, 240), "shape": "poly", "sides": 5},   # pentagon
		{"pos": Vector2(710, 240), "size": Vector2(240, 240), "shape": "poly", "sides": 6},   # hexagon
		{"pos": Vector2(440, 520), "size": Vector2(240, 240), "shape": "poly", "sides": 3},   # triangle
		{"pos": Vector2(710, 520), "size": Vector2(250, 250), "shape": "blob"},               # organic blob
	]
	for d in panels:
		var p = CutPaper.new()
		p.shape = String(d.get("shape", "rect"))
		if d.has("sides"):
			p.sides = int(d["sides"])
		p.position = d["pos"]
		p.size = d["size"]
		p.custom_minimum_size = d["size"]
		p.paper_tex = tile
		root.add_child(p)

	await create_timer(0.5).timeout
	var err := Base.capture(self, out, ctx["args"])
	print("SHOT saved=%s err=%d size=%s" % [out, err, str(CANVAS)])
	quit(0)
