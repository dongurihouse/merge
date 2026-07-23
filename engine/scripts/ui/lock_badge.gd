extends RefCounted
## The market cover-up PADLOCK badge (fairy_hollow_market cluster unlocks). A covered cluster wears
## one of these. Both states paint at FULL opacity with a drop shadow so the icon reads clearly on the
## busy canopy: LOCKED is a plain cool padlock; READY is a bright gold padlock on a warm glow disc that
## gently pulses, so the one unlockable cluster pops. Tapping a READY badge routes through map.gd, which
## claims the cluster (spends the cost, records the unlock) and reveals its canopy away.

const Game = preload("res://engine/scripts/core/game.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")   # gen_halo_tex — the shared radial bloom

const PAD_PX := 168.0     # the padlock glyph — big enough to read as a tappable target on the map
const BOX := 216.0        # the badge box (room for the glow + shadow around the pad)
const SHADOW_OFFSET := Vector2(7.0, 14.0)

static func make(id: String) -> Control:
	var badge := Control.new()
	badge.name = "lock_%s" % id
	badge.custom_minimum_size = Vector2(BOX, BOX)
	badge.size = Vector2(BOX, BOX)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_meta("building_id", id)
	var pad_pos := Vector2(BOX - PAD_PX, BOX - PAD_PX) * 0.5
	var tex := _padlock_tex()
	# drop shadow — a black silhouette of the padlock, offset down-right, behind everything.
	var shadow := TextureRect.new()
	shadow.name = "Shadow"
	_config_sprite(shadow)
	shadow.size = Vector2(PAD_PX, PAD_PX)
	shadow.position = pad_pos + SHADOW_OFFSET
	shadow.texture = tex
	shadow.modulate = Color(0, 0, 0, 0.38)
	badge.add_child(shadow)
	# the padlock glyph itself.
	var pad := TextureRect.new()
	pad.name = "Pad"
	_config_sprite(pad)
	pad.size = Vector2(PAD_PX, PAD_PX)
	pad.position = pad_pos
	pad.pivot_offset = Vector2(PAD_PX, PAD_PX) * 0.5   # pulse scales from the centre
	pad.texture = tex
	badge.add_child(pad)
	set_ready(badge, false)
	return badge

# LOCKED: full-opacity cool padlock, no glow. READY: bright gold padlock on a warm glow disc that
# gently pulses. Idempotent — safe to call every rebuild.
static func set_ready(badge: Control, ready: bool) -> void:
	if badge == null or not is_instance_valid(badge):
		return
	var pad := badge.get_node_or_null("Pad") as TextureRect
	var shadow := badge.get_node_or_null("Shadow") as TextureRect
	if pad != null:
		# both states are FULL opacity; ready reads warm-bright, locked reads a cool slate.
		pad.modulate = Color(1.0, 0.95, 0.72, 1.0) if ready else Color(0.78, 0.82, 0.88, 1.0)
	if shadow != null:
		shadow.modulate = Color(0, 0, 0, 0.4 if ready else 0.32)
	var glow := badge.get_node_or_null("Glow") as TextureRect
	if ready and glow == null:
		# a REAL halo — the shared radial bloom (PieceView.gen_halo_tex: alpha fades to 0 at the rim),
		# not a flat rounded disc (a StyleBox circle read as a solid yellow background behind the lock).
		glow = TextureRect.new()
		glow.name = "Glow"
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE     # before size — the min-size cache clamps otherwise
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		glow.texture = PieceView.gen_halo_tex()
		glow.size = Vector2(BOX, BOX) * 1.35                  # the aura spills past the badge box, fading out
		glow.position = (Vector2(BOX, BOX) - glow.size) * 0.5
		glow.pivot_offset = glow.size * 0.5                   # breathe scales from the centre, like the pad
		glow.modulate = Color(1.0, 0.86, 0.36, 0.8)           # warm "unlockable" gold, shaped by the bloom's falloff
		badge.add_child(glow)
		badge.move_child(glow, 0)                             # behind shadow + pad
		_pulse(pad, glow)
	elif not ready and glow != null:
		glow.queue_free()

# The READY pulse: the pad swells and settles, and the halo BREATHES WITH IT — one tween drives both
# (same phase, same period), the halo swelling a touch wider and brightening at the peak so the light
# reads as coming from the lock.
static func _pulse(pad: Control, glow: Control = null) -> void:
	if pad == null or not pad.is_inside_tree():
		return                                              # tween needs the node in the tree
	var tw := pad.create_tween().set_loops()
	tw.tween_property(pad, "scale", Vector2(1.09, 1.09), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if glow != null:
		tw.parallel().tween_property(glow, "scale", Vector2(1.14, 1.14), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(glow, "modulate:a", 0.95, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_property(pad, "scale", Vector2(1.0, 1.0), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if glow != null:
		tw.parallel().tween_property(glow, "scale", Vector2(1.0, 1.0), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(glow, "modulate:a", 0.66, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

static func _config_sprite(t: TextureRect) -> void:
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE          # set BEFORE size (min-size cache clamp)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE

static func _padlock_tex() -> Texture2D:
	# the map-card keyhole (ui/card/lock.png) — THE house lock, same mark as the locked cells + map cards
	var p := "res://games/grove/assets/ui/card/lock.png"
	if not ResourceLoader.exists(p):
		p = Game.art("ui/meadow_v2/icon_padlock.png")
	return load(p) as Texture2D if ResourceLoader.exists(p) else null
