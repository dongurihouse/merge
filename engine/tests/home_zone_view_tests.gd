extends SceneTree
## Headless guard for the layered HOME zone renderer (ui/home_zone_view.gd): it builds the
## foundation + one painter-sorted prop per building from a manifest + injected state resolvers,
## and a build badge over every unbuilt plot. Also checks the shipped zone_fairy_hollow.json manifest.
##   godot --headless --path . -s res://engine/tests/home_zone_view_tests.gd

const HZV = preload("res://engine/scripts/ui/home_zone_view.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _manifest() -> Dictionary:
	return {
		"canvas": {"width": 941, "height": 1672},
		"background": "res://games/grove/assets/map/pages/fairy_hollow/foundation.png",
		"buildings": [
			{"id": "a", "position": [200, 800], "display_size": [100, 100], "sort_y": 800,
				"states": {"built": "res://games/grove/assets/map/pages/fairy_hollow/moon_swing_seat_front.png",
					"site": "res://games/grove/assets/map/pages/fairy_hollow/moon_swing_seat_front.png"}},
			{"id": "b", "position": [400, 1200], "display_size": [100, 100], "sort_y": 1200,
				"states": {"built": "res://games/grove/assets/map/pages/fairy_hollow/glowing_mushrooms.png"}},
		],
	}

func _initialize() -> void:
	print("== Home zone view tests ==")
	var m := _manifest()

	# state stubs: `a` is mid-build (site, still has a next step), `b` is empty (a plot, next step at L1)
	var states := {"a": "site", "b": "empty"}
	var steps := {
		"a": {"cost": 25, "min_level": 2, "shows": "built"},
		"b": {"cost": 10, "min_level": 1, "shows": "site"},
	}
	var state_of := func(id): return String(states.get(id, "empty"))
	var next_of := func(id): return steps.get(id, {})

	var parent := Control.new()
	get_root().add_child(parent)
	var out := HZV.build(parent, m, state_of, next_of)

	ok(out.base != null and out.base.texture != null, "the foundation base loads its background texture")
	ok(out.canvas == Vector2(941, 1672), "the stage sizes to the manifest canvas")

	# `a` has a site prop; `b` is empty so it has NO prop, only a badge.
	ok(out.props.has("a") and not out.props.has("b"), "a mid-build plot renders its prop; an empty plot renders none")
	var pa: TextureRect = out.props["a"]
	ok(pa.z_index == 0, "props stay at z 0 (painter order is child order, so chrome bands stay above the scene)")
	# painter order = sort_y as CHILD order: with the manifest listed back-to-front, the low-sort_y
	# prop still mounts before the high one, and badges mount after every prop (buttons on top).
	var rev := _manifest()
	(rev.buildings as Array).reverse()
	var out_rev := HZV.build(parent, rev, func(_id): return "built", \
		func(id): return {"cost": 5, "min_level": 1} if id == "a" else {})
	var ra: TextureRect = out_rev.props["a"]
	var rb: TextureRect = out_rev.props["b"]
	ok(ra.z_index == 0 and rb.z_index == 0 and ra.get_index() < rb.get_index(), \
		"a reversed manifest still paints low-sort_y props first (stable sort_y child order)")
	var rev_badge: Control = out_rev.badges["a"]
	ok(rev_badge.get_index() > rb.get_index(), "build badges mount after every prop (a button is never painted over)")
	ok(is_equal_approx(pa.position.x, 200 - 50) and is_equal_approx(pa.position.y, 800 - 100), \
		"the prop is center-bottom anchored (x-half-width, y-full-height)")
	ok(pa.modulate.a < 1.0, "a SITE prop renders dimmer than a finished building")

	# both unbuilt buildings carry a build badge with the step's cost + level
	ok(out.badges.has("a") and out.badges.has("b"), "every unbuilt building gets a build badge")
	var ba: Control = out.badges["b"]
	ok(int(ba.get_meta("cost")) == 10 and int(ba.get_meta("min_level")) == 1, "the badge carries the next step's cost + level")
	ok(String(ba.get_meta("building_id")) == "b", "the badge remembers its building id (for the tap→buy flow)")
	var modal := Overlay.mount(parent, "HomeZoneModalTest")
	ok(modal.z_index > ba.z_index and modal.z_index > pa.z_index, \
		"shared modal overlays render above painter-sorted Home props and build badges")
	modal.queue_free()

	# --- dynamic silhouette shadows ({"shadow": true} — replaces static shadow plates) ---
	var ms := _manifest()
	(ms.buildings[0] as Dictionary)["shadow"] = true
	var parent_sh := Control.new()
	get_root().add_child(parent_sh)
	var out_sh := HZV.build(parent_sh, ms, func(_id): return "built", func(_id): return {})
	var stage2: Control = out_sh.stage
	var shadow: Control = stage2.find_child("a_shadow", true, false)
	ok(shadow != null, "a shadow-tagged prop grows its dynamic silhouette shadow node")
	var prop2: Control = out_sh.props["a"]
	ok(shadow != null and shadow.z_index == prop2.z_index \
		and shadow.get_index() < prop2.get_index(), \
		"the shadow paints beneath its own prop (same z, earlier child)")
	ok(shadow != null and shadow.position == Vector2(200, 800), \
		"the shadow sits at the prop's FOOTING (the transform lays it on the ground)")
	ok(shadow != null and shadow.get("texture") == prop2.get("texture"), \
		"the shadow stamps the prop's own sprite (no shadow art asset)")
	ok(stage2.find_child("b_shadow", true, false) == null, "untagged props stay shadow-free")
	var soft: Texture2D = load("res://engine/scripts/ui/prop_shadow.gd")._soft_silhouette(prop2.texture)
	ok(soft != null and soft.get_width() < prop2.texture.get_width(), \
		"the silhouette stamp is a downsampled copy (bilinear upscale is the blur)")

	# --- locked-plot COVERINGS (scene_coverings.gd): an "empty" plot hides under a seeded
	# scatter of scene-themed cover sprites; a mid-build or built plot carries none. ---
	var frames: Array = []
	for i in range(1, 6):
		frames.append("res://games/grove/assets/map/coverings/hollow_grass_%02d.png" % i)
	var parent_cv := Control.new()
	get_root().add_child(parent_cv)
	var out_cv := HZV.build(parent_cv, m, state_of, next_of, frames)
	ok(not out_cv.coverings.has("a") and out_cv.coverings.has("b"), \
		"only a fully locked (empty) plot grows a covering; a mid-build site carries none")
	var cover: Control = out_cv.coverings["b"]
	ok(cover.name == "cover_b" and cover.position == Vector2(400 - 50, 1200 - 100) \
		and cover.size == Vector2(100, 100), "the covering group spans the plot envelope")
	var n_sprites := cover.get_child_count()
	ok(n_sprites >= 3 and n_sprites <= 8, "the scatter lays 3-8 cover sprites (got %d)" % n_sprites)
	var textured := true
	for c in cover.get_children():
		textured = textured and (c as TextureRect) != null and (c as TextureRect).texture != null
	ok(textured, "every cover sprite loads one of the scene's covering frames")
	ok(cover.get_index() < (out_cv.badges["b"] as Control).get_index(), \
		"the covering paints beneath the plot's build badge (the buy button stays tappable)")
	# determinism: a rebuild (resize / another plot's purchase) lays the exact same scatter
	var out_cv2 := HZV.build(parent_cv, m, state_of, next_of, frames)
	var cover2: Control = out_cv2.coverings["b"]
	var same := cover2.get_child_count() == n_sprites
	for i in cover2.get_child_count():
		var s1 := cover.get_child(i) as Control
		var s2 := cover2.get_child(i) as Control
		same = same and s1 != null and s2 != null \
			and s1.position.is_equal_approx(s2.position) and s1.size.is_equal_approx(s2.size)
	ok(same, "the scatter is seeded per plot — a rebuild lays the identical covering")
	# no frames → no covering layer at all (pages without cover art keep today's rendering)
	var out_nf := HZV.build(parent_cv, m, state_of, next_of)
	ok((out_nf.coverings as Dictionary).is_empty(), "no covering frames -> no covering groups")
	# reveal(): the group is adopted by the host (so the stage rebuild can't kill the tween)
	# and every sprite starts its pop-out tween
	var host := Control.new()
	get_root().add_child(host)
	var SC = preload("res://engine/scripts/ui/scene_coverings.gd")
	SC.reveal(cover2, host)
	ok(cover2.get_parent() == host, "reveal() reparents the covering to the host before animating")
	SC.reveal(null, host)   # a page with no covering for the plot is a safe no-op
	ok(true, "reveal() on a missing covering is a no-op")
	host.queue_free()
	parent_cv.queue_free()

	# a BUILT building: no next step → no badge, and the built prop renders full-opacity
	var states2 := {"a": "built"}
	var steps2 := {"a": {}}
	var out2 := HZV.build(parent, m, \
		func(id): return String(states2.get(id, "built")), \
		func(id): return steps2.get(id, {}))
	ok(out2.props.has("a") and not out2.badges.has("a"), "a built building shows its prop with no badge")
	ok(is_equal_approx((out2.props["a"] as TextureRect).modulate.a, 1.0), "a built prop renders full opacity")

	# the SHIPPED home page manifest (Fairy Hollow, the hub) parses and carries its layered buildings
	var shipped := HZV.load_manifest("res://games/grove/assets/map/pages/zone_fairy_hollow.json")
	ok(not shipped.is_empty(), "the shipped zone_fairy_hollow.json manifest parses")
	ok((shipped.get("buildings", []) as Array).size() == 16, "the shipped manifest carries the 16 Fairy Hollow buildings")
	ok(int(shipped.canvas.width) == 1320 and int(shipped.canvas.height) == 2346, "the shipped manifest matches the page canvas")

	parent.queue_free()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
