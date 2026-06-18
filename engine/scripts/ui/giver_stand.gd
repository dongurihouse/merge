extends RefCounted
## The giver-stand BUILDER (Wave 3, fence slice 1) — pure construction of one quest-giver
## stand on the §7 fence: the chest-up bust over the rail, the ask pill (1–3 asks + progress),
## the +N★ (and featured +N💎) shoulder reward, the featured ribbon, and the ready-check that
## docks on the pill. Stateless: state (the quests array, payability) stays in the board
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
	stand.pivot_offset = Vector2(sw / 2.0, fh * 0.6)
	# a wooden sign-board behind the giver — the frameless chest-up cutout used to
	# blend into the painted fence; a bordered, shadowed plaque lifts each quest off
	# the rail and makes the row read as distinct cards. The bust's head pokes above
	# it and the ask pill rides on its face (added after, so both sit in front).
	var plaque := Panel.new()
	var plw := 178.0
	var plh := 150.0
	plaque.position = Vector2((sw - plw) / 2.0, 60.0)
	plaque.size = Vector2(plw, plh)
	var pls := StyleBoxFlat.new()
	pls.bg_color = Color("#E7D3A6", 0.97)         # warm parchment-wood board
	pls.set_corner_radius_all(22)
	pls.set_border_width_all(3)
	pls.border_color = Color("#8A5A3B")           # the bark-brown used by the asks/pill
	pls.shadow_color = Color(0, 0, 0, 0.34)
	pls.shadow_size = 9
	pls.shadow_offset = Vector2(0, 5)
	plaque.add_theme_stylebox_override("panel", pls)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stand.add_child(plaque)
	var bust := Bust.make(qi % 2, 150.0)   # UI redesign: enlarged — the character is the card's anchor
	bust.position = Vector2((sw - 150.0) / 2.0, 0.0)
	stand.add_child(bust)
	# Tier 2 §2: the idle-bob is NOT started here — it now means "deliverable", so
	# _refresh_giver_lights gates it per giver via _giver_is_payable. (The bust is
	# returned in the chip entry so the refresh can reach it.)
	# juice: the giver pops in when its stand enters the tree (deferred so the
	# tween is never created on a not-yet-in-tree node — matches bob)
	bust.tree_entered.connect(func() -> void:
		if is_instance_valid(bust) and bust.is_inside_tree():
			FX.pop_in(bust), CONNECT_ONE_SHOT)
	# the ask PILL — hugs [item icon + n/m] PER ASK (X3: 1–3 asks), centered under
	# the bust, on the fence. The capacity is the same pill; multi-ask just adds pairs.
	var pill := ask_pill()
	pill.offset_top = 122.0
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(inner)
	var asks: Array = G.quest_asks(q)
	var ask_uis: Array = []
	if q.has("grant"):                        # §6: a generator-grant quest shows the NEW generator to receive
		var gdef: Dictionary = G.gen_def(G.GENERATORS, String(q.grant.grants))
		var gtex := Game.art(String(gdef.get("tex", "")))
		if ResourceLoader.exists(gtex):
			var gicon := TextureRect.new()
			gicon.texture = load(gtex)
			gicon.custom_minimum_size = Vector2(56, 56)
			gicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			gicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			gicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(gicon)
		var glbl := Label.new()
		glbl.text = TranslationServer.translate("✿ new tool")
		glbl.add_theme_font_size_override("font_size", 22)
		glbl.add_theme_color_override("font_color", Color("#33402F"))
		glbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(glbl)
	var isz := 56.0 if asks.size() >= 2 else 62.0
	for ai in asks.size():
		var ask: Dictionary = asks[ai]
		var aline := int(ask.line)
		var atier := int(ask.tier)
		var acode := aline * 100 + atier
		if ai > 0:                              # a "+" joins the pairs of a multi-ask
			var plus := Label.new()
			plus.text = "+"
			plus.add_theme_font_size_override("font_size", 24)
			plus.add_theme_color_override("font_color", BARK)
			plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(plus)
		# #4: the ASK item — the icon IS the ask; its progress rides ON it as a
		# corner count-chip (wordless: just the wanted count), and a green ✓ overlays
		# the corner when this single ask is already satisfied on the board. No
		# detached "n/m" label anymore. The whole returned {badge_lbl, badge, met}
		# is driven from _refresh_giver_lights' have>=need test.
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(isz, isz)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP   # tapping the ITEM shows its ladder
		var piece := PieceView.make_piece(acode, isz)
		icon.add_child(piece)
		# the count chip hugs the item's BOTTOM-RIGHT, the ✓ its TOP-RIGHT — both via
		# anchors (no deferred positioning lambda, so nothing dangles past teardown).
		var badge := _count_badge(int(ask.count))           # cream chip, bottom-right ON the item
		badge.anchor_left = 1.0
		badge.anchor_top = 1.0
		badge.anchor_right = 1.0
		badge.anchor_bottom = 1.0
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
		badge.offset_left = 5.0
		badge.offset_top = 5.0
		badge.offset_right = 5.0
		badge.offset_bottom = 5.0
		icon.add_child(badge)
		var met := _ask_met_check()                         # green ✓, top-right, hidden until satisfied
		met.anchor_left = 1.0
		met.anchor_right = 1.0
		met.offset_left = -met.size.x + 5.0
		met.offset_top = -5.0
		met.offset_right = 5.0
		met.offset_bottom = met.size.y - 5.0
		icon.add_child(met)
		wire_tap.call(icon, func() -> void: ask_tap.call(aline, atier))
		inner.add_child(icon)
		ask_uis.append({"code": acode, "need": int(ask.count), "piece": piece, "badge": badge, "badge_lbl": badge.get_child(0), "met": met})
	stand.add_child(pill)
	# AB3: the +N★ reward floats at the bust's shoulder — a bare star + count (no
	# chip slab; an ink outline lifts the number off the scene)
	var pay := HBoxContainer.new()
	pay.add_theme_constant_override("separation", 1)
	pay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pay.add_child(Look.icon("star", 30.0))
	var pay_lbl := Label.new()
	pay_lbl.text = "+%d" % Quests.stars(q)
	pay_lbl.add_theme_font_size_override("font_size", 24)
	pay_lbl.add_theme_color_override("font_color", STRAW)
	pay_lbl.add_theme_color_override("font_outline_color", Color("#33402F"))
	pay_lbl.add_theme_constant_override("outline_size", 5)
	pay_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pay.add_child(pay_lbl)
	pay.position = Vector2(sw / 2.0 + 30.0, 6.0)
	stand.add_child(pay)
	# §7 FEATURED: a small random share of regular quests are featured — flag it on the fence.
	# A code-drawn gold ribbon sits above the bust ("this one's special"); when the featured
	# bonus rolled a premium, a +N💎 rides the shoulder under the ★. The bonus is coins/premium,
	# never extra ★ (the ★ shoulder above is untouched by featuring).
	if bool(q.get("featured", false)):
		var ribbon := _featured_ribbon()
		ribbon.position = Vector2((sw - 122.0) / 2.0, -2.0)
		stand.add_child(ribbon)
		var feat_gems := Quests.gems(q)
		if feat_gems > 0:
			var gem_pay := HBoxContainer.new()
			gem_pay.add_theme_constant_override("separation", 1)
			gem_pay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gem_pay.add_child(Look.icon("gem", 26.0))
			var gem_lbl := Label.new()
			gem_lbl.text = "+%d" % feat_gems
			gem_lbl.add_theme_font_size_override("font_size", 22)
			gem_lbl.add_theme_color_override("font_color", Color("#BFE6F2"))
			gem_lbl.add_theme_color_override("font_outline_color", Color("#33402F"))
			gem_lbl.add_theme_constant_override("outline_size", 5)
			gem_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			gem_pay.add_child(gem_lbl)
			gem_pay.position = Vector2(sw / 2.0 + 30.0, 38.0)
			stand.add_child(gem_pay)
	# AB3: the ready check docks on the pill's TOP-LEFT corner (no ring border)
	var check := _ready_check()
	stand.add_child(check)
	_dock_check(check, pill, stand)
	wire_tap.call(stand, func() -> void: stand_tap.call(qi, stand))
	return {"chip": stand, "qi": qi, "asks": ask_uis, "check": check, "bust": bust}

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

# §7 FEATURED: a code-drawn gold ribbon that crowns a featured giver's stand — a clear
# "this one's special" highlight on the fence (no art exists; Look-kit warm palette). A
# straw-gold pill, deeper-gold border + soft shadow, holding a ★ glyph + a "Featured" caption.
static func _featured_ribbon() -> PanelContainer:
	var ribbon := PanelContainer.new()
	var rs := StyleBoxFlat.new()
	rs.bg_color = STRAW                        # the warm straw-gold accent the fence already uses
	rs.set_corner_radius_all(11)
	rs.set_border_width_all(2)
	rs.border_color = Color("#8A5A3B")         # the bark-brown border the asks/plus use
	rs.shadow_color = Color(0, 0, 0, 0.28)
	rs.shadow_size = 4
	rs.shadow_offset = Vector2(0, 2)
	rs.content_margin_left = 10.0
	rs.content_margin_right = 12.0
	rs.content_margin_top = 3.0
	rs.content_margin_bottom = 3.0
	ribbon.add_theme_stylebox_override("panel", rs)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.add_child(row)
	var star := Look.icon("star", 20.0)
	star.modulate = Color("#FBF3EA")           # a cream star reads on the straw fill
	row.add_child(star)
	var lbl := Label.new()
	lbl.text = TranslationServer.translate("Featured")
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color("#4A2F1B"))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	return ribbon

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

# #4: a SMALL green ✓ sticker on the item's top-right corner — the per-ask
# "this one's ready" mark, shown only when its single ask is satisfied. Distinct
# from (and smaller than) the stand-level _ready_check that drives delivery.
static func _ask_met_check() -> Panel:
	var mark := Panel.new()
	mark.custom_minimum_size = Vector2(26, 26)
	mark.size = Vector2(26, 26)
	var mbg := StyleBoxFlat.new()
	mbg.bg_color = Color("#5CAF5C")
	mbg.set_corner_radius_all(13)
	mbg.set_border_width_all(2)
	mbg.border_color = CREAM
	mbg.shadow_color = Color(0, 0, 0, 0.28)
	mbg.shadow_size = 2
	mbg.shadow_offset = Vector2(0, 1)
	mark.add_theme_stylebox_override("panel", mbg)
	var mi := Look.icon("check", 18.0)
	mi.set_anchors_preset(Control.PRESET_FULL_RECT)
	if mi is Label:
		(mi as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(mi as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_child(mi)
	mark.visible = false
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return mark

static func _ready_check() -> Panel:
	var check := Panel.new()
	check.custom_minimum_size = Vector2(40, 40)
	check.size = Vector2(40, 40)
	var ck_bg := StyleBoxFlat.new()
	ck_bg.bg_color = Color("#5CAF5C")
	ck_bg.set_corner_radius_all(20)
	ck_bg.set_border_width_all(3)
	ck_bg.border_color = Color("#FBF3EA")
	check.add_theme_stylebox_override("panel", ck_bg)
	var ck_icon := Look.icon("check", 26.0)
	ck_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ck_icon is Label:
		(ck_icon as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(ck_icon as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	check.add_child(ck_icon)
	check.visible = false
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return check

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
