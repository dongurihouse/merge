extends Control
## Optional placement bounds and center-bottom anchors for the Home workbench.

var entries: Array = []


func _draw() -> void:
	for entry_variant in entries:
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant
		var anchor: Vector2 = entry.get("position", Vector2.ZERO)
		var display_size: Vector2 = entry.get("size", Vector2.ZERO)
		var bounds := Rect2(
			anchor - Vector2(display_size.x * 0.5, display_size.y), display_size
		)
		draw_rect(bounds, Color(1.0, 0.95, 0.25, 0.9), false, 2.0)
		draw_line(anchor - Vector2(8, 0), anchor + Vector2(8, 0), Color.WHITE, 2.0)
		draw_line(anchor - Vector2(0, 8), anchor + Vector2(0, 8), Color.WHITE, 2.0)
