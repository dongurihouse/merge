@tool
extends Container
## Uniformly scales its single Control child by `scale_factor`, preserving the child's
## AUTHORED pixel sizes. The child is laid out at (this.width / scale_factor) so its
## contents wrap and size exactly as they would at that width, then rendered at
## `scale_factor`. The container reports the child's *scaled* minimum height as its own
## minimum height, so a parent ScrollContainer scrolls the scaled footprint correctly.
## scale_factor == 1 is a transparent pass-through (no visual or layout change).
##
## Preloaded (no class_name) so a brand-new file needs no project rescan to be referenced.

@export var scale_factor: float = 1.0:
	set(v):
		var nv: float = maxf(0.01, v)
		if is_equal_approx(nv, scale_factor):
			return
		scale_factor = nv
		queue_sort()
		update_minimum_size()

func _child() -> Control:
	for c in get_children():
		if c is Control and not c.is_set_as_top_level():
			return c
	return null

func _get_minimum_size() -> Vector2:
	var c := _child()
	if c == null:
		return Vector2.ZERO
	# Width 0 → we EXPAND_FILL to the available (scroll) width. Height = the child's
	# minimum height at its laid-out width, scaled up — the scaled footprint a parent
	# ScrollContainer must scroll.
	return Vector2(0.0, c.get_combined_minimum_size().y * scale_factor)

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var c := _child()
		if c == null:
			return
		var s: float = maxf(0.01, scale_factor)
		if not c.minimum_size_changed.is_connected(_remeasure):
			c.minimum_size_changed.connect(_remeasure)
		c.pivot_offset = Vector2.ZERO
		c.scale = Vector2(s, s)
		c.position = Vector2.ZERO
		# Give the child our full width in its own (unscaled) space; let it choose its own
		# height (containers size to their content's min height for that width).
		c.size = Vector2(size.x / s, c.get_combined_minimum_size().y)

func _remeasure() -> void:
	update_minimum_size()
	queue_sort()
