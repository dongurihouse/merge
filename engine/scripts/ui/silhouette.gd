extends RefCounted
## The SHARED soft-silhouette stamp behind both code-drawn shadows: a sprite's alpha decoded once and
## downsampled hard, so the linear-filtered upscale at draw time IS the blur. prop_shadow.gd shears the
## stamp flat onto the ground; sprite_shadow.gd lays it behind a flat UI surface. Both used to carry
## their own copy of this — including the headless null-cache, which a fix to one would have missed.
##
## `whiten` flattens rgb to WHITE and keeps the (now soft) alpha, for callers whose draw modulate is a
## COLOUR (sprite_shadow's slate tint × a white silhouette = the slate cast; keeping the sprite's own
## rgb would tint the cast by the art's colour). Callers that modulate with pure black (prop_shadow)
## don't need it — the rgb is multiplied away either way — and skip the per-pixel pass.

# One cache for both callers, keyed on texture rid + div + whiten: the same sprite legitimately yields
# a DIFFERENT stamp per downsample factor and per whiten pass, so all three belong in the key.
# (prop_shadow's old rid-only key was a latent collision the moment its fixed SOFT_DIV grew a knob.)
static var _cache: Dictionary = {}

static func soft(tex: Texture2D, div: int, whiten: bool) -> Texture2D:
	if tex == null:
		return null
	var key := "%d:%d:%d" % [tex.get_rid().get_id(), div, 1 if whiten else 0]
	if _cache.has(key):
		return _cache[key]
	var img := tex.get_image()
	if img == null:
		_cache[key] = null      # get_image fails on the headless dummy renderer — cache the null so we
		return null             # never retry per frame
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(maxi(1, img.get_width() / div), maxi(1, img.get_height() / div), Image.INTERPOLATE_BILINEAR)
	if whiten:
		var w := img.get_width()
		var h := img.get_height()
		for y in h:
			for x in w:
				var a := img.get_pixel(x, y).a
				img.set_pixel(x, y, Color(1, 1, 1, a))
	var stamp := ImageTexture.create_from_image(img)
	_cache[key] = stamp
	return stamp
