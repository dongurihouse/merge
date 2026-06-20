extends RefCounted
## Level dialog — the kit-built parchment dialog (ref lvl.png). Two modes, one dialog:
##   LevelPopup.open(host)              — INFO: tap-to-view (HUD level badge / locked cell). "Got it",
##                                        veil-dismissable, no reward.
##   LevelPopup.open_levelup(host, n)   — LEVELUP: auto on a level gain. Shows the earned gift; the
##                                        "Collect" button GRANTS it (grant_level_gift) then closes.
##                                        NOT veil-dismissable (only Collect closes) so the reward
##                                        can't be lost.
## Self-contained (like the old popup): builds into `host`. Renders via the shared kit (Kit.level_dialog),
## so the workbench tunes its look and the game reads the same config.

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Pal = Game.PALETTE
const OVERLAY_NAME = "LevelPopupOverlay"
const DEFAULT_WIDTH_PCT := 80.0

static func open(host: Control) -> Control:
	return _build(host, "info", 0)

static func open_levelup(host: Control, levels_up: int) -> Control:
	return _build(host, "levelup", maxi(1, levels_up))

static func _build(host: Control, mode: String, levels_up: int) -> Control:
	# Idempotent: keep exactly one popup per host. emulate_touch_from_mouse delivers a tap as BOTH a
	# mouse AND a touch event, so a trigger's gui_input can fire open() twice in one frame — without this
	# guard that stacks two overlays. add_child is synchronous, so the duplicate event finds the first here.
	var live := host.get_node_or_null(NodePath(OVERLAY_NAME))
	if live is Control and not (live as Node).is_queued_for_deletion():
		return live as Control

	var earned := int(Save.grove().get("stars_earned", 0))
	var lvl := G.level_for_stars(earned)
	var base := G.stars_at_level(lvl)            # stars to BE at this level
	var nxt := G.stars_at_level(lvl + 1)         # stars to reach the next
	var into := clampi(earned - base, 0, nxt - base)
	var span := maxi(1, nxt - base)
	var remaining := maxi(0, nxt - earned)

	var overlay := Control.new()
	overlay.name = OVERLAY_NAME
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(Pal.INK, 0.5)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	# INFO dismisses on a veil tap; LEVELUP does NOT (only Collect closes, so the reward can't be lost).
	if mode == "info":
		veil.gui_input.connect(func(ev: InputEvent) -> void:
			if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
				overlay.queue_free())

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	var cfg := Kit.load_config(Kit.CONFIG_PATH)
	var opts := Kit.level_opts_from_config(cfg)
	opts["banner_text"] = TranslationServer.translate("Level %d") % lvl
	# responsive: a % of the LIVE screen width (mirrors inbox.gd), so the dialog fits every phone size
	var vw: float = host.get_viewport_rect().size.x
	var pct: float = float((cfg.get("level", {}) as Dictionary).get("width_pct", DEFAULT_WIDTH_PCT))
	var width: float = vw * clampf(pct, 30.0, 100.0) / 100.0

	var gift: Dictionary = G.level_gift(levels_up) if mode == "levelup" else {}
	var data := {
		"level": lvl, "earned": earned, "next": nxt, "into": into, "span": span,
		"remaining": remaining, "mode": mode, "gift": gift,
		"on_button": func() -> void:
			if mode == "levelup":
				G.grant_level_gift(gift)        # the deferred grant — Collect pays out the level-up reward
			overlay.queue_free(),
	}
	var dialog := Kit.level_dialog(data, width, opts)
	cc.add_child(dialog)
	FX.pop_in(dialog)
	return overlay
