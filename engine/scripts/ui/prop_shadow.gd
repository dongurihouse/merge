extends Control
## A DYNAMIC ground shadow stamped from a prop's OWN silhouette — no static shadow art.
## The sprite's alpha is downsampled once into a soft blob (cached per texture), then drawn
## about the prop's FOOTING (this node's origin) through a shear+squash Transform2D, so the
## silhouette lies flat on the ground: the base stays at the footing, the crown falls away.
## Used by home_page_view for manifest entries tagged {"shadow": true} (major buildings,
## trees — first shipped for the desert palms, replacing their baked shadow plate).

const SOFT_DIV := 6                 # silhouette downsample factor — bilinear upscale = the blur
const ALPHA := 0.26                 # cozy paper shadows stay light
const SHEAR := 0.45                 # horizontal fall per unit height (sun from the upper right)
const SQUASH := 0.22                # ground extent as a fraction of the prop height

static var _soft_cache: Dictionary = {}   # texture rid id -> downsampled silhouette texture

var texture: Texture2D = null       # the prop's sprite (the silhouette source)
var disp := Vector2.ZERO            # the prop's on-canvas display size

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if texture == null or disp.x <= 0.0 or disp.y <= 0.0:
		return
	var soft := _soft_silhouette(texture)
	if soft == null:
		return
	# Basis: X stays put; Y shears sideways and flattens DOWN (screen +y) — a point at height h
	# above the footing lands at (−SHEAR·h, +SQUASH·h), so the trunk base pins to the footing
	# and the crown falls to the lower-left, flipped onto the ground by construction.
	draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(SHEAR, -SQUASH), Vector2.ZERO))
	draw_texture_rect(soft, Rect2(Vector2(-disp.x * 0.5, -disp.y), disp), false, Color(0, 0, 0, ALPHA))

## The blurred stamp: the sprite decoded once, downsampled hard; the linear-filtered upscale at
## draw time is the softening. Modulate blackens it, so only the alpha channel matters.
static func _soft_silhouette(tex: Texture2D) -> Texture2D:
	var key := tex.get_rid().get_id()
	if _soft_cache.has(key):
		return _soft_cache[key]
	var img := tex.get_image()
	if img == null:
		_soft_cache[key] = null
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(maxi(1, img.get_width() / SOFT_DIV), maxi(1, img.get_height() / SOFT_DIV),
		Image.INTERPOLATE_BILINEAR)
	var soft := ImageTexture.create_from_image(img)
	_soft_cache[key] = soft
	return soft
