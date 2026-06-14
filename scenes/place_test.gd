extends Node2D
## Standalone placement sandbox — JUST the new farmhouse background + the new
## photo frames, draggable at runtime like the real game.
##   godot --path . scenes/place_test.tscn
## Controls:  drag = move the frame · [1]-[9] switch frame · [ - / = ] resize
##            [P] print the normalized coord to the console
## The house sits at (0,0), so a frame's normalized coord = position / (1084,1451)
## — that's the number for fh_picture in data/placements.json.

const BG := "res://assets/ChatGPT Image Jun 13, 2026, 01_47_01 PM.png"
const FRAMES := [
	"res://assets/frames/frame_1.png",
	"res://assets/frames/frame_2.png",
	"res://assets/frames/frame_3.png",
	"res://assets/frames/frame_4.png",
	"res://assets/frames/frame_5.png",
	"res://assets/frames/frame_6.png",
	"res://assets/frames/frame_7.png",
	"res://assets/frames/frame_8.png",
	"res://assets/frames/frame_9.png",
]
const HOUSE := Vector2(1084, 1451)
const Layout = preload("res://scripts/layout.gd")
const G = preload("res://scripts/grove_content.gd")

var frames: Array = []
var active := 0
var dragging := false
var label: Label
var pic_z := 0   # farmhouse zone / fh_picture spot index (found in _ready)
var pic_k := 0

func _tex(p: String) -> Texture2D:
	# decode the PNG directly so transparency is preserved (the imported texture
	# can flatten the frames' alpha to white)
	var img := Image.new()
	img.load_png_from_buffer(FileAccess.get_file_as_bytes(p))
	return ImageTexture.create_from_image(img)

func _ready() -> void:
	var house := Sprite2D.new()
	house.texture = _tex(BG)
	house.centered = false
	house.position = Vector2.ZERO
	add_child(house)
	for i in FRAMES.size():
		var fr := Sprite2D.new()
		fr.texture = _tex(FRAMES[i])
		fr.scale = Vector2(0.40, 0.40)         # cleaned frames are cropped tight
		fr.position = Vector2(390, 300)        # back-wall spot; drag from here
		fr.visible = (i == 0)
		add_child(fr)
		frames.append(fr)
	for z in G.ZONES.size():
		for k in G.ZONES[z].spots.size():
			if String(G.ZONES[z].spots[k].id) == "fh_picture":
				pic_z = z
				pic_k = k
	var cl := CanvasLayer.new()
	add_child(cl)
	label = Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	cl.add_child(label)
	_refresh()

func _refresh() -> void:
	var f: Sprite2D = frames[active]
	var n := f.position / HOUSE
	label.text = "Frame %d/9   norm (%.4f, %.4f)   scale %.3f\n[1-9] switch  ·  drag  ·  - / = resize  ·  S = SAVE to placements.json" % \
		[active + 1, n.x, n.y, f.scale.x]

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if e.keycode >= KEY_1 and e.keycode <= KEY_9:
			var idx: int = e.keycode - KEY_1
			if idx < frames.size():
				frames[active].visible = false
				active = idx
				frames[active].visible = true
				_refresh()
		elif e.keycode == KEY_EQUAL or e.keycode == KEY_KP_ADD:
			frames[active].scale *= 1.05; _refresh()
		elif e.keycode == KEY_MINUS or e.keycode == KEY_KP_SUBTRACT:
			frames[active].scale *= 0.95; _refresh()
		elif e.keycode == KEY_S:
			var sf: Sprite2D = frames[active]
			var pos: Vector2 = sf.position / HOUSE
			var fsz: float = sf.texture.get_size().x * sf.scale.x
			Layout.set_spot_pos(pic_z, pic_k, pos)
			Layout.set_spot_fsize(pic_z, pic_k, fsz)
			var path: String = Layout.save()
			label.text = "✓ SAVED frame_%d → fh_picture   pos [%.4f, %.4f]  fsize %d\n%s\n(tell me to install frame_%d as furn_fh_picture.png to see it in-game)" % \
				[active + 1, pos.x, pos.y, int(fsz), path, active + 1]
			print("SAVED fh_picture frame_%d pos=[%.4f,%.4f] fsize=%d -> %s" % [active + 1, pos.x, pos.y, int(fsz), path])
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			var f: Sprite2D = frames[active]
			var sz: Vector2 = f.texture.get_size() * f.scale
			if Rect2(f.global_position - sz / 2.0, sz).has_point(get_global_mouse_position()):
				dragging = true
		else:
			dragging = false
			_refresh()
	elif e is InputEventMouseMotion and dragging:
		frames[active].global_position = get_global_mouse_position()
		_refresh()
