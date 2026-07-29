extends "res://engine/tests/test_base.gd"
## Headless unit tests for the shared code-drawn action button (Kit.action_button) and its config
## reader. The button draws the rugged cut-paper edge in code (a CutPaperPanel surface) + a centered
## glyph — one source for the home bottom bar and the board Home/Bag wells.
##   godot --headless --path . -s res://engine/tests/action_button_tests.gd

const Kit = preload("res://games/grove/ui_kit.gd")

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
	var NavBar := load("res://engine/scripts/ui/nav_bar.gd")
	var plain: Control = load(Kit.CUT_PAPER).new()
	root.add_child(plain)
	plain.configure(Kit.cut_paper_opts_from_config({}, "action_button", Kit.ACTION_BUTTON_CP_DEFAULTS), Color.WHITE)
	ok(is_equal_approx(plain.edge_feather, 0.0), "a shared cut-paper surface feathers nothing by default")
	var tab: Control = load(Kit.CUT_PAPER).new()
	root.add_child(tab)
	tab.configure(NavBar.tab_cp(200.0, 166.0, 220.0), Color.WHITE)
	ok(tab.edge_feather > 0.0, "the nav tab asks for the feather (%.2fpx)" % tab.edge_feather)
	ok(is_equal_approx(tab.deckle_amp, 0.0), "…precisely because its edge is smooth, with no tear to hide the stairs")

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
