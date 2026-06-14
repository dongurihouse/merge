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
const GROUND := Color("#3F6B43")
const GROUND_EDGE := Color("#33402F")
const BRAMBLE_BG := Color("#4A5A3A")
const BRAMBLE_EDGE := Color("#33402F")

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
