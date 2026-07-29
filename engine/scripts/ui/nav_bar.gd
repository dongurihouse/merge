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
# are in the workbench's picker set (Kit.CUT_PAPER_KNOBS) too; `halo_falloff` is code-set only, because it
# is meaningless on a surface whose `halo_reach` is 0 and every surface but this row's is.
const FLARE := 0.055                  # the VISIBLE bottom edge reads 5.5% wider than the top (a trapezoid)
# THE TAB'S CAST SHADOW. The tile bleeds off the bottom of the screen, so a DOWNWARD offset is wasted —
# the lift has to come from the ambient halo on the top and the sides. What that halo must NOT be is a
# broad smudge. Measured off the mock's own Shop tile (its right edge, against the flat sky, on the 931px
# concept canvas → ×1.16 for our 1080), the darkening beside a tile runs
#     0.30 at 1px · 0.21 at 3.5px · 0.12 at 6px · 0.08 at 8px · 0.03 at 13px · 0 by ~15px
# — an exponential decay with a ~5.5px constant. Reaching 0.11 W (~21px) on a LINEAR ramp instead put
# 0.18 at 8px and 0.08 still at 16px: the same contact darkness smeared across twice the run, which on a
# flat ground (the map gallery, where nothing hides it) reads as a grey wash under the row rather than a
# card sitting on the art. The reach comes back to the mock's own, and the ramp gets the mock's curve.
const HALO_REACH_FRAC := 0.083        # ~16px at our 1080 — where the mock's own shadow dies
const HALO_FALLOFF := 2.2             # …spent as this many e-folds across that reach (0 = the old linear
                                      # ramp). 2.2 over 16px is the mock's ~5.5px decay constant.
const HALO_ALPHA_PCT := 45.0          # …and its alpha where it touches the paper (%). This is the alpha at
                                      # t = 0; the innermost RING bounds the first ~1px band and so samples
                                      # the curve a little way down it, which on a decay this steep costs
                                      # ~15% of the contact that a linear ramp handed over for free. 45%
                                      # renders back the 0.26 the row already shipped (and which the mock
                                      # measures at ~0.30), so the CONTACT is unchanged and only the reach
                                      # and the shape of the falloff moved.
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
# THE STACK IS GENERATED, NOT HAND-AUTHORED, and that is the whole point. A hand-written five-layer table
# (grow 0.025/0.055/0.090/0.128/0.175) puts its copies 1.5 · 3.3 · 5.4 · 7.6 · 10.4 px out from the glyph
# on a 119px icon — steps of ~2px, each carrying an alpha JUMP of 0.05-0.19. The accumulation is therefore
# not a pool at all but five flat plateaus with hard rings between them, which is exactly the failure
# cut_paper.gd's own drop-shadow comment warns about: "a sparse few-copy stack (3/7/11px) shows as discrete
# stepped bands on small elements (a button), so keep the step ≈ 1px". So this stack keeps the ENVELOPE the
# five layers drew — the same contact darkness, the same outer reach, the same ~exponential decay fitted
# through them (0.51 at the foot, e-folding every ~3px, gone by 10.4) — and resamples it at ~1px steps, so
# the copies overlap into one concrete pool. `grow` and `dy` both vary smoothly across the stack.
# NOTE: the glyph SPRITES still ship a baked cream sticker outline, which holds this shadow off the
# artwork's own edge. That outline is being removed in a parallel pass; when it lands the same stack will
# read heavier still, and GLYPH_SHADOW_CONTACT is the one place to pull it back.
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
