extends RefCounted
## The APP STORE UPDATE prompt — an optional, dismissible "Update Available" dialog shown at home open
## when core/update_check.gd finds a newer App Store version. Modeled on ui/settings.gd::open(host):
## a dimmed veil + a centered SHARED dialog frame (ui_workbench_kit.dialog_frame — the SAME parchment
## card · title · ✕ every other dialog uses), wrapping a message + a two-button row (cream "Not now" ·
## green "Update"). Update opens the store page; Not now / ✕ silences this version (Save.update_dismissed).
## Layering: ui/ may import core/ + ui/, never scenes/. The kit is loaded by PATH at runtime (like
## inbox.gd / settings.gd) so this file keeps no hard dependency on a tools script.

const Strings = preload("res://engine/scripts/core/strings.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const Pal = Game.PALETTE
const OVERLAY_NAME := "UpdatePromptOverlay"
static var KIT_PATH := Game.kit()

# Open the prompt over `host`. `store_version` is the App Store version (persisted on dismiss so it does
# not re-nag until a newer one ships); `store_url` is the App Store page opened by Update.
static func open(host: Control, store_version: String, store_url: String) -> void:
	if Overlay.is_open(host, OVERLAY_NAME):
		return
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("UpdatePrompt: kit missing at %s" % KIT_PATH)
		return
	Audio.play("button_tap", -2.0)

	# the dimmed backdrop — tapping it dismisses (same light modal seam as settings / mail / shop).
	# Every close path (veil tap, ✕, "Not now") runs the scaffold's one seam: silence THIS version
	# until a newer one ships, then free.
	var modal := Overlay.modal(host, OVERLAY_NAME, {"on_dismiss": func() -> void:
		Save.mark_update_dismissed(store_version)})
	var cc: CenterContainer = modal["center"]
	var dismiss: Callable = modal["dismiss"]

	var vw: float = host.get_viewport_rect().size.x
	var width: float = vw * 0.62
	var content := _content(Kit, width, store_url, dismiss)
	var opts := {
		"banner_text": Strings.t("update.title"),
		"on_close": dismiss,                           # the ✕ disc → same as Not now
	}
	var dialog: Control = Kit.dialog_frame(content, width, opts)
	cc.add_child(dialog)
	FX.pop_in(dialog)

# The dialog body: a centred message + a row of two pill buttons (cream "Not now" · green "Update").
static func _content(Kit: GDScript, width: float, store_url: String, dismiss: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 30)
	col.alignment = BoxContainer.ALIGNMENT_CENTER

	var msg := Label.new()
	msg.text = Strings.t("update.body")
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.custom_minimum_size.x = width * 0.84
	msg.add_theme_font_size_override("font_size", FS.BODY)
	msg.add_theme_color_override("font_color", Pal.INK)
	msg.add_theme_constant_override("outline_size", 0)
	msg.add_theme_constant_override("line_spacing", 8)
	col.add_child(msg)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var later: Button = Kit.pill_button(Strings.t("update.later"), {"bg": "cream", "font": FS.BODY})
	later.pressed.connect(func() -> void: dismiss.call())
	var update: Button = Kit.pill_button(Strings.t("update.update"), {"bg": "green", "font": FS.BODY})
	update.pressed.connect(func() -> void:
		Audio.play("button_tap", -2.0)
		if store_url != "":
			OS.shell_open(store_url)                   # open the App Store page
		dismiss.call())                                # dismiss persists store_version → no re-nag next launch
	row.add_child(later)
	row.add_child(update)
	col.add_child(row)
	return col
