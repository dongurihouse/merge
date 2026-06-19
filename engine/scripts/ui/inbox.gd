extends RefCounted
## THE MAILBOX surface — the diegetic LiveOps inbox popup (HUD chrome · §13). A parchment
## card framing a scrollable list of operator messages (gifts / compensation / news): each
## row is an icon + a title + a short body, with a Claim button + a reward chip when the
## message carries an unclaimed gift. Claiming pays the reward (core/inbox.gd), plays a small
## reward shout, and refreshes the row in place. Opening marks everything read.
##
## The list + the claim/grant live in core/inbox.gd; this is only its face. Skinned from the
## sliced MAIL KIT (mail.png → ui/mail + ui/kit) over the SHARED popup components (skin.gd), the
## same component language the shop + bag speak: the parchment panel (Look.kit_panel), the gold
## ribbon header (Look.banner_title, here the mail banner + the envelope motif), the round ✕ disc
## (Look.close_button, here the mail close), and the kit nine-patch box (Look.kit_box) for the
## message-row card + the green Claim / reward pills. The modal idiom matches login/vault: a veil
## that taps away to dismiss, a centered card, FX.pop_in, every node MOUSE_FILTER_IGNORE except the
## veil + the buttons. Rewards are icon SPRITES beside a number (emoji-purge §13), never a glyph.

const Save = preload("res://engine/scripts/core/save.gd")
const Inbox = preload("res://engine/scripts/core/inbox.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

const INK := Pal.INK
const CREAM := Pal.CREAM
const STRAW := Pal.STRAW
const BARK := Pal.BARK
const LEAF := Pal.LEAF

const CARD_MAX_W := 520.0          # wide enough to seat icon + title/body + reward pill + Claim in one row
const CARD_VW_FRAC := 0.92
const LIST_MAX_H := 480.0          # the scroll area's ceiling — a long inbox scrolls, never grows the card
const BANNER_H := 92.0             # the mail-ribbon header band
const MSG_ICON := 60.0             # a message's plated icon (gift / leaf / news / coin)
const CLOSE_MARGIN := 12.0         # the ✕ disc's inset from the card's top-right corner
const ROW_TEX_MARGIN := Vector2(30, 30)   # the mail_card nine-patch border (448×105 source)
const PILL_TEX := Vector2(46, 34)         # the mail_pill capsule nine-patch (cap-preserving — 220×77 / 180×76 source)

# --- the mailbox popup --------------------------------------------------------------

static func open(host: Control) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	host.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(INK, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	var vw: float = host.get_viewport_rect().size.x
	var card_w: float = minf(CARD_MAX_W, vw * CARD_VW_FRAC)
	card.custom_minimum_size = Vector2(card_w, 0)
	cc.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	# header — the mail ribbon with engine "Mail" riding it (images never carry words, §13.3) and
	# the envelope motif perched on its left. Both ride the SHARED banner builder; the envelope is
	# overlaid only when the real ribbon art is present (the text-chip fallback has no band to perch on).
	var header := Look.banner_title(host.tr("Mail"), 32, BANNER_H, "mail/mail_banner.png")
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

	# the message list, in a scroll so a long inbox never grows the card past LIST_MAX_H
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(card_w - 40.0, 0)
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)

	# the round ✕ disc (the mail close) docks inside the card's top-right corner. The async fill
	# below GROWS the card, so placing on open would freeze the ✕ at the short card's centred
	# position — instead it is placed once the rows have filled and the card settles, and resized
	# keeps it pinned through any later relayout (a claim rebuild). The veil tap dismisses too.
	var close := Look.close_button(func() -> void: overlay.queue_free(), "kit/mail_close.png")
	overlay.add_child(close)
	var place := func() -> void:
		if not is_instance_valid(card) or not is_instance_valid(close):
			return
		var r := card.get_global_rect()
		var cw: float = close.custom_minimum_size.x
		close.global_position = Vector2(
			r.position.x + r.size.x - cw - CLOSE_MARGIN, r.position.y + CLOSE_MARGIN)
	card.resized.connect(place)

	# opening the mailbox reads everything (the badge then rests on unclaimed gifts only)
	Inbox.mark_all_read()
	FX.pop_in(card)

	# fill the rows, then pin the ✕ once the card has reached its final size + centred position
	await _fill_rows(host, rows, scroll, card_w)
	await host.get_tree().process_frame
	place.call()

# (Re)build every message row. Called on open and after each claim so a grabbed gift's Claim
# button collapses to a "Claimed" tag in place without rebuilding the whole modal.
static func _fill_rows(host: Control, rows: VBoxContainer, scroll: ScrollContainer, card_w: float) -> void:
	for c in rows.get_children():
		c.queue_free()
	var list := Inbox.messages()
	if list.is_empty():
		var empty := Label.new()
		empty.text = host.tr("No mail right now — check back soon.")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 17)
		empty.add_theme_color_override("font_color", Color(BARK, 0.9))
		rows.add_child(empty)
	for m in list:
		rows.add_child(_message_row(host, m, rows, scroll, card_w))
	# clamp the scroll height so a long list scrolls instead of overflowing the screen
	await host.get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.custom_minimum_size.y = minf(LIST_MAX_H, rows.size.y)

# One message: a plated icon, the title + body text, and (when there's an unclaimed gift) a reward
# chip + a Claim button. A claimed gift shows a quiet "Claimed" tag instead. The row rides the
# sliced mail_card nine-patch (cream parchment tile), with a code-drawn card box as the fallback.
static func _message_row(host: Control, m: Dictionary, rows: VBoxContainer, scroll: ScrollContainer, card_w: float) -> Control:
	var panel := PanelContainer.new()
	var box := Look.kit_box("kit/mail_card.png", ROW_TEX_MARGIN, Vector4(18, 12, 18, 12))
	if box != null:
		panel.add_theme_stylebox_override("panel", box)
	else:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(CREAM, 0.5)
		s.set_corner_radius_all(14)
		s.set_border_width_all(1)
		s.border_color = Color(BARK, 0.4)
		s.content_margin_left = 12; s.content_margin_right = 12
		s.content_margin_top = 10; s.content_margin_bottom = 10
		panel.add_theme_stylebox_override("panel", s)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	# the message icon (plated mail-kit sprite when generated, else its glyph)
	var ic := Look.icon(String(m.get("icon", "star")), MSG_ICON)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)

	# the text column — title (bold-ish, INK) over a wrapped body line
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var title := Label.new()
	title.text = host.tr(String(m.get("title", "")))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # wrap (never overflow) so the reward + Claim stay seated on the row
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", INK)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)
	var body := Label.new()
	body.text = host.tr(String(m.get("body", "")))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(BARK, 0.95))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(body)

	# the reward affordance — the reward chip + a Claim button SIDE BY SIDE on the row's right
	# (cream count pill, then the green Claim — the mockup layout), a quiet "Claimed" tag once
	# grabbed, nothing at all for a plain news note. All vertically centered against the text.
	var rew: Dictionary = m.get("reward", {})
	if _reward_total(rew) > 0:
		var chip := _reward_chip(host, rew)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
		if not bool(m.get("claimed", false)):
			var id := String(m.get("id", ""))
			var claim := _claim_button(host, func() -> void:
				var at := panel.get_global_rect().get_center()
				var granted := Inbox.claim(id)
				if not granted.is_empty():
					_celebrate(host, at, granted)
				_fill_rows(host, rows, scroll, card_w))
			claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(claim)
		else:
			var done := Label.new()
			done.text = host.tr("Claimed")
			done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			done.add_theme_font_size_override("font_size", 14)
			done.add_theme_color_override("font_color", Color(LEAF.darkened(0.1), 0.95))
			done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(done)
			panel.modulate = Color(1, 1, 1, 0.7)
	return panel

# The green "Claim" button — the sliced mail_pill capsule nine-patch carrying engine text, with the
# shared press juice. Falls back to the shared green primary pill (Look.button) when the art is absent.
static func _claim_button(host: Control, cb: Callable) -> Button:
	var box := Look.kit_box("kit/mail_pill.png", PILL_TEX, Vector4(24, 8, 24, 8))
	if box == null:
		return Look.button(host.tr("Claim"), cb, true)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = host.tr("Claim")
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", CREAM)
	b.add_theme_color_override("font_pressed_color", CREAM)
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", box)
	var bp: StyleBoxTexture = box.duplicate()
	bp.modulate_color = Color(0.88, 0.88, 0.88)
	b.add_theme_stylebox_override("pressed", bp)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Look.add_press_juice(b)
	b.pressed.connect(func() -> void: cb.call())
	return b

# A reward's components as icon sprites + numbers (emoji-purge §13) — shows every non-zero part
# (coins / 💎 / water) so the player sees exactly what the Claim grants. The cluster rides the
# sliced CREAM capsule (mail_pill_cream — green is reserved for the Claim CTA, §mockup), dark INK
# numbers for contrast; a bare row when the art is absent.
static func _reward_chip(host: Control, rew: Dictionary) -> Control:
	# currencies STACK vertically inside the pill (one icon+number per line) so the chip stays
	# NARROW whatever the count — a 3-currency compensation gift doesn't crowd out the row's text.
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := Look.kit_box("kit/mail_pill_cream.png", PILL_TEX, Vector4(14, 6, 14, 6))
	for pair in [["coin", int(rew.get("coins", 0))], ["gem", int(rew.get("gems", 0))], ["water", int(rew.get("water", 0))]]:
		if int(pair[1]) <= 0:
			continue
		var cell := HBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 3)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(Look.icon(String(pair[0]), 20))
		var l := Label.new()
		l.text = str(int(pair[1]))
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", INK)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(l)
		col.add_child(cell)
	if box == null:
		return col
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", box)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(col)
	return pill

# Play the claimed gift's juice — a small reward shout per granted component (mirrors the
# login calendar's _celebrate, kept simple).
static func _celebrate(host: Control, at: Vector2, rew: Dictionary) -> void:
	Audio.play("merge_success", -3.0, 1.2)
	var dy := 0.0
	if int(rew.get("gems", 0)) > 0:
		FX.celebrate_reward(host, at + Vector2(0, dy), "gem", int(rew.gems), Color("#A9C7E8")); dy += 34
	if int(rew.get("coins", 0)) > 0:
		FX.celebrate_reward(host, at + Vector2(0, dy), "coin", int(rew.coins), STRAW); dy += 34
	if int(rew.get("water", 0)) > 0:
		FX.celebrate_reward(host, at + Vector2(0, dy), "water", int(rew.water), Color("#9CCDE8")); dy += 34

static func _reward_total(rew: Dictionary) -> int:
	return int(rew.get("coins", 0)) + int(rew.get("gems", 0)) + int(rew.get("water", 0))
