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
const CORNER_FRAC := 0.19             # rounded-rect corner radius
const CAPTION_FONT_FRAC := 0.16       # caption size before the fit-to-width shrink
const CAPTION_BASELINE_FRAC := 0.055  # caption baseline above the tile's BOTTOM edge
const GLYPH_BOX_FRAC := 0.62          # the glyph's square box
const GLYPH_CENTER_FRAC := 0.42       # glyph centre, as a fraction of the tile's OWN visible height
const ACTIVE_W_FRAC := 1.05           # the active tab grows outward into the gaps …
const ACTIVE_H_FRAC := 0.94           # … and upward, so it reads as the raised, current tab
const ACTIVE_RIM_FRAC := 0.037        # its cream rim, drawn OUTSIDE the fill

# The tab's PAPER look — the things that separate a bled tab from the art behind it. All of them are
# shared cut-paper knobs (Kit.CUT_PAPER_KNOBS) whose defaults are inert, so they bite on this row and
# nowhere else.
const FLARE := 0.07                   # the VISIBLE bottom edge reads 7% wider than the top (a trapezoid)
const HALO_REACH_FRAC := 0.11         # the ambient shadow's reach out from every edge. The tile bleeds off
                                      # the bottom of the screen, so a DOWNWARD offset is wasted — the lift
                                      # has to come from a long, soft halo on the top and the sides. Twice
                                      # the mock's reach: the mock's shadow dies by ~12px and reads glued
                                      # on; a card floating above the ground carries a fringe out past 20.
const HALO_ALPHA_PCT := 38.0          # …and its alpha where it touches the paper (%) — measured off the
                                      # mock, whose tiles darken their ground by ~0.28 at the contact edge
const BEVEL_FRAC := 0.045             # the slab bevel's depth in from the edge
const BEVEL_STRENGTH_PCT := 34.0      # …and its peak alpha (%)
# SMOOTH EDGE: the tabs wear the mock's clean rounded corners, not the torn cut-paper deckle every other
# paper surface in the game wears. It is the same CutPaperPanel with its tear amplitude zeroed — fill,
# rim, halo, bevel and every metric above are untouched.
const DECKLE_AMP := 0.0
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
	}
	if not active:
		o["rim_width"] = PLAIN_RIM_WIDTH
	return o

## The plain tile's box for a row whose slot width is `w`.
static func tile_size(w: float) -> Vector2:
	return Vector2(w, w * TILE_H_FRAC)

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
		"rim_px": w * ACTIVE_RIM_FRAC,
		"caption_shadow": CAPTION_SHADOW,
	}
