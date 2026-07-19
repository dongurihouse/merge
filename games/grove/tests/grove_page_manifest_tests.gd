extends SceneTree
## Guards the picture-book PAGE wiring (2026-07-18): every map names a zone manifest that parses,
## whose background + prop textures all import, and whose paint order carries the scene's z.
## Manifests are GENERATED — tools/build_page_manifests.py from the scene-workbench bundles.

const G = preload("res://engine/scripts/core/content.gd")
const Home = preload("res://engine/scripts/core/home.gd")
const HomeZoneView = preload("res://engine/scripts/ui/home_zone_view.gd")

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
	print("== Grove page manifests ==")
	ok(G.MAPS.size() == 5, "the world is the five picture-book pages")
	ok(String(G.MAPS[0].id) == "fairy_hollow" and bool(G.MAPS[0].get("hub", false)),
		"Fairy Hollow opens the book as the hub page")
	for z in G.MAPS.size():
		var id := String(G.MAPS[z].id)
		var path := String(G.MAPS[z].get("zone_manifest", ""))
		var m := HomeZoneView.load_manifest(path)
		ok(not m.is_empty(), "page '%s' manifest parses (%s)" % [id, path])
		if m.is_empty():
			continue
		ok(ResourceLoader.exists(String(m.get("background", ""))),
			"page '%s' background texture imports" % id)
		var missing := 0
		var props: Array = m.get("buildings", [])
		for b in props:
			for state in (b as Dictionary).get("states", {}).values():
				if not ResourceLoader.exists(String(state)):
					missing += 1
		ok(missing == 0, "page '%s': every prop texture imports (%d props)" % [id, props.size()])
		ok(z == 0 or bool(G.MAPS[z].get("open", false)),
			"page '%s' is browsable (interim `open` until the frontier gate lands)" % id)
		ok(G.resident_lines(z).size() == 1, "page '%s' carries its resident line" % id)
	# the hub page still carries the interim build surface (farmhouse items + spots)
	var hub_m := HomeZoneView.load_manifest(String(G.MAPS[0].zone_manifest))
	var hub_ids := {}
	for b in hub_m.get("buildings", []):
		hub_ids[String((b as Dictionary).get("id", ""))] = true
	var carried := 0
	for d in Home.defs():
		if hub_ids.has(String(d.id)):
			carried += 1
	ok(carried == Home.defs().size(), "the hub page carries every farmhouse build item (interim build surface)")
	ok((G.MAPS[0].spots as Array).size() == Home.defs().size(), "the hub page keeps the build spots for save-compat")
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
