@tool
extends Control
## UI Workbench — gallery + inspector sidebar.
##
## `make workbench` opens this. The left column is a scroll of the fundamental components, built
## bottom-up from the self-contained kit (cost pill → mail card → mail dialog). CLICK an element to
## select it; the right SIDEBAR then shows that element's own options/sliders. Changing a slider
## rebuilds just that element — and because the components compose, a dialog's pill size still flows
## down into every row.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const SETTINGS := "res://games/grove/tools/ui_workbench_settings.json"   # persisted params (in the repo)

const IDS := ["button", "pill", "icon", "card", "dialog"]
const CAPTIONS := {
	"button": "Button — shared (bg · icon · state)",
	"pill": "Cost pill — the cream button variant",
	"icon": "Icon — edge polish (raw vs cleaned)",
	"card": "Mail card — pill + Claim",
	"dialog": "Mail dialog — cards",
}
# Per-element knob schema: [key, min, max]. The sidebar renders one slider per entry.
const SCHEMA := {
	"pill": [],                                             # no own controls — it's the shared Button (cream)
	"button": [["font", 12, 40], ["corner", 0, 40]],        # bg / icon / enabled are toggles, added below
	"icon": [["feather", 0, 4], ["supersample", 1, 4]],     # defringe is a toggle, added below
	"card": [["title", 12, 30], ["body", 10, 24]],          # pill size inherits from the Cost pill
	"dialog": [                                             # pill size inherits from the Cost pill
		["width", 360, 720], ["card_corner", 0, 60],
		["banner_font", 16, 56], ["banner_h", 50, 160], ["banner_icon", 24, 110],
		["banner_x", -200, 200], ["banner_y", -120, 120],
		["banner_icon_x", 0, 700], ["banner_icon_y", 0, 160],
		["close_size", 30, 96], ["close_x", -100, 100], ["close_y", -100, 100],
		["snap", 1, 40],
		["entries", 1, 12], ["list_max_h", 0, 900],          # scroll test: rows count + height cap (0 = no cap)
	],
}

var _params := {
	"pill": {},                                             # the cost pill is the shared Button (no own state)
	"button": {"text": "Claim", "bg": "green", "show_icon": false, "enabled": true, "font": 22, "corner": 16},
	"icon": {"defringe": false, "feather": 1, "supersample": 1},
	"card": {"title": 20, "body": 15},
	"dialog": {
		"width": 560, "card_corner": 22,
		"banner_font": 32, "banner_h": 92, "banner_icon": 54, "banner_icon_on": true,
		"banner_x": 0, "banner_y": 0,
		"banner_icon_x": 130, "banner_icon_y": 19,
		"close_size": 64, "close_x": 12, "close_y": 12, "snap": 8,
		"entries": 4, "list_max_h": 0,
	},
}
var _selected := "button"
var _gallery: VBoxContainer = null
var _sidebar_body: VBoxContainer = null

# polished-icon textures, cached by their opts so an unrelated rebuild doesn't re-run the (slow) polish
var _icon_cache: Dictionary = {}

# drag-to-move (banner icon / ✕), with snap-to-grid
var _drag_kind := ""
var _drag_node: Control = null
var _drag_grab := Vector2.ZERO

func _ready() -> void:
	if Engine.is_editor_hint():
		theme = UiFont.make()
	_load_settings()
	_build()

func _build() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()

	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 0)
	add_child(hb)

	# right — the gallery (scrolls; the dialog is tall)
	var gal_scroll := ScrollContainer.new()
	gal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gal_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gal_scroll.size_flags_vertical = Control.SIZE_FILL
	hb.add_child(gal_scroll)
	var gal_margin := MarginContainer.new()
	gal_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		gal_margin.add_theme_constant_override("margin_" + side, 24)
	gal_scroll.add_child(gal_margin)
	_gallery = VBoxContainer.new()
	_gallery.add_theme_constant_override("separation", 18)
	_gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gal_margin.add_child(_gallery)

	# left — the options sidebar (fixed width)
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(380, 0)
	side.size_flags_vertical = Control.SIZE_FILL
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0, 0, 0, 0.42)
	ssb.border_width_right = 2
	ssb.border_color = Color(Pal.CREAM, 0.12)
	ssb.set_content_margin_all(18)
	side.add_theme_stylebox_override("panel", ssb)
	# scope a SMALL font to the sidebar — the global 40px default made the row labels balloon and
	# crowd the sliders out. Keep the rounded face, drop the heavy outline for small text.
	var st := UiFont.make()
	st.default_font_size = 16
	for t in ["Label", "Button", "LineEdit", "OptionButton", "CheckButton"]:
		st.set_constant("outline_size", t, 0)
	side.theme = st
	hb.add_child(side)
	hb.move_child(side, 0)   # sidebar on the LEFT, gallery to its right
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(side_scroll)
	_sidebar_body = VBoxContainer.new()
	_sidebar_body.add_theme_constant_override("separation", 10)
	_sidebar_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(_sidebar_body)

	_rebuild_gallery()
	_rebuild_sidebar()

## Build the live element for an id from its current params.
func _make_element(id: String) -> Control:
	var p: Dictionary = _params[id]
	match id:
		"pill":
			return Kit.cost_pill("gem", 50, _btn_opts())
		"button":
			return Kit.pill_button(String(p.text), _btn_opts())
		"icon":
			var box := HBoxContainer.new()
			box.add_theme_constant_override("separation", 28)
			box.add_child(_icon_preview("Raw", {"defringe": false, "feather": 0.0, "supersample": 1}))
			box.add_child(_icon_preview("Polished", {"defringe": bool(p.defringe), "feather": float(p.feather), "supersample": int(p.supersample)}))
			return box
		"card":
			# the cost pill AND the Claim both inherit from the shared Button
			return Kit.mail_card(Kit.DEMO_MAIL[0], int(p.title), int(p.body), _btn_opts())
		"dialog":
			var opts := {
				"card_corner": float(p.card_corner),
				"banner_font": int(p.banner_font),
				"banner_h": float(p.banner_h),
				"banner_icon": float(p.banner_icon),
				"banner_icon_on": bool(p.banner_icon_on),
				"banner_pos": Vector2(float(p.banner_x), float(p.banner_y)),
				"banner_icon_pos": Vector2(float(p.banner_icon_x), float(p.banner_icon_y)),
				"close_size": float(p.close_size),
				"close_poke": Vector2(float(p.close_x), float(p.close_y)),
				"entries_count": int(p.entries),
				"list_max_h": float(p.list_max_h),
				"btn": _btn_opts(),                        # the shared Button drives the cost pills + Claims
			}
			var d := Kit.mail_dialog(Kit.DEMO_MAIL, float(p.width), opts)
			_attach_dialog_drag(d)
			return d
	return Control.new()

## One labelled icon preview (raw or polished) for the Icon element.
func _icon_preview(label: String, opts: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = label
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(Pal.CREAM, 0.8))
	v.add_child(l)
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(170, 170)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	opts["size"] = 160
	var key := "%s|%s|%s" % [opts.get("defringe", false), opts.get("feather", 0.0), opts.get("supersample", 1)]
	if not _icon_cache.has(key):
		_icon_cache[key] = Kit.polish_icon_tex("gem", opts)
	tr.texture = _icon_cache[key]
	v.add_child(tr)
	return v

## The shared Button's params as a kit opts dict. The card + dialog Claim are built ENTIRELY from
## this (no styling of their own), so editing the Button item updates every Claim automatically.
func _btn_opts() -> Dictionary:
	var b: Dictionary = _params["button"]
	return {
		"text": String(b.text),
		"bg": String(b.bg),
		"icon": ("gem" if bool(b.show_icon) else ""),
		"enabled": bool(b.enabled),
		"font": int(b.font),
		"corner": int(b.corner),
	}

## --- gallery (left) ------------------------------------------------------------------------------

func _rebuild_gallery() -> void:
	if _gallery == null or not is_instance_valid(_gallery):
		return
	for c in _gallery.get_children():
		_gallery.remove_child(c)
		c.queue_free()
	for id in IDS:
		_gallery.add_child(_section(id))

func _section(id: String) -> Control:
	var sec := PanelContainer.new()
	sec.add_theme_stylebox_override("panel", _section_style(id == _selected))
	sec.mouse_filter = Control.MOUSE_FILTER_STOP            # catches clicks on the non-button areas
	sec.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sec.gui_input.connect(_on_section_input.bind(id))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sec.add_child(v)
	var cap := Label.new()
	cap.text = ("●  " if id == _selected else "") + String(CAPTIONS[id])
	cap.add_theme_font_size_override("font_size", 15)
	cap.add_theme_color_override("font_color", Pal.STRAW if id == _selected else Color(Pal.CREAM, 0.8))
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cap)
	var holder := CenterContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var el := _make_element(id)
	_ignore_nonbuttons(el)
	holder.add_child(el)
	v.add_child(holder)
	return sec

## Make every non-button Control mouse-transparent, so a click anywhere on the section EXCEPT the
## inner buttons (Claim / ✕ / the buy pill) falls through to the section and selects it.
func _ignore_nonbuttons(n: Node) -> void:
	for c in n.get_children():
		# keep the draggable banner + banner icon mouse-active so they can be grabbed
		if c is Control and not (c is BaseButton) and String(c.name) != "DialogBannerIcon" and String(c.name) != "DialogBanner":
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_nonbuttons(c)

## --- drag-to-move with snap (dialog banner icon + ✕) ---------------------------------------------

## Make the dialog's named handles draggable. Re-run on every dialog rebuild (new nodes each time).
func _attach_dialog_drag(d: Control) -> void:
	var banner: Control = d.find_child("DialogBanner", true, false)
	if banner != null:
		banner.mouse_filter = Control.MOUSE_FILTER_STOP
		_make_draggable(banner, "banner")
	var env: Control = d.find_child("DialogBannerIcon", true, false)
	if env != null:
		env.mouse_filter = Control.MOUSE_FILTER_STOP
		_make_draggable(env, "banner_icon")
	var close: Control = d.find_child("DialogClose", true, false)
	if close != null:
		_make_draggable(close, "close")

func _make_draggable(node: Control, kind: String) -> void:
	node.mouse_default_cursor_shape = Control.CURSOR_MOVE
	node.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (ev as InputEventMouseButton).pressed:
			_drag_kind = kind
			_drag_node = node
			_drag_grab = (ev as InputEventMouseButton).global_position - node.global_position
			get_viewport().set_input_as_handled())

# Global so the drag keeps following the cursor even when it leaves the small handle.
func _input(ev: InputEvent) -> void:
	if _drag_kind == "" or _drag_node == null or not is_instance_valid(_drag_node):
		return
	if ev is InputEventMouseMotion:
		var parent := _drag_node.get_parent() as Control
		if parent == null:
			return
		var target: Vector2 = (ev as InputEventMouseMotion).global_position - _drag_grab
		var local: Vector2 = parent.get_global_transform().affine_inverse() * target
		local = _snap_vec(local)
		_drag_node.position = local
		_store_drag(_drag_kind, local)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and not (ev as InputEventMouseButton).pressed:
		_drag_kind = ""
		_drag_node = null
		_rebuild_sidebar()      # reflect the dragged position in the sliders (and clamp it)
		_rebuild_gallery()      # re-apply the (possibly clamped) params consistently

func _snap_vec(v: Vector2) -> Vector2:
	var g: float = float(int(_params["dialog"]["snap"]))
	if g < 1.0:
		return v
	return Vector2(roundf(v.x / g) * g, roundf(v.y / g) * g)

func _store_drag(kind: String, local: Vector2) -> void:
	var p: Dictionary = _params["dialog"]
	if kind == "banner":
		p["banner_x"] = local.x
		p["banner_y"] = local.y
	elif kind == "banner_icon":
		p["banner_icon_x"] = local.x
		p["banner_icon_y"] = local.y
	elif kind == "close":
		var card := _drag_node.get_parent().get_child(0) as Control   # wrap's first child is the card
		var cw: float = (card.size.x if card != null else float(p["width"]))
		p["close_x"] = local.x - (cw - _drag_node.size.x)             # inverse of the kit's dock() formula
		p["close_y"] = -local.y

func _on_section_input(ev: InputEvent, id: String) -> void:
	var hit: bool = (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	hit = hit or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed)
	if hit:
		select(id)

func select(id: String) -> void:
	if id == _selected:
		return
	_selected = id
	# DEFER: select() runs inside a section's gui_input dispatch — rebuilding (freeing the very
	# section that is mid-emit) here would hit "Object is locked and can't be freed". Defer so the
	# tree is mutated only after the input dispatch returns.
	_rebuild_gallery.call_deferred()      # refresh the selection highlight
	_rebuild_sidebar.call_deferred()      # swap in this element's options

func _section_style(selected: bool) -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	if selected:
		sb.bg_color = Color(1, 1, 1, 0.05)
		sb.set_border_width_all(2)
		sb.border_color = Pal.STRAW
	else:
		sb.bg_color = Color(0, 0, 0, 0.22)
		sb.set_border_width_all(1)
		sb.border_color = Color(Pal.CREAM, 0.1)
	return sb

## --- sidebar (right) -----------------------------------------------------------------------------

func _rebuild_sidebar() -> void:
	if _sidebar_body == null or not is_instance_valid(_sidebar_body):
		return
	for c in _sidebar_body.get_children():
		_sidebar_body.remove_child(c)
		c.queue_free()
	var head := Label.new()
	head.text = "Options"
	head.add_theme_font_size_override("font_size", 26)
	_sidebar_body.add_child(head)
	var save := Button.new()
	save.text = "Save settings"
	save.pressed.connect(_save_settings)
	_sidebar_body.add_child(save)
	var sub := Label.new()
	sub.text = String(CAPTIONS[_selected])
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(Pal.CREAM, 0.65))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sidebar_body.add_child(sub)
	if _selected == "pill" or _selected == "card" or _selected == "dialog":
		var note := Label.new()
		note.text = "Cost pill + Claim are the shared Button (cream / green) — edit them on the Button item."
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	_sidebar_body.add_child(HSeparator.new())

	if _selected == "button":
		_sidebar_body.add_child(_text_row("Text", "text"))
		_sidebar_body.add_child(_option_row("Background", "bg", ["green", "cream"]))
		_sidebar_body.add_child(_toggle_row("Show icon", "show_icon"))
		_sidebar_body.add_child(_toggle_row("Enabled", "enabled"))
	elif _selected == "dialog":
		_sidebar_body.add_child(_toggle_row("Banner icon", "banner_icon_on"))
	elif _selected == "icon":
		_sidebar_body.add_child(_toggle_row("Defringe", "defringe"))
	for spec in SCHEMA[_selected]:
		_sidebar_body.add_child(_slider_row(spec))

func _slider_row(spec: Array) -> Control:
	var key: String = spec[0]
	var lo: float = float(spec[1])
	var hi: float = float(spec[2])
	var params: Dictionary = _params[_selected]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = key.replace("_", " ").capitalize()
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.value = float(params[key])
	params[key] = s.value          # keep the param in sync if the value was out of range (clamped)
	s.custom_minimum_size = Vector2(0, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := Label.new()
	val.text = "%d" % int(params[key])
	val.custom_minimum_size = Vector2(44, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		params[key] = x
		val.text = "%d" % int(x)
		_rebuild_gallery())
	return row

func _text_row(label: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var le := LineEdit.new()
	le.text = String(_params[_selected].get(key, ""))
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(t: String) -> void:
		_params[_selected][key] = t
		_rebuild_gallery())
	row.add_child(le)
	return row

func _toggle_row(label: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var cb := CheckButton.new()
	cb.button_pressed = bool(_params[_selected].get(key, false))
	cb.toggled.connect(func(on: bool) -> void:
		_params[_selected][key] = on
		_rebuild_gallery())
	row.add_child(cb)
	return row

func _option_row(label: String, key: String, options: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var ob := OptionButton.new()
	var cur := String(_params[_selected].get(key, options[0]))
	for i in options.size():
		ob.add_item(String(options[i]).capitalize(), i)
		if String(options[i]) == cur:
			ob.select(i)
	ob.item_selected.connect(func(idx: int) -> void:
		_params[_selected][key] = String(options[idx])
		_rebuild_gallery())
	row.add_child(ob)
	return row

## --- persistence -------------------------------------------------------------------------------

func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS, FileAccess.WRITE)
	if f == null:
		push_warning("UI Workbench: could not write %s" % SETTINGS)
		return
	f.store_string(JSON.stringify(_params, "\t"))
	f.close()
	print("WORKBENCH: settings saved -> %s" % SETTINGS)

## Merge the saved file over the defaults, copying ONLY keys present in both — so an older or newer
## settings file can never corrupt the live schema.
func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS):
		return
	var f := FileAccess.open(SETTINGS, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not (data is Dictionary):
		return
	for id in _params.keys():
		if data.has(id) and data[id] is Dictionary:
			for k in (_params[id] as Dictionary).keys():
				if (data[id] as Dictionary).has(k):
					_params[id][k] = data[id][k]
