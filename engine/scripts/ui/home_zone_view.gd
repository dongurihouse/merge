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

# Parse a zone manifest JSON into a Dictionary ({} on any parse failure).
static func load_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

# Build the zone into `parent` (cleared first). `state_of` and `next_step_of` are Callables keyed by
# building id. Returns {stage, base, props, badges} — `stage` is the canvas-sized Control the props
# sit in (the caller fits/positions it), `props`/`badges` are id→node maps for later state refresh.
static func build(parent: Control, manifest: Dictionary, state_of: Callable, next_step_of: Callable) -> Dictionary:
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
	for entry_v in manifest.get("buildings", []):
		if not entry_v is Dictionary:
			continue
		var b: Dictionary = entry_v
		var id := String(b.get("id", ""))
		var anchor := _vec(b.get("position", [0, 0]))
		var disp := _vec(b.get("display_size", [100, 100]))
		var sort_y := int(b.get("sort_y", anchor.y))

		var state := String(state_of.call(id))
		var tex_path := _state_texture(b, state)
		if tex_path != "":
			var prop := TextureRect.new()
			prop.name = id
			prop.texture = load(tex_path) as Texture2D
			# {"shadow": true} → a DYNAMIC ground shadow stamped from the prop's own silhouette
			# (prop_shadow.gd), added first at the same z so it paints beneath its prop.
			if bool(b.get("shadow", false)) and prop.texture != null:
				var shadow: Control = PropShadow.new()
				shadow.name = id + "_shadow"
				shadow.texture = prop.texture
				shadow.disp = disp
				shadow.position = anchor
				shadow.z_index = sort_y
				stage.add_child(shadow)
			prop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			prop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			prop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
			prop.size = disp
			prop.position = anchor - Vector2(disp.x * 0.5, disp.y)
			prop.z_index = sort_y
			# an unfinished SITE reads dimmer than the finished building (placeholder until the
			# pipeline ships true site art — PROVISIONAL, spec §8).
			if state == "site":
				prop.modulate = Color(1, 1, 1, 0.75)
			stage.add_child(prop)
			props[id] = prop

		# a build badge sits at the plot centre for every UNBUILT building (next_step non-empty).
		var step: Dictionary = next_step_of.call(id)
		if not step.is_empty():
			var badge := _build_badge(id, int(step.get("cost", 0)), int(step.get("min_level", 1)))
			badge.position = anchor - badge.size * 0.5
			badge.z_index = sort_y + 1
			stage.add_child(badge)
			badges[id] = badge

	return {"stage": stage, "base": base, "props": props, "badges": badges, "canvas": native}

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
