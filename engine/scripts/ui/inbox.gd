extends RefCounted
## THE MAILBOX surface — the diegetic LiveOps inbox popup (HUD chrome · §13). A parchment
## card framing a scrollable list of operator messages (gifts / compensation / news): each
## row is an icon + a title + a short body, with a Claim button + a reward chip when the
## message carries an unclaimed gift. Claiming pays the reward (core/inbox.gd), plays a small
## reward shout, and refreshes the row in place. Opening marks everything read.
##
## The list + the claim/grant live in core/inbox.gd; this is only its face. Reuses the Look
## kit + the FX vocabulary exactly like ui/login.gd / ui/vault.gd (the modal idiom: a veil
## that taps away to dismiss, a centered parchment card, FX.pop_in, every node
## MOUSE_FILTER_IGNORE except the veil + the buttons). Rewards are icon SPRITES beside a
## number (emoji-purge §13), never a glyph baked into text.

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

const CARD_MAX_W := 460.0
const CARD_VW_FRAC := 0.92
const LIST_MAX_H := 480.0          # the scroll area's ceiling — a long inbox scrolls, never grows the card

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
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	# title — engine text on a kit ribbon (images never carry words, §13.3)
	var ribbon := Look.title_ribbon(host.tr("Mailbox"), 30)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ribbon)

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

	_fill_rows(host, rows, scroll, card_w)

	# the Close CTA
	var close := Look.button(host.tr("Close"), func() -> void: overlay.queue_free(), false)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(close)

	# opening the mailbox reads everything (the badge then rests on unclaimed gifts only)
	Inbox.mark_all_read()
	FX.pop_in(card)

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

# One message: an icon, the title + body text, and (when there's an unclaimed gift) a reward
# chip + a Claim button. A claimed gift shows a quiet "Claimed" tag instead.
static func _message_row(host: Control, m: Dictionary, rows: VBoxContainer, scroll: ScrollContainer, card_w: float) -> Control:
	var panel := PanelContainer.new()
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

	# the message icon (sprite when generated, else its glyph)
	var ic := Look.icon(String(m.get("icon", "star")), 40)
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
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", INK)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)
	var body := Label.new()
	body.text = host.tr(String(m.get("body", "")))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(card_w - 200.0, 0)
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(BARK, 0.95))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(body)

	# the reward affordance — a Claim button + reward chip when there's an unclaimed gift,
	# a quiet "Claimed" tag once grabbed, nothing at all for a plain news note.
	var rew: Dictionary = m.get("reward", {})
	if _reward_total(rew) > 0:
		var side := VBoxContainer.new()
		side.alignment = BoxContainer.ALIGNMENT_CENTER
		side.add_theme_constant_override("separation", 4)
		side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(side)
		side.add_child(_reward_chip(host, rew))
		if not bool(m.get("claimed", false)):
			var id := String(m.get("id", ""))
			var claim := Look.button(host.tr("Claim"), func() -> void:
				var at := panel.get_global_rect().get_center()
				var granted := Inbox.claim(id)
				if not granted.is_empty():
					_celebrate(host, at, granted)
				_fill_rows(host, rows, scroll, card_w), true)
			claim.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			side.add_child(claim)
		else:
			var done := Label.new()
			done.text = host.tr("Claimed")
			done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			done.add_theme_font_size_override("font_size", 14)
			done.add_theme_color_override("font_color", Color(LEAF.darkened(0.1), 0.95))
			side.add_child(done)
			panel.modulate = Color(1, 1, 1, 0.7)
	return panel

# A reward's components as icon sprites + numbers (emoji-purge §13) — shows every non-zero
# part (coins / 💎 / water) so the player sees exactly what the Claim grants.
static func _reward_chip(host: Control, rew: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair in [["coin", int(rew.get("coins", 0))], ["gem", int(rew.get("gems", 0))], ["water", int(rew.get("water", 0))]]:
		if int(pair[1]) <= 0:
			continue
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(Look.icon(String(pair[0]), 20))
		var l := Label.new()
		l.text = str(int(pair[1]))
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", INK)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(l)
		row.add_child(cell)
	return row

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
