extends RefCounted
## GROVE palette — the game's colours (skin). The engine reads these via
## Config.PALETTE instead of hardcoding/duplicating them across scripts.
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
