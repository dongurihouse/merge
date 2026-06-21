@tool
extends Control
## UI Workbench — gallery + inspector sidebar.
##
## `make workbench` opens this. The left column is a scroll of the fundamental components, built
## bottom-up from the self-contained kit (cost pill → mail card → mail dialog). CLICK an element to
## select it; the right SIDEBAR then shows that element's own options/sliders. Changing a slider
## rebuilds just that element — and because the components compose, a dialog's pill size still flows
## down into every row.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")   # kit-relative art paths (Look.kit) for the polish source
const GiverStand = preload("res://engine/scripts/ui/giver_stand.gd")   # the quest-giver card builder (board reskin)
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")     # merge pieces for the Board preview
const Pal = Game.PALETTE
# Demo merge pieces for the Board preview — [row, col, item code]; cells outside the grid are skipped.
const BOARD_DEMO := [[1, 1, 101], [1, 2, 101], [2, 3, 102], [3, 2, 103], [4, 4, 102], [5, 1, 104], [6, 5, 101], [2, 5, 103]]
const SETTINGS := "res://games/grove/tools/ui_workbench_settings.json"   # persisted params (in the repo)
const PHONE_W := 1080.0   # the project's portrait base width; dialog widths are a % of it (and of the live
                          # screen in-game), so the workbench previews the same responsive width the game uses

const IDS := ["board", "button", "home_button", "home_unlock_button", "icon", "badge", "progress_bar", "card", "daily_card", "toggle_card", "bag_card", "map_card", "quest_card", "frame", "dialog", "daily", "shop", "level", "tiers", "currency_pill", "info_bar", "settings", "vault", "bag"]
# Gallery layout: TWO side-by-side COLUMNS. The LEFT column is the building-block components, ALWAYS ONE
# element per row (each on its own line). The RIGHT column stacks every DIALOG in a single column. Each
# column is a list of ROWS; a row CAN hold side-by-side elements (the right column may), but the left
# column never pairs — one per row. Splitting dialogs into their own column keeps them grouped and balances
# the gallery's height (the tall dialogs no longer each span a full-width row).
const COLUMNS := [
	# the building blocks — one element per row (the HUD currency pill lives here too, as a reusable atom).
	# the Board preview leads the column — the live merge grid you size with the scale / item-width knobs.
	[["board"], ["home_button"], ["home_unlock_button"], ["button"], ["icon"], ["badge"], ["card"], ["daily_card"], ["toggle_card"], ["bag_card"], ["map_card"], ["quest_card"], ["currency_pill"], ["info_bar"], ["frame"], ["progress_bar"]],
	[["dialog"], ["daily"], ["shop"], ["level"], ["tiers"], ["settings"], ["vault"], ["bag"]],   # dialogs, settings, vault, bag
]
# Editing element X must also refresh the elements that COMPOSE from it (derived from the kit's
# opts-builders): the Button's style flows into every Claim/cost pill; the shared Frame + the small
# cards flow into the dialogs; the Badge's polish flows into the Home button. Editing anything else
# (a dialog's own width, the icon sandbox, the pill, …) touches only itself. Used to rebuild just the
# edited element + its dependents instead of the whole gallery.
const DEPENDENTS := {
	"button": ["card", "dialog", "daily", "shop", "settings"],
	"card": ["dialog", "daily", "shop", "settings"],
	"frame": ["dialog", "daily", "shop", "settings", "bag", "tiers"],
	"daily_card": ["daily", "shop"],
	"toggle_card": ["settings"],
	"badge": ["home_button"],
	# the slot cell backs the bag dialog, the discovery ladder (inherits its look), AND the Board preview's wells — editing it rebuilds all
	"bag_card": ["bag", "tiers", "board"],
	"currency_pill": ["bag", "info_bar"],   # the info bar borrows the pill's capsule frame
}
# Badge backgrounds live in the kit now (Kit.BADGES) so the game resolves them from the same map.
# Icons the button can show (all resolve via the kit's _icon_tex); "none" = no icon.
const ICONS := ["none", "coin", "gem", "bluegem", "water", "leaf", "gift", "star", "daisy", "faucet", "rain", "news", "mail"]
# Icons the HOME button can show (the home page's rail + nav set; all resolve via the kit's _icon_tex).
const HOME_ICONS := ["gear", "shop", "map", "piggy", "gift", "faucet", "mail", "daisy", "leaf"]
# Currencies the HOME-UNLOCK disc can show as its cost (the spend the spot wants; the game passes "star").
const UNLOCK_ICONS := ["star", "coin", "gem", "daisy", "leaf", "water"]
# Each element's params split into two buckets: anything listed here is TEST-ONLY scaffolding (sample
# content, preview counts, tool helpers) and is NOT written to / read from the config file; everything
# else is real design config that IS persisted. The sidebar mirrors this split under two headers.
#   button — icon/size/enabled are just to eyeball the shape; the REAL claim icon lives on the Card.
#   icon   — the whole element is a polish-tuning sandbox (the shipped recipe is fixed in the kit).
#   dialog — entries is a preview count, snap is the drag grid.
const TEST_KEYS := {
	# the BOARD preview — the size knobs (scale / cell / item / gap / frame / cols / rows) are the saved
	# design; `pieces` just toggles the demo merge pieces in the preview.
	"board": ["pieces"],
	# the Button is a shared-STYLE sandbox: only shadow / use-art / font are real config. Its text, bg,
	# icon, badge, corner are test props — the REAL text/badge/icon for the game live on the Card.
	"button": ["text", "bg", "icon", "icon_size", "enabled", "corner", "badge"],
	# the HOME button is a shared-STYLE sandbox: size / icon scale / caption look / badge offset / SPARKLE
	# persist. The previewed icon, caption text, sparkle toggle + sample badge count are test props.
	"home_button": ["icon", "caption", "sparkle", "badge_count", "count"],
	# the HOME-UNLOCK disc is a shared-STYLE sandbox: disc size + the inner proportions persist. The
	# previewed cost number + currency icon are test props — the map sets each spot's real cost + "star".
	"home_unlock_button": ["cost", "icon", "sparkle"],
	"icon": ["defringe", "feather", "supersample", "shadow"],
	"progress_bar": ["frac"],              # frac is a preview slider; height/art/star_knob are the saved style
	"badge": [],                           # the disc-shell polish is SAVED — the home button reads it
	"card": [],
	"daily_card": ["preview", "ribbon", "sparkle"],   # preview/ribbon view toggles; sparkle is NOT saved (always on in-game)
	"frame": ["snap"],                     # snap is the drag-grid helper, not a saved design value
	"dialog": ["entries"],
	"daily": [],
	"shop": [],
	"level": ["preview_level", "into", "span", "mode"],   # preview state (level / progress / which mode)
	"tiers": [],
	# the currency pill — the STYLE (art / padding / border / font / icon box / gaps) persists; the
	# ★/🪙/💎 counts are preview-only (the live wallet shows the player's real balances).
	"currency_pill": ["star", "coin", "gem"],
	# the bottom-bar INFO BAR — the LAYOUT (height · inner scale · fonts · separation · sell button) persists;
	# the FRAME is the shared currency-pill capsule (tune it on that element). `filled` just previews the
	# selected-vs-empty state (the game fills it from the tapped board item).
	"info_bar": ["filled"],
	"toggle_card": ["label", "value"],   # sample row content (label + on/off) — preview only, not saved
	# the map-select place-picker card — the STYLE (art · frame inset · art radius · pill metrics · §8
	# veil look) persists; open/done/stars_left just preview the card (the game sets each from map state).
	"map_card": ["open", "done", "stars_left"],
	# the quest-giver card — the LAYOUT block (card/bust/bubble/item/plaque fractions) IS saved config now:
	# the board reads it via Kit.giver_lay_from_config, so a tweak here flows to the live giver card. Only
	# the DEMO knobs are test-only (which bust, the asked tier/reward, the board-given size, the ready ✓).
	"quest_card": ["bust", "tier", "stars", "stand_w", "fence_h", "met"],
	"settings": [],
	"vault": ["balance", "claimable"],   # the previewed gem read + the claimable gate — preview only
	# the bag CELL — the cell STYLE persists; `preview` just picks which state (filled/empty/next/locked) to show.
	"bag_card": ["preview", "level", "cost"],
	# the bag DIALOG — grid/caption persist; balance/owned/filled just preview the slot ladder (the game
	# sets each from save: the 💎 balance, how many slots owned, how many hold a piece).
	"bag": ["balance", "owned", "filled"],
}
const CAPTIONS := {
	"board": "Board — merge grid (frame · cells · pieces · scale + item width)",
	"button": "Button — shared (bg · icon · state)",
	"home_button": "Home button — rail + nav (shell · icon · sparkle)",
	"home_unlock_button": "Home unlock — restore-cost disc (+ · ★ N)",
	"icon": "Icon — edge polish (raw vs cleaned)",
	"badge": "Badge — disc shell (raw vs polished)",
	"progress_bar": "Progress bar — track + fill (reusable)",
	"card": "Mail card — pill + Claim",
	"daily_card": "Daily card — one day (badges)",
	"bag_card": "Slot cell — bag · board · discovery (empty · filled · unlockable · locked)",
	"toggle_card": "Toggle card — label + switch",
	"map_card": "Map card — place-picker (gold frame / locked panel)",
	"quest_card": "Quest card — giver (portrait · ask · plaque reward)",
	"frame": "Dialog frame — shared chrome",
	"dialog": "Mail dialog — cards",
	"daily": "Daily — day grid (shared frame)",
	"shop": "Shop — packs (shared frame)",
	"level": "Level — dialog (medallion · bar · collect)",
	"tiers": "Discovery — tier ladder (shared frame, no vines)",
	"currency_pill": "Currency pill — top-bar wallet (★ 🪙 💎)",
	"info_bar": "Info bar — board bottom bar (ⓘ · selected piece + name · sell)",
	"settings": "Settings — toggles (shared frame)",
	"vault": "Vault — piggy bank (twig border)",
	"bag": "Bag — slot grid (shared frame · acorn pill)",
}
var _params := {
	# the BOARD preview — a live merge grid (bamboo frame · the shared slot-cell well · demo pieces). Two
	# INDEPENDENT size knobs: `scale` zooms the whole composition (frame + cells together, in %); `cell` is
	# the item width in px (the grid grows, the frame thickness stays), so you trade item size vs frame weight.
	# `item` = the piece sprite size as a % of its cell; gap/frame/cols/rows shape the grid. Preview only.
	"board": {"scale": 100, "cell": 52, "gap": 7, "cols": 7, "rows": 9, "frame": 60, "item": 68, "pieces": true},
	"button": {"text": "Claim", "bg": "green", "icon": "none", "icon_size": 30, "enabled": true, "font": 22, "corner": 16, "art": true, "shadow": false, "badge": "auto"},
	# the HOME button — the round icon button shared by the side rail + bottom nav. px / icon_scale /
	# caption_font / caption_gap / glow / twinkle are the saved STYLE; icon / caption / sparkle preview it.
	# Its disc shell's polish lives on the standalone Badge item; its icon uses the global icon clean.
	"home_button": {"px": 140, "icon_scale": 50, "caption_font": 22, "caption_gap": 4, "caption_pad_x": 30, "caption_pad_y": 8,
		"badge_dx": -26, "badge_dy": -26, "glow": 45, "twinkle": 55,
		"count_dx": 0, "count_dy": 38, "count_font": 26,
		"icon": "gift", "caption": "Daily", "sparkle": true, "badge_count": 3, "count": "1/6"},
	# the HOME-UNLOCK disc — the restore-cost badge on an unowned home spot. disc_pct is the diameter as a
	# % of the MAP width (the game multiplies it by the live map width; the preview uses the 1080 base, so
	# it shows the EXACT in-game size). plus/icon/cost + the two gaps are % of the disc, so all scales with
	# it. cost + icon are preview-only — the map passes each spot's real cost + the "star" spend currency.
	"home_unlock_button": {"disc_pct": 16, "plus_scale": 30, "icon_scale": 26, "cost_font": 26, "stack_gap": -1, "icon_gap": 2,
		"glow": 0, "twinkle": 0, "gray_unaffordable": true, "cost": 4, "icon": "star", "sparkle": true, "afford": true},
	"icon": {"defringe": false, "feather": 1, "supersample": 1, "shadow": false},
	# the BADGE — the home button's disc shell, extracted as its own polish sandbox (defringe / shadow /
	# feather, like the Icon item). SAVED, and the home button reads it so a tweak flows to the rail + nav.
	"badge": {"defringe": false, "shadow": false, "feather": 0},
	# the reusable PROGRESS BAR — its own building-block component (track + honey fill). height / art /
	# star_knob are the saved style; frac is a preview-only fill slider. The Level dialog reads this style.
	"progress_bar": {"height": 20, "art": true, "star_knob": false, "frac": 50},
	"card": {"title": 20, "body": 15, "badge": "auto", "icon_badge": "disc light", "claim_text": "Claim", "icon_on": false, "icon": "gem"},
	# the shared FRAME is its OWN standalone component (banner · card border/art · ✕ · scroll/list ·
	# padding). EVERY dialog reuses it. width here is just for the frame's own preview; each dialog
	# carries its own width. snap is the drag-grid for the banner/✕ handles.
	"frame": {
		"width": 560, "border": "parchment", "card_corner": 22, "card_art": true,
		"card_slice_l": 40, "card_slice_t": 40, "card_slice_r": 40, "card_slice_b": 40,
		"card_h_stretch": "stretch", "card_v_stretch": "stretch",
		"banner_font": 32, "banner_h": 92, "banner_icon": 54, "banner_icon_on": true,
		"banner_text_x": 0, "banner_text_y": 0, "banner_burn": 60,
		"banner_x": 0, "banner_y": 0,
		"banner_icon_x": 130, "banner_icon_y": 19,
		"close_size": 64, "close_x": 12, "close_y": 12, "snap": 8,
		"list_max_h": 0, "list_top_pad": 0,
	},
	# the mail DIALOG = the shared frame + the mail cards. width_pct = the dialog's width as a % of the
	# SCREEN (responsive — the game multiplies by the live viewport width; here it previews against the
	# 1080 portrait base). entries = the preview count.
	"dialog": {"width_pct": 85, "entries": 4},
	# the small CARD is its own component, shared by daily + shop (cell size, highlight badges, and a
	# preview state/ribbon for trying it as a shop pack). preview + ribbon are workbench-only view toggles.
	"daily_card": {"preview": "today", "ribbon": "", "cell_w": 96, "cell_h": 116, "cell_slice": 28,
		"cell_art": true, "today_badge": "gold glow", "milestone_badge": "amber glow", "sparkle": true,
		"label_y": 12, "label_x": 0, "claim_y": 14, "info_icon": false,
		"ribbon_scale": 100, "ribbon_x": 0, "ribbon_y": -10},
	# the TOGGLE CARD — a new card type: one setting row (a label + the shared switch). label_font /
	# switch_h / card_art are the saved STYLE; label + value just preview the row. Reused by Settings.
	"toggle_card": {"label_font": 28, "switch_h": 44, "card_art": true, "label": "Music", "value": false},
	# the MAP-SELECT place-picker card (spec §8). Defaults mirror the shipped §8 constants, so the saved
	# block the game's map.gd reads renders the SHIPPED card until you change it. Insets/fracs are scaled
	# integers for the sliders (inset/radius in thousandths, fracs + veil alphas in percent — see
	# Kit.map_card_opts_from_config). open/done/stars_left are preview-only (the game sets each per map).
	"map_card": {"use_art": true, "edge_sparkle": 60,
		"pill_w_frac": 30, "pill_min": 170, "pill_max": 290, "pill_y_frac": 13,
		"veil_scrim": 42, "veil_deep": 66, "veil_mark_alpha": 16, "veil_mark_size": 64,
		"open": true, "done": false, "stars_left": 3},
	# the QUEST-GIVER card (giver_stand.gd) — the painted board_asset box (bubble baked into the right) +
	# the live portrait (left) / item-in-bubble (right) / hung wooden plaque the board draws on it. The
	# LAYOUT fractions (card/bust/bubble/item/plaque) ARE saved and the board reads them (giver_lay_from_config).
	# The DEMO knobs only preview: bust picks which of giver_0..15 sits on the left; tier is the asked item's
	# tier (the demo item is the Wildflower line); stars is the plaque reward; stand_w/fence_h preview the
	# board's size; met toggles the ready ✓.
	"quest_card": {"bust": 1, "tier": 3, "stars": 25, "stand_w": 480, "fence_h": 410, "met": false,
		"card_w": 98, "card_h": 65, "card_slice_l": 46, "card_slice_t": 44, "card_slice_r": 46, "card_slice_b": 56,
		"bust_size": 94, "bust_x": 25, "bust_y": 53,
		"bubble_size": 66, "bubble_x": 72, "bubble_y": 35,
		"item_size": 32, "item_x": 72, "item_y": 32, "plaque_w": 40, "plaque_x": 72, "plaque_y": 81},
	# …the daily DIALOG reuses the shared frame + that card, adding the grid knobs + its OWN scroll cap
	# (list_max_h 0 = no scroll, tall enough for every day; the frame's mail-list cap doesn't apply)…
	"daily": {"width_pct": 85, "cols": 3, "list_max_h": 0},
	# …and the SHOP dialog reuses the SAME frame + the SAME card with bigger cells, its own scroll cap
	# (list_max_h 0 = no scroll, show every item), and the GAME's real items.
	"shop": {"width_pct": 85, "cols": 3, "cell_w": 112, "cell_h": 150, "row_gap": 22, "list_max_h": 0},
	# the LEVEL dialog — its OWN dedicated frame (title pill · ornate border, NOT the shared frame),
	# the medallion (wreath + ring + number), the reusable progress bar, and the Collect/Got-it button.
	# preview_level / into / span / mode are workbench-only preview state; the game sets them from save.
	"level": {"width_pct": 80, "banner_text": "Level", "title_font": 30,
		"frame_slice": 56, "frame_pad": 26, "frame_top_pad": 70,
		"medallion_px": 120, "ring_dy": 0, "tally_font": 28, "hint_font": 22, "btn_font": 22, "gap": 14,
		"preview_level": 1, "into": 0, "span": 6, "mode": "info"},
	# the DISCOVERY dialog — the STANDARD shared frame (border, banner, ✕ — all tuned on the Frame item),
	# wrapping the discovery content: the tier grid (cols, gap, scroll cap) of SHARED slot cells. The tile's
	# piece/medal size + well art are INHERITED from the Slot cell item; only the discovery-specific knobs live
	# here — the square cell size, the tier-number medal, and the marked-tier sparkle (percents for the sliders).
	# The grid fills the frame's inner width, derived from the Frame's chosen border padding.
	"tiers": {"width_pct": 85, "cols": 3, "cell_gap": 16, "list_max_h": 0,
		"cell_w": 150, "cell_h": 150, "show_num": true, "mark_glow": 60, "mark_twinkle": 50},
	# the top-bar CURRENCY PILL (the 💧 🪙 💎 wallet — water replaced the star count). Defaults mirror
	# Tune.Hud, so the saved block the HUD reads renders the SHIPPED pill until you change it. The preview
	# is a single WATER pill with its "+" (the live HUD repeats this capsule for water/coin/gem); plus_gap /
	# plus_dy tune the "+" LOCATION. `water` is a preview-only sample count.
	"currency_pill": {"use_art": true, "border": "gold capsule", "pad_x": 18, "pad_y": 12, "radius": 40, "border_w": 3, "shadow_size": 5,
		"num_size": 34, "icon_box": 40, "row_sep": 4, "pair_sep": 14, "plus_gap": 0, "plus_dy": 0, "plus_size": 26,
		"water": 128},
	# the bottom-bar INFO BAR — the LAYOUT is the saved design; the frame is the shared currency-pill capsule.
	# height matches the Bag/Home wells; inner_scale / sell_icon are % of that height. `filled` previews state.
	"info_bar": {"height": 130, "inner_scale": 48, "name_font": 32, "sep": 10, "sell_font": 30, "sell_icon": 30, "filled": true},
	# the SETTINGS dialog = the shared frame + a column of toggle cards (one per persisted flag). width_pct
	# like every dialog; the toggle-card style lives on the Toggle card item, the chrome on the Frame item.
	"settings": {"width_pct": 80, "row_gap": 12},
	# the VAULT dialog — the shared frame in the NEW twig border + the jar hero. width_pct + the twig
	# slice/pad + the jar/plate sizes are saved; balance/claimable just preview the read. The banner / ✕
	# styling is inherited from the Frame item (like the other dialogs).
	"vault": {"width_pct": 80, "card_slice": 64, "panel_pad_x": 40, "panel_pad_y": 34,
		"jar_px": 200, "plate_px": 250, "balance_font": 34, "row_gap": 12,
		"balance": 320, "claimable": true},
	# the BAG CELL — the slot tile, its own component (the Bag dialog reuses it). cell size/art + the
	# content/lock/cost metrics are saved; `preview` just picks which state the standalone tile shows.
	"bag_card": {"preview": "unlockable", "cell_w": 116, "cell_h": 120, "cell_slice": 28, "cell_art": true,
		"content_frac": 62, "cost_font": 24, "cost_icon": 26, "cost_y": 0, "cost_x": 0, "cost_scale": 100, "level_frac": 44,
		"next_glow": 45, "next_twinkle": 55, "level": 7, "cost": 120},
	# the BAG dialog — the shared frame + the reused currency pill (acorn balance) + a grid of bag cells.
	# width_pct/cols/gaps/caption are saved; balance/owned/filled preview the slot ladder (the game sets
	# each from save). The banner / ✕ styling is inherited from the Frame item (like the other dialogs).
	"bag": {"width_pct": 85, "cols": 6, "cell_gap": 12, "grid_inset": 70, "row_gap": 14, "list_max_h": 0,
		"caption": "Open a slot with acorns.", "balance": 132, "owned": 8, "filled": 5},
}
var _selected := "button"
var _columns: Array = []          # one content VBox per gallery column (each in its OWN scroll)
var _sidebar_body: VBoxContainer = null
var _sections: Dictionary = {}    # id -> the element's gallery section (PanelContainer), for in-place rebuilds
var _dirty: Dictionary = {}       # id -> true: linked elements queued to rebuild, one per frame (coalesced)
var _awaiting: Dictionary = {}    # id -> true: elements showing a raw placeholder until a worker polish lands
var _building := ""               # the id whose section is mid-build (so the polish previews know who to await)

# drag-to-move (banner icon / ✕), with snap-to-grid
var _drag_kind := ""
var _drag_node: Control = null
var _drag_grab := Vector2.ZERO

func _ready() -> void:
	if Engine.is_editor_hint():
		theme = UiFont.make()
	_load_settings()
	_build()

func _build() -> void:
	if not is_inside_tree():
		return
	# Headless editor (`godot --import` / `--export`) instantiates this @tool scene but has no UI to
	# show. Building the gallery there is pointless AND fatal: it kicks off polish_async
	# WorkerThreadPool tasks whose GDScript lambdas are still pending when the import process exits,
	# crashing the pool's destructor at shutdown (SIGSEGV). The interactive workbench, the in-editor
	# @tool, and the headless `-s` tests are NOT editor-hint+headless, so they still build.
	if Engine.is_editor_hint() and DisplayServer.get_name() == "headless":
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()

	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 0)
	add_child(hb)

	# right — the gallery: each COLUMN gets its OWN vertical scroll (both fill the window height), so the
	# tall dialogs column scrolls INDEPENDENTLY of the building-blocks column. The dialog column is a
	# fixed-width panel on the right; the building blocks take the remaining width.
	var gal_row := HBoxContainer.new()
	gal_row.add_theme_constant_override("separation", 0)
	gal_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gal_row.size_flags_vertical = Control.SIZE_FILL
	hb.add_child(gal_row)
	# the DIALOG column is sized to the WIDEST dialog (mail/daily/shop carry their own width) + chrome, so
	# no dialog is clipped inside its column; the building-blocks column takes the remaining width.
	var dlg_w := 0.0
	for did in ["dialog", "daily", "shop", "tiers", "bag"]:
		dlg_w = maxf(dlg_w, _dlg_px(did))
	var dlg_col_w: float = dlg_w + 96.0
	_columns.clear()
	for ci in COLUMNS.size():
		var col_scroll := ScrollContainer.new()
		col_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO   # a too-wide column scrolls sideways
		col_scroll.size_flags_vertical = Control.SIZE_FILL                      # window-height → its own vertical scroll
		if ci == COLUMNS.size() - 1:
			col_scroll.custom_minimum_size = Vector2(dlg_col_w, 0)              # the DIALOG column: fits the widest dialog
			col_scroll.size_flags_horizontal = Control.SIZE_FILL
		else:
			col_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL         # building blocks take the rest
		gal_row.add_child(col_scroll)
		var col_margin := MarginContainer.new()
		col_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for side in ["left", "right", "top", "bottom"]:
			col_margin.add_theme_constant_override("margin_" + side, 24)
		col_scroll.add_child(col_margin)
		var colbox := VBoxContainer.new()
		colbox.add_theme_constant_override("separation", 18)
		colbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col_margin.add_child(colbox)
		_columns.append(colbox)

	# left — the options sidebar (fixed width)
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(348, 0)
	side.size_flags_vertical = Control.SIZE_FILL
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0, 0, 0, 0.42)
	ssb.border_width_right = 2
	ssb.border_color = Color(Pal.CREAM, 0.12)
	ssb.set_content_margin_all(18)
	side.add_theme_stylebox_override("panel", ssb)
	# scope a SMALL font to the sidebar — the global 40px default made the row labels balloon and
	# crowd the sliders out. Keep the rounded face, drop the heavy outline for small text.
	var st := UiFont.make()
	st.default_font_size = 16
	for t in ["Label", "Button", "LineEdit", "OptionButton", "CheckButton"]:
		st.set_constant("outline_size", t, 0)
	side.theme = st
	hb.add_child(side)
	hb.move_child(side, 0)   # sidebar on the LEFT, gallery to its right
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(side_scroll)
	_sidebar_body = VBoxContainer.new()
	_sidebar_body.add_theme_constant_override("separation", 10)
	_sidebar_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(_sidebar_body)

	_rebuild_gallery()
	_rebuild_sidebar()

## A dialog's preview width in PIXELS, from its saved width_pct (% of the screen). The workbench previews
## against the 1080 portrait base; in-game the SAME pct multiplies the live viewport width (see login.gd /
## inbox.gd) — so the dialog is responsive, never a fixed pixel width.
func _dlg_px(id: String) -> float:
	return PHONE_W * float((_params[id] as Dictionary).get("width_pct", 85)) / 100.0

## Build the live element for an id from its current params.
func _make_element(id: String) -> Control:
	var p: Dictionary = _params[id]
	match id:
		"board":
			return _make_board_preview()
		"button":
			return Kit.pill_button(String(p.text), _btn_opts())
		"home_button":
			# the round icon button as the rail + nav build it, from the SAME kit transform the game reads.
			# Two variants side by side: nav-style (no caption / no sparkle) and rail-style (caption + the
			# tuned sparkle), so the configurable parts read at a glance. A bottom margin gives the caption
			# tab room (it overflows below the disc, exactly as it does on the rail).
			# include the BADGE item's polish so the home button reflects it LIVE (the same link the game uses)
			var ho := Kit.home_button_opts_from_config({"home_button": p, "badge": _params["badge"]})
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 30)
			# the nav-style disc carries the Bag's in-disc "x/y" COUNT so the count_dx / count_dy / count_font
			# knobs are tunable live (the bag well is a nav-style disc; only a count-bearing button draws it).
			row.add_child(Kit.home_button({"icon": String(p.icon), "caption": "", "sparkle": false, "count": String(p.get("count", ""))}, ho))
			# the rail-style disc carries a SAMPLE red badge so the badge_dx / badge_dy offset is tunable live
			# (the same Look.attach_badge the side rail uses; count 0 → bare dot, ≥1 → count pill).
			var rail_btn := Kit.home_button({"icon": String(p.icon), "caption": String(p.caption), "sparkle": bool(p.sparkle)}, ho)
			var bcount := int(p.get("badge_count", 3))
			var bg := Look.badge("pill", bcount) if bcount >= 1 else Look.badge("dot")
			Look.attach_badge(rail_btn, bg, Vector2(float(ho.get("badge_dx", -8)), float(ho.get("badge_dy", -8))))
			row.add_child(rail_btn)
			var mc := MarginContainer.new()
			mc.add_theme_constant_override("margin_bottom", int(p.caption_font) + 26)
			mc.add_child(row)
			return mc
		"home_unlock_button":
			# the restore-cost disc as the map builds it, from the SAME kit transform the game reads. The
			# preview diameter = PHONE_W × disc_pct (the in-game d on the design phone), so the workbench
			# shows the exact size + proportions the map will. cost + icon are the preview-only content.
			var uo := Kit.home_unlock_opts_from_config({"home_unlock_button": p})
			uo["px"] = PHONE_W * float(p.disc_pct) / 100.0
			# preview the GRAY (can't-afford) state via the test-only "afford" toggle + the saved gray_unaffordable.
			var pgray := bool(p.get("gray_unaffordable", true)) and not bool(p.get("afford", true))
			var ub: Button = Kit.home_unlock_button({"cost": int(p.cost), "icon": String(p.icon), "sparkle": bool(p.sparkle) and not pgray}, uo)
			if pgray:
				ub.modulate = Color(0.6, 0.6, 0.6, 1.0)
			return ub
		"icon":
			var box := HBoxContainer.new()
			box.add_theme_constant_override("separation", 28)
			box.add_child(_icon_preview("Raw", {"defringe": false, "feather": 0.0, "supersample": 1}))
			box.add_child(_icon_preview("Polished", {"defringe": bool(p.defringe), "feather": float(p.feather), "supersample": int(p.supersample), "shadow": bool(p.shadow)}))
			return box
		"badge":
			# the home button's disc shell as its own polish sandbox — raw vs the tuned defringe/feather/shadow.
			# The home button reads these same params, so editing here updates the home button live.
			var box := HBoxContainer.new()
			box.add_theme_constant_override("separation", 28)
			box.add_child(_badge_preview("Raw", {}))
			box.add_child(_badge_preview("Polished", {"defringe": bool(p.defringe), "feather": float(p.feather), "shadow": bool(p.shadow)}))
			return box
		"progress_bar":
			# the reusable bar at the previewed fill — built from the SAME config transform the game reads
			var po := Kit.progress_bar_opts_from_config({"progress_bar": p})
			var bar := Kit.progress_bar(float(p.frac) / 100.0, po)
			bar.custom_minimum_size.x = 320
			return bar
		"card":
			# the Claim inherits the shared Button's STYLE, but the card picks its OWN (saved) badge
			# background + icon for it. Give the standalone preview a representative width — a real card
			# always lives width-constrained in the dialog, so without one its shrinkable text collapses.
			var card := Kit.mail_card(Kit.DEMO_MAIL[0], int(p.title), int(p.body), _card_btn_opts(), Kit.card_icon_badge(_params))
			card.custom_minimum_size.x = 560   # comfortable width so the title doesn't clip
			return card
		"frame":
			# the SHARED frame on its own, with placeholder content — the one chrome every dialog reuses
			var fo := Kit.dialog_opts_from_config(_params)
			fo["banner_text"] = "Frame"
			var fr := Kit.dialog_frame(_frame_placeholder(), float(p.width), fo)
			_attach_dialog_drag(fr)
			return fr
		"dialog":
			# build from the SHARED kit transform (same one the game uses) + the test-only preview count
			var opts := Kit.dialog_opts_from_config(_params)
			opts["entries_count"] = int(p.entries)
			# NOT draggable — the frame (banner / ✕ positions) is edited on the Frame item, not here
			return Kit.mail_dialog(Kit.DEMO_MAIL, _dlg_px("dialog"), opts)
		"daily_card":
			# the shared small card in a chosen preview state (incl. a shop pack). Rendered at 2× (bigger
			# cell + fonts; the icons scale with cell_w) — a preview ZOOM so the small card is comfortable
			# to edit. The real daily/shop dialogs still use the saved (smaller) size.
			# a preview ZOOM: only the cell SIZE is enlarged — every content size + offset scales from cell_w
			# inside daily_card, so the zoomed preview shows the EXACT proportions the dialog will.
			var co := Kit.daily_card_opts_from_config(_params)
			var z := 2.0
			co["cell_w"] = float(co["cell_w"]) * z
			co["cell_h"] = float(co["cell_h"]) * z
			var day := _daily_preview_day(String(p.preview))
			if String(p.ribbon) != "":
				day["ribbon"] = String(p.ribbon)
			return Kit.daily_card(day, co)
		"toggle_card":
			# one settings ROW, standalone — a label + the shared switch, at a representative width (it always
			# lives width-constrained in the Settings dialog). label_font / switch_h / card_art are saved.
			var tco := Kit.toggle_card_opts_from_config(_params)
			var tcard := Kit.toggle_card({"label": String(p.label), "value": bool(p.value)}, tco)
			tcard.custom_minimum_size.x = 460
			return tcard
		"daily":
			# SHARED frame config (from the Dialog item) + the separately-defined day card + grid knobs
			var dopts := Kit.daily_opts_from_config(_params)
			dopts["banner_text"] = "Daily"
			return Kit.daily_dialog(Kit.DEMO_DAILY, _dlg_px("daily"), dopts)   # frame edited on the Frame item
		"shop":
			# the SAME shared frame + the SAME small card — just shop data (icon+count+price+ribbon)
			var sopts := Kit.shop_opts_from_config(_params)
			sopts["banner_text"] = "Shop"
			return Kit.shop_dialog(Kit.demo_shop(), _dlg_px("shop"), sopts)   # the GAME's real items
		"level":
			# the dedicated level dialog, from the SAME config transform the game (level_popup) reads
			var lo := Kit.level_opts_from_config(_params)
			lo["banner_text"] = TranslationServer.translate("Level %d") % int(p.preview_level)
			var lv_into: int = int(p.into)
			var lv_span: int = maxi(1, int(p.span))
			var lv_data := {
				"level": int(p.preview_level), "earned": lv_into, "next": lv_span,
				"into": lv_into, "span": lv_span, "remaining": maxi(0, lv_span - lv_into),
				"mode": String(p.mode), "gift": {"water": 30, "gems": 1},
			}
			return Kit.level_dialog(lv_data, _dlg_px("level"), lo)
		"map_card":
			# the place-picker card, built from the SAME kit resolver map.gd reads (so the preview is
			# exactly what the game renders). The locale art is preview-only "" → the meadow fill, so the
			# gold frame / dark panel + the §8 veil read on their own; open/done/stars_left preview the state.
			var mco := Kit.map_card_opts_from_config({"map_card": p})
			var mw := 460.0
			var mh := mw / Kit.MAP_CARD_ASPECT
			var mdata := {"open": bool(p.open), "done": bool(p.done), "art": "", "stars_left": int(p.stars_left),
				"prereq": "✿ after Meadow", "map_id": ""}
			return Kit.map_card(mdata, mco, mw, mh)
		"quest_card":
			# the giver card as the board builds it, from the SAME GiverStand.make the board scene calls — and
			# the SAME Kit.giver_lay_from_config transform the board reads, so the preview is byte-for-byte what
			# saving (then the board) will render. `bust` IS the asked line (the bust face is keyed off it), so it
			# drives both the giver and the item art; tier + stars round out the demo.
			var demo_q := {"line": maxi(1, int(p.bust)), "tier": int(p.tier), "reward": {"stars": int(p.stars)}}
			var noop2 := func(_a: Variant, _b: Variant) -> void: pass
			var qcfg := {
				"ask_tap": noop2, "stand_tap": noop2,
				"wire_tap": func(node: Control, action: Callable) -> void:
					node.gui_input.connect(func(ev: InputEvent) -> void:
						if ev is InputEventMouseButton and not (ev as InputEventMouseButton).pressed:
							action.call()),
				"stand_w": float(p.stand_w), "fence_h": float(p.fence_h),
				"lay": Kit.giver_lay_from_config({"quest_card": p}),
			}
			var made := GiverStand.make(maxi(1, int(p.bust)), demo_q, qcfg)
			var stand: Control = made.chip
			if bool(p.met):                       # preview the ready state (the board drives this live)
				var met: Control = (made.item as Dictionary).get("met")
				if met != null and is_instance_valid(met):
					met.visible = true
			return stand
		"tiers":
			# the STANDARD shared frame (no override) + the tier-cell grid (NO vines). The banner text is the line name.
			var topts := Kit.tiers_opts_from_config(_params)
			topts["banner_text"] = "Wildflower"
			return Kit.tiers_dialog(Kit.DEMO_TIERS, _dlg_px("tiers"), topts)
		"currency_pill":
			# the live top-bar wallet pill, built from the SAME kit resolver the HUD reads (so the preview is
			# exactly what the game renders). Shown as a single WATER pill WITH its "+" so the + LOCATION
			# (plus_gap / plus_dy) is tunable here; the live HUD repeats this capsule for water/coin/gem.
			var co := Kit.currency_pill_opts_from_config({"currency_pill": p})
			co["icons"] = [["water", 40.0]]
			co["show_plus"] = true
			return Kit.currency_pill(co, {"water": int(p.get("water", 128))})
		"info_bar":
			# the board's bottom-bar info pill, built from the SAME kit component + resolver the game reads
			# (so the preview is exactly the live bar). Pull in the currency_pill block too — the bar borrows
			# its capsule frame, so a pill tweak shows here live. `filled` previews the selected-vs-empty state.
			var io := Kit.info_bar_opts_from_config({"info_bar": p, "currency_pill": _params["currency_pill"]})
			var ib: PanelContainer = Kit.info_bar({}, io)   # no live callbacks in the preview
			var inner := float(ib.get_meta("inner_px", 62.0))
			if bool(p.get("filled", true)):
				(ib.get_meta("info_icon") as CenterContainer).add_child(PieceView.make_piece(102, inner * 0.8))
				(ib.get_meta("name_label") as Label).text = "Hazelnut · Tier 2"
				(ib.get_meta("info_btn") as Button).disabled = false
				var sb := ib.get_meta("sell_btn") as Button
				sb.text = " +12🪙"
				sb.visible = true
			else:
				(ib.get_meta("name_label") as Label).text = "Tap an item to inspect it"
				(ib.get_meta("info_btn") as Button).disabled = true
				(ib.get_meta("sell_btn") as Button).visible = false
			# the bar expands to fill the bottom row in-game; give the preview a representative bottom-bar width
			var wrap := Control.new()
			wrap.custom_minimum_size = Vector2(620, float(io.get("height", 130)))
			ib.set_anchors_preset(Control.PRESET_FULL_RECT)
			wrap.add_child(ib)
			return wrap
		"settings":
			# the SHARED frame + a column of toggle cards (the SAME builder the game's settings.gd uses)
			var setopts := Kit.settings_opts_from_config(_params)
			setopts["banner_text"] = "Settings"
			return Kit.settings_dialog(Kit.DEMO_SETTINGS, _dlg_px("settings"), setopts)
		"vault":
			# the SHARED frame in the NEW twig border + the jar hero (the SAME builder ui/vault.gd uses)
			var vopts := Kit.vault_opts_from_config(_params)
			vopts["banner_text"] = "Vault"
			var p_st := Kit.DEMO_VAULT.duplicate()
			p_st["balance"] = int(p.balance)
			p_st["claimable"] = bool(p.claimable)
			return Kit.vault_dialog(p_st, _dlg_px("vault"), vopts)
		"bag_card":
			# the slot tile in a chosen preview state, rendered at 2× so it's comfortable to edit: only the
			# SIZE scales — every metric is taken from the cell, so the zoom shows the EXACT proportions the
			# bag and discovery dialogs will.
			var bco := Kit.bag_card_opts_from_config(_params)
			var z := 2.0
			bco["cell_w"] = float(bco["cell_w"]) * z
			bco["cell_h"] = float(bco["cell_h"]) * z
			bco["cost_font"] = int(float(bco["cost_font"]) * z)
			bco["cost_icon"] = float(bco["cost_icon"]) * z
			bco["cost_y"] = float(bco["cost_y"]) * z
			bco["cost_x"] = float(bco["cost_x"]) * z   # cost_scale is a ratio — not zoomed
			return Kit.slot_cell(_bag_preview_cell(String(p.preview), int(p.level), int(p.cost)), bco)
		"bag":
			# the SHARED frame + the reused currency pill + a grid of bag cells (the SAME builder the game's
			# bag_overlay.gd uses). owned/filled compose the slot ladder; balance feeds the acorn pill.
			var bopts := Kit.bag_opts_from_config(_params)
			bopts["banner_text"] = "Bag"
			return Kit.bag_dialog(_bag_demo_entries(int(p.owned), int(p.filled)), int(p.balance), _dlg_px("bag"), bopts)
	return Control.new()

## A faithful BOARD preview — the bamboo frame (board_frame.png nine-patch) + the cell grid (the SHARED
## slot-cell well the board + bag use) + a few demo merge pieces (PieceView), the SAME art the live board
## renders. Two INDEPENDENT size knobs: `scale` zooms the WHOLE composition (frame + cells together);
## `cell` is the item width in px (the grid grows, the frame thickness stays) — so you trade item size
## against frame weight. `item` sizes the piece sprite as a % of its cell. Pure preview; not yet wired
## into the in-game board (which still sizes itself responsively from the viewport).
func _make_board_preview() -> Control:
	var p: Dictionary = _params["board"]
	var s: float = float(p.scale) / 100.0
	var cell: float = maxf(8.0, float(p.cell) * s)
	var gap: float = maxf(0.0, float(p.gap) * s)
	var frame: float = maxf(0.0, float(p.frame) * s)
	var cols: int = maxi(1, int(p.cols))
	var rows: int = maxi(1, int(p.rows))
	var grid_w: float = cols * cell + (cols - 1) * gap
	var grid_h: float = rows * cell + (rows - 1) * gap
	var total := Vector2(grid_w + frame * 2.0, grid_h + frame * 2.0)

	var root := Control.new()
	root.custom_minimum_size = total
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# the bamboo frame, overhanging the grid by `frame` on every side (PANEL_MARGIN 70 = board.gd's slice)
	var fp := Look.kit("board/board_frame.png")
	if ResourceLoader.exists(fp):
		var panel := NinePatchRect.new()
		panel.texture = load(fp)
		panel.size = total
		panel.patch_margin_left = 70
		panel.patch_margin_top = 70
		panel.patch_margin_right = 70
		panel.patch_margin_bottom = 70
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(panel)

	# the empty wells — the SHARED slot cell (Kit.slot_cell), at the LIVE Slot-cell (bag_card) style
	var opts: Dictionary = Kit.bag_card_opts_from_config(_params)
	opts["cell_w"] = cell
	opts["cell_h"] = cell
	for r in rows:
		for c in cols:
			var well: Control = Kit.slot_cell({"state": "empty"}, opts)
			well.position = Vector2(frame + c * (cell + gap), frame + r * (cell + gap))
			well.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(well)

	# a few demo merge pieces. The holder fills the cell (so it centers exactly like the game); the `item`
	# knob is the sprite width WITHIN it, applied as the inset — the SAME path the live board uses, so the
	# preview reads 1:1 with the game (board._make_piece passes the same inset from the saved board.item).
	if bool(p.pieces):
		var inset: float = clampf((1.0 - float(p.item) / 100.0) / 2.0, 0.0, 0.45)
		for d in BOARD_DEMO:
			var r: int = int(d[0])
			var c: int = int(d[1])
			if r >= rows or c >= cols:
				continue
			var piece: Control = PieceView.make_piece(int(d[2]), cell, inset)
			piece.position = Vector2(frame + c * (cell + gap), frame + r * (cell + gap))
			piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(piece)
	return root

## A demo slot CELL for the standalone Slot-cell preview, in the chosen state. `level`>0 docks the board
## level badge (lower-right); `cost`>0 shows the bag acorn cost — either applies only to locked/unlockable.
func _bag_preview_cell(state: String, level: int, cost: int) -> Dictionary:
	var d := {"state": state}
	if state == "filled":
		d["icon"] = "leaf"
	if state == "locked" or state == "unlockable":
		if level > 0:
			d["level"] = level
		if cost > 0:
			d["cost"] = cost
	return d

## The demo slot ladder for the Bag dialog preview — classified exactly like the game's slot_plan: the
## first `filled` slots hold a piece, the rest of the `owned` slots are empty, slot owned+1 is the gold
## "next" buy, the remainder are locked. Demo costs mirror G.BAG_SLOT_PRICES; the cap is 18 slots.
func _bag_demo_entries(owned: int, filled: int) -> Array:
	const CAP := 18
	const START := 6
	const PRICES := [10, 10, 10, 15, 15, 15, 20, 20, 20, 25, 25, 25]
	const ICONS_ := ["leaf", "gift", "daisy", "water", "star"]
	var out: Array = []
	for k in range(1, CAP + 1):
		if k <= owned:
			if k <= filled:
				out.append({"kind": "filled", "icon": ICONS_[(k - 1) % ICONS_.size()]})
			else:
				out.append({"kind": "empty"})
		elif k == owned + 1:
			out.append({"kind": "next", "cost": _bag_price(k, PRICES, START)})
		else:
			out.append({"kind": "locked", "cost": _bag_price(k, PRICES, START)})
	return out

## The acorn price to unlock 1-based slot `k` (0 for a starting/past slot) — mirrors BagOverlay._price_at.
func _bag_price(k: int, prices: Array, start: int) -> int:
	var idx := (k - 1) - start
	return int(prices[idx]) if idx >= 0 and idx < prices.size() else 0

## A demo day for the standalone Daily-card preview, in the chosen state (today shows the today badge,
## mystery shows the milestone badge + chest).
func _daily_preview_day(state: String) -> Dictionary:
	match state:
		"done":    return {"day": 2, "label": "Day 2", "reward": {"water": 10}, "state": "done"}
		"future":  return {"day": 5, "label": "Day 5", "reward": {"coins": 100}, "state": "future"}
		"mystery": return {"day": 7, "label": "Day 7", "reward": {"gems": 30}, "state": "future", "mystery": true}
		"shop":    return {"icon": "gem", "count": 500, "price": "$4.99"}   # the SAME card as a shop pack
		_:         return {"day": 4, "label": "Day 4", "reward": {"coins": 150}, "state": "today"}

## Placeholder content for the standalone Frame preview — faint bars standing in for "any content".
func _frame_placeholder() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 4:
		var bar := PanelContainer.new()
		bar.custom_minimum_size = Vector2(0, 56)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Pal.BARK, 0.12)
		sb.set_corner_radius_all(10)
		bar.add_theme_stylebox_override("panel", sb)
		v.add_child(bar)
	return v

## One labelled icon preview (raw or polished) for the Icon element.
func _icon_preview(label: String, opts: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = label
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(Pal.CREAM, 0.8))
	v.add_child(l)
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(170, 170)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	opts["size"] = 160
	var key := "icon|%s|%s|%s|%s" % [opts.get("defringe", false), opts.get("feather", 0.0), opts.get("supersample", 1), opts.get("shadow", false)]
	_set_polished(tr, key, Game.art("ui/currency/icon_gem.png"), opts, false)
	v.add_child(tr)
	return v

## One labelled badge (disc-shell) preview (raw or polished) for the Badge element — the SAME shell the
## home button uses, polished by the SAME kit transform, so what you see here is what the rail/nav get.
func _badge_preview(label: String, polish: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = label
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(Pal.CREAM, 0.8))
	v.add_child(l)
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(170, 170)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# the untouched "Raw" shell is an instant plain load; the "Polished" one bakes on a worker thread
	var defr := bool(polish.get("defringe", false))
	var feat := float(polish.get("feather", 0.0))
	var shad := bool(polish.get("shadow", false))
	if not defr and feat <= 0.0 and not shad:
		tr.texture = Kit.shell_texture(Kit.HOME_SHELL, polish)
	else:
		var key := "badge|%s|%s|%s" % [defr, feat, shad]
		_set_polished(tr, key, Look.kit(Kit.HOME_SHELL), polish, true)
	v.add_child(tr)
	return v

## Drive a preview TextureRect from the worker-thread polish cache: show the finished texture if it's
## ready, else show the RAW sprite now and mark this element awaiting — the pump rebuilds it (picking up
## the cached polish) once the worker lands. Keeps the polish sliders responsive (no per-tick main-thread bake).
func _set_polished(tr: TextureRect, key: String, path: String, opts: Dictionary, aspect: bool) -> void:
	var tex := Kit.polished_cached(key)            # cheap peek — skip the source decode on a cache hit
	if tex != null:
		tr.texture = tex
		return
	var src := _src_image(path)
	if src == null:
		tr.texture = null                          # art absent: nothing to bake, and DON'T await (no rebuild loop)
		return
	tex = Kit.polish_async(key, src, opts, aspect)
	if tex != null:
		tr.texture = tex
	else:
		tr.texture = load(path)                    # raw placeholder while the worker bakes
		if _building != "":
			_awaiting[_building] = true
			set_process(true)

## Load a sprite's RAW Image on the MAIN thread (ResourceLoader isn't threaded here), null-tolerant.
func _src_image(path: String) -> Image:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var t := load(path) as Texture2D
	return t.get_image() if t != null else null

## The shared Button's params as a kit opts dict. The card + dialog Claim are built ENTIRELY from
## this (no styling of their own), so editing the Button item updates every Claim automatically.
## The shared Button's STYLE (art / bg / corner / font / shadow) as a kit opts dict. The Button's own
## icon is test-only, so the card/dialog pass `overrides` to supply the REAL, saved icon + badge:
##   overrides.badge — a Card-chosen badge that wins over the Button's; overrides.icon — the claim icon
##   ("" = none). Absent overrides fall back to the Button's own values (used by the Button preview).
func _btn_opts(overrides := {}) -> Dictionary:
	var b: Dictionary = _params["button"]
	var badge: String = String(overrides.get("badge", b.get("badge", "auto")))
	var o := {
		"text": String(overrides.get("text", b.text)),
		"bg": String(overrides.get("bg", b.bg)),
		"icon": ("" if String(b.icon) == "none" else String(b.icon)),
		"icon_size": int(b.icon_size),
		"enabled": bool(b.enabled),
		"font": int(b.font),
		"corner": int(b.corner),
		"art": bool(b.art),
		"shadow": bool(b.shadow),
	}
	if overrides.has("icon"):
		o["icon"] = String(overrides["icon"])      # the Card's saved icon choice ("" = none)
	# a specific badge forces art mode and overrides the default bg-based sprite
	if badge != "auto" and Kit.BADGES.has(badge) and String(Kit.BADGES[badge]) != "":
		o["art"] = true
		o["art_rel"] = String(Kit.BADGES[badge])
	return o

## The Button style + the Card's OWN saved badge / icon / claim text — drives the cost pill + Claim in
## both the Card preview and every dialog row. Delegates to the SAME kit builder the game uses, so the
## transform lives in exactly one place.
func _card_btn_opts() -> Dictionary:
	return Kit.card_btn_opts(_params)

## --- gallery (left) ------------------------------------------------------------------------------

func _rebuild_gallery() -> void:
	if _columns.is_empty():
		return
	for ci in COLUMNS.size():
		var colbox := _columns[ci] as VBoxContainer
		if not is_instance_valid(colbox):
			continue
		for c in colbox.get_children():
			colbox.remove_child(c)
			c.queue_free()
		for row in COLUMNS[ci]:                # each ROW is a line of side-by-side element sections
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 18)
			line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			for id in row:
				line.add_child(_section(id))
			colbox.add_child(line)
		# scroll-past room at the bottom of EACH column, so the last element never sits flush against the
		# window edge — you can scroll a little past it to see its full base.
		var tail := Control.new()
		tail.custom_minimum_size = Vector2(0, 200)
		tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		colbox.add_child(tail)

func _section(id: String) -> Control:
	var sec := PanelContainer.new()
	sec.add_theme_stylebox_override("panel", _section_style(id == _selected))
	sec.mouse_filter = Control.MOUSE_FILTER_STOP            # catches clicks on the non-button areas
	sec.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sec.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # natural width so a row pairs sit side by side
	sec.size_flags_vertical = Control.SIZE_SHRINK_BEGIN     # top-align within the row
	sec.gui_input.connect(_on_section_input.bind(id))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sec.add_child(v)
	var cap := Label.new()
	# short caption in the gallery (the full description rides the sidebar) so paired sections stay narrow
	cap.text = ("●  " if id == _selected else "") + String(CAPTIONS[id]).split(" — ")[0]
	cap.add_theme_font_size_override("font_size", 15)
	cap.add_theme_color_override("font_color", Pal.STRAW if id == _selected else Color(Pal.CREAM, 0.8))
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cap)
	var holder := CenterContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_building = id                          # so the polish previews know which element to mark awaiting
	var el := _make_element(id)
	_building = ""
	_make_clickthrough(el, id == "frame")   # only the FRAME keeps its handles grabbable
	holder.add_child(el)
	v.add_child(holder)
	_sections[id] = sec
	return sec

## Apply an edit to the SELECTED element: rebuild it NOW (live feedback on the control you're dragging),
## then queue its dependents to rebuild one-per-frame (post-change, so the sliders never freeze). The
## queue is a Set, so a fast drag that fires many times just re-marks the same ids — no rebuild backlog.
func _apply_edit() -> void:
	_rebuild_element(_selected)
	_mark_dirty(DEPENDENTS.get(_selected, []))

## Queue ids to rebuild on the staggered pump (see _process). Coalesced via the _dirty Set.
func _mark_dirty(ids: Array) -> void:
	for id in ids:
		_dirty[id] = true
	if not _dirty.is_empty():
		set_process(true)

# Drain the dirty queue ONE element per frame (so the screen keeps repainting between heavy linked
# rebuilds instead of freezing through all of them), then settle elements waiting on a worker polish:
# once their off-thread bake lands, rebuild them so the raw placeholder swaps to the polished texture.
func _process(_delta: float) -> void:
	if not _dirty.is_empty():
		var id: String = String(_dirty.keys()[0])
		_dirty.erase(id)
		_rebuild_element(id)
	elif not _awaiting.is_empty() and Kit.pump_polish() == 0:
		var ids: Array = _awaiting.keys()
		_awaiting.clear()
		for id in ids:
			_rebuild_element(id)
	if _dirty.is_empty() and _awaiting.is_empty():
		set_process(false)

## Rebuild a single element's section in place (swap the node at its position in the row), leaving every
## OTHER section untouched. No-op if the gallery hasn't been built yet (the initial _rebuild_gallery does).
func _rebuild_element(id: String) -> void:
	var old: Node = _sections.get(id)
	if old == null or not is_instance_valid(old):
		return
	var parent := (old as Control).get_parent()
	if parent == null:
		return
	var idx := (old as Control).get_index()
	var fresh := _section(id)          # also re-registers _sections[id] = fresh
	parent.add_child(fresh)
	parent.move_child(fresh, idx)
	old.queue_free()

## Make EVERYTHING in the section mouse-transparent, so a click ANYWHERE — even on top of the component
## itself (a card, a button, the banner) — falls through to the section and selects it. The ONE
## exception: the FRAME element keeps its banner / banner-icon / ✕ active so those handles stay
## draggable there (the other dialogs reuse the frame read-only, so their banner is NOT draggable).
func _make_clickthrough(n: Node, keep_handles: bool) -> void:
	for c in n.get_children():
		if c is Control:
			var is_handle: bool = String(c.name) in ["DialogBanner", "DialogBannerIcon", "DialogClose"]
			if not (keep_handles and is_handle):
				(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_make_clickthrough(c, keep_handles)

## --- drag-to-move with snap (dialog banner icon + ✕) ---------------------------------------------

## Make the dialog's named handles draggable. Re-run on every dialog rebuild (new nodes each time).
func _attach_dialog_drag(d: Control) -> void:
	var banner: Control = d.find_child("DialogBanner", true, false)
	if banner != null:
		banner.mouse_filter = Control.MOUSE_FILTER_STOP
		_make_draggable(banner, "banner")
	var env: Control = d.find_child("DialogBannerIcon", true, false)
	if env != null:
		env.mouse_filter = Control.MOUSE_FILTER_STOP
		_make_draggable(env, "banner_icon")
	var close: Control = d.find_child("DialogClose", true, false)
	if close != null:
		_make_draggable(close, "close")

func _make_draggable(node: Control, kind: String) -> void:
	node.mouse_default_cursor_shape = Control.CURSOR_MOVE
	node.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (ev as InputEventMouseButton).pressed:
			_drag_kind = kind
			_drag_node = node
			_drag_grab = (ev as InputEventMouseButton).global_position - node.global_position
			get_viewport().set_input_as_handled())

# Global so the drag keeps following the cursor even when it leaves the small handle.
func _input(ev: InputEvent) -> void:
	if _drag_kind == "" or _drag_node == null or not is_instance_valid(_drag_node):
		return
	if ev is InputEventMouseMotion:
		var parent := _drag_node.get_parent() as Control
		if parent == null:
			return
		var target: Vector2 = (ev as InputEventMouseMotion).global_position - _drag_grab
		var local: Vector2 = parent.get_global_transform().affine_inverse() * target
		local = _snap_vec(local)
		_drag_node.position = local
		_store_drag(_drag_kind, local)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and not (ev as InputEventMouseButton).pressed:
		_drag_kind = ""
		_drag_node = null
		_rebuild_sidebar()      # reflect the dragged position in the sliders (and clamp it)
		# the dragged handles are FRAME config (shared) — rebuild the frame + every dialog that reuses it
		_rebuild_element("frame")
		_mark_dirty(DEPENDENTS["frame"])

func _snap_vec(v: Vector2) -> Vector2:
	var g: float = float(int(_params["frame"]["snap"]))
	if g < 1.0:
		return v
	return Vector2(roundf(v.x / g) * g, roundf(v.y / g) * g)

func _store_drag(kind: String, local: Vector2) -> void:
	var p: Dictionary = _params["frame"]      # banner/✕ positions are FRAME config (shared by every dialog)
	if kind == "banner":
		p["banner_x"] = local.x
		p["banner_y"] = local.y
	elif kind == "banner_icon":
		p["banner_icon_x"] = local.x
		p["banner_icon_y"] = local.y
	elif kind == "close":
		var card := _drag_node.get_parent().get_child(0) as Control   # wrap's first child is the card
		var cw: float = (card.size.x if card != null else float(p["width"]))
		p["close_x"] = local.x - (cw - _drag_node.size.x)             # inverse of the kit's dock() formula
		p["close_y"] = -local.y

func _on_section_input(ev: InputEvent, id: String) -> void:
	var hit: bool = (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	hit = hit or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed)
	if hit:
		select(id)

func select(id: String) -> void:
	if id == _selected:
		return
	var prev := _selected
	_selected = id
	# DEFER: select() runs inside a section's gui_input dispatch — rebuilding (freeing the very
	# section that is mid-emit) here would hit "Object is locked and can't be freed". Defer so the
	# tree is mutated only after the input dispatch returns. Refresh ONLY the two sections whose
	# highlight changed (the old + the new selection), not the whole gallery.
	_rebuild_element.call_deferred(prev)
	_rebuild_element.call_deferred(id)
	_rebuild_sidebar.call_deferred()      # swap in this element's options

func _section_style(selected: bool) -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	if selected:
		sb.bg_color = Color(1, 1, 1, 0.05)
		sb.set_border_width_all(2)
		sb.border_color = Pal.STRAW
	else:
		sb.bg_color = Color(0, 0, 0, 0.22)
		sb.set_border_width_all(1)
		sb.border_color = Color(Pal.CREAM, 0.1)
	return sb

## --- sidebar (right) -----------------------------------------------------------------------------

func _rebuild_sidebar() -> void:
	if _sidebar_body == null or not is_instance_valid(_sidebar_body):
		return
	for c in _sidebar_body.get_children():
		_sidebar_body.remove_child(c)
		c.queue_free()
	var head := Label.new()
	head.text = "Options"
	head.add_theme_font_size_override("font_size", 26)
	_sidebar_body.add_child(head)
	var save := Button.new()
	save.text = "Save settings"
	save.pressed.connect(_save_settings)
	_sidebar_body.add_child(save)
	var sub := Label.new()
	sub.text = String(CAPTIONS[_selected])
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(Pal.CREAM, 0.65))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sidebar_body.add_child(sub)
	if _selected == "daily_card":
		var note := Label.new()
		note.text = "This single day card is reused by the Daily dialog. (The Claim is the shared Button.) Preview a state below; the badges show on today / milestone."
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	if _selected == "toggle_card":
		var note := Label.new()
		note.text = "This single setting row is reused by the Settings dialog. (The switch is the shared kit switch.) Label + value below just preview the row."
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	if _selected == "dialog" or _selected == "daily" or _selected == "shop" or _selected == "settings":
		var note := Label.new()
		var card_src := ""
		if _selected == "daily" or _selected == "shop":
			card_src = " the card is on the Daily card item;"
		elif _selected == "settings":
			card_src = " the card is on the Toggle card item;"
		note.text = "The frame (banner · border · ✕ · scroll · padding) is SHARED — edit it on the Frame item.%s Here: this dialog's content." % card_src
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	if _selected == "card" or _selected == "dialog":
		var note := Label.new()
		note.text = "Claim inherits the Button's STYLE (font / corner / art / shadow). Its badge + icon are the Card's own saved choice."
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	if _selected == "tiers":
		var note := Label.new()
		note.text = "Uses the STANDARD shared frame with NO override — border, banner + ✕ are all tuned on the Frame item and flow here. The tiles ARE the SHARED slot cell: a seen tier → the filled well holds its piece, an unseen tier → the locked well (baked padlock, no \"?\"); the tier rides the gold level medal lower-right; marked tiers sparkle. The piece/medal size + well art are inherited from the Slot cell item — only the square cell size, the medal toggle, the sparkle, and the grid are tuned here. A plain grid — no vines."
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	if _selected == "bag_card":
		var note := Label.new()
		note.text = "ONE cell shared by the Bag dialog AND the board, on the board's cream well: empty / filled (slot_tile); locked / unlockable (slot_locked, baked lock). Unlockable = the highlight (gold border + dynamic sparkle). Add a level badge (board) or an acorn cost (bag) below."
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	if _selected == "bag":
		var note := Label.new()
		note.text = "Reuses the SHARED frame (banner · border · ✕ — edit on the Frame item) + the REUSED currency pill (the acorn balance — edit on the Currency pill item). The tile is the Bag cell item. Here: the grid + the preview ladder."
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	if _selected == "board":
		var note := Label.new()
		note.text = "A live preview of the merge board: the bamboo frame + the SHARED cell well (edit its look on the Slot cell item) + demo pieces. SCALE zooms the whole board (frame + cells together); CELL is the item width — the grid grows while the frame thickness stays, so you trade item size against frame weight. ITEM is the piece size within its cell. Preview only — not yet wired into the in-game board (which still sizes itself from the screen)."
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	_sidebar_body.add_child(HSeparator.new())

	# Every element splits its controls into the two buckets (see TEST_KEYS): the persisted design
	# config first, then the transient test/preview scaffolding that the config file never touches.
	match _selected:
		"board":
			_group_header("Saved to config", true)
			_section_header("Size")
			_sidebar_body.add_child(_slider_row(["scale", 30, 200]))   # overall zoom (% — frame + cells together)
			_sidebar_body.add_child(_slider_row(["cell", 28, 120]))    # item width (px) — grid grows, frame stays
			_sidebar_body.add_child(_slider_row(["item", 40, 100]))    # piece sprite size as % of its cell
			_sidebar_body.add_child(_slider_row(["gap", 0, 30]))       # gutter between cells (px)
			_sidebar_body.add_child(_slider_row(["frame", 0, 120]))    # bamboo frame overhang (px)
			_section_header("Grid")
			_sidebar_body.add_child(_slider_row(["cols", 1, 9]))
			_sidebar_body.add_child(_slider_row(["rows", 1, 12]))
			_group_header("Test only — not saved", false)
			_sidebar_body.add_child(_toggle_row("Demo pieces", "pieces"))
		"button":
			_group_header("Saved to config", true)            # only the shared STYLE persists
			_sidebar_body.add_child(_toggle_row("Drop shadow", "shadow"))
			_sidebar_body.add_child(_toggle_row("Use art", "art", true))   # sprite (scaled whole) vs code-drawn
			_sidebar_body.add_child(_slider_row(["font", 12, 40]))
			_group_header("Test only — not saved", false)      # preview props; text/badge/icon live on the Card
			_sidebar_body.add_child(_text_row("Text", "text"))
			_sidebar_body.add_child(_option_row("Background", "bg", ["green", "cream"]))
			if bool(_params["button"]["art"]):
				_sidebar_body.add_child(_option_row("Badge", "badge", Kit.BADGES.keys()))
			else:
				_sidebar_body.add_child(_slider_row(["corner", 0, 40]))
			_sidebar_body.add_child(_option_row("Icon", "icon", ICONS))
			_sidebar_body.add_child(_slider_row(["icon_size", 8, 60]))
			_sidebar_body.add_child(_toggle_row("Enabled", "enabled"))
		"home_button":
			_group_header("Saved to config", true)              # the shared shell / icon / caption / sparkle style
			_sidebar_body.add_child(_slider_row(["px", 90, 200]))
			_sidebar_body.add_child(_slider_row(["icon_scale", 30, 80]))   # icon as % of the disc
			_sidebar_body.add_child(_slider_row(["caption_font", 14, 34]))
			_sidebar_body.add_child(_slider_row(["caption_gap", -10, 40]))   # tab offset below the disc (negative tucks up)
			_sidebar_body.add_child(_slider_row(["caption_pad_x", 0, 40]))   # caption tab horizontal padding
			_sidebar_body.add_child(_slider_row(["caption_pad_y", 0, 20]))   # caption tab vertical padding
			_section_header("Side-rail badge (red dot / count)")
			_sidebar_body.add_child(_slider_row(["badge_dx", -30, 20]))   # badge x past the disc corner (neg tucks in)
			_sidebar_body.add_child(_slider_row(["badge_dy", -30, 20]))   # badge y past the disc corner (neg tucks in)
			_section_header("Bag count (in-disc \"x/y\")")
			_sidebar_body.add_child(_slider_row(["count_dx", -60, 60]))   # count x offset from the disc centre
			_sidebar_body.add_child(_slider_row(["count_dy", -60, 60]))   # count y offset from the disc centre (+ = lower)
			_sidebar_body.add_child(_slider_row(["count_font", 14, 40]))  # the "x/y" font size
			_section_header("Sparkle (engine FX — no baked art)")
			_sidebar_body.add_child(_slider_row(["glow", 0, 100]))       # the breathing halo amount
			_sidebar_body.add_child(_slider_row(["twinkle", 0, 100]))    # the drifting-star density
			_group_header("Test only — not saved", false)        # the rail/nav each set their own icon + caption
			_sidebar_body.add_child(_option_row("Icon", "icon", HOME_ICONS))
			_sidebar_body.add_child(_text_row("Caption", "caption"))
			_sidebar_body.add_child(_toggle_row("Sparkle", "sparkle"))   # preview the sparkle on the right-hand disc
			_sidebar_body.add_child(_slider_row(["badge_count", 0, 99]))   # sample badge count (0 = dot, ≥1 = count pill)
			_sidebar_body.add_child(_text_row("Bag count", "count"))   # sample "x/y" on the nav disc (empty = none)
		"home_unlock_button":
			_group_header("Saved to config", true)              # disc size + the inner proportions
			_sidebar_body.add_child(_slider_row(["disc_pct", 8, 30]))      # disc diameter as % of the MAP width
			_sidebar_body.add_child(_slider_row(["plus_scale", 10, 60]))   # the "+" as % of the disc
			_sidebar_body.add_child(_slider_row(["icon_scale", 10, 60]))   # the cost icon as % of the disc
			_sidebar_body.add_child(_slider_row(["cost_font", 10, 60]))    # the cost number as % of the disc
			_sidebar_body.add_child(_slider_row(["stack_gap", -10, 20]))   # gap "+"↔cost row, % of disc (neg tucks up)
			_sidebar_body.add_child(_slider_row(["icon_gap", 0, 15]))      # gap icon↔number, % of disc
			_sidebar_body.add_child(_toggle_row("Gray when unaffordable", "gray_unaffordable", true))   # dim locked spots
			_section_header("Sparkle (engine FX — no baked art)")
			_sidebar_body.add_child(_slider_row(["glow", 0, 100]))       # the breathing halo amount (0 = off)
			_sidebar_body.add_child(_slider_row(["twinkle", 0, 100]))    # the drifting-star density (0 = off)
			_group_header("Test only — not saved", false)        # the map sets each spot's real cost + "star"
			_sidebar_body.add_child(_slider_row(["cost", 0, 999]))
			_sidebar_body.add_child(_option_row("Icon", "icon", UNLOCK_ICONS))
			_sidebar_body.add_child(_toggle_row("Sparkle", "sparkle"))   # preview the sparkle (glow/twinkle must be > 0)
			_sidebar_body.add_child(_toggle_row("Affordable", "afford", true))   # OFF → preview the grayed locked state
		"card":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_option_row("Icon badge", "icon_badge", Kit.ICON_BADGES.keys()))
			_sidebar_body.add_child(_option_row("Button badge", "badge", Kit.BADGES.keys()))
			_sidebar_body.add_child(_text_row("Claim text", "claim_text"))
			_sidebar_body.add_child(_toggle_row("Claim icon", "icon_on", true))   # whether the Claim shows an icon
			if bool(_params["card"]["icon_on"]):
				_sidebar_body.add_child(_option_row("Icon", "icon", ICONS.slice(1)))   # ICONS minus "none"
			_sidebar_body.add_child(_slider_row(["title", 12, 30]))
			_sidebar_body.add_child(_slider_row(["body", 10, 24]))
		"icon":
			_group_header("Test only — not saved", false)   # a polish-tuning sandbox; the recipe is fixed in the kit
			_sidebar_body.add_child(_toggle_row("Defringe", "defringe"))
			_sidebar_body.add_child(_toggle_row("Drop shadow", "shadow"))
			_sidebar_body.add_child(_slider_row(["feather", 0, 4]))
			_sidebar_body.add_child(_slider_row(["supersample", 1, 4]))
		"badge":
			_group_header("Saved to config", true)           # the disc-shell polish; the home button reads it live
			_sidebar_body.add_child(_toggle_row("Defringe", "defringe"))
			_sidebar_body.add_child(_toggle_row("Drop shadow", "shadow"))
			_sidebar_body.add_child(_slider_row(["feather", 0, 4]))
		"progress_bar":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["height", 8, 48]))
			_sidebar_body.add_child(_toggle_row("Use art", "art"))
			_sidebar_body.add_child(_toggle_row("Star knob", "star_knob"))
			_group_header("Test only — not saved", false)
			_sidebar_body.add_child(_slider_row(["frac", 0, 100]))   # preview the fill amount
		"frame":
			_frame_sidebar()         # the shared frame's own config (Card / Banner / Close / List)
		"dialog":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["width_pct", 40, 100]))   # % of the screen width (responsive)
			_group_header("Test only — not saved", false)
			_sidebar_body.add_child(_slider_row(["entries", 1, 12]))   # how many rows to preview
		"daily_card":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_option_row("Today badge", "today_badge", Kit.DAY_BADGES))
			_sidebar_body.add_child(_option_row("Milestone badge", "milestone_badge", Kit.DAY_BADGES))
			_sidebar_body.add_child(_toggle_row("Info icon (top-right)", "info_icon"))
			_sidebar_body.add_child(_slider_row(["label_y", 0, 90]))      # the "Day N" text drop from the top
			_sidebar_body.add_child(_slider_row(["label_x", -80, 80]))    # the text horizontal position
			_sidebar_body.add_child(_slider_row(["claim_y", 0, 90]))      # how far the action lifts in from the base
			_sidebar_body.add_child(_slider_row(["ribbon_scale", 50, 220]))  # the ribbon SIZE (%)
			_sidebar_body.add_child(_slider_row(["ribbon_x", -150, 150]))    # the ribbon horizontal position
			_sidebar_body.add_child(_slider_row(["ribbon_y", -40, 40]))      # the ribbon vertical position (over the top)
			_sidebar_body.add_child(_slider_row(["cell_w", 60, 160]))
			_sidebar_body.add_child(_slider_row(["cell_h", 70, 180]))
			_sidebar_body.add_child(_slider_row(["cell_slice", 0, 80]))
			_sidebar_body.add_child(_toggle_row("Cell art", "cell_art"))
			_group_header("Test only — not saved", false)
			_sidebar_body.add_child(_toggle_row("Sparkle (today)", "sparkle"))   # preview only — always on in-game
			_sidebar_body.add_child(_option_row("Preview", "preview", ["today", "mystery", "done", "future", "shop"]))
			_sidebar_body.add_child(_option_row("Ribbon", "ribbon", Kit.POPULAR_BADGES))   # the popular badge
		"daily":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["width_pct", 40, 100]))   # % of the screen width (responsive)
			_sidebar_body.add_child(_slider_row(["cols", 1, 7]))
			_sidebar_body.add_child(_slider_row(["list_max_h", 0, 1000]))   # height cap; 0 = no scroll
		"shop":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["width_pct", 40, 100]))   # % of the screen width (responsive)
			_sidebar_body.add_child(_slider_row(["cols", 1, 5]))
			_sidebar_body.add_child(_slider_row(["cell_w", 80, 160]))
			_sidebar_body.add_child(_slider_row(["cell_h", 100, 200]))
			_sidebar_body.add_child(_slider_row(["row_gap", 6, 60]))        # spacing between rows + sections
			_sidebar_body.add_child(_slider_row(["list_max_h", 0, 1000]))   # height cap; 0 = no scroll
		"level":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["width_pct", 40, 100]))   # % of the screen width (responsive)
			_sidebar_body.add_child(_text_row("Banner text", "banner_text"))
			_sidebar_body.add_child(_slider_row(["title_font", 16, 48]))
			_sidebar_body.add_child(_slider_row(["medallion_px", 80, 180]))
			_sidebar_body.add_child(_slider_row(["ring_dy", -60, 60]))     # nudge the ring within the wreath
			_sidebar_body.add_child(_slider_row(["tally_font", 16, 40]))
			_sidebar_body.add_child(_slider_row(["hint_font", 12, 32]))
			_sidebar_body.add_child(_slider_row(["btn_font", 16, 48]))    # the Got-it / Collect button label size
			_sidebar_body.add_child(_slider_row(["frame_slice", 0, 160]))   # nine-patch corner slice
			_sidebar_body.add_child(_slider_row(["frame_pad", 8, 60]))
			_sidebar_body.add_child(_slider_row(["frame_top_pad", 20, 140]))   # room under the title pill
			_sidebar_body.add_child(_slider_row(["gap", 4, 40]))
			_group_header("Test only — not saved", false)
			_sidebar_body.add_child(_option_row("Mode", "mode", ["info", "levelup"]))
			_sidebar_body.add_child(_slider_row(["preview_level", 1, 50]))
			_sidebar_body.add_child(_slider_row(["into", 0, 30]))
			_sidebar_body.add_child(_slider_row(["span", 1, 30]))
		"map_card":
			_group_header("Saved to config", true)
			# the painted kit (card_active / card_locked / pill_left) vs the code-drawn fallback. The §8 fog
			# veil + its dials apply ONLY to that fallback (a locked card with art off), so they show then.
			_sidebar_body.add_child(_toggle_row("Use art", "use_art", true))
			_sidebar_body.add_child(_slider_row(["edge_sparkle", 0, 100]))    # twinkles ringing an ACTIVE open card's gold band (% — 0 = off)
			_sidebar_body.add_child(_slider_row(["pill_w_frac", 10, 60]))     # count-pill width (% of card width)
			_sidebar_body.add_child(_slider_row(["pill_min", 80, 360]))       # …clamped to this min px
			_sidebar_body.add_child(_slider_row(["pill_max", 120, 460]))      # …and this max px
			_sidebar_body.add_child(_slider_row(["pill_y_frac", 0, 40]))      # pill lift off the bottom edge (% of height)
			if not bool(_params["map_card"]["use_art"]):
				_sidebar_body.add_child(_slider_row(["veil_scrim", 0, 100]))       # §8 fog haze over the locked thumb
				_sidebar_body.add_child(_slider_row(["veil_deep", 0, 100]))        # …pooled deeper at the base
				_sidebar_body.add_child(_slider_row(["veil_mark_alpha", 0, 100]))  # the ✿ ghost in the mist
				_sidebar_body.add_child(_slider_row(["veil_mark_size", 16, 120]))  # ✿ glyph px (also the meadow-fill mark)
			_group_header("Test only — not saved", false)                    # the game sets open / done / count per map
			_sidebar_body.add_child(_toggle_row("Open (unlocked)", "open"))
			_sidebar_body.add_child(_toggle_row("Done (restored)", "done"))
			_sidebar_body.add_child(_slider_row(["stars_left", 0, 99]))
		"tiers":
			_group_header("Saved to config", true)
			_section_header("Layout (grid — no vines)")
			_sidebar_body.add_child(_slider_row(["width_pct", 40, 100]))    # % of the screen width (responsive)
			_sidebar_body.add_child(_slider_row(["cols", 1, 5]))
			_sidebar_body.add_child(_slider_row(["cell_gap", 0, 48]))
			_sidebar_body.add_child(_slider_row(["list_max_h", 0, 1400]))   # height cap; 0 = no scroll
			_section_header("Tile (square cell — piece/medal size + art are on the Slot cell)")
			_sidebar_body.add_child(_slider_row(["cell_w", 80, 240]))
			_sidebar_body.add_child(_slider_row(["cell_h", 80, 240]))
			_sidebar_body.add_child(_toggle_row("Tier medal", "show_num"))  # the lower-right gold level badge
			_section_header("Marked tier (sparkle)")
			_sidebar_body.add_child(_slider_row(["mark_glow", 0, 100]))     # the marked tier's glow (0 = off)
			_sidebar_body.add_child(_slider_row(["mark_twinkle", 0, 100]))  # ...and its drifting twinkles (0 = off)
			# the frame chrome (border · banner · ✕) is the STANDARD shared frame — tune it on the Frame item.
		"currency_pill":
			_group_header("Saved to config", true)
			# the painted capsule (panel_pill.png) vs a code-drawn cream pill. The Border picker swaps the
			# painted capsule (art path); radius / border_w / shadow shape the code-drawn pill (the art bakes
			# its own rim), so the picker shows only with art ON and those knobs only with art OFF.
			_sidebar_body.add_child(_toggle_row("Use art", "use_art", true))
			if bool(_params["currency_pill"]["use_art"]):
				_sidebar_body.add_child(_option_row("Border", "border", Kit.PILL_BORDERS.keys()))   # which painted capsule
			_sidebar_body.add_child(_slider_row(["pad_x", 0, 60]))          # horizontal padding
			_sidebar_body.add_child(_slider_row(["pad_y", 0, 40]))          # vertical padding
			if not bool(_params["currency_pill"]["use_art"]):
				_sidebar_body.add_child(_slider_row(["radius", 0, 60]))     # corner radius
				_sidebar_body.add_child(_slider_row(["border_w", 0, 12]))   # border width
				_sidebar_body.add_child(_slider_row(["shadow_size", 0, 24]))   # drop shadow (0 = off)
			_sidebar_body.add_child(_slider_row(["num_size", 16, 56]))      # the currency number font
			_sidebar_body.add_child(_slider_row(["icon_box", 20, 72]))      # the shared square icon box
			_sidebar_body.add_child(_slider_row(["row_sep", 0, 20]))        # icon↔number gap
			_sidebar_body.add_child(_slider_row(["pair_sep", 0, 40]))       # gap between currencies (the live cluster)
			_sidebar_body.add_child(_slider_row(["plus_gap", 0, 48]))       # the "+" LOCATION: gap right of the number
			_sidebar_body.add_child(_slider_row(["plus_dy", -24, 24]))      # the "+" LOCATION: vertical nudge up(-)/down(+)
			_sidebar_body.add_child(_slider_row(["plus_size", 14, 44]))     # the green "+" token diameter (font tracks it)
			_group_header("Test only — not saved", false)                  # preview count; the wallet shows live balances
			_sidebar_body.add_child(_slider_row(["water", 0, 9999]))
		"info_bar":
			_group_header("Saved to config", true)                         # layout only — the frame is the shared currency pill
			_sidebar_body.add_child(_slider_row(["height", 90, 180]))       # bar height (matches the Bag/Home wells)
			_sidebar_body.add_child(_slider_row(["inner_scale", 30, 70]))   # the info ⓘ + piece box as % of the height
			_sidebar_body.add_child(_slider_row(["name_font", 18, 44]))     # the "<name> · Tier N" font
			_sidebar_body.add_child(_slider_row(["sep", 0, 30]))            # gap between the bar's controls
			_sidebar_body.add_child(_slider_row(["sell_font", 16, 40]))     # the sell button's payout font
			_sidebar_body.add_child(_slider_row(["sell_icon", 15, 50]))     # the cart icon as % of the height
			_group_header("Test only — not saved", false)                  # the frame is tuned on the Currency pill element
			_sidebar_body.add_child(_toggle_row("Filled (vs empty)", "filled", true))   # preview the selected vs empty state
		"toggle_card":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_toggle_row("Card art (parchment)", "card_art"))
			_sidebar_body.add_child(_slider_row(["label_font", 16, 44]))
			_sidebar_body.add_child(_slider_row(["switch_h", 28, 72]))
			_group_header("Test only — not saved", false)
			_sidebar_body.add_child(_text_row("Label", "label"))
			_sidebar_body.add_child(_toggle_row("Value (on)", "value"))
		"settings":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["width_pct", 40, 100]))   # % of the screen width (responsive)
			_sidebar_body.add_child(_slider_row(["row_gap", 0, 40]))       # gap between toggle rows
		"vault":
			_vault_sidebar()         # the vault's own layout + twig-border knobs (chrome on the Frame item)
		"bag_card":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_toggle_row("Cell art", "cell_art"))
			_sidebar_body.add_child(_slider_row(["cell_w", 60, 180]))
			_sidebar_body.add_child(_slider_row(["cell_h", 60, 200]))
			_sidebar_body.add_child(_slider_row(["cell_slice", 0, 80]))      # the well's nine-patch corner margin
			_sidebar_body.add_child(_slider_row(["content_frac", 30, 95]))   # the piece size (% of cell)
			_sidebar_body.add_child(_slider_row(["level_frac", 20, 70]))     # the level badge size (% of cell)
			_sidebar_body.add_child(_slider_row(["cost_font", 12, 48]))
			_sidebar_body.add_child(_slider_row(["cost_icon", 16, 56]))
			_sidebar_body.add_child(_slider_row(["cost_y", -60, 60]))        # nudge the acorn cost up(-) / down(+)
			_sidebar_body.add_child(_slider_row(["cost_x", -60, 60]))        # nudge the acorn cost left(-) / right(+)
			_sidebar_body.add_child(_slider_row(["cost_scale", 30, 130]))    # the cost pill's overall size (% — shrink to fit the card)
			_section_header("Unlockable highlight (engine FX — no baked art)")
			_sidebar_body.add_child(_slider_row(["next_glow", 0, 100]))       # the unlockable cell's glow halo
			_sidebar_body.add_child(_slider_row(["next_twinkle", 0, 100]))    # ...and its drifting-star density
			_group_header("Test only — not saved", false)
			_sidebar_body.add_child(_option_row("Preview", "preview", ["unlockable", "filled", "empty", "locked"]))
			_sidebar_body.add_child(_slider_row(["level", 0, 25]))           # 0 = no level badge; >0 docks it (board)
			_sidebar_body.add_child(_slider_row(["cost", 0, 999]))           # 0 = no cost; >0 shows the acorn cost (bag)
		"bag":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["width_pct", 40, 100]))   # % of the screen width (responsive)
			_sidebar_body.add_child(_slider_row(["cols", 1, 8]))
			_sidebar_body.add_child(_slider_row(["cell_gap", 0, 40]))
			_sidebar_body.add_child(_slider_row(["grid_inset", 0, 200]))    # how far the parchment border eats the grid width
			_sidebar_body.add_child(_slider_row(["row_gap", 0, 40]))        # gap between pill / grid / footer
			_sidebar_body.add_child(_slider_row(["list_max_h", 0, 1200]))   # height cap; 0 = no scroll
			_sidebar_body.add_child(_text_row("Caption", "caption"))
			_group_header("Test only — not saved", false)                  # the game sets each from save
			_sidebar_body.add_child(_slider_row(["balance", 0, 9999]))      # the 💎 acorn balance the pill shows
			_sidebar_body.add_child(_slider_row(["owned", 0, 18]))          # how many slots are owned
			_sidebar_body.add_child(_slider_row(["filled", 0, 18]))         # how many owned slots hold a piece
		"quest_card":
			# The LAYOUT block (card_w..plaque_y) are the giver-card fractions, in PERCENT. They are SAVED to
			# config; the board reads them live via Kit.giver_lay_from_config, so a tweak here flows straight to
			# the live giver card on Save. (giver_stand.LAY stays the shipped fallback for an empty config.)
			_group_header("Layout — saved to config (board reads it live)", true)
			_sidebar_body.add_child(_slider_row(["card_w", 40, 300]))      # box width  (% of stand) — independent of height
			_sidebar_body.add_child(_slider_row(["card_h", 40, 300]))      # box height (% of stand) — independent of width
			_section_header("Card 9-slice (source px — corners stay crisp)")
			_sidebar_body.add_child(_slider_row(["card_slice_l", 0, 120]))  # left patch margin (keeps the L frame + side tab base)
			_sidebar_body.add_child(_slider_row(["card_slice_t", 0, 100]))  # top patch margin (keeps the wood top + peg holes)
			_sidebar_body.add_child(_slider_row(["card_slice_r", 0, 120]))  # right patch margin
			_sidebar_body.add_child(_slider_row(["card_slice_b", 0, 100]))  # bottom patch margin (bracket the leaf sprig)
			_section_header("Quest giver")
			_sidebar_body.add_child(_slider_row(["bust_size", 50, 160]))   # size (% of box height)
			_sidebar_body.add_child(_slider_row(["bust_x", 0, 100]))       # centre x (% of box width)
			_sidebar_body.add_child(_slider_row(["bust_y", 0, 100]))       # centre y (% of box height)
			_section_header("Speech bubble")
			_sidebar_body.add_child(_slider_row(["bubble_size", 30, 100])) # size (% of box height)
			_sidebar_body.add_child(_slider_row(["bubble_x", 0, 100]))     # centre x (% of box width)
			_sidebar_body.add_child(_slider_row(["bubble_y", 0, 100]))     # centre y (% of box height)
			_section_header("Item icon")
			_sidebar_body.add_child(_slider_row(["item_size", 10, 150]))   # uniform size (% of box height) — drives item_w == item_h, so the item stays square
			_sidebar_body.add_child(_slider_row(["item_x", 0, 100]))       # centre x (% of box width)
			_sidebar_body.add_child(_slider_row(["item_y", 0, 100]))       # centre y (% of box height)
			_section_header("Plaque")
			_sidebar_body.add_child(_slider_row(["plaque_w", 20, 90]))     # width (% of box width)
			_sidebar_body.add_child(_slider_row(["plaque_x", 0, 100]))     # centre x (% of box width)
			_sidebar_body.add_child(_slider_row(["plaque_y", 0, 100]))     # centre y (% of box height)
			_group_header("Demo (preview only)", false)
			_sidebar_body.add_child(_slider_row(["bust", 0, 15]))          # which giver (0..15) — also the asked line
			_sidebar_body.add_child(_slider_row(["tier", 1, 12]))          # the asked item's tier
			_sidebar_body.add_child(_slider_row(["stars", 1, 99]))         # the +N reward on the plaque
			_sidebar_body.add_child(_slider_row(["stand_w", 200, 640]))    # preview stand width
			_sidebar_body.add_child(_slider_row(["fence_h", 160, 460]))    # preview stand height
			_sidebar_body.add_child(_toggle_row("Ready (✓)", "met"))       # preview the deliverable state

## A bold top-level group header — the two buckets: gold ● = saved to config, dim ○ = test-only.
func _group_header(title: String, saved: bool) -> void:
	_sidebar_body.add_child(HSeparator.new())
	var l := Label.new()
	l.text = ("●  " if saved else "○  ") + title
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Pal.STRAW if saved else Color(Pal.CREAM, 0.5))
	_sidebar_body.add_child(l)

## A small section header in the sidebar (a separator + an accent label), to group settings.
func _section_header(title: String) -> void:
	_sidebar_body.add_child(HSeparator.new())
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Pal.STRAW)
	_sidebar_body.add_child(l)

## The shared FRAME's options: the saved-to-config bucket (sub-grouped by function), then test-only.
func _frame_sidebar() -> void:
	_group_header("Saved to config", true)
	_section_header("Card")
	_sidebar_body.add_child(_slider_row(["width", 360, 720]))
	_sidebar_body.add_child(_option_row("Border", "border", Kit.FRAME_BORDERS.keys()))   # parchment / vault twig
	_sidebar_body.add_child(_toggle_row("9-slice art", "card_art", true))   # rebuilds the sidebar to swap the slider
	if bool(_params["frame"]["card_art"]):
		for k in ["card_slice_l", "card_slice_t", "card_slice_r", "card_slice_b"]:
			_sidebar_body.add_child(_slider_row([k, 0, 200]))
		_sidebar_body.add_child(_option_row("H stretch", "card_h_stretch", ["stretch", "tile", "tile_fit"]))
		_sidebar_body.add_child(_option_row("V stretch", "card_v_stretch", ["stretch", "tile", "tile_fit"]))
	else:
		_sidebar_body.add_child(_slider_row(["card_corner", 0, 60]))

	_section_header("Banner")
	_sidebar_body.add_child(_slider_row(["banner_font", 16, 56]))
	_sidebar_body.add_child(_slider_row(["banner_h", 50, 160]))
	_sidebar_body.add_child(_slider_row(["banner_text_x", -150, 150]))
	_sidebar_body.add_child(_slider_row(["banner_text_y", -80, 80]))
	_sidebar_body.add_child(_slider_row(["banner_burn", 0, 100]))   # engrave intensity (0 = off)
	_sidebar_body.add_child(_toggle_row("Banner icon", "banner_icon_on"))
	_sidebar_body.add_child(_slider_row(["banner_icon", 24, 110]))
	_sidebar_body.add_child(_slider_row(["banner_x", -200, 200]))
	_sidebar_body.add_child(_slider_row(["banner_y", -120, 120]))
	_sidebar_body.add_child(_slider_row(["banner_icon_x", 0, 700]))
	_sidebar_body.add_child(_slider_row(["banner_icon_y", 0, 160]))

	_section_header("Close")
	_sidebar_body.add_child(_slider_row(["close_size", 30, 96]))
	_sidebar_body.add_child(_slider_row(["close_x", -100, 100]))
	_sidebar_body.add_child(_slider_row(["close_y", -100, 100]))

	_section_header("List")
	_sidebar_body.add_child(_slider_row(["list_max_h", 0, 900]))
	_sidebar_body.add_child(_slider_row(["list_top_pad", -80, 200]))   # gap above row 1 (negative tucks it up)

	_group_header("Test only — not saved", false)
	_sidebar_body.add_child(_slider_row(["snap", 1, 40]))            # the drag-to-move grid

## The VAULT dialog's own knobs — layout + the twig-border slice/pad. The banner / ✕ styling is
## inherited from the Frame item (like every dialog), so it isn't repeated here.
func _vault_sidebar() -> void:
	_group_header("Saved to config", true)
	_section_header("Layout")
	_sidebar_body.add_child(_slider_row(["width_pct", 40, 100]))   # % of the screen width (responsive)
	_sidebar_body.add_child(_slider_row(["jar_px", 120, 320]))
	_sidebar_body.add_child(_slider_row(["plate_px", 120, 340]))
	_sidebar_body.add_child(_slider_row(["balance_font", 18, 56]))
	_sidebar_body.add_child(_slider_row(["row_gap", 4, 40]))
	_section_header("Border (twig panel)")
	_sidebar_body.add_child(_slider_row(["card_slice", 0, 160]))
	_sidebar_body.add_child(_slider_row(["panel_pad_x", 0, 140]))
	_sidebar_body.add_child(_slider_row(["panel_pad_y", 0, 140]))
	_group_header("Test only — not saved", false)
	_sidebar_body.add_child(_slider_row(["balance", 0, 999]))       # the previewed gem read
	_sidebar_body.add_child(_toggle_row("Claimable", "claimable"))  # toggles the CTA dim + hint

func _slider_row(spec: Array) -> Control:
	var key: String = spec[0]
	var lo: float = float(spec[1])
	var hi: float = float(spec[2])
	var params: Dictionary = _params[_selected]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = key.replace("_", " ").capitalize()
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.value = float(params[key])
	params[key] = s.value          # keep the param in sync if the value was out of range (clamped)
	s.custom_minimum_size = Vector2(0, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := Label.new()
	val.text = "%d" % int(params[key])
	val.custom_minimum_size = Vector2(44, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		params[key] = x
		val.text = "%d" % int(x)
		_apply_edit())
	return row

func _text_row(label: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var le := LineEdit.new()
	le.text = String(_params[_selected].get(key, ""))
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(t: String) -> void:
		_params[_selected][key] = t
		_apply_edit())
	row.add_child(le)
	return row

func _toggle_row(label: String, key: String, rebuild_sidebar := false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var cb := CheckButton.new()
	cb.button_pressed = bool(_params[_selected].get(key, false))
	cb.toggled.connect(func(on: bool) -> void:
		_params[_selected][key] = on
		_apply_edit()
		if rebuild_sidebar:
			_rebuild_sidebar.call_deferred())   # defer — we're inside this toggle's own signal
	row.add_child(cb)
	return row

func _option_row(label: String, key: String, options: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var ob := OptionButton.new()
	var cur := String(_params[_selected].get(key, options[0]))
	for i in options.size():
		ob.add_item(String(options[i]).capitalize(), i)
		if String(options[i]) == cur:
			ob.select(i)
	ob.item_selected.connect(func(idx: int) -> void:
		_params[_selected][key] = String(options[idx])
		_apply_edit())
	row.add_child(ob)
	return row

## --- persistence -------------------------------------------------------------------------------

## Is this element/key a persisted design setting (vs transient test scaffolding from TEST_KEYS)?
func _is_config(id: String, key: String) -> bool:
	return not (key in TEST_KEYS.get(id, []))

func _save_settings() -> void:
	# write ONLY the config bucket — test/preview scaffolding (button icon, dialog entries, …) is excluded
	var out := {}
	for id in _params.keys():
		var sub := {}
		for k in (_params[id] as Dictionary).keys():
			if _is_config(id, k):
				sub[k] = _params[id][k]
		out[id] = sub
	var f := FileAccess.open(SETTINGS, FileAccess.WRITE)
	if f == null:
		push_warning("UI Workbench: could not write %s" % SETTINGS)
		return
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	Kit.clear_config_cache(SETTINGS)   # so any live Kit reader picks up the new file (not the stale cache)
	print("WORKBENCH: settings saved -> %s" % SETTINGS)

## Merge the saved file over the defaults, copying ONLY config keys present in both — so test
## scaffolding is never restored, and an older or newer settings file can't corrupt the live schema.
func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS):
		return
	var f := FileAccess.open(SETTINGS, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not (data is Dictionary):
		return
	# MIGRATION: the shared frame's keys used to live under "dialog"; they're a standalone "frame" now.
	# An older file has them under "dialog" — lift those into "frame" so prior tuning isn't lost.
	if data.has("dialog") and data["dialog"] is Dictionary and not data.has("frame"):
		var fr := {}
		for k in (_params["frame"] as Dictionary).keys():
			if (data["dialog"] as Dictionary).has(k):
				fr[k] = data["dialog"][k]
		if not fr.is_empty():
			data["frame"] = fr
	for id in _params.keys():
		if data.has(id) and data[id] is Dictionary:
			for k in (_params[id] as Dictionary).keys():
				if _is_config(id, k) and (data[id] as Dictionary).has(k):
					_params[id][k] = data[id][k]
