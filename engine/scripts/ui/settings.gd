extends RefCounted
## The SETTINGS card (music · sounds) — opened from the map's side-rail Settings tile.
##
## The FACE is now BUILT from the shared MAIL KIT (games/grove/tools/ui_workbench_kit.gd) using the
## design config the UI WORKBENCH saves — the SAME pattern the mailbox (inbox.gd) and daily (login.gd)
## use. The shared dialog FRAME (parchment card · gold banner · ✕) wraps a column of TOGGLE CARDS, one
## per persisted flag — the look (banner, card art, switch size, label font, width) is authored ONCE in
## the workbench's Settings + Toggle-card items and read here, never duplicated. Only the BEHAVIOUR
## (which flags, their defaults, persistence + side-effects) lives in this file.
## Layering: ui/ may import core/ + ui/, never scenes/ — see docs/design/merge_spec.md §15. The kit is
## loaded by PATH at runtime (like inbox.gd) so this file keeps no hard dependency on a tools script.

const Strings = preload("res://engine/scripts/core/strings.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Music = preload("res://engine/scripts/core/music.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const Pal = Game.PALETTE
const OVERLAY_NAME := "SettingsOverlay"

# The kit ships in the game build (export_filter=all_resources); load() at runtime keeps this file from
# hard-depending on a tools script, matching the inbox/login idiom.
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
# The privacy policy the App Store listing points at — also reachable in-app (reviewer-expected for a
# paid-IAP app). The SAME URL goes in App Store Connect's "Privacy Policy URL" field.
const PRIVACY_URL := "https://dongurihouse.net/privacy"

# The persisted flags, in display order: key · label (localized at build) · the unset default. Music
# re-evaluates playback on change (Music.refresh); the rest are pull-based, so no side-effect needed.
const FLAGS := [
	{"key": "music", "label": "Music", "def": false},
	{"key": "sfx", "label": "Sounds", "def": true},
	{"key": "haptics", "label": "Vibration", "def": true},
]

static func open(host: Control) -> void:
	if Overlay.is_open(host, OVERLAY_NAME):
		return
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("Settings: mail kit missing at %s" % KIT_PATH)
		return
	Audio.play("button_tap", -2.0)

	var overlay := Overlay.mount(host, OVERLAY_NAME)
	# the dimmed backdrop, dismissing on tap (the same light modal seam as mail / shop / bag).
	var veil := ColorRect.new()
	veil.color = Color(Pal.INK, 0.6)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	# the dialog renders at the SINGLE global frame width; content scales from the authored baseline
	# (Kit.DIALOG_DESIGN_PCT) to that width — responsive across phones.
	var vw: float = host.get_viewport_rect().size.x
	var width: float = vw * Kit.DIALOG_DESIGN_PCT["settings"] / 100.0

	# build the kit settings dialog (shared frame + a toggle card per flag) from the saved design config.
	var opts: Dictionary = Kit.settings_opts_from_config(cfg)
	opts["content_scale"] = Kit.dialog_content_scale(cfg, "settings")
	opts["on_close"] = func() -> void:
		if is_instance_valid(overlay): overlay.queue_free()
	opts["banner_text"] = Strings.t("settings.title")
	# the Privacy Policy link under the toggles — opens the policy in the system browser.
	opts["footer_text"] = Strings.t("settings.privacy")
	opts["on_footer"] = func() -> void:
		Audio.play("button_tap", -2.0)
		OS.shell_open(PRIVACY_URL)
	var dialog: Control = Kit.settings_dialog(_entries(host), width, opts)
	cc.add_child(dialog)
	FX.pop_in(dialog)

# Map the persisted FLAGS → kit toggle entries: a localized label, the saved value, and an on_toggle that
# persists the new state, runs the flag's side-effect (music re-evaluates playback), and clicks. The
# switch repaints itself (Look.toggle_switch), so — unlike the mailbox — no dialog rebuild is needed.
static func _entries(host: Control) -> Array:
	var out: Array = []
	for f in FLAGS:
		var key := String(f.key)
		var e := {
			"label": host.tr(String(f.label)),
			"value": Save.get_setting(key, bool(f.def)),
		}
		e["on_toggle"] = func(on: bool) -> void:
			Save.set_setting(key, on)
			if key == "music":
				Music.refresh()
			Audio.play("button_tap", -2.0)
		out.append(e)
	return out
