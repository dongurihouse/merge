extends RefCounted
## FAREWELL CARD — one calm acknowledgement before a not-currently-needed line is swept from the board.
## Every close path uses the same Overlay dismiss seam; the board coordinator owns the sweep callback.
##   FarewellCard.open(host, {line:int, next_need:Dictionary, pieces:int, coins:int, on_close:Callable})

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
const OVERLAY_NAME := "FarewellCardOverlay"

static func is_open(host: Control) -> bool:
	return Overlay.is_open(host, OVERLAY_NAME)

static func open(host: Control, opts: Dictionary) -> void:
	if Overlay.is_open(host, OVERLAY_NAME):
		return
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("FarewellCard: ui kit missing at %s" % KIT_PATH)
		return
	var line := int(opts.get("line", 0))
	if line <= 0:
		return
	var next_need: Dictionary = opts.get("next_need", {})
	var coins := int(opts.get("coins", 0))
	var on_close: Callable = opts.get("on_close", Callable())
	Audio.play("button_tap", -4.0)

	var modal := Overlay.modal(host, OVERLAY_NAME, {"ink": Pal.GROUND_EDGE, "dismissable": false})
	var overlay: Control = modal["overlay"]
	var dismiss: Callable = modal["dismiss"]
	var cc: CenterContainer = modal["center"]
	overlay.set_meta("farewell_line", line)
	overlay.set_meta("farewell_return_level", int(next_need.get("level", 0)))
	overlay.set_meta("farewell_for_line", int(next_need.get("for_line", 0)))
	var close_once := func() -> void:
		if not is_instance_valid(overlay) or bool(overlay.get_meta("_farewell_closing", false)):
			return
		overlay.set_meta("_farewell_closing", true)
		dismiss.call()
		if on_close.is_valid():
			on_close.call()
	var veil: ColorRect = modal["veil"]
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			close_once.call())

	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var vw: float = host.get_viewport_rect().size.x
	var width: float = vw * Kit.frame_width_pct(cfg) / 100.0

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER

	var art := PieceView.make_piece(line * 100 + 1, width * 0.26, 0.0)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(art)

	var body := Label.new()
	body.text = _body_text(line, next_need, coins)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.max_lines_visible = 3
	body.custom_minimum_size.x = width * 0.80
	body.add_theme_font_size_override("font_size", FS.BODY)
	body.add_theme_color_override("font_color", Pal.INK)
	col.add_child(body)

	var btn: Button = Kit.cta_button(Strings.t("farewell.ok"), Kit.button_opts_from_config(cfg))
	btn.name = "FarewellOK"
	btn.pressed.connect(func() -> void:
		close_once.call())
	col.add_child(btn)

	var dopts: Dictionary = Kit.dialog_opts_from_config(cfg)
	dopts["banner_text"] = Strings.t("farewell.title_returning") if not next_need.is_empty() else Strings.t("farewell.title_complete")
	dopts["min_h"] = width * 0.60
	dopts["on_close"] = close_once
	dopts["outer_scroll_enabled"] = false

	var dialog: Control = Kit.dialog_frame(col, width, dopts)
	cc.add_child(dialog)
	FX.pop_in(dialog)

static func _body_text(line: int, next_need: Dictionary, coins: int) -> String:
	var name := G.item_display_name(int(line) * 100 + 1)
	if not next_need.is_empty():
		var for_name := G.item_display_name(int(next_need.get("for_line", 0)) * 100 + 1)
		var coin_clause := ""
		if coins > 0:
			coin_clause = Strings.t("farewell.returning_coin_clause_one" if coins == 1 else "farewell.returning_coin_clause") % coins
		return Strings.t("farewell.returning_body") % [name, int(next_need.get("level", 0)), for_name, coin_clause]
	var done_clause := ""
	if coins > 0:
		done_clause = Strings.t("farewell.complete_coin_clause_one" if coins == 1 else "farewell.complete_coin_clause") % coins
	return Strings.t("farewell.complete_body") % [name, done_clause]
