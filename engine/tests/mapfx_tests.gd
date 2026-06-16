extends SceneTree
## Headless tests for the map-SELECT fog veil (spec §8 "the horizon — visible AND
## veiled"): a LOCKED map card sits behind fog (a teasing, not-yet-revealed scrim
## over its thumbnail); an UNLOCKED/available card does NOT. This is a PERCEPTUAL
## item, so these asserts stand in for the eye — they prove the veil node exists on
## locked cards (and NOT on open ones), carries the expected dimming/alpha, and
## IGNOREs the mouse (the single-input-surface rule the whole map relies on).
##   godot --headless --path . -s res://engine/tests/mapfx_tests.gd
## NOTE: headless dummy renderer can't capture images — that's why this logic check
## (not a screenshot) is the primary evidence. A visual capture is a bonus only.

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Map = preload("res://engine/scripts/scenes/map.gd")
const MAP_SCENE := "res://engine/scenes/Map.tscn"

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func fresh(name: String) -> void:
	var dir := "user://tu_test_mapfx_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

# First descendant named `n` (depth-first), or null.
func _find(node: Node, n: String) -> Node:
	for c in node.get_children():
		if c.name == n:
			return c
		var hit := _find(c, n)
		if hit != null:
			return hit
	return null

# The veil's flat ink haze: the first ColorRect under `veil` whose alpha is high
# enough to actually dim. Returns null if none (→ the veil isn't really dimming).
func _haze(veil: Node) -> ColorRect:
	for c in veil.get_children():
		if c is ColorRect and (c as ColorRect).color.a >= 0.2:
			return c as ColorRect
	return null

# Every Control in `node`'s subtree (inclusive) IGNOREs the mouse.
func _all_ignore(node: Node) -> bool:
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		print("    offender: %s (%s)" % [node.get_path(), node.get_class()])
		return false
	for c in node.get_children():
		if not _all_ignore(c):
			return false
	return true

func _card_for(h, z: int) -> Control:
	for hit in h.select_hits:
		if int(hit.z) == z:
			return hit.node
	return null

func _initialize() -> void:
	print("== Map FX (locked-card fog veil §8) tests ==")
	fresh("veil")

	# instantiate the real map scene and drive it into the map-SELECT view, exactly
	# as a player reaches it (atlas button → _open_select). Fresh save: map 0 open,
	# every later map locked.
	var h = load(MAP_SCENE).instantiate()
	get_root().add_child(h)
	if h.content == null:
		h._ready()
	await create_timer(0.05).timeout
	h._open_select()
	await create_timer(0.05).timeout
	ok(h._view == "select", "the map-select view is up")
	ok(h.select_hits.size() == G.MAPS.size(), "one card per map")
	ok(h.map_unlocked(0) and not h.map_unlocked(1), "fresh save: map 0 open, map 1 locked (the fixture)")

	# the locked card (z=1) wears the fog veil; the open card (z=0) does not.
	var locked: Control = _card_for(h, 1)
	var open_card: Control = _card_for(h, 0)
	ok(locked != null and open_card != null, "found a locked card and an open card")

	var open_veil := _find(open_card, Map.VEIL_NODE)
	ok(open_veil == null, "an UNLOCKED card has NO veil (it reads as available)")

	var veil := _find(locked, Map.VEIL_NODE)
	ok(veil != null, "a LOCKED card HAS the fog veil overlay node")
	if veil == null:
		_done()
		return
	ok(veil is Control, "the veil is a Control overlay")

	# it really DIMS — a flat ink haze at the tuned alpha (perceptual: not a no-op).
	var haze := _haze(veil)
	ok(haze != null, "the veil carries a dimming ink haze ColorRect")
	if haze != null:
		ok(absf(haze.color.a - Map.VEIL_SCRIM_ALPHA) < 0.001,
			"the haze alpha matches VEIL_SCRIM_ALPHA (%.2f)" % Map.VEIL_SCRIM_ALPHA)
		ok(haze.color.r == Map.VEIL_TINT.r and haze.color.g == Map.VEIL_TINT.g and haze.color.b == Map.VEIL_TINT.b,
			"the haze is tinted with VEIL_TINT (the fog colour)")

	# fog settling (the bottom-deepening gradient) + the teasing ✿ ghost are present,
	# so it reads as mist, not flat grey.
	var has_gradient := false
	for c in veil.get_children():
		if c is TextureRect and (c as TextureRect).texture is GradientTexture2D:
			has_gradient = true
	ok(has_gradient, "the veil has the bottom-deepening fog gradient (mist, not flat grey)")
	var mark := _find(veil, "VeilMark")
	ok(mark is Label and (mark as Label).text == "✿", "the veil shows the teasing ✿ ghost in the mist")
	if mark is Label:
		ok((mark as Label).get_theme_color("font_color").a <= 0.3,
			"the ✿ ghost is faint (a tease, not a label)")

	# the veil must not break the single-input-surface rule — every node IGNOREs.
	ok(_all_ignore(veil), "every veil node IGNOREs the mouse (single-input-surface safe)")

	# sweep: EVERY locked map gets a veil; NO unlocked map does. (Guards future
	# maps + the open/locked branch staying in one place.)
	var all_locked_veiled := true
	var any_open_veiled := false
	for z in G.MAPS.size():
		var card := _card_for(h, z)
		if card == null:
			continue
		var v := _find(card, Map.VEIL_NODE)
		if h.map_unlocked(z):
			if v != null:
				any_open_veiled = true
		else:
			if v == null:
				all_locked_veiled = false
	ok(all_locked_veiled, "every LOCKED map card is veiled")
	ok(not any_open_veiled, "no UNLOCKED map card is veiled")

	_done()

func _done() -> void:
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
