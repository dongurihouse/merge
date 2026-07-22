extends Control
## The soft INNER shadow a recessed cut-paper inset casts from its TOP edge — the darkening you see where
## the sunken green well sits below the cream card lip. A top-down gradient that follows the inset's
## rounded top corners (so it doesn't spill past them). Drawn in code, tuned by the torn-cell knobs.
##
##   var s := CutPaperInsetShadow.new(); s.size = inset_size; s.configure(corner, height, strength, tint)

var corner: float = 14.0        # the inset's rounded-corner radius (so the shadow hugs the top corners)
var shade_h: float = 26.0       # how far the shadow reaches down from the top edge (px)
var strength: float = 0.28      # peak alpha at the very top
var tint: Color = Color("#294654")   # Meadow "tinted shadow"
var falloff: float = 1.6        # gradient curve: >1 concentrates the dark near the top

func configure(corner_px: float, height_px: float, strength_a: float, tint_c: Color, falloff_p: float = 1.6) -> void:
	corner = corner_px
	shade_h = height_px
	strength = strength_a
	tint = tint_c
	falloff = falloff_p
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var r := minf(corner, minf(w, h) * 0.5)
	var rows := int(ceilf(minf(shade_h, h)))
	for y in rows:
		var t := float(y) / maxf(1.0, shade_h)          # 0 at the top edge → 1 at the reach
		var a := strength * pow(clampf(1.0 - t, 0.0, 1.0), falloff)
		if a <= 0.002:
			continue
		# horizontal inset at this row so the band follows the rounded TOP corners
		var dx := 0.0
		if float(y) < r:
			dx = r - sqrt(maxf(0.0, r * r - (r - float(y)) * (r - float(y))))
		draw_rect(Rect2(dx, float(y), maxf(0.0, w - 2.0 * dx), 1.0), Color(tint.r, tint.g, tint.b, a))
