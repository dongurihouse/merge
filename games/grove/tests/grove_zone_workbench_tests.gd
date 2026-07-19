extends SceneTree
## Gates games/grove/tools/zone_workbench_model.gd — the PURE half of the unlock-zone
## workbench (page listing, document load/save round-trip, zone ops, clamping).

const M = preload("res://games/grove/tools/zone_workbench_model.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

const CANVAS := Vector2(1320, 2346)
const TRI := [Vector2(100, 100), Vector2(300, 100), Vector2(200, 300)]

func _initialize() -> void:
	print("== Zone workbench model tests ==")

	# --- pages ----------------------------------------------------------------------
	var pages: Array = M.pages()
	ok(pages.size() == 5, "pages() lists the five picture-book pages")
	var ids: Array = []
	for p in pages:
		ids.append(String(p.id))
		ok(FileAccess.file_exists(String(p.zone_manifest)),
			"page %s names an existing zone manifest" % p.id)
	ok(ids.has("fairy_hollow"), "fairy_hollow is a page")
	ok(M.unlocks_path("fairy_hollow") == "res://games/grove/assets/map/pages/unlocks_fairy_hollow.json",
		"unlocks_path is the sibling-file convention")

	# --- document ops ---------------------------------------------------------------
	var d: Dictionary = M.blank("fairy_hollow", CANVAS)
	ok(int(d.version) == 1 and String(d.scene) == "fairy_hollow" and (d.zones as Array).is_empty(),
		"blank() shapes an empty v1 document")
	ok(not M.add_zone(d, [Vector2(0, 0), Vector2(1, 1)]), "add_zone rejects <3 points")
	ok(M.add_zone(d, TRI), "add_zone accepts a triangle")
	M.add_zone(d, [Vector2(400, 400), Vector2(600, 400), Vector2(9999, 9999)])
	var z1: Dictionary = (d.zones as Array)[1]
	ok((z1.points as Array)[2] == Vector2(CANVAS.x - 1, CANVAS.y - 1), "points clamp to the canvas")
	ok(String(z1.name) == "Zone 2", "zones auto-name by position")
	M.rename_zone(d, 1, "Gate")
	M.set_enabled(d, 1, false)
	M.set_button(d, 0, Vector2(150, 150))
	M.reorder_zone(d, 1, 0)
	ok(String((d.zones as Array)[0].name) == "Gate", "reorder moves the zone (order = unlock order)")

	# --- save / load round-trip -----------------------------------------------------
	var text: String = M.serialize(d)
	var parsed: Dictionary = JSON.parse_string(text)
	ok(int(parsed.version) == 1 and (parsed.zones as Array).size() == 2, "serialize emits v1 with both zones")
	ok((parsed.zones as Array)[1].has("button") and not (parsed.zones as Array)[0].has("button"),
		"button persists only when placed")
	ok((parsed.canvas as Array)[0] == 1320.0 and (parsed.canvas as Array)[1] == 2346.0,
		"canvas rides the document")
	var tmp := "user://test_unlocks_roundtrip.json"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var back: Dictionary = M.load_doc_from(tmp, "fairy_hollow", CANVAS)
	ok((back.zones as Array).size() == 2, "load_doc_from reads both zones back")
	ok(String((back.zones as Array)[0].name) == "Gate" and not bool((back.zones as Array)[0].enabled),
		"name + enabled round-trip")
	ok((back.zones as Array)[1].button is Vector2, "button round-trips as Vector2")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	ok((M.load_doc_from("user://does_not_exist.json", "fairy_hollow", CANVAS).zones as Array).is_empty(),
		"a missing file loads as blank")

	# --- zone removal ---------------------------------------------------------------
	M.delete_zone(d, 0)
	ok((d.zones as Array).size() == 1 and String((d.zones as Array)[0].name) == "Zone 1",
		"delete_zone removes by index")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
