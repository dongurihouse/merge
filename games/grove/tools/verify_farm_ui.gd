extends SceneTree
## Dev tool (one-off): verify the sliced home-screen kit assets load as real, non-null
## Texture2D with sane sizes (a missing-texture placeholder would be tiny / wrong-sized).
##
##   godot --headless --path . -s res://games/grove/tools/verify_farm_ui.gd

# name -> expected size (from the slice run)
const EXPECT := {
	"badge_cost":         Vector2i(212, 214),
	"badge_locked":       Vector2i(232, 212),
	"pill_progress":      Vector2i(603, 109),
	"pill_progress_fill": Vector2i(333, 26),
	"nav_market":         Vector2i(166, 175),
	"nav_garden":         Vector2i(185, 194),
	"nav_map":            Vector2i(164, 176),
	"nav_piggy":          Vector2i(164, 175),
}

func _initialize() -> void:
	var fails := 0
	for key in EXPECT:
		var name := String(key)
		var path: String = "res://games/grove/assets/ui/kit/" + name + ".png"
		var tex: Texture2D = load(path)
		if tex == null:
			print("FAIL %s -> null" % name); fails += 1; continue
		var sz := tex.get_size()
		var want: Vector2i = EXPECT[name]
		var ok := int(sz.x) == want.x and int(sz.y) == want.y
		print("%s %s -> %dx%d (want %dx%d)" % [
			"OK  " if ok else "FAIL", name, int(sz.x), int(sz.y), want.x, want.y])
		if not ok: fails += 1
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
