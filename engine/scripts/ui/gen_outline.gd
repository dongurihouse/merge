@tool
extends Control
## Code-drawn OUTLINE that traces a generator icon's EXACT silhouette (not a square frame). It is given
## a white-silhouette of the icon (alpha = the shape, rgb = white) and draws it tinted, offset around a
## ring; the overlapping copies build a solid rim, and the real art sprite (drawn on top) covers the
## interior — so a clean coloured line peeks out following the art's contour. No shader / AtlasTexture
## pitfalls; width + opacity are tunable. Fit MUST match PieceView._add_sprite (same inset + KEEP_ASPECT
## _CENTERED) so the rim lines up with the art.

@export var tex: Texture2D                 # white-silhouette of the icon (rgb = white, a = shape)
@export var color := Color("#E8BE5C")      # rim colour (gold)
@export var width := 3.0                    # rim thickness in px (outward)
@export var alpha := 0.85                   # rim opacity
@export var blur := 0.0                      # rim feather in px (0 = crisp edge; >0 fades the rim outward)
@export var inset := 0.16                   # MUST equal the sprite's ITEM_INSET
@export var steps := 16                     # ring sample count (higher = smoother rim)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	if tex == null or width <= 0.0 or alpha <= 0.0:
		return
	var ts := tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return
	# KEEP_ASPECT_CENTERED of the silhouette inside the inset box — identical to PieceView._add_sprite.
	var bw := size.x * (1.0 - 2.0 * inset)
	var bh := size.y * (1.0 - 2.0 * inset)
	var sc: float = minf(bw / ts.x, bh / ts.y)
	var dw := ts.x * sc
	var dh := ts.y * sc
	var rect := Rect2((size.x - dw) / 2.0, (size.y - dh) / 2.0, dw, dh)
	# The solid rim: stamp the silhouette around a ring of radius `width`.
	_stamp_ring(rect, width, alpha)
	# The feather (blur): concentric rings fading to 0 across `blur` px beyond the rim, softening the hard
	# outer edge. Skipped when blur <= 0 so the crisp look is byte-for-byte the single-ring rim as before.
	if blur > 0.0:
		var layers := clampi(int(ceil(blur)), 1, 12)
		for r in range(1, layers + 1):
			var t := float(r) / float(layers)              # 0..1 outward across the feather band
			_stamp_ring(rect, width + blur * t, alpha * (1.0 - t))   # linear falloff to 0 at the outer edge

# Stamp the silhouette `steps` times around a ring of the given radius, tinted at alpha `a`. Overlapping
# copies build a continuous rim; successive rings (see _draw) build the feather band.
func _stamp_ring(rect: Rect2, radius: float, a: float) -> void:
	if a <= 0.0 or radius <= 0.0:
		return
	var col := color
	col.a = a
	for i in steps:
		var ang := TAU * float(i) / float(steps)
		var off := Vector2(cos(ang), sin(ang)) * radius
		draw_texture_rect(tex, Rect2(rect.position + off, rect.size), false, col)
