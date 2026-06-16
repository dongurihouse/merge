extends SceneTree
## Headless check for the §8 ghost-preview (engine/scripts/scenes/map.gd).
##   godot --headless --path . -s res://engine/tests/ghost_preview_tests.gd
## Perceptual item, asserted deterministically (no window, no image capture):
##   - the buildable ghost is gated by the Features "spot_ghost" flag,
##   - its cut-out has REDUCED alpha (it is a ghost, not the real sprite),
##   - an UNOWNED spot WITH art gets a ghost node behind its price-pin,
##   - an OWNED/built spot draws the REAL sprite and gets NO ghost.
## The ghost reuses Map's `furn_path` (Game.art("rooms/furn_<id>.png")) — the SAME
## buildable-sprite lookup the Layout editor draws from. Art only exists under the
## grove clothes, so this suite forces GAME=grove before any Game.art() call.

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

# Depth-first: the FIRST descendant of `node` carrying the "ghost" meta, or null.
func _find_ghost(node: Node) -> Node:
	if node.has_meta("ghost"):
		return node
	for c in node.get_children():
		var hit := _find_ghost(c)
		if hit != null:
			return hit
	return null

# First (z, k) whose buildable sprite actually exists on disk, else [-1, -1].
func _first_spot_with_art() -> Array:
	for z in G.MAPS.size():
		for k in G.MAPS[z].spots.size():
			var p := Game.art("rooms/furn_%s.png" % String(G.MAPS[z].spots[k].id))
			if p != "" and ResourceLoader.exists(p):
				return [z, k]
	return [-1, -1]

func _initialize() -> void:
	# Force the grove clothes so furn_*.png art exists (the engine default is the
	# art-less placeholder). Game.active() reads this env at call time.
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

	# Any real texture proves the on/off behaviour without depending on game art.
	var any_tex := "res://icon.png"
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

	# --- 3. end-to-end: UNOWNED spot gets a ghost, OWNED spot does NOT ----------
	var sa := _first_spot_with_art()
	ok(sa[0] >= 0, "found a spot with buildable art under grove (z=%d k=%d)" % [sa[0], sa[1]])
	if sa[0] >= 0:
		var z: int = sa[0]
		var k: int = sa[1]
		var sid := String(G.MAPS[z].spots[k].id)
		var lvl := 99   # high enough that the spot is buyable, not level-gated
		var rect := Rect2(Vector2.ZERO, Vector2(1000, 1000))

		# UNOWNED: nothing in unlocks -> the price-pin branch, ghost behind it.
		map.unlocks = {}
		var unowned: Control = map._make_spot(z, k, lvl, rect)
		ok(_find_ghost(unowned) != null, "UNOWNED spot '%s' renders a ghost-preview node" % sid)
		var ug := _find_ghost(unowned)
		if ug != null:
			ok(ug.modulate.a < 1.0, "UNOWNED ghost has reduced alpha (%.2f)" % ug.modulate.a)
		unowned.free()

		# OWNED: in unlocks -> the real sprite branch, NO ghost.
		map.unlocks = {sid: true}
		ok(map.spot_owned(sid), "spot_owned('%s') true once in unlocks" % sid)
		var owned: Control = map._make_spot(z, k, lvl, rect)
		ok(_find_ghost(owned) == null, "OWNED spot '%s' draws the real sprite, NO ghost" % sid)
		owned.free()

	map.queue_free()
	await process_frame

	print("== Ghost-preview: %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
