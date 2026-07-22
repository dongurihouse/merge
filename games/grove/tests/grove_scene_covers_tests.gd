extends SceneTree
## Gates the scene workbench's COVER tooling — the pure zone sidecar (scene_covers_model.gd) and the
## zone-fill scatter generator (scene_covers_gen.gd). No rendering; geometry + doc ops only.

const Gen = preload("res://games/grove/tools/scene_covers_gen.gd")
const CM = preload("res://games/grove/tools/scene_covers_model.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _square(x0: float, y0: float, s: float) -> Array:
	return [Vector2(x0, y0), Vector2(x0 + s, y0), Vector2(x0 + s, y0 + s), Vector2(x0, y0 + s)]

func _assets() -> Array:
	return [
		{"id": "shell_cap", "image": "a/shell.png", "w": 585, "h": 600},
		{"id": "kelp", "image": "a/kelp.png", "w": 400, "h": 700},
	]

# center of an emitted entry = (x, y - h/2), inverting the center-bottom anchor the generator writes.
func _center(e: Dictionary) -> Vector2:
	return Vector2(float(e.x), float(e.y) - float(e.h) * 0.5)

func _initialize() -> void:
	print("== Scene covers tests ==")
	var poly := _square(100.0, 100.0, 600.0)
	var assets := _assets()

	# --- generator: coverage + tagging -------------------------------------------------
	var covers := Gen.generate(poly, assets, "unlock_region_shipwreck", 100, 1234)
	ok(covers.size() >= 6, "a 600px square zone fills with a multi-sprite scatter")
	var all_coverup := true
	var all_cluster := true
	var all_flag := true
	for e in covers:
		if String(e.layer) != "coverup":
			all_coverup = false
		if String(e.cluster) != "unlock_region_shipwreck":
			all_cluster = false
		if not bool(e.unlockCover):
			all_flag = false
	ok(all_coverup, "every cover lands in the coverup layer")
	ok(all_cluster, "every cover joins the zone's unlock_region cluster")
	ok(all_flag, "every cover is tagged unlockCover")
	ok(int(covers[0].clusterZ) == 100, "clusterZ is carried through from the caller")

	# --- painter order + size mix ------------------------------------------------------
	var ordered := true
	for i in range(1, covers.size()):
		if float(covers[i].y) - float(covers[i].h) * 0.5 < float(covers[i - 1].y) - float(covers[i - 1].h) * 0.5:
			ordered = false
	ok(ordered, "covers emit in painter order (back to front by centre y)")
	var sizes := {}
	for e in covers:
		sizes[int(e.w)] = true
	ok(sizes.size() >= 2, "the scatter mixes larger and smaller covers")

	# --- overflow bound: centres stay inside the zone or within 10% of the short side --
	var margin := 600.0 * Gen.OVERFLOW
	var within := true
	for e in covers:
		var c := _center(e)
		if not (Gen._in_poly(c, poly) or Gen._dist_to_poly(c, poly) <= margin + 0.001):
			within = false
	ok(within, "no cover centre strays past the allowed 10% overflow margin")

	# --- determinism + reroll ----------------------------------------------------------
	var again := Gen.generate(poly, assets, "unlock_region_shipwreck", 100, 1234)
	ok(JSON.stringify(again) == JSON.stringify(covers), "same seed reproduces the exact scatter")
	var rerolled := Gen.generate(poly, assets, "unlock_region_shipwreck", 100, 5678)
	ok(JSON.stringify(rerolled) != JSON.stringify(covers), "a new seed rerolls a different scatter")

	# --- degenerate inputs -------------------------------------------------------------
	ok(Gen.generate([Vector2(0, 0), Vector2(10, 0)], assets, "c", 0, 1).is_empty(),
		"a <3-vertex polygon yields nothing")
	ok(Gen.generate(poly, [], "c", 0, 1).is_empty(), "no coverup art yields nothing")

	# --- sidecar model round-trip ------------------------------------------------------
	var canvas := Vector2(941, 1672)
	var doc := CM.blank("coral", canvas)
	ok(CM.set_zone(doc, "shipwreck", poly), "set_zone adds a zone for an object")
	ok(not CM.set_zone(doc, "bad", [Vector2(0, 0), Vector2(1, 1)]), "a <3-point zone is rejected")
	ok(CM.has_zone(doc, "shipwreck") and not CM.has_zone(doc, "chest"), "has_zone reflects membership")
	CM.set_zone(doc, "shipwreck", _square(0.0, 0.0, 200.0))
	ok((doc.zones as Array).size() == 1, "set_zone REPLACES an object's existing zone (no duplicate)")
	CM.set_zone(doc, "chest", _square(300.0, 300.0, 150.0))

	var path := "user://covers_test.json"
	ok(CM.save_doc(path, doc), "save_doc writes the sidecar")
	var loaded := CM.load_doc(path, "coral", canvas)
	ok((loaded.zones as Array).size() == 2, "load_doc round-trips both zones")
	ok(CM.zone_for(loaded, "chest").get("object", "") == "chest", "zone_for finds a zone by object")
	CM.delete_zone(loaded, "shipwreck")
	ok((loaded.zones as Array).size() == 1 and not CM.has_zone(loaded, "shipwreck"),
		"delete_zone removes the object's zone")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
