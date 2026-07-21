extends "res://games/grove/tests/grove_test_base.gd"
## grove · MAPS page — the cards-only map gallery (maps_page_v2_cards_only mock): the bottom-nav
## Map button opens a full-screen gallery; the frontier rides a featured card with a CONTINUE
## button, untouched pages read LOCKED (a tap wobbles, never navigates), and taps resolve through
## the single input surface (maps_hits).

func _initialize() -> void:
	begin("grove · maps page")
	fresh("mapspage")
	var h = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h)
	if h.content == null:
		h._ready()
	await create_timer(0.05).timeout
	ok(h._view == "map", "boot lands on a map")

	h._open_maps()
	await create_timer(0.05).timeout
	ok(h._view == "maps", "_open_maps shows the MAPS gallery view")
	ok(h.maps_hits.size() == G.MAPS.size(), "the gallery seats one card per map")
	var feat_hit = null
	var locked_hit = null
	var locked_n := 0
	for hit in h.maps_hits:
		if bool(hit.locked):
			locked_n += 1
			locked_hit = hit
		else:
			feat_hit = hit
	ok(feat_hit != null and int(feat_hit.z) == G.frontier_map(h.unlocks, []), \
		"the featured card is the frontier map")
	ok(locked_n == G.MAPS.size() - 1, "every other map reads LOCKED on a fresh save")

	# a still-tap on a LOCKED card stays on the gallery (wobble, no navigation)
	_map_tap_at(h, _hit_center(locked_hit.node))
	await create_timer(0.05).timeout
	ok(h._view == "maps", "tapping a LOCKED card stays on the gallery")

	# a still-tap on the FEATURED card opens that map
	_map_tap_at(h, _hit_center(feat_hit.node))
	await create_timer(0.05).timeout
	ok(h._view == "map" and h._map_idx == int(feat_hit.z), "tapping the featured card opens the frontier map")

	# the featured CONTINUE button also opens the frontier (a real button — the chip exception)
	h._open_maps()
	await create_timer(0.05).timeout
	# the CONTINUE button is now the baked cut-paper sprite button (named "ContinueButton", no text);
	# fall back to matching the caption for the drawn Look.button variant.
	var go: Button = h.content.find_child("ContinueButton", true, false) as Button
	if go == null:
		for b in h.content.find_children("*", "Button", true, false):
			if (b as Button).text.findn(Strings.t("map.page.continue")) != -1:
				go = b
	ok(go != null, "the featured card carries a CONTINUE button")
	if go != null:
		go.pressed.emit()
		await create_timer(0.05).timeout
		ok(h._view == "map" and h._map_idx == int(feat_hit.z), "CONTINUE opens the frontier map")

	# pages are STRICTLY the scene-workbench scenes (decision 2026-07-18): no page carries the
	# retired farmhouse build items, so every page — the frontier included — reads total 0
	# ("no build system yet") until the zoning-tool unlockables land. Buying farmhouse steps
	# off-page must not move page progress either.
	var p0: Vector2i = h._page_progress(int(feat_hit.z))
	ok(p0 == Vector2i(0, 0), "the frontier page reports no build system yet (pages are pure sw scenes)")
	Save.earn_coins(2000)
	var hst: Dictionary = HomeBuild.state()
	var d: Dictionary = HomeBuild.def_of("fh_hearth")
	var HB := load("res://engine/scripts/core/home_build.gd")
	while HB.buy_step(hst, d):
		pass
	Save.grove_write()
	var p1: Vector2i = h._page_progress(int(feat_hit.z))
	ok(p1 == Vector2i(0, 0), "farmhouse build state no longer feeds page progress")

	# the bottom-nav Map button routes to the gallery (not the spirit dock)
	h._open_map(int(feat_hit.z))
	await create_timer(0.05).timeout
	h._build_maps_page()   # a rebuild never duplicates hits
	ok(h.maps_hits.size() == G.MAPS.size(), "a gallery rebuild seats exactly one hit per map")

	# the gallery chrome: NO heading label; it wears the SAME bottom bar as the home screen, with the
	# leading Map tile swapped for a Home tile (the gallery IS the map). Home · Residents · Daily
	# · Board, plus Mail when the inbox build is present (Vault is parked behind its OFF flag).
	ok(not _label_texts(h.content).has("MAPS"), "the gallery carries no MAPS heading")
	var caps := _label_texts(h.content)
	# Home leads the gallery, and Residents · Daily · Board follow — all baked cut-paper sprite tiles now
	# (icon + label in the PNG, no caption Label), so assert each tile NODE wears its nav sprite.
	for pair in [["HomeTile", "nav_home"], ["ResidentsTile", "nav_residents"], ["DailyTile", "nav_daily"], ["BoardTile", "nav_board"]]:
		var tile := h.content.find_child(String(pair[0]), true, false) as Control
		var wears := tile != null and tile.find_children("*", "TextureRect", true, false).any( \
			func(tr: TextureRect) -> bool: \
				return tr.texture != null and String(tr.texture.resource_path).ends_with(String(pair[1]) + ".png"))
		ok(wears, "the gallery nav carries %s (baked sprite)" % pair[0])
	ok(not caps.has(Strings.t("map.rail.vault")), "the gallery nav drops the parked Vault (flag OFF)")
	ok(not caps.has(Strings.t("map.nav.map")), "the gallery nav drops the Map tile (Home takes its slot)")
	ok(h._select_back == null or not h._select_back.visible, "the gallery hides the back arrow (Home is the way back)")
	# Home steps back to the map you were viewing (the baked sprite tile, found by node name)
	var home_btn := h.content.find_child("HomeTile", true, false) as Button
	ok(home_btn != null, "the HOME nav tile is a real button")
	if home_btn != null:
		home_btn.pressed.emit()
		await create_timer(0.05).timeout
		ok(h._view == "map", "HOME returns to the map view")

	finish()

const HomeBuild = preload("res://engine/scripts/core/home.gd")
