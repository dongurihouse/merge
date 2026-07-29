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
# against 13/25 before.
const GAP_FRAC := 0.0074
const GAP_MIN_PX := 5.0               # …floored so a narrow phone keeps a visible cut between the tabs
const GAP_MAX_PX := 12.0              # …and capped so a tablet does not spread the row into five islands

# The tab's PAPER look — the things that separate a bled tab from the art behind it. All of them are
# shared cut-paper knobs (Kit.CUT_PAPER_KNOBS) whose defaults are inert, so they bite on this row and
# nowhere else.
const FLARE := 0.055                  # the VISIBLE bottom edge reads 5.5% wider than the top (a trapezoid)
const HALO_REACH_FRAC := 0.11         # the ambient shadow's reach out from every edge. The tile bleeds off
                                      # the bottom of the screen, so a DOWNWARD offset is wasted — the lift
                                      # has to come from a long, soft halo on the top and the sides. Twice
                                      # the mock's reach: the mock's shadow dies by ~12px and reads glued
                                      # on; a card floating above the ground carries a fringe out past 20.
const HALO_ALPHA_PCT := 38.0          # …and its alpha where it touches the paper (%) — measured off the
                                      # mock, whose tiles darken their ground by ~0.28 at the contact edge
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
# Measured off the mock's Home tile, as darkening (1 − sampled/face luma) stepping out of the icon:
#     below   0.50 at 1px → 0.30 at 5px → 0.08 at 9px  (931px canvas)
#     beside  0.40 at 1px → 0.14 at 5px → 0.04 at 8px
# The shared stack could not reach that sideways at ANY alpha: its copies are offset straight DOWN, so
# there is no lateral shadow at all — ours measured 0.13 at 1px and nothing past 3px, and the icons read
# as stickers laid flat on the paper. So each layer here also carries `grow`: the copy is drawn that much
# larger than the glyph (a fraction of the icon box, split evenly), which is what puts a soft pool all
# round it. `grow` defaults to 0 in the shared applier, so no other action button changes.
# Layers are cheap (one TextureRect each) and only the five tabs pay for them.
# NOTE: the glyph SPRITES still ship a baked cream sticker outline, which holds this shadow off the
# artwork's own edge. That outline is being removed in a parallel pass; when it lands the same stack will
# read heavier still, and the alphas here are the one place to pull it back.
const GLYPH_SHADOW := [
	{"dy": 0.020, "grow": 0.025, "a": 0.28},   # contact — tight and dark right at the icon's foot
	{"dy": 0.032, "grow": 0.055, "a": 0.17},
	{"dy": 0.042, "grow": 0.090, "a": 0.11},
	{"dy": 0.050, "grow": 0.128, "a": 0.055},
	{"dy": 0.058, "grow": 0.175, "a": 0.030},  # the outermost skirt — what the mock has and we did not
]

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
		"glyph_shadow": GLYPH_SHADOW,
	}
