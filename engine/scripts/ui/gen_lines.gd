extends RefCounted
## PRODUCING MODAL — the lines a tapped generator currently makes, as a grid of the SAME discovery cells the
## tier ladder uses. A line in the live pop pool wears the gold marked ring (it is being generated right now);
## a line the player has seen shows its lowest-seen piece; an unseen line shows the locked "?" well. Tapping a
## seen line drills into THAT line's tier ladder (the existing Ladder modal, opened on top). Self-contained
## popup like ui/ladder.gd: builds its overlay into `host`, dismisses on a veil tap or the shared ✕, enters
## with FX.pop_in. The coordinator (board.gd) owns the data (which generator, the pool, the seen set) and the
## drill-down callback; this just renders.
##   GenLines.open(host, {entries: Array, on_line: Callable})
##   entries: [{line:int, seen:bool, in_pool:bool, code:int}]  (code = the lowest-seen tier code, 0 if unseen)
##
## The FACE is the SAME shared "tiers" dialog as ui/ladder.gd (twig border, ribbon, ✕ disc, slot cells) from
## the UI WORKBENCH config — only the banner text, the per-cell tap, and the marked=in_pool flag differ.

const Strings = preload("res://engine/scripts/core/strings.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
const CARD_WIDTH_PCT := 85.0       # share the tier ladder's default width (overridable via the tiers config)
const OVERLAY_NAME := "GenLinesOverlay"

static func open(host: Control, opts: Dictionary) -> void:
	if Overlay.is_open(host, OVERLAY_NAME):
		return
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("GenLines: ui kit missing at %s" % KIT_PATH)
		return
	var entries: Array = opts.get("entries", [])
	if entries.is_empty():
		return
	var on_line: Callable = opts.get("on_line", Callable())
	Audio.play("button_tap", -4.0)

	var overlay := Overlay.mount(host, OVERLAY_NAME)
	var veil := ColorRect.new()
	veil.color = Color(Pal.GROUND_EDGE, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	# the board fills the SAME % of the SCREEN width as the tier ladder (the workbench saves tiers.width_pct).
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var vw: float = host.get_viewport_rect().size.x
	var pct: float = float((cfg.get("tiers", {}) as Dictionary).get("width_pct", CARD_WIDTH_PCT))
	var width: float = vw * clampf(pct, 30.0, 100.0) / 100.0

	# the shared tiers dialog opts (twig border + ribbon + ✕ + slot-cell look). Lines carry no tier number
	# (they aren't tiers), so suppress it; make_content reads each cell's `code` to render its piece.
	var dopts: Dictionary = Kit.tiers_opts_from_config(cfg)
	dopts["show_num"] = false
	dopts["banner_text"] = Strings.t("producing.title")
	dopts["make_content"] = func(d: Dictionary, px: float) -> Control:
		var piece := PieceView.make_piece(int(d.get("code", 0)), px)
		# a SEEN but NOT-in-pool line is a discovered line the generator ISN'T making right now — recede it
		# (greyscale + faded) so only the live pop pool's pieces read as "currently producing".
		if not bool(d.get("marked", false)):
			_recede(piece)
		return piece
	dopts["on_close"] = func() -> void:
		if is_instance_valid(overlay): overlay.queue_free()

	var dialog: Control = Kit.tiers_dialog(_cells(entries, on_line), width, dopts)
	cc.add_child(dialog)
	FX.pop_in(dialog)

# Desaturate (greyscale) the discovered-but-inactive cell's sprite so it clearly recedes behind the live
# pool's full-colour pieces; the holder fade also dims its contact shadow. One shared material across cells.
const _RECEDE_SHADER := "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tfloat g = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n\tc.rgb = mix(c.rgb, vec3(g), 0.92);\n\tc.rgb *= 0.92;\n\tCOLOR = c;\n}\n"
static var _recede_mat: ShaderMaterial

static func _recede(piece: Control) -> void:
	piece.modulate = Color(1.0, 1.0, 1.0, 0.62)        # fade the whole piece (sprite + contact shadow) back
	if _recede_mat == null:
		var sh := Shader.new()
		sh.code = _RECEDE_SHADER
		_recede_mat = ShaderMaterial.new()
		_recede_mat.shader = sh
	_apply_mat(piece, _recede_mat)

static func _apply_mat(n: Node, mat: ShaderMaterial) -> void:
	if n is TextureRect or n is Sprite2D:
		(n as CanvasItem).material = mat
	for c in n.get_children():
		_apply_mat(c, mat)

# Map line entries → kit discovery cells. tier 0 keeps the number badge off; marked rides the live pop pool;
# `code` feeds make_content's piece (only a SEEN line is filled); on_tap drills a seen line into its ladder.
static func _cells(entries: Array, on_line: Callable) -> Array:
	var out: Array = []
	for e in entries:
		var line := int(e.get("line", 0))
		var cell := {
			"tier": 0,
			"seen": bool(e.get("seen", false)),
			"marked": bool(e.get("in_pool", false)),
			"code": int(e.get("code", 0)),
		}
		if on_line.is_valid():
			cell["on_tap"] = func() -> void: on_line.call(line)
		out.append(cell)
	return out
