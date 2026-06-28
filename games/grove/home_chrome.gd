extends RefCounted
## SINGLE SOURCE OF TRUTH for the home screen's bakeable chrome art — the bottom nav, the live-ops rail,
## the place-picker back button, and the orange Play disc. BOTH the renderer (engine/scripts/scenes/map.gd)
## and the texture bake (games/tools/bake_targets.gd) read these ids, so a chrome icon is declared ONCE:
## adding it here bakes it (bake_targets iterates BAKE_ICONS) AND map.gd renders it from the same name — no
## second list to drift out of sync.
##
## The backstop if something is added to map.gd but NOT here: grove_vine_tests._test_boot_does_zero_live_work
## builds the real home and fails loudly, naming any sprite that polished live on boot because it wasn't baked.

# Named ids the renderer references at its specific call sites (keeps map.gd's chrome builders literal-free).
const ICON_MAP := "map"             # bottom-nav Map badge → the place-picker
const ICON_RESIDENTS := "house"     # bottom-nav Residents badge → the resident roster shop (residence → residents)
const ICON_EXPEDITION := "1512"     # side-rail Expedition badge → rendered through the item/icon-node path
const ICON_PLAY := "board"          # the merged Play CTA, default face (taps into the board)
const ICON_PLAY_RESTORE := "vine"   # the Play CTA's restore-ready face (swapped in when a spot is affordable)
const ICON_DAILY := "calendar"      # live-ops rail: the daily-login calendar
const ICON_VAULT := "chest"         # live-ops rail: the piggy vault
const ICON_INBOX := "mail"          # live-ops rail: the inbox
const ICON_SETTINGS := "gear"       # HUD top-right settings (also baked in its rect-badge form)

const PLAY_SHELL := "shared/play_disc.png"    # the orange Play disc shell (NOT the default cream disc)
const BACK_ICON_REL := "map/back_arrow.png"   # the place-picker back arrow (kit-relative, not an icon_<id>)

# The COMPLETE set of home-surface icon ids that home_button polishes via clean_tex_path — the bake iterates
# this. Beyond the nav/rail named above it carries the HUD/shop affordance icons that also ride the home.
const BAKE_ICONS: Array = [
	ICON_MAP, ICON_RESIDENTS, ICON_PLAY, ICON_PLAY_RESTORE, ICON_DAILY, ICON_VAULT, ICON_INBOX, ICON_SETTINGS,
	"shop", "piggy", "gift", "faucet",
]
