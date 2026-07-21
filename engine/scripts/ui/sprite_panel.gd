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
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size_flags_horizontal = inner.size_flags_horizontal
	root.size_flags_vertical = inner.size_flags_vertical
	# ONE soft blurred shadow (matching build), not stacked silhouette copies — those stepped visibly on
	# tall cards. Anchored full-rect so it tracks the wrapper, nudged down a hair for the drop.
	var sh := Look.shadow_rect(14.0, {})
	sh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sh.offset_top += 4.0
	sh.offset_bottom += 4.0
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sh)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(inner)
	# push inner's content size onto the wrapper so the shadow tracks an auto-height element
	var sync := func() -> void:
		if is_instance_valid(root) and is_instance_valid(inner):
			root.custom_minimum_size = inner.get_combined_minimum_size()
	sync.call()
	inner.minimum_size_changed.connect(sync)
	return root

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
