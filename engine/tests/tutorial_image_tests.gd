extends SceneTree
## Headless guard for full-screen tutorial image overlays.

const TutorialImage = preload("res://engine/scripts/ui/tutorial_image.gd")

const CASES := [
	{
		"name": "board",
		"overlay": "TestBoardTutorialOverlay",
		"path": "res://games/grove/assets/ui/tutorial/how_to_play_board.png",
	},
	{
		"name": "rush",
		"overlay": "TestRushTutorialOverlay",
		"path": "res://games/grove/assets/ui/tutorial/how_to_play_rush.png",
	},
]

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _initialize() -> void:
	var host := Control.new()
	host.name = "TutorialImageTestHost"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	await process_frame

	var viewport_size := get_root().get_viewport().get_visible_rect().size
	for c in CASES:
		var overlay_name := String(c.overlay)
		var overlay := TutorialImage.open(host, overlay_name, String(c.path))
		await process_frame
		var backdrop := overlay.find_child("TutorialImageBackdrop", true, false) as ColorRect if overlay != null else null
		var art := overlay.find_child("TutorialImageArt", true, false) as TextureRect if overlay != null else null
		var hit := overlay.find_child("TutorialDismissHitArea", true, false) as Button if overlay != null else null
		ok(overlay != null, "%s tutorial opens a full-screen overlay" % String(c.name))
		ok(backdrop != null and backdrop.get_global_rect().size.distance_to(viewport_size) < 2.0, \
			"%s tutorial paints a full-screen black backdrop behind contained art" % String(c.name))
		ok(backdrop != null and backdrop.color.is_equal_approx(Color.BLACK), \
			"%s tutorial backdrop is opaque black" % String(c.name))
		ok(backdrop != null and art != null and backdrop.get_index() < art.get_index(), \
			"%s tutorial backdrop sits behind the art" % String(c.name))
		ok(art != null and art.get_global_rect().size.distance_to(viewport_size) < 2.0, \
			"%s tutorial art rect fills the screen" % String(c.name))
		ok(hit != null and hit.get_global_rect().size.distance_to(viewport_size) < 2.0, \
			"%s tutorial tap target fills the screen" % String(c.name))
		ok(art != null and art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, \
			"%s tutorial image is fully contained and centered instead of cropped" % String(c.name))
		if overlay != null:
			overlay.queue_free()
			await process_frame

	host.queue_free()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
