extends SceneTree
## Dev tool (real renderer; run via engine/tools/quiet_godot.sh): a board item, a resident sprite and
## a second board item side by side at the same size — the A/B for "do these two paths frame their art
## the same way?".   quiet_godot.sh --path . -s res://games/grove/tools/cell_compare_shot.gd -- /tmp/cells.png

const Base = preload("res://games/grove/tools/shot_base.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Game = preload("res://engine/scripts/core/game.gd")

const PX := 240.0

func _initialize() -> void:
	var ctx := await Base.begin(self, {"tool": "cell_compare", "default_out": "/tmp/cell_compare.png", "save": false})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var out: String = ctx["out"]
	var bg := ColorRect.new(); bg.color = Color("#7FA6B8"); bg.size = Vector2(1000, 400); root.add_child(bg)
	# 1: a board item (mushroom t1) via make_piece — the board's exact call
	var item := PieceView.make_piece(101, PX)   # line 1 (flower) t1... use a real code
	item.position = Vector2(40, 60); bg.add_child(item)
	# 2: a resident via the residents path. Keyed by SPECIES ("sprout"), not by the currency KIND
	# ("coin") the tool used to pass — that path resolved to a file that does not exist, and the
	# null texture then crashed the run before it could quit (a hang, since a SceneTree tool only
	# exits on quit()). Missing art now degrades to a gap, loudly.
	var art := G.resident_art("sprout", 1)
	var tex := load(art) as Texture2D if ResourceLoader.exists(art) else null
	if tex == null:
		print("cell_compare: no resident art at %s — skipping panel 2" % art)
	else:
		var img := tex.get_image(); var ur := img.get_used_rect()
		var at := AtlasTexture.new(); at.atlas = tex; at.region = Rect2(ur)
		var res := PieceView.make_piece_from_texture(at, PX, PieceView.ITEM_INSET)
		res.position = Vector2(360, 60); bg.add_child(res)
	# 3: a board mushroom (squarish) for reference
	var mush := PieceView.make_piece(501, PX)   # line 5 mushroom t1
	mush.position = Vector2(680, 60); bg.add_child(mush)
	await create_timer(0.5).timeout
	var err := Base.capture(self, out, ctx["args"], Rect2i(0, 0, 960, 360))
	print("SHOT saved=%s err=%d px=%d" % [out, err, PX])
	quit()
