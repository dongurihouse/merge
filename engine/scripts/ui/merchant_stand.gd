extends RefCounted
## The merchant-stall BUILDER (Wave 3, merchant slice) — pure construction of the merchant's
## stand on the §7 fence: the frameless bust, the "top -> +N" sell pill, the wicker buy-back
## basket, and the optional acorn treat. (The W3 drag sell-tag was the dark stat_chip pill —
## retired T48 ahead of the UI redesign.) Stateless: the coordinator owns the basket array +
## sell/buy-back transactions + the
## porter, and drives the sell affordance from the grid's drag; this only assembles nodes and
## returns the refs the coordinator keeps. Tap behaviour is injected as `Callable`s so this never
## reaches up into scenes/ (the §15 layering invariant).
##
## Usage:  var m := MerchantStand.build({
##           "stand_w": float, "fence_h": float,
##           "buy_treat": Callable(),            # the acorn treat was tapped
##           "wire_tap": Callable(node, action)})# the coordinator's still-release tap wirer
##         merchant_chip = m.stand ; basket_chip = m.basket_chip ; ... ; _rebuild_basket()
## Returns {stand, basket_chip}.

const Strings = preload("res://engine/scripts/core/strings.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Bust = preload("res://engine/scripts/ui/bust.gd")
const GiverStand = preload("res://engine/scripts/ui/giver_stand.gd")

# The merchant keeps the right end of the fence — same card anatomy as a giver stand.
static func build(cfg: Dictionary) -> Dictionary:
	var sw: float = cfg.stand_w
	var fh: float = cfg.fence_h
	var buy_treat: Callable = cfg.buy_treat
	var wire_tap: Callable = cfg.wire_tap
	var stand := Control.new()
	stand.custom_minimum_size = Vector2(sw, fh)
	stand.pivot_offset = Vector2(sw / 2.0, fh * 0.6)
	var bust := Bust.make(2, 124.0)              # AB4: frameless, like the givers
	bust.position = Vector2((sw - 124.0) / 2.0, 0.0)
	stand.add_child(bust)
	GiverStand.bob(bust)
	var pill := GiverStand.ask_pill()        # the trade rides the same pill (W3 brightens it)
	pill.offset_top = 130.0
	# T39 sell pill: the pill advertises the SELL PINNACLE -- a PREMIUM_TIER (t8) item sells for a
	# flat 1 premium (the gem pinnacle). PREMIUM_TIER is decoupled from TOP_TIER (grove_data.gd), so
	# the pinnacle must be read off PREMIUM_TIER, not TOP_TIER (which now pays banded coins). Per the
	# chrome rule the number is pure ASCII ("+1") and the currency is a Look.icon sprite (gem), never
	# an emoji baked into the text. The figure tracks sell_reward so the invariant (t8 -> 1 premium)
	# can never drift from what the merchant pays.
	var top_rw := G.sell_reward(100 + G.PREMIUM_TIER)   # the premium pinnacle -> Vector2i(0, 1)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 4)
	prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = Strings.t("merchant.top") % (top_rw.y if top_rw.y > 0 else top_rw.x)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color("#6E4B2F"))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prow.add_child(lbl)
	var pill_icon := Look.icon("gem" if top_rw.y > 0 else "coin", 24.0)
	pill_icon.set_meta("icon_id", "gem" if top_rw.y > 0 else "coin")
	prow.add_child(pill_icon)
	pill.add_child(prow)
	stand.add_child(pill)
	# (W3's live "+N🪙" drag sell-tag was the dark stat_chip pill — retired T48 ahead of the UI
	# redesign. The stall still brightens on drag (board.gd `_show_sell_affordance`); the +N value
	# read returns as a new-language chip during the redesign.)
	# Y2: the collection basket rides at the merchant's feet — sold items land here
	# and stay buy-backable until the porter collects. A wicker tray of <=3 sale chips.
	var basket_chip := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color("#9C7A4E", 0.96)        # wicker
	bsb.set_corner_radius_all(12)
	bsb.set_border_width_all(2)
	bsb.border_color = Color("#6E4B2F")
	bsb.shadow_color = Color(0, 0, 0, 0.22)
	bsb.shadow_size = 4
	bsb.content_margin_left = 8.0
	bsb.content_margin_right = 8.0
	bsb.content_margin_top = 5.0
	bsb.content_margin_bottom = 5.0
	basket_chip.add_theme_stylebox_override("panel", bsb)
	basket_chip.position = Vector2(sw / 2.0 - 56.0, fh - 62.0)
	basket_chip.visible = false
	stand.add_child(basket_chip)
	# (the coordinator paints the basket chips via _rebuild_basket once it owns the refs)
	# Z3: a 10🪙 acorn treat at the stall — tap it and a wandering spirit scurries
	# over to nibble (a tiny, endlessly-repeatable coin sink between wayside buys).
	if Features.on("spirit_treats"):
		var treat := PanelContainer.new()
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color("#FBF6EC", 0.96)
		tsb.set_corner_radius_all(14)
		tsb.set_border_width_all(2)
		tsb.border_color = Color("#C9A66B", 0.9)
		tsb.shadow_color = Color(0, 0, 0, 0.22)
		tsb.shadow_size = 4
		tsb.content_margin_left = 8.0
		tsb.content_margin_right = 8.0
		tsb.content_margin_top = 4.0
		tsb.content_margin_bottom = 5.0
		treat.add_theme_stylebox_override("panel", tsb)
		var trow := HBoxContainer.new()
		trow.add_theme_constant_override("separation", 3)
		trow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		treat.add_child(trow)
		if ResourceLoader.exists(Game.art("characters/spirit_acorn.png")):
			var ac := TextureRect.new()
			ac.texture = load(Game.art("characters/spirit_acorn.png"))
			ac.custom_minimum_size = Vector2(30, 30)
			ac.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ac.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ac.mouse_filter = Control.MOUSE_FILTER_IGNORE
			trow.add_child(ac)
		var tl := Label.new()
		tl.text = "%d" % G.TREAT_COST
		tl.add_theme_font_size_override("font_size", 22)
		tl.add_theme_color_override("font_color", Color("#33402F"))
		tl.add_theme_constant_override("outline_size", 0)
		trow.add_child(tl)
		trow.add_child(Look.icon("coin", 22.0))
		treat.position = Vector2(-22.0, 8.0)        # the merchant's shoulder-left
		wire_tap.call(treat, buy_treat)
		stand.add_child(treat)
	# T39 §9: NO tap-sell — dragging an item onto the stall is the ONLY sell verb. (The basket
	# buy-back chips and the treat keep their own taps; the stall itself is drag-only.)
	return {"stand": stand, "basket_chip": basket_chip}
