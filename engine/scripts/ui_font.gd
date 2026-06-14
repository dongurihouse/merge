extends RefCounted
## Global UI font + cozy text styling.
##
## Uses a ROUNDED, TINTABLE font (so font_color works) and adds a dark outline globally so
## cream/peach text pops on the warm backgrounds. The face is the ACTIVE GAME's (Game.font());
## when a game ships none (e.g. the placeholder), a rounded SYSTEM font is used instead.

const Game = preload("res://engine/scripts/game.gd")
const Pal = Game.PALETTE
static var _done := false

static func apply() -> void:
	if _done:
		return
	_done = true

	var f: Font
	var ttf := Game.font()                 # the active game's UI font ("" = none)
	if ttf != "" and ResourceLoader.exists(ttf):
		# the game's variable TTF (e.g. grove's Baloo 2, OFL, license alongside)
		# pinned to SemiBold; emoji/symbols fall back to system fonts.
		var fv := FontVariation.new()
		fv.base_font = load(ttf)
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
		th.set_color("font_outline_color", t, Pal.BG_DEEP)
		th.set_constant("outline_size", t, 10)
	Engine.get_main_loop().root.theme = th
