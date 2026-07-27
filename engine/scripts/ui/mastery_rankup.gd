extends RefCounted
## Generator mastery rank-up card. The board owns queueing and Save.mater_seen;
## this mirrors the retire-offer dialog frame and only renders the celebration.

const Strings = preload("res://engine/scripts/core/strings.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Pal = Game.PALETTE
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale

const OVERLAY_NAME := "MasteryRankupOverlay"

static func is_open(host: Control) -> bool:
	return Overlay.is_open(host, OVERLAY_NAME)

static func open(host: Control, opts: Dictionary) -> Control:
	if Overlay.is_open(host, OVERLAY_NAME):
		return null
	var Kit: GDScript = Game.kit_script()
	if Kit == null:
		push_warning("MasteryRankup: ui kit missing")
		return null
	var line := int(opts.get("line", 0))
	var rank := int(opts.get("rank", 0))
	var window: Vector2i = opts.get("window", Vector2i(1, 4))
	if line <= 0 or rank <= 0:
		return null
	Audio.play("level_complete", -4.0, 1.08)

	var modal := Overlay.modal(host, OVERLAY_NAME, {"ink": Pal.GROUND_EDGE})
	var overlay: Control = modal["overlay"]
	var cc: CenterContainer = modal["center"]
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var width: float = host.get_viewport_rect().size.x * Kit.frame_width_pct(cfg) / 100.0

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER

	var gid := G.gen_for_line(line)
	var art: Control = PieceView.make_generator(gid, width * 0.28, {}, 1) if gid != "" else PieceView.make_piece(line * 100 + 1, width * 0.28, 0.0)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(art)

	var body := Label.new()
	var line_name := String((G.LINES.get(line, {}) as Dictionary).get("name", G.item_display_name(line * 100 + 1)))
	body.text = Strings.t("mastery.rankup.body") % [line_name, window.x, window.y]
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.max_lines_visible = 3
	body.custom_minimum_size.x = width * 0.82
	body.add_theme_font_size_override("font_size", FS.BODY)
	body.add_theme_color_override("font_color", Pal.INK)
	col.add_child(body)

	var btn: Button = Kit.cta_button(Strings.t("mastery.rankup.continue"), Kit.button_opts_from_config(cfg))
	btn.pressed.connect(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free())
	col.add_child(btn)

	var dopts: Dictionary = Kit.dialog_opts_from_config(cfg)
	dopts["banner_text"] = Strings.t("mastery.rankup.title") % rank
	dopts["min_h"] = width * 0.62
	dopts["on_close"] = modal["dismiss"]

	var dialog: Control = Kit.dialog_frame(col, width, dopts)
	cc.add_child(dialog)
	FX.pop_in(dialog)
	FX.burst(host, cc.get_global_rect().get_center(), Pal.STRAW)
	return overlay
