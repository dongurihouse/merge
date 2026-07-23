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

# node names the shape smoke reads to tell the casts apart (a rounded-RECT cast behind cut-paper art
# rings it with a grey halo; the shape test asserts each wrapper carries a silhouette cast instead).
const CARD_SHADOW := "CardShadow"       # a copy of the element's own StyleBoxTexture face
const SPRITE_SHADOW := "SpriteShadow"   # a copy of a bare sprite's own texture
const PANEL_SHADOW := "PanelShadow"     # the rounded-rect fallback, for a code-drawn element

const LADDER_MIN := 3                   # copies, even for a very short cast

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
	# A cut-paper card casts its OWN FACE: copies of the element's StyleBoxTexture, stepped along the
	# shared cast. A blurred rounded rect cannot do this job — its feather escapes sideways by
	# (blur + spread - |offset_x|), and offset_x is 0, so it rings every card with a grey halo no
	# matter how it is tuned; the sprite's transparent margin then exposes even more of it.
	var face: StyleBox = inner.get_theme_stylebox("panel") if inner.has_theme_stylebox_override("panel") else null
	if face is StyleBoxTexture:
		var rungs := _ladder()
		for i in rungs.size():
			var copy := Panel.new()
			copy.name = "%s%d" % [CARD_SHADOW, i + 1]   # numbered: Godot renames a COLLIDING name to @Panel@n
			copy.add_theme_stylebox_override("panel", face)   # the same 9-slice = the same silhouette
			root.add_child(_place(copy, Color(rungs[i]["tint"]), Vector2(rungs[i]["drop"])))
	else:
		# code-drawn fallback (no baked face to copy): the shared rounded-rect cast, clamped
		var sh := Look.shadow_rect(Look.shape_corner(inner, WRAP_CORNER), Look.saved_shadow_params())
		sh.name = PANEL_SHADOW
		root.add_child(_place(sh, Color.WHITE, Vector2.ZERO))
	_fill(root, inner)
	return root

## Wrap a bare SPRITE (art that does NOT fill its box) with the same shape-true cast, stamped from the
## sprite's own texture. A rounded-rect cast is doubly wrong here: the art is transparent, so the rect
## prints a grey slab around the sprite instead of a shadow under it.
static func wrap_sprite(inner: Control, tex: Texture2D) -> Control:
	var root := _wrap_root(inner)
	if tex != null:
		var rungs := _ladder()
		for i in rungs.size():
			var copy: Control = (inner.duplicate() as Control) if inner is TextureRect else _layer(tex)
			copy.name = "%s%d" % [SPRITE_SHADOW, i + 1]   # numbered: a colliding name becomes @TextureRect@n
			root.add_child(_place(copy, Color(rungs[i]["tint"]), Vector2(rungs[i]["drop"])))
	_fill(root, inner)
	return root

## The cast as a DENSE stack: copies stepping out to the saved offset ~1px apart, each at a low alpha
## that accumulates to exactly the saved alpha where they all overlap. Dense is what keeps a stacked
## cast smooth — a 3-copy stack visibly steps, which is why this used to be a blurred rect.
## Returns [{tint, drop}] back-to-front; empty when the block casts nothing.
static func _ladder() -> Array:
	var p := Look.saved_shadow_params()
	var drop := Vector2(float(p.offset_x), float(p.offset_y))
	var alpha := float(p.alpha)
	if drop.length() <= 0.0 or alpha <= 0.0:
		return []
	var steps := maxi(LADDER_MIN, int(ceilf(drop.length())))
	# n copies of `each` read as one layer of `alpha`: 1 - (1-each)^n = alpha
	var each := 1.0 - pow(1.0 - alpha, 1.0 / float(steps))
	var rungs := []
	for i in steps:
		rungs.append({"tint": Look.shadow_color(each), "drop": drop * (float(i + 1) / float(steps))})
	return rungs

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

# Lay ONE cast copy over the wrapper, dropped by `drop`. Duplicating inner (rather than building a
# fresh node) carries its expand/stretch mode over, so an aspect-centred icon's shadow lands exactly
# under the art instead of under its larger box.
static func _place(copy: Control, tint: Color, drop: Vector2) -> Control:
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
