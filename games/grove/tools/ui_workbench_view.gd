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
const FX = preload("res://engine/scripts/ui/fx.gd")
const FxWorkbenchView = preload("res://games/grove/tools/fx_workbench_view.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")   # kit-relative art paths (Look.kit) for the polish source
const GiverStand = preload("res://engine/scripts/ui/giver_stand.gd")   # the quest-giver card builder (board reskin)
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")     # merge pieces for the Board preview
const LoginMystery = preload("res://engine/scripts/ui/login_mystery.gd")  # the mystery spin-reveal dialog (build_reveal)
const Login = preload("res://engine/scripts/core/login.gd")            # mystery_config(slot) → the demo pool for the preview
const Pal = Game.PALETTE
# Demo merge pieces for the Board preview — [row, col, item code]; cells outside the grid are skipped.
const BOARD_DEMO := [[1, 1, 101], [1, 2, 101], [2, 3, 102], [3, 2, 103], [4, 4, 102], [5, 1, 104], [6, 5, 101], [2, 5, 103]]
const SETTINGS := "res://games/grove/tools/ui_workbench_settings.json"   # persisted params (in the repo)
const PHONE_W := 1080.0   # the project's portrait base width; dialog widths are a % of it (and of the live
                          # screen in-game), so the workbench previews the same responsive width the game uses
const PHONE_H := 1920.0   # the project's portrait base height; the map card's height is a % of it (see map_card)

const IDS := ["board", "fx", "generator", "button", "home_button", "hud_layout", "icon", "gold_badge", "level_badge", "progress_bar", "card", "daily_card", "toggle_card", "bag_card", "map_card", "quest_card", "frame", "dialog", "daily", "mystery", "shop", "level", "tiers", "gold_currency_pill", "info_bar", "settings", "vault", "info", "bag"]
# Gallery layout: TWO side-by-side COLUMNS. The LEFT column is the building-block components, ALWAYS ONE
# element per row (each on its own line). The RIGHT column leads with the Board preview, then stacks every
# DIALOG in a single column. Each column is a list of ROWS; a row CAN hold side-by-side elements (the right
# column may), but the left column never pairs — one per row. Splitting dialogs into their own column keeps
# them grouped and balances the gallery's height (the tall dialogs no longer each span a full-width row).
const COLUMNS := [
	# the building blocks — one element per row (the HUD gold currency pill lives here too, as a reusable atom).
	[["shadow"], ["generator"], ["home_button"], ["hud_layout"], ["button"], ["gold_badge"], ["level_badge"], ["gold_currency_pill"], ["icon"], ["card"], ["daily_card"], ["toggle_card"], ["bag_card"], ["map_card"], ["quest_card"], ["info_bar"], ["frame"], ["progress_bar"]],
	# the RIGHT column: the Board preview LEADS it — the live merge grid you size with the scale / item-width
	# knobs — then every dialog stacked below.
	[["board"], ["fx"], ["dialog"], ["daily"], ["mystery"], ["shop"], ["level"], ["tiers"], ["settings"], ["vault"], ["info"], ["bag"]],   # board + FX + dialogs, settings, vault, info, bag
]
# Editing element X must also refresh the elements that COMPOSE from it (derived from the kit's
# opts-builders): the Button's style flows into every Claim/cost pill; the shared Frame + the small
# cards flow into the dialogs; the Badge's polish flows into the Home button. Editing anything else
# (a dialog's own width, the icon sandbox, the pill, ...) touches only itself. Used to rebuild just the
# edited element + its dependents instead of the whole gallery.
const DEPENDENTS := {
	"button": ["card", "dialog", "daily", "shop", "settings", "info"],
	"card": ["dialog", "daily", "shop", "settings", "info"],
	"frame": ["dialog", "daily", "mystery", "shop", "settings", "bag", "tiers", "info"],
	"daily_card": ["daily", "shop"],
	"toggle_card": ["settings"],
	"home_button": ["info_bar"],
	"hud_layout": ["info_bar"],
	"gold_badge": ["board", "info_bar", "map_card"],
	# the slot cell backs the bag dialog, the discovery ladder (inherits its look), AND the Board preview's wells — editing it rebuilds all
	"bag_card": ["bag", "tiers", "board"],
	"gold_currency_pill": ["bag", "info_bar"],   # bag balance + info bar margins borrow the gold pill padding
}
# Badge backgrounds live in the kit now (Kit.BADGES) so the game resolves them from the same map.
# Icons the button can show (all resolve via the kit's _icon_tex); "none" = no icon.
const ICONS := ["none", "coin", "gem", "bluegem", "water", "leaf", "gift", "star", "daisy", "faucet", "rain", "news", "mail"]
# Icons the HOME button can show (the home page's rail + nav set; all resolve via the kit's _icon_tex).
const HOME_ICONS := ["gear", "shop", "map", "piggy", "gift", "faucet", "mail", "daisy", "leaf"]
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
	"fx": [],
	# the GENERATOR highlight sandbox: glow / outline / sparkle knobs persist (they flow to the live board
	# via Kit.gen_highlight_opts_from_config); `preview` (which generator) and `cell` (preview size) are test-only.
	"generator": ["preview", "cell"],
	# the Button is a shared-STYLE sandbox: only shadow / use-art / font are real config. Its text, bg,
	# icon, badge, corner are test props — the REAL text/badge/icon for the game live on the Card.
	"button": ["text", "bg", "icon", "icon_size", "enabled", "corner", "badge"],
	# the HOME button is a shared-STYLE sandbox: size / icon scale / caption look / badge offset / SPARKLE
	# persist. The previewed icon, caption text, sparkle toggle + sample badge count are test props.
	"home_button": ["icon", "caption", "sparkle", "badge_count", "count"],
	"hud_layout": [],
	"icon": ["defringe", "feather", "supersample", "shadow"],
	"progress_bar": ["frac"],              # frac is a preview slider; height/art/star_knob are the saved style
	"badge": [],                           # the disc-shell polish is SAVED — the home button reads it
	"gold_badge": ["px"],                  # px is preview-only; inset + shine are saved and shared by board/info
	"gold_currency_pill": ["icon", "count"],   # standalone pill study; sample icon/count are preview-only
	"card": [],
	"daily_card": ["preview", "ribbon", "sparkle"],   # preview/ribbon view toggles; sparkle is NOT saved (always on in-game)
	"frame": ["snap", "preview_text"],     # snap is the drag-grid helper; preview_text is sample title text — neither saved
	"dialog": ["entries"],
	"daily": [],
	# the MYSTERY spin-reveal dialog has no own saved knobs — it inherits the shared frame (edited on the
	# Frame item) and sizes by the engine's min(560, 94%) rule; `preview` just picks which pool + state to show.
	"mystery": ["preview"],
	"shop": [],
	"level": ["preview_level", "into", "span", "mode"],   # preview state (level / progress / which mode)
	# the LAYERED level badge — every position/size knob (incl. circle_design + num_burn) is saved design;
	# only preview_level (drives the tier stage + the printed number) is workbench-only.
	"level_badge": ["preview_level"],
	"tiers": [],
	# the bottom-bar INFO BAR — the LAYOUT (height · inner scale · fonts · separation · sell button) persists;
	# the FRAME is the shared gold badge skin; gold_currency_pill padding controls its content margin. `filled` previews the
	# selected-vs-empty state (the game fills it from the tapped board item).
	"info_bar": ["filled"],
	"toggle_card": ["label", "value"],   # sample row content (label + on/off) — preview only, not saved
	# the map-select place-picker card — the STYLE (art · frame inset · art radius · pill metrics · §8
	# veil look) persists; open/done/zone progress just preview the card (the game sets each from map state).
	"map_card": ["open", "done", "owned_zones", "total_zones"],
	# the quest-giver card — the LAYOUT block (card/bust/bubble/item/plaque fractions) IS saved config now:
	# the board reads it via Kit.giver_lay_from_config, so a tweak here flows to the live giver card. Only
	# the DEMO knobs are test-only (which bust, the asked tier/reward, the board-given size, the ready ✓).
	"quest_card": ["bust", "tier", "stars", "stand_w", "fence_h", "met"],
	"settings": [],
	"info": [],   # the demo line items are fixed in the preview; every knob is saved style
	"vault": ["balance", "claimable"],   # the previewed gem read + the claimable gate — preview only
	# the bag CELL — the cell STYLE persists; `preview` just picks which state (filled/empty/next/locked) to show.
	"bag_card": ["preview", "level", "cost"],
	# the bag DIALOG — grid/caption persist; balance/owned/filled just preview the slot ladder (the game
	# sets each from save: the 💎 balance, how many slots owned, how many hold a piece).
	"bag": ["balance", "owned", "filled"],
}
const CAPTIONS := {
	"shadow": "Shadow — the SHARED drop shadow (offset · blur · spread) every component casts",
	"board": "Board — merge grid (frame · cells · pieces · scale + item width)",
	"fx": "FX Workbench — reward arrivals in board, map, and home context",
	"generator": "Generator — board producer (glow · silhouette outline · sparkle)",
	"button": "Button — shared (bg · icon · state)",
	"home_button": "Home button — rail + nav (shell · icon · sparkle)",
	"hud_layout": "HUD layout — screen-width slots for top bar, side rail, board stack, and board bottom bar",
	"icon": "Icon — edge polish (raw vs cleaned)",
	"gold_badge": "Gold badge — CSS port",
	"level_badge": "Level badge — layered emblem (circle·leaf·flower·acorn·gem + number)",
	"gold_currency_pill": "Gold currency pills — home wallet",
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
	"mystery": "Mystery — slot reveal (reels spin · premium shines · pick N)",
	"shop": "Shop — packs (shared frame)",
	"level": "Level — dialog (medallion · bar · collect)",
	"tiers": "Discovery — tier ladder (shared frame, no vines)",
	"info_bar": "Info bar — board bottom action bar (Bag · ⓘ · selected piece · Home)",
	"settings": "Settings — toggles (shared frame)",
	"vault": "Vault — piggy bank (twig border)",
	"info": "Info — detail sheet (mail dialog · no Claim · Got it)",
	"bag": "Bag — slot grid (shared frame · acorn pill)",
}
var _params := {
	# the SHARED SHADOW — ONE box-shadow definition every component casts (via its Shadow toggle). Offset-
	# based, so the same numbers read consistently on a small icon or a large badge. offset_x/y + blur +
	# spread are px; alpha + warmth are percent. Defaults reproduce the shipped soft drop beneath.
	"shadow": {"offset_x": 0, "offset_y": 4, "blur": 14, "spread": 4, "alpha": 34, "warmth": 82},
	# the BOARD preview — a live merge grid (bamboo frame · the shared slot-cell well · demo pieces). Two
	# INDEPENDENT size knobs: `scale` zooms the whole composition (frame + cells together, in %); `cell` is
	# the item width in px (the grid grows, the frame thickness stays), so you trade item size vs frame weight.
	# `item` = the piece sprite size as a % of its cell; gap/frame/cols/rows shape the grid. Preview only.
	"board": {"scale": 100, "cell": 52, "gap": 7, "cols": 7, "rows": 9, "frame": 60, "item": 68, "pieces": true,
		# the board FRAME (Kit.board_panel): "badge" = the shared gold badge skin; "code" = a code-drawn depth
		# border. frame_corner + the drop shadow apply to both; border_w / inner_w / top_shadow are code-only.
		"frame_style": "badge", "frame_corner": 46,
		"frame_border_w": 4, "frame_inner_w": 0, "frame_top_shadow": 0},
	"fx": {"shadow": false},
	# the GENERATOR highlight — the glow halo / silhouette outline / sparkle drawn by engine make_generator.
	# Saved knobs (glow_scale %, glow_a %, outline_w per-mille of cell, outline_a %, sparkle_count, sparkle_speed
	# /100 cyc/s) flow to the LIVE board via Kit.gen_highlight_opts_from_config; defaults mirror piece_view's
	# GEN_* consts. `preview` (which generator) + `cell` (preview px) are test-only.
	"generator": {"glow_scale": 100, "glow_a": 30, "outline_w": 35, "outline_a": 85, "sparkle_count": 5, "sparkle_speed": 70,
		"preview": "seed_satchel", "cell": 170},
	"button": {"text": "Claim", "bg": "green", "icon": "none", "icon_size": 30, "enabled": true, "font": 22, "corner": 16, "art": true, "shadow": false, "badge": "auto"},
	# the HOME button — the round icon button shared by the side rail + bottom nav. px / icon_scale /
	# caption_font / caption_gap / glow / twinkle are the saved STYLE; icon / caption / sparkle preview it.
	# Its shell edge polish (defringe / feather) lives under this item's Shell-polish knobs (saved as
	# config["badge"]); its icon uses the global icon clean.
	"home_button": {"px": 140, "icon_scale": 50, "caption_font": 22, "caption_gap": 4, "caption_pad_x": 30, "caption_pad_y": 8,
		"fill_alpha": 100, "rect_pad": 13, "play_px": 188,
		"badge_dx": -26, "badge_dy": -26, "badge_dot_px": 14, "badge_num_size": 14, "glow": 45, "twinkle": 55,
		"count_dx": 0, "count_dy": 38, "count_font": 26,
		"icon": "gift", "caption": "Daily", "sparkle": true, "badge_count": 3, "count": "1/6"},
	"hud_layout": {"level_w_pct": 25, "currency_area_pct": 75, "currency_pill_w_pct": 25,
		"edge_margin_px": 18,
		"top_band_h_pct": 15, "button_w_pct": 15, "info_bar_w_pct": 70,
		"quest_bar_x_pct": 3, "quest_bar_y_pct": 17, "quest_bar_h_pct": 11,
		"board_x_pct": 12, "board_y_pct": 30, "board_h_pct": 48},
	"icon": {"defringe": false, "feather": 1, "supersample": 1, "shadow": false},
	# the BADGE — the home button's disc shell, extracted as its own polish sandbox (defringe / shadow /
	# feather, like the Icon item). SAVED, and the home button reads it so a tweak flows to the rail + nav.
	"badge": {"defringe": false, "shadow": false, "feather": 0},
	"gold_badge": {"px": 270, "inner_inset": 11, "shine": 100, "corner": 58, "gradient": 100},
	"gold_currency_pill": {"icon": "water", "count": 2450, "overall_scale": 100, "pill_w": 292, "pill_h": 100,
		"pad_left": 18, "pad_x": 16, "pad_y": 12, "icon_box": 54, "icon_size": 34, "icon_x": 0,
		"amount_w": 88, "num_size": 30, "amount_x": 0,
		"gap": 12, "plus_x": 0, "plus_radius": 28, "plus_shine": 32,
		"plus_stroke": 2, "plus_font": 70, "plus_button": 100, "plus_round": 8, "plus_hue": 65,
		"plus_label_y": 0,
		"inner_shadow": 30, "shadow_alpha": 34},
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
		"banner_text_pad_l": 50, "banner_text_pad_r": 50,   # title↔tail room (the auto-sizing ribbon's L/R padding)
		"banner_x": 0, "banner_y": 0,
		"banner_icon_x": 130, "banner_icon_y": 19,
		"close_size": 64, "close_x": 12, "close_y": 12, "snap": 8,
		"list_max_h": 0, "list_top_pad": 0,
		"preview_text": "Frame",   # TEST-only: type any title to preview the ribbon's letter-count width-scaling
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
	# the MAP-SELECT place-picker card (spec §8). card_w_frac / card_h_frac SIZE the card as a % of the
	# screen (width % of screen width — smaller = wider side margins; height % of screen height). The rest
	# mirror the shipped §8 constants, so the saved block the game's map.gd reads renders the card until you
	# change it. Fracs are scaled integers for the sliders (fracs + veil alphas in percent — see
	# Kit.map_card_opts_from_config). open/done/zone progress are preview-only (the game sets each per map).
	"map_card": {"use_art": true, "card_w_frac": 96, "card_h_frac": 16, "edge_sparkle": 60,
		"pill_w_frac": 30, "pill_min": 170, "pill_max": 290, "pill_y_frac": 13, "veil_mark_size": 64,
		"open": true, "done": false, "owned_zones": 0, "total_zones": 6},
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
	# the MYSTERY spin-reveal dialog (login_mystery.gd) — the shared frame + a row of reward cards the spin
	# lands on. NO saved knobs (the frame is the shared one; width is the engine's min(560, 94%) cap). `preview`
	# picks the pool (day 4 = 3 cards/1 win · day 7 = 5 cards/2 wins) and the state (all shown · winners landed).
	"mystery": {"preview": "day 7 · revealed"},
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
	# piece size + well art are INHERITED from the Slot cell item; only the discovery-specific knobs live
	# here — the square cell size, plain tier number, and marked-tier sparkle (percents for the sliders).
	# The grid fills the frame's inner width, derived from the Frame's chosen border padding.
	"tiers": {"width_pct": 85, "cols": 3, "cell_gap": 16, "list_max_h": 0,
		"cell_w": 150, "cell_h": 150, "show_num": true, "mark_glow": 60, "mark_twinkle": 50},
	# the LAYERED level badge — five cut parts (ui/lvl_parts) composited bottom-up + the level number.
	# Every position/size knob is a PERCENT of the badge px (so the emblem scales to any size); they map
	# 1:1 to Kit.level_badge_opts_from_config, the SAME resolver the HUD chip / level dialog
	# read. The preview shows ALL parts at once (so you can position them together); preview_level drives
	# the tier stage + the printed number. circle_design pins the coin (auto = grow with tier); num_burn is
	# the engraved burn on the number.
	"level_badge": {"size": 100, "num_size": 32, "num_x": 0, "num_y": -16, "num_burn": 0,
		"circle_base": true, "circle_design": "auto",
		"circle_x": 0, "circle_y": -4, "circle_scale": 90,
		"leaf_x": 0, "leaf_y": 0, "leaf_scale": 100,
		"flower_x": 0, "flower_y": -10, "flower_scale": 48,
		"acorn_x": 0, "acorn_y": -8, "acorn_scale": 52,
		"gem_x": 0, "gem_y": -40, "gem_scale": 36,
		"preview_level": 30},
	# the bottom-bar INFO BAR — the LAYOUT is the saved design; the frame is the shared gold badge skin.
	# height matches the Bag/Home wells; inner_scale / sell_icon are % of that height. item_icon_scale is
	# % of the selected-piece box. `filled` previews state.
	"info_bar": {"height": 130, "inner_scale": 48, "item_icon_scale": 80, "info_x": 0, "name_font": 32, "sep": 10, "sell_font": 24, "sell_label_font": 22, "sell_icon": 30, "sell_badge_radius": 10, "pad_right": 16,
		"icon_scale_pct": 50, "pad_x_pct": 0, "pad_y_pct": 0, "bag_x_pct": 0, "info_x_pct": 0, "home_x_pct": 0,
		"filled": true},
	# the SETTINGS dialog = the shared frame + a column of toggle cards (one per persisted flag). width_pct
	# like every dialog; the toggle-card style lives on the Toggle card item, the chrome on the Frame item.
	"settings": {"width_pct": 80, "row_gap": 12},
	# the VAULT dialog — the shared frame in the NEW twig border + the jar hero. width_pct + the twig
	# slice/pad + the jar/plate sizes are saved; balance/claimable just preview the read. The banner / ✕
	# styling is inherited from the Frame item (like the other dialogs).
	"vault": {"width_pct": 80, "card_slice": 64, "panel_pad_x": 40, "panel_pad_y": 34,
		"jar_px": 200, "plate_px": 250, "balance_font": 34, "row_gap": 12,
		"balance": 320, "claimable": true},
	# the INFO detail sheet — now the shared MAIL DIALOG (parchment cards, NO Claim) with a "Got it" footer.
	# Its face is inherited wholesale from the Frame/Card elements; only the sheet WIDTH is info-specific (a
	# 1–2 row sheet is narrower than the inbox). Read by the game's _info_sheet via Kit.info_opts_from_config.
	"info": {"width_pct": 58},
	# the BAG CELL — the slot tile, its own component (the Bag dialog reuses it). cell size/art + the
	# content/lock/cost metrics are saved; `preview` just picks which state the standalone tile shows.
	"bag_card": {"preview": "locked", "cell_w": 116, "cell_h": 120, "cell_slice": 28, "cell_art": true,
		"content_frac": 62, "cost_font": 24, "cost_icon": 26, "cost_y": 0, "cost_x": 0, "cost_scale": 100, "level_frac": 44,
		"next_glow": 45, "next_twinkle": 55, "glow_hue": 42, "glow_sat": 74,
		"glow_size": 170, "glow_shadow": 55, "glow_shadow_size": 10,
		"open_hue": 43, "open_sat": 10, "open_val": 92,
		"frontier_hue": 45, "frontier_sat": 14, "frontier_val": 89,
		"deep_hue": 44, "deep_sat": 12, "deep_val": 85,
		"rim_hue": 89, "rim_sat": 37, "rim_val": 68, "rim_alpha": 35, "corner": 18,
		"depth": 4, "depth_alpha": 18, "cell_shadow": 16, "cell_shadow_size": 10, "cell_shadow_y": 3,
		"level": 7, "cost": 120},
	# the BAG dialog — the shared frame + the reused currency pill (acorn balance) + a grid of bag cells.
	# width_pct/cols/gaps/caption are saved; balance/owned/filled preview the slot ladder (the game sets
	# each from save). The banner / ✕ styling is inherited from the Frame item (like the other dialogs).
	"bag": {"width_pct": 85, "cols": 6, "cell_gap": 12, "grid_inset": 70, "row_gap": 14, "list_max_h": 0, "acorn_x": 0,
		"caption": "Open a slot with acorns.", "balance": 132, "owned": 8, "filled": 5},
}
var _selected := "button"
var _fx_selected := "coin_pickup"
var _focus_only := ""             # if set (a component id), _build() renders JUST that element centred — a
                                  # focused, repeatable capture (make shot-workbench EL=<id>); "" = full gallery
var _columns: Array = []          # one content VBox per gallery column (each in its OWN scroll)
var _sidebar_body: VBoxContainer = null
var _sections: Dictionary = {}    # id -> the element's gallery section (PanelContainer), for in-place rebuilds
var _dirty: Dictionary = {}       # id -> true: linked elements queued to rebuild, one per frame (coalesced)
var _awaiting: Dictionary = {}    # id -> true: elements showing a raw placeholder until a worker polish lands
var _building := ""               # the id whose section is mid-build (so the polish previews know who to await)
var _hud_board_height_auto := false
var _hud_board_x_auto := false
var _hud_board_y_auto := false
var _hud_quest_height_auto := false
var _hud_quest_y_auto := false

# drag-to-move (banner icon / ✕), with snap-to-grid
var _drag_kind := ""
var _drag_node: Control = null
var _drag_grab := Vector2.ZERO

func _ready() -> void:
	if Engine.is_editor_hint():
		theme = UiFont.make()
	_ensure_shadow_keys()
	_load_settings()
	_sync_legacy_hud_board_layout()
	_build()

## Give EVERY component a `shadow` on/off key (default ON for the elements that ship a drop shadow, OFF
## otherwise), so the universal Shadow toggle persists through _save / _load (which only round-trip keys
## present in _params). Run BEFORE _load_settings so a saved file can still override the default.
func _ensure_shadow_keys() -> void:
	var on_by_default := {"home_button": true, "board": true, "gold_badge": true}
	for id in _params.keys():
		if id == "shadow":
			continue
		if not (_params[id] as Dictionary).has("shadow"):
			_params[id]["shadow"] = bool(on_by_default.get(id, false))

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

	# FOCUS capture: render JUST one element, centred, with no sidebar/gallery chrome — a clean, repeatable
	# single-component shot (make shot-workbench EL=<id>). Used to capture the mystery spin-reveal dialog
	# (and any other component) for visual regression without cropping it out of the full gallery.
	if _focus_only != "" and IDS.has(_focus_only):
		var cc := CenterContainer.new()
		cc.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(cc)
		cc.add_child(_make_element(_focus_only))
		return

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

func _preview_screen_w() -> float:
	# The workbench window is intentionally wide so tools/dialogs fit side by side.
	# HUD previews should still use the game's portrait viewport width.
	return PHONE_W

func _gold_currency_wallet_preview(p: Dictionary) -> Control:
	var layout := Kit.hud_layout_opts_from_config({"hud_layout": _params["hud_layout"]})
	var edge := float(layout.get("edge_margin_px", 18.0))
	var pill_slot_w := maxf(1.0, roundf(_preview_screen_w() * float(layout.get("currency_pill_w_frac", 0.25))))
	var pill_body_w := maxf(1.0, pill_slot_w - edge)
	var row := HBoxContainer.new()
	row.name = "GoldCurrencyWalletPreview"
	row.add_theme_constant_override("separation", int(round(edge)))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base := Kit.gold_currency_pill_opts_from_config({
		"gold_currency_pill": p,
		"gold_badge": _params["gold_badge"],
		"shadow": _params["shadow"],
	})
	for sample in [
		{"icon": "water", "count": 100},
		{"icon": "coin", "count": 0},
		{"icon": "gem", "count": 5},
	]:
		var opts := base.duplicate()
		var icon_id := String(sample.icon)
		opts["icon"] = icon_id
		opts["count"] = int(sample.count)
		var pill := Kit.gold_currency_pill(opts, {icon_id: int(sample.count)})
		var pill_surface := pill.find_child("GoldCurrencyPill", true, false) as Control
		if pill_surface != null:
			pill_surface.custom_minimum_size = Vector2(pill_body_w, pill_surface.custom_minimum_size.y)
		pill.custom_minimum_size = Vector2(pill_body_w, pill.custom_minimum_size.y)
		row.add_child(pill)
	row.custom_minimum_size = Vector2(pill_body_w * 3.0 + edge * 2.0, row.custom_minimum_size.y)
	return row

## Build the live element for an id from its current params.
func _make_element(id: String) -> Control:
	var p: Dictionary = _params[id]
	match id:
		"shadow":
			# the SHARED shadow on its own — a CIRCLE sample and a RECT sample side by side, both casting the
			# SAME shared shadow, so the sliders' effect reads on both shapes at once (over a light cell so the
			# warm shadow shows). This is the single source of truth every other component's toggle references.
			return _shadow_preview()
		"board":
			return _make_board_preview()
		"fx":
			var fx := FxWorkbenchView.new()
			fx.name = "FxWorkbenchComponent"
			fx.embedded = true
			fx.show_sidebar = false
			fx.preview_scale = 0.68
			fx.set("_preview_action", _fx_selected)
			fx.custom_minimum_size = Vector2(540, 760)
			fx.size = fx.custom_minimum_size
			return fx
		"generator":
			# the live board generator (engine make_generator) with its highlight tuned by the knobs, through
			# the SAME Kit transform the board reads — so the preview is 1:1 with the game.
			var ghl := Kit.gen_highlight_opts_from_config({"generator": p})
			var gcell := float(p.get("cell", 170))
			var gwrap := CenterContainer.new()
			gwrap.custom_minimum_size = Vector2(gcell + 90, gcell + 90)
			gwrap.add_child(PieceView.make_generator(String(p.get("preview", "seed_satchel")), gcell, ghl))
			return gwrap
		"button":
			return Kit.pill_button(String(p.text), _btn_opts())
		"home_button":
			# the shared home button as the LIVE rail + nav + board build it, from the SAME kit transform the
			# game reads. Every live surface is a ROUNDED-RECT tile now (icon over label INSIDE the badge):
			# the bag well (in-tile "x/y" count), the rail/Map tile (caption + a red badge), plus the orange
			# Play disc. (The old circular disc-with-caption/-count form is retired — the rail moved to rect.)
			# include the shell edge polish (config["badge"], tuned under this item's Shell-polish knobs) so
			# the home button reflects it LIVE — the same link the game uses
			var ho := Kit.home_button_opts_from_config({"home_button": p, "badge": _params["badge"], "shadow": _params["shadow"]})
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 30)
			# the RECT bag well carries the Bag's in-tile "x/y" COUNT so count_dx / count_dy / count_font tune
			# live (the live bag well is this exact rect-with-count form — board.gd _home_well).
			var co := ho.duplicate()
			co["shape"] = "rect"
			row.add_child(Kit.home_button({"icon": String(p.icon), "caption": "", "count": String(p.get("count", ""))}, co))
			# the RECT rail tile as the live side rail + Map button build it (shape:"rect"): icon over label
			# INSIDE the rounded-rect, carrying a SAMPLE red badge so badge_dx / badge_dy (+ dot/num size) tune
			# live — the same Look.attach_badge the rail uses (count 0 → bare dot, ≥1 → count pill).
			var ro := ho.duplicate()
			ro["shape"] = "rect"
			var rail_btn := Kit.home_button({"icon": String(p.icon), "caption": String(p.caption), "sparkle": bool(p.sparkle)}, ro)
			var bcount := int(p.get("badge_count", 3))
			var bopts := {"dot_px": int(ho.get("badge_dot_px", 14)), "num_size": int(ho.get("badge_num_size", 14))}
			var bg := Look.badge("pill", bcount, bopts) if bcount >= 1 else Look.badge("dot", 0, bopts)
			Look.attach_badge(rail_btn, bg, Vector2(float(ho.get("badge_dx", -8)), float(ho.get("badge_dy", -8))))
			row.add_child(rail_btn)
			# the orange PLAY disc (bottom-right CTA) at its tuned size + art, so play_px adjusts live here.
			var po := ho.duplicate()
			po["px"] = float(ho.get("play_px", 188))
			po["shell"] = "shared/play_disc.png"
			po["icon_scale"] = 0.52
			row.add_child(Kit.home_button({"icon": "board", "caption": ""}, po))
			var mc := MarginContainer.new()
			mc.add_theme_constant_override("margin_bottom", int(p.caption_font) + 26)
			mc.add_child(row)
			return mc
		"hud_layout":
			return _hud_layout_preview()
		"icon":
			var box := HBoxContainer.new()
			box.add_theme_constant_override("separation", 28)
			box.add_child(_icon_preview("Raw", {"defringe": false, "feather": 0.0, "supersample": 1}))
			box.add_child(_icon_preview("Polished", {"defringe": bool(p.defringe), "feather": float(p.feather), "supersample": int(p.supersample)}))
			return box
		"gold_badge":
			return Kit.gold_badge(float(p.get("px", 270)), float(p.get("inner_inset", 11)), float(p.get("shine", 100)), float(p.get("corner", 58)), float(p.get("gradient", 100)))
		"gold_currency_pill":
			return _gold_currency_wallet_preview(p)
		"level_badge":
			# the shared LAYERED level badge, from the SAME resolver the HUD chip / dialog read.
			# preview_level -> the tier stage (+ the printed number). The workbench draws ALL parts (show_all)
			# so every part can be positioned together; the live game draws only the tier's group.
			var lbpx := 320.0
			var lopts := Kit.level_badge_opts_from_config({"level_badge": p})
			var lblvl := int(p.get("preview_level", 30))
			var lbadge := Kit.level_badge(lopts, Look.level_badge_index(lblvl), lblvl, lbpx, -1, true)
			var wrap := CenterContainer.new()
			wrap.custom_minimum_size = Vector2(lbpx + 20.0, lbpx + 20.0)
			wrap.add_child(lbadge)
			return wrap
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
			fo["banner_text"] = String(p.get("preview_text", "Frame"))   # type any title to test the ribbon width-scaling
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
		"mystery":
			# the spin-reveal dialog (login_mystery.gd build_reveal) — the SAME face the game animates, rendered
			# STATIC so it's visual-checkable. The preview picks a pool + a state; the demo roll is DETERMINISTIC
			# (no shuffle) so the capture is repeatable. Frame edits flow through via frame_cfg: _params.
			return _mystery_preview(String(p.preview))
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
			# gold frame / dark panel + the §8 veil read on their own; open/done/zone progress preview the state.
			# pass the shared gold_badge skin so the open card's frame previews the SAME tuning as board/info-bar.
			var mco := Kit.map_card_opts_from_config({"map_card": p, "gold_badge": _params["gold_badge"]})
			# preview at the SAME proportion the game lays out — card_w_frac of the screen WIDTH by
			# card_h_frac of the screen HEIGHT — scaled to the 460-px preview width, so dragging the
			# size sliders reshapes the card live (and shows any gold-frame stretch). No height cap: the
			# place-picker scrolls in-game, so a tall card previews at its true (tall) shape.
			var mw := 460.0
			var wf: float = maxf(1.0, float(p.get("card_w_frac", 96)))
			var hf: float = maxf(1.0, float(p.get("card_h_frac", 16)))
			var mh := mw * (PHONE_H * hf) / (PHONE_W * wf)
			var mdata := {"open": bool(p.open), "done": bool(p.done), "art": "",
				"owned_zones": int(p.owned_zones), "total_zones": int(p.total_zones),
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
		"info_bar":
			# The merged Workbench target previews the LIVE board bottom bar as one shared tray: Bag · Info ·
			# Home. The inner Bag/Home/Info frames are transparent so only the parent tray paints a border.
			return _action_bar_preview()
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
		"info":
			# the shop's detail sheet — now the SAME mail dialog the inbox uses (parchment cards, NO Claim)
			# with a level-style "Got it" footer, exactly what the "i" opens in-game. Demo: the Welcome
			# bundle's two line items, each amount riding a read-only cream chip.
			var iopts := Kit.info_opts_from_config(_params)
			iopts["banner_text"] = "Welcome gift"
			iopts["banner_icon_on"] = false
			iopts["got_it"] = "Got it"
			iopts["note"] = "Claimable just once — a warm start to the grove."
			iopts["on_close"] = func() -> void: print("WORKBENCH: info closed")
			var demo := [
				{"icon": "gem", "title": "Acorns", "body": "premium currency for shortcuts", "chip": {"icon": "gem", "text": "400"}},
				{"icon": "water", "title": "Water", "body": "tops up your watering can", "chip": {"icon": "water", "text": "60"}}]
			return Kit.mail_dialog(demo, _dlg_px("info"), iopts)
		"bag_card":
			# The slot tile in a chosen preview state, rendered at the original 2x Workbench preview size so
			# it stays comfortable to edit while the saved cell_w/cell_h remain the live game size.
			var bco := Kit.bag_card_opts_from_config(_params)
			var z := 2.0
			bco["cell_w"] = float(bco["cell_w"]) * z
			bco["cell_h"] = float(bco["cell_h"]) * z
			bco["cost_font"] = int(float(bco["cost_font"]) * z)
			bco["cost_icon"] = float(bco["cost_icon"]) * z
			bco["cost_y"] = float(bco["cost_y"]) * z
			bco["cost_x"] = float(bco["cost_x"]) * z   # cost_scale is a ratio; it stays unzoomed.
			return Kit.slot_cell(_bag_preview_cell(String(p.preview), int(p.level), int(p.cost)), bco)
		"bag":
			# the SHARED frame + the reused gold currency pill + a grid of bag cells (the SAME builder the game's
			# bag_overlay.gd uses). owned/filled compose the slot ladder; balance feeds the acorn pill.
			var bopts := Kit.bag_opts_from_config(_params)
			bopts["banner_text"] = "Bag"
			bopts["banner_min_w"] = PHONE_W * Kit.BANNER_MIN_W_FRAC   # 25% of the screen — matches bag_overlay.gd
			return Kit.bag_dialog(_bag_demo_entries(int(p.owned), int(p.filled)), int(p.balance), _dlg_px("bag"), bopts)
	return Control.new()

func _hud_layout_preview() -> Control:
	var p: Dictionary = _params["hud_layout"]
	var s := 0.26
	var w := PHONE_W * s
	var h := PHONE_H * s
	var root := Control.new()
	root.custom_minimum_size = Vector2(w, h)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color("#20333A")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var top_h := h * float(p.get("top_band_h_pct", 15)) / 100.0
	root.add_child(_layout_preview_box(Rect2(0, 0, w, top_h), Color("#D9E8D2", 0.18), "top %d%%" % int(p.get("top_band_h_pct", 15))))
	var level_w := w * float(p.get("level_w_pct", 25)) / 100.0
	var edge := float(p.get("edge_margin_px", 18)) * s
	root.add_child(_layout_preview_box(Rect2(0, edge, level_w, level_w), Color("#F6C76F", 0.72), "Lv %d%%" % int(p.get("level_w_pct", 25))))
	var wallet_w := w * float(p.get("currency_area_pct", 75)) / 100.0
	var wallet_x := w - wallet_w
	var pill_w := w * float(p.get("currency_pill_w_pct", 25)) / 100.0
	var pill_h := maxf(34.0, top_h * 0.46)
	var pill_body_w := maxf(1.0, pill_w - edge)
	var pill_y := edge
	for i in 3:
		root.add_child(_layout_preview_box(Rect2(wallet_x + pill_w * i, pill_y, pill_body_w, pill_h), Color("#F8F1C9", 0.82), "%d%%" % int(p.get("currency_pill_w_pct", 25))))
	var wallet_clear_y := pill_y + pill_h + edge
	var quest_x := w * float(p.get("quest_bar_x_pct", 3)) / 100.0
	if _hud_quest_y_auto:
		p["quest_bar_y_pct"] = _live_quest_y_pct()
	if _hud_quest_height_auto:
		p["quest_bar_h_pct"] = _live_quest_h_pct()
	var quest_y := maxf(_live_quest_y_px() * s, wallet_clear_y) if _hud_quest_y_auto else h * float(p.get("quest_bar_y_pct", 17)) / 100.0
	var quest_h := Kit.live_quest_bar_height() * s if _hud_quest_height_auto else h * float(p.get("quest_bar_h_pct", 11)) / 100.0
	if _hud_quest_y_auto:
		p["quest_bar_y_pct"] = clampf(roundf(quest_y / h * 100.0), 0.0, 55.0)
	var quest_w := maxf(1.0, w - quest_x * 2.0)
	root.add_child(_layout_preview_box(Rect2(quest_x, quest_y, quest_w, quest_h), Color("#E7B36B", 0.58), "quest", "HudLayoutQuestBar"))
	var live_board_size := Kit.live_board_frame_size(Vector2(PHONE_W, PHONE_H), _params) * s
	if _hud_board_x_auto:
		p["board_x_pct"] = _live_board_x_pct()
	if _hud_board_y_auto:
		p["board_y_pct"] = _live_board_y_pct()
	if _hud_board_height_auto:
		p["board_h_pct"] = _live_board_h_pct()
	var board_x := w * float(p.get("board_x_pct", 12)) / 100.0
	var board_y := maxf(_live_board_y_px() * s, quest_y + quest_h + 10.0 * s) if _hud_board_y_auto else h * float(p.get("board_y_pct", 30)) / 100.0
	var board_h := live_board_size.y if _hud_board_height_auto else h * float(p.get("board_h_pct", 48)) / 100.0
	if _hud_board_y_auto:
		p["board_y_pct"] = clampf(roundf(board_y / h * 100.0), 0.0, 75.0)
	var board_w := minf(w - board_x, live_board_size.x * board_h / maxf(1.0, live_board_size.y))
	root.add_child(_layout_preview_box(Rect2(board_x, board_y, board_w, board_h), Color("#A8D29B", 0.48), "board", "HudLayoutBoard"))
	var btn_w := w * float(p.get("button_w_pct", 15)) / 100.0
	var side_x := w - edge - btn_w
	var rail_top := wallet_clear_y
	for i in 4:
		root.add_child(_layout_preview_box(Rect2(side_x, rail_top + i * (btn_w + 8.0), btn_w, btn_w), Color("#9AD7C8", 0.72), "%d%%" % int(p.get("button_w_pct", 15))))
	var bottom_y := h - btn_w - edge
	var info_w := w * float(p.get("info_bar_w_pct", 70)) / 100.0
	root.add_child(_layout_preview_box(Rect2(0, bottom_y, btn_w, btn_w), Color("#B9D5FF", 0.72), "bag"))
	root.add_child(_layout_preview_box(Rect2(btn_w, bottom_y, info_w, btn_w), Color("#F2D59A", 0.78), "info %d%%" % int(p.get("info_bar_w_pct", 70))))
	root.add_child(_layout_preview_box(Rect2(btn_w + info_w, bottom_y, btn_w, btn_w), Color("#B9D5FF", 0.72), "home"))
	return root

func _action_bar_preview_style(bar_h: float, ao: Dictionary) -> StyleBox:
	var bopts: Dictionary = Kit.board_panel_opts_from_config(_params)
	var pad_x := roundf(bar_h * float(ao.get("pad_x_frac", 0.0)))
	var pad_y := roundf(bar_h * float(ao.get("pad_y_frac", 0.0)))
	if String(bopts.get("frame_style", "badge")) == "code":
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color("#FBF3E2")
		flat.border_color = Pal.STRAW
		flat.set_border_width_all(int(bopts.get("border_w", 4)))
		flat.set_corner_radius_all(int(bopts.get("corner", 46)))
		flat.content_margin_left = pad_x
		flat.content_margin_right = pad_x
		flat.content_margin_top = pad_y
		flat.content_margin_bottom = pad_y
		return flat
	var badge: Dictionary = (bopts.get("badge", {}) as Dictionary).duplicate() if bopts.get("badge", {}) is Dictionary else {}
	badge["content_margin_left"] = pad_x
	badge["content_margin_right"] = pad_x
	badge["content_margin_top"] = pad_y
	badge["content_margin_bottom"] = pad_y
	return Kit.gold_badge_style(badge)

func _action_bar_nudge(child: Control, x_frac: float, node_name: String) -> Control:
	if absf(x_frac) < 0.001:
		return child
	var slot := MarginContainer.new()
	slot.name = node_name
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = child.custom_minimum_size
	slot.size_flags_horizontal = child.size_flags_horizontal
	slot.size_flags_vertical = child.size_flags_vertical
	var x_px := int(roundf(maxf(1.0, child.custom_minimum_size.x) * x_frac))
	slot.add_theme_constant_override("margin_left", x_px)
	slot.add_theme_constant_override("margin_right", -x_px)
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_child(child)
	return slot

func _action_bar_clear_button_frame(b: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for st_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st_name, empty)

func _action_bar_transparent_info_frame(opts: Dictionary) -> StyleBoxEmpty:
	var empty := StyleBoxEmpty.new()
	var pad: Dictionary = opts.get("pill", {})
	var pad_x := float(pad.get("pad_x", 18.0))
	empty.content_margin_left = float(pad.get("pad_left", pad_x))
	empty.content_margin_right = float(opts.get("pad_right", 16.0))
	var vpad := float(opts.get("vpad", 8.0))
	empty.content_margin_top = vpad
	empty.content_margin_bottom = vpad
	return empty

func _action_bar_separator_preview(px: float, node_name: String) -> Control:
	var slot := CenterContainer.new()
	slot.name = node_name + "Slot"
	slot.custom_minimum_size = Vector2(maxf(18.0, px * 0.24), px)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sep := TextureRect.new()
	sep.name = node_name
	sep.custom_minimum_size = Vector2(maxf(18.0, px * 0.24), px * 0.94)
	sep.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sep.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := Look.kit("shared/action_separator.png")
	if ResourceLoader.exists(p):
		sep.texture = load(p)
	slot.add_child(sep)
	return slot

func _action_bar_preview() -> Control:
	var p: Dictionary = _params["info_bar"]
	var ao := Kit.action_bar_opts_from_config({"info_bar": p})
	var layout := Kit.hud_layout_opts_from_config({"hud_layout": _params["hud_layout"]})
	var ho := Kit.home_button_opts_from_config({"home_button": _params["home_button"], "badge": _params["badge"], "shadow": _params["shadow"]})
	var preview_w := PHONE_W
	var btn_px := maxf(80.0, float(ho.get("px", roundf(preview_w * float(layout.get("button_w_frac", 0.15))))))
	var bar_h := maxf(166.0, btn_px + 36.0)
	var sep_w := maxf(18.0, btn_px * 0.24)
	var tray_pad_x := roundf(bar_h * float(ao.get("pad_x_frac", 0.0)))
	var info_w := maxf(120.0, preview_w * float(layout.get("info_bar_w_frac", 0.70)) - sep_w * 2.0 - tray_pad_x * 2.0)

	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(preview_w, bar_h)
	bar.add_theme_stylebox_override("panel", _action_bar_preview_style(bar_h, ao))
	var row := HBoxContainer.new()
	row.name = "ActionBarPreviewRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	bar.add_child(row)

	ho["px"] = btn_px
	ho["shape"] = "rect"
	ho["shadow"] = false
	ho["icon_scale"] = float(ao.get("icon_scale", 0.5))
	var bag_btn := Kit.home_button({"icon": "bag", "caption": "", "count": "0/6"}, ho.duplicate())
	bag_btn.name = "ActionBarPreviewBag"
	_action_bar_clear_button_frame(bag_btn)
	row.add_child(_action_bar_nudge(bag_btn, float(ao.get("bag_x_frac", 0.0)), "ActionBarPreviewBagOffset"))
	row.add_child(_action_bar_separator_preview(btn_px, "ActionBarPreviewSeparatorBagInfo"))
	var io := Kit.info_bar_opts_from_config({"info_bar": _params["info_bar"], "gold_currency_pill": _params["gold_currency_pill"], "gold_badge": _params["gold_badge"], "shadow": _params["shadow"]})
	var ib: PanelContainer = Kit.info_bar({}, io)
	ib.name = "ActionBarPreviewInfoBar"
	ib.custom_minimum_size.x = info_w
	ib.add_theme_stylebox_override("panel", _action_bar_transparent_info_frame(io))
	var inner := float(ib.get_meta("inner_px", 62.0))
	var item_scale := float(ib.get_meta("item_icon_scale", 0.80))
	if bool(p.get("filled", true)):
		(ib.get_meta("info_icon") as CenterContainer).add_child(PieceView.make_piece(102, inner * item_scale))
		(ib.get_meta("name_label") as Label).text = "Hazelnut · Tier 2"
		(ib.get_meta("info_btn") as Button).disabled = false
		var sb := ib.get_meta("sell_btn") as Button
		(ib.get_meta("sell_count") as Label).text = "12"
		var demo_coin_slot := ib.get_meta("sell_coin") as Control
		demo_coin_slot.add_child(Look.icon("coin", demo_coin_slot.custom_minimum_size.x))
		sb.visible = true
	else:
		(ib.get_meta("name_label") as Label).text = "Tap an item to inspect it"
		(ib.get_meta("info_btn") as Button).disabled = true
		(ib.get_meta("sell_btn") as Button).visible = false
	row.add_child(_action_bar_nudge(ib, float(ao.get("info_x_frac", 0.0)), "ActionBarPreviewInfoOffset"))
	row.add_child(_action_bar_separator_preview(btn_px, "ActionBarPreviewSeparatorInfoHome"))
	var home_btn := Kit.home_button({"icon": "house", "caption": ""}, ho.duplicate())
	home_btn.name = "ActionBarPreviewHome"
	_action_bar_clear_button_frame(home_btn)
	row.add_child(_action_bar_nudge(home_btn, float(ao.get("home_x_frac", 0.0)), "ActionBarPreviewHomeOffset"))
	return bar

func _layout_preview_box(rect: Rect2, color: Color, text: String, node_name := "") -> Control:
	var p := PanelContainer.new()
	if node_name != "":
		p.name = node_name
	p.position = rect.position
	p.size = rect.size
	p.custom_minimum_size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = Color(Pal.CREAM, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(7)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Pal.INK if color.get_luminance() > 0.45 else Pal.CREAM)
	l.add_theme_constant_override("outline_size", 0)
	l.clip_text = true
	p.add_child(l)
	return p

func _live_board_h_pct() -> float:
	var size := Kit.live_board_frame_size(Vector2(PHONE_W, PHONE_H), _params)
	return clampf(roundf(size.y / PHONE_H * 100.0), 20.0, 70.0)

func _live_board_x_pct() -> float:
	var size := Kit.live_board_frame_size(Vector2(PHONE_W, PHONE_H), _params)
	return clampf(roundf(maxf(0.0, (PHONE_W - size.x) * 0.5) / PHONE_W * 100.0), 0.0, 40.0)

func _live_board_y_px() -> float:
	return Kit.live_board_frame_top_y(0.0)

func _live_board_y_pct() -> float:
	return clampf(roundf(_live_board_y_px() / PHONE_H * 100.0), 0.0, 75.0)

func _live_quest_y_px() -> float:
	return Kit.live_quest_bar_top_y(0.0)

func _live_quest_y_pct() -> float:
	return clampf(roundf(_live_quest_y_px() / PHONE_H * 100.0), 0.0, 55.0)

func _live_quest_h_pct() -> float:
	return clampf(roundf(Kit.live_quest_bar_height() / PHONE_H * 100.0), 5.0, 25.0)

func _hud_layout_should_auto(h: Dictionary, key: String, legacy_value: float, live_value: float) -> bool:
	if not h.has(key):
		return true
	var v := float(h.get(key, legacy_value))
	return is_equal_approx(v, legacy_value) or is_equal_approx(v, live_value)

func _sync_legacy_hud_board_layout() -> void:
	var h: Dictionary = _params["hud_layout"]
	var live_quest_y := _live_quest_y_pct()
	var live_quest_h := _live_quest_h_pct()
	var live_board_x := _live_board_x_pct()
	var live_board_y := _live_board_y_pct()
	var live_board_h := _live_board_h_pct()
	if _hud_layout_should_auto(h, "quest_bar_y_pct", 17.0, live_quest_y):
		h["quest_bar_y_pct"] = live_quest_y
		_hud_quest_y_auto = true
	if _hud_layout_should_auto(h, "quest_bar_h_pct", 11.0, live_quest_h):
		h["quest_bar_h_pct"] = live_quest_h
		_hud_quest_height_auto = true
	if _hud_layout_should_auto(h, "board_x_pct", 12.0, live_board_x):
		h["board_x_pct"] = live_board_x
		_hud_board_x_auto = true
	if _hud_layout_should_auto(h, "board_y_pct", 30.0, live_board_y):
		h["board_y_pct"] = live_board_y
		_hud_board_y_auto = true
	if _hud_layout_should_auto(h, "board_h_pct", 48.0, live_board_h):
		h["board_h_pct"] = live_board_h
		_hud_board_height_auto = true

## A faithful BOARD preview — the bamboo frame (board_frame.png nine-patch) + the cell grid (the SHARED
## slot-cell well the board + bag use) + a few demo merge pieces (PieceView), the SAME art the live board
## renders. Two INDEPENDENT size knobs: `scale` zooms the WHOLE composition (frame + cells together);
## `cell` is the item width in px (the grid grows, the frame thickness stays) — so you trade item size
## against frame weight. `item` sizes the piece sprite as a % of its cell. Pure preview; not yet wired
## into the in-game board (which still sizes itself responsively from the viewport).
## --- the SHARED shadow preview + the per-component wrap ------------------------------------------

## Components whose KIT builder already casts the shared shadow internally (from opts.shadow + shadow_params);
## the view must NOT also wrap them, or the shadow would double up. (info_bar is NOT here: it returns a
## PanelContainer and builds its own frame directly, so its shadow comes from the
## view-level wrap below, like the other unwired components.)
const SHADOW_WIRED := {"home_button": true, "board": true, "button": true, "gold_currency_pill": true}

## Cast the SHARED shadow behind a component's preview when its Shadow toggle is on. Skips the wired
## components (their builder casts it) and the Shadow item itself. A rounded-rect cast (corner ~ a card's)
## suits the panel/card/dialog family; the dedicated Shadow item demos the circular shape, and the disc
## home buttons cast their own circle via the builder.
func _maybe_wrap_shadow(el: Control, id: String) -> Control:
	if id == "shadow" or SHADOW_WIRED.has(id):
		return el
	if not bool((_params[id] as Dictionary).get("shadow", false)):
		return el
	var corner := 28.0
	if id == "gold_badge":
		var p: Dictionary = _params[id]
		corner = float(p.get("corner", 58)) * float(p.get("px", 270)) / 270.0
	return Look.with_shadow(el, corner, Look.shadow_params({"shadow": _params["shadow"]}))

## The SHARED shadow on its own — a circle sample + a rounded-rect sample, both casting it, over a light cell.
func _shadow_preview() -> Control:
	var p := Look.shadow_params({"shadow": _params["shadow"]})
	var cell := ColorRect.new()
	cell.color = Color("#EFE6D2")                # a light parchment so the dark soft shadow reads
	cell.custom_minimum_size = Vector2(560, 340)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 90)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(row)
	row.add_child(_shadow_sample(true, p))       # circular
	row.add_child(_shadow_sample(false, p))      # rounded rect
	return cell

## ONE sample for the Shadow preview: a cream disc (circular) or rounded-rect badge with the shared shadow
## cast behind it (show_behind_parent — a Panel is not a Container, so the child draws cleanly underneath).
func _shadow_sample(circular: bool, p: Dictionary) -> Control:
	var holder := CenterContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := Panel.new()
	var box_px := 150.0
	box.custom_minimum_size = Vector2(box_px, box_px)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.CREAM
	sb.border_color = Pal.STRAW
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(box_px / 2.0) if circular else 34)
	box.add_theme_stylebox_override("panel", sb)
	var sh := Look.shadow_circle(box_px, p) if circular else Look.shadow_rect(34.0, p)
	sh.show_behind_parent = true
	box.add_child(sh)
	holder.add_child(box)
	return holder

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

	# the board frame + its drop shadow — the SHARED Kit.board_panel, the SAME builder the live board uses,
	# so this preview shows the ACTUAL border (the gold badge skin, or the code-drawn depth border per the knobs).
	root.add_child(Kit.board_panel(total, Kit.board_panel_opts_from_config({"board": p, "gold_badge": _params["gold_badge"], "shadow": _params["shadow"]})))

	# the wells — the SHARED slot cell (Kit.slot_cell), at the LIVE Slot-cell (bag_card) style. Preview the
	# board's outer locked/frontier cells too, so Slot-cell locked-background knobs are visible on Board.
	var opts: Dictionary = Kit.bag_card_opts_from_config(_params)
	opts["cell_w"] = cell
	opts["cell_h"] = cell
	var demo_by_cell := {}
	var inset: float = clampf((1.0 - float(p.item) / 100.0) / 2.0, 0.0, 0.45)
	if bool(p.pieces):
		for d in BOARD_DEMO:
			var dr: int = int(d[0])
			var dc: int = int(d[1])
			if dr < rows and dc < cols:
				demo_by_cell["%d,%d" % [dr, dc]] = int(d[2])
	for r in rows:
		for c in cols:
			var cell_data := {"state": "empty"}
			var demo_key := "%d,%d" % [r, c]
			if demo_by_cell.has(demo_key):
				var piece_code: int = int(demo_by_cell[demo_key])
				cell_data = {"state": "filled", "make_content": func(_px: float) -> Control:
					return PieceView.make_piece(piece_code, cell, inset)}
			elif r == 0 and c == 0:
				cell_data = {"state": "unlockable", "frontier": true}
			elif r == 0 or c == 0:
				cell_data = {"state": "locked", "frontier": true}
			elif r == rows - 1 or c == cols - 1:
				cell_data = {"state": "locked", "frontier": false}
			var well: Control = Kit.slot_cell(cell_data, opts)
			well.position = Vector2(frame + c * (cell + gap), frame + r * (cell + gap))
			well.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(well)
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

## The MYSTERY slot-reveal dialog, rendered STATIC for a repeatable visual check (T54). `which` selects
## the pool (day 4 = 3 reels / pick 1 · day 7 = 5 reels / pick 2) and the state: "revealed" = every reel
## landed with the premium ones shining (the end of the spin); "pick" = the pick phase, one reel already
## selected + the Claim button. The reels are DETERMINISTIC (first `show` pool entries — no shuffle), and
## "▶ Play spin" (sidebar) replays the real animation on this element. Reuses LoginMystery.build_reveal,
## so it's byte-for-byte the dialog the game opens; frame_cfg: _params flows live Frame edits through.
func _mystery_preview(which: String) -> Control:
	var slot := 4 if which.begins_with("day 4") else 7
	var pick_state := which.ends_with("pick")
	var mc: Dictionary = Login.mystery_config(slot)
	var pool: Array = mc.get("pool", [])
	var show: int = mini(int(mc.get("show", 0)), pool.size())
	var win: int = mini(int(mc.get("win", 0)), show)
	var options: Array = []
	for i in show:
		options.append(pool[i])                       # first `show` (deterministic — the live roll shuffles)
	var built: Dictionary = LoginMystery.build_reveal(options, range(win), LoginMystery.reveal_width(PHONE_W), {"frame_cfg": _params})
	var reels: Array = built["reels"]
	var dialog: Control = built["dialog"]
	LoginMystery.reveal_static(reels)                 # land + shine the premium reels (end-of-spin look)
	if pick_state:
		var noop := func(_p: Array) -> void: pass
		LoginMystery.enter_pick(reels, win, built["caption"], built["claim"], noop)
		if reels.size() >= 2:
			((reels[1] as Control).get_meta("tap") as Button).pressed.emit()   # preview one chosen
	dialog.set_meta("reels", reels)                   # so "▶ Play spin" can replay on this element
	return dialog

## "▶ Play spin" — replay the REAL reel animation on the live Mystery preview element (find the dialog
## carrying the reels, reset + spin). Lets the owner watch + tune the spin pacing in the workbench.
func _play_mystery_spin() -> void:
	var sec: Variant = _sections.get("mystery")
	if sec == null:
		return
	for n in (sec as Control).find_children("*", "Control", true, false):
		if (n as Control).has_meta("reels"):
			LoginMystery.replay_spin(n, (n as Control).get_meta("reels"))
			return

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
		"shadow_params": Look.shadow_params({"shadow": _params["shadow"]}),
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
	el = _maybe_wrap_shadow(el, id)         # cast the SHARED shadow behind the preview when this component's Shadow toggle is on
	_make_clickthrough(el, id == "frame")   # only the FRAME keeps its handles grabbable
	holder.custom_minimum_size = el.custom_minimum_size
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
	# LIGHT cell so a dark drop-shadow reads against it (a dark cell hid the shadow knobs' effect). A cool
	# light slate also keeps the cream badges legible (cream-on-cream would wash out).
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	if selected:
		sb.bg_color = Color("#E3ECEF")
		sb.set_border_width_all(2)
		sb.border_color = Pal.STRAW
	else:
		sb.bg_color = Color("#C7D4DB")
		sb.set_border_width_all(1)
		sb.border_color = Color(Pal.INK, 0.18)
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
	if _selected == "dialog" or _selected == "daily" or _selected == "mystery" or _selected == "shop" or _selected == "settings":
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
		note.text = "Uses the STANDARD shared frame with NO override — border, banner + ✕ are all tuned on the Frame item and flow here. The tiles ARE the SHARED slot cell: a seen tier → the filled well holds its piece, an unseen tier → the code-drawn locked background, with a plain lower-right tier number; marked tiers sparkle. The piece size + well/background look are inherited from the Slot cell item — only the square cell size, tier-number toggle, sparkle, and grid are tuned here. A plain grid — no vines."
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	if _selected == "bag_card":
		var note := Label.new()
		note.text = "ONE cell shared by the Bag dialog AND the board: empty / filled use the cream well; locked / unlockable use the code-drawn locked background. Unlockable = the highlight (gold border + dynamic sparkle). Add a level badge (board) or an acorn cost (bag) below."
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
		note.text = "A live preview of the merge board: the bamboo frame + the SHARED Slot cell states (open wells, frontier locks, deep locks) + demo pieces. Edit the cell art and locked-background colours on the Slot cell item. SCALE zooms the whole board (frame + cells together); CELL is the item width — the grid grows while the frame thickness stays, so you trade item size against frame weight. ITEM is the piece size within its cell."
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	if _selected == "fx":
		var note := Label.new()
		note.text = "Coin Flow is one shared reward-flight component. Saved settings tune the shared feel and gate which actions use it; test settings only change this preview."
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	_sidebar_body.add_child(HSeparator.new())

	# the UNIVERSAL Shadow toggle — every component casts the ONE shared shadow (tuned on the Shadow item).
	# Skipped on the Shadow item itself (that IS the editor).
	if _selected != "shadow" and _selected != "fx":
		_sidebar_body.add_child(_toggle_row("Shadow", "shadow"))
		var sn := Label.new()
		sn.text = "Casts the shared drop shadow — tune its look on the Shadow item."
		sn.add_theme_font_size_override("font_size", 11)
		sn.add_theme_color_override("font_color", Color(Pal.STRAW, 0.7))
		sn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(sn)
		_sidebar_body.add_child(HSeparator.new())

	# Every element splits its controls into the two buckets (see TEST_KEYS): the persisted design
	# config first, then the transient test/preview scaffolding that the config file never touches.
	match _selected:
		"fx":
			_fx_sidebar()
		"shadow":
			_group_header("Saved to config", true)
			_section_header("Cast (offset-based — size-independent)")
			_sidebar_body.add_child(_slider_row(["offset_x", -40, 40]))   # horizontal cast (px): −left / +right
			_sidebar_body.add_child(_slider_row(["offset_y", -40, 40]))   # vertical cast (px): −up / +down
			_section_header("Shape")
			_sidebar_body.add_child(_slider_row(["blur", 0, 40]))         # soft feather radius (px)
			_sidebar_body.add_child(_slider_row(["spread", -20, 40]))     # grow(+) / shrink(−) the shadow on every side (px)
			_section_header("Tint")
			_sidebar_body.add_child(_slider_row(["alpha", 0, 80]))        # opacity (%)
			_sidebar_body.add_child(_slider_row(["warmth", 0, 100]))      # warm brown ↔ cool violet-black
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
			_section_header("Frame")
			_sidebar_body.add_child(_option_row("Style", "frame_style", ["badge", "code"]))   # shared gold badge vs code-drawn
			_sidebar_body.add_child(_slider_row(["frame_corner", 0, 90]))         # corner radius (both styles)
			_section_header("Code border (when Style = code)")
			_sidebar_body.add_child(_slider_row(["frame_border_w", 0, 16]))       # outer border width
			_sidebar_body.add_child(_slider_row(["frame_inner_w", 0, 10]))        # inner hairline — the border of the border
			_sidebar_body.add_child(_slider_row(["frame_top_shadow", 0, 100]))    # top inset shadow — depth near the top
			_group_header("Test only — not saved", false)
			_sidebar_body.add_child(_toggle_row("Demo pieces", "pieces"))
		"generator":
			_group_header("Saved to config", true)     # flows to the LIVE board (Kit.gen_highlight_opts_from_config)
			_section_header("Glow halo")
			_sidebar_body.add_child(_slider_row(["glow_scale", 60, 160]))    # halo size, % of cell
			_sidebar_body.add_child(_slider_row(["glow_a", 0, 80]))          # halo opacity %
			_section_header("Outline (traces the art)")
			_sidebar_body.add_child(_slider_row(["outline_w", 0, 90]))       # rim thickness (per-mille of cell)
			_sidebar_body.add_child(_slider_row(["outline_a", 0, 100]))      # rim opacity %
			_section_header("Sparkle")
			_sidebar_body.add_child(_slider_row(["sparkle_count", 0, 7]))    # twinkle count
			_sidebar_body.add_child(_slider_row(["sparkle_speed", 0, 150]))  # twinkle speed (/100 cyc/s)
			_group_header("Test only — not saved", false)
			_sidebar_body.add_child(_option_row("Generator", "preview", ["seed_satchel", "hen_coop", "tool_shed", "bee_skep", "mushroom_ring"]))
			_sidebar_body.add_child(_slider_row(["cell", 90, 240]))         # preview size (px)
		"button":
			_group_header("Saved to config", true)            # only the shared STYLE persists
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
			_sidebar_body.add_child(_slider_row(["px", 90, 260]))
			_sidebar_body.add_child(_slider_row(["icon_scale", 30, 80]))   # icon as % of the disc
			_sidebar_body.add_child(_slider_row(["caption_font", 14, 34]))
			_sidebar_body.add_child(_slider_row(["caption_gap", -10, 40]))   # tab offset below the disc (negative tucks up)
			_sidebar_body.add_child(_slider_row(["caption_pad_x", 0, 40]))   # caption tab horizontal padding
			_sidebar_body.add_child(_slider_row(["caption_pad_y", 0, 20]))   # caption tab vertical padding
			_section_header("Rect badge (rail + Map — shape:\"rect\")")
			_sidebar_body.add_child(_slider_row(["fill_alpha", 20, 100]))         # the rect-badge OPACITY (%)
			_sidebar_body.add_child(_slider_row(["rect_pad", 4, 28]))            # inner padding (% of px) for the icon+label stack
			_section_header("Play disc (bottom-right CTA)")
			_sidebar_body.add_child(_slider_row(["play_px", 120, 260]))          # the orange Play disc diameter (px)
			_section_header("Side-rail badge (red dot / count)")
			_sidebar_body.add_child(_slider_row(["badge_dx", -30, 20]))   # badge x past the disc corner (neg tucks in)
			_sidebar_body.add_child(_slider_row(["badge_dy", -30, 20]))   # badge y past the disc corner (neg tucks in)
			_sidebar_body.add_child(_slider_row(["badge_dot_px", 8, 28]))     # the bare-dot badge diameter
			_sidebar_body.add_child(_slider_row(["badge_num_size", 8, 28]))   # the count-badge number size (pill tracks it)
			_section_header("Bag count (in-disc \"x/y\")")
			_sidebar_body.add_child(_slider_row(["count_dx", -60, 60]))   # count x offset from the disc centre
			_sidebar_body.add_child(_slider_row(["count_dy", -60, 60]))   # count y offset from the disc centre (+ = lower)
			_sidebar_body.add_child(_slider_row(["count_font", 14, 40]))  # the "x/y" font size
			_section_header("Sparkle (engine FX — no baked art)")
			_sidebar_body.add_child(_slider_row(["glow", 0, 100]))       # the breathing halo amount
			_sidebar_body.add_child(_slider_row(["twinkle", 0, 100]))    # the drifting-star density
			_section_header("Shell polish (raw vs cleaned — shared by every home button)")
			# the shell's edge polish (defringe / feather) — SAVED under config["badge"], read by the live
			# game via Kit.badge_polish_from_config and applied to every home-button shell (rect + play).
			_sidebar_body.add_child(_toggle_row("Defringe", "defringe", false, "badge"))
			_sidebar_body.add_child(_slider_row(["feather", 0, 4], "badge"))
			_group_header("Test only — not saved", false)        # the rail/nav each set their own icon + caption
			_sidebar_body.add_child(_option_row("Icon", "icon", HOME_ICONS))
			_sidebar_body.add_child(_text_row("Caption", "caption"))
			_sidebar_body.add_child(_toggle_row("Sparkle", "sparkle"))   # preview the sparkle on the right-hand disc
			_sidebar_body.add_child(_slider_row(["badge_count", 0, 99]))   # sample badge count (0 = dot, ≥1 = count pill)
			_sidebar_body.add_child(_text_row("Bag count", "count"))   # sample "x/y" on the nav disc (empty = none)
		"hud_layout":
			_group_header("Saved to config", true)
			_section_header("Top HUD")
			_sidebar_body.add_child(_slider_row(["level_w_pct", 10, 40]))          # Lv badge slot width (% screen width)
			_sidebar_body.add_child(_slider_row(["currency_area_pct", 50, 90]))    # wallet's right-side band (% screen width)
			_sidebar_body.add_child(_slider_row(["currency_pill_w_pct", 12, 35]))  # each currency pill width (% screen width)
			_sidebar_body.add_child(_slider_row(["edge_margin_px", 0, 48]))        # shared wallet + rail right-edge inset (px)
			_sidebar_body.add_child(_slider_row(["top_band_h_pct", 5, 30]))        # vertical band reserved before rail/settings
			_section_header("Buttons + board bottom")
			_sidebar_body.add_child(_slider_row(["button_w_pct", 8, 25]))          # rail/nav/back/bag/home width (% screen width)
			_sidebar_body.add_child(_slider_row(["info_bar_w_pct", 40, 85]))       # board info-bar width (% screen width)
			_section_header("Quest bar")
			_sidebar_body.add_child(_slider_row(["quest_bar_x_pct", 0, 30]))       # quest fence left inset / position (% screen width)
			_sidebar_body.add_child(_slider_row(["quest_bar_y_pct", 0, 55]))       # quest fence top position (% screen height)
			_sidebar_body.add_child(_slider_row(["quest_bar_h_pct", 5, 25]))       # quest fence height (% screen height)
			_section_header("Board area")
			_sidebar_body.add_child(_slider_row(["board_x_pct", 0, 40]))           # board area left position (% screen width)
			_sidebar_body.add_child(_slider_row(["board_y_pct", 0, 75]))           # board area top position (% screen height)
			_sidebar_body.add_child(_slider_row(["board_h_pct", 20, 70]))          # board area height (% screen height)
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
			_sidebar_body.add_child(_slider_row(["feather", 0, 4]))
			_sidebar_body.add_child(_slider_row(["supersample", 1, 4]))
		"gold_badge":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["corner", 12, 134]))
			_sidebar_body.add_child(_slider_row(["inner_inset", 4, 36]))
			_sidebar_body.add_child(_slider_row(["shine", 0, 200]))
			_sidebar_body.add_child(_slider_row(["gradient", 0, 100]))
			_group_header("Test only — not saved", false)
			_sidebar_body.add_child(_slider_row(["px", 160, 360]))
		"gold_currency_pill":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["overall_scale", 60, 220]))
			_sidebar_body.add_child(_slider_row(["pill_w", 180, 380]))
			_sidebar_body.add_child(_slider_row(["pill_h", 64, 132]))
			_section_header("Padding")
			_sidebar_body.add_child(_slider_row(["pad_left", 0, 60]))
			_sidebar_body.add_child(_slider_row(["pad_x", 0, 60]))
			_sidebar_body.add_child(_slider_row(["pad_y", -36, 36]))
			_sidebar_body.add_child(_slider_row(["inner_shadow", 0, 100]))
			_sidebar_body.add_child(_slider_row(["gap", 0, 30]))
			_section_header("Icon")
			_sidebar_body.add_child(_slider_row(["icon_box", 20, 90]))
			_sidebar_body.add_child(_slider_row(["icon_size", 18, 64]))
			_sidebar_body.add_child(_slider_row(["icon_x", -32, 32]))
			_section_header("Amount")
			_sidebar_body.add_child(_slider_row(["amount_w", 40, 180]))
			_sidebar_body.add_child(_slider_row(["num_size", 16, 48]))
			_sidebar_body.add_child(_slider_row(["amount_x", -40, 40]))
			_section_header("Plus button")
			_sidebar_body.add_child(_slider_row(["plus_x", -20, 20]))
			_sidebar_body.add_child(_slider_row(["plus_radius", 8, 44]))
			_sidebar_body.add_child(_slider_row(["plus_shine", 0, 60]))
			_sidebar_body.add_child(_slider_row(["plus_stroke", 0, 5]))
			_sidebar_body.add_child(_slider_row(["plus_font", 50, 160]))
			_sidebar_body.add_child(_slider_row(["plus_button", 75, 135]))
			_sidebar_body.add_child(_slider_row(["plus_round", 0, 18]))
			_sidebar_body.add_child(_slider_row(["plus_hue", 55, 82]))
			_sidebar_body.add_child(_slider_row(["plus_label_y", -20, 20]))   # nudge the "+" up/down within the green button
			_section_header("Shadow")
			_sidebar_body.add_child(_slider_row(["shadow_alpha", 0, 80]))   # the pill's own drop-shadow STRENGTH (turn it on with the Shadow toggle above)
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
		"mystery":
			# no saved knobs: the frame is shared (Frame item), width is the engine's min(560, 94%) cap.
			# The preview-state picker (which pool · revealed-vs-pick) + "▶ Play spin" to watch the real animation.
			_group_header("Test only — not saved", false)
			_sidebar_body.add_child(_option_row("Preview", "preview", ["day 7 · revealed", "day 7 · pick", "day 4 · revealed", "day 4 · pick"]))
			var mplay := Button.new()
			mplay.text = "▶ Play spin"
			mplay.pressed.connect(_play_mystery_spin)
			_sidebar_body.add_child(mplay)
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
		"level_badge":
			_group_header("Saved to config", true)
			# every part has its own X/Y/Scale, all visible at once; the preview renders ALL parts together
			_section_header("Circle (coin background)")
			_sidebar_body.add_child(_toggle_row("Circle base", "circle_base"))   # draw the coin behind every tier
			# the coin design: 'auto' grows with the level, or pin one of the 6 designs from the asset
			_sidebar_body.add_child(_option_row("Circle design", "circle_design", ["auto", "1", "2", "3", "4", "5", "6"]))
			_sidebar_body.add_child(_slider_row(["circle_x", -60, 60]))
			_sidebar_body.add_child(_slider_row(["circle_y", -60, 60]))
			_sidebar_body.add_child(_slider_row(["circle_scale", 10, 160]))
			for pn in [["Leaf (wreath)", "leaf"], ["Flower", "flower"], ["Acorn", "acorn"], ["Gem", "gem"]]:
				_section_header(String(pn[0]))
				var part_key := String(pn[1])
				var y_min := -120 if part_key == "gem" else -60
				_sidebar_body.add_child(_slider_row([part_key + "_x", -60, 60]))      # horizontal offset (% of px)
				_sidebar_body.add_child(_slider_row([part_key + "_y", y_min, 60]))    # vertical offset (% of px; - = up)
				_sidebar_body.add_child(_slider_row([part_key + "_scale", 10, 160]))  # size (% of the common box)
			_section_header("Number (the level text)")
			_sidebar_body.add_child(_slider_row(["num_size", 8, 70]))       # font (% of px)
			_sidebar_body.add_child(_slider_row(["num_x", -50, 50]))        # side (horizontal offset)
			_sidebar_body.add_child(_slider_row(["num_y", -50, 50]))        # margin (vertical offset)
			_sidebar_body.add_child(_slider_row(["num_burn", 0, 100]))      # engraved burn (dark ink + emboss + outline)
			_section_header("Overall")
			_sidebar_body.add_child(_slider_row(["size", 40, 120]))         # the common part box (% of px)
			_group_header("Test only — not saved", false)
			# preview_level drives the tier stage + the printed number (the preview shows ALL parts)
			_sidebar_body.add_child(_slider_row(["preview_level", 1, 110]))
		"map_card":
			_group_header("Saved to config", true)
			# card SIZE: width as a % of the screen width (smaller = wider side margins) and height as a % of
			# the screen height — the two are INDEPENDENT (width sets margins; height has no ceiling now: the
			# place-picker SCROLLS when tall cards overflow the band). A w:h far from the art's ~2.92 aspect
			# stretches the gold frame (the preview shows it).
			_sidebar_body.add_child(_slider_row(["card_w_frac", 60, 100]))    # card width  (% of screen width)
			_sidebar_body.add_child(_slider_row(["card_h_frac", 8, 50]))      # card height (% of screen height; the picker scrolls past the band)
			# the count pill's painted art (pill_left) vs a code-drawn cream pill — both card frames + the
			# locked interior are code-drawn now, so this toggle only governs the count pill.
			_sidebar_body.add_child(_toggle_row("Use art", "use_art", true))
			_sidebar_body.add_child(_slider_row(["edge_sparkle", 0, 100]))    # twinkles ringing an ACTIVE open card's gold band (% — 0 = off)
			_sidebar_body.add_child(_slider_row(["pill_w_frac", 10, 60]))     # count-pill width (% of card width)
			_sidebar_body.add_child(_slider_row(["pill_min", 80, 360]))       # …clamped to this min px
			_sidebar_body.add_child(_slider_row(["pill_max", 120, 460]))      # …and this max px
			_sidebar_body.add_child(_slider_row(["pill_y_frac", 0, 40]))      # pill lift off the bottom edge (% of height)
			_group_header("Test only — not saved", false)                    # the game sets open / done / count per map
			_sidebar_body.add_child(_toggle_row("Open (unlocked)", "open"))
			_sidebar_body.add_child(_toggle_row("Done (restored)", "done"))
			_sidebar_body.add_child(_slider_row(["owned_zones", 0, 12]))
			_sidebar_body.add_child(_slider_row(["total_zones", 0, 12]))
		"tiers":
			_group_header("Saved to config", true)
			_section_header("Layout (grid — no vines)")
			_sidebar_body.add_child(_slider_row(["width_pct", 40, 100]))    # % of the screen width (responsive)
			_sidebar_body.add_child(_slider_row(["cols", 1, 5]))
			_sidebar_body.add_child(_slider_row(["cell_gap", 0, 48]))
			_sidebar_body.add_child(_slider_row(["list_max_h", 0, 1400]))   # height cap; 0 = no scroll
			_section_header("Tile (square cell — piece size + art are on the Slot cell)")
			_sidebar_body.add_child(_slider_row(["cell_w", 80, 240]))
			_sidebar_body.add_child(_slider_row(["cell_h", 80, 240]))
			_sidebar_body.add_child(_toggle_row("Tier number", "show_num"))  # plain lower-right text, no badge
			_section_header("Marked tier (sparkle)")
			_sidebar_body.add_child(_slider_row(["mark_glow", 0, 100]))     # the marked tier's glow (0 = off)
			_sidebar_body.add_child(_slider_row(["mark_twinkle", 0, 100]))  # ...and its drifting twinkles (0 = off)
			# the frame chrome (border · banner · ✕) is the STANDARD shared frame — tune it on the Frame item.
		"info_bar":
			_group_header("Saved to config", true)                         # full bottom action tray + info content
			_section_header("Action tray")
			_sidebar_body.add_child(_slider_row(["icon_scale_pct", 25, 95]))       # Bag/Home icon size (% of the button slot)
			_sidebar_body.add_child(_slider_row(["pad_x_pct", 0, 16]))             # left/right padding (% of bar height)
			_sidebar_body.add_child(_slider_row(["pad_y_pct", 0, 16]))             # top/bottom padding (% of bar height)
			_sidebar_body.add_child(_slider_row(["bag_x_pct", -30, 30]))           # Bag item horizontal nudge
			_sidebar_body.add_child(_slider_row(["info_x_pct", -30, 30]))          # Info pill horizontal nudge
			_sidebar_body.add_child(_slider_row(["home_x_pct", -30, 30]))          # Home item horizontal nudge
			_section_header("Info content")
			_sidebar_body.add_child(_slider_row(["height", 90, 180]))       # bar height (matches the Bag/Home wells)
			_sidebar_body.add_child(_slider_row(["inner_scale", 30, 70]))   # the info ⓘ + piece box as % of the height
			_sidebar_body.add_child(_slider_row(["item_icon_scale", 50, 120]))  # selected item/generator art as % of that box
			_sidebar_body.add_child(_slider_row(["info_x", -120, 120]))     # nudge the info ⓘ button left(−) / right(+)
			_sidebar_body.add_child(_slider_row(["name_font", 18, 44]))     # the "<name> · Tier N" font
			_sidebar_body.add_child(_slider_row(["sep", 0, 30]))            # gap between the bar's controls
			_sidebar_body.add_child(_slider_row(["sell_label_font", 14, 34]))  # the plain "Sell" caption font
			_sidebar_body.add_child(_slider_row(["sell_font", 16, 40]))     # the sell badge's payout number font
			_sidebar_body.add_child(_slider_row(["sell_icon", 15, 50]))     # the payout coin as % of the height
			_sidebar_body.add_child(_slider_row(["sell_badge_radius", 0, 30]))  # the green badge corner radius
			_sidebar_body.add_child(_slider_row(["pad_right", 0, 80]))      # right padding — how near the Sell button sits to the edge
			_group_header("Test only — not saved", false)                  # preview selected vs empty state
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
		"info":
			# the info sheet IS the mail dialog now: its border/banner/✕/card art + fonts are tuned on the
			# Frame + Card elements (shared). Only the sheet WIDTH is info-specific.
			_group_header("Saved to config", true)
			_section_header("Layout (face shared with the Mail dialog — tune the Frame + Card elements)")
			_sidebar_body.add_child(_slider_row(["width_pct", 40, 100]))   # % of the screen width (responsive)
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
			_sidebar_body.add_child(_slider_row(["glow_hue", 0, 60]))         # accent tone: 0 orange → 42 straw → 60 yellow
			_sidebar_body.add_child(_slider_row(["glow_sat", 0, 100]))        # accent saturation: 0 warm-white → 100 full gold
			_sidebar_body.add_child(_slider_row(["glow_size", 0, 250]))       # outer-bloom spread (% of cell; 100 = cell-sized, 0 = no halo)
			_sidebar_body.add_child(_slider_row(["glow_shadow", 0, 100]))     # rim-shadow strength (0 = no glow hugging the cell)
			_sidebar_body.add_child(_slider_row(["glow_shadow_size", 0, 40])) # rim-shadow size (% of cell)
			_section_header("Cell background: open fill")
			_sidebar_body.add_child(_slider_row(["open_hue", 0, 90]))
			_sidebar_body.add_child(_slider_row(["open_sat", 0, 100]))
			_sidebar_body.add_child(_slider_row(["open_val", 40, 100]))
			_section_header("Cell background: frontier fill")
			_sidebar_body.add_child(_slider_row(["frontier_hue", 0, 90]))
			_sidebar_body.add_child(_slider_row(["frontier_sat", 0, 100]))
			_sidebar_body.add_child(_slider_row(["frontier_val", 40, 100]))
			_section_header("Cell background: deep fill")
			_sidebar_body.add_child(_slider_row(["deep_hue", 0, 90]))
			_sidebar_body.add_child(_slider_row(["deep_sat", 0, 100]))
			_sidebar_body.add_child(_slider_row(["deep_val", 40, 100]))
			_section_header("Cell background: frontier rim")
			_sidebar_body.add_child(_slider_row(["rim_hue", 0, 140]))
			_sidebar_body.add_child(_slider_row(["rim_sat", 0, 100]))
			_sidebar_body.add_child(_slider_row(["rim_val", 40, 100]))
			_sidebar_body.add_child(_slider_row(["rim_alpha", 0, 100]))
			_section_header("Cell background: shape, depth, shadow")
			_sidebar_body.add_child(_slider_row(["corner", 4, 50]))
			_sidebar_body.add_child(_slider_row(["depth", 0, 24]))
			_sidebar_body.add_child(_slider_row(["depth_alpha", 0, 100]))
			_sidebar_body.add_child(_slider_row(["cell_shadow", 0, 100]))
			_sidebar_body.add_child(_slider_row(["cell_shadow_size", 0, 40]))
			_sidebar_body.add_child(_slider_row(["cell_shadow_y", -20, 20]))
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
			_sidebar_body.add_child(_slider_row(["acorn_x", -200, 80]))     # nudge the acorn-balance pill left(−) / right(+)
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
	_sidebar_body.add_child(_slider_row(["banner_text_pad_l", 0, 200]))   # title↔left-tail room (the ribbon auto-sizes to fit)
	_sidebar_body.add_child(_slider_row(["banner_text_pad_r", 0, 200]))   # title↔right-tail room
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
	_sidebar_body.add_child(_text_row("Banner text", "preview_text"))   # type any title to test the ribbon's width-scaling
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

func _slider_row(spec: Array, target := "") -> Control:
	var key: String = spec[0]
	var lo: float = float(spec[1])
	var hi: float = float(spec[2])
	var params: Dictionary = _params[target if target != "" else _selected]
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
		if String(target if target != "" else _selected) == "hud_layout":
			if key == "board_h_pct":
				_hud_board_height_auto = false
			elif key == "board_x_pct":
				_hud_board_x_auto = false
			elif key == "board_y_pct":
				_hud_board_y_auto = false
			elif key == "quest_bar_h_pct":
				_hud_quest_height_auto = false
			elif key == "quest_bar_y_pct":
				_hud_quest_y_auto = false
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

func _toggle_row(label: String, key: String, rebuild_sidebar := false, target := "") -> Control:
	var params: Dictionary = _params[target if target != "" else _selected]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var cb := CheckButton.new()
	cb.button_pressed = bool(params.get(key, false))
	cb.toggled.connect(func(on: bool) -> void:
		params[key] = on
		_apply_edit()
		if rebuild_sidebar:
			_rebuild_sidebar.call_deferred())   # defer — we're inside this toggle's own signal
	row.add_child(cb)
	return row

func _option_row(label: String, key: String, options: Array, rebuild_sidebar := false) -> Control:
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
		_apply_edit()
		if rebuild_sidebar:
			_rebuild_sidebar.call_deferred())   # defer — we're inside this option's own signal
	row.add_child(ob)
	return row

func _fx_sidebar() -> void:
	var saved := Label.new()
	saved.name = "WorkbenchFxSavedSettingsHeader"
	saved.text = "●  Saved to config"
	saved.add_theme_font_size_override("font_size", 20)
	saved.add_theme_color_override("font_color", Pal.STRAW)
	_sidebar_body.add_child(saved)
	_section_header("Action gates")
	for entry in FxWorkbenchView.FX_DEFS:
		var def: Dictionary = entry
		var fx_id := String(def.get("id", ""))
		var toggle := CheckButton.new()
		toggle.name = "WorkbenchFxActionToggle_%s" % fx_id
		toggle.text = String(def.get("label", fx_id))
		toggle.button_pressed = FX.reward_fx_enabled(fx_id)
		toggle.add_theme_color_override("font_color", Pal.CREAM)
		toggle.toggled.connect(func(on: bool) -> void:
			_fx_set_enabled(fx_id, on))
		_sidebar_body.add_child(toggle)

	_section_header("Feel")
	_sidebar_body.add_child(_fx_slider_row("Icon size", "icon_size", FX.REWARD_FX_MIN_ICON_SIZE, FX.REWARD_FX_MAX_ICON_SIZE, 1))
	_sidebar_body.add_child(_fx_slider_row("Trail count", "trail_count", FX.REWARD_FX_MIN_TRAIL_COUNT, FX.REWARD_FX_MAX_TRAIL_COUNT, 1))

	var test := Label.new()
	test.name = "WorkbenchFxTestSettingsHeader"
	test.text = "○  Test only — not saved"
	test.add_theme_font_size_override("font_size", 20)
	test.add_theme_color_override("font_color", Color(Pal.CREAM, 0.5))
	_sidebar_body.add_child(test)
	_sidebar_body.add_child(_fx_action_row())
	var replay := Button.new()
	replay.name = "WorkbenchFxReplayButton"
	replay.text = "Replay"
	replay.disabled = not FX.reward_fx_enabled(_fx_selected)
	replay.pressed.connect(_fx_replay)
	_sidebar_body.add_child(replay)
	_sidebar_body.add_child(_fx_slider_row("Amount", "amount", FX.REWARD_FX_MIN_AMOUNT, FX.REWARD_FX_MAX_AMOUNT, 1))
	_sidebar_body.add_child(_fx_slider_row("Source size", "coin_size", FX.REWARD_FX_MIN_SOURCE_SIZE, FX.REWARD_FX_MAX_SOURCE_SIZE, 1))
	var auto := CheckButton.new()
	auto.name = "WorkbenchFxAutoReplayToggle"
	auto.text = "Auto replay"
	var preview := _fx_preview()
	auto.button_pressed = bool(preview.get("_settings").get("auto_replay", false)) if preview != null else false
	auto.add_theme_color_override("font_color", Pal.CREAM)
	auto.toggled.connect(func(on: bool) -> void:
		_fx_set_auto_replay(on))
	_sidebar_body.add_child(auto)

func _fx_action_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "WorkbenchFxPreviewActionRow"
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = "Preview action"
	lbl.custom_minimum_size = Vector2(118, 0)
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.name = "WorkbenchFxPreviewActionOption"
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in FxWorkbenchView.FX_DEFS.size():
		var def: Dictionary = FxWorkbenchView.FX_DEFS[i]
		opt.add_item(String(def.get("label", def.get("id", ""))), i)
		if String(def.get("id", "")) == _fx_selected:
			opt.select(i)
	opt.item_selected.connect(func(index: int) -> void:
		var def: Dictionary = FxWorkbenchView.FX_DEFS[index]
		_fx_select(String(def.get("id", "coin_pickup"))))
	row.add_child(opt)
	return row

func _fx_slider_row(label: String, key: String, lo: float, hi: float, step: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var s := HSlider.new()
	s.name = "WorkbenchFx%sSlider" % _pascal_fx_key(key)
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(_fx_global_value(key))
	s.custom_minimum_size = Vector2(0, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := Label.new()
	val.text = "%d" % int(round(s.value))
	val.custom_minimum_size = Vector2(44, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		var iv := int(round(x))
		val.text = "%d" % iv
		_fx_set_global_setting(key, iv))
	return row

func _pascal_fx_key(key: String) -> String:
	var out := ""
	for part in key.split("_"):
		out += String(part).capitalize()
	return out

func _fx_global_value(key: String) -> int:
	var preview := _fx_preview()
	if preview != null and preview.has_method("_set_global_setting"):
		var settings: Dictionary = preview.get("_settings")
		if settings.has(key):
			return int(round(float(settings.get(key, 0))))
	match key:
		"amount":
			return FX.reward_fx_amount()
		"icon_size":
			return int(round(FX.reward_fx_icon_size()))
		"trail_count":
			return FX.reward_fx_trail_count()
		"coin_size":
			return int(round(FX.reward_fx_source_size()))
		_:
			return 0

func _fx_preview() -> Control:
	return find_child("FxWorkbenchComponent", true, false) as Control

func _fx_select(id: String) -> void:
	_fx_selected = id
	var preview := _fx_preview()
	if preview != null and is_instance_valid(preview):
		preview.call("_select_action", id)
	else:
		_rebuild_element("fx")
	_rebuild_sidebar.call_deferred()

func _fx_set_enabled(id: String, on: bool) -> void:
	var preview := _fx_preview()
	if preview != null and is_instance_valid(preview):
		preview.call("_set_fx_enabled", id, on)
	else:
		FX.set_reward_fx_enabled(id, on)
	_rebuild_sidebar.call_deferred()

func _fx_set_global_setting(key: String, value: int) -> void:
	var preview := _fx_preview()
	if preview != null and is_instance_valid(preview):
		preview.call("_set_global_setting", key, value)
		return
	match key:
		"amount":
			FX.set_reward_fx_amount(value)
		"icon_size":
			FX.set_reward_fx_icon_size(float(value))
		"trail_count":
			FX.set_reward_fx_trail_count(value)
		"coin_size":
			FX.set_reward_fx_source_size(float(value))

func _fx_set_auto_replay(on: bool) -> void:
	var preview := _fx_preview()
	if preview != null and is_instance_valid(preview):
		preview.call("_set_auto_replay", on)
	else:
		FX.set_reward_fx_auto_replay(on)

func _fx_replay() -> void:
	var preview := _fx_preview()
	if preview != null and is_instance_valid(preview):
		preview.call("_play_selected")

func _fx_def(id: String) -> Dictionary:
	for entry in FxWorkbenchView.FX_DEFS:
		var def: Dictionary = entry
		if String(def.get("id", "")) == id:
			return def
	return FxWorkbenchView.FX_DEFS[0]

## --- persistence -------------------------------------------------------------------------------

## Is this element/key a persisted design setting (vs transient test scaffolding from TEST_KEYS)?
func _is_config(id: String, key: String) -> bool:
	return not (key in TEST_KEYS.get(id, []))

func _save_settings() -> void:
	# write ONLY the config bucket — test/preview scaffolding (button icon, dialog entries, …) is excluded
	var out := {}
	for id in _params.keys():
		if id == "fx":
			continue
		var sub := {}
		for k in (_params[id] as Dictionary).keys():
			if _is_config(id, k):
				sub[k] = _params[id][k]
		out[id] = sub
	out["fx"] = FX.reward_fx_config()
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
