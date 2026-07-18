extends RefCounted
## GROVE palette — the game's colours (skin). The engine reads these via
## Game.PALETTE instead of hardcoding/duplicating them across scripts.
## A different game ships its own palette with the same const names.

# Fixed Meadow Sky semantic roles. Keep the established constant names because engine UI code reads
# Game.PALETTE through this stable interface; every value is one of the approved production roles.
const CREAM := Color("#F6EBDD")
const STRAW := Color("#D6A94C")
const INK := Color("#243B4B")
const BARK := Color("#3F6D7D")
const SKY := Color("#6FA9C0")
const MEADOW := Color("#A8D3B9")
const LEAF := Color("#5F9B6D")
const CLAY := Color("#D87865")
const GROUND := CREAM
const GROUND_EDGE := BARK
const BRAMBLE_BG := Color("#8296AF")
const BRAMBLE_EDGE := BARK

# chrome colours the shared UI/fx use (were in the old palette.gd)
const BG := SKY
const BG_DEEP := BARK
const TEXT := CREAM
const TEXT_MUTED := BRAMBLE_BG
const GOLD := STRAW

# UI-kit fallback chrome (were inline in skin.gd's StyleBox fallbacks)
const COIN_EDGE := BARK
const PLANK := BARK
const PLANK_EDGE := INK
const PILL := CREAM
const PILL_EDGE := BARK
const BTN_PRIMARY := LEAF
const BTN_PRIMARY_EDGE := BARK

# --- UI redesign (2026-06-17): semantic role tiers --------------------------------
# Spec: docs/superpowers/specs/2026-06-17-ui-language-redesign-design.md
# Surface = the neutral stage; Locked recedes below it; accents are reserved for meaning.
const SCREEN_BG := SKY
const SURFACE := CREAM
const SURFACE_FRAME := BARK
const CELL_EMPTY := MEADOW
const LOCKED := BRAMBLE_BG
const LOCKED_GLYPH := BARK
const NEAR_UNLOCK := SKY
const NEAR_HINT := LEAF
const CARD_PEDESTAL := CREAM
const INK_MUTED := BARK
# Accents — reserved, meaning only. Aliased to the established chrome colours.
const ACCENT_CTA := BTN_PRIMARY
const ACCENT_REWARD := STRAW
const ACCENT_ALERT := CLAY
const ACCENT_INFO := SKY
