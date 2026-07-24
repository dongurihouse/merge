extends SceneTree
## Gates the scene workbench's COVER tooling — the pure zone sidecar (scene_covers_model.gd) and the
## zone-fill scatter generator (scene_covers_gen.gd). No rendering; geometry + doc ops only.

const Gen = preload("res://games/grove/tools/scene_covers_gen.gd")
const CM = preload("res://games/grove/tools/scene_covers_model.gd")
const HZV = preload("res://engine/scripts/ui/home_zone_view.gd")

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

	# --- sourceCrop parity (winter's edge foliage) -------------------------------------
	# The sw crops a full-canvas plate to each placement's REGION; that crop MUST survive into the
	# manifest AND be applied by the runtime, else the whole plate smears across the scene (winter's
	# edge foliage rendered over the sky — the bug this guards). Covers BOTH pipeline halves.
	var zdoc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://games/grove/assets/map/winter/zone.json"))
	var cropped_entries := 0
	for b in zdoc.get("buildings", []):
		if String((b as Dictionary).get("id", "")).begins_with("edge_covering"):
			var sc = (b as Dictionary).get("sourceCrop")
			if sc is Array and (sc as Array).size() == 4:
				cropped_entries += 1
	ok(cropped_entries == 5, "build_page_manifests carries sourceCrop into winter's 5 edge coverings (%d)" % cropped_entries)

	var img_path := "res://games/grove/assets/map/winter/background/edge_coverings.png"
	var full_tex := HZV._placed_texture(img_path, {})
	ok(full_tex != null and not (full_tex is AtlasTexture), "no sourceCrop -> the whole texture, uncropped")
	var crop_tex := HZV._placed_texture(img_path, {"sourceCrop": [0, 0, 360, 570]})
	ok(crop_tex is AtlasTexture, "a sourceCrop yields an AtlasTexture (only the authored region renders)")
	ok(crop_tex is AtlasTexture and (crop_tex as AtlasTexture).region == Rect2(0, 0, 360, 570),
		"the AtlasTexture region matches the sourceCrop")

	# --- rot parity (leaning props + canopies) -----------------------------------------
	# The sw rotates EVERY placement about its foot (scene_workbench_view._make_layer). Like
	# sourceCrop above, that rot must survive into the manifest AND be applied by the runtime —
	# otherwise the workbench shows a leaning grove and the game renders it bolt-upright.
	# Both halves are guarded; the counts are derived from the authored art, not hardcoded.
	var rot_src := 0
	var rot_mf := 0
	for scene_id in ["hollow", "winter", "oasis", "coral", "sakura"]:
		var zj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://games/grove/assets/map/%s/zone.json" % scene_id))
		var pjd: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://games/grove/assets/map/%s/placements.json" % scene_id))
		var mids := {}
		for sec in ["buildings", "coverups"]:
			for e in zj.get(sec, []):
				var ed: Dictionary = e
				mids[String(ed.get("id", ""))] = true
				if absf(float(ed.get("rot", 0.0))) > 0.0001:
					rot_mf += 1
		for e in pjd.get("placements", []):
			var pd: Dictionary = e
			# ids absent from the manifest were skipped for missing art — not a dropped rot
			if mids.has(String(pd.get("id", ""))) and absf(float(pd.get("rot", 0.0))) > 0.0001:
				rot_src += 1
	ok(rot_src > 0, "the authored scenes carry rotation at all (%d placements)" % rot_src)
	ok(rot_mf == rot_src,
		"build_page_manifests carries EVERY authored rot into the manifests (%d of %d)" % [rot_mf, rot_src])

	# runtime half — drive the real build() and measure the nodes it produces
	var holder := Control.new()
	get_root().add_child(holder)
	var mf := {
		"canvas": {"width": 1000, "height": 1000}, "background": img_path,
		"buildings": [{"id": "leaner", "position": [500, 800], "display_size": [100, 200],
			"sort_y": 0, "rot": 30.0, "states": {"built": img_path}}],
		"coverups": [{"id": "canopy", "cluster": "c1", "position": [300, 600],
			"display_size": [80, 160], "sort_y": 0, "rot": 30.0, "image": img_path}],
	}
	var built: Dictionary = HZV.build(holder, mf, func(_i): return "built", func(_i): return {},
		[], true, func(_c): return true)
	var leaner: Control = (built.props as Dictionary).get("leaner")
	ok(leaner != null and is_equal_approx(leaner.rotation_degrees, 30.0),
		"the runtime applies the manifest rot to a prop")
	ok(leaner != null and leaner.pivot_offset.is_equal_approx(Vector2(50, 200)),
		"a prop rotates about its FOOT (bottom-centre) — the tool's pivot")
	var grp: Control = (built.coverings as Dictionary).get("c1")
	var canopy: Control = grp.get_child(0) if grp != null and grp.get_child_count() > 0 else null
	var d := Vector2(0.0, 80.0)                       # centre -> foot of a 160-tall sprite
	var want := Vector2(300.0 - 40.0, 600.0 - 160.0) + d - d.rotated(deg_to_rad(30.0))
	ok(canopy != null and canopy.pivot_offset.is_equal_approx(Vector2(40, 80)),
		"a canopy KEEPS its centre pivot (reveal() scales from there)")
	ok(canopy != null and canopy.position.is_equal_approx(want),
		"a canopy is shifted so centre-pivot rotation lands exactly where foot-pivot rotation would")
	holder.queue_free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
