extends RefCounted
## The giver-stand BUILDER (Wave 3, fence slice 1) — pure construction of one quest-giver
## card on the §7 fence. Reskinned to the painted `ui/quest/card_quest.png` (board1 art): a
## VERTICAL parchment card with a gold frame and a wooden reward plaque baked into the bottom.
## The engine draws the live content ON TOP: the character portrait in the card field, the
## requested item in a cream ask-bubble (item over an "N/1" count) at the top-right, and the
## +N reward centred on the painted plaque. The per-item green ✓ overtakes the item when payable.
## (Featured-ness is NOT surfaced here — the flag/bonus pay out silently; see the note in make().)
## Stateless: state (the quests array, payability) stays in the board coordinator; this only
## assembles nodes and returns their refs. Tap behaviour is injected as `Callable`s so this
## never reaches up into scenes/ (the §15 layering invariant).
##
## Usage:  GiverStand.make(qi, q, {
##           "ask_tap": Callable(line, tier),   # the ask bubble was tapped → open its ladder
##           "stand_tap": Callable(qi, chip),   # the stand was tapped → try to deliver
##           "wire_tap": Callable(node, action),# the coordinator's still-release tap wirer
##           "stand_w": float, "fence_h": float})
## Returns {chip, qi, item:{code, piece, met, count}, check, bust} — the same entry board.gd's
## giver_chips holds, so _refresh_giver_lights / _giver_is_payable read it (the new `count` label
## is flipped 0/1 ↔ 1/1 there alongside the ✓).

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

# the painted card's native size (ui/quest/card_quest.png — island 5 of board_asset.png): a wide
# box with a speech bubble baked into the right side. Width follows this ratio off the fence-bound
# height so the art never stretches.
const CARD_ART_W := 417.0
const CARD_ART_H := 239.0
const PLAQUE_PATH := "quest/plaque.png"   # the reusable wooden reward sign (island 6 of board1_asset2.png)
const PLAQUE_AR := 202.0 / 110.0          # plaque art aspect, so it never stretches

# A wide quest BOX (board_asset reskin): the 9-sliced painted box fills the stand. The character
# bust sits LARGE on the LEFT (filling top↔bottom, free to overflow the box), the requested item
# rides a CLEAR drawn speech bubble on the RIGHT (one big item — every quest needs exactly one), and
# the +N reward sits centred on the reusable wooden plaque hung at the bottom-centre (over the bust).
# No level badge, no count. No separate stand-level check — the per-item ✓ is the ready signal.
static func make(qi: int, q: Dictionary, cfg: Dictionary) -> Dictionary:
	var sw: float = cfg.stand_w
	var fh: float = cfg.fence_h
	var ask_tap: Callable = cfg.ask_tap
	var stand_tap: Callable = cfg.stand_tap
	var wire_tap: Callable = cfg.wire_tap
	var stand := Control.new()
	stand.custom_minimum_size = Vector2(sw, fh)
	stand.pivot_offset = Vector2(sw / 2.0, fh * 0.5)
	# the box: width follows the art ratio off the fence-bound height, but never overflows the stand
	# width (the wide box is usually width-bound). A little headroom is left below for the hung plaque.
	var artR := CARD_ART_W / CARD_ART_H
	var cardH := (fh - 16.0) * 0.86            # leave room under the box for the overhanging plaque
	var cardW := cardH * artR
	if cardW > sw - 8.0:                        # never overflow the stand width
		cardW = sw - 8.0
		cardH = cardW / artR
	var cx := (sw - cardW) / 2.0
	var cy := (fh - cardH) / 2.0 - cardH * 0.07   # nudge the box up so the plaque hangs in-band
	var card := _quest_card(cardW, cardH)
	card.position = Vector2(cx, cy)
	card.size = Vector2(cardW, cardH)
	stand.add_child(card)
	# the character portrait — LARGE on the LEFT, filling the box top↔bottom and free to overflow its
	# edges. Drawn before the plaque so the plaque hangs in FRONT of it.
	var bsz := cardH * 1.08
	var bust := Bust.make(qi % 3, bsz)
	bust.position = Vector2(cx + cardW * 0.275 - bsz / 2.0, cy + cardH * 0.50 - bsz / 2.0)
	stand.add_child(bust)
	# Tier 2 §2: the idle-bob is gated by _refresh_giver_lights (it carries "deliverable").
	bust.tree_entered.connect(func() -> void:
		if is_instance_valid(bust) and bust.is_inside_tree():
			FX.pop_in(bust), CONNECT_ONE_SHOT)
	# the requested item — one big icon in a CLEAR drawn speech bubble on the box's right (~0.73w,
	# 0.40h). The bubble's tail points back toward the character; the ✓ overtakes the item when ready.
	var it: Dictionary = G.quest_item(q)
	var item_ui: Dictionary = {}
	if not it.is_empty():
		var acode := int(it.line) * 100 + int(it.tier)
		var bd := cardH * 0.62                       # bubble diameter
		var bubble := _speech_bubble(bd)
		bubble.position = Vector2(cx + cardW * 0.735 - bd / 2.0, cy + cardH * 0.40 - bd / 2.0)
		var isz := bd * 0.70                          # the big item fills the bubble
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(isz, isz)
		icon.size = Vector2(isz, isz)
		icon.position = Vector2((bd - isz) / 2.0, (bd - isz) / 2.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var piece := PieceView.make_piece(acode, isz)
		icon.add_child(piece)
		var mpx := isz * 0.88
		var met := _ask_met_check(mpx)
		met.position = Vector2((isz - mpx) / 2.0, (isz - mpx) / 2.0)
		icon.add_child(met)
		bubble.add_child(icon)
		stand.add_child(bubble)
		wire_tap.call(bubble, func() -> void: ask_tap.call(int(it.line), int(it.tier)))
		item_ui = {"code": acode, "piece": piece, "met": met}
	# the near-end map quest ALSO rewards the next map's generator — preview its tool icon as a small
	# badge tucked at the box's top-right, so the player sees the bonus they'll earn.
	if q.has("reward") and (q.reward as Dictionary).has("generators") and not (q.reward.generators as Array).is_empty():
		var gdef: Dictionary = G.gen_def(G.GENERATORS, String(q.reward.generators[0]))
		var gtex := Game.art(String(gdef.get("tex", "")))
		if ResourceLoader.exists(gtex):
			var gs := cardH * 0.24
			var gicon := TextureRect.new()
			gicon.texture = load(gtex)
			gicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			gicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			gicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gicon.size = Vector2(gs, gs)
			gicon.position = Vector2(cx + cardW * 0.92 - gs, cy + cardH * 0.04)
			stand.add_child(gicon)
	# the reusable wooden PLAQUE — hung at the bottom-centre, overhanging the box's lower edge, in
	# FRONT of the bust, with the +N reward (flower/star + WHITE count) centred on its wooden face.
	var plw := cardW * 0.46
	var plh := plw / PLAQUE_AR
	var ptop := cy + cardH - plh * 0.62          # ~38% of the plaque overhangs below the box edge
	var plaque := _reward_plaque(plw, plh)
	plaque.position = Vector2(cx + cardW * 0.50 - plw / 2.0, ptop)
	stand.add_child(plaque)
	var pcx := cx + cardW * 0.50
	var pcy := ptop + plh * 0.50                  # the plaque sprite (= wood face) centre
	var pay := HBoxContainer.new()
	pay.add_theme_constant_override("separation", 3)
	pay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pay.add_child(Look.icon("star", plh * 0.50))
	var pay_lbl := Label.new()
	pay_lbl.text = "+%d" % Quests.stars(q)
	pay_lbl.add_theme_font_size_override("font_size", int(plh * 0.42))
	pay_lbl.add_theme_color_override("font_color", Color.WHITE)
	pay_lbl.add_theme_constant_override("outline_size", 0)             # solid plaque behind — no halo
	pay_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pay.add_child(pay_lbl)
	# centre the pair on the plaque face. Driven by resized — fires only while `pay` is alive + in-tree
	# (a stand freed before idle would otherwise fire this over a freed `pay`, the §120 freed-capture).
	var place_pay := func() -> void:
		pay.position = Vector2(pcx - pay.size.x / 2.0, pcy - pay.size.y / 2.0)
	pay.resized.connect(place_pay)
	stand.add_child(pay)
	# §7 FEATURED is intentionally NOT surfaced on the board: quests aren't skippable, so a
	# "this one's special" highlight (or a +N💎 shoulder) is noise the player can't act on. The
	# `featured` flag + its coins/premium bonus still ride in the quest data and pay out silently
	# on hand-in (board.gd). A real surface — where featured-ness DOES drive a choice (a daily/
	# event "do a featured quest" hook, §17/§18) — is parked in the backlog.
	# the ready check is per-item (the big centered ✓ over the item), so there is no separate
	# stand-level check. The "check" key stays in the result for board.gd, set to null (the board
	# already guards it with `if check != null and is_instance_valid(check)`).
	wire_tap.call(stand, func() -> void: stand_tap.call(qi, stand))
	return {"chip": stand, "qi": qi, "item": item_ui, "check": null, "bust": bust}

# The quest card surface: the painted `ui/quest/card_quest.png` (vertical gold-framed parchment
# card with the reward plaque baked into the bottom) stretched to the card rect; a flat parchment
# card when the art is absent.
static func _quest_card(w: float, h: float) -> Control:
	var p := Look.kit("quest/card_quest.png")
	if ResourceLoader.exists(p):
		# 9-slice so the gold ornamental border keeps its thickness at any size (the flat parchment
		# centre is the only part that stretches) — no more border-stretch.
		var n := NinePatchRect.new()
		n.texture = load(p)
		var m := 44
		n.patch_margin_left = m
		n.patch_margin_right = m
		n.patch_margin_top = m
		n.patch_margin_bottom = m
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return n
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

# The reusable wooden reward plaque (ui/quest/plaque.png) sized to the card — a flat wooden
# StyleBox panel when the art is absent. The caller hangs it at the box's bottom-centre and
# centres the +N reward on its face.
static func _reward_plaque(w: float, h: float) -> Control:
	var p := Look.kit(PLAQUE_PATH)
	if ResourceLoader.exists(p):
		var t := TextureRect.new()
		t.texture = load(p)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.custom_minimum_size = Vector2(w, h)
		t.size = Vector2(w, h)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(w, h)
	panel.size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BARK
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color("#6B4A2B")
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

# A CLEAR drawn speech bubble — a near-white round body (StyleBox, soft warm border + shadow) with a
# tail off the lower-left pointing back at the character. The painted box's own bubble reads too faint
# at board size, so the giver draws this on top of it; the caller drops the big item inside.
static func _speech_bubble(d: float) -> Control:
	var bubble := Control.new()
	bubble.custom_minimum_size = Vector2(d, d)
	bubble.size = Vector2(d, d)
	bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	var body := Panel.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFFDF6")
	sb.set_corner_radius_all(int(d * 0.46))
	sb.set_border_width_all(maxi(2, int(d * 0.03)))
	sb.border_color = Color("#C9A66B")
	sb.shadow_color = Color(0, 0, 0, 0.20)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	body.add_theme_stylebox_override("panel", sb)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(body)
	# the tail — drawn ON TOP of the body so it bridges the bottom border, tip extending toward the giver
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(d * 0.18, d * 0.78), Vector2(d * 0.46, d * 0.80), Vector2(d * 0.02, d * 1.06)])
	tail.color = Color("#FFFDF6")
	bubble.add_child(tail)
	return bubble

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
