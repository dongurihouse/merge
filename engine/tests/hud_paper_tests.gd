extends "res://engine/tests/test_base.gd"
## Headless guard for the TOP CHROME's paper furniture — the wallet pills, the level badge and the
## settings tile wearing the same chalked cut-paper language as the shipped bottom nav row.
##   godot --headless --path . -s res://engine/tests/hud_paper_tests.gd
##
## The concept this was built to is games/grove/assets/_concepts/screens/
## home_screen_furniture_a_v1_1080x1920.png (variant A, approved), and the method for measuring against
## a concept is docs/design/verifying-against-a-mock.md. What a suite can hold is the part that is not
## a measurement: that the pill really wears the row's own knobs, that the numbers it derives land in
## the mock's own bands, and that the layout the owner asked for is the layout that is built.
##
## EVERY BOUND HERE IS A LITERAL. A bound spelled in terms of the constant under test passes a
## deliberately broken constant (the doc's rule 12), and the round-trip checks below are exactly the
## shape that fails that way — so each one carries a plain-number sanity range beside it.

const NavBar = preload("res://engine/scripts/ui/nav_bar.gd")       # the nav ROW (slots · gaps · chalk)
const Paper = preload("res://engine/scripts/ui/paper_button.gd")   # …the shared MATERIAL, incl. the furniture form
const EdgeTab = preload("res://engine/scripts/ui/edge_tab.gd")     # …and the screen-edge tab geometry
const Hud = preload("res://engine/scripts/ui/hud.gd")
const Design = preload("res://engine/scripts/core/design.gd")
const Kit = preload("res://games/grove/ui_kit.gd")
const Game = preload("res://engine/scripts/core/game.gd")

## The shipped home row: five tabs across the design canvas at the HUD's own edge margin. Re-derived
## here rather than imported so the numbers below are a check on the row, not an echo of it.
const EDGE_MARGIN := 18.0
const TABS := 5


func _initialize() -> void:
	print("== HUD paper furniture guard ==")
	_check_furniture_matches_the_row()
	_check_furniture_knob_list_is_in_step()
	_check_pill_wears_the_furniture_edge()
	_check_pill_icons_rest_on_the_paper()
	_check_glyph_stack_stays_dense_on_small_furniture()
	_check_pill_faces_sit_in_the_tab_family_band()
	_check_pill_numerals_are_white_on_a_shadow()
	await _check_badge_is_bigger_and_clear_of_the_wallet()
	finish()


# --- the language is ONE language ------------------------------------------------------------

## `furniture_cp(h)` re-expresses the shared material against an element's HEIGHT. At the plain nav
## tile's own height it must hand back the tab's own pixels — otherwise the wallet pill and the tabs
## are two tunings wearing one name.
func _check_furniture_matches_the_row() -> void:
	# THE ONE COUPLING THAT IS NOT AN EXPRESSION. paper_button.gd cannot import nav_bar.gd — the row is
	# built OUT of the material, so the dependency only runs one way — and the height conversion needs
	# the reference tile's own aspect and corner. They are restated there and pinned HERE: a re-tune of
	# the row's tile stops the sweep and makes a human decide whether the furniture follows, instead of
	# the two drifting apart in silence.
	ok(is_equal_approx(Paper.FURNITURE_ASPECT, NavBar.TILE_H_FRAC),
		"the material's reference aspect IS the nav tile's (%.4f)" % Paper.FURNITURE_ASPECT)
	ok(is_equal_approx(Paper.FURNITURE_CORNER_FRAC, NavBar.CORNER_FRAC),
		"…and its reference corner IS the nav tile's (%.4f)" % Paper.FURNITURE_CORNER_FRAC)

	var view_w: float = Design.size().x
	var w := NavBar.tile_px(view_w - EDGE_MARGIN * 2.0, TABS, NavBar.gap_px(view_w))
	var h := NavBar.tile_size(w).y
	var f := Paper.furniture_cp(h)
	var tab := EdgeTab.tab_cp(w, h, h, false)
	ok(is_equal_approx(float(f["corner"]), w * NavBar.CORNER_FRAC),
		"furniture corner at the tile's height IS the tab's corner (%.2f)" % float(f["corner"]))
	# …and the ONE place it deliberately does not: the owner asked for more shadow after the first
	# render, so the furniture's halo runs deeper and further than the row's. Both gains are checked as
	# a RATIO against the row (which is not the constant under test) and again as plain px below, so
	# reverting either constant to 1.0 fails here rather than passing on its own arithmetic.
	var reach_gain: float = float(f["halo_reach"]) / maxf(1.0, float(tab["halo_reach"]))
	ok(reach_gain > 1.15 and reach_gain < 1.60,
		"furniture halo reaches 15-60%% FURTHER than the tab's (%.2fx)" % reach_gain)
	var alpha_gain: float = float(f["halo_strength"]) / maxf(1.0, float(tab["halo_strength"]))
	ok(alpha_gain > 1.15 and alpha_gain < 1.60,
		"…and lands 15-60%% darker at the contact (%.2fx)" % alpha_gain)
	ok((f["halo_offset"] as Vector2).is_equal_approx(tab["halo_offset"] as Vector2),
		"…but the LIGHT does not move: the offset IS the tab's %s" % str(f["halo_offset"]))
	ok(is_equal_approx(float(f["bevel_px"]), float(tab["bevel_px"])),
		"furniture bevel depth IS the tab's (%.2f)" % float(f["bevel_px"]))
	ok(is_equal_approx(float(f["edge_feather"]), float(tab["edge_feather"])),
		"furniture edge feather IS the tab's (%.2f)" % float(f["edge_feather"]))
	ok(is_equal_approx(float(f["deckle_amp"]), 0.0), "furniture paper is a SMOOTH cut, not a torn deckle")
	ok(is_equal_approx(float(f["rim_width"]), 0.0), "furniture paper wears no warm cut-edge rim")

	# …and the same numbers, as plain px on the shipped canvas. Every check above would also pass with
	# the whole table zeroed; these say the table is a real paper edge (rule 12).
	ok(w > 180.0 and w < 220.0, "the shipped five-tab slot is ~198px wide (%.1f)" % w)
	ok(float(f["corner"]) > 28.0 and float(f["corner"]) < 42.0,
		"…so a tile's corner is a large smooth radius, 28-42px (%.1f)" % float(f["corner"]))
	ok(float(f["halo_reach"]) > 22.0 and float(f["halo_reach"]) < 32.0,
		"…its cast shadow reaches 22-32px — the row's ~21 deepened (%.1f)" % float(f["halo_reach"]))
	var off := (f["halo_offset"] as Vector2)
	ok(off.x > 1.5 and off.x < 4.5 and is_equal_approx(off.x, off.y),
		"…the light slides it 1.5-4.5px DOWN AND RIGHT — one upper-left source (%.2f,%.2f)" % [off.x, off.y])
	ok(float(f["bevel_px"]) > 0.8 and float(f["bevel_px"]) < 2.6,
		"…and the lit cut edge is a HAIRLINE, 1-2.5px, not a slab (%.2f)" % float(f["bevel_px"]))
	ok(float(f["halo_strength"]) > 48.0 and float(f["halo_strength"]) < 62.0,
		"…at a contact alpha of 48-62%% — the row's 40 deepened (%.0f)" % float(f["halo_strength"]))


## `FURNITURE_KNOBS` is what the mock rig's scale pass reads to know which knobs already followed the
## element's size. A knob added to `furniture_cp` and forgotten here is silently scaled TWICE.
func _check_furniture_knob_list_is_in_step() -> void:
	var built: Array = Paper.furniture_cp(100.0).keys()
	built.sort()
	var declared: Array = Paper.FURNITURE_KNOBS.duplicate()
	declared.sort()
	ok(built.size() >= 8, "furniture_cp sets a real knob set (%d knobs)" % built.size())
	ok(built == declared, "FURNITURE_KNOBS names exactly what furniture_cp sets\n    sets:     %s\n    declares: %s"
		% [", ".join(PackedStringArray(built)), ", ".join(PackedStringArray(declared))])


# --- the wallet pill -------------------------------------------------------------------------

func _pill(icon: String) -> Control:
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var o: Dictionary = Kit.gold_currency_pill_opts_from_config(cfg)
	o["icon"] = icon
	return Kit.gold_currency_pill(o, {icon: 100})


func _pill_face(pill: Control) -> Control:
	return pill.find_child("ButtonDeckleSurface", true, false) as Control


func _check_pill_wears_the_furniture_edge() -> void:
	var pill := _pill("water")
	var face := _pill_face(pill)
	ok(face != null, "the wallet pill's face is the shared cut-paper panel")
	if face == null:
		pill.free()
		return
	ok(is_equal_approx(face.deckle_amp, 0.0), "the pill's edge is a SMOOTH cut (deckle amp 0)")
	ok(is_equal_approx(face.rim_width, 0.0), "the pill wears no warm cut-edge rim")
	ok(face.edge_feather > 1.0, "the smooth arc is antialiased (feather %.1fpx)" % face.edge_feather)
	# THE THING THAT WAS MISSING. The old cream capsule cast NOTHING sideways — 0.000 left and right on
	# the rig — which is what made it sit on top of the art instead of in it.
	ok(face.halo_reach > 6.0, "the pill casts an AMBIENT halo on every side (%.1fpx)" % face.halo_reach)
	ok(face.halo_offset.x > 0.5 and is_equal_approx(face.halo_offset.x, face.halo_offset.y),
		"…slid down AND right, so the shadow side is the lower right (%.2f,%.2f)"
		% [face.halo_offset.x, face.halo_offset.y])
	ok(face.halo_falloff > 1.0, "…dying exponentially, not as a linear smudge (%.1f e-folds)" % face.halo_falloff)
	ok(face.bevel_px > 0.4 and face.bevel_px < 2.6,
		"the lit edge is a hairline, not an inner bevel (%.2fpx)" % face.bevel_px)
	var corner_frac: float = float(face.corner) / maxf(1.0, pill.custom_minimum_size.y)
	ok(corner_frac > 0.15 and corner_frac < 0.28,
		"the corner is a large smooth radius, not a capsule (%.3f of the height)" % corner_frac)
	# ONE sheet: the gold under-sheet is gone (it also made our silhouette differ from the concept's,
	# which profiles as a shadow that BRIGHTENS — verifying-against-a-mock.md rule 6).
	ok(pill.find_child("PaperBacker", true, false) == null,
		"the pill is ONE sheet — no stacked-paper backer")
	pill.free()


## THE CURRENCY ICON RESTS ON THE SHEET. It used to be a bare `make_icon` — one TextureRect, no shadow
## layer at all — while every nav-tab glyph rode the row's generated dense stack, which is precisely why
## the tab icons read as objects on their tile and the pill's currency read as ink printed on its paper.
##
## Bounds are literals and are on what is SEEN — how far the outermost copy stands out from the glyph's
## own silhouette, and how dark the accumulation is where it meets that silhouette — never on the
## constants that produce them (the doc's rule 12: a bound spelled `STEP_PX * 1.3` passed a deliberately
## re-sparsed stack).
func _check_pill_icons_rest_on_the_paper() -> void:
	for icon_id in ["water", "coin", "gem"]:
		var pill := _pill(icon_id)
		var icon := pill.find_child("GoldCurrencyIcon", true, false) as Control
		ok(icon != null, "the %s pill still exposes its icon under the contract name" % icon_id)
		if icon == null:
			pill.free()
			continue
		var copies: Array = icon.get_children()
		ok(copies.size() >= 5,
			"…built as a shadow STACK under one clean copy (%d layers)" % maxi(0, copies.size() - 1))
		if copies.size() < 3:
			pill.free()
			continue
		var glyph := copies[copies.size() - 1] as TextureRect
		ok(glyph != null and glyph.modulate.is_equal_approx(Color.WHITE),
			"…the TOP copy is the untinted artwork, not a shadow")
		var icon_px: float = icon.custom_minimum_size.x
		ok(icon_px > 40.0 and icon_px < 120.0,
			"…in the pill's own small icon box, 40-120px (%.0f)" % icon_px)
		# the outermost copy's reach out of the glyph's silhouette, in PLAIN PIXELS — the pool has to be
		# visible at the pill icon's size, which is a bit over half a nav glyph's.
		var outer := copies[0] as TextureRect
		var reach_px: float = -outer.offset_left
		ok(reach_px > 2.5 and reach_px < 9.0,
			"…whose outermost copy stands 2.5-9px proud of the artwork (%.1f)" % reach_px)
		# …and it is a POOL, not a smear: the copies grow SIDEWAYS as well as dropping. A stack with no
		# lateral term is the shared GLYPH_SHADOW, which measured 0.13 at 1px and nothing past 3px.
		ok(outer.offset_top < 0.0,
			"…and it is a pool AROUND the icon, not a smear under it (top %.1fpx)" % outer.offset_top)
		# DENSE, ~1px steps. cut_paper.gd's own rule: a sparse 3/7/11px stack bands visibly on a small
		# element, and this element is the smallest one wearing the stack.
		var second := copies[1] as TextureRect
		var step_px: float = absf(outer.offset_left - second.offset_left)
		ok(step_px > 0.4 and step_px < 1.6,
			"…stepped ~1px so it cannot band on a piece this small (%.2fpx)" % step_px)
		# the accumulated darkening where the pool meets the glyph — solved, so no single copy carries it.
		var keep := 1.0
		for c in copies.slice(0, copies.size() - 1):
			keep *= 1.0 - (c as TextureRect).modulate.a
		var contact := 1.0 - keep
		ok(contact > 0.35 and contact < 0.70,
			"…accumulating to a 35-70%% contact pool (%.0f%%)" % (contact * 100.0))
		pill.free()


## THE STACK IS GENERATED, so it has to hold up at sizes the row was never fitted at. The nav glyph is
## ~122px on the shipped canvas; the settings gear's is ~56 and a wallet pill's currency is ~74. What
## must survive the shrink is the DENSITY — cut_paper.gd's own rule is that a sparse few-copy stack
## bands visibly on a small element, and these are the smallest elements wearing it.
func _check_glyph_stack_stays_dense_on_small_furniture() -> void:
	for px in [56.0, 74.0, 122.0]:
		var stack: Array = Paper.glyph_shadow(px)
		ok(stack.size() >= 4, "a %.0fpx glyph still gets a real stack (%d copies)" % [px, stack.size()])
		if stack.size() < 2:
			continue
		# the OUTERMOST copy's reach out of the silhouette, and the step between neighbours, in px.
		var reach_px: float = float(stack[0]["grow"]) * px * 0.5
		var step_px: float = reach_px - float(stack[1]["grow"]) * px * 0.5
		ok(step_px > 0.4 and step_px < 1.6,
			"…resampled at ~1px whatever the size (%.2fpx at %.0f)" % [step_px, px])
		ok(reach_px > 2.5, "…and the pool still stands clear of the artwork (%.1fpx)" % reach_px)
		# the accumulation at the contact is a property of the ENVELOPE, so it must not drift with size.
		var keep := 1.0
		for layer in stack:
			keep *= 1.0 - float(layer["a"])
		ok(1.0 - keep > 0.35 and 1.0 - keep < 0.70,
			"…to the same 35-70%% contact pool at every size (%.0f%%)" % ((1.0 - keep) * 100.0))


## Each pill's face is its currency's chalked paper role, and the whole set sits in the band the nav
## tabs were measured into off the concept: saturation ~25-35%, value 70-92.
func _check_pill_faces_sit_in_the_tab_family_band() -> void:
	for pair in [["water", "sky"], ["coin", "gold"], ["gem", "coral"]]:
		var icon: String = pair[0]
		var role: String = pair[1]
		var pill := _pill(icon)
		var face := _pill_face(pill)
		var want: Color = NavBar.chalk(Kit.PAPER_SURFACES[role]["fill"])
		var got: Color = face.paper_color if face != null else Color.BLACK
		ok(face != null and got.is_equal_approx(want),
			"the %s pill's face is the chalked %s paper role (%s)" % [icon, role, got.to_html(false)])
		ok(got.s >= 0.20 and got.s <= 0.40,
			"…saturation %.1f%% is inside the tab family's 20-40 band" % (got.s * 100.0))
		ok(got.v >= 0.70 and got.v <= 0.93,
			"…value %.1f is inside the 70-93 band" % (got.v * 100.0))
		pill.free()
	# the three faces must still be TELLING APART — chalking to one band is not chalking to one colour.
	var w := _pill("water")
	var g := _pill("gem")
	var wf := _pill_face(w)
	var gf := _pill_face(g)
	var dh: float = absf((wf.paper_color.h if wf != null else 0.0) - (gf.paper_color.h if gf != null else 0.0))
	ok(dh > 0.15, "water and acorn keep clearly different hues (%.2f apart on the wheel)" % dh)
	w.free()
	g.free()


func _check_pill_numerals_are_white_on_a_shadow() -> void:
	var pill := _pill("coin")
	var amount := pill.find_child("GoldCurrencyAmount", true, false) as Label
	ok(amount != null, "the pill carries its amount label")
	if amount == null:
		pill.free()
		return
	var col: Color = amount.get_theme_color("font_color")
	ok(col.v > 0.95 and col.s < 0.05, "the numeral is WHITE (%s)" % col.to_html(false))
	ok(amount.get_theme_constant("shadow_offset_y") >= 1,
		"…dropped onto a soft dark shadow (%dpx)" % amount.get_theme_constant("shadow_offset_y"))
	ok(amount.get_theme_color("font_shadow_color").a > 0.15,
		"…at a readable alpha (%.2f)" % amount.get_theme_color("font_shadow_color").a)
	ok(amount.get_theme_font("font") != null, "…on the bold face the tab captions use")
	pill.free()


# --- the level badge -------------------------------------------------------------------------

## Kept as the layered star rosette (NOT flattened into a paper chip like the concept's) and stepped up
## a size. Both ends are bounded: big enough to read as status against the new pastel pills, small
## enough not to become a fourth pill, and clear of the wallet cluster at the shipped canvas.
func _check_badge_is_bigger_and_clear_of_the_wallet() -> void:
	var host := Control.new()
	host.custom_minimum_size = Design.size()
	host.size = Design.size()
	get_root().add_child(host)
	var hud: Dictionary = Hud.build(host, {})
	await process_frame
	await process_frame
	var lv_panel := hud.get("lv_panel") as Control
	var badge := lv_panel.find_child("LevelBadge", true, false) as Control if lv_panel != null else null
	var water := hud.get("water_pill") as Control
	var cluster := hud.get("wallet") as Control
	ok(badge != null and water != null and cluster != null, "the HUD builds a badge and a wallet cluster")
	if badge == null or water == null or cluster == null:
		host.queue_free()
		await process_frame
		return
	# the badge is the layered rosette, not a paper tile: it has no cut-paper face at all.
	ok(badge.find_child("ButtonDeckleSurface", true, false) == null
		and badge.find_child("ActionButtonDeckleSurface", true, false) == null,
		"the level badge is the painted rosette, not a cut-paper chip")
	ok(badge.find_child("lv_badge_art", true, false) != null, "…and still wears its layered star art")
	var badge_h := badge.get_global_rect().size.y
	var pill_h := water.get_global_rect().size.y
	ok(pill_h > 40.0, "the wallet pill has a real height (%.1f)" % pill_h)
	ok(badge_h > pill_h * 1.25, "the badge is a step BIGGER than a wallet pill (%.1f vs %.1f)" % [badge_h, pill_h])
	ok(badge_h < pill_h * 1.60, "…and still not a fourth pill (%.2fx)" % (badge_h / pill_h))
	# 116px at the shipped 86px pill: a literal, so zeroing the scale cannot pass this.
	ok(badge_h > 100.0 and badge_h < 140.0, "…which is 100-140px on the design canvas (%.1f)" % badge_h)
	var badge_right := badge.get_global_rect().end.x
	var cluster_left := cluster.get_global_rect().position.x
	ok(badge_right < cluster_left,
		"the badge clears the wallet cluster's left edge (%.1f < %.1f)" % [badge_right, cluster_left])
	ok(cluster_left - badge_right > 40.0,
		"…with real air between them, not a hairline (%.1fpx)" % (cluster_left - badge_right))
	host.queue_free()
	await process_frame
