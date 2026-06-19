extends RefCounted
## UI Workbench — the self-contained component kit.
##
## The workbench's OWN definitions of the fundamental components, composed bottom-up:
##   cost_pill / claim_button   (atoms)
##     → mail_card              (molecule — composes a cost_pill + a claim_button)
##       → mail_dialog          (organism — composes a list of mail_cards)
## Each higher component CALLS the lower ones, so a change to an atom flows up automatically.
##
## Self-contained on purpose: this depends only on the shared design-system foundation
## (skin.gd primitives, the kit art, the palette) — NOT on the game screens (inbox.gd / shop.gd)
## or any game state. That keeps the components portable, so the game can later pull from here.

const Look = preload("res://engine/scripts/ui/skin.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

# Nine-patch margins for the shared mail kit (sourced from the real recipe in inbox.gd).
const CARD_TEX := Vector2(30, 30)
const CARD_PAD := Vector4(18, 12, 18, 12)
const PILL_TEX := Vector2(46, 34)
const PILL_PAD := Vector4(14, 6, 14, 6)
const CLAIM_PAD := Vector4(24, 8, 24, 8)
const BANNER_H := 92.0

# Demo inbox matching the mockup — gift/acorn, leaf/water, news/gem, gift/coin.
const DEMO_MAIL := [
	{"icon": "gift", "title": "Welcome Gift", "body": "Thanks for joining us!", "rew": "gem", "n": 50},
	{"icon": "leaf", "title": "Garden Update", "body": "Here are your rewards!", "rew": "water", "n": 30},
	{"icon": "news", "title": "Maintenance Notice", "body": "Servers will be down soon.", "rew": "bluegem", "n": 20},
	{"icon": "gift", "title": "Daily Bonus", "body": "Your daily reward is here!", "rew": "coin", "n": 100},
]

## Resolve an icon id to a real sprite Control. Most ids ride the shared Look.icon; "bluegem" is the
## faceted premium gem (not the grove's acorn), loaded directly.
static func make_icon(id: String, px: float) -> Control:
	if id == "bluegem":
		var p := Game.art("ui/currency/icon_gem_t3.png")
		if ResourceLoader.exists(p):
			var t := TextureRect.new()
			t.texture = load(p)
			t.custom_minimum_size = Vector2(px, px)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return t
	return Look.icon(id, px)

## A cream cost/reward pill: the sliced cream capsule + an icon + a number (mockup image 1).
static func cost_pill(rew_id: String, n: int, font_px: int = 18, icon_px: float = 24.0) -> Control:
	var pill := PanelContainer.new()
	var box := Look.kit_box("kit/mail_pill_cream.png", PILL_TEX, PILL_PAD)
	if box != null:
		pill.add_theme_stylebox_override("panel", box)
	else:
		var s := StyleBoxFlat.new()
		s.bg_color = Pal.CREAM
		s.set_corner_radius_all(18)
		s.set_border_width_all(2)
		s.border_color = Pal.STRAW
		s.content_margin_left = 14; s.content_margin_right = 14
		s.content_margin_top = 6; s.content_margin_bottom = 6
		pill.add_theme_stylebox_override("panel", s)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var ic := make_icon(rew_id, icon_px)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var l := Label.new()
	l.text = str(n)
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", Pal.INK)
	l.add_theme_constant_override("outline_size", 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	return pill

## The green Claim button: the sliced green capsule carrying engine text; falls back to the shared
## primary pill when the art is absent.
static func claim_button(text: String = "Claim", on_press: Callable = Callable(), font_px: int = 18) -> Button:
	var box := Look.kit_box("kit/mail_pill.png", PILL_TEX, CLAIM_PAD)
	if box == null:
		return Look.button(text, on_press if on_press.is_valid() else func() -> void: pass, true)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.add_theme_font_size_override("font_size", font_px)
	b.add_theme_color_override("font_color", Pal.CREAM)
	b.add_theme_color_override("font_hover_color", Pal.CREAM)
	b.add_theme_color_override("font_pressed_color", Pal.CREAM)
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", box)
	var bp: StyleBoxTexture = box.duplicate()
	bp.modulate_color = Color(0.88, 0.88, 0.88)
	b.add_theme_stylebox_override("pressed", bp)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		if on_press.is_valid(): on_press.call())
	return b

## The green shop BUY pill (mockup-adjacent green CTA): background art + acorn icon + price.
static func buy_pill(price: String = "250", rew_id: String = "gem", font_px: int = 26, icon_px: float = 28.0,
		pad_x: float = 16.0, pad_top: float = 6.0, pad_bottom: float = 7.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = price
	b.add_theme_font_size_override("font_size", font_px)
	b.add_theme_color_override("font_color", Pal.CREAM)
	b.add_theme_color_override("font_hover_color", Pal.CREAM)
	b.add_theme_color_override("font_pressed_color", Pal.CREAM)
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_constant_override("icon_max_width", int(icon_px))
	b.add_theme_constant_override("h_separation", 6)
	var ip := Game.art("ui/currency/icon_%s.png" % rew_id)
	if ResourceLoader.exists(ip):
		b.icon = load(ip)
	var box := Look.kit_box("kit/shop_buy.png", Vector2(46, 22), Vector4(pad_x, pad_top, pad_x, pad_bottom))
	if box != null:
		b.add_theme_stylebox_override("normal", box)
		b.add_theme_stylebox_override("hover", box)
		var bp: StyleBoxTexture = box.duplicate()
		bp.modulate_color = Color(0.92, 0.92, 0.92)
		b.add_theme_stylebox_override("pressed", bp)
	return b

## A plated message icon — the icon seated on a pale cream disc (mockup's left-of-row motif).
static func plated_icon(id: String, px: float = 56.0) -> Control:
	var plate := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(Pal.CREAM, 0.9)
	ps.set_corner_radius_all(int(px))
	ps.set_border_width_all(2)
	ps.border_color = Color(Pal.BARK, 0.22)
	var pad := px * 0.16
	ps.content_margin_left = pad; ps.content_margin_right = pad
	ps.content_margin_top = pad; ps.content_margin_bottom = pad
	plate.add_theme_stylebox_override("panel", ps)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.add_child(make_icon(id, px))
	return plate

## A mail card (mockup image 2): plated icon + title/body + a cost_pill + a claim_button.
## COMPOSES the two atoms — pill size flows in from the caller so a knob change propagates here.
static func mail_card(entry: Dictionary, pill_font: int = 18, pill_icon: float = 24.0,
		title_font: int = 20, body_font: int = 15) -> Control:
	var panel := PanelContainer.new()
	var box := Look.kit_box("kit/mail_card.png", CARD_TEX, CARD_PAD)
	if box != null:
		panel.add_theme_stylebox_override("panel", box)
	else:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(Pal.CREAM, 0.6)
		s.set_corner_radius_all(14)
		s.set_border_width_all(1)
		s.border_color = Color(Pal.BARK, 0.4)
		s.content_margin_left = 14; s.content_margin_right = 14
		s.content_margin_top = 10; s.content_margin_bottom = 10
		panel.add_theme_stylebox_override("panel", s)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var ic := plated_icon(String(entry.get("icon", "star")), 56.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var title := Label.new()
	title.text = String(entry.get("title", ""))
	title.add_theme_font_size_override("font_size", title_font)
	title.add_theme_color_override("font_color", Pal.INK)
	title.add_theme_constant_override("outline_size", 0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)
	var body := Label.new()
	body.text = String(entry.get("body", ""))
	body.add_theme_font_size_override("font_size", body_font)
	body.add_theme_color_override("font_color", Color(Pal.BARK, 0.95))
	body.add_theme_constant_override("outline_size", 0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(body)

	var chip := cost_pill(String(entry.get("rew", "gem")), int(entry.get("n", 0)), pill_font, pill_icon)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	var claim := claim_button("Claim", func() -> void: print("WORKBENCH: claim %s" % entry.get("title", "")), pill_font)
	claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(claim)
	return panel

## The whole Mail dialog (mockup image 3): a parchment card with the gold banner + envelope, a
## docked ✕, and a column of mail_cards. COMPOSES mail_card for every entry.
static func mail_dialog(entries: Array, pill_font: int = 18, pill_icon: float = 24.0, width: float = 560.0) -> Control:
	var wrap := Control.new()

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	card.custom_minimum_size = Vector2(width, 0)
	card.position = Vector2.ZERO
	wrap.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	var header := Look.banner_title("Mail", 32, BANNER_H, "mail/mail_banner.png")
	header.size_flags_horizontal = Control.SIZE_FILL
	col.add_child(header)
	if ResourceLoader.exists(Look.kit("mail/mail_banner.png")):
		var env := Look.icon("mail", 54)
		env.anchor_left = 0.30; env.anchor_right = 0.30
		env.anchor_top = 0.5; env.anchor_bottom = 0.5
		env.grow_horizontal = Control.GROW_DIRECTION_BOTH
		env.grow_vertical = Control.GROW_DIRECTION_BOTH
		env.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(env)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for e in entries:
		rows.add_child(mail_card(e, pill_font, pill_icon))
	col.add_child(rows)

	# the ✕ disc docks at the card's top-right corner once the card has laid out + sized.
	var close := Look.close_button(func() -> void: print("WORKBENCH: mail closed"), "kit/mail_close.png")
	wrap.add_child(close)
	var dock := func() -> void:
		if not is_instance_valid(card) or not is_instance_valid(close):
			return
		wrap.custom_minimum_size = card.size
		var xs: float = close.custom_minimum_size.x
		close.position = Vector2(card.size.x - xs + 12.0, -12.0)
	card.resized.connect(dock)
	card.ready.connect(dock)
	return wrap
