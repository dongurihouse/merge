extends RefCounted
## RETIREMENT OFFER — the modal that clears a line the game will never ask for again (§6).
##
## A line is DONE when no remaining level can require it (`G.gen_retirable`) — its generator is then dead
## weight on the board and its leftover stock is unusable. This offers to clear both in one action: the
## generator leaves the board AND the gen_bag, every leftover piece (board + item bag) is sold, and the coins
## land as SPENDABLE only (retirement never advances the clock — quests do).
##
## It is an OFFER, never an auto-execute: the card shows exactly what goes and exactly what comes back, and
## nothing happens until the player presses it. Dismissing is safe — the info-bar sell button also clears a
## retirable generator, so a dead tool is never stuck on the board.
##
## On the shipped roster this fires THREE times in the whole game (gen_1/gen_6/gen_16 at their derived
## zone_unlock_level(3)/(8)/(11) boundaries), so it reads as a ceremony beat. The coordinator (board.gd) decides WHEN
## (a calm moment — board entry, never mid-gesture) and owns the commit; this just renders.
##   RetireOffer.open(host, {line:int, gen_id:String, pieces:int, coins:int, on_confirm:Callable})

const Strings = preload("res://engine/scripts/core/strings.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Pal = Game.PALETTE
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale

static var KIT_PATH := Game.kit()
const OVERLAY_NAME := "RetireOfferOverlay"

static func is_open(host: Control) -> bool:
	return Overlay.is_open(host, OVERLAY_NAME)

static func open(host: Control, opts: Dictionary) -> void:
	if Overlay.is_open(host, OVERLAY_NAME):
		return
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("RetireOffer: ui kit missing at %s" % KIT_PATH)
		return
	var line := int(opts.get("line", 0))
	if line <= 0:
		return
	var pieces := int(opts.get("pieces", 0))
	var coins := int(opts.get("coins", 0))
	var on_confirm: Callable = opts.get("on_confirm", Callable())
	var on_dismiss: Callable = opts.get("on_dismiss", Callable())
	# closed WITHOUT confirming = declined. Boxed so both close paths (veil tap, ✕) and the CTA share one flag.
	var confirmed := [false]
	var dismiss := func() -> void:
		if not bool(confirmed[0]) and on_dismiss.is_valid():
			on_dismiss.call()
	Audio.play("button_tap", -4.0)

	var modal := Overlay.modal(host, OVERLAY_NAME, {"ink": Pal.GROUND_EDGE, "on_dismiss": dismiss})
	var overlay: Control = modal["overlay"]
	var cc: CenterContainer = modal["center"]

	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var vw: float = host.get_viewport_rect().size.x
	# size against the REAL card width (the single global frame %) and render content at 1:1. Authoring to a
	# narrower design baseline + content_scale would blow the art up ~1.5x and overflow the frame, which
	# clips the body and hides the confirm button behind a scrollbar.
	var width: float = vw * Kit.frame_width_pct(cfg) / 100.0

	# --- content: the line's own piece, then plainly what goes and what comes back ---
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER

	var art := PieceView.make_piece(line * 100 + 1, width * 0.26, 0.0)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(art)

	var body := Label.new()
	body.text = Strings.t("retire.body") % [pieces, coins]
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# an autowrap Label reports a min HEIGHT for its CURRENT width and blows up at transient narrow widths —
	# bound it so the card cannot stretch while the frame is still resolving its layout.
	body.max_lines_visible = 3
	body.custom_minimum_size.x = width * 0.80
	body.add_theme_font_size_override("font_size", FS.BODY)
	body.add_theme_color_override("font_color", Pal.INK)
	col.add_child(body)

	var btn: Button = Kit.cta_button(Strings.t("retire.confirm"), Kit.button_opts_from_config(cfg))
	btn.pressed.connect(func() -> void:
		confirmed[0] = true
		if is_instance_valid(overlay):
			overlay.queue_free()
		if on_confirm.is_valid():
			on_confirm.call())
	col.add_child(btn)

	var dopts: Dictionary = Kit.dialog_opts_from_config(cfg)
	dopts["banner_text"] = Strings.t("retire.title")
	# dialog_frame scrolls its content inside a card whose height comes from a FLOOR (min_h, default a small
	# fraction of the screen). This card is art + copy + a CTA, so leave an explicit floor tall enough to hold
	# all three — otherwise the button lands under the bottom edge and the only hint is a thin scrollbar.
	dopts["min_h"] = width * 0.60
	dopts["on_close"] = modal["dismiss"]   # the ✕ takes the SAME seam as the veil tap: decline, then close

	var dialog: Control = Kit.dialog_frame(col, width, dopts)
	cc.add_child(dialog)
	FX.pop_in(dialog)
