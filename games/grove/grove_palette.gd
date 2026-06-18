extends RefCounted
## GROVE palette — the game's colours (skin). The engine reads these via
## Game.PALETTE instead of hardcoding/duplicating them across scripts.
## A different game ships its own palette with the same const names.

# the grove's themed colours (were scattered as local consts in grove/home/shop/hud)
const CREAM := Color("#FBF3EA")
const STRAW := Color("#E3B23C")
const INK := Color("#33402F")
const BARK := Color("#8A5A3B")
const SKY := Color("#9CCDE8")
const MEADOW := Color("#7FA65A")
const LEAF := Color("#3F6B43")
const CLAY := Color("#C96F4A")
const GROUND := Color("#D9DCC4")        # was olive #3F6B43 — now the sage SURFACE (UI redesign P1)
const GROUND_EDGE := Color("#C3C8AC")   # was #33402F — now SURFACE_FRAME
const BRAMBLE_BG := Color("#C2C7A6")    # was olive #4A5A3A — now the recessive LOCKED tone
const BRAMBLE_EDGE := Color("#B4B996")  # was #33402F — a muted edge so locked recedes

# chrome colours the shared UI/fx use (were in the old palette.gd)
const BG := Color("#241E2E")
const BG_DEEP := Color("#17121E")
const TEXT := Color("#FBF3EA")
const TEXT_MUTED := Color("#A99FB5")
const GOLD := Color("#FFD56B")

# UI-kit fallback chrome (were inline in skin.gd's StyleBox fallbacks)
const COIN_EDGE := Color("#C98A2B")        # coin-icon rim
const PLANK := Color("#6E4B2F")            # wooden plank panel
const PLANK_EDGE := Color("#3D2A1B")
const PILL := Color("#FBF6EC")             # cream pill (HUD/ribbon language)
const PILL_EDGE := Color("#C9A66B")
const BTN_PRIMARY := Color("#4E7C46")      # primary button (leaf green)
const BTN_PRIMARY_EDGE := Color("#3C6037")

# --- UI redesign (2026-06-17): semantic role tiers --------------------------------
# Spec: docs/superpowers/specs/2026-06-17-ui-language-redesign-design.md
# Surface = the neutral stage; Locked recedes below it; accents are reserved for meaning.
const SCREEN_BG := Color("#EFE7D5")        # warm cream chrome that frames the cooler board
const SURFACE := Color("#D9DCC4")          # cool-sage board field (the play stage)
const SURFACE_FRAME := Color("#C3C8AC")    # board border
const CELL_EMPTY := Color("#CFD3B6")       # an empty playable cell (inset on the surface)
const LOCKED := Color("#C2C7A6")           # sealed/locked cell — desaturated, recedes (Sunk plane)
const LOCKED_GLYPH := Color("#8F977A")     # the small low-contrast lock icon
const NEAR_UNLOCK := Color("#CDD3B0")      # a cell one merge from opening
const NEAR_HINT := Color("#8FAE6E")        # its faint green anticipation edge
const CARD_PEDESTAL := Color("#F2EFDC")    # pale disc under items in CARDS (orders/shop) — NOT the board
const INK_MUTED := Color("#7A7558")        # muted ink (INK already exists above)
# Accents — reserved, meaning only. Aliased to the established chrome colours.
const ACCENT_CTA := BTN_PRIMARY            # primary action / growth (leaf green #4E7C46)
const ACCENT_REWARD := STRAW               # reward / value (honey gold #E3B23C)
const ACCENT_ALERT := Color("#E24B4A")     # alert / new
const ACCENT_INFO := Color("#5FA8D8")      # info
