extends RefCounted
## Common TUNING for the base engine — theme-agnostic look/feel defaults, grouped by
## the module they shape (one inner class each). These are the ENGINE's own defaults,
## independent of the active game; GAME-specific values live in Game.DATA (read as
## G.X) and Game.PALETTE (read as Pal.X). Retune here without spelunking the modules.
##
## A consumer aliases its own section, e.g.  const Tune = preload(this).Ambient → Tune.X

class Ambient:
	# --- characters --------------------------------------------------------------------
	const CHAR_SIZE := Vector2(84, 84)            # a character's on-screen box
	const SPARSE_CAP := 2                          # a "sparse" layer (the board's backdrop band) shows at most this many
	const EDGE_MARGIN := 40.0                      # a character is kept this many px clear of every edge of bounds
	const REPATH_SPAN := 3600.0                    # the per-frame position pump re-arms over this span (s); only needs to outlast a sitting

	# --- the wander path (a slow Lissajous figure + a vertical bob) ---------------------
	const CENTER_MIN := 0.16                        # each character's home point lands in [MIN, MIN+SPAN] of bounds, per axis
	const CENTER_SPAN := 0.68
	const SPEED_BASE := 0.010                       # base angular speed of the wander
	const SPEED_STEP := 0.005                       # +this per speed-class, so characters drift out of phase
	const SPEED_CLASSES := 3                        # i % this picks the speed-class
	const AMP_X := 0.20                             # horizontal reach of the wander, as a fraction of bounds
	const AMP_Y := 0.14                             # vertical reach (a flatter ellipse than X)
	const FREQ_Y_RATIO := 0.83                      # Y oscillates at this fraction of X's rate → an open, non-repeating figure
	const PHASE_Y_MULT := 1.7                       # extra Y phase, so X and Y never crest together
	const BOB_AMP := 7.0                            # the small extra up/down bob, in px
	const BOB_SPEED := 1.6                          # bob angular speed
	const BOB_PHASE_STEP := 1.3                     # per-character bob phase, so they don't bob in lockstep

	# --- placeholder character art (drawn only when the game ships no sprite) -----------
	const BODY_SIZE := Vector2(56, 56)              # the rounded body panel
	const BODY_OFFSET := Vector2(14, 18)            # its inset within CHAR_SIZE
	const BODY_COLOR := Color("#6B7B52", 0.92)      # soft moss green
	const BODY_SHADOW := Color(0, 0, 0, 0.2)
	const BODY_SHADOW_SIZE := 4
	const EYE_COUNT := 2
	const EYE_SIZE := Vector2(7, 9)
	const EYE_COLOR := Color("#E8B23C")             # warm amber
	const EYE_ORIGIN := Vector2(30, 38)             # the first eye's top-left within the character box
	const EYE_SPACING := 16                          # px from one eye to the next

	# --- the tap-hop (a quick squash & stretch) ----------------------------------------
	const HOP_SQUASH := Vector2(1.15, 0.85)
	const HOP_STRETCH := Vector2(0.92, 1.12)
	const HOP_T_SQUASH := 0.08                       # seconds for the squash leg
	const HOP_T_REST := 0.10                         # seconds for the stretch leg, and again for the settle leg

	# --- weather selection (a deterministic roll, one bucket per real hour) -------------
	const SECS_PER_HOUR := 3600.0                    # weather rolls once per hour; also the win-back's hour→seconds factor
	const ROLL_RANGE := 100                          # the hourly roll spans 0..ROLL_RANGE-1
	const BREEZE_AT := 70                            # roll in [BREEZE_AT, RAIN_AT) → breeze  (≈20%)
	const RAIN_AT := 90                              #         [RAIN_AT, SNOW_AT)   → rain    (≈8%)
	const SNOW_AT := 98                              #         [SNOW_AT, ROLL_RANGE) → snow   (≈2%); below BREEZE_AT → clear (≈70%)
	const WINBACK_RAIN_SECS := 60.0                  # on a >=48h return, it rains for this long

	# --- weather particles (budget: ≤2 emitters, ≤80 particles per layer) ---------------
	const BREEZE_PETAL := Color("#D98BA3")           # pink blossom drift
	const BREEZE_LEAF := Color("#7FA65A")            # green leaf drift
	const BREEZE_AMOUNT := 12
	const BREEZE_PETAL_LIFE := 9.0
	const BREEZE_LEAF_LIFE := 11.0
	const BREEZE_PETAL_VEL := Vector2(34, 10)        # (gravity x, y) for the petal emitter
	const BREEZE_LEAF_VEL := Vector2(28, 14)
	const RAIN_AMOUNT := 70
	const RAIN_LIFE := 1.3
	const RAIN_VEL := Vector2(40, 980)               # fast, almost straight down
	const RAIN_TOP_OFFSET := -40.0                   # the rain emitter sits this far above the view
	const RAIN_SCALE_MIN := 0.8                      # the tiny streak tex needs ~full size
	const RAIN_SCALE_MAX := 1.3
	const RAIN_VEIL := Color(0.45, 0.58, 0.74, 0.10) # a faint blue wash over the scene
	const SNOW_AMOUNT := 50
	const SNOW_LIFE := 12.0
	const SNOW_VEL := Vector2(14, 38)                # slow, drifting
	const SNOW_SCALE_MIN := 1.1
	const SNOW_SCALE_MAX := 1.8
	const SNOW_FROST := Color(0.62, 0.72, 0.86, 0.10) # a cool cast so flakes read on a pale background

	# --- the shared drift emitter + the two code-drawn textures ------------------------
	const EMIT_WIDTH_FRAC := 0.75                    # the emission band spans this fraction of the view width
	const EMIT_BAND_H := 8.0                         # ...and is this thin (px)
	const EMIT_TOP_OFFSET := -30.0                   # particles spawn this far above the top edge
	const DRIFT_DIR := Vector2(0.2, 1.0)             # mostly down, with a slight sideways lean
	const DRIFT_SPREAD := 12.0                       # ± degrees of spread around DRIFT_DIR
	const DRIFT_VEL_MIN := 18.0                      # initial speed range
	const DRIFT_VEL_MAX := 42.0
	const DRIFT_SPIN := 40.0                         # ± angular velocity (deg/s)
	const DRIFT_SCALE_MIN := 0.05                    # default particle scale (rain & snow override these)
	const DRIFT_SCALE_MAX := 0.16
	const STREAK_SIZE := Vector2i(4, 26)             # the rain-streak bitmap, in px
	const STREAK_COLOR := Color(0.75, 0.85, 1.0, 0.55)
	const FLAKE_SIZE := 10                           # the snowflake bitmap is FLAKE_SIZE × FLAKE_SIZE px
	const FLAKE_RADIUS := 4.5                        # soft-disc radius, and the bitmap's center
	const FLAKE_ALPHA := 0.9                         # alpha at the flake's center, fading to 0 at the rim

	# --- internal: seed mixing (arbitrary co-primes; they only decorrelate the inputs) --
	const SECS_PER_DAY := 86400.0                    # the wander reseeds once per real day
	const SEED_DAY_MULT := 31                        # hash(day*SEED_DAY_MULT + i*SEED_I_MULT)
	const SEED_I_MULT := 7
	const SPREAD_X := 997                            # large primes that fan the hash across the 0..1 ranges
	const SPREAD_Y := 991
	const PHASE_MOD := 6283                          # phase ∈ [0, PHASE_MOD/PHASE_DIV) ≈ [0, 2π)
	const PHASE_DIV := 1000.0


class Audio:
	# --- the SFX player pool -----------------------------------------------------------
	const VOICES := 8                                # round-robin player pool → max sounds that can overlap


class FX:
	# --- calm mode (accessibility) -----------------------------------------------------
	const CALM_AMOUNT_SCALE := 0.4        # particle count ×this in calm mode
	const CALM_AMOUNT_FLOOR := 4          # ...but never fewer than this

	# --- pop (tap / confirm acknowledge) -----------------------------------------------
	const POP_SCALE := Vector2(1.12, 1.12)
	const POP_T_OUT := 0.1
	const POP_T_SETTLE := 0.16

	# --- wobble (invalid / nudge) ------------------------------------------------------
	const WOBBLE_CALM_TILT := 0.07                  # calm: one gentle tilt (rad)
	const WOBBLE_CALM_T_OUT := 0.12
	const WOBBLE_CALM_T_BACK := 0.14
	const WOBBLE_SHAKE := [0.22, -0.17, 0.09]       # else: a quick shake — keyframe angles (rad)
	const WOBBLE_SHAKE_T := [0.05, 0.06, 0.05, 0.05]   # per-leg durations (4th = settle to 0)

	# --- rock / breathe (idle attention) -----------------------------------------------
	const ROCK_DEG := 6.0                 # default sway amplitude (deg)
	const ROCK_CYCLE := 1.2               # default seconds per full sway
	const ROCK_CYCLES := 3
	const BREATHE_AMOUNT := 1.05          # default pulse scale
	const BREATHE_PERIOD := 0.9           # default seconds per breath

	# --- floating_text -----------------------------------------------------------------
	const FLOAT_SIZE := 44                # default font size
	const FLOAT_OUTLINE := 10
	const FLOAT_Z := 60
	const FLOAT_SCALE_START := 0.4
	const FLOAT_ROT_START := -0.12
	const FLOAT_SCALE_POP := Vector2(1.3, 1.3)
	const FLOAT_ROT_POP := 0.06
	const FLOAT_T_POP := 0.16
	const FLOAT_RISE := 75.0              # how far it drifts up (px)
	const FLOAT_T_RISE := 0.75
	const FLOAT_HOLD := 0.18              # pause before fading
	const FLOAT_T_FADE := 0.3

	# --- celebrate_at ------------------------------------------------------------------
	const CELEB_TEXT_DX := 11.0           # text re-center: px per character
	const CELEB_TEXT_DY := 64.0
	const CELEB_BURST := 20               # particle count for a celebration

	# --- pop_in / scatter_in (overlay & group arrivals) --------------------------------
	const POPIN_SCALE_START := 0.92
	const POPIN_T := 0.12
	const SCATTER_SCALE_START := 0.3
	const SCATTER_STAGGER := 0.04         # added delay per item
	const SCATTER_T := 0.22

	# --- tick (wallet count-up) --------------------------------------------------------
	const TICK_T_COUNT := 0.4             # number roll duration
	const TICK_CHIP_SCALE := Vector2(1.06, 1.06)
	const TICK_CHIP_T_OUT := 0.12
	const TICK_CHIP_T_BACK := 0.14

	# --- fly_to_wallet (a grant arcs its icon to the wallet chip) ----------------------
	const FLY_ICON_OFFSET := Vector2(16, 16)        # icon is centered by subtracting this
	const FLY_Z := 60
	const FLY_FALLBACK := Vector2(0, -200)          # dest when there's no target chip
	const FLY_ARC := Vector2(0, -110)               # mid-point lift for the arc
	const FLY_T_UP := 0.18
	const FLY_T_DOWN := 0.22
	const FLY_SCALE := Vector2(0.55, 0.55)

	# --- burst (celebration particles; grove sprite vs soft dot) -----------------------
	const BURST_AMOUNT := 14              # default particle count
	const BURST_Z := 30
	const BURST_EMIT_RADIUS := 6.0
	const BURST_SPREAD := 180.0
	const BURST_GROVE_LIFE := 1.1         # grove juice is floaty / settling
	const BURST_DOT_LIFE := 0.55
	const BURST_GROVE_GRAVITY := 130.0
	const BURST_DOT_GRAVITY := 320.0
	const BURST_GROVE_VEL_MIN := 60.0
	const BURST_GROVE_VEL_MAX := 170.0
	const BURST_DOT_VEL_MIN := 110.0
	const BURST_DOT_VEL_MAX := 280.0
	const BURST_GROVE_SPIN := 160.0       # ± angular velocity (dots don't spin)
	const BURST_GROVE_SCALE_MIN := 0.05   # sprites are 128px
	const BURST_GROVE_SCALE_MAX := 0.14
	const BURST_DOT_SCALE_MIN := 0.4      # dots are 24px
	const BURST_DOT_SCALE_MAX := 1.0
	const BURST_GROVE_TINT := Color(1, 1, 1, 0.95)  # sprites carry their own paint

	# --- _pick_tex colour → sprite, and the fallback dot texture -----------------------
	const POLLEN_R := 0.7                 # r > this ...
	const POLLEN_G := 0.55                # ... and g > this ...
	const POLLEN_B := 0.5                 # ... and b < this → pollen (else leaf if g>r, else petal)
	const DOT_TEX_SIZE := 24


class Hud:
	# --- layout ------------------------------------------------------------------------
	const EDGE_MARGIN := 16.0             # gap from the screen edge (top + sides)
	const ROW_SEP := 6                    # px between currency icon/number pairs
	const LV_ROW_SEP := 7                 # px in the level-chip row

	# --- the cream pill (shared by the currency cluster + the level chip) --------------
	const PILL_BG := Color("#FBF6EC", 0.95)         # soft cream
	const PILL_RADIUS := 40
	const PILL_BORDER_W := 3
	const PILL_BORDER := Color("#C9A66B", 0.9)      # warm gold (matches the ask pills)
	const PILL_SHADOW := Color(0, 0, 0, 0.22)
	const PILL_SHADOW_SIZE := 5
	const CLUSTER_PAD_X := 18.0           # currency pill horizontal content margin
	const PILL_PAD_X := 16.0              # level pill horizontal content margin
	const PILL_PAD_Y := 12.0              # vertical content margin (both pills)

	# --- currency cluster --------------------------------------------------------------
	const STAR_ICON := 44                 # icon px, per currency
	const COIN_ICON := 40
	const GEM_ICON := 38
	const NUM_SIZE := 34                  # currency number font size

	# --- the level chip ----------------------------------------------------------------
	const LV_PX := 48.0                   # the round level "coin" diameter
	const LV_TOKEN_BG := Color("#3F6B43") # deep leaf — growth, contrasts the cream pill
	const LV_TOKEN_BORDER := Color("#C9A66B")  # warm gold ring
	const LV_NUM_SIZE := 26               # the level number inside the token
	const XP_SIZE := 28                   # the exp fraction to its right
	const XP_INK_ALPHA := 0.85            # xp text = Color(INK, this)


class UiSkin:                             # NOT "Skin" — that's a native Godot class
	# --- background --------------------------------------------------------------------
	const BG_SCRIM_ALPHA := 0.5           # default dark scrim over a background image

	# --- the coin marker (code-drawn fallback) -----------------------------------------
	const COIN_PX := 34.0                 # default coin diameter
	const COIN_BORDER_W := 3

	# --- the kit: panel surfaces (plank / chip / parchment) ----------------------------
	const KIT_TEX_MARGIN := 96.0          # nine-patch texture margin (512 source)
	const PLANK_PAD_X := 18.0
	const PLANK_PAD_Y := 14.0
	const PLANK_ALPHA := 0.94             # flat-fallback bg = Color(Pal.PLANK, this)
	const PLANK_RADIUS := 18
	const PLANK_BORDER_W := 4
	const CHIP_PAD_X := 16.0
	const CHIP_PAD_Y := 6.0
	const CHIP_ALPHA := 0.62              # flat chip bg = Color(Pal.INK, this)
	const CHIP_RADIUS := 20
	const PARCH_PAD_X := 26.0
	const PARCH_PAD_T := 20.0
	const PARCH_PAD_B := 22.0             # parchment is bottom-heavy
	const PARCH_RADIUS := 26
	const PARCH_BORDER_W := 5
	const PARCH_SHADOW := Color(0, 0, 0, 0.3)
	const PARCH_SHADOW_SIZE := 8
	const PARCH_SHADOW_OFFSET := Vector2(0, 5)

	# --- icons & stat chip -------------------------------------------------------------
	const ICON_PX := 28.0                 # default icon size (glyph or sprite)
	const CHIP_ROW_SEP := 6               # icon↔number separation in a stat chip
	const STAT_NUM_SIZE := 34

	# --- title ribbon ------------------------------------------------------------------
	const TITLE_SIZE := 32                # default title font size
	const TITLE_BG_ALPHA := 0.96          # bg = Color(Pal.PILL, this)
	const TITLE_RADIUS := 20
	const TITLE_BORDER_W := 3
	const TITLE_EDGE_ALPHA := 0.9         # border = Color(Pal.PILL_EDGE, this)
	const TITLE_SHADOW := Color(0, 0, 0, 0.22)
	const TITLE_SHADOW_SIZE := 5
	const TITLE_PAD_X := 30.0
	const TITLE_PAD_T := 7.0
	const TITLE_PAD_B := 9.0

	# --- press juice (every button) ----------------------------------------------------
	const PRESS_DOWN_SCALE := Vector2(0.96, 0.96)
	const PRESS_DOWN_T := 0.05
	const PRESS_UP_SCALE := Vector2(1.03, 1.03)
	const PRESS_UP_T := 0.05
	const PRESS_SETTLE_T := 0.04

	# --- buttons -----------------------------------------------------------------------
	const BTN_MIN_SIZE := Vector2(190, 88)
	const BTN_SIZE := 32                  # label font size
	const BTN_RADIUS := 28
	const BTN_BORDER_W := 3
	const BTN_PILL_ALPHA := 0.97          # secondary bg = Color(Pal.PILL, this)
	const BTN_EDGE_ALPHA := 0.9           # secondary border = Color(Pal.PILL_EDGE, this)
	const BTN_SHADOW := Color(0, 0, 0, 0.3)
	const BTN_SHADOW_SIZE := 5
	const BTN_SHADOW_OFFSET := Vector2(0, 3)
	const BTN_PAD_X := 30.0
	const BTN_PAD_T := 12.0
	const BTN_PAD_B := 14.0
	const BTN_PRESS_DARKEN := 0.1         # pressed bg = normal.darkened(this)
	const BTN_PRESS_SHADOW_SIZE := 2
	const BTN_PRESS_SHADOW_OFFSET := Vector2(0, 1)


class Music:
	const VOLUME_DB := -8.0               # the ambient bed's playback level


class Shop:
	# --- overlay / card ----------------------------------------------------------------
	const VEIL_ALPHA := 0.6               # dim behind the storefront = Color(INK, this)
	const CONFIRM_VEIL_ALPHA := 0.5       # ...and behind the cash confirm
	const COL_SEP := 12                   # storefront column spacing
	const CONFIRM_COL_SEP := 14
	const CARD_MAX_W := 920.0             # storefront card width cap
	const CARD_VW_FRAC := 0.86            # ...else this fraction of the viewport
	const SECTION_PAD := 6                # the wallet/foot breathing-room spacers

	# --- header / title ----------------------------------------------------------------
	const HEADER_H := 140                 # the stall banner band height
	const TITLE_SIZE := 40                # storefront title font
	const CONFIRM_TITLE_SIZE := 32        # confirm dialog title font
	const RIBBON_TOP := 4.0               # title chip inset from the band top

	# --- rows --------------------------------------------------------------------------
	const ROW_SEP := 14                   # wallet / help / gem-card rows
	const DIV_SEP := 10                   # divider row (tab ↔ vine)
	const WHAT_SEP := 8                   # confirm "icon + amount" row
	const BTNS_SEP := 16                  # confirm button row

	# --- the close (✕) button ----------------------------------------------------------
	const X_BTN := 64.0                   # round close button size
	const X_FONT := 30
	const X_MARGIN := 12.0                # inset from the card's top-right corner
	const X_TEX_MARGIN := 24.0            # nine-patch margin when art exists
	const X_RADIUS := 32
	const X_BORDER_W := 3
	const X_BG := Color("#6E4B2F")        # fallback brown disc
	const X_BG_PRESSED := Color("#5A3D26")
	const X_EDGE := Color("#3D2A1B")

	# --- divider tab + vine ------------------------------------------------------------
	const TAB_BG := Color("#E8D9BC")
	const TAB_RADIUS := 12
	const TAB_BORDER_W := 2
	const TAB_EDGE_ALPHA := 0.45          # border = Color(BARK, this)
	const TAB_PAD_X := 12.0
	const TAB_PAD_T := 3.0
	const TAB_PAD_B := 4.0
	const DIV_CAP_SIZE := 23
	const DIV_CAP_INK_ALPHA := 0.9        # caption = Color(INK, this)
	const VINE_H := 26                    # divider vine art height
	const LINE_H := 3                     # ...else a flat rule this tall
	const LINE_ALPHA := 0.35              # rule = Color(BARK, this)

	# --- help card ---------------------------------------------------------------------
	const HELP_CARD := Vector2(330, 232)
	const CARD_INNER_SEP := 4             # inner VBox spacing (help + gem cards)
	const HELP_ICON := 56.0
	const HELP_TITLE_SIZE := 27
	const HELP_CAP_SIZE := 20
	const HELP_CAP_BARK_ALPHA := 0.8      # caption = Color(BARK, this)
	const HELP_PRICE_SIZE := 26           # gem price chip number

	# --- featured offer cards (T40: item-shortcuts + cosmetics) -------------------------
	# Reuse the help-card frame (HELP_CARD / HELP_* fonts); the cosmetic swatch is a tint chip.
	const SWATCH_SIZE := 56.0             # the cosmetic look-preview swatch
	const SWATCH_RADIUS := 14
	const SWATCH_BORDER_W := 2

	# --- gem (cash pack) card ----------------------------------------------------------
	const GEM_CARD := Vector2(206, 312)
	const POP_RADIUS := 10                # "Popular" badge
	const POP_PAD_X := 10.0
	const POP_PAD_Y := 2.0
	const POP_SIZE := 18
	const GEM_ICON := 64.0
	const GEM_COUNT_SIZE := 40
	const GEM_PRICE_BG := Color("#5A3F28", 0.94)
	const GEM_PRICE_RADIUS := 18
	const GEM_PRICE_BORDER_W := 2
	const GEM_PRICE_EDGE := Color("#3D2A1B")
	const GEM_PRICE_PAD_X := 14.0
	const GEM_PRICE_PAD_T := 5.0
	const GEM_PRICE_PAD_B := 6.0
	const GEM_PRICE_SIZE := 26

	# --- the card button (both card kinds) ---------------------------------------------
	const CARD_BG := Color("#F4E9D6")
	const CARD_BG_PRESSED := Color("#EADCC2")
	const CARD_RADIUS := 20
	const CARD_BORDER_W := 3
	const CARD_EDGE_ALPHA := 0.55         # border = Color(BARK, this)
	const CARD_SHADOW := Color(0, 0, 0, 0.18)
	const CARD_SHADOW_SIZE := 4
	const CARD_SHADOW_OFFSET := Vector2(0, 3)

	# --- affordability + purchase feedback ---------------------------------------------
	const DIM_MODULATE := Color(0.72, 0.73, 0.7, 0.92)   # can't-afford card tint
	const NEED_OFFSET := Vector2(100, 70)  # "Need N more" floater offset
	const NEED_SIZE := 28
	const FLY_ICON := 32.0                # the grant icon that arcs to the wallet
	const SCATTER_DELAY := 0.08           # storefront row scatter-in base delay

	# --- cash confirm ------------------------------------------------------------------
	const CONFIRM_GEM_ICON := 36.0
	const CONFIRM_AMOUNT_SIZE := 34
	const CONFIRM_NOTE_SIZE := 22
