extends RefCounted
## The market cover-up PADLOCK badge (fairy_hollow_market cluster unlocks). A covered cluster wears
## one of these: LOCKED reads as a dim padlock; READY brightens it and adds a warm code-drawn glow
## disc so it reads as tappable. Tapping a READY badge routes through map.gd, which claims the cluster
## (deducts cost, records the unlock) and reveals its canopy away. Render-only + stateless: map.gd
## owns which cluster is ready.

const PAD_PX := 96.0
const BOX := 120.0

static func make(id: String) -> Control:
	var badge := Control.new()
	badge.name = "lock_%s" % id
	badge.custom_minimum_size = Vector2(BOX, BOX)
	badge.size = Vector2(BOX, BOX)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_meta("building_id", id)
	var pad := TextureRect.new()
	pad.name = "Pad"
	pad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE      # set BEFORE size (min-size cache clamp)
	pad.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pad.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.size = Vector2(PAD_PX, PAD_PX)
	pad.position = Vector2(BOX - PAD_PX, BOX - PAD_PX) * 0.5
	var pad_path := Game.art("ui/meadow_v2/icon_padlock.png")
	if ResourceLoader.exists(pad_path):
		pad.texture = load(pad_path) as Texture2D
	badge.add_child(pad)
	set_ready(badge, false)
	return badge

# LOCKED: dim the pad, no glow. READY: full-bright pad + a warm rounded glow disc behind it.
# Idempotent — safe to call every rebuild.
static func set_ready(badge: Control, ready: bool) -> void:
	if badge == null or not is_instance_valid(badge):
		return
	var pad := badge.get_node_or_null("Pad") as TextureRect
	if pad != null:
		pad.modulate = Color(1, 1, 1, 1.0) if ready else Color(1, 1, 1, 0.55)
	var glow := badge.get_node_or_null("Glow") as Panel
	if ready and glow == null:
		glow = Panel.new()
		glow.name = "Glow"
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.size = Vector2(BOX, BOX) * 1.2
		glow.position = -(glow.size - Vector2(BOX, BOX)) * 0.5
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.9, 0.45, 0.5)          # warm "unlockable" halo
		sb.set_corner_radius_all(int(glow.size.x * 0.5))  # a soft disc
		glow.add_theme_stylebox_override("panel", sb)
		badge.add_child(glow)
		badge.move_child(glow, 0)                         # glow paints behind the pad
	elif not ready and glow != null:
		glow.queue_free()
