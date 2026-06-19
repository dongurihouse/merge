extends RefCounted
## Global UI font + cozy text styling.
##
## Uses a ROUNDED, TINTABLE font (so font_color works) and adds a dark outline globally so
## cream/peach text pops on the warm backgrounds. The face is the ACTIVE GAME's (Game.font());
## when a game ships none (e.g. the placeholder), a rounded SYSTEM font is used instead.

const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
static var _done := false

## The cozy UI face: the active game's variable TTF pinned to SemiBold (grove ships none today),
## else a rounded/friendly SYSTEM font. Mipmaps keep glyphs crisp when the 1080 canvas is
## down-sampled (the fix for the blurry shop text). Emoji/symbols fall back to system fonts.
static func _face() -> Font:
	var ttf := Game.font()                 # the active game's UI font ("" = none)
	if ttf != "" and ResourceLoader.exists(ttf):
		var fv := FontVariation.new()
		fv.base_font = load(ttf)
		fv.variation_opentype = {"wght": 600}
		return fv
	var sys := SystemFont.new()
	# cute / rounded / friendly faces; first available wins, generic fallback last
	sys.font_names = PackedStringArray([
		"Arial Rounded MT Bold", "Chalkboard SE", "Marker Felt",
		"Comic Sans MS", "SF Pro Rounded", "Verdana", "Arial",
	])
	sys.font_weight = 700          # chunky / bold for the cozy look
	sys.generate_mipmaps = true
	return sys

## Build the cozy text Theme WITHOUT installing it. apply() puts this on the running game's root;
## dev tools that want the look on a SINGLE preview node (so they don't restyle the whole editor
## when run as @tool) assign it to that node's `theme` instead.
##   outline_size is ABSOLUTE (px): a single default has to read on the SMALL inherited text
##   (~28-34px pill numbers). 4px (~10-14% of the glyph) is a clean cozy halo there; big headings
##   set their own. (Per-label font_color / outline overrides still win where set.)
static func make() -> Theme:
	var th := Theme.new()
	th.default_font = _face()
	th.default_font_size = 40
	for t in ["Label", "Button", "RichTextLabel", "LineEdit"]:
		th.set_color("font_outline_color", t, Pal.BG_DEEP)
		th.set_constant("outline_size", t, 4)
	return th

static func apply() -> void:
	if _done:
		return
	_done = true
	Engine.get_main_loop().root.theme = make()
