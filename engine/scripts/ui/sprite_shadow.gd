extends Control
## A FLAT drop-shadow stamped from a sprite's OWN silhouette — so the cast follows the art's real
## shape (a deckled card edge, an item outline), not a rounded-rect approximation. The sprite's alpha
## is downsampled once into a soft white silhouette (cached per texture+div; the bilinear upscale at
## draw time IS the blur), then drawn at the element's rect, offset by the shared shadow cast, tinted
## to the shared slate. Unlike prop_shadow (which shears+squashes a standing prop onto the ground),
## this stays flat behind a flat UI surface. Add as a show_behind_parent child of the element it shades.
##
## Usage:  var sh := SpriteShadow.new()
##         sh.texture = tex; sh.draw_size = Vector2(w, h); sh.offset = Vector2(ox, oy)
##         sh.tint = Look.shadow_color(alpha)
##         sh.fit = true; sh.inset = w * 0.16   # aspect-fit the texture in the box (items); OFF = stretch-fill (cards)
##         sh.show_behind_parent = true; element.add_child(sh)

var texture: Texture2D = null       # the silhouette source (the element's own art)
var draw_size := Vector2.ZERO       # the element's on-canvas size (card box / icon box)
var offset := Vector2.ZERO          # the shared shadow cast (offset_x, offset_y)
var tint := Color(0, 0, 0, 0.3)     # the shared slate shadow colour (rgb + alpha)
var fit := false                    # true → aspect-fit the texture within (draw_size − inset) like the art; false → stretch-fill
var inset := 0.0                    # per-side inset (px) when fit — mirror the sprite's own inset so the shadow lines up
var soft_div := 3                   # silhouette downsample factor — bigger = softer / less shape detail

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if texture == null or draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return
	var soft := _soft_silhouette(texture, soft_div)
	if soft == null:
		return
	var rect: Rect2
	if fit:
		rect = _aspect_fit(texture.get_size(), Rect2(Vector2(inset, inset), draw_size - Vector2(inset, inset) * 2.0))
	else:
		rect = Rect2(Vector2.ZERO, draw_size)
	rect.position += offset
	draw_texture_rect(soft, rect, false, tint)   # white silhouette × tint = a flat slate cast at tint.a

# The largest texture-aspect rect that fits inside `box`, centred — mirrors STRETCH_KEEP_ASPECT_CENTERED
# so a fitted silhouette lands exactly under the art the sprite draws the same way.
static func _aspect_fit(tex_size: Vector2, box: Rect2) -> Rect2:
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or box.size.x <= 0.0 or box.size.y <= 0.0:
		return box
	var s := minf(box.size.x / tex_size.x, box.size.y / tex_size.y)
	var sz := tex_size * s
	return Rect2(box.position + (box.size - sz) / 2.0, sz)

# The blurred stamp: the sprite decoded once, downsampled hard (the linear upscale at draw time is the
# softening), then flattened to WHITE rgb so the caller's `tint` alone colours it (draw modulate
# multiplies — a white silhouette × slate tint = the slate shadow; keeping the sprite's own rgb would
# tint the cast by the art's colour). Cached per texture rid + div. get_image can fail on the headless
# dummy renderer — cache the null so we never retry per frame.
static var _soft_cache: Dictionary = {}
static func _soft_silhouette(tex: Texture2D, div: int) -> Texture2D:
	var key := "%d:%d" % [tex.get_rid().get_id(), div]
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
	img.resize(maxi(1, img.get_width() / div), maxi(1, img.get_height() / div), Image.INTERPOLATE_BILINEAR)
	# flatten rgb to white, keep the (now soft) alpha — the tint colours it at draw time
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var a := img.get_pixel(x, y).a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var soft := ImageTexture.create_from_image(img)
	_soft_cache[key] = soft
	return soft
