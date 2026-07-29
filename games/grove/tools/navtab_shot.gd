extends SceneTree
## Dev tool (real renderer; via engine/tools/quiet_godot.sh): render ONE nav tab in ISOLATION on a FLAT
## field of the concept mock's OWN sky, at the mock's OWN tab pixel size — and, in the same sheet, a 1:1
## crop of a tab out of the mock itself. That pairing is the whole point.
##
## WHY IT EXISTS. The bottom row was restyled off `_concepts/screens/palette_a_meadow_sky_board.png`, and
## every shadow tuning round before this one was "verified" by measuring OUR row on a leafy home screen
## (or a blue-grey gallery) at 1080px, in our chalked fills, against THE MOCK's row on its flat sky at
## 931px in its own fills. A shadow's alpha is INFERRED from a luma ratio, so it depends on the ground
## it falls on; the scale differed by 1.16x and the fills differed too. Those numbers could not be
## compared and the conclusions drawn from them were not evidence. This tool removes all three variables
## at once: same background pixels, same scale, and `fill=` forces our tab to the mock tab's own face
## colour so the ONLY thing left varying is the shadow.
##
##   make shot-navtab OUT=/tmp/navtab.png TABS="mock:home home home:halo=0.11,0,38"
##   make shot TOOL=games/grove/tools/navtab_shot ARGS="/tmp/n.png w=162 mock:shop play:active"
##
## Each TAB is `ROLE[:MOD][:MOD]…`; cells are laid left to right, all bottom-aligned on ONE baseline so
## every tab bleeds off the sheet's bottom edge exactly as it bleeds off the screen.
##   home / map / play / bag / …   a nav tab for that action-button role (Kit.ACTION_GLYPHS)
##   mock:home · mock:shop         the MOCK's own pixels for that tab, 1:1, uncompressed (see MOCK_TABS)
##   :active                       the raised current tab (wider, taller, white rim)
##   :halo=REACH_FRAC,FALLOFF,ALPHA_PCT[,OFFSET_FRAC]  override the tab's cast-shadow tuning, the last
##                                 field being the light's own offset (`:halo=off` removes the shadow)
##   :glyph=off | :glyph=DY,GROW,A/DY,GROW,A/…   override the ICON's shadow stack (`off` removes it;
##                                 layers are split on `/` because `;` would end the shell command)
##   :fill=#RRGGBB                 force the paper face colour (the mock's own, so fill stops being a variable)
##   :cap=TEXT                     override the caption
##   :label=TEXT                   override the text printed above the cell
## Global `key=value` args: `bg=` the flat field · `w=` the tab's slot width · `pad=` the sky margin
## round each tab · `labels=0` to drop the label band (a fully clean field for measuring).
##
## The tool PRINTS a `NAVTAB cells=[…]` JSON line giving every cell's rect and the tab rect inside it, so
## a measuring pass samples the exact columns the tab was drawn at instead of re-finding its edges.
const Base = preload("res://engine/tools/shot_base.gd")
const NavBar = preload("res://engine/scripts/ui/nav_bar.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")

## The concept mock this row was drawn from, and the tab rects measured off it (931x1690 canvas; a tab's
## paper runs off the bottom edge, so a rect is x · top · width and the height is whatever reaches 1690).
## Home and Shop are the two the sheet wants: Home is the LEFTMOST tab, with 24px of untouched sky to its
## left, and Shop the RIGHTMOST, with 37px to its right — the only two edges in the row where a shadow
## falls on plain sky instead of into a gap shared with a neighbour.
##
## `sky` is the window of the mock the crop may take: the tab plus only as much surrounding sky as is
## genuinely EMPTY. It is not a framing preference — outside it the crop would carry a neighbouring tab
## (Home's right edge is 10px from Board) or the info card that runs the full width 20px above the row.
## The mock has NO clean sky above any tab, so `sky` opens 5px above the tab and no more, and the top of
## a mock cell is the flat field. Whatever the sheet does not crop, it does not claim.
const MOCK_PNG := "res://games/grove/assets/_concepts/screens/palette_a_meadow_sky_board.png"
const MOCK_SIZE := Vector2i(931, 1690)
const MOCK_TABS := {
	"home": {"tab": Rect2i(24, 1551, 162, 0), "sky": Rect2i(0, 1546, 191, 144)},
	"shop": {"tab": Rect2i(728, 1553, 166, 0), "sky": Rect2i(722, 1548, 209, 142)},
}
## The mock's sky BEHIND the row, as the flat field our tab is rendered on: the mean over the two clean
## patches either side of the row (x<15 and x>915, y 1560..1688) — (122,184,208), luma 168.3, sigma 2.7.
const MOCK_SKY := "#7AB8D0"
## The mock's own tab width, in its own pixels. Our row's tab is ~1.16x this on the 1080 canvas, so a
## capture of the live row cannot be laid beside the mock without resampling one of them; rendering at
## the mock's number instead keeps both sets of pixels native. Every nav metric is a fraction of this
## width, so the whole tab — corner, glyph, caption, shadow reach — scales with it coherently.
const MOCK_TAB_W := 162.0
const PAD := 44.0            # sky either side of a tab: wider than any shadow reach in play (~16px)
const LABEL_H := 30.0

## Captions for the roles the row ships (games/grove/strings.json map.nav.*); anything else is titled
## from its own role name.
const CAPTION := {"play": "Board", "map": "Map", "home": "Home", "residents": "Residents",
	"mail": "Mail", "daily": "Daily", "vault": "Vault", "bag": "Bag", "almanac": "Almanac"}

func _initialize() -> void:
	var ctx := await Base.begin(self, {"tool": "navtab", "default_out": "/tmp/navtab.png", "save": false})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var args: Array = ctx["args"]
	var out: String = ctx["out"]
	# 1:1 PIXELS, ALWAYS. The game stretches its 1080x1920 canvas to the window, which on a wide capture
	# window letterboxes the drawing into a sub-rect and resamples every tab on the way — a measuring rig
	# cannot afford either. Disabling the stretch makes a `WxH` arg buy real room instead of a scale
	# factor, so a sweep of six tunings fits in ONE launch.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	UiFont.apply()                    # the real global font — the caption must read as it ships

	var specs: Array = []
	var wxh := RegEx.create_from_string("^[0-9]+x[0-9]+$")     # shot_base's window-size arg, not a tab
	for a in args.slice(1):
		if "=" in String(a).split(":")[0] or wxh.search(String(a)) != null:
			continue                                # a `key=value` global (or the size) is not a tab spec
		specs.append(String(a))
	if specs.is_empty():
		specs = ["mock:home", "home"]               # the default sheet: the mock's tab beside ours

	var slot_w := maxf(24.0, float(Base.opt(args, "w", str(MOCK_TAB_W))))
	var pad := maxf(0.0, float(Base.opt(args, "pad", str(PAD))))
	var label_h := 0.0 if Base.opt(args, "labels", "1") == "0" else LABEL_H
	var bg_col := Color(Base.opt(args, "bg", MOCK_SKY))

	var bg := ColorRect.new()
	bg.color = bg_col
	bg.size = Vector2(4000, 4000)                   # covers the window, so the crop is never dark
	root.add_child(bg)

	# One pass to size the sheet: the widest DRAWN sheet and the tallest tab decide the cell.
	var plans: Array = []
	var cell_w := 0.0
	var tab_h := 0.0
	for spec in specs:
		var p := _plan(String(spec), slot_w)
		plans.append(p)
		cell_w = maxf(cell_w, float(p["drawn_w"]) + pad * 2.0)
		tab_h = maxf(tab_h, float(p["visible_h"]))
	var content := Vector2(cell_w * float(plans.size()), label_h + pad + tab_h)

	var cells: Array = []
	for i in plans.size():
		var p: Dictionary = plans[i]
		var drawn: float = p["drawn_w"]
		var x := float(i) * cell_w + (cell_w - drawn) * 0.5
		var y := content.y - float(p["visible_h"])           # every tab bleeds off the SAME bottom line
		# how many px of GENUINE mock sky the cell carries on each side. Past it the cell is the flat
		# field, where a profile would read a serene 0.000 and mean nothing; navtab_profile.py refuses to
		# report beyond these, so a crop that ran out of mock cannot be mistaken for a shadow that ended.
		var real := {"left": int(pad), "right": int(pad), "top": int(pad)}
		if bool(p["is_mock"]):
			var box := _add_mock(bg, p, Vector2(x, y), pad)
			var r: Rect2i = p["rect"]
			real = {"left": r.position.x - box.position.x, "top": r.position.y - box.position.y,
				"right": (box.position.x + box.size.x) - (r.position.x + r.size.x)}
		else:
			_add_tab(bg, p, Vector2(x, y), slot_w)
		if label_h > 0.0:
			var lbl := Label.new()
			# `_` reads as a space: the whole tab spec arrives as ONE shell word, so a label cannot
			# contain a real space and still be one argument.
			lbl.text = String(p["label"]).replace("_", " ")
			lbl.clip_text = true
			lbl.position = Vector2(float(i) * cell_w, 4.0)
			lbl.size = Vector2(cell_w, label_h)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_color_override("font_color", Color("#20303A"))
			lbl.add_theme_font_size_override("font_size", 17)
			bg.add_child(lbl)
		cells.append({"spec": p["spec"], "label": String(p["label"]).replace("_", " "),
			"cell_x": int(round(float(i) * cell_w)), "cell_w": int(round(cell_w)),
			"tab_x": int(round(x)), "tab_y": int(round(y)),
			"tab_w": int(round(float(p["fill_w"]))), "tab_h": int(round(float(p["visible_h"]))),
			"real_ground": real})

	await create_timer(0.4).timeout
	# a sheet wider than the framebuffer would be CROPPED, and a cropped last cell still profiles — as
	# nonsense. Say so loudly; the fix is a bigger `WxH` arg (shot_base honours it).
	if content.x > root.size.x or content.y > root.size.y:
		push_error("navtab_shot: %d cells need %dx%d but the window is %s — pass a bigger WxH arg" % \
			[plans.size(), int(content.x), int(content.y), str(root.size)])
	var err := Base.capture(self, out, args, Rect2i(0, 0, int(content.x), int(content.y)))
	# the cell map goes NEXT TO the PNG as well as to stdout: navtab_profile.py reads `<sheet>.json` by
	# default, so a measuring pass can never be run against a stale hand-copied rect list.
	var side := FileAccess.open(out + ".json", FileAccess.WRITE)
	if side != null:
		side.store_string(JSON.stringify(cells))
		side.close()
	print("NAVTAB saved=%s err=%d canvas=%dx%d bg=%s w=%.1f cells=%s" % \
		[out, err, int(content.x), int(content.y), bg_col.to_html(false), slot_w, JSON.stringify(cells)])
	quit()

## Parse `ROLE[:MOD]…` into everything the layout pass needs before anything is built.
## `drawn_w` is the sheet's full drawn width (the active tab's rim lives outside its fill), `fill_w` the
## FACE's own width — the one a shadow is measured out from — and `visible_h` the height on screen.
func _plan(spec: String, slot_w: float) -> Dictionary:
	var parts := spec.split(":")
	var role := String(parts[0])
	var mods: Dictionary = {}
	for i in range(1, parts.size()):
		var m := String(parts[i])
		var eq := m.find("=")
		if eq < 0:
			mods[m] = "1"
		else:
			mods[m.substr(0, eq)] = m.substr(eq + 1)
	if role == "mock":
		var which := String(parts[1]) if parts.size() > 1 else "home"
		var entry: Dictionary = MOCK_TABS.get(which, MOCK_TABS["home"])
		var r: Rect2i = entry["tab"]
		return {"spec": spec, "is_mock": true, "which": which, "rect": r, "sky": entry["sky"], "mods": mods,
			"drawn_w": float(r.size.x), "fill_w": float(r.size.x), "visible_h": float(MOCK_SIZE.y - r.position.y),
			"label": String(mods.get("label", "MOCK %s  1:1" % which))}
	var active := mods.has("active")
	var box: Vector2 = NavBar.active_size(slot_w) if active else NavBar.tile_size(slot_w)
	return {"spec": spec, "is_mock": false, "role": role, "mods": mods, "active": active, "box": box,
		"drawn_w": NavBar.drawn_w(slot_w, active), "fill_w": box.x, "visible_h": box.y,
		"label": String(mods.get("label", spec))}

## The mock's own pixels for one tab, 1:1. Loaded through Image.load_from_file (NOT load()): the concept
## PNG is an imported texture, and whatever compression that import carries would move the very luma this
## sheet exists to measure. The crop runs to the canvas bottom, so the mock tab bleeds off the sheet's
## bottom edge the same way ours does; where the mock has less sky beside the tab than `pad`, the flat
## field shows through, which is the SAME colour the crop's own sky averages to.
func _add_mock(parent: Control, plan: Dictionary, at: Vector2, pad: float) -> Rect2i:
	var r: Rect2i = plan["rect"]
	var sky: Rect2i = plan["sky"]
	var img := Image.load_from_file(ProjectSettings.globalize_path(MOCK_PNG))
	if img == null:
		push_error("navtab_shot: could not read %s" % MOCK_PNG)
		return Rect2i()
	# the crop the caller asked for (tab ± pad, down to the canvas edge), clipped to the window of the
	# mock that is genuinely empty sky — see MOCK_TABS.sky.
	var want := Rect2i(r.position.x - int(pad), r.position.y - int(pad),
		r.size.x + int(pad) * 2, img.get_height() - (r.position.y - int(pad)))
	var box := want.intersection(sky).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if box.size.x <= 0 or box.size.y <= 0:
		return Rect2i()
	var cx := box.position.x
	var cy := box.position.y
	var cw := box.size.x
	var ch := box.size.y
	var cut := img.get_region(box)
	var tex := TextureRect.new()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE          # set BEFORE size: it clamps the min otherwise
	tex.texture = ImageTexture.create_from_image(cut)
	tex.size = Vector2(cw, ch)
	tex.position = Vector2(at.x - float(r.position.x - cx), at.y - float(r.position.y - cy))
	parent.add_child(tex)
	return box

## One of OUR tabs, built through the SAME two calls the live row makes (NavBar.tab_opts + NavBar.tab_cp
## merged over Kit.action_button_opts_from_config), so what lands on the sheet is the shipping tab and not
## a re-implementation of it. The `:halo=` / `:glyph=` / `:fill=` mods patch the result afterwards — which
## is how one launch can show the tuning before AND after a change without touching the constants.
func _add_tab(parent: Control, plan: Dictionary, at: Vector2, slot_w: float) -> void:
	var Kit: GDScript = Game.kit_script()
	if Kit == null:
		push_error("navtab_shot: no UI kit for this game")
		return
	var role: String = plan["role"]
	var mods: Dictionary = plan["mods"]
	var box: Vector2 = plan["box"]
	var active: bool = plan["active"]
	var o: Dictionary = Kit.action_button_opts_from_config(Game.kit_config())
	o.merge(NavBar.tab_opts(slot_w), true)
	o["name"] = "NavTab_" + role
	o["caption"] = String(mods.get("cap", CAPTION.get(role, role.capitalize())))
	o["active"] = active
	o["fill"] = Color(String(mods["fill"])) if mods.has("fill") \
		else NavBar.chalk(Kit.action_role_fill(role, o.get("tints", {})))
	# the paper runs one corner radius past the bottom edge, so the bottom corners round OFF the sheet and
	# only the top two show — the bled tab bar. (`Look.safe_bottom` is 0 on a desktop capture.)
	var bleed := float(o["corner"])
	o["bleed_bottom"] = bleed
	var cp: Dictionary = (o.get("cp", {}) as Dictionary).duplicate()
	cp.merge(NavBar.tab_cp(slot_w, box.y, box.y + bleed, active), true)
	if mods.has("halo"):
		var h := String(mods["halo"])
		if h == "off":
			cp["halo_reach"] = 0.0
		else:
			var f := h.split(",")
			cp["halo_reach"] = slot_w * float(f[0])
			cp["halo_falloff"] = float(f[1]) if f.size() > 1 else 0.0
			cp["halo_strength"] = float(f[2]) if f.size() > 2 else 38.0
			# the 4th field is the LIGHT: the halo's offset, down-right, as a fraction of the tab width
			# (0 or absent = the symmetric ring). See CutPaper.halo_offset.
			var off: float = slot_w * (float(f[3]) if f.size() > 3 else 0.0)
			cp["halo_offset"] = Vector2(off, off)
	o["cp"] = cp
	if mods.has("glyph"):
		o["glyph_shadow"] = _glyph_stack(String(mods["glyph"]))
	var b: Button = Kit.action_button(role, box, Callable(), o)
	b.position = at + Vector2((float(plan["drawn_w"]) - box.x) * 0.5, 0.0)
	b.size = box
	parent.add_child(b)

## `off` → no icon shadow; else `DY,GROW,A/DY,GROW,A/…` → that literal stack. Literal rather than a
## named preset on purpose: the stack a past commit shipped is then a command-line argument, so the rig
## can render a retired tuning without checking the tree out at that commit. `/` separates the layers
## because a `;` inside a `make TABS=...` value ends the shell command instead.
func _glyph_stack(s: String) -> Array:
	if s == "off":
		return []
	var out: Array = []
	for layer in s.split("/", false):
		var f := String(layer).split(",")
		if f.size() >= 3:
			out.append({"dy": float(f[0]), "grow": float(f[1]), "a": float(f[2])})
	return out
