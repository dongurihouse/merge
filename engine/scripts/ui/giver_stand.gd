extends RefCounted
## The giver-stand BUILDER (Wave 3, fence slice 1) — pure construction of one quest-giver
## stand on the §7 fence: the chest-up bust over the rail, the ask pill (1–3 asks + progress),
## the +N★ shoulder reward, and the ready-check that docks on the pill. (Featured-ness is NOT
## surfaced here — the flag/bonus pay out silently; see the note in make().) Stateless: state
## (the quests array, payability) stays in the board
## coordinator; this only assembles nodes and returns their refs. Tap behaviour is injected as
## `Callable`s so this never reaches up into scenes/ (the §15 layering invariant).
##
## Usage:  GiverStand.make(qi, q, {
##           "ask_tap": Callable(line, tier),   # an ask icon was tapped → open its ladder
##           "stand_tap": Callable(qi, chip),   # the stand was tapped → try to deliver
##           "wire_tap": Callable(node, action),# the coordinator's still-release tap wirer
##           "stand_w": float, "fence_h": float})
## Returns {chip, qi, asks:[{code, need, prog}], check, bust} — the same entry board.gd's
## giver_chips holds, so _refresh_giver_lights / _giver_is_payable read it unchanged.

const G = preload("res://engine/scripts/core/content.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Quests = preload("res://engine/scripts/core/quests.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Bust = preload("res://engine/scripts/ui/bust.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const STRAW = Game.PALETTE.STRAW
const CREAM = Game.PALETTE.CREAM
const BARK = Game.PALETTE.BARK
const INK = Game.PALETTE.INK

# AB: the giver pops over the fence UNFRAMED — the chest-up cutout IS the UI. The ask rides a
# small content-sized cream pill UNDER them; the +N★ reward floats at the shoulder; a green
# check docks on the pill's corner when payable. No card, no border ring — the fence breathes.
static func make(qi: int, q: Dictionary, cfg: Dictionary) -> Dictionary:
	var sw: float = cfg.stand_w
	var fh: float = cfg.fence_h
	var ask_tap: Callable = cfg.ask_tap
	var stand_tap: Callable = cfg.stand_tap
	var wire_tap: Callable = cfg.wire_tap
	var stand := Control.new()
	stand.custom_minimum_size = Vector2(sw, fh)
	stand.pivot_offset = Vector2(sw / 2.0, fh * 0.5)
	# A HORIZONTAL quest card (reference layout): the character PORTRAIT on the left, the
	# requested item LARGE in the speech bubble on the right. The painted `card_quest.png`
	# IS the card (its bubble sits upper-right); a flat parchment card is the fallback.
	var cardW := sw - 14.0
	var cardH := minf(fh - 24.0, cardW * 0.60)
	var cx := (sw - cardW) / 2.0
	var cy := (fh - cardH) / 2.0
	var card := _quest_card(cardW, cardH)
	card.position = Vector2(cx, cy)
	card.size = Vector2(cardW, cardH)
	stand.add_child(card)
	# the character portrait — left ~40% of the card, vertically centered
	var bsz := cardH * 0.82
	var bust := Bust.make(qi % 2, bsz)
	bust.position = Vector2(cx + cardW * 0.04, cy + (cardH - bsz) / 2.0)
	stand.add_child(bust)
	# Tier 2 §2: the idle-bob is gated by _refresh_giver_lights (it carries "deliverable").
	bust.tree_entered.connect(func() -> void:
		if is_instance_valid(bust) and bust.is_inside_tree():
			FX.pop_in(bust), CONNECT_ONE_SHOT)
	# the requested item(s) — large, inside the speech bubble (right portion of the card)
	var asks: Array = G.quest_asks(q)
	var ask_uis: Array = []
	# the painted bubble sits in the card's RIGHT third (centre ~0.82w, 0.41h of card_quest.png);
	# the item is centred on it so it reads as "spoken" from the bubble, not floating mid-card.
	var bub := Vector2(cx + cardW * 0.82, cy + cardH * 0.41)   # bubble centre (matches the art)
	if q.has("grant"):                        # §6: a generator-grant quest shows the NEW generator to receive
		var gdef: Dictionary = G.gen_def(G.GENERATORS, String(q.grant.grants))
		var gtex := Game.art(String(gdef.get("tex", "")))
		if ResourceLoader.exists(gtex):
			var gicon := TextureRect.new()
			gicon.texture = load(gtex)
			gicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			gicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			gicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var gs := cardH * 0.5
			gicon.size = Vector2(gs, gs)
			gicon.position = bub - Vector2(gs, gs) / 2.0
			stand.add_child(gicon)
	var isz := (cardH * 0.36) if asks.size() >= 2 else (cardH * 0.46)   # sized to sit INSIDE the bubble
	var span := isz * 0.88
	for ai in asks.size():
		var ask: Dictionary = asks[ai]
		var aline := int(ask.line)
		var atier := int(ask.tier)
		var acode := aline * 100 + atier
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(isz, isz)
		icon.size = Vector2(isz, isz)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP   # tapping the ITEM shows its ladder
		# centre the item(s) on the bubble; multi-ask spreads them around it
		var off := (float(ai) - (asks.size() - 1) / 2.0) * span
		icon.position = Vector2(bub.x - isz / 2.0 + off, bub.y - isz / 2.0)
		var piece := PieceView.make_piece(acode, isz)
		icon.add_child(piece)
		# #4: the count chip shows ONLY when more than one is wanted (no lone "1")
		var badge: PanelContainer = null
		var badge_lbl: Label = null
		if int(ask.count) > 1:
			badge = _count_badge(int(ask.count))
			badge.anchor_left = 1.0; badge.anchor_top = 1.0; badge.anchor_right = 1.0; badge.anchor_bottom = 1.0
			badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
			badge.offset_left = 5.0; badge.offset_top = 5.0; badge.offset_right = 5.0; badge.offset_bottom = 5.0
			icon.add_child(badge)
			badge_lbl = badge.get_child(0)
		var mpx := isz * 0.85                               # big disc that overtakes the item
		var met := _ask_met_check(mpx)                      # green ✓, centered, hidden until satisfied
		met.position = Vector2((isz - mpx) / 2.0, (isz - mpx) / 2.0)
		icon.add_child(met)
		wire_tap.call(icon, func() -> void: ask_tap.call(aline, atier))
		stand.add_child(icon)
		ask_uis.append({"code": acode, "need": int(ask.count), "piece": piece, "badge": badge, "badge_lbl": badge_lbl, "met": met})
	# the +N★ reward — a small bare star + count, tucked in the card's TOP-RIGHT corner
	var pay := HBoxContainer.new()
	pay.add_theme_constant_override("separation", 1)
	pay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pay.add_child(Look.icon("star", 26.0))
	var pay_lbl := Label.new()
	pay_lbl.text = "+%d" % Quests.stars(q)
	pay_lbl.add_theme_font_size_override("font_size", 22)
	pay_lbl.add_theme_color_override("font_color", STRAW)
	pay_lbl.add_theme_color_override("font_outline_color", Color("#33402F"))
	pay_lbl.add_theme_constant_override("outline_size", 5)
	pay_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pay.add_child(pay_lbl)
	pay.position = Vector2(cx + cardW - 78.0, cy + 6.0)
	stand.add_child(pay)
	# §7 FEATURED is intentionally NOT surfaced on the board: quests aren't skippable, so a
	# "this one's special" highlight (or a +N💎 shoulder) is noise the player can't act on. The
	# `featured` flag + its coins/premium bonus still ride in the quest data and pay out silently
	# on hand-in (board.gd). A real surface — where featured-ness DOES drive a choice (a daily/
	# event "do a featured quest" hook, §17/§18) — is parked in the backlog.
	# the ready check is now per-ask (the big centered ✓ over each item), so there is no
	# separate stand-level check. The "check" key stays in the result for board.gd, set to
	# null (the board already guards it with `if check != null and is_instance_valid(check)`).
	wire_tap.call(stand, func() -> void: stand_tap.call(qi, stand))
	return {"chip": stand, "qi": qi, "asks": ask_uis, "check": null, "bust": bust}

# The quest card surface: the painted `ui/kit/card_quest.png` (horizontal speech-bubble card)
# stretched to the card rect; a flat parchment card when the art is absent.
static func _quest_card(w: float, h: float) -> Control:
	var p := Look.kit("card_quest.png")
	if ResourceLoader.exists(p):
		var t := TextureRect.new()
		t.texture = load(p)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	var card := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FBF1D8", 0.98)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(3)
	sb.border_color = Color("#C9A66B")
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 7
	sb.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card

# AB2: the shared ask pill — content-sized cream tray (StyleBoxFlat, soft warm
# border + shadow), anchored to center on its parent's x and grow both ways.
# Public: the merchant stand (board.gd) rides the same pill.
static func ask_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("#FBF6EC", 0.96)
	ps.set_corner_radius_all(18)
	ps.set_border_width_all(2)
	ps.border_color = Color("#C9A66B", 0.85)
	ps.shadow_color = Color(0, 0, 0, 0.22)
	ps.shadow_size = 4
	ps.shadow_offset = Vector2(0, 2)
	ps.content_margin_left = 14.0
	ps.content_margin_right = 16.0
	ps.content_margin_top = 7.0
	ps.content_margin_bottom = 7.0
	pill.add_theme_stylebox_override("panel", ps)
	pill.anchor_left = 0.5
	pill.anchor_right = 0.5
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pill

# #4: the per-ask COUNT CHIP — a small high-contrast cream sticker that rides the
# item's bottom-right corner showing the wanted count (wordless: a number, no "/m").
# The chip's number is updated live and its fill greens to a soft sage when this ask
# is satisfied (have >= need) so a met ask reads "done" even before the ✓ lands.
# child(0) is the Label (board.gd reads it to retint/leave the number as-is).
static func _count_badge(need: int) -> PanelContainer:
	var chip := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = CREAM
	cs.set_corner_radius_all(11)
	cs.set_border_width_all(2)
	cs.border_color = BARK
	cs.shadow_color = Color(0, 0, 0, 0.28)
	cs.shadow_size = 2
	cs.shadow_offset = Vector2(0, 1)
	cs.content_margin_left = 6.0
	cs.content_margin_right = 6.0
	cs.content_margin_top = 0.0
	cs.content_margin_bottom = 0.0
	chip.add_theme_stylebox_override("panel", cs)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = "%d" % need
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", INK)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(16, 0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(lbl)
	return chip

# #4: the per-ask green ✓ — a BIG round disc that overtakes the item when its single
# ask is satisfied (centered over the icon, not a corner sticker). Sized by the caller
# to ~85% of the item so a single large mark reads "this one's ready". This is now the
# ONLY check on the stand — the old stand-level bottom-right check was removed.
static func _ask_met_check(px: float) -> Panel:
	var mark := Panel.new()
	mark.custom_minimum_size = Vector2(px, px)
	mark.size = Vector2(px, px)
	var mbg := StyleBoxFlat.new()
	mbg.bg_color = Color("#5CAF5C")
	mbg.set_corner_radius_all(int(px / 2.0))
	mbg.set_border_width_all(3)
	mbg.border_color = CREAM
	mbg.shadow_color = Color(0, 0, 0, 0.28)
	mbg.shadow_size = 4
	mbg.shadow_offset = Vector2(0, 2)
	mark.add_theme_stylebox_override("panel", mbg)
	var mi := Look.icon("check", px * 0.7)
	mi.set_anchors_preset(Control.PRESET_FULL_RECT)
	if mi is Label:
		(mi as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(mi as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_child(mi)
	mark.visible = false
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return mark

# keep the check pinned to the (content-sized, centered) pill's top-left corner
static func _dock_check(check: Control, pill: Control, stand: Control) -> void:
	var dock := func() -> void:
		if not (is_instance_valid(check) and is_instance_valid(pill) and is_instance_valid(stand)):
			return
		check.position = pill.get_global_rect().position - stand.get_global_rect().position - Vector2(14.0, 14.0)
	pill.resized.connect(dock)
	dock.call_deferred()

# AB1: slow ±4px sine bob (~3s) on a bust. Tier 2 §2: the bob now carries "ready"
# information — only a DELIVERABLE giver bobs, so callers gate it with `active`
# (driven by _giver_is_payable in _refresh_giver_lights). The merchant, which is not
# a deliverable giver, keeps the default always-on bob.
#
# Idempotent + reversible: the live loop tween is parked in the "bob_tw" meta and the
# rest-Y baseline in "bob_y" (captured ONCE, so toggling never drifts the baseline
# mid-flight). active=true starts the loop if not already running; active=false kills
# it and settles the bust back to rest.
static func bob(bust: Control, active: bool = true) -> void:
	if not Features.on("giver_bob"):
		return
	if not bust.has_meta("bob_y"):
		bust.set_meta("bob_y", bust.position.y)
		bust.set_meta("bob_tw", null)         # seed so later get_meta("bob_tw") never errors on a missing key (Godot 4.6 logs even with a default)
	if not active:
		bob_stop(bust)
		return
	var existing: Variant = bust.get_meta("bob_tw") if bust.has_meta("bob_tw") else null
	if existing is Tween and (existing as Tween).is_valid():
		return                                    # already bobbing — don't stack tweens
	# start now if already in the tree (the reactive payable case), else on entry
	if bust.is_inside_tree():
		bob_start(bust)
	else:
		bust.tree_entered.connect(func() -> void:
			# only (re)start if still wanted, and not already bobbing, when we enter the tree
			if not is_instance_valid(bust) or not bust.is_inside_tree():
				return
			# bob_tw may be unseeded here (e.g. the merchant bust): get_meta(key, null) ERRORS on a
			# missing key in Godot 4.6 — guard with has_meta to avoid the stderr spam (T35 missed this read)
			var tw: Variant = bust.get_meta("bob_tw") if bust.has_meta("bob_tw") else null
			if not (tw is Tween and (tw as Tween).is_valid()):
				bob_start(bust), CONNECT_ONE_SHOT)

static func bob_start(bust: Control) -> void:
	var by: float = bust.get_meta("bob_y", bust.position.y)
	var tw := bust.create_tween().set_loops()
	tw.tween_property(bust, "position:y", by - 4.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(bust, "position:y", by, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bust.set_meta("bob_tw", tw)

static func bob_stop(bust: Control) -> void:
	if bust.has_meta("bob_tw"):
		var existing: Variant = bust.get_meta("bob_tw")
		if existing is Tween and (existing as Tween).is_valid():
			(existing as Tween).kill()
		bust.set_meta("bob_tw", null)
	if bust.has_meta("bob_y"):
		bust.position.y = bust.get_meta("bob_y")   # settle to rest
