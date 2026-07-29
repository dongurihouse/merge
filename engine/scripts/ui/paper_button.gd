extends RefCounted
## THE PAPER-BUTTON SURFACE TREATMENT — the MATERIAL a cut-paper button is made of, owned in one place.
##
## This is not a component and not a layout: it is the set of cut-paper knobs that make a Kit.action_button
## read as a clean sheet of card lying on the art — a SMOOTH antialiased edge, a DIRECTIONAL cast shadow
## thrown by the scene's upper-left light, a LIT hairline paper edge, a DENSE glyph shadow, and no rim on a
## plain tile. Every number here was measured off the concept mock
## (games/grove/assets/_concepts/screens/palette_a_meadow_sky_board.png) on the like-for-like rig
## (`make shot-mock`; the method is docs/design/verifying-against-a-mock.md), and each is written as a
## fraction of the button's own face WIDTH so one tuning holds at any button size.
##
## WHO WEARS IT: the bottom nav tabs (engine/scripts/ui/nav_bar.gd), the board's Home + Bag wells and its
## almanac chip (engine/scripts/scenes/board.gd), and the place-picker's back button
## (engine/scripts/scenes/map.gd). It started life as the nav row's own constant block; the moment a second
## surface needed the same material, "the nav row's numbers" stopped being an honest name for it. Callers
## read from HERE — there is no second copy to drift.
##
## WHAT IS *NOT* HERE, deliberately: the nav tab's FLARE, its bottom BLEED and its CAPTION. Those are not
## material, they are the geometry of a tab anchored to the screen edge — a free-standing square well must
## not taper, and has nothing to run off. They stay in nav_bar.gd.
##
## The DEFAULTS on cut_paper.gd are all inert (0 reach / 0 bevel / 0 feather / full deckle), so a surface
## that does not ask for this treatment renders exactly as it always did.

const CutPaper = preload("res://engine/scripts/ui/cut_paper.gd")   # for the shared shadow falloff curve

# SMOOTH EDGE: a paper button wears the mock's clean rounded corners, not the torn cut-paper deckle every
# other paper surface in the game wears. It is the same CutPaperPanel with its tear amplitude zeroed —
# fill, rim, halo and bevel are untouched.
const DECKLE_AMP := 0.0
# …and the price of losing the tear: `draw_colored_polygon` antialiases nothing, so with the deckle gone
# the corner arc rasterizes as a hard binary STAIRCASE. Measured across a nav tile's top-left arc — the
# pixels whose value lands between the ground and the fill — ours ran 0.00 per row (a pure binary step)
# against the mock's 1.68 on its own 931px canvas, i.e. ~1.95 at our 1080. A card's defining quality is a
# clean cut edge, so the treatment asks for the shared feather at that width. The ramp is CENTRED on the
# outline, so the silhouette neither moves nor grows — half the band of coverage lands either side of it,
# which is what the rasterizer would have written. Rendered back: 1.22 per row at 2.0px. Wider still
# (2.5 measured 1.39) stops reading as a cut and starts reading as a soft glow.
const EDGE_FEATHER_PX := 2.0

# THE CAST SHADOW — the thing that makes the sheet sit ON the art rather than be printed into it.
#
# THE MOCK'S SHADOW IS DIRECTIONAL, and every tuning of the nav row before this one missed that, because
# every one of them measured OUR row on a leafy home screen (or a blue-grey gallery), in our chalked
# fills, at 1080px, against THE MOCK's row on its flat sky, in its own fills, at 931px. A shadow's alpha
# is INFERRED from a luma ratio, so it is a function of the ground it lands on; none of those numbers
# were comparable, and each round drew a conclusion from them anyway. `make shot-mock` exists to end
# that: it puts ONE of our elements and ONE of the mock's on the same flat field of the mock's own
# ground, at the mock's own pixel size, with `fill=` forcing our paper to the mock's own colour — so the
# only thing left varying between the two cells is the shadow. The method is
# docs/design/verifying-against-a-mock.md.
# Measured there (`games/grove/tools/mock_profile.py`, darkening = 1 - sampled/field, stepping out from
# each element's own per-row edge), the mock's LEFTMOST nav tab and its RIGHTMOST do not carry the same
# shadow at all:
#     left   0.168 at 1px · 0.077 at 3 · 0.052 at 4 · 0.020 at 6 · 0.006 at 8 · gone by 9
#     right  0.388 at 1px · 0.278 at 3 · 0.237 at 4 · 0.164 at 6 · 0.112 at 8 · 0.010 at 16
# The info card above the row splits the same way (0.23 left, 0.36 right), and so do the wallet pills
# (top 0.097 · left 0.129 · right 0.366 · bottom 0.396). It is the SCENE's light — upper left — and not
# one tile's quirk, which is exactly why the numbers belong to the material and not to the nav row. A
# SYMMETRIC halo cannot be both: at the reach that fits the right, the left is four times too heavy; at
# the reach that fits the left, the right disappears. The 0.11 W linear ramp scored rms 0.144 against
# those two curves and a 0.083 W / 2.2-e-fold one scored 0.084 — better on the left, WORSE on the right,
# and neither within reach of the mock.
# So the halo carries a direction (CutPaper.halo_offset, inert at its default everywhere else) and the
# three numbers below were fitted on the rig against BOTH curves at once. Rendered, this tuning scores
# rms 0.018 — the mock's own paper grain is 0.016 — with one residual worth naming: the lit contact
# reads 0.108 where the mock reads 0.168, because the ring stack is ~1px granular and the mock's value
# falls between two rings. That is one pixel column 6% light, and it is not visible at 1x.
const HALO_REACH_FRAC := 0.105        # the DILATION reach; the light then splits it into ~9px on the lit
                                      # side and ~19px on the shadow side (at a 158px face)
const HALO_FALLOFF := 3.6             # …spent as this many e-folds across that reach (0 = a linear ramp)
const HALO_ALPHA_PCT := 40.0          # …and its alpha at the contact edge (%), which the shadow side
                                      # renders at 0.366 against the mock's 0.388
const HALO_OFFSET_FRAC := 0.0139      # THE LIGHT: the halo slides this far down and right, which is what
                                      # makes the two sides differ at all

# PAPER THICKNESS — a LIT hairline, not a dark bevel.
const BEVEL_FRAC := 0.008             # the lit cut edge's depth in from the edge — a HAIRLINE (~1.3px on
                                      # a 158px face). Measured off the mock: stepping inward from a
                                      # tile's edge onto its face, the mock gains ~+8 luma on the FIRST
                                      # pixel and is flat by the second. It is a lit paper edge, not a
                                      # shaded slab: a band reaching 0.045 W in reads as volume and the
                                      # sheet inflates into a plastic button.
const BEVEL_STRENGTH_PCT := 34.0      # …and its peak alpha (%)

# A PLAIN tile carries no visible border — its paper edge just ends. The warm cut-edge rim is reserved
# for the one tile that has something to say with it (the nav row's ACTIVE tab wears a cream/white rim
# sheet, which is what marks the current destination). The shared rim (rim_color/rim_width) is untouched
# everywhere else; this zeroes it for the surfaces that opt in.
const PLAIN_RIM_WIDTH := 0.0

# THE GLYPH'S DROP SHADOW — far heavier than the kit's shared Kit.GLYPH_SHADOW (0.18/0.12/0.07, straight
# down), which stays the default for every caller that does not ask for this treatment.
# Measured off the mock's Home tile, as darkening (1 − sampled/face luma) stepping SIDEWAYS out of the
# roof's right eave onto the flat coral face (931px canvas; ×1.16 for our 1080):
#     0.47 at 1px · 0.30 at 3px · 0.16 at 5px · 0.08 at 7px · 0.03 at 9px · 0 by ~12px
# The shared stack could not reach that sideways at ANY alpha: its copies are offset straight DOWN, so
# there is no lateral shadow at all — ours measured 0.13 at 1px and nothing past 3px, and the icons read
# as stickers laid flat on the paper. So each layer here also carries `grow`: the copy is drawn that much
# larger than the glyph (a fraction of the icon box, split evenly), which is what puts a soft pool all
# round it. `grow` defaults to 0 in the shared applier, so no other action button changes.
#
# THE STACK IS GENERATED, NOT HAND-AUTHORED. A hand-written five-layer table (grow
# 0.025/0.055/0.090/0.128/0.175) puts its copies 1.5 · 3.3 · 5.4 · 7.6 · 10.4 px out from the glyph on a
# 119px icon — steps of ~2px, each carrying an alpha JUMP of 0.05-0.19. The accumulation is therefore not
# a pool at all but flat plateaus with rings between them, which is exactly the failure cut_paper.gd's own
# drop-shadow comment warns about: "a sparse few-copy stack (3/7/11px) shows as discrete stepped bands on
# small elements (a button), so keep the step ≈ 1px". This stack fits an envelope through those five and
# resamples it at ~1px steps instead; `grow` and `dy` both vary smoothly across it.
#
# THAT MUCH IS MEASURED, on the rig (`make shot-mock` renders the same tab twice, once with each stack,
# on ONE face colour — so the art, the geometry and the ground are identical and only the stack differs;
# mock_profile.py's `--probe` then steps sideways off the house's own wall edge):
#     five-layer  0.289 · 0.145 · 0.092 · 0.094 · 0.035 · 0.028   ← 2px and 3px are the SAME: a plateau,
#     generated   0.221 · 0.120 · 0.052 · 0.030 · 0.022 · 0.027      then a cliff. The banding is real.
# The generated stack is monotone through the same run, so the ring is gone.
#
# TWO THINGS THAT ARE NOT TRUE, and were claimed when this stack landed:
#  * it does NOT keep the five-layer envelope. On the same probe it is 24% lighter at the contact and
#    reaches about half as far (down to the 0.015 noise floor by 4px, where the table took 6).
#  * neither stack is anywhere near the MOCK's own icon shadow, which on the same face colour holds
#    ≥ 0.40 for 9px and only dies at ~19px. That comparison is a bound, not a target: the mock's house is
#    a different drawing with an overhanging roof, so a ray out of its wall crosses the roof's cast shadow
#    too, and the rig cannot separate the two.
# It is left alone anyway, for a reason that outranks the gap: the glyph SPRITES still ship a baked cream
# sticker outline, which holds this shadow off the artwork's own edge, and a parallel pass is removing it.
# Both the contact and the reach move when that lands. GLYPH_SHADOW_CONTACT is the knob to re-fit then,
# on the rig, in one pass.
const GLYPH_SHADOW_GROW := 0.175      # the OUTERMOST copy's size gain, as a fraction of the icon box …
const GLYPH_SHADOW_DY := 0.058        # … and its drop. Both split across the stack, `dy` on a √ so the
                                      # near copies keep the mock's down-bias without smearing the far ones.
const GLYPH_SHADOW_CONTACT := 0.51    # the TOTAL darkening where the pool meets the glyph's own edge
const GLYPH_SHADOW_FALLOFF := 3.3     # …spent as this many e-folds across the reach (≈ 3px per e-fold)
const GLYPH_SHADOW_STEP_PX := 1.0     # …resampled THIS finely. The step is what stops the banding.


## THE TREATMENT, as a cut-paper knob patch to merge over whatever `cp` a caller already has (the shared
## action-button set from the workbench config). `face_w` is the button's own face WIDTH — every metric
## above is a fraction of it, so one tuning holds from a 130px almanac chip to a 200px nav tab.
##
## `rimmed` is the ONE tile in a group that keeps a border (the nav row's active tab). Everything else
## gets `rim_width` zeroed: a plain paper button's edge just ends.
##
## Note what is absent: no `flare`, no `bleed_bottom`, no caption. Those are a screen-edge tab's geometry
## and a free-standing button must not inherit them.
static func surface_cp(face_w: float, rimmed := false) -> Dictionary:
	var o := {
		"deckle_amp": DECKLE_AMP,
		"halo_reach": face_w * HALO_REACH_FRAC,
		"halo_strength": HALO_ALPHA_PCT,
		"halo_falloff": HALO_FALLOFF,
		"halo_offset": Vector2(face_w, face_w) * HALO_OFFSET_FRAC,  # down AND right: the light is upper-left
		"bevel_px": face_w * BEVEL_FRAC,
		"bevel_strength": BEVEL_STRENGTH_PCT,
		"edge_feather": EDGE_FEATHER_PX,
	}
	if not rimmed:
		o["rim_width"] = PLAIN_RIM_WIDTH
	return o


## Put the whole treatment on a Kit.action_button opts dict, in place, and return it. ONE call is what a
## caller needs: the cut-paper patch merged over its own `cp`, plus the dense glyph shadow generated for
## the icon box this button will actually draw.
##
## `size` is the button's rect. `icon_px` is the glyph box — pass it when the caller knows it; left out,
## it is derived exactly as Kit.action_button derives it for a CAPTIONLESS tile (`size.y * icon_scale`),
## which is what every free-standing paper button in the game is. A captioned tile (a nav tab) has its own
## builder and does not come through here.
static func apply(opts: Dictionary, size: Vector2, icon_px := -1.0) -> Dictionary:
	var cp: Dictionary = (opts.get("cp", {}) as Dictionary).duplicate()
	cp.merge(surface_cp(size.x), true)
	opts["cp"] = cp
	if icon_px <= 0.0:
		icon_px = size.y * float(opts.get("icon_scale", 0.9))
	opts["glyph_shadow"] = glyph_shadow(icon_px)
	return opts


## The glyph-shadow stack for an icon `icon_px` across — the {dy, grow, a} layer list Kit.action_button
## consumes. A layer's copy is drawn `grow`×icon_px wider (split evenly on all four sides) and `dy`×icon_px
## lower than the glyph, so the silhouette's outermost point moves out by `grow`×icon_px/2: THAT is the
## distance the step count is derived from, so the copies stay ~1px apart whatever size the button comes
## out at. Per-layer alphas are solved (outermost first) so the ACCUMULATION — not any single copy —
## follows the measured envelope.
static func glyph_shadow(icon_px: float) -> Array:
	var reach_px := GLYPH_SHADOW_GROW * maxf(icon_px, 1.0) * 0.5
	var steps := maxi(4, int(round(reach_px / maxf(GLYPH_SHADOW_STEP_PX, 0.05))))
	var out: Array = []
	var keep := 1.0            # transmittance the copies already emitted (the outer ones) leave behind
	for i in range(steps, 0, -1):
		var u := float(i) / float(steps)                       # 0 at the glyph → 1 at the fringe
		# the band this copy bounds runs from (i-1)/steps to i/steps — sample its MIDPOINT, the best a
		# piecewise-constant stack can do against a continuous curve.
		var want := GLYPH_SHADOW_CONTACT * CutPaper.halo_profile(GLYPH_SHADOW_FALLOFF, (float(i) - 0.5) / float(steps))
		var target := 1.0 - want
		var per := clampf(1.0 - target / maxf(keep, 0.0001), 0.0, 1.0)
		keep = target
		if per <= 0.0:
			continue
		out.append({"dy": GLYPH_SHADOW_DY * sqrt(u), "grow": GLYPH_SHADOW_GROW * u, "a": per})
	return out
