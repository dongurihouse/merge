extends SceneTree
## Headless tests for the map-SELECT place-picker cards (spec §8 "the horizon — visible AND veiled",
## now PAINTED — map_asset.png / the map.png preview). An OPEN place wears the glowing gold frame
## (ui/map/card_active.png) over its locale art + a "★ N left"/"restored" pill; a LOCKED place is the
## dark baked panel (ui/map/card_locked.png — its flower-lock medallion + scene baked in) under an
## "after <prev>" prerequisite line. These asserts stand in for the eye (a perceptual item): they
## prove the right frame is on the right card, the prerequisite/count reads are present, and every
## node IGNOREs the mouse (the single-input-surface rule the whole map relies on). The code-drawn fog
## veil survives ONLY as the fallback when the painted panel is missing (asserted last).
##   godot --headless --path . -s res://engine/tests/mapfx_tests.gd
## NOTE: the headless dummy renderer can't capture images — this logic check (not a screenshot) is
## the primary evidence; a visual capture (make shot-map MODE=select) is a bonus only.

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

# True iff any TextureRect in `node`'s subtree carries a texture whose path ends with `suffix`
# (so we can name the shipped frame by its kit file without depending on node names).
func _has_tex(node: Node, suffix: String) -> bool:
	if node is TextureRect:
		var tex := (node as TextureRect).texture
		if tex != null and String(tex.resource_path).ends_with(suffix):
			return true
	for c in node.get_children():
		if _has_tex(c, suffix):
			return true
	return false

# True iff any Label in `node`'s subtree contains `frag` (case-sensitive substring).
func _has_label(node: Node, frag: String) -> bool:
	if node is Label and frag in (node as Label).text:
		return true
	for c in node.get_children():
		if _has_label(c, frag):
			return true
	return false

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
	print("== Map FX (painted place-picker cards §8) tests ==")
	fresh("cards")

	# instantiate the real map scene and drive it into the map-SELECT view, exactly as a player
	# reaches it (atlas button → _open_select). Fresh save: map 0 open, every later map locked.
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

	var open_card: Control = _card_for(h, 0)
	var locked: Control = _card_for(h, 1)
	ok(open_card != null and locked != null, "found an open card and a locked card")
	if open_card == null or locked == null:
		_done()
		return

	# OPEN card: the glowing gold frame over its art + the restore-count pill ("N left"); no dark
	# locked panel, no fog veil (it reads as available, not veiled).
	ok(_has_tex(open_card, "card_active.png"), "an OPEN card wears the gold frame (card_active)")
	ok(_has_label(open_card, "left"), "an OPEN+incomplete card shows the 'N left' restore pill")
	ok(not _has_tex(open_card, "card_locked.png"), "an OPEN card has NO dark locked panel")
	ok(_find(open_card, Map.VEIL_NODE) == null, "an OPEN card has NO fog veil (painted art present)")

	# LOCKED card: the dark baked panel + the "after <prev>" prerequisite line; no gold frame.
	ok(_has_tex(locked, "card_locked.png"), "a LOCKED card wears the dark panel (card_locked)")
	ok(_has_label(locked, "after"), "a LOCKED card shows the 'after <prev>' prerequisite line")
	ok(not _has_tex(locked, "card_active.png"), "a LOCKED card has NO gold frame")

	# the single-input-surface rule — every node in either card IGNOREs the mouse (taps resolve on
	# `content`, never a child).
	ok(_all_ignore(open_card), "every OPEN-card node IGNOREs the mouse (single-input-surface safe)")
	ok(_all_ignore(locked), "every LOCKED-card node IGNOREs the mouse (single-input-surface safe)")

	# sweep: EVERY locked map gets the dark panel + no gold frame; EVERY open map the reverse.
	# (Guards future maps + the open/locked branch staying in one place.)
	var all_ok := true
	for z in G.MAPS.size():
		var card := _card_for(h, z)
		if card == null:
			continue
		if h.map_unlocked(z):
			if not _has_tex(card, "card_active.png") or _has_tex(card, "card_locked.png"):
				all_ok = false
		else:
			if not _has_tex(card, "card_locked.png") or _has_tex(card, "card_active.png"):
				all_ok = false
	ok(all_ok, "every map card wears the frame for its state (open=gold, locked=dark)")

	# the bottom-left BACK arrow belongs to the picker: shown in select, gone on a map.
	ok(h._select_back != null and h._select_back.visible, "the place-picker shows its back arrow")
	h._open_map(0)
	await create_timer(0.05).timeout
	ok(h._select_back != null and not h._select_back.visible, "opening a map hides the back arrow")
	# (The code-drawn §8 fog veil survives only as _dress_locked_card's fallback when card_locked.png
	# is absent; with the painted panel shipped it is correctly absent — asserted above.)

	_done()

func _done() -> void:
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
