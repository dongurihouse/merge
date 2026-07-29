extends RefCounted
## The shared bottom-navigation GEOMETRY constants (owner: one module read by the board + the map).
## The row builder that used to live here is gone — every shipped surface now builds its own bottom
## row — but the spacing contract stayed shared so the board and the home/map screen keep placing
## their bottom row (and everything that must clear it) at the SAME insets.
## Read by `engine/scripts/scenes/map.gd`, which preloads this script purely for these values.
## Lives in ui/ so scenes/ may import it; it must NOT reach up into scenes/ (the layering guard enforces this).
##
## The row is a TAB BAR bled to the screen edge (mock: _concepts/screens/palette_a_meadow_sky_board.png):
## each tile's paper runs OFF the bottom of the screen, so only its TOP corners visibly round and there
## is no margin under the row at all. The band anything else must clear is therefore the ACTIVE tile's
## height — the tallest thing in the row — never the plain tile's.

const CutPaper = preload("res://engine/scripts/ui/cut_paper.gd")   # for the shared shadow falloff curve

const DEFAULT_PX := 150.0     # nav button box size
const SIDE_INSET := 32.0      # left/right inset of the row

# Every nav-tab metric is a fraction of the NORMAL tile width W (measured off the concept mock). The
# ACTIVE tile takes its caption/glyph/rim sizes from the SAME W as its neighbours, so the captions read
# at one size on one baseline across the whole row however much taller the active tile grows.
const TILE_H_FRAC := 0.83             # visible tile height (the paper bleeds further down, off-screen)
const CORNER_FRAC := 0.173            # rounded-rect corner radius (measured off the mock's own tiles)
const CAPTION_FONT_FRAC := 0.16       # caption size before the fit-to-width shrink
const CAPTION_BASELINE_FRAC := 0.055  # caption baseline above the tile's BOTTOM edge
const GLYPH_BOX_FRAC := 0.62          # the glyph's square box
const GLYPH_CENTER_FRAC := 0.42       # glyph centre, as a fraction of the tile's OWN visible height
const ACTIVE_W_FRAC := 1.05           # the active tab grows outward into the gaps …
const ACTIVE_H_FRAC := 0.94           # … and upward, so it reads as the raised, current tab
const ACTIVE_RIM_FRAC := 0.037        # its white rim, drawn OUTSIDE the fill

# THE GAP between two neighbouring tabs, as a fraction of the SCREEN width. ONE accessor: the row's slot
# metric and its layout pass both read `gap_px`, so the two can never drift apart.
# Measured off the mock's own bottom edge (931px canvas): 8px either side of the active tab, 10px between
# two plain tiles — ~0.011 of its width. Ours sits TIGHTER than that on purpose, because ours carries two
# things the mock's flat tiles do not: the tabs FLARE, so the sheet narrows toward the top and the gap
# opens by another ~12px up there, and each sheet casts an ambient halo INTO the gap, which darkens it and
# reads as more void still. Matching the mock at the bottom therefore overshoots it everywhere the eye
# actually reads the row. 0.0074 puts ~8px between the drawn sheets at the bottom and ~20px at the top,
# against 13/25 before. (The halo has since been pulled back onto the mock's own reach, so it now floods
# the cut less — measured on the gallery render, the deepest point in the gap darkens by 0.19 where it
# darkened by 0.30. The flare still opens the cut toward the top, and the row reads unchanged there, so
# the pitch stays; if the gaps ever start reading tight, THIS is the number to open, not the halo.)
const GAP_FRAC := 0.0074
const GAP_MIN_PX := 5.0               # …floored so a narrow phone keeps a visible cut between the tabs
const GAP_MAX_PX := 12.0              # …and capped so a tablet does not spread the row into five islands

# The tab's PAPER look — the things that separate a bled tab from the art behind it. All of them are
# shared cut-paper knobs whose defaults are inert, so they bite on this row and nowhere else. All but one
# are in the workbench's picker set (Kit.CUT_PAPER_KNOBS) too; `halo_falloff` and `halo_offset` are
# code-set only, because both are meaningless on a surface whose `halo_reach` is 0 and every surface but
# this row's is.
const FLARE := 0.055                  # the VISIBLE bottom edge reads 5.5% wider than the top (a trapezoid)
# THE TAB'S CAST SHADOW. The tile bleeds off the bottom of the screen, so a shadow that only drops
# DOWNWARD is wasted — the lift has to come from the ambient halo on the top and the sides.
#
# THE MOCK'S SHADOW IS DIRECTIONAL, and every tuning of this row before this one missed that, because
# every one of them measured OUR row on a leafy home screen (or a blue-grey gallery), in our chalked
# fills, at 1080px, against THE MOCK's row on its flat sky, in its own fills, at 931px. A shadow's alpha
# is INFERRED from a luma ratio, so it is a function of the ground it lands on; none of those numbers
# were comparable, and each round drew a conclusion from them anyway. `games/grove/tools/navtab_shot.gd`
# exists to end that: it puts ONE of our tabs and ONE of the mock's on the same flat field of the mock's
# own sky, at the mock's own 162px tab width, with `fill=` forcing our paper to the mock tab's own
# colour — so the only thing left varying between the two cells is the shadow.
# Measured there (`navtab_profile.py`, darkening = 1 - sampled/field, stepping out from each tab's own
# per-row edge), the mock's LEFTMOST tab and its RIGHTMOST tab do not carry the same shadow at all:
#     left   0.168 at 1px · 0.077 at 3 · 0.052 at 4 · 0.020 at 6 · 0.006 at 8 · gone by 9
#     right  0.388 at 1px · 0.278 at 3 · 0.237 at 4 · 0.164 at 6 · 0.112 at 8 · 0.010 at 16
# The info card above the row splits the same way (0.23 left, 0.36 right), so this is the scene's light —
# upper left — and not one tile's quirk. A SYMMETRIC halo cannot be both: at the reach that fits the
# right, the left is four times too heavy; at the reach that fits the left, the right disappears. The
# 0.11 W linear ramp scored rms 0.144 against those two curves and a 0.083 W / 2.2-e-fold one scored
# 0.084 — better on the left, WORSE on the right, and neither within reach of the mock.
# So the halo gains a direction (CutPaper.halo_offset, inert at its default everywhere else) and the
# three numbers below were re-fitted on the rig against BOTH curves at once. Rendered, this tuning scores
# rms 0.018 — the mock's own paper grain is 0.016 — with one residual worth naming: the left contact
# reads 0.108 where the mock reads 0.168, because the ring stack is ~1px granular and the mock's value
# falls between two rings. That is one pixel column 6% light, and it is not visible at 1x.
const HALO_REACH_FRAC := 0.105        # the DILATION reach; the light then splits it into ~9px on the lit
                                      # side and ~19px on the shadow side (at our 1080 canvas)
const HALO_FALLOFF := 3.6             # …spent as this many e-folds across that reach (0 = a linear ramp)
const HALO_ALPHA_PCT := 40.0          # …and its alpha at the contact edge (%), which the shadow side
                                      # renders at 0.366 against the mock's 0.388
const HALO_OFFSET_FRAC := 0.0139      # THE LIGHT: the halo slides this far down and right (~2.6px at our
                                      # 1080), which is what makes the two sides differ at all
const BEVEL_FRAC := 0.008             # the lit cut edge's depth in from the edge — a HAIRLINE (~1.5px).
                                      # Measured off the mock: stepping inward from a tile's edge onto its
                                      # face, the mock gains ~+8 luma on the FIRST pixel and is flat by the
                                      # second. It is a lit paper edge, not a shaded slab: a band reaching
                                      # 9px in (0.045 W) reads as volume and the tab inflates into a button.
const BEVEL_STRENGTH_PCT := 34.0      # …and its peak alpha (%)
# SMOOTH EDGE: the tabs wear the mock's clean rounded corners, not the torn cut-paper deckle every other
# paper surface in the game wears. It is the same CutPaperPanel with its tear amplitude zeroed — fill,
# rim, halo, bevel and every metric above are untouched.
const DECKLE_AMP := 0.0
# …and the price of losing the tear: `draw_colored_polygon` antialiases nothing, so with the deckle gone
# the corner arc rasterized as a hard binary STAIRCASE. Measured across the Map tile's top-left arc — the
# pixels whose value lands between the ground and the fill — ours ran 0.00 per row (a pure binary step)
# against the mock's 1.68 on its own 931px canvas, i.e. ~1.95 at our 1080. A card's defining quality is a
# clean cut edge, so the row asks for the shared feather at that width. The ramp is CENTRED on the
# outline, so the silhouette neither moves nor grows — half the band of coverage lands either side of it,
# which is what the rasterizer would have written. Rendered back: 1.22 per row at 2.0px. Wider still
# (2.5 measured 1.39) stops reading as a cut and starts reading as a soft glow.
const EDGE_FEATHER_PX := 2.0
# Only the ACTIVE tab carries a visible border (its cream rim sheet). A plain tab's paper edge just ends —
# no warm cut-edge rim — which is what separates the current destination from its neighbours in the mock.
# The shared rim (rim_color/rim_width) is untouched everywhere else; this zeroes it for THIS row's plain
# tiles only.
const PLAIN_RIM_WIDTH := 0.0

# CHALK — the nav row's OWN tint transform, applied to whatever fill each tab's paper role resolves to.
# The roles (cream · sky · green · coral · gold) are shared with dialogs, pills, the board and the shop and
# must not move; the mock's tab colours are the same hues chalked down to pastels, so the row transforms
# the role fill at its own call site instead. Measured off the mock's tiles: saturation ~25-30% mean with
# nothing above ~40%, value 70-95 with a spread under 25.
const CHALK_SAT := 0.72          # keep this much of the role's saturation …
const CHALK_SAT_MAX := 0.30      # … and cap it, so a poster colour (gold 0.65, coral 0.53) lands in the band
const CHALK_LIFT := 0.50         # lift the value halfway to white — the chalk
const CHALK_VALUE_MAX := 0.92    # … but never past this: a white caption needs its tile to stay off white

# The caption's OWN shadow stack, heavier than the shared glyph one (Kit.GLYPH_SHADOW, 0.18/0.12/0.07).
# Chalking lifts every tile's value into the 70-95 band, which costs white type its contrast against the
# paper: measured on the rendered row, the white-vs-paper ratio falls from 3.0-3.8 to ~2.1. The letterform
# is resolved against its own shadow, not the paper, so the row darkens that instead — restoring the local
# contrast the chalked fills gave up, without pulling the tint back out of the mock's band.
const CAPTION_SHADOW := [{"dy": 0.03, "a": 0.30}, {"dy": 0.06, "a": 0.20}, {"dy": 0.09, "a": 0.12}]

# The ACTIVE tab's rim FILL — white. The rim is the one mark that says which destination you are on, and
# it has to carry against two very different grounds at once: the chalked GOLD Board tile it wraps, and
# the busy dark map art outside it. The shared Pal.CREAM (#F6EBDD) renders through the paper fibre at
# ~(235,218,195) — 1.34:1 against the chalked gold face, a warm sheet on a warm sheet, and it disappeared.
# A WHITE fill renders at ~(244,237,225) — 1.57:1, the ceiling available over a tile that pale, and the
# brightest thing in the row against the art. Not a hex near-white: the shared paper fibre is what warms
# it, and it lands on the mock's own measured rim (248,239,222). Pal.CREAM stays the default everywhere
# else (Kit.action_button's `rim_fill` opt).
const ACTIVE_RIM_FILL := Color.WHITE

# THE GLYPH'S DROP SHADOW for this row — far heavier than the shared Kit.GLYPH_SHADOW (0.18/0.12/0.07,
# straight down), which is the default everywhere else and is untouched by this table.
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
# THAT MUCH IS MEASURED, on the rig (games/grove/tools/navtab_shot.gd renders the same tab twice, once
# with each stack, on ONE face colour — so the art, the geometry and the ground are identical and only
# the stack differs; navtab_profile.py's `--probe` then steps sideways off the house's own wall edge):
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

## The row's glyph-shadow stack for an icon `icon_px` across — the {dy, grow, a} layer list
## Kit.action_button consumes. A layer's copy is drawn `grow`×icon_px wider (split evenly on all four
## sides) and `dy`×icon_px lower than the glyph, so the silhouette's outermost point moves out by
## `grow`×icon_px/2: THAT is the distance the step count is derived from, so the copies stay ~1px apart
## whatever size the row's tiles come out at. Per-layer alphas are solved (outermost first) so the
## ACCUMULATION — not any single copy — follows the measured envelope.
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

## The chalked tint for a nav tab whose paper role resolves to `fill`. Hue is preserved exactly — this is
## a chalking pass, not a re-hue, so every tab keeps its identity.
static func chalk(fill: Color) -> Color:
	var s := minf(fill.s * CHALK_SAT, CHALK_SAT_MAX)
	var v := minf(fill.v + (1.0 - fill.v) * CHALK_LIFT, CHALK_VALUE_MAX)
	return Color.from_hsv(fill.h, s, v, fill.a)

## The nav tab's CUT-PAPER knob patch — merged over the shared action-button opts so the tuning lands on
## THIS row only. `sheet_h` is the paper's full drawn height (the box plus whatever it bleeds off the
## screen); the flare is scaled by sheet_h/box_h so the 7% is measured across the part the player can
## SEE, not across the run that finishes below the screen edge. `active` is the raised current tab, the
## only tile in the row that keeps a border.
static func tab_cp(w: float, box_h: float, sheet_h: float, active := false) -> Dictionary:
	var f := FLARE
	if box_h > 0.0 and sheet_h > box_h:
		f = FLARE * sheet_h / box_h
	var o := {
		"flare": f,
		"deckle_amp": DECKLE_AMP,
		"halo_reach": w * HALO_REACH_FRAC,
		"halo_strength": HALO_ALPHA_PCT,
		"halo_falloff": HALO_FALLOFF,
		"halo_offset": Vector2(w, w) * HALO_OFFSET_FRAC,   # down AND right: the mock's light is upper-left
		"bevel_px": w * BEVEL_FRAC,
		"bevel_strength": BEVEL_STRENGTH_PCT,
		"edge_feather": EDGE_FEATHER_PX,
	}
	if not active:
		o["rim_width"] = PLAIN_RIM_WIDTH
	return o

## THE GAP between two neighbouring tabs' DRAWN sheets, on a screen `view_w` px wide. One accessor for
## the whole row — the slot metric and the layout pass must never compute this twice.
static func gap_px(view_w: float) -> float:
	return clampf(view_w * GAP_FRAC, GAP_MIN_PX, GAP_MAX_PX)

## The plain tile's box for a row whose slot width is `w`.
static func tile_size(w: float) -> Vector2:
	return Vector2(w, w * TILE_H_FRAC)

## The width a tab actually DRAWS for a row of slot width `w`: a plain tile is exactly its slot, but the
## active tab is wider than its slot AND wears a rim outside its fill. Laying the row out on these — not
## on the slots — is what keeps the VISIBLE gap even across the row and the tabs from ever touching.
static func drawn_w(w: float, active: bool) -> float:
	return (w * ACTIVE_W_FRAC + 2.0 * rim_px(w)) if active else w

## The active tab's rim thickness for a row of slot width `w`.
static func rim_px(w: float) -> float:
	return w * ACTIVE_RIM_FRAC

## The PLAIN tile (slot) width for a row of `n` tabs, `actives` of them raised, whose DRAWN sheets fill
## `span` px with `gap` between them. Solving for the drawn widths — rather than dividing the span into n
## equal slots and letting the active tab overhang into its neighbours' gaps — is the whole point: on the
## even-slot layout the raised tab's rim closed to 0.7px of its neighbour at the bottom edge (measured),
## so ANY tighter gap collided.
static func tile_px(span: float, n: int, gap: float, actives := 1) -> float:
	if n <= 0:
		return 0.0
	var units := float(n - actives) + float(actives) * (ACTIVE_W_FRAC + 2.0 * ACTIVE_RIM_FRAC)
	return maxf(1.0, (span - gap * float(n - 1)) / units)

## The ACTIVE tile's box: wider and taller than its slot. It is centred on its own slot and grows into
## the gaps, so it must NOT be laid out in flow — the neighbours keep their slots.
static func active_size(w: float) -> Vector2:
	return Vector2(w * ACTIVE_W_FRAC, w * ACTIVE_H_FRAC)

## The band the row occupies above its bottom edge: the TALLEST tile (the active tab). Everything that
## must clear the bar reserves THIS, so a raised active tab can never land under a badge or a card grid.
static func band_px(w: float) -> float:
	return w * ACTIVE_H_FRAC

## The nav-tab look opts every tile in a row of slot width `w` shares — fed straight into
## Kit.action_button. Derived here (not per tile) precisely because the active tile is a different
## SIZE but must wear the same type, glyph and corner as its neighbours.
static func tab_opts(w: float) -> Dictionary:
	return {
		"corner": w * CORNER_FRAC,
		"caption_font_px": int(round(w * CAPTION_FONT_FRAC)),
		"caption_baseline_px": w * CAPTION_BASELINE_FRAC,
		"glyph_box_px": w * GLYPH_BOX_FRAC,
		"glyph_center_frac": GLYPH_CENTER_FRAC,
		"rim_px": rim_px(w),
		"rim_fill": ACTIVE_RIM_FILL,
		"caption_shadow": CAPTION_SHADOW,
		"glyph_shadow": glyph_shadow(w * GLYPH_BOX_FRAC),
	}
