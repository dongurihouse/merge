extends RefCounted
## Tidy Up — global UI font + cozy text styling.
##
## Uses a cute ROUNDED, TINTABLE font (so font_color actually works) and adds a dark outline
## globally so cream/peach text pops on the warm room backgrounds. The generated bitmap atlas
## (ui.fnt) was a baked FULL-COLOR display font — not tintable, no usable outline — so it's no
## longer used for UI text (keep it for big display art only). If a real rounded ui.ttf is ever
## dropped in, it's preferred over the system font for cross-device consistency.

const Palette = preload("res://engine/scripts/palette.gd")
const TTF_PATH := "res://engine/assets/fonts/ui.ttf"
static var _done := false

static func apply() -> void:
	if _done:
		return
	_done = true

	var f: Font
	if ResourceLoader.exists(TTF_PATH):
		# Baloo 2 variable TTF (OFL, license alongside) pinned to SemiBold —
		# the GROVE_UI_SPEC §2 face; emoji/symbols fall back to system fonts.
		var fv := FontVariation.new()
		fv.base_font = load(TTF_PATH)
		fv.variation_opentype = {"wght": 600}
		f = fv
	else:
		var sys := SystemFont.new()
		# cute / rounded / friendly faces; first available wins, generic fallback last
		sys.font_names = PackedStringArray([
			"Arial Rounded MT Bold", "Chalkboard SE", "Marker Felt",
			"Comic Sans MS", "SF Pro Rounded", "Verdana", "Arial",
		])
		sys.font_weight = 700          # chunky / bold for the cozy look
		f = sys

	var th := Theme.new()
	th.default_font = f
	th.default_font_size = 40
	# cozy styling applied to every text control: a dark outline so it pops on the warm bg.
	# (Per-label font_color / outline overrides in the scenes still win where set.)
	for t in ["Label", "Button", "RichTextLabel", "LineEdit"]:
		th.set_color("font_outline_color", t, Palette.BG_DEEP)
		th.set_constant("outline_size", t, 10)
	Engine.get_main_loop().root.theme = th
