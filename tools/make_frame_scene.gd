extends SceneTree
## Dev tool: build a throwaway scene for hand-placing the photo frames on the
## farmhouse background in the EDITOR.
##   godot --headless --path . -s res://tools/make_frame_scene.gd
## Then open scenes/frame_test.tscn in the editor and drag the frame sprites
## onto the wall. Delete the scene when you're done testing.

const BG := "res://assets/ChatGPT Image Jun 13, 2026, 01_47_01 PM.png"
const FRAMES := [
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_03 PM (1).png",
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_04 PM (2).png",
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_04 PM (3).png",
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_04 PM (4).png",
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_04 PM (5).png",
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_06 PM (6).png",
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_06 PM (7).png",
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_06 PM (8).png",
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_06 PM (9).png",
]

func _initialize() -> void:
	var root := Node2D.new()
	root.name = "FrameTest"

	var house := Sprite2D.new()
	house.name = "House"
	house.texture = load(BG)
	house.centered = false
	house.position = Vector2.ZERO
	root.add_child(house)
	house.owner = root

	# all 9 frames start stacked at the back-wall picture spot (matches the montage
	# position/scale). Only frame_1 is shown; toggle the eye icon on frame_2..9 in
	# the Scene dock to compare each ON THE WALL, and drag any to fine-tune.
	var wall := Vector2(390, 300)   # ~ (0.36, 0.205) of the 1084x1451 background
	for i in FRAMES.size():
		var fr := Sprite2D.new()
		fr.name = "frame_%d" % (i + 1)
		fr.texture = load(FRAMES[i])
		fr.scale = Vector2(0.24, 0.24)
		fr.position = wall
		fr.visible = (i == 0)
		root.add_child(fr)
		fr.owner = root

	var packed := PackedScene.new()
	var perr := packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/frame_test.tscn")
	print("pack=%d  save=%d  ->  res://scenes/frame_test.tscn" % [perr, err])
	quit()
