extends "res://games/grove/tests/grove_test_base.gd"
## grove · ladder — the tier screen's GENERATOR-ICON header (base lines) and the MERGED-LINE
## recipe view: two ingredient items alone, each tapping through to its OWN tier screen.

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
	var hmerged: Dictionary = b._ladder_header(71)
	ok(String(hmerged.get("kind", "")) == "recipe" and Array(hmerged.get("lines", [])) == [1, 2], \
		"a merged line's header descriptor is the 2-ingredient recipe [1,2]")

	# --- routing: a base line opens the tier grid (carrying its generator); a merged line the recipe view ---
	b._open_ladder(1, 1)
	var ov_base: Node = _ladder_overlay(b)
	ok(ov_base != null and String(ov_base.get_meta("ladder_kind", "")) == "tiers", \
		"a base line opens the tier-grid screen")
	ok(String(ov_base.get_meta("header_gid", "")) == "gen_1", \
		"the base tier screen carries its generator icon (gen_1)")

	b._open_ladder(71, 1)
	var ov_rec: Node = _ladder_overlay(b)
	ok(ov_rec != null and String(ov_rec.get_meta("ladder_kind", "")) == "recipe", \
		"a merged line opens the recipe view (no tier grid)")
	ok(Array(ov_rec.get_meta("recipe_lines", [])) == [1, 2], \
		"the recipe view shows the two ingredient lines [1,2]")
	ok(_ingredient_count(ov_rec) == 2, "the recipe view shows exactly the two ingredient items")

	# --- navigation: tapping an ingredient REPLACES the modal with THAT line's tier screen ---
	var ing: Button = _ingredient(ov_rec, 1)
	ok(ing != null, "the recipe view has a tappable node for ingredient line 1 (Wildflower)")
	if ing != null:
		ing.pressed.emit()
		await create_timer(0.1).timeout
		var ov_nav: Node = _ladder_overlay(b)
		ok(ov_nav != null and String(ov_nav.get_meta("ladder_kind", "")) == "tiers" \
			and String(ov_nav.get_meta("header_gid", "")) == "gen_1", \
			"tapping ingredient Wildflower opens its OWN tier screen (gen_1)")
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
