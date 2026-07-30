extends SceneTree
## Dev tool: the paper-MEDAL level badge, every tier × every digit count, on ONE flat field at the
## SHIPPED slot size — the sheet the number's centring is measured on.
##
##   make shot TOOL=games/grove/tools/medal_badge_shot ARGS="/tmp/medal.png"
##   (needs the REAL renderer: get_image() returns null under --headless)
##
## WHY THIS EXISTS. The bar is "the number's ink is optically dead centre on the DISC, at every tier
## and at 1/2/3 digits, measured on the real render". The live screens can only ever show ONE of
## those nine cases (the player's own level), and a mock sheet is a different renderer fitting a
## different box. This builds the badge through Look.make_star_level_badge — the same call the HUD
## makes, at the same 116 px slot, with the same Hud._lv_font_size — so the pixels measured are the
## pixels shipped.
##
## It writes TWO files: `<out>` and `<out>_blank.png`, identical except that the blank one carries
## no number. That is the centring skill's blank-plate method: the ink mask is the DIFFERENCE of the
## two, so nothing about the ink is inferred from colour and the art can never be mistaken for it.
##
## THE DIGIT COUNT IS FORCED, and deliberately so: t1 is worn at L1-10 and t3 from L41, so no single
## save can show t1 with three digits. The tool sets `lv_num`'s text + font_size exactly the way
## Hud.refresh does on a level tick, which is the real path, then measures what that draws.

const Base = preload("res://engine/tools/shot_base.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")

const PX := 116.0            # the shipped HUD slot: ceil(pill_h 87 × Hud.LEVEL_BADGE_SCALE 1.35)
const CELL := Vector2(190, 210)
const ORIGIN := Vector2(40, 40)
const FIELD := Color(0.42, 0.44, 0.46)   # flat, mid, unsaturated: fuses with neither the cream
                                         # disc (bright) nor Pal.INK (dark) nor any ribbon
## One exemplar level per medal tier, and one per digit count. The tier column comes from the
## LEVEL (the shipping map); the digit column is forced on top of it.
const TIER_LEVELS := [2, 24, 85]         # the three approved mocks' own labels
const DIGIT_LEVELS := [7, 88, 888]

func _initialize() -> void:
	var ctx := await Base.begin(self, {"tool": "medal_badge", "default_out": "/tmp/medal_badge.png", "save": false})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var out: String = ctx["out"]
	UiFont.apply()                # the same root theme the running game installs
	var root := get_root()
	var bg := ColorRect.new()
	bg.color = FIELD
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var nums: Array[Label] = []
	for r in TIER_LEVELS.size():
		for c in DIGIT_LEVELS.size():
			var lvl := int(DIGIT_LEVELS[c])
			var badge := Look.make_star_level_badge(int(TIER_LEVELS[r]), PX, Hud._lv_font_size(lvl, PX))
			badge.position = ORIGIN + Vector2(CELL.x * c, CELL.y * r)
			var num := badge.get_node_or_null("lv_num") as Label
			if num != null:
				num.text = str(lvl)          # the digit count, applied the way Hud.refresh applies it
				nums.append(num)
			root.add_child(badge)
	# the machine-readable cell map, so the measuring script never guesses where a badge is
	print("MEDAL_SHEET origin=%.0f,%.0f cell=%.0f,%.0f px=%.0f rows=%s cols=%s" % \
		[ORIGIN.x, ORIGIN.y, CELL.x, CELL.y, PX, str(TIER_LEVELS), str(DIGIT_LEVELS)])
	await process_frame
	await process_frame
	var err := Base.capture(self, out, ctx["args"])
	if err != OK:
		print("FAIL: no image (run through quiet_godot.sh, not --headless)")
		quit(1)
		return
	# ... and the same sheet with the numbers suppressed: the blank plate the ink is differenced against
	for n in nums:
		n.text = ""
	await process_frame
	await process_frame
	var blank: String = out.get_basename() + "_blank." + out.get_extension()
	err = Base.capture(self, blank, ctx["args"])
	if err != OK:
		print("FAIL: no image for the blank plate")
		quit(1)
		return
	# ... and the BIAS plate: the same Label geometry with no art under it, at INTEGER positions, so
	# the face's own line-box-vs-ink bias can be read without the badge's fractional offset or the
	# disc detector in the way. A Label centres its LINE BOX (ascent+descent); the digits' ink is not
	# centred in that box, and the gap is what this measures. The game ships NO bundled TTF
	# (games/grove/game.gd FONT := ""), so the face here is the SystemFont the engine falls back to,
	# emboldened by Kit.bold_font() — measured, never assumed.
	for c in root.get_children():
		if c != bg:
			root.remove_child(c)
			c.queue_free()
	var Kit = Game.kit_script()
	bg.color = Color(0.96, 0.92, 0.86)          # flat cream: dark ink on it, nothing else
	var fonts := [49, 39, 31]
	for r in fonts.size():
		for c in DIGIT_LEVELS.size():
			var box := ColorRect.new()          # the rect whose centre the ink is measured against
			box.color = Color(0.55, 0.75, 0.55)
			box.position = ORIGIN + Vector2(CELL.x * c, CELL.y * r)
			box.size = Vector2(PX, PX)
			root.add_child(box)
			var l := Label.new()
			l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.text = str(DIGIT_LEVELS[c])
			l.add_theme_font_override("font", Kit.bold_font())
			l.add_theme_font_size_override("font_size", int(fonts[r]))
			l.add_theme_color_override("font_color", Pal.INK)
			l.add_theme_constant_override("outline_size", 0)
			box.add_child(l)
	print("BIAS_SHEET origin=%.0f,%.0f cell=%.0f,%.0f box=%.0f fonts=%s cols=%s" % \
		[ORIGIN.x, ORIGIN.y, CELL.x, CELL.y, PX, str(fonts), str(DIGIT_LEVELS)])
	await process_frame
	await process_frame
	var bias: String = out.get_basename() + "_bias." + out.get_extension()
	err = Base.capture(self, bias, ctx["args"])
	if err != OK:
		print("FAIL: no image for the bias plate")
		quit(1)
		return
	print("wrote ", out, ", ", blank, " and ", bias)
	quit(0)
