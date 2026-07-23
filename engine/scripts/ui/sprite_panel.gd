extends RefCounted
## A non-interactive cut-paper SPRITE PANEL: one flat sprite (a card / cell / bar frame baked as a PNG)
## laid over ONE soft drop shadow (the shared Look.shadow_rect the rest of the UI uses). Returns a Control
## sized to `size`; the caller stacks its content on top (add_child). Used by the reskinned dialog cards
## and habitat cells.
##
##   var card := SpritePanel.build(load(tex), Vector2(w, h))
##   card.add_child(<content laid out with anchors over the panel>)

const Look = preload("res://engine/scripts/ui/skin.gd")

# corner radius of the soft shadow, as a fraction of the panel's short side (the cards are rounded rects).
const SHADOW_CORNER_FRAC := 0.12

# wrap()'s fallback corner, for an element that stamps no SHADOW_CORNER_META of its own.
const WRAP_CORNER := 14.0

# node names the shape smoke reads to tell the two casts apart (a rect cast behind transparent art
# is the grey-slab bug; the shape test asserts each wrapper carries the RIGHT one).
const PANEL_SHADOW := "PanelShadow"
const SPRITE_SHADOW_NAME := "SpriteShadow"

# wrap_sprite()'s silhouette ladder: f = fraction of the shared cast this copy steps out,
# a = fraction of the shared alpha it carries. Three copies overlap into one soft gradient.
const SPRITE_SHADOW := [
	{"f": 0.34, "a": 0.8},
	{"f": 0.67, "a": 0.6},
	{"f": 1.0, "a": 0.4},
]

static func build(tex: Texture2D, size: Vector2, opts: Dictionary = {}) -> Control:
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bool(opts.get("shadow", true)):
		# ONE soft blurred shadow (the game's shared cast), not a stack of offset silhouette copies — those
		# stepped visibly on tall cards. The shadow's filled footprint sits behind (and is hidden by) the
		# sprite; only its feathered, downward-offset edge shows. Inset a hair so its fill never rings the
		# torn sprite edge.
		var short := minf(size.x, size.y)
		var sh := Look.shadow_rect(short * SHADOW_CORNER_FRAC, {})
		var inset := short * 0.03
		sh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sh.offset_left = inset
		sh.offset_top = inset
		sh.offset_right = -inset
		sh.offset_bottom = -inset
		root.add_child(sh)
	root.add_child(_layer(tex))
	return root

## Wrap an EXISTING textured Control (a StyleBoxTexture card / button) with ONE soft drop shadow — the same
## shared blurred cast build() uses — sitting behind `inner`, which then fills the wrapper. Auto-sizes to
## inner's content (so an auto-height card still casts a matching shadow) and copies inner's size flags;
## clicks pass through to inner. Lets the shop cards/buttons gain the cut-paper shadow without restructuring
## their content.
static func wrap(inner: Control, _tex: Texture2D) -> Control:
	var root := _wrap_root(inner)
	# ONE soft blurred shadow (matching build), not stacked silhouette copies — those stepped visibly on
	# tall cards. Anchored full-rect so it tracks the wrapper; the drop comes from the SAVED block's
	# offset, never a hand-added nudge — a nudge slides the shadow's HARD filled body out from under the
	# card as a grey slab, which is exactly what shadow_params()'s spread clamp exists to prevent.
	var sh := Look.shadow_rect(Look.shape_corner(inner, WRAP_CORNER), Look.saved_shadow_params())
	sh.name = PANEL_SHADOW
	sh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sh)
	_fill(root, inner)
	return root

## Wrap a bare SPRITE (art that does NOT fill its box) with a SHAPE-TRUE shadow: dark copies of the
## sprite's own silhouette, stepped out along the shared cast and fading as they go (the ladder
## SpriteButton and the wallet pills use, here derived from the saved block so all three stay in step).
## wrap()'s rounded-rect cast is wrong for transparent art — it paints a grey slab around the sprite
## instead of a shadow under it.
static func wrap_sprite(inner: Control, tex: Texture2D) -> Control:
	var root := _wrap_root(inner)
	var p := Look.saved_shadow_params()
	var drop := Vector2(float(p.offset_x), float(p.offset_y))
	if tex != null and drop.length() > 0.0:
		for step in SPRITE_SHADOW:
			root.add_child(_silhouette(inner, tex,
				Look.shadow_color(float(p.alpha) * float(step["a"])), drop * float(step["f"])))
	_fill(root, inner)
	return root

# The wrapper shell both paths share: mouse-transparent, inheriting inner's size flags.
static func _wrap_root(inner: Control) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size_flags_horizontal = inner.size_flags_horizontal
	root.size_flags_vertical = inner.size_flags_vertical
	return root

# Lay `inner` over the shadow already in `root` and keep the wrapper sized to inner's content, so an
# auto-height card still casts a matching shadow. Clicks pass through the wrapper to inner.
static func _fill(root: Control, inner: Control) -> void:
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(inner)
	var sync := func() -> void:
		if is_instance_valid(root) and is_instance_valid(inner):
			root.custom_minimum_size = inner.get_combined_minimum_size()
	sync.call()
	inner.minimum_size_changed.connect(sync)

# ONE dark copy of the sprite, dropped by `drop`. Duplicating inner (rather than building a fresh
# TextureRect) carries its expand/stretch mode over, so an aspect-centred icon's shadow lands exactly
# under the art instead of under its larger box.
static func _silhouette(inner: Control, tex: Texture2D, tint: Color, drop: Vector2) -> Control:
	var copy: Control = (inner.duplicate() as Control) if inner is TextureRect else _layer(tex)
	copy.name = SPRITE_SHADOW_NAME
	copy.modulate = tint
	copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	copy.offset_left += drop.x
	copy.offset_right += drop.x
	copy.offset_top += drop.y
	copy.offset_bottom += drop.y
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return copy

static func _layer(tex: Texture2D) -> TextureRect:
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # BEFORE anchors, so native px never drives min size
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture = tex
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.custom_minimum_size = Vector2.ZERO
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## A cut-paper PROGRESS BAR from two sprites: the hollow track, with the green fill revealed left-to-right
## to `frac` (0..1). Returns a Control sized to `size`; mouse-transparent.
static func progress(track_tex: Texture2D, fill_tex: Texture2D, frac: float, size: Vector2) -> Control:
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := TextureRect.new()
	track.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	track.stretch_mode = TextureRect.STRETCH_SCALE
	track.texture = track_tex
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.custom_minimum_size = Vector2.ZERO
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(track)
	# the fill is drawn at FULL bar size inside a left-anchored clip whose width = frac, so the fill's
	# rounded left cap stays put and only its right end is revealed/hidden.
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = Vector2.ZERO
	clip.size = Vector2(size.x * clampf(frac, 0.0, 1.0), size.y)
	root.add_child(clip)
	var fill := TextureRect.new()
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	fill.texture = fill_tex
	fill.position = Vector2.ZERO
	fill.size = size
	fill.custom_minimum_size = Vector2.ZERO
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(fill)
	return root
