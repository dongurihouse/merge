extends Control
## A FLAT drop-shadow stamped from a sprite's OWN silhouette — so the cast follows the art's real
## shape (a deckled card edge, an item outline), not a rounded-rect approximation. The sprite's alpha
## is downsampled once into a soft white silhouette (silhouette.gd, cached; the bilinear upscale at
## draw time IS the blur), then drawn at the element's rect, offset by the shared shadow cast, tinted
## to the shared slate. Unlike prop_shadow (which shears+squashes a standing prop onto the ground),
## this stays flat behind a flat UI surface. Add as a show_behind_parent child of the element it shades.
##
## Usage:  var sh := SpriteShadow.new()
##         sh.texture = tex; sh.draw_size = Vector2(w, h); sh.offset = Vector2(ox, oy)
##         sh.tint = Look.shadow_color(alpha)
##         sh.fit = true; sh.inset = w * 0.16   # aspect-fit the texture in the box (items); OFF = stretch-fill (cards)
##         sh.show_behind_parent = true; element.add_child(sh)

const Silhouette = preload("res://engine/scripts/ui/silhouette.gd")   # the shared downsampled-alpha stamp

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
	# The blurred stamp, flattened to WHITE rgb so the caller's `tint` alone colours it (draw modulate
	# multiplies — a white silhouette × slate tint = the slate shadow; keeping the sprite's own rgb
	# would tint the cast by the art's colour).
	var soft := Silhouette.soft(texture, soft_div, true)
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
