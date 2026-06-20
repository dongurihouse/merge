extends RefCounted
## Discovery-ladder MODAL — the tier ladder for a line: a twig-framed parchment board whose tiers fill a
## plain grid (a grown tier shows its piece, an unseen tier the baked "?" cell, the tapped tier the
## gold-ring cell). Self-contained popup, like ui/inbox.gd: builds its overlay into `host`, dismisses on a
## veil tap or the shared ✕, enters with FX.pop_in. The coordinator owns the open-gate (the
## discovery_ladder feature + line validity) and the data (Quests.ladder_entries); this just renders.
##   Ladder.open(host, {title: String, entries: Array, mark_tier: int})
##
## The FACE is BUILT from the shared UI KIT (games/grove/tools/ui_workbench_kit.gd) using the design the
## UI WORKBENCH saves — the twig border, ladder ribbon, ✕ disc and tier-cell look are authored ONCE in the
## workbench (the "tiers" + "tiers_card" items) and read here, never duplicated. There are NO vines — just
## the cards, in a plain grid. Only the open-gate + the entry→cell mapping live here.

const Game = preload("res://engine/scripts/core/game.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Pal = Game.PALETTE

# The kit ships in the game build (export_filter=all_resources); load() at runtime keeps this file from
# hard-depending on a tools script, matching inbox.gd's guarded idiom.
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
const CARD_WIDTH_PCT := 85.0       # default discovery-dialog width as a % of the screen (overridable in config)

static func open(host: Control, opts: Dictionary) -> void:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("Ladder: ui kit missing at %s" % KIT_PATH)
		return
	var title: String = opts.title
	var entries: Array = opts.entries
	var mark_tier: int = opts.mark_tier
	Audio.play("button_tap", -4.0)

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	host.add_child(overlay)
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

	# the board fills a % of the SCREEN width (the workbench saves width_pct), so it's responsive across
	# phone sizes instead of a fixed pixel width.
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var vw: float = host.get_viewport_rect().size.x
	var pct: float = float((cfg.get("tiers", {}) as Dictionary).get("width_pct", CARD_WIDTH_PCT))
	var width: float = vw * clampf(pct, 30.0, 100.0) / 100.0

	# the TIERS dialog opts (twig border + ladder ribbon + ✕ + the tier-cell look) from the saved config.
	# make_content lets the kit build each discovered tile's piece at the cell size IT computes, so this
	# file never touches layout — it just renders the merge piece for a code.
	var dopts: Dictionary = Kit.tiers_opts_from_config(cfg)
	dopts["banner_text"] = host.tr(title)
	dopts["make_content"] = func(d: Dictionary, px: float) -> Control:
		return PieceView.make_piece(int(d.get("code", 0)), px)
	dopts["on_close"] = func() -> void:
		if is_instance_valid(overlay): overlay.queue_free()

	var dialog: Control = Kit.tiers_dialog(_cells(entries, mark_tier), width, dopts)
	cc.add_child(dialog)
	FX.pop_in(dialog)

# Map Quests.ladder_entries ({tier, code, seen}) → kit tier cells ({tier, seen, marked, code}). The kit's
# make_content reads `code` to build the discovered piece; `marked` flags the tapped/asked tier's ring.
static func _cells(entries: Array, mark_tier: int) -> Array:
	var out: Array = []
	for e in entries:
		out.append({
			"tier": int(e.get("tier", 0)),
			"seen": bool(e.get("seen", false)),
			"marked": int(e.get("tier", 0)) == mark_tier,
			"code": int(e.get("code", 0)),
		})
	return out
