extends SceneTree
## Headless check for the §8 ghost-preview (engine/scripts/scenes/map.gd).
##   godot --headless --path . -s res://engine/tests/ghost_preview_tests.gd
## Perceptual item, asserted deterministically (no window, no image capture):
##   - the buildable ghost is gated by the Features "spot_ghost" flag,
##   - its cut-out has REDUCED alpha (it is a ghost, not the real sprite),
##   - an UNOWNED spot WITH a cutout gets a ghost node behind its price-pin,
##   - an OWNED/built spot draws the REAL sprite and gets NO ghost,
##   - an OWNED spot with NO cutout draws the code-generated placeholder tile.
## The ghost reuses Map's `art_path` (the spot's `art` cutout) — only spots that ship
## a cutout can ghost. Cutout art only exists under the grove clothes, so this suite
## forces GAME=grove before any Game.art() call.

const Features = preload("res://engine/scripts/core/features.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Game = preload("res://engine/scripts/core/game.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# Depth-first: the FIRST descendant of `node` carrying meta `key`, or null.
func _find_meta(node: Node, key: String) -> Node:
	if node.has_meta(key):
		return node
	for c in node.get_children():
		var hit := _find_meta(c, key)
		if hit != null:
			return hit
	return null

func _find_ghost(node: Node) -> Node:
	return _find_meta(node, "ghost")

# First (z, k) whose spot ships a cutout (`art`) that exists on disk, else [-1, -1].
func _first_spot_with_art() -> Array:
	for z in G.MAPS.size():
		for k in G.MAPS[z].spots.size():
			var p := String(G.MAPS[z].spots[k].get("art", ""))
			if p != "" and ResourceLoader.exists(p):
				return [z, k]
	return [-1, -1]

# First (z, k) whose spot ships NO cutout (the placeholder path), else [-1, -1].
func _first_spot_without_art() -> Array:
	for z in G.MAPS.size():
		for k in G.MAPS[z].spots.size():
			if String(G.MAPS[z].spots[k].get("art", "")) == "":
				return [z, k]
	return [-1, -1]

func _initialize() -> void:
	# Force the grove clothes so the spot cutouts (the hub's map1v2 items) resolve;
	# the engine default is the art-less placeholder. Game.active() reads this env at call time.
	OS.set_environment("GAME", "grove")
	print("== Ghost-preview (§8) tests ==  clothes=%s" % Game.id())

	var Map := load("res://engine/scripts/scenes/map.gd")

	# --- 1. flag + constant contract (art-independent) -------------------------
	ok(Features.FLAGS.has("spot_ghost"), "Features has the 'spot_ghost' flag")
	ok(Map.GHOST_ALPHA > 0.0 and Map.GHOST_ALPHA < 1.0,
		"GHOST_ALPHA is a reduced alpha in (0,1): %.2f" % Map.GHOST_ALPHA)

	# --- 2. _ghost_sprite() helper contract (uses a real, art-agnostic texture) -
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(map)
	await process_frame

	# No art path -> no ghost, regardless of flag.
	ok(map._ghost_sprite("", 200.0) == null, "no art path -> _ghost_sprite returns null")

	# Any real texture proves the on/off behaviour; a stable grove item under the
	# clothes forced above (Game.art tracks the active art root).
	var any_tex := Game.art("items/flower_1.png")
	ok(ResourceLoader.exists(any_tex), "fixture texture exists (%s)" % any_tex)

	Features.FLAGS["spot_ghost"] = false
	ok(map._ghost_sprite(any_tex, 200.0) == null, "flag OFF -> _ghost_sprite returns null (guard works)")

	Features.FLAGS["spot_ghost"] = true
	var g = map._ghost_sprite(any_tex, 200.0)
	ok(g != null, "flag ON + art -> _ghost_sprite returns a node")
	if g != null:
		ok(g is TextureRect, "ghost node is a TextureRect")
		ok(g.has_meta("ghost"), "ghost node carries the 'ghost' meta marker")
		ok(absf(g.modulate.a - Map.GHOST_ALPHA) < 0.001,
			"ghost alpha == GHOST_ALPHA (%.2f), i.e. see-through" % Map.GHOST_ALPHA)
		ok(g.modulate.a < 1.0, "ghost is more transparent than the real sprite (a<1)")
		ok(g.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ghost ignores input (single-input-surface rule)")
		g.free()

	# --- 3. end-to-end: UNOWNED spot WITH a cutout gets a ghost, OWNED does NOT --
	var rect := Rect2(Vector2.ZERO, Vector2(1000, 1000))
	var sa := _first_spot_with_art()
	ok(sa[0] >= 0, "found a spot with a cutout under grove (z=%d k=%d)" % [sa[0], sa[1]])
	if sa[0] >= 0:
		var z: int = sa[0]
		var k: int = sa[1]
		var sid := String(G.MAPS[z].spots[k].id)

		# UNOWNED: nothing in unlocks -> the price-pin branch, ghost behind it.
		map.unlocks = {}
		var unowned: Control = map._make_spot(z, k, rect)
		ok(_find_ghost(unowned) != null, "UNOWNED spot '%s' renders a ghost-preview node" % sid)
		var ug := _find_ghost(unowned)
		if ug != null:
			ok(ug.modulate.a < 1.0, "UNOWNED ghost has reduced alpha (%.2f)" % ug.modulate.a)
		unowned.free()

		# OWNED: in unlocks -> the real sprite branch, NO ghost.
		map.unlocks = {sid: true}
		ok(map.spot_owned(sid), "spot_owned('%s') true once in unlocks" % sid)
		var owned: Control = map._make_spot(z, k, rect)
		ok(_find_ghost(owned) == null, "OWNED spot '%s' draws the real sprite, NO ghost" % sid)
		owned.free()

	# --- 4. a spot with NO cutout draws the code-generated placeholder tile ------
	var sb := _first_spot_without_art()
	ok(sb[0] >= 0, "found a spot with no cutout (placeholder path) (z=%d k=%d)" % [sb[0], sb[1]])
	if sb[0] >= 0:
		var z2: int = sb[0]
		var k2: int = sb[1]
		var sid2 := String(G.MAPS[z2].spots[k2].id)
		map.unlocks = {sid2: true}
		var ph: Control = map._make_spot(z2, k2, rect)
		ok(_find_meta(ph, "placeholder") != null,
			"OWNED no-cutout spot '%s' draws a code-generated placeholder tile" % sid2)
		ok(_find_ghost(ph) == null, "placeholder spot draws no ghost")
		ph.free()

	map.queue_free()
	await process_frame

	print("== Ghost-preview: %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
