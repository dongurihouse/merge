extends RefCounted
## THE SCREEN-EDGE TAB GEOMETRY — what makes a cut-paper sheet read as a TAB pulled up out of the screen's
## bottom edge, rather than as a card floating on the art. Owned in one place, like the material beside it.
##
## Two things, and only two:
##   * THE BLEED — the paper runs PAST the sheet's own box, through the device's safe-area inset and one
##     corner radius beyond the screen, so the bottom corners round off-SCREEN and only the top two are
##     ever seen. There is no margin under the row at all.
##   * THE FLARE — the sheet is a symmetric trapezoid about its vertical centreline: the visible bottom
##     edge is wider than the top, so the sheet reads as splayed out of the edge it is anchored to.
##
## WHAT IS NOT HERE: the MATERIAL (smooth feathered edge · directional cast shadow · lit hairline · dense
## glyph shadow · no rim), which is engine/scripts/ui/paper_button.gd and holds whether a surface is edge
## anchored or not; and the ROW's layout (slot solve, gaps, captions, chalk), which is per-row and lives
## with the row that owns it (engine/scripts/ui/nav_bar.gd for the home/map bottom navigation).
##
## WHO WEARS IT: the home/map bottom nav tabs (engine/scripts/scenes/map.gd via NavBar) and the board's
## whole bottom row — its Home well, its cream info tray and its Bag well (engine/scripts/scenes/board.gd
## + engine/scripts/ui/action_bar.gd). It started life as a block of constants inside nav_bar.gd; the
## moment a second row needed the same geometry, "the nav row's numbers" stopped being an honest name.
##
## Every knob it produces is INERT at cut_paper.gd's own defaults (flare 0 = a plain rounded rect,
## bleed 0 = the paper stops at the box), so a surface that does not ask for this renders as it always did.

const Paper = preload("res://engine/scripts/ui/paper_button.gd")


# ── THE FLARE ────────────────────────────────────────────────────────────────────────────────────────
# Measured off the concept mock (games/grove/assets/_concepts/screens/palette_a_meadow_sky_board.png):
# a nav tab's VISIBLE bottom edge reads 5.5% wider than its top.
const FLARE := 0.055

# …and this is the figure the mock actually constrains: 5.5% OF WHAT. `cut_paper.flare` is a fraction of
# the sheet's own WIDTH, so the same 0.055 handed to two sheets of different proportions produces two
# different LEAN ANGLES on their short sides — and the lean is what the eye reads when the sheets sit
# side by side in one row. On the board's bottom row the spread is not subtle: at the nav tab's own
# aspect 0.055 leans the sides 1.8°, on a square Home well it would lean them 1.5°, and on the ~660px
# info tray beside them 4.9° — three different trapezoids in a row that is supposed to read as one bar.
#
# So the LEAN is the geometry and 0.055 is that lean written in the nav tab's own units. LEAN is how far
# each short side moves INWARD per px of DRAWN sheet height (box + bleed), and it is exactly what the nav
# row already renders — derived, not chosen:
#     flare knob   f       = FLARE · sheet_h / box_h        (the flare is measured across the VISIBLE box)
#     width lost at top    = f / (1 + f)                    (cut_paper._tab_base's `squeeze`)
#     lean                 = squeeze · face_w / (2 · sheet_h)
# On a nav tile, box_h = 0.83 W and the bleed is one corner radius (0.173 W), so sheet_h/box_h = 1.208
# whatever the row's tile count or the device's safe-area inset: f = 0.0665, squeeze = 0.0623, and the
# lean comes out 0.03107 at a 4-tab row and 0.03107 at a 5-tab one. Hence:
const LEAN := 0.0311
# `lean_of` recomputes it from the row's real numbers and engine/tests/action_button_tests.gd (4f) fails
# if the two ever drift — so re-tuning FLARE without re-deriving LEAN cannot ship a mismatched row.


## The `flare` knob for a sheet `face_w` px wide whose DRAWN paper (its visible box plus whatever it
## bleeds off the screen) is `sheet_h` px tall, so its short sides lean at `want_lean`. The inverse of
## `lean_of`. This is the entry point for any sheet that is not a nav tile — a square well, a wide tray.
static func flare_for_lean(face_w: float, sheet_h: float, want_lean: float = LEAN) -> float:
	if face_w <= 0.0 or sheet_h <= 0.0 or want_lean <= 0.0:
		return 0.0
	# squeeze = the total width the TOP edge gives up, as a fraction of the box width (cut_paper's own
	# spelling). Capped well short of 1 so a pathologically tall, narrow sheet cannot invert its own top.
	var squeeze := clampf(2.0 * want_lean * sheet_h / face_w, 0.0, 0.5)
	return squeeze / (1.0 - squeeze)


## The lean a `flare` knob actually produces on a sheet of these dimensions — the angle of its short
## sides, as px inward per px of drawn sheet height. The measurement `LEAN` is derived from.
static func lean_of(face_w: float, sheet_h: float, flare: float) -> float:
	if face_w <= 0.0 or sheet_h <= 0.0 or flare <= 0.0:
		return 0.0
	return (flare / (1.0 + flare)) * face_w / (2.0 * sheet_h)


## The NAV TAB's own flare knob: FLARE is measured across the tile's VISIBLE box, so the knob — which
## cut_paper applies across the WHOLE drawn sheet — is scaled by sheet_h/box_h. Kept as its own spelling
## (rather than routed through `flare_for_lean`) because it is the measurement LEAN was taken from, and
## because the shipped nav row must not move by a float's worth when the shared module lands.
static func tab_flare(box_h: float, sheet_h: float) -> float:
	if box_h > 0.0 and sheet_h > box_h:
		return FLARE * sheet_h / box_h
	return FLARE


## ── THE BLEED ────────────────────────────────────────────────────────────────────────────────────────
## How far the PAPER runs below the sheet's own box: through the device's safe-area inset (so a caption or
## a count never hides under a home indicator, while the sheet still meets the physical screen edge) and
## one full `corner` radius beyond it (so the bottom corner arc completes entirely off-screen and only the
## top two ever read as round). The owning Control's rect — and therefore its hit area — is untouched.
static func bleed_px(safe_bottom: float, corner: float) -> float:
	return maxf(0.0, safe_bottom) + maxf(0.0, corner)


## ── THE KNOB PATCHES ─────────────────────────────────────────────────────────────────────────────────
## The shared paper-button MATERIAL plus this geometry, as one cut-paper knob patch to merge over whatever
## `cp` a caller already has.
##
## `tab_cp` is the NAV TAB's: `face_w` is the tile's width, `box_h` its visible height and `sheet_h` the
## full drawn paper. `rimmed` is the one tile in a row that keeps a border (the active tab).
static func tab_cp(face_w: float, box_h: float, sheet_h: float, rimmed := false) -> Dictionary:
	var o: Dictionary = Paper.surface_cp(face_w, rimmed)
	o["flare"] = tab_flare(box_h, sheet_h)
	return o


## `sheet_cp` is every OTHER edge-anchored sheet's — a square well, a wide tray — flared to the SAME lean
## as a nav tab whatever its proportions. `material_w` is the face width the MATERIAL is scaled from and is
## deliberately separate from `face_w`: the treatment's metrics are fractions of a button's width because
## a button is roughly square, and handing a 660px-wide, 160px-tall tray its own width would ask for a 69px
## halo reach against the 17px its neighbours cast. A row of sheets shares one material scale — pass the
## row's own well size — while each sheet flares off its own real width.
static func sheet_cp(face_w: float, sheet_h: float, material_w: float, rimmed := false) -> Dictionary:
	var o: Dictionary = Paper.surface_cp(material_w, rimmed)
	o["flare"] = flare_for_lean(face_w, sheet_h)
	return o
