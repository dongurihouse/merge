extends RefCounted
## THE PAPER PROGRESS-BAR TREATMENT — the MATERIAL a cut-paper progress bar is made of, owned in one place.
##
## Like engine/scripts/ui/paper_button.gd beside it, this is not a component and not a layout: it is the
## set of knobs that make Kit.progress_bar's code-drawn track and fill read as CUT PAPER — a WELL sunk
## into the sheet it lies on (a warm cream floor, a dark crease at its lip, and the soft inner shadow the
## lip throws down into it) with a RAISED capsule of green card lying in that well, casting the scene's
## own upper-left light onto the floor beside its head.
##
## WHO WEARS IT: the board's NEXT UNLOCK strip (engine/scripts/ui/unlock_bar.gd). Nothing else — see
## "WHY THIS IS NOT THE DEFAULT" below, which is the whole reason this file exists rather than a changed
## constant in the kit.
##
## Every number is measured off THIS BAR'S OWN concept mock,
## games/grove/assets/_concepts/screens/board_next_unlock_v1_1080x1920.png, whose bar is 524 x 48 px at
## the mock's own 1080 canvas — and every one is written as a fraction of the bar's own drawn HEIGHT, so
## one tuning holds across the strip's whole shipped range (the band is 84-132px tall depending on the
## viewport, so the bar is 30-48px). Height, not width: a progress bar is a long capsule, and its width
## is the layout's business, not the material's. That is the same separation EdgeTab.sheet_cp makes when
## it takes a `material_w` apart from the sheet's own `face_w`.
##
## HOW THE NUMBERS WERE TAKEN. `mock_profile.py` steps out from an element's own edge and reports the
## DARKENING (1 - sampled/field). Inside a well there is no edge to step out from, so the readings below
## are plain columns through the mock's bar, converted to the alpha that reproduces them over the well's
## own floor. The rig (`make shot-mock CELLS="mock:unlock_track unlock_track"`) then puts our bar and the
## mock's on ONE cream field at ONE scale, which is what the fit was checked against — see
## docs/design/verifying-against-a-mock.md.
##
## WHY THIS IS NOT THE DEFAULT ON Kit.progress_bar. The shared component has a second shipping caller,
## the level-up dialog (engine/scripts/ui/level_popup.gd), and that dialog draws its bar from its OWN
## asset sheet — kit/level_track.png's slate capsule, matched to the navy medallion above it. No mock
## asks for that surface to change, and board_next_unlock_v1 is not its authority. So the material is an
## OPT: `Kit.progress_bar` renders exactly what it always did unless a caller hands it `paper`, and the
## band is the only caller that does. Flipping the whole game onto it is a one-line change here (put this
## patch in Kit.progress_bar_opts_from_config) if the owner ever wants it — this file being the single
## place the look is written is what makes that one line, rather than a second copy to keep in step.

const Game = preload("res://engine/scripts/core/game.gd")
const Paper = preload("res://engine/scripts/ui/paper_button.gd")   # the shared cast shadow + smooth edge
const Pal = Game.PALETTE


# ── THE WELL ─────────────────────────────────────────────────────────────────────────────────────────
# The mock's track floor is NOT the band's cream: measured on a column of empty track, the band reads
# (251,236,218) and the floor beside it (247,225,201) — a little less red, ~11 less green and ~17 less
# blue. A recess in warm paper goes WARMER, not merely darker, which is why this is a per-channel tint
# and not `Pal.CREAM.darkened(k)` (that would take all three channels down together and read grey).
#
# IT IS A RATIO OF THE SHEET, NOT AN ABSOLUTE COLOUR, and that is the whole correction this constant
# carries. The first spelling was the mock's own floor pixels, `Color("#F8E1C9")`, handed straight to
# `configure()` — and a CutPaperPanel MULTIPLIES its fill by the paper-fibre tile. Measured on the rig,
# that tile costs (0.956, 0.931, 0.879), so the well rendered (238,210,178) where the mock draws
# (247,225,201): 9 red, 15 green and 23 blue too dark, which is a visible peach cast at 1x.
#
# The right target is not the mock's absolute value either, because the SAME tile is under the band, and
# our whole cut-paper skin therefore sits below the painting (our band face renders (235,219,195) against
# the mock's (251,236,218)). Matching the mock's floor in absolute terms would need a red of 258/255 —
# unreachable — and would have made the recess shallower than the mock's rather than deeper. What is
# like-for-like is the RECESS DEPTH: how much darker the floor is than the sheet it is cut into, which is
# rule 16 of docs/design/verifying-against-a-mock.md read forwards. Measured on the mock: floor/band =
# (0.984, 0.953, 0.922). Written as a ratio of the sheet, the tile cancels exactly — rendered floor over
# rendered band is well/CREAM whatever the tile costs — so this holds if the fibre or the cream is
# re-tuned, and it verified to the digit: CREAM (246,235,221) inferred back out of the shipped render at
# (245.7, 234.5, 220.6).
const WELL_OF_SHEET := Color(0.9841, 0.9534, 0.9220)

## The well's floor for a given sheet colour — the SHEET the well is cut into, not the well.
static func well_fill(sheet: Color = Pal.CREAM) -> Color:
	return Color(sheet.r * WELL_OF_SHEET.r, sheet.g * WELL_OF_SHEET.g, sheet.b * WELL_OF_SHEET.b, sheet.a)

# THE LIP'S CREASE — the dark line where the sheet's own surface turns down into the well. Measured on
# the same column: (190,167,139) at its darkest, i.e. the floor colour scaled by 0.77 / 0.74 / 0.69.
# Written as a `darkened()` of whatever floor colour is in play so a re-tint carries the crease with it;
# the residual is the blue channel, which the mock takes ~15 further down than a uniform scale does.
const CREASE_DARKEN := 0.23
# …and how wide that line is. The rim is drawn as a polyline ON the outline (half in, half out), so this
# is its full drawn width.
#
# THE FIRST FIGURE MEASURED THE RAMP, NOT THE LINE. "The mock's crease runs 3px of a 48px bar" counted
# every row between the band face and the flat floor, and set rim_width to all of it — which rendered a
# SLAB, not a crease. Sectioned on the rig (a 60px-wide column mean through empty track, both cells on
# one field):
#     mock  204,182,157 · 189,164,136 · 197,172,144 · 215,190,163 · 233,209,182 · 241,219,193 · floor
#     ours  191,173,155 · 191,173,155 · 191,173,155 · 191,173,155 · 223,199,171 · 234,207,176 · floor
# The mock's dark CORE is two rows with one darkest, and everything after it is the lip's inner shadow
# recovering over four more. Ours was four rows of one flat value — the rim — and the inset shadow had
# almost nothing left to fall on. At 3x the well read as a grey OUTLINE round a cream capsule instead of
# a cut edge. So the line is the core only and the ramp goes back to INSET_* below, where it belongs.
const CREASE_W_FRAC := 0.0417        # 2px on a 48px bar

# THE INNER SHADOW the lip throws down into the well. Measured, as the alpha of the crease colour over
# the well floor, stepping DOWN from the first floor pixel: 0.53 · 0.20 · 0.10 · 0.07 · 0 by 5px. The
# tint is the crease itself and not the cool `#294654` every other inset in the kit uses, and that is a
# measurement rather than a preference: solving the mock's ramp for a tint gives the SAME alpha from all
# three channels only for a warm one (0.517 / 0.534 / 0.548 at the contact row). The cool tint fits the
# red and then leaves green and blue 5-10 too high.
const INSET_REACH_FRAC := 0.115       # how far down into the well it reaches (5.5px on a 48px bar)
const INSET_ALPHA := 0.53             # its alpha at the contact row
const INSET_FALLOFF := 3.0            # …spent as this power across the reach (CutPaperInsetShadow's curve)

# THE WELL IS A CAPSULE: fully round ends, whatever the bar's length. Not a knob — a progress bar with
# square ends is a different drawing — but spelled here so the caller does not have to know it.
const CORNER_FRAC := 0.5

# …and a capsule is the ONE shape in the game whose corner radius is half its own height, so it is the
# one that cannot afford cut_paper's legacy arc sampling (see `arc_step` there: quarter-arcs get 0.45x
# the point density straight edges get, at every radius). At the fill's 21.6px radius that formula spends
# three segments per quadrant — an 11px chord — and the rim polyline draws a dark line along each flat,
# so the cap photographed as a six-sided fan beside the mock's semicircle. Asked for at the edge
# feather's own width the facet is narrower than the ramp that would have to reveal it: sagitta falls
# from 0.74px to 0.02px.
const ARC_STEP_PX := Paper.EDGE_FEATHER_PX


# ── THE FILL ─────────────────────────────────────────────────────────────────────────────────────────
# The green card lying IN the well. It nearly fills it: the mock's fill is 44px in a 48px well, so 2px
# of floor shows above and below and the capsule reads as seated rather than floating.
const FILL_H_FRAC := 0.90
# …and 1.5px of floor either end, which is what keeps its cap from merging into the crease.
const FILL_INSET_X_FRAC := 0.031

# THE FILL'S OWN PAPER EDGE — a darker line all round the green, the same cut-edge the rest of the game's
# card stock carries. Measured off the mock's fill face (101,151,87) against its edge (83,122,71): a flat
# 0.82 on every channel, i.e. a uniform darkening, so `darkened()` is the right spelling here.
const FILL_RIM_DARKEN := 0.185
const FILL_RIM_W_FRAC := 0.05         # of the FILL's height (~2px on a 44px fill)

# THE CAST SHADOW off the fill's HEAD, onto the well floor in front of it — the thing that makes the
# capsule sit ON the floor rather than be printed into it. Probed on the rig stepping RIGHT out of each
# cap (a 16px-tall column mean, both cells on the band's own cream):
#     mock  0.292 · 0.242 · 0.204 · 0.172 · 0.113 · 0.059 · 0.030 · 0.015 · gone by 10px
#     ours  0.273 · 0.148 · 0.095 · 0.060 · 0.032 · 0.017 · 0.010 · 0.005 · gone by 10px
# That contact is the SCENE's own (the mock's nav tabs read 0.388 on their shadow side, the wallet pills
# 0.366), so the shadow is the shared paper-button material and not a second tuning — `Paper.surface_cp`
# is what produces it, and re-tuning the game's light moves this with everything else.
#
# ONE THING HAS TO BE SCALED BY HAND (rule 2 of the method doc). The material's reaches are fractions of
# a BUTTON's width because a button is roughly square; a 44px-tall capsule is not. Handed its own height
# the reach comes out 4.6px against the 10px the mock draws. `Paper`'s split puts the shadow side at
# reach + offset, which on the nav tab's 158px face is 18.8px — so the face width that lands 10px is
# 158 x 10/18.8 = 84, i.e. 1.9 x the fill's height. Hence:
const FILL_MATERIAL_K := 1.9
# A NAMED RESIDUAL, not a to-do (rule 15). Contact and reach both land — 0.273 against 0.292, dead by
# 10px like the mock — but the MID-field is about half the mock's and the pair scores rms 0.060 against
# a 0.008 grain floor. The shape is the shared material's own: `Paper.HALO_FALLOFF` spends 3.6 e-folds
# across the reach, and the mock's head shadow holds a near-plateau for 4px and then drops. Fitting it
# here means either re-tuning that falloff — which restyles every paper button in the game against a
# curve none of them were measured on — or inflating FILL_MATERIAL_K until the near field fits, which
# buys it with a reach of 17px on a 48px bar, i.e. a faint smudge across a third of the well where the
# mock has clean floor (swept: K=3.3 scores rms 0.033 and puts 0.049 at 8px against the mock's 0.015).
# The same undershoot is already recorded on the nav tab, which is where the material WAS fitted. So the
# capsule is left on the shared scale, and this is the number to quote rather than chase.


## The material, as a patch for Kit.progress_bar's `paper` opt — the ONE key that turns its code-drawn
## track and fill into a cut-paper well and capsule. `bar_h` is the bar's own drawn height in px.
##
## `fill` is the capsule's face colour; the crease and the fill's rim are derived from the two faces, so
## a caller that re-hues the fill (the strip turns it gold when the next unlock is affordable) gets a
## matching edge for free rather than a green line round a gold capsule.
##
## `sheet` is the colour of the SURFACE THE WELL IS CUT INTO, not the well's own — the floor is a ratio
## of it (WELL_OF_SHEET), so a band drawn on some other stock gets a recess of the right depth in it
## rather than a cream well pasted onto the wrong paper.
static func opts(bar_h: float, fill: Color, sheet: Color = Pal.CREAM) -> Dictionary:
	var h := maxf(1.0, bar_h)
	var fill_h := h * FILL_H_FRAC
	var well := well_fill(sheet)
	return {
		"well_fill": well,
		"crease": well.darkened(CREASE_DARKEN),
		"crease_w": h * CREASE_W_FRAC,
		"feather": Paper.EDGE_FEATHER_PX,
		"arc_step": ARC_STEP_PX,
		"inset_reach": h * INSET_REACH_FRAC,
		"inset_alpha": INSET_ALPHA,
		"inset_falloff": INSET_FALLOFF,
		"inset_tint": well.darkened(CREASE_DARKEN),
		"fill_rim": fill.darkened(FILL_RIM_DARKEN),
		"fill_rim_w": fill_h * FILL_RIM_W_FRAC,
		"fill_inset_x": h * FILL_INSET_X_FRAC,
		"fill_cp": Paper.surface_cp(fill_h * FILL_MATERIAL_K),
		"corner_frac": CORNER_FRAC,
	}


## The geometry knobs that go on the progress bar's own opts dict beside `paper` — the fill's height
## inside the well. Separate from `opts` because these are keys Kit.progress_bar has always had, and a
## caller may want to say something else with them.
static func fill_geometry() -> Dictionary:
	return {"fill_height_pct": FILL_H_FRAC * 100.0}
