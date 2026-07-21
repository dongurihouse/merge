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

# TOP-DOWN unlock order per coverup page (scenes 2-5 wiring, 2026-07-20) — see BRIEF-scenes.md.
const TOP_DOWN_CLUSTERS := {
	"fairy_hollow": ["mushroom_hall", "tea_stall", "crystal_map_stall", "stream_bridge", "flower_crate", "lantern_gate"],
	"snowy_village": ["lodge", "christmas_tree", "gazebo", "dock", "entrance_arch"],
	"desert_oasis": ["adobe", "watchtower", "market_stall", "travel_tent", "caravan"],
	"coral_reef": ["shipwreck", "anchor", "chest", "statue", "clam"],
	"cherry_blossom_garden": ["pavilion", "pond_bridge", "temizuya", "torii"],
}

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
		# each page's cover-up: a coverup_mode page (the market) carries the authored per-cluster canopy
		# (manifest `coverups`); every other page names its five scene-themed locked-plot covering
		# sprites (scene_coverings.gd scatter).
		if bool(G.MAPS[z].get("coverup_mode", false)):
			var covs: Array = m.get("coverups", [])
			var covs_ok := covs.size() > 0
			for c in covs:
				covs_ok = covs_ok and ResourceLoader.exists(String((c as Dictionary).get("image", "")))
			ok(covs_ok, "page '%s': authored coverup canopy imports (%d sprites)" % [id, covs.size()])
			# Task 2 (scenes 2-5 wiring, 2026-07-20): every coverup page's clusters() ids match the
			# authored TOP-DOWN unlock order exactly (BRIEF-scenes.md's per-scene cluster table).
			var want_order: Array = TOP_DOWN_CLUSTERS.get(id, [])
			var got_order: Array = []
			for c in G.clusters(z):
				got_order.append(String((c as Dictionary).id))
			ok(got_order == want_order, "page '%s': clusters() top-down order is %s (got %s)" % [id, want_order, got_order])
		else:
			var frames: Array = G.MAPS[z].get("covering_frames", [])
			var frames_ok := frames.size() == 5
			for f in frames:
				frames_ok = frames_ok and ResourceLoader.exists(String(f))
			ok(frames_ok, "page '%s': five covering frames all import" % id)
		ok(G.resident_lines(z).size() == 1, "page '%s' carries its resident line" % id)
	# pages are STRICTLY the scene-workbench scenes (decision 2026-07-18): no farmhouse build
	# items ride any page — unlockables arrive via the zoning tool + coverings instead.
	var hub_m := HomeZoneView.load_manifest(String(G.MAPS[0].zone_manifest))
	var hub_ids := {}
	for b in hub_m.get("buildings", []):
		hub_ids[String((b as Dictionary).get("id", ""))] = true
	var carried := 0
	for d in Home.defs():
		if hub_ids.has(String(d.id)):
			carried += 1
	ok(carried == 0, "no page carries the retired farmhouse build items (pages are pure sw scenes)")
	ok((G.MAPS[0].spots as Array).size() == Home.defs().size(), "the hub page keeps the build spots for save-compat")
	# Task 1 (market cluster unlocks, 2026-07-20): the generated fairy_hollow_market page manifest,
	# standalone ahead of Task 2's page-1 repoint — exactly the 6 hero clusters, no coverup leaves.
	var market_path := "res://games/grove/assets/map/pages/zone_fairy_hollow_market.json"
	var market := HomeZoneView.load_manifest(market_path)
	ok(not market.is_empty(), "fairy_hollow_market manifest generated and parses")
	if not market.is_empty():
		var m_canvas: Dictionary = market.get("canvas", {})
		ok(int(m_canvas.get("width", 0)) == 1320 and int(m_canvas.get("height", 0)) == 2346,
			"market canvas is 1320x2346")
		ok(ResourceLoader.exists(String(market.get("background", ""))), "market background texture imports")
		var m_props: Array = market.get("buildings", [])
		var m_ids: Array = []
		for b in m_props:
			m_ids.append(String((b as Dictionary).get("id", "")))
		ok(m_ids.size() == 6, "market manifest has exactly the 6 hero clusters (got %d)" % m_ids.size())
		for want in ["mushroom_hall", "tea_stall", "crystal_map_stall", "stream_bridge", "flower_crate", "lantern_gate"]:
			ok(m_ids.has(want), "market cluster present: %s" % want)
		var m_missing := 0
		for b in m_props:
			for state in (b as Dictionary).get("states", {}).values():
				if not ResourceLoader.exists(String(state)):
					m_missing += 1
		ok(m_missing == 0, "every market prop texture imports (%d props)" % m_props.size())
		# Task 1 (2026-07-20): the authored per-cluster canopy "coverup" layer is carried through
		# from the placements bundle into the manifest as coverups (NOT page props).
		var coverups: Array = market.get("coverups", [])
		ok(coverups.size() == 11, "market manifest carries the 11 canopy coverups (got %d)" % coverups.size())
		var by_cluster := {}
		var c_missing := 0
		var c_prefixed := 0
		for c in coverups:
			var cl := String((c as Dictionary).get("cluster", ""))
			by_cluster[cl] = int(by_cluster.get(cl, 0)) + 1
			if cl.begins_with("unlock_region_"):
				c_prefixed += 1
			if not ResourceLoader.exists(String((c as Dictionary).get("image", ""))):
				c_missing += 1
		ok(c_prefixed == 0, "coverup cluster ids have the unlock_region_ prefix stripped")
		ok(c_missing == 0, "every coverup texture imports (%d coverups)" % coverups.size())
		var c_groups_ok := true
		for want in ["mushroom_hall", "tea_stall", "crystal_map_stall", "stream_bridge", "flower_crate", "lantern_gate"]:
			c_groups_ok = c_groups_ok and by_cluster.has(want)
		ok(c_groups_ok, "coverup groups present for all 6 clusters")
	# Task 5 (2026-07-20): the market page's strict bottom-up cluster unlock sequence + level/coin gate
	# (content.gd helpers). Pure data — no scene. The page carries its ordered clusters table.
	var cl_ids: Array = []
	for c in G.clusters(0):
		cl_ids.append(String((c as Dictionary).id))
	ok(cl_ids == ["mushroom_hall", "tea_stall", "crystal_map_stall", "stream_bridge", "flower_crate", "lantern_gate"],
		"market: clusters unlock top-down (the top cluster first — the bottom sits behind the nav bar)")
	var ul := {}
	ok(G.next_locked_cluster(0, ul) == "mushroom_hall", "market: top cluster first in the sequence")
	ok(G.cluster_locked(0, "tea_stall", ul), "market: tea_stall starts locked")
	ok(not G.cluster_ready(0, "mushroom_hall", ul, 0, 0), "market: under-leveled/too-poor is not ready")
	# min_level is now a FORMULA (2 + global_cluster_index) — mushroom_hall, the very first cluster
	# across every coverup page, lands at L2, not L1.
	ok(not G.cluster_ready(0, "mushroom_hall", ul, 1, 10), "market: L1 is under the formula's L2 floor")
	ok(G.cluster_ready(0, "mushroom_hall", ul, 2, 10), "market: gate met (L2) -> ready")
	ok(not G.cluster_ready(0, "tea_stall", ul, 9, 9999), "market: a later cluster is never ready (strict sequence)")
	ul["mushroom_hall"] = true
	ok(G.next_locked_cluster(0, ul) == "tea_stall", "market: the sequence advances after an unlock")
	ok(G.cluster_ready(0, "tea_stall", ul, 9, 9999), "market: the next cluster becomes ready")

	# Task 3 (scenes 2-5 wiring, 2026-07-20): the GLOBAL consecutive-level formula + the cross-scene
	# gate (content.gd). Pure data/logic — no scene.
	ok(G.coverup_pages() == [0, 1, 2, 3, 4], "every page is a coverup page, in MAPS order")
	ok(G.cluster_min_level(0, "mushroom_hall") == 2, "market's first cluster unlocks at L2")
	ok(G.cluster_min_level(0, "tea_stall") == 3, "market's second cluster unlocks at L3")
	ok(G.cluster_min_level(0, "lantern_gate") == 7, "market's last (6th) cluster unlocks at L7")
	# winter is MAPS[1] — its first cluster sits 6 slots after the market's 6 clusters: L2 + 6 = L8.
	var winter_z := 1
	ok(String(G.MAPS[winter_z].id) == "snowy_village", "MAPS[1] is snowy_village (winter)")
	ok(G.cluster_min_level(winter_z, "lodge") == 2 + 6, "winter's first cluster (lodge) unlocks at L8 (2 + 6 market clusters)")
	# desert is MAPS[2] — its first cluster sits 11 slots after market(6) + winter(5).
	var desert_z := 2
	ok(String(G.MAPS[desert_z].id) == "desert_oasis", "MAPS[2] is desert_oasis")
	ok(G.cluster_min_level(desert_z, "adobe") == 2 + 6 + 5, "desert's first cluster (adobe) unlocks at L13 (2 + 6 + 5)")

	# The cross-scene gate: winter's clusters can't be ready until EVERY market cluster is unlocked,
	# no matter how high the level/coins — a scene's padlocks don't go live until the previous scene
	# is fully restored.
	ok(not G.coverup_scene_open(winter_z, {}), "winter is gated shut with no market clusters unlocked")
	ok(not G.cluster_ready(winter_z, "lodge", {}, 99, 99999), "winter's first cluster is NOT ready while gated, even overpowered")
	var market_done := {}
	for c in G.clusters(0):
		market_done[String((c as Dictionary).id)] = true
	ok(G.coverup_scene_open(winter_z, market_done), "winter opens once every market cluster is unlocked")
	ok(G.cluster_ready(winter_z, "lodge", market_done, 99, 99999), "winter's first cluster becomes ready once its scene opens (+ level/coins met)")
	# desert stays gated even though winter's OWN gate (the market) is satisfied — desert also needs
	# winter's own clusters finished first.
	ok(not G.coverup_scene_open(desert_z, market_done), "desert stays gated until winter's own clusters are also unlocked")
	ok(not G.cluster_ready(desert_z, "adobe", market_done, 99, 99999), "desert's first cluster is NOT ready until winter finishes too")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
