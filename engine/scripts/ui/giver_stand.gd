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
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const SpriteShadow = preload("res://engine/scripts/ui/sprite_shadow.gd")
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
const CARD_CORNER_FRAC := 0.12            # card corner radius as a fraction of the card height (shadow rounding)
const CARD_PATH := "ui/quest/card_shell.png"     # the deckled cut-paper card shell (art fills the box)
# Irregular hand-cut paper plates — the preferred card surface. Each 512² PNG carries its OWN
# painted down-right contact shadow in the alpha channel (authored on the board blue and
# un-blended), so a plate card adds NO runtime shadow. Probed once: plate_01.png upward.
const PLATE_DIR := "ui/quest/plates/"
static var _plate_pool: Array[String] = []       # resolved plate paths (empty = no plates shipped)
static var _plates_probed := false
const PILL_PATH := "ui/quest/reward_pill.png"    # the stitched reward tag — gold coin baked into the LEFT third
const PLAQUE_AR := 1.9                    # the reward pill's native w : h (coin left, +N set into the right two-thirds)

static func _meadow_path(file_name: String) -> String:
	return Game.art(MEADOW_UI % file_name)

static func _meadow_tex(file_name: String) -> Texture2D:
	var path := _meadow_path(file_name)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

# Tunable layout — ALL fractions. card_w / card_h are the box's width / height fraction of the stand,
# INDEPENDENT (the deckled card art fills the box, so a box off its native shape stretches it). item_w/h
# are a size (×cardH) and item_x/y a centre (×cardW, ×cardH): the asked item is the card's BIG centred
# focal art. plaque_w is a width (×cardW) and plaque_x/y a centre — the reward tag hangs at the bottom-
# right. These are the SHIPPED DEFAULTS / fallback; the board passes cfg.lay from the UI workbench's saved
# config (Kit.giver_lay_from_config), overriding per key — designers tune + Save in the workbench, not here.
# Legacy bust_*/bubble_* keys are still accepted (ignored) from saved configs — the portrait + speech
# bubble were retired when the card became just the item + the reward plaque.
const LAY := {
	"card_w": 0.92, "card_h": 0.97,
	"item_w": 0.60, "item_h": 0.60, "item_x": 0.50, "item_y": 0.44,
	"plaque_w": 0.46, "plaque_x": 0.70, "plaque_y": 0.85,
	"gap": 16.0,   # px BETWEEN cards in the fence row (board.gd reads it for the row separation)
}

# The per-surface shadow gate: `<key>` (item_shadow / card_shadow / plaque_shadow) when the lay
# carries it, else the legacy single `shadow` toggle — so old saved configs keep their one-switch
# behaviour and the new per-surface toggles simply override it.
static func _shadow_on(lay: Dictionary, key: String) -> bool:
	return bool(lay.get(key, lay.get("shadow", false)))

# The quest card: an irregular cut-paper plate (PLATE_DIR; deckled CARD_PATH shell as the fallback
# surface) carrying just two things — the asked item as
# the BIG centred focal art, and the reward tag (PILL_PATH) hung at the bottom-right with "+N" set into
# its blank right two-thirds (the coin is baked into the art). Each of the three surfaces — card, item,
# plaque — casts the ONE shared drop-shadow when the universal Shadow toggle is on. The per-item ✓
# overtakes the item when payable; there is no separate stand-level check, no portrait, no speech bubble.
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
	# the asked item, fetched early: it also seeds the plate pick, so a quest keeps ITS plate
	# for its whole life (slot shifts don't reshuffle the paper).
	var it: Dictionary = G.quest_item(q)
	var plate_seed := 0 if it.is_empty() else int(it.line) * 100 + int(it.tier) + Quests.coins(q) * 101
	var card := _quest_card(cardW, cardH, L, plate_seed)
	card.position = Vector2(cx, cy)
	card.size = Vector2(cardW, cardH)
	stand.add_child(card)
	# the asked item — the card's BIG centred focal art, with its own shared drop-shadow. Its ladder tap
	# is wired below; the per-item ✓ overtakes it when payable. Falls back to nothing for an item-less quest.
	var item_ui: Dictionary = {}
	var focal: Control = null                          # the item icon — board.gd bobs THIS as the ready signal
	if not it.is_empty():
		var acode := int(it.line) * 100 + int(it.tier)
		var iw := cardH * float(L.item_w)
		var ih := cardH * float(L.item_h)
		var icx := cx + cardW * float(L.item_x)         # item centre
		var icy := cy + cardH * float(L.item_y)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(iw, ih)
		icon.size = Vector2(iw, ih)
		icon.position = Vector2(icx - iw / 2.0, icy - ih / 2.0)
		# PASS, not STOP: let the drag reach the ScrollContainer so the bar scrolls even when the touch
		# starts on the item. Its OWN tap still works (wire_tap), and _stand_tap calls accept_event()
		# when that tap fires, so it doesn't also trigger the card's deliver-tap underneath.
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		# a SHAPE-TRUE drop-shadow behind the item — stamped from the item's OWN silhouette, offset by the
		# shared cast, so it follows the art outline (not a generic ground ellipse). show_behind_parent → it
		# draws behind the piece. Fit + inset mirror _add_sprite so the silhouette lines up with the art.
		_add_shape_shadow(icon, PieceView.content_texture(acode), Vector2(iw, ih), L, true, iw * PieceView.ITEM_INSET, 4, "item_shadow")
		# the asked item — built square at the LARGER of w/h (so it never upscales), then scaled to fill the
		# w×h box. item_w == item_h gives an undistorted icon; differ them to stretch (the workbench tunes both).
		var base := maxf(iw, ih)
		var piece := PieceView.make_piece(acode, base)
		piece.scale = Vector2(iw / base, ih / base)
		# strip the piece's OWN soft ground ellipse (make_piece adds it when item_backing is on) — the card
		# gives the item a single shape-true cast above, so the built-in ellipse would double the shadow.
		var built_in_shadow := piece.get_node_or_null(NodePath("ContactShadow"))
		if built_in_shadow != null:
			built_in_shadow.queue_free()
		icon.add_child(piece)
		var mpx := minf(iw, ih) * float(L.get("check_scale", 0.88))
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
		focal = icon
	# the reward tag — the stitched paper pill (coin baked into the LEFT third) hung at the card's
	# bottom-right, its own shared drop-shadow behind it, with "+N" set into the blank RIGHT two-thirds.
	var plw := cardW * float(L.plaque_w)
	var plh := plw / PLAQUE_AR
	var pcx := cx + cardW * float(L.plaque_x)
	var pcy := cy + cardH * float(L.plaque_y)        # the reward pill centre
	var plaque := _reward_plaque(plw, plh)
	plaque.position = Vector2(pcx - plw / 2.0, pcy - plh / 2.0)
	# SHAPE-TRUE: the plaque is the stitched pill ART, so stamp its cast from the pill's own silhouette —
	# a rounded-rect panel was the wrong shape (it squared off the tag's stitched edge). The code-drawn
	# fallback pill has no silhouette to stamp, so it keeps the rounded-rect cast.
	if plaque is TextureRect and (plaque as TextureRect).texture != null:
		_add_shape_shadow(plaque, (plaque as TextureRect).texture, Vector2(plw, plh), L, false, 0.0, 3, "plaque_shadow")
	else:
		_add_content_shadow(plaque, plh * 0.4, L, "plaque_shadow")
	stand.add_child(plaque)
	# the "+N" reward, set into the pill's blank RIGHT two-thirds (the coin lives in the art's left third).
	var pay_lbl := Label.new()
	pay_lbl.text = "+%d" % Quests.coins(q)
	pay_lbl.add_theme_font_size_override("font_size", int(plh * 0.58))
	pay_lbl.add_theme_color_override("font_color", INK)
	pay_lbl.add_theme_constant_override("outline_size", 0)             # solid pill behind — no halo
	pay_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pay_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pay_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# centre the number on the RIGHT two-thirds of the pill (x ≈ 0.64 across it; the coin fills the left third).
	var num_cx := (pcx - plw / 2.0) + plw * 0.64
	# Driven by resized — fires only while the label is alive + in-tree (a stand freed before idle would
	# otherwise fire this over a freed label, the §120 freed-capture).
	var place_pay := func() -> void:
		pay_lbl.position = Vector2(num_cx - pay_lbl.size.x / 2.0, pcy - pay_lbl.size.y / 2.0)
	pay_lbl.resized.connect(place_pay)
	stand.add_child(pay_lbl)
	# §7 FEATURED is intentionally NOT surfaced on the board: quests aren't skippable, so a
	# "this one's special" highlight (or a +N💎 shoulder) is noise the player can't act on. The
	# `featured` flag + its coins/premium bonus still ride in the quest data and pay out silently
	# on hand-in (board.gd). A real surface — where featured-ness DOES drive a choice (a daily/
	# event "do a featured quest" hook, §17/§18) — is parked in the backlog.
	# the ready check is per-item (the big centered ✓ over the item), so there is no separate
	# stand-level check. The "check" key stays in the result for board.gd, set to null (the board
	# already guards it with `if check != null and is_instance_valid(check)`). "bust" now points at
	# the item icon — board.gd bobs it as the ready signal (the portrait it used to bob is gone).
	wire_tap.call(stand, func() -> void: stand_tap.call(qi, stand))
	return {"chip": stand, "qi": qi, "item": item_ui, "check": null, "bust": focal}

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

# The quest card surface: an irregular cut-paper plate (PLATE_DIR, picked by `seed`) when plates
# ship, else the deckled shell (CARD_PATH), else the code-drawn paper panel. lay is consulted for
# the shared shadow toggle; card_slice_* keys are ignored.
static func _quest_card(w: float, h: float, lay: Dictionary = {}, seed: int = 0) -> Control:
	var card := _card_surface(w, h, seed)
	# a SHAPE-TRUE drop-shadow following the deckled card / plate edge when the card is a cut-paper
	# texture; the code-drawn paper fallback keeps the rounded-rect shared shadow (no silhouette to stamp).
	# NOTE: a PLATE also carries a painted contact shadow in its art — the Card-shadow controls add the
	# runtime cast ON TOP of it, so turn the toggle off to keep the painted one alone.
	if card is TextureRect and (card as TextureRect).texture != null:
		_add_shape_shadow(card, (card as TextureRect).texture, Vector2(w, h), lay, false, 0.0, 3, "card_shadow")
	else:
		_add_card_shadow(card, h, lay, "card_shadow")
	return card

# The plate pool, probed once: PLATE_DIR/plate_01.png upward until a gap. Cached for the session.
static func _plate_paths() -> Array[String]:
	if _plates_probed:
		return _plate_pool
	_plates_probed = true
	var i := 1
	while true:
		var p := Game.art(PLATE_DIR + "plate_%02d.png" % i)
		if not ResourceLoader.exists(p):
			break
		_plate_pool.append(p)
		i += 1
	return _plate_pool

# The card art as a fill TextureRect (STRETCH_SCALE — the box shape drives it, so card_w/card_h
# tune the card outline): a seed-picked irregular plate when plates ship (its painted contact shadow
# rides in the alpha — flagged `baked_shadow` so callers can tell), else the deckled shell, else the
# code-drawn paper panel. Stamps the shadow corner meta either way for the shared-shadow consumers.
static func _card_surface(w: float, h: float, seed: int = 0) -> Control:
	var plates := _plate_paths()
	var path := plates[absi(seed) % plates.size()] if not plates.is_empty() else Game.art(CARD_PATH)
	if ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.name = "MeadowQuestCard"
		t.texture = load(path)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.custom_minimum_size = Vector2(w, h)
		t.size = Vector2(w, h)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.set_meta(Look.SHADOW_CORNER_META, h * CARD_CORNER_FRAC)
		if not plates.is_empty():
			t.set_meta("baked_shadow", true)
		return t
	return _paper_panel("MeadowQuestCard", maxf(10.0, h * CARD_CORNER_FRAC))

# Cast the ONE SHARED drop-shadow behind the card when the universal Shadow toggle is on (lay.shadow). Reuses
# Skin.shadow_rect + the shared lay.shadow_params (from the global `shadow` block) — the exact shadow every
# other component casts. Added as a show_behind_parent child so the card keeps its node identity (a non-
# container Control — mirrors Skin's non-container shadow pattern). No-op when the toggle is off.
static func _add_card_shadow(card: Control, h: float, lay: Dictionary, key: String = "shadow") -> void:
	if not _shadow_on(lay, key):
		return
	var sh := Look.shadow_rect(Look.shape_corner(card, h * 0.12), _shadow_params(lay, key))
	sh.show_behind_parent = true
	card.add_child(sh)

# Cast the shared drop-shadow behind a SOLID content surface (the reward pill) at corner radius `corner`,
# as a show_behind_parent child — the same filled shadow the card casts. No-op when the universal Shadow
# toggle is off, so card + plaque light + darken together.
static func _add_content_shadow(surface: Control, corner: float, lay: Dictionary, key: String = "shadow") -> void:
	if not _shadow_on(lay, key):
		return
	var sh := Look.shadow_rect(corner, _shadow_params(lay, key))
	sh.show_behind_parent = true
	surface.add_child(sh)

# Cast a SHAPE-TRUE drop-shadow (SpriteShadow) behind `surface`, stamped from `tex`'s own silhouette and
# offset by the shared cast — so the shadow follows the deckled card edge / the item outline instead of a
# rounded-rect approximation. Added as a show_behind_parent child so it draws behind the surface's art.
# `fit`/`inset` aspect-fit the silhouette in the box like the sprite (items); OFF = stretch-fill (cards).
# `div` is the softness at the DEFAULT blur — the surface's `blur` param scales it (see _soft_div), so the
# blur slider is real for sprite shadows too. No-op when the Shadow toggle is off or `tex` is null.
static func _add_shape_shadow(surface: Control, tex: Texture2D, size: Vector2, lay: Dictionary, fit: bool, inset: float, div: int, key: String = "shadow") -> void:
	if not _shadow_on(lay, key) or tex == null:
		return
	var p := _shadow_params(lay, key)
	var sh := SpriteShadow.new()
	sh.texture = tex
	sh.draw_size = size
	sh.offset = Vector2(float(p.get("offset_x", 0.0)), float(p.get("offset_y", 5.0)))
	sh.tint = Look.shadow_color(float(p.get("alpha", 0.2)))
	sh.fit = fit
	# spread TIGHTENS a sprite cast the only way a stamped silhouette can: by insetting the stamp, so a
	# negative spread pulls the shadow in under the art (the filled-panel shadows read it the same way).
	sh.inset = inset + absf(float(p.get("spread", 0.0)))
	sh.soft_div = _soft_div(div, float(p.get("blur", Look.SHADOW_DEFAULTS.blur)))
	sh.show_behind_parent = true
	surface.add_child(sh)

# A sprite shadow's softness is its silhouette downsample factor, not a gaussian radius — so map the
# shared `blur` px onto it, scaled around the DEFAULT blur so `base_div` still reproduces the shipped
# look at blur 6. Bigger = softer / less shape detail; clamped to a sane, non-zero band.
static func _soft_div(base_div: int, blur: float) -> int:
	var d := float(base_div) * maxf(blur, 0.0) / maxf(float(Look.SHADOW_DEFAULTS.blur), 0.001)
	return clampi(int(round(d)), 1, 32)

# The shadow look for a surface: its OWN tuned params (`<key>_params`, e.g. item_shadow_params) when the
# workbench set them apart, else the shared `shadow_params`, else Skin's default. So each surface can carry
# its own offset/blur/spread/alpha, but an untuned surface still tracks the one shared cast.
static func _shadow_params(lay: Dictionary, key: String = "shadow") -> Dictionary:
	if key != "shadow":
		var own: Dictionary = lay.get(key + "_params", {}) as Dictionary
		if not own.is_empty():
			return own
	var params: Dictionary = lay.get("shadow_params", {}) as Dictionary
	return params if not params.is_empty() else Look.shadow_params({})

# The reward pill: the stitched cut-paper tag (PILL_PATH) — coin baked into the LEFT third — stretched to
# fill the w×h box, falling back to the code-drawn paper pill when the art is absent. The caller hangs it
# at the card's bottom-right and sets "+N" into its blank right two-thirds.
static func _reward_plaque(w: float, h: float) -> Control:
	var path := Game.art(PILL_PATH)
	if ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.name = "MeadowRewardPill"
		t.texture = load(path)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.custom_minimum_size = Vector2(w, h)
		t.size = Vector2(w, h)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.set_meta(Look.SHADOW_CORNER_META, h * 0.4)
		return t
	var pill := _paper_panel("MeadowRewardPill", h * 0.5)
	pill.custom_minimum_size = Vector2(w, h)
	pill.size = Vector2(w, h)
	return pill

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
