extends "res://games/grove/tests/grove_test_base.gd"
## grove · ladder — the tier screen's GENERATOR-ICON header (base lines) and the MERGED-LINE
## recipe view: the two ingredient items + the merged line's OWN tier ladder below, each ingredient
## tapping through to its OWN tier screen.

func _initialize() -> void:
	begin("grove · ladder")
	fresh("ladder")
	var b = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(b)
	if b.board == null:
		b._ready()

	# --- header descriptor: a base line → its generator; a merged line → its 2-ingredient recipe ---
	var hbase: Dictionary = b._ladder_header(1)
	ok(String(hbase.get("kind", "")) == "generator" and String(hbase.get("gid", "")) == "gen_1", \
		"a base line's header descriptor is its generator (gen_1)")
	var hmerged: Dictionary = b._ladder_header(5)
	ok(String(hmerged.get("kind", "")) == "recipe" and Array(hmerged.get("lines", [])) == [2, 3], \
		"a merged line's header descriptor is the 2-ingredient recipe [2,3]")

	# --- routing: a base line opens the tier grid (carrying its generator); a merged line the recipe view ---
	# one frame first: the ladder sizes itself from the live viewport at open, and before the window's
	# first layout pass that reads as 0-wide — the geometry asserts below need the real-width dialog.
	await process_frame
	b._open_ladder(1, 1)
	var ov_base: Node = _ladder_overlay(b)
	ok(ov_base != null and String(ov_base.get_meta("ladder_kind", "")) == "tiers", \
		"a base line opens the tier-grid screen")
	ok(String(ov_base.get_meta("header_gid", "")) == "gen_1", \
		"the base tier screen carries its generator icon (gen_1)")

	# GEOMETRY: no tier cell may be sliced by the frame's clip — the right column used to poke a
	# few px past the scroll edge (the grid's initial width math ignored content_scale on the pads).
	# The grid's deferred fit() → resize → refit cascade needs a few frames beyond the usual 0.1s.
	await create_timer(0.25).timeout
	if ov_base != null:
		var cell_bgs: Array = ov_base.find_children("SlotCellBackground", "", true, false)
		ok(cell_bgs.size() > 0, "the tier grid built its slot cells")
		for cb in cell_bgs:
			var tile := (cb as Control).get_parent() as Control
			if not assert_unclipped(tile, "h", 0.5, "tier cell tile"):
				break

	b._open_ladder(5, 3)
	await create_timer(0.1).timeout   # let the prior base-line grid's deferred queue_free settle before counting cells
	var ov_rec: Node = _ladder_overlay(b)
	ok(ov_rec != null and String(ov_rec.get_meta("ladder_kind", "")) == "recipe", \
		"a merged line opens the recipe view")
	ok(Array(ov_rec.get_meta("recipe_lines", [])) == [2, 3], \
		"the recipe view shows the two ingredient lines [2,3]")
	ok(_ingredient_count(ov_rec) == 2, "the recipe view shows exactly the two ingredient items")
	ok(_ingredient_code(ov_rec, 2) == 203 and _ingredient_code(ov_rec, 3) == 303, \
		"the recipe view shows the actual tier-3 ingredient items required for this merge")
	# the recipe view ALSO carries the merged line's OWN tier ladder below the two ingredients
	# (the same shared tier grid the base-line screen uses), so the merged line's progression reads here too.
	var merged_tiers: int = b._ladder_entries(5).size()
	ok(merged_tiers > 0 and _tier_cell_count(ov_rec) == merged_tiers, \
		"the recipe view also shows the merged line's full tier ladder (%d cells)" % merged_tiers)

	# --- navigation: tapping an ingredient REPLACES the modal with THAT line's tier screen ---
	var ing: Button = _ingredient(ov_rec, 2)
	ok(ing != null, "the recipe view has a tappable node for ingredient line 2 (Wild Berries)")
	if ing != null:
		ing.pressed.emit()
		await create_timer(0.1).timeout
		var ov_nav: Node = _ladder_overlay(b)
		ok(ov_nav != null and String(ov_nav.get_meta("ladder_kind", "")) == "tiers" \
			and String(ov_nav.get_meta("header_gid", "")) == "gen_2", \
			"tapping ingredient Wild Berries opens its OWN tier screen (gen_2)")
		ok(ov_nav != null and int(ov_nav.get_meta("mark_tier", 0)) == 3, \
			"tapping a tier-3 ingredient keeps that tier marked on its own screen")
		ok(_count_ladder_overlays(b) == 1, "navigation REPLACES — only ever one ladder modal open")

	b.queue_free()
	finish()

# the single live ladder overlay mounted on the board (mount name is "LadderOverlay")
func _ladder_overlay(b: Node) -> Node:
	for c in b.get_children():
		if c is Control and String(c.name).begins_with("LadderOverlay") and not (c as Node).is_queued_for_deletion():
			return c
	return null

func _count_ladder_overlays(b: Node) -> int:
	var n := 0
	for c in b.get_children():
		if c is Control and String(c.name).begins_with("LadderOverlay") and not (c as Node).is_queued_for_deletion():
			n += 1
	return n

# a tappable ingredient button (meta-tagged ingredient_line) inside the recipe overlay
func _ingredient(overlay: Node, line: int) -> Button:
	for btn in (overlay as Control).find_children("*", "Button", true, false):
		if btn.has_meta("ingredient_line") and int(btn.get_meta("ingredient_line")) == line:
			return btn
	return null

func _ingredient_count(overlay: Node) -> int:
	var n := 0
	for btn in (overlay as Control).find_children("*", "Button", true, false):
		if btn.has_meta("ingredient_line"):
			n += 1
	return n

func _ingredient_code(overlay: Node, line: int) -> int:
	var btn := _ingredient(overlay, line)
	return int(btn.get_meta("ingredient_code", 0)) if btn != null else 0

# count the tier cells rendered in the overlay — each discovery cell carries a "TierNumber" label
func _tier_cell_count(overlay: Node) -> int:
	return (overlay as Control).find_children("TierNumber", "Label", true, false).size()
