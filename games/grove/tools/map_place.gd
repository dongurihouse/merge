extends SceneTree
## INTERACTIVE placement session for map art — a VISIBLE window with the farmhouse owned (so the
## buildings render, not pins) and the drag-to-place editor ON. This is NOT a quiet capture, so it
## deliberately does NOT use override.cfg / minimize — we want a focusable window you can drag in.
##
## Run when YOU are ready to place (it takes window focus):
##   GAME=grove godot --path . -s res://games/grove/tools/map_place.gd
##
## The map rides a camera framed with a margin so the whole map is visible. MOUSE WHEEL (with
## nothing selected) zooms the view · ARROW KEYS pan · 0 resets the framing.
## In the window: drag a building to move it · drag empty map art to move the background ·
## −/+ buttons (or wheel on a selection) resize the selected building/background · 💾 SAVE writes res://data/placements.json.
## Close the window when done — the saved positions persist (committed with the repo), and the real
## game reads through them. Uses a throwaway /tmp save, so your real progress is untouched; only
## placements.json changes.

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Debug = preload("res://engine/scripts/ui/debug.gd")

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(430, 932))
	DisplayServer.window_set_title("Grove — Map 1 placement editor")
	# throwaway save so real progress is untouched; placements.json is a SEPARATE committed file
	var dir := "/tmp/tu_place/"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)
	Save.set_setting("music", false)            # no music during placement
	# own every farmhouse spot so the buildings render as art (not the 3-state pin)
	var g := Save.grove()
	var ul := {}
	for sp in G.MAPS[0].spots:
		ul[String(sp.id)] = true
	g["unlocks"] = ul
	g["stars_earned"] = 40
	Save.grove_write()
	Debug.force = true                          # show the drag-to-place editor chrome
	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.5).timeout
	scn._open_map(0)                            # the Farmhouse (map index 0)
	print("\n=== MAP 1 PLACEMENT EDITOR ===")
	print("Wheel (nothing selected) zooms the view · arrows pan · 0 resets · drag a building to move it · drag empty map art to move background · −/+ resize selected · 💾 SAVE → data/placements.json")
	print("Close the window when done, then tell me — I'll read back the positions.\n")
	# NO quit — stay interactive until the window is closed
