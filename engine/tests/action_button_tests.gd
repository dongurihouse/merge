extends "res://engine/tests/test_base.gd"
## Headless unit tests for the shared code-drawn action button (Kit.action_button) and its config
## reader. The button draws the rugged cut-paper edge in code (a CutPaperPanel surface) + a centered
## glyph — one source for the home bottom bar and the board Home/Bag wells.
##   godot --headless --path . -s res://engine/tests/action_button_tests.gd

const Kit = preload("res://games/grove/ui_kit.gd")
const CutPaper = preload("res://engine/scripts/ui/cut_paper.gd")

## The darkening below which a cast shadow has stopped being a shadow and is just noise on the ground.
## The mock's own sky grain is ±0.016, so nothing under this is separable from the paper it falls on.
const VISIBLE_DARKENING := 0.02

## How far out from an edge the directional halo is still VISIBLE, in px. `halo_reach` is not that number
## and never was: it is the DILATION the ring stack spans, and `halo_offset` then hands one side more of
## it than the other (down-right, where the light throws it) — `dir` is +1 for that side and -1 for the
## lit one. Bounding the reach alone lets a SYMMETRIC halo pass a test written off a measurement of the
## shadow side, which is exactly how the nav row shipped a four-times-too-heavy lit edge while green.
func _halo_visible_px(reach: float, falloff: float, alpha: float, offset: float, dir: float) -> float:
	for i in 400:
		var x := float(i) * 0.25
		if alpha * CutPaper.halo_profile(falloff, (x - dir * offset) / maxf(reach, 0.001)) < VISIBLE_DARKENING:
			return x
	return 999.0

func _initialize() -> void:
	var root := get_root()

	# 1) the builder returns a Button carrying the code-drawn deckle surface (a CutPaperPanel), NOT a baked sprite
	var opts := {
		"cp": {"deckle": true, "corner": 20.0, "deckle_amp": 5.0, "deckle_freq": 0.05, "rim_width": 2.0, "edge_shadow": true},
		"tints": {"map": "sky"},
		"icon_scale": 0.5,
	}
	var b := Kit.action_button("map", Vector2(120, 120), Callable(), opts)
	root.add_child(b)
	ok(b is Button, "action_button returns a Button")
	var surface := b.find_child("ActionButtonDeckleSurface", true, false)
	ok(surface != null, "the button wears a code-drawn CutPaperPanel surface")
	ok(surface != null and surface.get_script() == load(Kit.CUT_PAPER),
		"the surface is the shared cut_paper.gd panel")

	# 2) the per-button tint resolves the sky paper-role fill onto the panel
	ok(surface != null and surface.paper_color.is_equal_approx(Kit.PAPER_SURFACES["sky"]["fill"]),
		"the map tile fills with its sky paper-role tint")

	# 3) the glyph sits centered on top (a TextureRect wearing the map glyph)
	var rects: Array = b.find_children("*", "TextureRect", true, false)
	var wears_glyph := rects.any(func(tr: TextureRect) -> bool:
		return tr.texture != null and String(tr.texture.resource_path).findn("glyph_map") != -1)
	ok(wears_glyph, "the map tile composites its transparent glyph in the middle")

	# 4) config reader round-trips the cut-paper edge knobs + the tint palette
	var cfg := {"action_button": {"deckle": true, "corner": 24, "deckle_amp": 6, "deckle_freq": 5,
		"rim_width": 3, "edge_shadow": true, "icon_scale": 55,
		"tint_map": "sky", "tint_home": "cream"}}
	var ro := Kit.action_button_opts_from_config(cfg)
	ok(float(ro["cp"]["corner"]) == 24.0, "reader round-trips the edge corner")
	ok(is_equal_approx(float(ro["cp"]["deckle_freq"]), 0.05), "reader normalizes deckle_freq (5 → 0.05)")
	ok(String(ro["tints"].get("map", "")) == "sky", "reader round-trips the per-button tint palette")
	ok(is_equal_approx(float(ro["icon_scale"]), 0.55), "reader normalizes icon_scale (55 → 0.55)")

	# 4b) the cut-paper edge band is a LIT cut edge, not a shaded slab. Light comes from above: an edge
	# facing up takes the full highlight, a SIDE takes light and no shadow at all, and only the foot
	# darkens. A side that shades is what reads as volume — a flat card inflated into a button — so the
	# split is pinned here rather than left to the drawing code.
	var CP := load(Kit.CUT_PAPER)
	var w_top: Vector2 = CP.bevel_weights(-1.0)     # outward normal pointing straight UP
	var w_side: Vector2 = CP.bevel_weights(0.0)     # …horizontal (a side)
	var w_foot: Vector2 = CP.bevel_weights(1.0)     # …straight DOWN
	ok(is_equal_approx(w_top.x, 1.0) and is_equal_approx(w_top.y, 0.0),
		"the top edge takes the full highlight and no shadow (%.2f/%.2f)" % [w_top.x, w_top.y])
	ok(w_side.x > 0.0 and is_equal_approx(w_side.y, 0.0),
		"a SIDE edge is lit, never shaded — the flat-card read (%.2f/%.2f)" % [w_side.x, w_side.y])
	ok(is_equal_approx(w_foot.x, 0.0) and w_foot.y > 0.0,
		"only the foot darkens (%.2f/%.2f)" % [w_foot.x, w_foot.y])
	ok(w_top.x > w_side.x, "…and the top edge catches more light than the sides")

	# 4c) THE SILHOUETTE IS ANTIALIASED. draw_colored_polygon computes no coverage — a pixel is wholly
	# in or wholly out — so a SMOOTH sheet's corner arc rasterizes as a hard binary staircase (the torn
	# deckle hid it; a nav tab, whose deckle is zeroed, is all staircase). `edge_feather` restores the
	# coverage term the rasterizer skipped. Asserted as the drawn PLAN because a real-renderer capture
	# is the only way to look at pixels and get_image() is null under --headless.
	var STEP := 0.1
	var hard := 0
	var soft := 0
	for i in range(-30, 31):
		var d := float(i) * STEP
		if CP.feather_coverage(0.0, d) > 0.0 and CP.feather_coverage(0.0, d) < 1.0:
			hard += 1
		if CP.feather_coverage(1.5, d) > 0.0 and CP.feather_coverage(1.5, d) < 1.0:
			soft += 1
	ok(hard == 0, "no feather = a BINARY step: not one sample of partial coverage (%d)" % hard)
	ok(soft >= 10, "a 1.5px feather covers ~1.5px in partial coverage, not a step (%d samples)" % soft)
	ok(is_equal_approx(CP.feather_coverage(1.5, 0.0), 0.5),
		"…the ramp is centred ON the outline, so the silhouette neither moves nor grows")
	ok(is_equal_approx(CP.feather_coverage(1.5, -0.75), 1.0) and is_equal_approx(CP.feather_coverage(1.5, 0.75), 0.0),
		"…and it is fully opaque half a band in, fully clear half a band out")

	# the plan the drawing follows: a ramp ring straddling the outline, and an opaque core inset PAST
	# that ring's inner lip — the core is an ordinary polygon, so its own staircase must land where the
	# strip is already solid or it shows through as a 1px seam.
	var plan: Dictionary = CP.feather_plan(1.5)
	var ramp: Dictionary = plan["rings"][1]
	ok(is_equal_approx(float(ramp["d_in"]), -0.75) and is_equal_approx(float(ramp["d_out"]), 0.75),
		"the coverage ramp straddles the outline symmetrically")
	ok(is_equal_approx(float(ramp["a_in"]), 1.0) and is_equal_approx(float(ramp["a_out"]), 0.0),
		"…running 1 → 0 across the band")
	ok(float(plan["core"]) < float(ramp["d_in"]),
		"the opaque core is inset past the ramp's inner lip (%.2f < %.2f)" % [plan["core"], ramp["d_in"]])

	# 4d) OPT-IN. A torn surface must draw exactly what it always drew, so the feather is off unless the
	# knob set asks for it; the nav tab — the one smooth surface — asks.
	var EdgeTab := load("res://engine/scripts/ui/edge_tab.gd")
	var plain: Control = load(Kit.CUT_PAPER).new()
	root.add_child(plain)
	plain.configure(Kit.cut_paper_opts_from_config({}, "action_button", Kit.ACTION_BUTTON_CP_DEFAULTS), Color.WHITE)
	ok(is_equal_approx(plain.edge_feather, 0.0), "a shared cut-paper surface feathers nothing by default")
	var tab: Control = load(Kit.CUT_PAPER).new()
	root.add_child(tab)
	tab.configure(EdgeTab.tab_cp(200.0, 166.0, 220.0), Color.WHITE)
	ok(tab.edge_feather > 0.0, "the nav tab asks for the feather (%.2fpx)" % tab.edge_feather)
	ok(is_equal_approx(tab.deckle_amp, 0.0), "…precisely because its edge is smooth, with no tear to hide the stairs")

	# 4e) THE SHARED PAPER-BUTTON MATERIAL (engine/scripts/ui/paper_button.gd). The nav tabs, the board's
	# Home + Bag wells, its info tray, its almanac chip and the place-picker's back button are all the same
	# MATERIAL — smooth feathered edge, the scene's directional cast shadow, a lit hairline, a dense glyph
	# shadow and no rim — and they read it from ONE module rather than five copies of the same numbers.
	# The tab's GEOMETRY (flare · bottom bleed) is a SECOND shared module, engine/scripts/ui/edge_tab.gd:
	# every sheet ANCHORED to the screen's bottom edge wears it (both bottom rows), and nothing else does —
	# a free-standing button (the almanac chip, the place-picker's back arrow) has nothing to bleed off.
	var Paper := load("res://engine/scripts/ui/paper_button.gd")
	var FACE := 158.0                          # the size these buttons actually ship at
	var mat: Dictionary = Paper.surface_cp(FACE)
	ok(not mat.has("flare") and not mat.has("bleed_bottom") and not mat.has("caption"),
		"the shared material carries no tab geometry — no flare, no bleed, no caption")
	# ONE source: the nav row's own patch IS this material plus its flare, not a second copy of it.
	var tabp: Dictionary = EdgeTab.tab_cp(FACE, 131.0, 158.0)
	var same := true
	for k in mat:
		if k == "halo_offset":
			same = same and (tabp.get(k, Vector2.ZERO) as Vector2).is_equal_approx(mat[k])
		else:
			same = same and is_equal_approx(float(tabp.get(k, -1.0)), float(mat[k]))
	ok(same, "the nav tab's paper IS the shared material — every knob, one source")
	ok(float(tabp.get("flare", 0.0)) > 0.0 and mat.size() + 1 == tabp.size(),
		"…and the flare is the ONE thing the tab adds to it")

	# 4f) THE TAB GEOMETRY'S TWO SPELLINGS AGREE. `FLARE` is the mock's own figure — the nav tab's visible
	# bottom edge reads 5.5% wider than its top — and it is only meaningful at that tile's proportions,
	# because `cut_paper.flare` is a fraction of the sheet's WIDTH. `LEAN` is the same geometry as an
	# ANGLE, which is what any OTHER shape (a square well, a 4:1 tray) has to be given to sit in the same
	# row without reading as a different trapezoid. The nav row keeps the FLARE spelling so its shipped
	# render cannot move by a float; this is the guard that stops the two drifting. A re-tune of FLARE
	# that is not re-derived into LEAN fails HERE rather than shipping a mismatched bottom row.
	var NAV := load("res://engine/scripts/ui/nav_bar.gd")
	for tile_w in [162.0, 197.5, 247.3]:                 # a 5-tab row, a 4-tab row, and the shipped size
		var box_h: float = tile_w * NAV.TILE_H_FRAC
		var sheet_h: float = box_h + tile_w * NAV.CORNER_FRAC       # the bleed: one corner radius (safe area 0)
		var got: float = EdgeTab.lean_of(tile_w, sheet_h, EdgeTab.tab_flare(box_h, sheet_h))
		ok(absf(got - EdgeTab.LEAN) < 0.0004,
			"a %.0fpx nav tab leans %.4f — EdgeTab.LEAN says %.4f" % [tile_w, got, EdgeTab.LEAN])
	# …and the inverse really is an inverse: handing `flare_for_lean` a sheet and asking for the lean it
	# produced must give the flare back. Checked on the two shapes the board's row actually carries.
	for shape in [Vector2(162.0, 203.0), Vector2(662.0, 191.0)]:    # the square well, the wide info tray
		var f: float = EdgeTab.flare_for_lean(shape.x, shape.y)
		ok(is_equal_approx(EdgeTab.lean_of(shape.x, shape.y, f), EdgeTab.LEAN),
			"a %.0fx%.0f sheet flared %.4f leans exactly LEAN" % [shape.x, shape.y, f])
	# THE BLEED ON A REAL DEVICE. `Look.safe_bottom` is 0 on every desktop capture and in every headless
	# suite (it reads the display's safe area, which a Mac window does not have), so the one case that
	# only ever runs on a phone is asserted on the function instead: the paper runs through the home
	# indicator's inset AND a corner radius past it, so the sheet meets the physical screen edge while
	# the box — captions, counts, tap area — stays above the inset.
	ok(is_equal_approx(EdgeTab.bleed_px(0.0, 41.0), 41.0),
		"off-device the bleed is one corner radius (%.1f)" % EdgeTab.bleed_px(0.0, 41.0))
	ok(is_equal_approx(EdgeTab.bleed_px(34.0, 41.0), 75.0),
		"on a phone it is the safe-area inset AS WELL (%.1f)" % EdgeTab.bleed_px(34.0, 41.0))

	# THE UNTREATED CALLER IS UNTOUCHED. Any action button that does not ask for the material renders
	# exactly what it always did: a torn deckle, a warm rim, and none of the cast shadow / bevel / feather.
	# This is the scoping guard — the defaults on cut_paper.gd stay inert.
	var untouched: Dictionary = Kit.action_button_opts_from_config({})
	var plainb := Kit.action_button("map", Vector2(FACE, FACE), Callable(), untouched.duplicate(true))
	root.add_child(plainb)
	var pp := plainb.find_child("ActionButtonDeckleSurface", true, false) as Control
	ok(pp != null and pp.deckle_amp > 0.0 and pp.rim_width > 0.0,
		"an untreated action button keeps its torn edge and its warm rim")
	ok(pp != null and is_equal_approx(pp.halo_reach, 0.0) and is_equal_approx(pp.bevel_px, 0.0)
			and is_equal_approx(pp.edge_feather, 0.0),
		"…and carries none of the material: no cast shadow, no hairline, no feather")

	# THE TREATED CALLER — built through the same one call board.gd / map.gd make.
	var treated: Dictionary = Kit.action_button_opts_from_config({})
	Paper.apply(treated, Vector2(FACE, FACE))
	var wellb := Kit.action_button("bag", Vector2(FACE, FACE), Callable(), treated)
	root.add_child(wellb)
	var wp := wellb.find_child("ActionButtonDeckleSurface", true, false) as Control
	ok(wp != null and is_equal_approx(wp.deckle_amp, 0.0) and wp.edge_feather > 0.0,
		"a paper button's edge is SMOOTH and antialiased, not torn")
	ok(wp != null and is_equal_approx(wp.rim_width, 0.0), "…with no rim: its paper edge just ends")
	ok(wp != null and is_equal_approx(wp.flare, 0.0) and wp.shape == "rect",
		"…and it does NOT taper — a free-standing well is not an edge-anchored tab")
	# the cast shadow has a DIRECTION, because the scene's light is upper-left and every element in the
	# mock splits that way (nav tabs 0.168 lit / 0.388 shadow; wallet pills 0.129 / 0.366).
	var off: Vector2 = wp.halo_offset
	ok(wp != null and wp.halo_reach > 0.0 and off.x > 0.0 and off.y > 0.0 and off.length() < wp.halo_reach,
		"the well casts a DIRECTIONAL shadow, thrown down-right (%.2fpx inside a %.1fpx reach)"
			% [off.x, wp.halo_reach])
	ok(wp != null and wp.halo_falloff > 0.0, "…which decays, rather than ramping linearly to its fringe")
	# BOUNDED ON WHAT IS SEEN, in LITERAL px — never on the constant under test, which would pass any
	# re-tuning of itself. On a 158px face this renders 9.8px of visible shadow on the lit side and 14.2
	# on the other; a symmetric halo, or one reaching half the tile, fails these.
	var lit := _halo_visible_px(wp.halo_reach, wp.halo_falloff, wp.halo_alpha, off.x, -1.0)
	var dark := _halo_visible_px(wp.halo_reach, wp.halo_falloff, wp.halo_alpha, off.x, 1.0)
	ok(dark >= lit * 1.3, "…and throws further on the shadow side than the lit one (%.1fpx vs %.1f)"
		% [dark, lit])
	ok(lit >= 3.0 and lit <= 12.0 and dark >= 8.0 and dark <= 18.0,
		"…both sides dying like a contact shadow on a 158px face (lit %.1fpx, shadow %.1fpx)" % [lit, dark])
	# the paper's own thickness is a LIT HAIRLINE. A band reaching several px in stops reading as a cut
	# edge and reads as an inflated, domed face — so this is bounded in px, not as a fraction of itself.
	ok(wp != null and wp.bevel_px >= 0.5 and wp.bevel_px <= 2.5 and wp.bevel_strength > 0.0,
		"the paper edge is a LIT HAIRLINE, not a slab (%.2fpx)" % wp.bevel_px)

	# THE GLYPH'S POOL. The kit default is three copies dropped straight DOWN — no lateral shadow at all,
	# and the icons read as stickers laid flat on the paper. The material's stack GROWS each copy, so it
	# pools all round the glyph, and it is resampled finely enough not to band (cut_paper.gd's own rule:
	# a sparse 3/7/11px stack shows as discrete steps on something button-sized).
	var icon_px := FACE * 0.8
	var stack: Array = Paper.glyph_shadow(icon_px)
	ok((Kit.GLYPH_SHADOW as Array).all(func(l: Dictionary) -> bool: return float(l.get("grow", 0.0)) == 0.0),
		"the kit's default glyph shadow still smears straight down — untouched")
	ok(stack.all(func(l: Dictionary) -> bool: return float(l.get("grow", 0.0)) > 0.0),
		"the material's glyph shadow pools AROUND the glyph (every copy grows)")
	# density, in LITERAL px: consecutive copies must sit about a pixel apart. Spelled as STEP_PX * 1.3
	# this assertion passed a deliberately re-sparsed stack — see rule 12 of the method doc.
	var worst_step := 0.0
	for i in range(1, stack.size()):
		var a := float((stack[i - 1] as Dictionary)["grow"]) * icon_px * 0.5
		var c := float((stack[i] as Dictionary)["grow"]) * icon_px * 0.5
		worst_step = maxf(worst_step, absf(a - c))
	ok(stack.size() >= 8 and worst_step <= 1.4,
		"…densely: %d copies, never more than %.2fpx apart" % [stack.size(), worst_step])
	# the ACCUMULATION — not any single copy — is what follows the measured envelope, so it is the
	# accumulation that is bounded: the mock's icon pool darkens its own paper by about half at the
	# contact. Literal bounds again, not GLYPH_SHADOW_CONTACT restated.
	var acc := 0.0
	for l in stack:
		acc = acc + (1.0 - acc) * float((l as Dictionary)["a"])
	ok(acc >= 0.35 and acc <= 0.65, "…accumulating to the mock's contact darkening (%.3f)" % acc)

	# SCALE. Every metric is a fraction of the face width, so the same material holds on a 130px chip and
	# a 200px tab — that is what lets four differently sized buttons share one tuning.
	var big: Dictionary = Paper.surface_cp(FACE * 2.0)
	ok(is_equal_approx(float(big["halo_reach"]), float(mat["halo_reach"]) * 2.0)
			and is_equal_approx(float(big["bevel_px"]), float(mat["bevel_px"]) * 2.0),
		"the material scales with the face: twice the width, twice the reach and the hairline")

	# 5) the workbench registers the action_button component and drops the old home_button component
	# NOTE: DEFAULTS is not a const dict or a static func in ui_workbench_view.gd — the schema lives in
	# the instance method _default_params() (declared on the shared workbench_view.gd base, overridden
	# here). IDS IS a top-level const, so it's read directly off the loaded script. _default_params()
	# needs an instance, but .new() alone (no add_child) never enters the tree, so _ready() (which builds
	# the whole gallery UI) never runs — cheap and safe to call headlessly.
	var View := load("res://games/grove/tools/ui_workbench_view.gd")
	ok(View.IDS.has("action_button"), "the workbench registers the action_button component")
	ok(not View.IDS.has("home_button"), "the workbench no longer registers the home_button component")
	var view_defaults: Dictionary = View.new()._default_params()
	ok(view_defaults.has("action_button"), "action_button ships a saved config block")
	ok(not view_defaults.has("home_button"), "the home_button config block is gone")

	finish()
