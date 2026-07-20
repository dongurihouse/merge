extends RefCounted
## The giver-stand BUILDER (Wave 3, fence slice 1) — pure construction of one quest-giver
## card on the §7 fence. The stable card/bubble/reward surfaces use Meadow paper assets;
## live content (portrait, ask item, progress, reward text, ready check) stays code-driven.
## The engine draws the live content ON TOP: the character portrait in the card field, the
## requested item in a cream ask-bubble (item over an "N/1" count) at the top-right, and the
## +N reward centred on the paper reward pill. The per-item green ✓ overtakes the item when payable.
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
const MEADOW_UI := "ui/meadow_v2/%s"

# The card surface wears the HUD pills' shared paper look (flat cream + thin PAPER_EDGE rim +
# a texture_cream grain layer from the UI kit) — see _paper_panel. The kit is loaded at runtime
# (matches hud.gd / action_bar.gd) to avoid a preload cycle. card_slice_* lay keys are retired
# with the old card_generic nine-slice but still accepted (ignored) from saved configs.
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
const PAPER_TEXTURE := "texture_cream.png"
const PAPER_FILL := Color("#F6EBDD")
const PAPER_EDGE := Color("#3F6D7D", 0.35)
const CARD_CORNER_FRAC := 0.12            # card corner radius as a fraction of the card height
const BUBBLE_PATH := "ui/quest/bubble_ask.png"   # the real speech bubble (tail toward the character)
const PLAQUE_AR := 2.1                    # the reward is a wide paper pill (w : h), not a square token

static func _meadow_path(file_name: String) -> String:
	return Game.art(MEADOW_UI % file_name)

static func _meadow_tex(file_name: String) -> Texture2D:
	var path := _meadow_path(file_name)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

# Tunable layout — ALL fractions. card_w / card_h are the box's width / height fraction of the stand,
# INDEPENDENT (the art fills the box, so a box off the art's ~1.77:1 native shape stretches it). The rest
# are a size (×cardH) and a centre x/y (×cardW, ×cardH): the bust fills the LEFT half, the standalone speech
# bubble + the asked item ride the upper RIGHT, and the reward pill hangs just below the bubble. These are
# the SHIPPED DEFAULTS / fallback; the board passes cfg.lay from the UI workbench's saved config
# (Kit.giver_lay_from_config), overriding per key — so designers tune + Save in the workbench, not here.
# card_w 0.92 leaves side padding between neighbouring cards on the fence; bust/bubble/pill x are
# pulled slightly inboard so the content keeps a margin from the card's side edges.
const LAY := {
	"card_w": 0.92, "card_h": 0.65,
	"bust_size": 0.94, "bust_x": 0.27, "bust_y": 0.53,
	"bubble_size": 0.66, "bubble_x": 0.70, "bubble_y": 0.35,
	"item_w": 0.32, "item_h": 0.32, "item_x": 0.70, "item_y": 0.32,
	"plaque_w": 0.40, "plaque_x": 0.70, "plaque_y": 0.81,
}

# A paper card in the HUD pills' family (_paper_panel). The character bust fills the LEFT HALF (free to
# overflow the box edges); the asked item sits on a STANDALONE speech bubble (board1_asset1, tail toward
# the character) in the upper RIGHT; the +N reward sits on the paper reward pill hung just BELOW the bubble.
# The bubble is a fixed-size sprite, so it never stretches with the card. No level badge, no count. No
# separate stand-level check — the per-item ✓ is the ready signal.
static func make(qi: int, q: Dictionary, cfg: Dictionary) -> Dictionary:
	var sw: float = cfg.stand_w
	var fh: float = cfg.fence_h
	var ask_tap: Callable = cfg.ask_tap
	var stand_tap: Callable = cfg.stand_tap
	var wire_tap: Callable = cfg.wire_tap
	var L := LAY.duplicate()                       # layout fractions; cfg.lay overrides (the workbench tunes these)
	for k in (cfg.get("lay", {}) as Dictionary):
		L[k] = (cfg.lay as Dictionary)[k]
	var stand := Control.new()
	# PASS (not the default STOP) so a touch-drag that STARTS on the card still reaches the quest-bar
	# ScrollContainer and scrolls the row. The still-release tap (wire_tap below) is unaffected — it only
	# fires when the touch barely moved. The bug this fixes: a STOP card swallowed the drag, so the fence
	# only scrolled in the slivers BETWEEN cards.
	stand.mouse_filter = Control.MOUSE_FILTER_PASS
	stand.custom_minimum_size = Vector2(sw, fh)
	stand.pivot_offset = Vector2(sw / 2.0, fh * 0.5)
	# the box: sized DIRECTLY to card_w × card_h of the stand — width and height are INDEPENDENT, so card_h
	# is a true height knob (the workbench tunes each). The surface is code-drawn paper (_paper_panel), so
	# any box shape stays crisp. Centred in the stand.
	var cardW: float = sw * float(L.card_w)
	var cardH: float = fh * float(L.card_h)
	var cx := (sw - cardW) / 2.0
	var cy := (fh - cardH) / 2.0
	# The stand keeps the LEFT margin (cx) but trims the dead space RIGHT of the card, so
	# neighbouring cards pack closer — the row gap alone separates them.
	var stand_trim_w := cx + cardW
	stand.custom_minimum_size.x = stand_trim_w
	stand.pivot_offset = Vector2(stand_trim_w / 2.0, fh * 0.5)
	var card := _quest_card(cardW, cardH, L)
	card.position = Vector2(cx, cy)
	card.size = Vector2(cardW, cardH)
	stand.add_child(card)
	# the character portrait — LARGE on the LEFT, filling the box top↔bottom and free to overflow its
	# edges. Drawn before the plaque so the plaque sits in FRONT of it. Its FACE is keyed off the quest's
	# asked line, so the fence draws a varied frameless cast from the scene's giver pool.
	# — stable for the life of the quest. Falls back to the slot index for an item-less quest.
	var it: Dictionary = G.quest_item(q)
	var bsz := cardH * float(L.bust_size)
	# the portrait is keyed off the quest's ASSIGNED giver index (board.gd picks one distinct from the last
	# 5), falling back to the asked line / slot index for quests authored before giver assignment existed.
	var giver_idx := int(q.get("giver", int(it.line) if not it.is_empty() else qi))
	# the giver POOL is map-specific (map 0 keeps the original cast; maps ≥1 use their own themed sheet)
	var bust := Bust.make(giver_idx, bsz, int(cfg.get("map_idx", 0)))
	# the portrait is CLIPPED to the card rect (mock: the character is cut by the card edge like a
	# sticker laid under the frame) — a dedicated clip layer, NOT clip_contents on the card itself,
	# so the card's show_behind_parent shared shadow keeps drawing outside the rect.
	var bust_clip := Control.new()
	bust_clip.name = "BustClip"
	bust_clip.position = Vector2(cx, cy)
	bust_clip.size = Vector2(cardW, cardH)
	bust_clip.clip_contents = true
	bust_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bust.position = Vector2(cardW * float(L.bust_x) - bsz / 2.0, cardH * float(L.bust_y) - bsz / 2.0)
	bust_clip.add_child(bust)
	stand.add_child(bust_clip)
	# Tier 2 §2: the idle-bob is gated by _refresh_giver_lights (it carries "deliverable").
	bust.tree_entered.connect(func() -> void:
		if is_instance_valid(bust) and bust.is_inside_tree():
			FX.pop_in(bust), CONNECT_ONE_SHOT)
	# the standalone speech bubble (ui/quest/bubble_ask.png — board1_asset1, tail tilting toward the
	# character on the left), with the asked item drawn ON it. A fixed-size sprite drawn behind the item,
	# so it never stretches with the card. The ✓ overtakes the item when the quest is ready.
	var item_ui: Dictionary = {}
	if not it.is_empty():
		var acode := int(it.line) * 100 + int(it.tier)
		var bd := cardH * float(L.bubble_size)
		var bubble := _speech_bubble(bd)
		bubble.position = Vector2(cx + cardW * float(L.bubble_x) - bd / 2.0, cy + cardH * float(L.bubble_y) - bd / 2.0)
		stand.add_child(bubble)
		var iw := cardH * float(L.item_w)
		var ih := cardH * float(L.item_h)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(iw, ih)
		icon.size = Vector2(iw, ih)
		icon.position = Vector2(cx + cardW * float(L.item_x) - iw / 2.0, cy + cardH * float(L.item_y) - ih / 2.0)
		# PASS, not STOP: let the drag reach the ScrollContainer so the bar scrolls even when the touch
		# starts on the ask bubble. Its OWN tap still works (wire_tap), and _stand_tap calls accept_event()
		# when that tap fires, so it doesn't also trigger the card's deliver-tap underneath.
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		# the asked item — built square at the LARGER of w/h (so it never upscales), then scaled to fill the
		# w×h box. item_w == item_h gives an undistorted icon; differ them to stretch (the workbench tunes both).
		var base := maxf(iw, ih)
		var piece := PieceView.make_piece(acode, base)
		piece.scale = Vector2(iw / base, ih / base)
		icon.add_child(piece)
		var mpx := minf(iw, ih) * 0.88
		var met := _ask_met_check(mpx)
		met.position = Vector2((iw - mpx) / 2.0, (ih - mpx) / 2.0)
		icon.add_child(met)
		stand.add_child(icon)
		# #3: route the item tap through item_tap (claim when the ✓ is up, else open the ladder).
		# Falls back to the bare ladder-open when a caller wires no item_tap (keeps make() standalone).
		var item_tap: Callable = cfg.get("item_tap", Callable())
		if item_tap.is_valid():
			wire_tap.call(icon, func() -> void: item_tap.call(qi, int(it.line), int(it.tier), stand))
		else:
			wire_tap.call(icon, func() -> void: ask_tap.call(int(it.line), int(it.tier)))
		item_ui = {"code": acode, "piece": piece, "met": met}
	# (The "incoming generator" reward preview was removed with the SINGLE-GENERATOR model: quests no
	# longer carry a `reward.generators` grant — the one map-0 anchor pops every opened line, so there is
	# no next-map tool to preview.)
	# the reward pill — seated INSIDE the box at the bottom, in FRONT of the bust, with the
	# coin + "+N" reward centred on its paper face.
	var plw := cardW * float(L.plaque_w)
	var plh := plw / PLAQUE_AR
	var pcx := cx + cardW * float(L.plaque_x)
	var pcy := cy + cardH * float(L.plaque_y)        # the reward pill centre
	var plaque := _reward_plaque(plw, plh)
	plaque.position = Vector2(pcx - plw / 2.0, pcy - plh / 2.0)
	stand.add_child(plaque)
	var pay := HBoxContainer.new()
	pay.add_theme_constant_override("separation", 3)
	pay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pay.add_child(Look.icon("coin", plh * 0.66))
	var pay_lbl := Label.new()
	pay_lbl.text = "+%d" % Quests.coins(q)
	pay_lbl.add_theme_font_size_override("font_size", int(plh * 0.64))
	pay_lbl.add_theme_color_override("font_color", INK)
	pay_lbl.add_theme_constant_override("outline_size", 0)             # solid pill behind — no halo
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

# One paper-family surface (shared by the card and the reward pill): a flat cream rounded panel
# with the thin PAPER_EDGE rim, carrying the kit's texture_cream grain layer clipped to the same
# corners — the exact recipe the HUD pills wear, so every quest surface sits in the pills' family.
static func _paper_panel(node_name: String, corner: float) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER_FILL
	sb.border_color = PAPER_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(round(corner)))
	sb.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_meta(Look.SHADOW_CORNER_META, corner)   # the card's real rounding — the shadow reads this
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var Kit: GDScript = load(KIT_PATH)
	if Kit != null:
		var paper: TextureRect = Kit.apply_rounded_paper_panel_surface(panel, node_name + "Paper", PAPER_TEXTURE, corner, 2.0)
		if paper != null:
			# a plain Panel has no container layout — anchor the grain into the 2px rim inset ourselves
			paper.set_anchors_preset(Control.PRESET_FULL_RECT)
			paper.offset_left = 2.0
			paper.offset_top = 2.0
			paper.offset_right = -2.0
			paper.offset_bottom = -2.0
	return panel

# The quest card surface: the shared paper panel at the card's corner radius (the mock's plain-border
# paper card). lay is still consulted for the shared shadow toggle; card_slice_* keys are ignored.
static func _quest_card(w: float, h: float, lay: Dictionary = {}) -> Control:
	var card := _paper_panel("MeadowQuestCard", maxf(10.0, h * CARD_CORNER_FRAC))
	_add_card_shadow(card, h, lay)
	return card

# Cast the ONE SHARED drop-shadow behind the card when the universal Shadow toggle is on (lay.shadow). Reuses
# Skin.shadow_rect + the shared lay.shadow_params (from the global `shadow` block) — the exact shadow every
# other component casts. Added as a show_behind_parent child so the NinePatch keeps its node identity (the card
# is a non-container Control — this mirrors Skin's non-container shadow pattern). No-op when the toggle is off.
static func _add_card_shadow(card: Control, h: float, lay: Dictionary) -> void:
	if not bool(lay.get("shadow", false)):
		return
	var params: Dictionary = lay.get("shadow_params", {}) as Dictionary
	var sh := Look.shadow_rect(Look.shape_corner(card, h * 0.12), params if not params.is_empty() else Look.shadow_params({}))
	sh.show_behind_parent = true
	card.add_child(sh)

# The standalone speech bubble (ui/quest/bubble_ask.png) drawn at a fixed size in a d×d box (aspect
# kept, so the tail stays put) — a plain cream rounded panel when the art is absent. The caller seats
# the asked item on it.
static func _speech_bubble(d: float) -> Control:
	var path := Game.art(BUBBLE_PATH)
	if ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.name = "MeadowAskBubble"
		t.texture = load(path)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(d, d)
		t.size = Vector2(d, d)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(d, d)
	panel.size = Vector2(d, d)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FBF6EC", 0.97)
	sb.set_corner_radius_all(int(d * 0.32))
	sb.set_border_width_all(2)
	sb.border_color = Color("#C9A66B", 0.85)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

# The reward pill: the shared paper panel at full pill rounding (the mock's reward chip). The
# caller hangs it at the card's bottom-right and centres the coin + "+N" row on its face — the
# pill itself carries NO coin, so the row's coin icon is the only one (the old reward_token.png
# backing was itself a big coin, doubling the row's coin icon behind the text).
static func _reward_plaque(w: float, h: float) -> Control:
	var pill := _paper_panel("MeadowRewardPill", h * 0.5)
	pill.custom_minimum_size = Vector2(w, h)
	pill.size = Vector2(w, h)
	return pill

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
	Look.apply_box_shadow(ps)
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
	Look.apply_box_shadow(mbg)
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
