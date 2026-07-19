extends RefCounted
## SINGLE SOURCE OF TRUTH for the home screen's bakeable chrome art — the bottom nav, the live-ops rail,
## the place-picker back button, and the orange Play disc. BOTH the renderer (engine/scripts/scenes/map.gd)
## and the texture bake (games/tools/bake_targets.gd) read these ids, so a chrome icon is declared ONCE:
## adding it here bakes it (bake_targets iterates BAKE_ICONS) AND map.gd renders it from the same name — no
## second list to drift out of sync.
##
## If something is added to map.gd but NOT here, its sprite polishes live on boot instead of loading
## from the bake — watch for the live-polish log line when adding chrome.

# Named ids the renderer references at its specific call sites (keeps map.gd's chrome builders literal-free).
const ICON_MAP := "map"             # bottom-nav Map badge → the place-picker
const ICON_RESIDENTS := "house"     # bottom-nav Residents badge → the resident roster shop (residence → residents)
const ICON_EXPEDITION := "expedition"  # side-rail Expedition badge → cozy map/compass shared icon
const ICON_PLAY := "board"          # the merged Play CTA, default face (taps into the board)
const ICON_PLAY_RESTORE := "vine"   # the Play CTA's restore-ready face (swapped in when a spot is affordable)
const ICON_DAILY := "daily"         # live-ops rail: Meadow daily-login icon
const ICON_VAULT := "vault"         # live-ops rail: Meadow vault icon
const ICON_INBOX := "mail"          # live-ops rail: the inbox
const ICON_SETTINGS := "settings"   # HUD top-right Meadow settings icon

const PLAY_SHELL := "shared/play_disc.png"    # the orange Play disc shell (NOT the default cream disc)
const BACK_ICON_REL := "map/back_arrow.png"   # the place-picker back arrow (kit-relative, not an icon_<id>)

# The COMPLETE set of home-surface icon ids that home_button polishes via clean_tex_path — the bake iterates
# this. Beyond the nav/rail named above it carries the HUD/shop affordance icons that also ride the home.
const BAKE_ICONS: Array = [
	ICON_MAP, ICON_RESIDENTS, ICON_EXPEDITION, ICON_PLAY, ICON_PLAY_RESTORE, ICON_DAILY, ICON_VAULT, ICON_INBOX, ICON_SETTINGS,
	"shop", "piggy", "gift", "faucet",
]
