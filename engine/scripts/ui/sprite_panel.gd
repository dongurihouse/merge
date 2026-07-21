extends RefCounted
## A non-interactive cut-paper SPRITE PANEL: one flat sprite (a card / cell / bar frame baked as a PNG)
## laid over its own soft downward silhouette shadow — the same shadow feel as SpriteButton and the
## wallet pills. Returns a Control sized to `size`; the caller stacks its content on top (add_child).
## Used by the reskinned dialog cards and habitat cells.
##
##   var card := SpritePanel.build(load(tex), Vector2(w, h))
##   card.add_child(<content laid out with anchors over the panel>)

const Look = preload("res://engine/scripts/ui/skin.gd")

const SHADOW := [
	{"dy": 0.03, "a": 0.16},
	{"dy": 0.06, "a": 0.12},
	{"dy": 0.09, "a": 0.08},
]

static func build(tex: Texture2D, size: Vector2, opts: Dictionary = {}) -> Control:
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bool(opts.get("shadow", true)):
		for layer in SHADOW:
			root.add_child(_layer(tex, Look.shadow_color(float(layer["a"])), size.y * float(layer["dy"])))
	root.add_child(_layer(tex, Color.WHITE, 0.0))
	return root

static func _layer(tex: Texture2D, mod: Color, dy: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # BEFORE anchors, so native px never drives min size
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture = tex
	tr.modulate = mod
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.offset_top += dy
	tr.offset_bottom += dy
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
