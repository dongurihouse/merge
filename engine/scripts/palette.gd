extends RefCounted
## Tidy Up — one shared cozy palette + item-art registry (preloaded by UI scripts).
## Keep all colors here so the menu, board, and finish screen stay consistent.

const BG := Color("#241E2E")          # cozy night background
const BG_DEEP := Color("#17121E")     # finish-screen veil
const SLOT := Color("#332A3D")        # empty board cell
const SLOT_WALL := Color("#4A3E57")   # fixed fixture
const SURFACE := Color("#3A3047")     # panels / tiles behind art
const TEXT := Color("#FBF3EA")        # warm cream
const TEXT_MUTED := Color("#A99FB5")
const ACCENT := Color("#FFB877")      # warm peach — primary CTA / logo
const ACCENT_2 := Color("#8AE0C8")    # calm mint
const GOLD := Color("#FFD56B")        # stars / sparkles / "tidy!" pop
const GOOD := Color("#7FE0A0")        # legal-merge highlight
const COOL := Color("#7FB4FF")        # reachable-cell highlight

# UI art (optional — auto-used if present, else flat-color fallback)
const UI_BG := "res://assets/ui/bg_bedroom.png"    # full-bleed room background (not generated; board stays clean)
const UI_TRAY := "res://assets/ui/board_tray.png"  # rug/basket behind the pockets
const UI_SLOT := "res://assets/ui/tile_slot.png"   # a single cozy pocket / cubby
const UI_LOGO := "res://assets/ui/logo_tidyup.png"
const UI_BTN_PLAY := "res://assets/ui/btn_play.png"
const FX_SPARKLE := "res://assets/fx/fx_sparkle.png"
const FX_GLOW := "res://assets/fx/fx_glow.png"
const ROOM_TIDY := "res://assets/rooms/bedroom_tidy.png"   # ambient backdrop (skin.gd)

# Placeholder tier tints (used only until item art is dropped in).
const TIER_TINTS := [
	Color("#7FB4FF"), Color("#7FE0A0"), Color("#C79BFF"), Color("#FF9DBB"), Color("#FFD56B"),
]

# Clutter families (bedroom). Art: res://assets/items/<base>_<tier>.png
const FAMILIES := {
	1: {"name": "Clothes", "base": "clothes"},
	2: {"name": "Books", "base": "books"},
	3: {"name": "Toys", "base": "toys"},
}

static func tier_color(t: int) -> Color:
	return TIER_TINTS[clampi(t - 1, 0, TIER_TINTS.size() - 1)]

static func item_tex_path(code: int) -> String:
	var fam := floori(code / 100.0)
	var tier := code % 100
	if not FAMILIES.has(fam):
		return ""
	return "res://assets/items/%s_%d.png" % [FAMILIES[fam].base, tier]
