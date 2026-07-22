extends RefCounted
## The layered HOME zone renderer (home build-and-upgrade redesign, spec 2026-07-17).
## Render-only: given a zone MANIFEST (foundation + buildings, the cut-paper pipeline output) and a
## STATE resolver (home.gd: which art state each building shows), it builds the node tree the Home
## scene mounts — a foundation TextureRect plus one center-bottom-anchored, painter-sorted prop per
## building, with a coin/level build BADGE over each unbuilt plot. No Save/scene deps beyond the two
## injected callables, so the whole tree is headless-testable (home_zone_view_tests.gd).
##
## Deps are INJECTED, not preloaded: `state_of(id) -> String` (the current art state id) and
## `next_step_of(id) -> Dictionary` ({} when built; else {cost, min_level, shows}). The scene passes
## Home.state_id / Home.next_step; a test passes stubs.

const PropShadow = preload("res://engine/scripts/ui/prop_shadow.gd")
const SpriteShadow = preload("res://engine/scripts/ui/sprite_shadow.gd")
const COVERUP_SHADOW_ALPHA := 0.58   # scene canopy contact-shadow depth — a strong crisp cut-paper contact shadow so the locked leaves clearly lift off the dark foliage
const Look = preload("res://engine/scripts/ui/skin.gd")
const Coverings = preload("res://engine/scripts/ui/scene_coverings.gd")
const LockBadge = preload("res://engine/scripts/ui/lock_badge.gd")

# Parse a zone manifest JSON into a Dictionary ({} on any parse failure).
static func load_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

# Build the zone into `parent` (cleared first). `state_of` and `next_step_of` are Callables keyed by
# building id. Returns {stage, base, props, badges, coverings} — `stage` is the canvas-sized Control
# the props sit in (the caller fits/positions it), `props`/`badges`/`coverings` are id→node maps for
# later state refresh. `covering_frames` (the scene's themed cover art, scene_coverings.gd) scatters
# a seeded cover over every still-locked ("empty") plot; empty list → no coverings.
static func build(parent: Control, manifest: Dictionary, state_of: Callable, next_step_of: Callable,
		covering_frames: Array = [], coverup_mode: bool = false, cluster_locked: Callable = Callable()) -> Dictionary:
	for c in parent.get_children():
		c.queue_free()
	var canvas: Dictionary = manifest.get("canvas", {})
	var native := Vector2(float(canvas.get("width", 941)), float(canvas.get("height", 1672)))

	var stage := Control.new()
	stage.name = "ZoneStage"
	stage.size = native
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(stage)

	var base := TextureRect.new()
	base.name = "ZoneBase"
	base.texture = load(String(manifest.get("background", ""))) as Texture2D
	base.size = native
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(base)

	var props := {}
	var badges := {}
	var coverings := {}
	# Painter order is sort_y (ties: manifest order) realized as CHILD ORDER at z 0 — never as
	# z_index. Raw sort_y used to be stamped into z_index, and the tall page canvases pushed it
	# past every chrome band (HUD side 30 / wallet 40, nav, even the 2048 modal layer), so the
	# scene art painted OVER the buttons. The whole zone staying at z 0 keeps every button and
	# overlay band above it by construction.
	var entries: Array = []
	for entry_v in manifest.get("buildings", []):
		if entry_v is Dictionary:
			entries.append(entry_v)
	var order: Array = range(entries.size())
	order.sort_custom(func(ia: int, ib: int) -> bool:
		var ea: Dictionary = entries[ia]
		var eb: Dictionary = entries[ib]
		var sa := int(ea.get("sort_y", _vec(ea.get("position", [0, 0])).y))
		var sb := int(eb.get("sort_y", _vec(eb.get("position", [0, 0])).y))
		return sa < sb if sa != sb else ia < ib)   # index tiebreak keeps the sort stable
	var pending_badges: Array = []
	for i in order:
		var b: Dictionary = entries[i]
		var id := String(b.get("id", ""))
		var anchor := _vec(b.get("position", [0, 0]))
		var disp := _vec(b.get("display_size", [100, 100]))

		var state := "built" if coverup_mode else String(state_of.call(id))
		var tex_path := _state_texture(b, state)
		if tex_path != "":
			var prop := TextureRect.new()
			prop.name = id
			prop.texture = load(tex_path) as Texture2D
			# {"shadow": true} → a DYNAMIC ground shadow stamped from the prop's own silhouette
			# (prop_shadow.gd), added just before its prop so it paints beneath it.
			if bool(b.get("shadow", false)) and prop.texture != null:
				var shadow: Control = PropShadow.new()
				shadow.name = id + "_shadow"
				shadow.texture = prop.texture
				shadow.disp = disp
				shadow.position = anchor
				stage.add_child(shadow)
			prop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			prop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			prop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
			prop.size = disp
			prop.position = anchor - Vector2(disp.x * 0.5, disp.y)
			# an unfinished SITE reads dimmer than the finished building (placeholder until the
			# pipeline ships true site art — PROVISIONAL, spec §8).
			if state == "site":
				prop.modulate = Color(1, 1, 1, 0.75)
			stage.add_child(prop)
			props[id] = prop

		# NON-coverup pages: a build badge at the plot centre for every UNBUILT building, and a
		# scene-themed covering scatter over a fully LOCKED (empty) plot (revealed on first buy).
		# Coverup pages skip both — the props render always-built and the authored canopy layer
		# (mounted below) is what hides each cluster.
		if not coverup_mode:
			var step: Dictionary = next_step_of.call(id)
			if not step.is_empty():
				var badge := _build_badge(id, int(step.get("cost", 0)), int(step.get("min_level", 1)))
				badge.position = anchor - badge.size * 0.5
				pending_badges.append(badge)
				badges[id] = badge
			if state == "empty" and not step.is_empty():
				var cover := Coverings.scatter(b, covering_frames)
				if cover != null:
					stage.add_child(cover)
					coverings[id] = cover
	# the badges are BUTTONS — mounted after every prop so no scenery ever paints over them.
	for badge_node in pending_badges:
		stage.add_child(badge_node)

	if coverup_mode:
		_mount_coverups(stage, manifest, cluster_locked, coverings, badges)

	return {"stage": stage, "base": base, "props": props, "badges": badges,
		"coverings": coverings, "canvas": native}

# Coverup pages: the scene's authored `coverups` (per-cluster canopy sprites, cluster == the unlock
# region id) mount frontmost, one group Control per STILL-LOCKED cluster (`cover_<cluster>`), plus a
# LockBadge centred over the cluster's structure. `coverings[cluster]` holds the group (revealed away
# on unlock); `badges[cluster]` holds the lock badge (the map's tap target). Sprites paint in sort_y.
static func _mount_coverups(stage: Control, manifest: Dictionary, cluster_locked: Callable,
		coverings: Dictionary, badges: Dictionary) -> void:
	var groups := {}             # cluster id -> {group: Control, sprites: [{sort_y, node}], bbox: Rect2}
	for cov_v in manifest.get("coverups", []):
		var cov: Dictionary = cov_v
		var cl := String(cov.get("cluster", ""))
		if not (cluster_locked.is_valid() and bool(cluster_locked.call(cl))):
			continue
		var ca := _vec(cov.get("position", [0, 0]))
		var cd := _vec(cov.get("display_size", [100, 100]))
		# this sprite's center-bottom-anchored footprint, used both to lay out the sprite AND to
		# fold into the cluster's own bounding box (the lock badge centres on THAT, not a structure).
		var rect := Rect2(ca - Vector2(cd.x * 0.5, cd.y), cd)
		if not groups.has(cl):
			var grp := Control.new()
			grp.name = "cover_%s" % cl
			grp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			groups[cl] = {"group": grp, "sprites": [], "bbox": rect}
		else:
			groups[cl]["bbox"] = (groups[cl]["bbox"] as Rect2).merge(rect)
		var spr := TextureRect.new()
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spr.size = cd
		spr.position = rect.position                      # center-bottom anchor, like props
		spr.pivot_offset = cd * 0.5                        # reveal() scales from the centre
		if String(cov.get("image", "")) != "" and ResourceLoader.exists(String(cov.image)):
			spr.texture = load(String(cov.image)) as Texture2D
			# a FLAT shape-true drop shadow stamped from the canopy leaf's OWN silhouette (SpriteShadow),
			# so each covering lifts off the scene the way every baked cut-paper layer around it does.
			# A SCENE shadow (like PropShadow), not UI chrome: its own scene alpha + a cast proportional
			# to the leaf's size (a fixed px offset vanishes under art this large), soft-blurred, behind
			# the sprite. Slate tint keeps it in the same shadow family as the UI.
			var csh := SpriteShadow.new()
			csh.texture = spr.texture
			csh.draw_size = cd
			csh.fit = true
			csh.offset = Vector2(cd.x * 0.02, cd.y * 0.05)
			csh.tint = Look.shadow_color(COVERUP_SHADOW_ALPHA)
			csh.soft_div = 2
			csh.show_behind_parent = true
			spr.add_child(csh)
		(groups[cl]["sprites"] as Array).append({"sort_y": int(cov.get("sort_y", 0)), "node": spr})
	for cl in groups.keys():
		var g: Dictionary = groups[cl]
		var sprites: Array = g.sprites
		sprites.sort_custom(func(a, b2): return int(a.sort_y) < int(b2.sort_y))
		for s in sprites:
			(g.group as Control).add_child(s.node)
		stage.add_child(g.group)                          # frontmost (added after every prop)
		coverings[cl] = g.group
	# a SECOND pass mounts every lock badge ON TOP of every canopy group — otherwise a later
	# cluster's canopy would paint over an earlier cluster's lock icon. Anchored on the CLUSTER'S
	# OWN canopy bbox centre (not a matching structure's anchor) — this decouples the lock from any
	# structure-cluster naming, which winter/desert's coverup clusters don't share with a building.
	for cl in groups.keys():
		var lb: Control = LockBadge.make(cl)
		var bbox: Rect2 = (groups[cl] as Dictionary).bbox
		lb.position = bbox.get_center() - lb.size * 0.5
		stage.add_child(lb)
		badges[cl] = lb

# The art path for a building's current state: its states map, falling back to "built" then "".
static func _state_texture(b: Dictionary, state: String) -> String:
	var states: Dictionary = b.get("states", {})
	if states.has(state):
		return String(states[state])
	if state == "empty":
		return ""                              # a bare plot has no prop
	return String(states.get("built", ""))

# A minimal build badge: a coin cost + a level requirement, in a named Control the scene styles/skins.
# Kept plain here so the renderer stays scene-agnostic; the scene can restyle via Kit if it wants.
static func _build_badge(id: String, cost: int, min_level: int) -> Control:
	var badge := Control.new()
	badge.name = "build_%s" % id
	badge.custom_minimum_size = Vector2(120, 64)
	badge.size = Vector2(120, 64)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_meta("building_id", id)
	badge.set_meta("cost", cost)
	badge.set_meta("min_level", min_level)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	badge.add_child(box)
	var cost_lbl := Label.new()
	cost_lbl.name = "Cost"
	# no emoji glyph (the game font lacks 🪙 — it renders as a blob); the scene can skin a coin
	# icon over this via the "Cost" node. Plain number keeps the renderer scene-agnostic.
	cost_lbl.text = "%d" % cost
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(cost_lbl)
	var lvl_lbl := Label.new()
	lvl_lbl.name = "Level"
	lvl_lbl.text = "Lv %d" % min_level
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lvl_lbl)
	return badge

static func _vec(a) -> Vector2:
	var arr: Array = a if a is Array else [0, 0]
	return Vector2(float(arr[0]) if arr.size() > 0 else 0.0, float(arr[1]) if arr.size() > 1 else 0.0)
