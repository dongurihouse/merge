extends "res://engine/tests/test_base.gd"
## Headless guards for the board's NEXT UNLOCK strip wearing the shared cut-paper material — the BAND
## (engine/scripts/ui/unlock_bar.gd on engine/scripts/ui/paper_button.gd) and its BAR
## (engine/scripts/ui/paper_progress.gd through Kit.progress_bar's `paper` opt).
##   godot --headless --path . -s res://engine/tests/unlock_bar_paper_tests.gd
##
## WHY A SUITE AT ALL when the look is verified on the mock rig: the rig needs the real renderer and a
## human to open the sheet, so it runs once per change at best. These are the facts that must not drift
## between those runs — and two of them are regressions this file was written after finding, on a render
## that every existing suite passed:
##
##   * the fill capsule cast NO shadow. `edge_shadow: false` was set on it to silence cut_paper's
##     straight-down drop, but that key maps to `draw_shadow`, which `_draw_edge_halo` ALSO returns
##     early on — so the directional halo the material exists to provide never drew. Probed on the rig
##     the head read 0.070 at 1px against the mock's 0.292, and the capsule looked printed into the well
##     rather than lying in it. Guard 7 is that one.
##   * the capsule's cap was an OCTAGON. cut_paper used to sample a corner arc at 0.45x the density it
##     samples a straight edge, which is invisible until a shape's corner radius is half its own height.
##     It now holds every arc to a fixed SAGITTA instead. Guard 8 bounds this capsule's cap; guard 13
##     bounds the rule across the whole radius range the game draws.
##
## EVERY BOUND HERE IS A LITERAL, deliberately (rule 12 of docs/design/verifying-against-a-mock.md): a
## bound spelled in terms of the constant under test passes whatever that constant becomes. What is
## bounded is what would be SEEN — a px width, a colour ratio, a shadow that exists.

const Kit = preload("res://games/grove/ui_kit.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const CutPaper = preload("res://engine/scripts/ui/cut_paper.gd")
const Paper = preload("res://engine/scripts/ui/paper_button.gd")
const PaperProgress = preload("res://engine/scripts/ui/paper_progress.gd")
const UnlockBar = preload("res://engine/scripts/ui/unlock_bar.gd")
const Pal = Game.PALETTE

## The mock's own bar box, so the numbers below are the ones the rig measured (board_next_unlock_v1).
const MOCK_BAR := Vector2(524, 48)

func save_prefix() -> String:
	return "tu_unlockpaper_"

func _initialize() -> void:
	print("== NEXT UNLOCK strip: the paper material ==")
	var root := get_root()
	var cfg := Game.kit_config()

	# --- the BAND ---------------------------------------------------------------------------
	var band := UnlockBar.new()
	band.size = Vector2(1028, 131)
	band.relayout()
	root.add_child(band)
	var surface := band.find_child(UnlockBar.DECKLE_SURFACE_NODE, true, false) as Control
	ok(surface != null, "the band wears a cut-paper surface")
	ok(surface != null and surface.get_script() == load(Kit.CUT_PAPER),
		"…and it is the shared cut_paper.gd panel, not a local one")

	var cp := UnlockBar.surface_cp(Kit, cfg, 131.0)
	# 1) SMOOTH, NOT TORN, and NOT RIMMED — the two things the old band wore that the mock draws neither of.
	ok(is_equal_approx(float(cp.get("deckle_amp", -1.0)), 0.0),
		"the band's edge is SMOOTH: the torn deckle amplitude is zeroed")
	ok(is_equal_approx(float(cp.get("rim_width", -1.0)), 0.0),
		"the band carries NO rim — a plain paper edge just ends")
	ok(float(cp.get("edge_feather", 0.0)) >= 1.5 and float(cp.get("edge_feather", 0.0)) <= 2.5,
		"…and the cut edge is antialiased by a ~2px feather instead")

	# 2) it carries the scene's DIRECTIONAL light — a halo that is heavier on one side than the other.
	ok(float(cp.get("halo_reach", 0.0)) > 0.0, "the band casts the material's ambient halo")
	var off: Vector2 = cp.get("halo_offset", Vector2.ZERO)
	ok(off.x > 0.0 and off.y > 0.0,
		"…offset DOWN and RIGHT, so the light reads as upper-left (a symmetric halo would not)")

	# 3) NO TAB GEOMETRY. The band floats under the HUD pills and touches no screen edge.
	ok(is_equal_approx(float(cp.get("flare", 0.0)), 0.0), "the band does not flare — it is not a screen-edge tab")
	ok(not bool(cp.get("bleed_bottom", false)), "…and does not bleed off any edge")

	# --- the SHARED component's other callers ---------------------------------------------------
	# 4) `paper` is the ONE key that switches Kit.progress_bar onto the well, and the shared config
	#    reader does not supply it. So the level-up dialog, the residents banks, the map's bar and the
	#    workbench preview all keep the surface they have always had.
	var shared: Dictionary = Kit.progress_bar_opts_from_config(cfg)
	ok(not shared.has("paper"),
		"progress_bar_opts_from_config carries NO `paper` — the well is an opt, not a new default")
	var plain: Control = Kit.progress_bar(0.5, shared)
	root.add_child(plain)
	var plain_track := plain.find_child("*Track", true, false) as Control
	ok(plain_track != null and plain_track.get_script() != load(Kit.CUT_PAPER),
		"a bar built WITHOUT `paper` draws no cut-paper track (the level dialog's bar is untouched)")

	# 5) …and the band's own opts DO carry it.
	var opts: Dictionary = UnlockBar.bar_opts(Kit, cfg, MOCK_BAR, false)
	ok(opts.has("paper") and not (opts["paper"] as Dictionary).is_empty(),
		"the band's bar asks for the cut-paper well")
	ok(String(opts.get("name", "")) == UnlockBar.BAR_NAME, "…on the shared Kit.progress_bar component")

	# --- the WELL and the CAPSULE -----------------------------------------------------------------
	var bar: Control = Kit.progress_bar(0.67, opts)
	bar.size = MOCK_BAR
	root.add_child(bar)
	Kit.progress_bar_set_frac(bar, 0.67)          # fires the layout callable
	var track := bar.find_child("*Track", true, false) as Control
	var fill := bar.find_child("*Fill", true, false) as Control
	var inset := bar.find_child("*InsetShadow", true, false) as Control
	ok(track != null and track.get_script() == load(Kit.CUT_PAPER), "the track is a cut-paper panel")
	ok(fill != null and fill.get_script() == load(Kit.CUT_PAPER), "the fill is a cut-paper panel")
	ok(inset != null, "the well carries the lip's inner shadow")

	# 6) A WELL IS SUNK: it casts nothing outward. (The rig confirms the same thing from outside — our
	#    sideways profile reads 0.000 at every step where the mock's reads its own lip.)
	ok(track != null and not track.draw_shadow, "the track throws no shadow — a recess casts nothing")
	ok(track != null and is_equal_approx(track.corner, 24.0),
		"…and it is a CAPSULE: the corner radius is half the 48px bar's height")

	# 7) THE CAPSULE LIES IN THE WELL — it casts the scene's own light onto the floor beside its head.
	#    This is the regression in the header: `draw_shadow` gates the halo too, so a bar that silences
	#    the drop shadow with `edge_shadow` silences the cast shadow as well and nothing says so.
	ok(fill != null and fill.draw_shadow,
		"the fill's shadow is ENABLED (edge_shadow:false would kill the halo, not just the drop)")
	ok(fill != null and fill.halo_reach > 0.0 and fill.halo_alpha > 0.0,
		"…the directional halo is what casts it")
	ok(fill != null and is_equal_approx(fill.shadow_reach, 0.0),
		"…and the straight-down drop shadow is silenced by its OWN reach, so only one shadow is cast")
	# what is SEEN: the head's shadow reaches roughly as far as the mock's (gone by ~8-10px), which is a
	# statement about the RENDER, not about FILL_MATERIAL_K.
	var reach_px: float = fill.halo_reach + absf(fill.halo_offset.x) if fill != null else 0.0
	ok(reach_px >= 7.0 and reach_px <= 14.0,
		"the head's cast shadow reaches %.1fpx — the mock's dies by ~8 (bound 7-14)" % reach_px)

	# 8) THE CAP IS ROUND. A capsule is the one shape whose corner radius is half its height, and a lazy
	#    arc sampling turns that into a visible polygon. Bound the SAGITTA — the deepest a chord falls
	#    short of the true arc — not the rule that produces it.
	ok(fill != null and _panel_sagitta_px(fill) < 0.15,
		"the capsule's cap falls %.3fpx short of a true circle (the legacy count left 0.749)"
			% _panel_sagitta_px(fill))
	ok(track != null and _panel_sagitta_px(track) < 0.15,
		"…and so do the well's own caps (%.3fpx)" % _panel_sagitta_px(track))

	# 9) THE CREASE IS A LINE, NOT A SLAB. Sectioned on the rig the mock's dark core is ~2 rows; the
	#    first spelling drew 4 flat rows of it and the well read as a grey outline round a cream capsule.
	var paper: Dictionary = opts["paper"]
	ok(float(paper.get("crease_w", 99.0)) <= 2.5,
		"the lip's crease is %.2fpx on a 48px bar — a cut edge, not a border" % float(paper.get("crease_w", 99.0)))
	ok(float(paper.get("inset_reach", 0.0)) >= 4.0,
		"…and the recess's ramp is the lip's INNER SHADOW, reaching %.1fpx down into the well"
			% float(paper.get("inset_reach", 0.0)))

	# 10) THE FLOOR IS A RATIO OF THE SHEET IT IS CUT INTO, not an absolute colour — which is what makes
	#     it survive the paper tile's own multiply (the tile cancels: rendered floor over rendered band is
	#     well over sheet whatever the fibre costs). Bound the measured recess depth, in literals.
	var well: Color = PaperProgress.well_fill(Pal.CREAM)
	var rr := well.r / Pal.CREAM.r
	var gg := well.g / Pal.CREAM.g
	var bb := well.b / Pal.CREAM.b
	ok(rr < 1.0 and gg < 1.0 and bb < 1.0, "the well's floor is darker than the sheet on every channel")
	ok(bb < gg and gg < rr, "…and it goes WARMER as it sinks (blue falls furthest), not merely grey")
	ok(rr > 0.975 and rr < 0.995 and gg > 0.945 and gg < 0.965 and bb > 0.912 and bb < 0.932,
		"the recess is %.3f/%.3f/%.3f of the sheet — the mock's own 0.984/0.953/0.922" % [rr, gg, bb])
	# the same rule at a DIFFERENT sheet colour, which is the whole point of writing it as a ratio
	var on_straw: Color = PaperProgress.well_fill(Pal.STRAW)
	ok(on_straw.r < Pal.STRAW.r and is_equal_approx(on_straw.r / Pal.STRAW.r, rr),
		"a well cut into some other stock sinks by the same ratio, not to the same cream")

	# 11) THE FILL'S GEOMETRY inside the well, and its FLOOR at 0% — a capsule shorter than its own
	#     height is not a capsule, so an empty bar shows a round nub rather than a lens.
	ok(fill != null and fill.size.y > MOCK_BAR.y * 0.86 and fill.size.y < MOCK_BAR.y * 0.94,
		"the capsule nearly fills the well (%.1f of 48px), so it reads as seated" % fill.size.y)
	Kit.progress_bar_set_frac(bar, 0.0)
	ok(fill != null and is_equal_approx(fill.size.x, fill.size.y),
		"at 0% the fill is exactly one capsule-length — a round nub, never a zero-width sliver")
	Kit.progress_bar_set_frac(bar, 1.0)
	ok(fill != null and fill.size.x > MOCK_BAR.x * 0.94,
		"at 100%% it runs the length of the well (%.0f of 524px)" % fill.size.x)

	# 12) THE READY CUE still re-hues cleanly: the rim and the crease are derived from the two faces, so a
	#     gold capsule gets a gold edge and not a green line round it.
	var gold: Dictionary = UnlockBar.bar_opts(Kit, cfg, MOCK_BAR, true)
	var gpaper: Dictionary = gold["paper"]
	var grim: Color = gpaper["fill_rim"]
	ok((gold["fill_color"] as Color).is_equal_approx(Pal.STRAW), "the affordable cue turns the fill gold")
	ok(grim.r > grim.b, "…and its cut edge is a darker GOLD, derived from the face it edges")

	# 13) THE RULE IS GAME-WIDE, not this capsule's favour. Every corner radius cut_paper draws — from a
	#     2px chip to a 120px sheet — must stay under the same 0.15px facet, because the sampling is
	#     bounded by the SAGITTA and not by a chord length (one chord is a different visible error at
	#     every radius). Swept rather than spot-checked: a chord rule passes at one radius and fails at
	#     the next.
	var probe := CutPaper.new()
	var worst_r := 0.0
	var worst := 0.0
	for i in range(2, 121):
		var r := float(i)
		var s := _sagitta_of(r, float(probe._arc_steps(r)))
		if s > worst:
			worst = s
			worst_r = r
	ok(worst < 0.15,
		"the deepest facet over r=2..120px is %.3fpx at r=%.0f — under the 0.15px bound at every radius"
			% [worst, worst_r])
	# …and the guard is proved by a known-positive: the formula this replaced BREAKS that bound, so a
	# revert cannot pass this file quietly.
	var legacy_22 := _sagitta_of(22.0, _legacy_steps(22.0))
	ok(legacy_22 > 0.15,
		"the legacy count leaves %.3fpx at r=22 (the dialog frame's own radius) — over the bound" % legacy_22)
	probe.free()

	finish()


## How far a quarter-arc of radius `r` sampled in `steps` segments falls short of the true circle — the
## depth of the facet the eye sees, in px.
func _sagitta_of(r: float, steps: float) -> float:
	if r <= 0.0 or steps <= 0.0:
		return 0.0
	return r * (1.0 - cos(PI * 0.5 / steps * 0.5))

## The same thing for the arc a live panel really draws: the radius is the one `_rect_base` uses (it
## clamps `corner` to half the shorter side), and the segment count is asked of CUT_PAPER ITSELF rather
## than re-derived here, so a broken sampling rule cannot hide behind a healthy copy of it in the test.
func _panel_sagitta_px(p: Control) -> float:
	if p == null:
		return 0.0
	var r := clampf(p.corner, 0.0, minf(p.size.x, p.size.y) * 0.5)
	return _sagitta_of(r, float(p.call("_arc_steps", r)))

## cut_paper's LEGACY count for a quarter-arc — the formula this rule replaced, kept only so the sweep
## above has a known-positive to fail on. Not reachable from any shipped path.
func _legacy_steps(r: float) -> float:
	return maxf(3.0, floor(r * 0.7 / CutPaper.STEP))
