extends RefCounted
## Locked-plot COVERINGS (scene_coverings_v1 art drop): while a plot is still fully locked
## ("empty" — no build step bought), it hides under a scatter of scene-themed cover sprites
## (grass / ice / palm fronds / shells / petals — five variants per scene). Buying the plot's
## first step clears them with a short staggered pop-out (`reveal`). Render-only and
## deterministic: placement is seeded from the building id, so every `_build_map` rebuild
## (resize, another plot's purchase) lays the exact same scatter.

const MIN_SPRITES := 3
const MAX_SPRITES := 8
const AREA_PER_SPRITE := 36000.0   # plot px² granting one sprite past MIN (bigger plots read denser)

# Scatter cover sprites over one plot. `b` is the manifest building entry (`position` is the
# center-bottom anchor, `display_size` the plot envelope), `frames` the scene's cover art paths
# (center-anchored square sprites). Returns the plot-sized group Control (named "cover_<id>",
# children in local coords) for the caller to mount in painter order — null when `frames` is empty.
static func scatter(b: Dictionary, frames: Array) -> Control:
	if frames.is_empty():
		return null
	var id := String(b.get("id", ""))
	var anchor := _vec(b.get("position", [0, 0]))
	var disp := _vec(b.get("display_size", [100, 100]))

	var group := Control.new()
	group.name = "cover_%s" % id
	group.position = anchor - Vector2(disp.x * 0.5, disp.y)
	group.size = disp
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)               # stable per plot — rebuilds never reshuffle the scatter
	var count := clampi(MIN_SPRITES + int(disp.x * disp.y / AREA_PER_SPRITE), MIN_SPRITES, MAX_SPRITES)
	var placements: Array = []
	for i in count:
		# capped so a big plot reads as MORE tufts, never one giant screen-filling cluster
		var s := clampf(maxf(disp.x, disp.y) * rng.randf_range(0.36, 0.55), 72.0, 230.0)
		placements.append({
			"size": s,
			# centers hug the plot's GROUND band (display_size is the building's full art envelope —
			# its upper span is air, and grass/ice/shells floating at roof height reads broken).
			# The tight band also overlaps the tufts, tucking each sprite's flat bottom cut behind
			# the one in front.
			"center": Vector2(rng.randf_range(s * 0.3, disp.x - s * 0.3),
				rng.randf_range(disp.y * 0.62, disp.y * 0.92)),
			"frame": String(frames[rng.randi_range(0, frames.size() - 1)]),
			"flip": rng.randf() < 0.5,
		})
	# painter order inside the group: lower (larger y) sprites paint over higher ones
	placements.sort_custom(func(pa: Dictionary, pb: Dictionary) -> bool:
		return (pa.center as Vector2).y < (pb.center as Vector2).y)
	for p in placements:
		var spr := TextureRect.new()
		spr.texture = load(String(p.frame)) as Texture2D
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spr.flip_h = bool(p.flip)
		var s := float(p.size)
		spr.size = Vector2(s, s)
		spr.position = (p.center as Vector2) - Vector2(s, s) * 0.5   # center-anchored art
		spr.pivot_offset = Vector2(s, s) * 0.5                       # reveal() scales from the center
		group.add_child(spr)
	return group

# The unlock animation: pop each sprite out (a tiny swell, then a back-eased shrink + fade),
# staggered so the covering "clears" across the plot, then free the whole group. `host` (any
# in-tree node outside the zone stage) adopts the group first — keeping its on-screen transform —
# so the immediate `_build_map` rebuild that follows a purchase can't cut the animation short.
static func reveal(group: Control, host: Node = null) -> void:
	if group == null or not is_instance_valid(group):
		return
	if host is Node and host != group.get_parent():
		var gt := group.get_global_transform()
		group.reparent(host)
		# reparent() keeps global POSITION only; re-apply the stage's fit scale by hand
		group.global_position = gt.origin
		group.scale = gt.get_scale()
	var last: Tween = null
	var kids := group.get_children()
	for i in kids.size():
		var c := kids[i] as Control
		if c == null:
			continue
		var tw := c.create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_property(c, "scale", Vector2(1.12, 1.12), 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2.ZERO, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "modulate:a", 0.0, 0.22)
		last = tw
	if last != null:
		last.finished.connect(group.queue_free)
	else:
		group.queue_free()

static func _vec(a) -> Vector2:
	var arr: Array = a if a is Array else [0, 0]
	return Vector2(float(arr[0]) if arr.size() > 0 else 0.0, float(arr[1]) if arr.size() > 1 else 0.0)
