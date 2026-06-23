extends Control

var settings := {
	"offset_x": 0.0,
	"offset_y": 10.0,
	"blur": 14.0,
	"spread": 4.0,
	"alpha": 0.34,
	"warmth": 0.82,
	"inner_highlight": 0.78,
}

func _ready() -> void:
	custom_minimum_size = Vector2(760.0, 520.0)
	resized.connect(queue_redraw)

func set_shadow_setting(key: String, value: float) -> void:
	if not settings.has(key):
		return
	settings[key] = value
	queue_redraw()

func get_shadow_settings() -> Dictionary:
	return settings.duplicate()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#67B8E6"), true)
	_draw_subtle_background()

	var button_size := Vector2(430.0, 116.0)
	var button_rect := Rect2((size - button_size) * 0.5, button_size)
	_draw_soft_shadow(button_rect)
	_draw_button(button_rect)

func _draw_subtle_background() -> void:
	for i in range(8):
		var t := float(i) / 7.0
		draw_rect(
			Rect2(Vector2(0.0, size.y * t), Vector2(size.x, size.y / 7.0 + 1.0)),
			Color(0.37, 0.70, 0.90, 0.09 * (1.0 - t)),
			true
		)

func _draw_soft_shadow(rect: Rect2) -> void:
	var blur := float(settings["blur"])
	var spread := float(settings["spread"])
	var alpha := float(settings["alpha"])
	var offset := Vector2(float(settings["offset_x"]), float(settings["offset_y"]))
	var warm := float(settings["warmth"])
	var base_color := Color("#5A371B").lerp(Color("#1D1720"), 1.0 - warm)
	var layers := maxi(5, int(round(blur)))

	for i in range(layers, 0, -1):
		var t := float(i) / float(layers)
		var eased := pow(1.0 - t, 2.15)
		var grow := spread + blur * t * 0.72
		var layer_rect := rect.grow(grow)
		layer_rect.position += offset + Vector2(0.0, t * blur * 0.18)
		var color := base_color
		color.a = alpha * eased * 0.32
		_draw_style(layer_rect, color, 40.0 + grow, 0.0, Color.TRANSPARENT)

	var contact := rect.grow(spread * 0.6)
	contact.position += offset + Vector2(0.0, 2.0)
	var contact_color := base_color
	contact_color.a = alpha * 0.34
	_draw_style(contact, contact_color, 40.0 + spread, 0.0, Color.TRANSPARENT)

func _draw_button(rect: Rect2) -> void:
	_draw_style(rect.grow(4.0), Color("#D5B46D"), 44.0, 0.0, Color.TRANSPARENT)
	_draw_style(rect.grow(1.0), Color("#FFF8E8"), 42.0, 0.0, Color.TRANSPARENT)
	_draw_style(rect, Color("#F6E7C9"), 39.0, 2.0, Color("#C69A4C"))

	var highlight_alpha := float(settings["inner_highlight"])
	_draw_style(Rect2(rect.position + Vector2(10.0, 9.0), rect.size - Vector2(20.0, 42.0)), Color(1.0, 1.0, 1.0, highlight_alpha * 0.34), 32.0, 0.0, Color.TRANSPARENT)
	_draw_style(Rect2(rect.position + Vector2(6.0, rect.size.y - 27.0), Vector2(rect.size.x - 12.0, 18.0)), Color("#C89042", 0.14), 22.0, 0.0, Color.TRANSPARENT)

	var coin_center := rect.position + Vector2(78.0, rect.size.y * 0.5)
	_draw_coin(coin_center, 39.0)

	_draw_plus_badge(rect.position + Vector2(rect.size.x - 58.0, rect.size.y * 0.5), 34.0)

	draw_string(
		ThemeDB.fallback_font,
		rect.position + Vector2(150.0, 73.0),
		"2,450",
		HORIZONTAL_ALIGNMENT_LEFT,
		170.0,
		42,
		Color("#3C1C13")
	)

func _draw_coin(center: Vector2, radius: float) -> void:
	draw_circle(center + Vector2(0.0, 4.0), radius + 4.0, Color("#6B3A11", 0.18))
	draw_circle(center, radius, Color("#B66F10"))
	draw_circle(center, radius - 4.0, Color("#FFD35C"))
	draw_circle(center, radius - 10.0, Color("#F6A91F"))
	draw_arc(center - Vector2(3.0, 3.0), radius - 12.0, PI * 0.78, PI * 1.82, 30, Color("#FFE791", 0.86), 5.0, true)
	_draw_star(center, radius * 0.38, Color("#FFE17B"), Color("#A8650E"))

func _draw_star(center: Vector2, radius: float, fill: Color, outline: Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		var r := radius if i % 2 == 0 else radius * 0.48
		var angle := -PI * 0.5 + float(i) * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, outline, 2.0, true)

func _draw_plus_badge(center: Vector2, radius: float) -> void:
	draw_circle(center + Vector2(0.0, 4.0), radius + 3.0, Color("#4A3814", 0.16))
	draw_circle(center, radius, Color("#6F862B"))
	draw_circle(center, radius - 4.0, Color("#CDE675"))
	draw_circle(center, radius - 12.0, Color("#8AA63F"))
	var plus_color := Color("#FEF8D5")
	var arm := radius * 0.47
	var w := radius * 0.16
	draw_rect(Rect2(center - Vector2(w, arm), Vector2(w * 2.0, arm * 2.0)), plus_color, true)
	draw_rect(Rect2(center - Vector2(arm, w), Vector2(arm * 2.0, w * 2.0)), plus_color, true)

func _draw_style(rect: Rect2, fill: Color, radius: float, border_width: float, border_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(int(round(radius)))
	if border_width > 0.0:
		style.set_border_width_all(int(round(border_width)))
		style.border_color = border_color
	draw_style_box(style, rect)
