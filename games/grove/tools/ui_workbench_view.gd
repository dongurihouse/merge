@tool
extends "res://games/grove/tools/workbench_view.gd"
## UI Workbench — gallery + inspector sidebar.
##
## `make w` opens this. The left column is a scroll of the fundamental components, built
## bottom-up from the self-contained kit (cost pill → mail card → mail dialog). CLICK an element to
## select it; the right SIDEBAR then shows that element's own options/sliders. Changing a slider
## rebuilds just that element — and because the components compose, a dialog's pill size still flows
## down into every row.
##
## The gallery/sidebar/persistence framework lives in the shared base (workbench_view.gd); this script
## is the UI element set. The FX elements moved out to their own workbench (fx_workbench_view.gd).

const Look = preload("res://engine/scripts/ui/skin.gd")   # kit-relative art paths (Look.kit) for the polish source
const ActionBar = preload("res://engine/scripts/ui/action_bar.gd")
const GiverStand = preload("res://engine/scripts/ui/giver_stand.gd")   # the quest-giver card builder (board reskin)
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")     # merge pieces for the Board preview
const FocusRing = preload("res://engine/scripts/ui/focus_ring.gd")     # the selected-cell corner-bracket highlight
const LoginMystery = preload("res://engine/scripts/ui/login_mystery.gd")  # the mystery spin-reveal dialog (build_reveal)
const Login = preload("res://engine/scripts/core/login.gd")            # mystery_config(slot) → the demo pool for the preview
const LoginUI = preload("res://engine/scripts/ui/login.gd")            # the REAL daily dialog / day-cell renderer (the game's daily card)
const LadderUI = preload("res://engine/scripts/ui/ladder.gd")          # the REAL discovery-ladder renderer (corner tier chips + generator header)
const ShopUI = preload("res://engine/scripts/ui/shop.gd")              # the REAL shop storefront renderer (Shop.build_body — sage art-left cards)
const LevelPopup = preload("res://engine/scripts/ui/level_popup.gd")   # the REAL level dialog sheet (the game's level screen)
# Demo merge pieces for the Board preview — [row, col, item code]; cells outside the grid are skipped.
const BOARD_DEMO := [[1, 1, 101], [1, 2, 101], [2, 3, 102], [3, 2, 103], [4, 4, 102], [5, 1, 104], [6, 5, 101], [2, 5, 103]]
const IDS := ["board", "focus_ring", "button", "home_button", "hud_layout", "progress_bar", "bag_card", "quest_card", "mail_card", "frame", "dialog", "daily", "mystery", "shop", "level", "tiers", "gold_currency_pill", "info_bar", "rush_bar", "settings", "vault", "info", "bag"]
# Gallery layout: TWO side-by-side COLUMNS. The LEFT column is the building-block components, ALWAYS ONE
# element per row (each on its own line). The RIGHT column leads with the Board preview, then stacks every
# DIALOG in a single column. Each column is a list of ROWS; a row CAN hold side-by-side elements (the right
# column may), but the left column never pairs — one per row. Splitting dialogs into their own column keeps
# them grouped and balances the gallery's height (the tall dialogs no longer each span a full-width row).
const COLUMNS := [
	# the building blocks — one element per row (the HUD gold currency pill lives here too, as a reusable atom).
	[["shadow"], ["focus_ring"], ["home_button"], ["hud_layout"], ["button"], ["gold_currency_pill"], ["bag_card"], ["quest_card"], ["mail_card"], ["info_bar"], ["rush_bar"], ["frame"], ["progress_bar"]],
	# the RIGHT column: the Board preview LEADS it — the live merge grid you size with the scale / item-width
	# knobs — then every dialog stacked below.
	[["board"], ["dialog"], ["daily"], ["mystery"], ["shop"], ["level"], ["tiers"], ["settings"], ["vault"], ["info"], ["bag"]],   # board + dialogs, settings, vault, info, bag
]
# Editing element X must also refresh the elements that COMPOSE from it (derived from the kit's
# opts-builders): the Button's style flows into every Claim/cost pill; the shared Frame + the small
# cards flow into the dialogs; the Badge's polish flows into the Home button. Editing anything else
# (a dialog's own width, the icon sandbox, the pill, ...) touches only itself. Used to rebuild just the
# edited element + its dependents instead of the whole gallery.
const DEPENDENTS := {
	"button": ["dialog", "daily", "shop", "settings", "info"],
	# the reward-card style (edge + tint) flows into the mail dialog + the welcome/info sheet.
	"mail_card": ["dialog", "info"],
	# the mail-card style is edited ON the Mail dialog now, so editing the dialog also refreshes the
	# other surfaces that reuse the card (daily · shop · settings · info).
	"dialog": ["daily", "shop", "settings", "info"],
	# the daily-cell style is edited ON the Daily dialog now (it feeds the shop's pack cells).
	"daily": ["shop"],
	"frame": ["dialog", "daily", "mystery", "shop", "settings", "bag", "tiers", "info", "level", "vault"],
	"home_button": ["info_bar"],
	"hud_layout": ["info_bar"],
	# the slot cell backs the bag dialog, the discovery ladder (inherits its look), AND the Board preview's wells — editing it rebuilds all
	"bag_card": ["bag", "tiers", "board"],
	"gold_currency_pill": ["bag", "info_bar"],   # bag balance + info bar margins borrow the gold pill padding
}
# Badge backgrounds live in the kit now (Kit.BADGES) so the game resolves them from the same map.
# Icons the button can show (all resolve via the kit's _icon_tex); "none" = no icon.
const ICONS := ["none", "coin", "gem", "bluegem", "water", "leaf", "gift", "star", "daisy", "faucet", "rain", "news", "mail"]
# Icons the HOME button can show — the real home-surface set (mirrors HomeChrome.BAKE_ICONS + the bag/well
# icons the board wells use), so the preview picker can only choose ids the game actually renders.
const HOME_ICONS := ["map", "house", "daily", "vault", "mail", "board", "vine", "expedition", "settings", "bag", "shop", "piggy", "gift", "faucet"]
# Each element's params split into two buckets: anything listed here is TEST-ONLY scaffolding (sample
# content, preview counts, tool helpers) and is NOT written to / read from the config file; everything
# else is real design config that IS persisted. The sidebar mirrors this split under two headers.
#   button — icon/size/enabled are just to eyeball the shape; the REAL claim icon lives on the Card.
#   dialog — entries is a preview count, snap is the drag grid.
const TEST_KEYS := {
	# the BOARD preview — scale/gap/frame/frame-style are saved live-board design. cell/cols/rows are
	# preview scaffolding because the live board derives cell size from screen fit and uses G.COLS×G.ROWS.
	"board": ["pieces", "cell", "cols", "rows"],
	# the FOCUS RING (selected-cell corner brackets): colour/halo/proportions persist (they flow to the
	# live board via Kit.focus_ring_opts_from_config); `cell` is the preview size only.
	"focus_ring": ["cell"],
	# the Button is a shared-STYLE sandbox: only shadow / use-art / font are real config. Its text, bg,
	# icon, badge, corner are test props — the REAL text/badge/icon for the game live on the Card.
	"button": ["text", "bg", "icon", "icon_size", "enabled", "corner", "badge", "paper", "border", "pad_scale", "static"],
	# the HOME button is a shared-STYLE sandbox: size / icon scale / caption look / badge offset / SPARKLE
	# persist. The previewed icon, caption text, sparkle toggle + sample badge count are test props.
	"home_button": ["icon", "caption", "sparkle", "badge_count", "count"],
	"hud_layout": [],
	"progress_bar": ["frac"],              # frac is a preview slider; height/art/star_knob are the saved style
	"badge": [],                           # the disc-shell polish is SAVED — the home button reads it
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
	"level": ["preview_level", "into", "span", "mode"],   # preview state; the size/dy layout knobs are SAVED
	"tiers": [],
	# the bottom-bar INFO BAR — the LAYOUT (height · inner scale · fonts · separation · sell button) persists;
	# the FRAME is the shared gold badge skin; gold_currency_pill padding controls its content margin. `filled` previews the
	# selected-vs-empty state (the game fills it from the tapped board item).
	"info_bar": ["filled"],
	# the RUSH BAR — every size/spacing knob is saved design; the preview values (time/score/mult) are static demo, not params
	"rush_bar": [],
	# the quest-giver card — the LAYOUT block (card/bust/bubble/item/plaque fractions) IS saved config now:
	# the board reads it via Kit.giver_lay_from_config, so a tweak here flows to the live giver card. Only
	# the DEMO knobs are test-only (which bust, the asked tier/reward, the board-given size, the ready ✓).
	"quest_card": ["bust", "tier", "stars", "stand_w", "fence_h", "met"],
	# the mail / reward-row card — the cut-paper edge + tint are SAVED style; the icon/title/body/chip TEXT is
	# just demo content to preview the row (the game supplies each mail entry's real content).
	"mail_card": ["icon", "title", "body", "chip_text"],
	"settings": [],
	"info": [],   # the demo line items are fixed in the preview; every knob is saved style
	"vault": ["balance", "claimable"],   # the previewed gem read + the claimable gate — preview only
	# the bag CELL — the cell STYLE persists; `preview` just picks which state (filled/empty/next/locked) to show.
	"bag_card": [],
	# the bag DIALOG — grid/caption persist; balance/owned/filled just preview the slot ladder (the game
	# sets each from save: the 💎 balance, how many slots owned, how many hold a piece).
	"bag": ["owned", "filled"],
}
const CAPTIONS := {
	"shadow": "Shadow — the SHARED drop shadow (offset · blur · spread) every component casts",
	"board": "Board — merge grid (frame · cells · pieces · scale)",
	"focus_ring": "Focus ring — selected-cell corner brackets (colour · halo · proportions)",
	"button": "Button — the shared kit button in every shape it builds (bg · paper · badge · chip)",
	"home_button": "Home bottom bar — the six paper tiles (icon · caption · badge) as map.gd builds them",
	"hud_layout": "HUD layout — the board screen's real regions: top HUD, next-unlock strip, quest fence, board, bottom bar",
	"gold_currency_pill": "Gold currency pills — home wallet",
	"progress_bar": "Progress bar — track + fill (reusable)",
	"bag_card": "Slot cell — the shared board + dialog cell in every state the game renders",
	"quest_card": "Quest card — giver (portrait · ask · plaque reward)",
	"mail_card": "Mail card — reward row (icon · title · body · value chip) in the shared cut-paper edge · own tint",
	"frame": "Dialog frame — shared chrome",
	"dialog": "Mail dialog — cards (card style: badge · icon · Claim · title/body)",
	"daily": "Daily — the game's real login screen (grid + capstone) in the shared frame",
	"mystery": "Mystery — slot reveal (reels spin · premium shines · pick N)",
	"shop": "Shop — packs (shared frame)",
	"level": "Level — the game's real dialog (level_popup: medallion · tally pill · bar · CTA)",
	"tiers": "Discovery — tier ladder (shared frame, no vines)",
	"info_bar": "Info bar — board bottom action bar (Home · ⓘ · selected piece · Bag)",
	"rush_bar": "Rush bar — Expedition top HUD (Time · Score · Mult): plain paper cards, cell size · text",
	"settings": "Settings — toggles (shared frame)",
	"vault": "Vault — piggy bank (twig border)",
	"info": "Mail — detail / welcome sheet (mail dialog · no Claim · Got it)",
	"bag": "Bag — slot grid (shared frame · acorn pill)",
}
func _ids() -> Array:
	return IDS

func _columns_spec() -> Array:
	return COLUMNS

func _captions() -> Dictionary:
	return CAPTIONS

func _test_keys() -> Dictionary:
	return TEST_KEYS

func _dependents() -> Dictionary:
	return DEPENDENTS

func _default_selected() -> String:
	return "button"

## The DIALOG column is sized to the global dialog width (every dialog now shares it) + chrome, so no
## dialog is clipped inside its column; the building-blocks column takes the remaining width.
func _last_column_width() -> float:
	return PHONE_W * Kit.frame_width_pct(_params) / 100.0 + 96.0

## Only the FRAME keeps its banner / banner-icon / ✕ grabbable (the other dialogs reuse it read-only).
func _keep_handles(id: String) -> bool:
	return id == "frame"

func _wrap_element(el: Control, id: String) -> Control:
	return _maybe_wrap_shadow(el, id)

func _before_load() -> void:
	_ensure_shadow_keys()

## MIGRATION: the shared frame's keys used to live under "dialog"; they're a standalone "frame" now.
## An older file has them under "dialog" — lift those into "frame" so prior tuning isn't lost.
func _load_migrate(data: Dictionary) -> void:
	if data.has("dialog") and data["dialog"] is Dictionary and not data.has("frame"):
		var fr := {}
		for k in (_params["frame"] as Dictionary).keys():
			if (data["dialog"] as Dictionary).has(k):
				fr[k] = data["dialog"][k]
		if not fr.is_empty():
			data["frame"] = fr
	# the frame's cut-paper keys were unified onto the shared knob set (cut_paper→deckle, card_corner→
	# corner, frame_shadow→edge_shadow). Lift any old-key values onto the canonical keys so saved tuning
	# carries over; the copy loop then reads them like any other key.
	if data.has("frame") and data["frame"] is Dictionary:
		var f: Dictionary = data["frame"]
		for pair in [["cut_paper", "deckle"], ["card_corner", "corner"], ["frame_shadow", "edge_shadow"]]:
			if f.has(pair[0]) and not f.has(pair[1]):
				f[pair[1]] = f[pair[0]]

func _default_params() -> Dictionary:
		return {
		# the SHARED SHADOW — ONE box-shadow definition every component casts (via its Shadow toggle). Offset-
		# based, so the same numbers read consistently on a small icon or a large badge. offset_x/y + blur +
		# spread are px; alpha is percent. Defaults are THE uniform shadow (skin.gd SHADOW_DEFAULTS).
		"shadow": {"offset_x": 0, "offset_y": 5, "blur": 6, "spread": -2, "alpha": 20},
		# the BOARD preview — a live merge grid (frame · the shared slot-cell well · demo pieces). `scale` is
		# the live board's overall zoom; `gap` and `frame` shape live spacing. `cell`/`cols`/`rows` only size
		# this preview. Piece size is owned by Slot-cell content_frac.
		"board": {"scale": 100, "cell": 52, "gap": 7, "cols": 7, "rows": 9, "frame": 60, "pieces": true,
			# the board FRAME defaults to the authored Meadow nine-slice; badge/code remain compatibility studies.
			"frame_style": "meadow", "frame_corner": 46,
			"frame_border_w": 4, "frame_inner_w": 0, "frame_top_shadow": 0},
		# the FOCUS RING — the selected-cell corner brackets. Colours are 6-digit hex (no '#'); arm/thick/pad
		# are % of the cell, halo_a is %. Defaults reproduce the shipped look (dark ink-green + cream halo).
		"focus_ring": {"color": "33402F", "halo_color": "FBF3EA", "halo_a": 90, "arm_pct": 30, "thick_pct": 8, "pad_pct": 4, "halo": true, "cell": 150},
		"button": {"text": "Claim", "bg": "green", "icon": "none", "icon_size": 30, "enabled": true, "font": 22, "art": true, "shadow": false, "badge": "auto",
			"paper": "none", "border": true, "pad_scale": 100, "static": false,
			# the SHARED cut-paper edge knob set (CUT_PAPER_KNOBS) — the SAME keys the frame + toggle bar use.
			"deckle": true, "corner": 16, "deckle_amp": 5, "deckle_freq": 5, "rim_width": 2, "edge_shadow": true, "shadow_reach": 10, "shadow_strength": 5},
		# the HOME button — the shared square-paper icon button (plus the authored Play disc). px / icon_scale /
		# caption_font / caption_gap / glow / twinkle are the saved STYLE; icon / caption / sparkle preview it.
		# Its shell edge polish (defringe / feather) lives under this item's Shell-polish knobs (saved as
		# config["badge"]); its icon uses the global icon clean.
		"home_button": {"px": 140, "icon_scale": 50, "caption_font": 22, "caption_gap": 4, "caption_pad_x": 30, "caption_pad_y": 8,
			"fill_alpha": 100, "rect_pad": 13,
			"badge_dx": -26, "badge_dy": -26, "badge_dot_px": 14, "badge_num_size": 14, "glow": 45, "twinkle": 55,
			"count_dx": 0, "count_dy": 38, "count_font": 26,
			"icon": "daily", "caption": "Daily", "sparkle": true, "badge_count": 3, "count": "1/6"},
		# The board + quest are responsive now (board fills width / auto-rotates 9×7; the quest+board stack is
		# bottom-anchored) — so the old manual board/quest x·y·h knobs are retired. Only the band HEIGHTS that
		# the live layout still reads remain tunable: quest_bar_h_pct, bottom_row_h_pct, button_w_pct.
		"hud_layout": {"currency_area_pct": 75, "currency_pill_w_pct": 25,
			"edge_margin_px": 18,
			"button_w_pct": 15, "bottom_row_h_pct": 10,
			"quest_bar_h_pct": 11},
		# the BADGE — the home button's disc shell, extracted as its own polish sandbox (defringe / shadow /
		# feather, like the Icon item). SAVED, and the home button reads it so a tweak flows to the rail + nav.
		"badge": {"defringe": false, "shadow": false, "feather": 0},
		"gold_currency_pill": {"icon": "water", "count": 2450, "overall_scale": 100, "pill_w": 292, "pill_h": 100,
			# the SHARED cut-paper edge knob set (CUT_PAPER_KNOBS) — the SAME keys the button + frame use.
			# `corner` seeds the capsule roundness to the old pill_h * 0.35 look (see Kit.PILL_CP_DEFAULTS).
			"deckle": true, "corner": 35, "deckle_amp": 4, "deckle_freq": 5, "rim_width": 2, "edge_shadow": true, "shadow_reach": 10, "shadow_strength": 5,
			"pad_left": 18, "pad_x": 16, "pad_y": 12, "icon_box": 54, "icon_size": 34, "icon_x": 0,
			"amount_w": 88, "num_size": 30, "amount_x": 0,
			"gap": 12, "plus_x": 0, "plus_y": 0, "plus_radius": 28, "plus_shine": 32,
			"plus_stroke": 2, "plus_font": 70, "plus_button": 100, "plus_round": 8, "plus_hue": 65,
			"plus_label_y": 0,
			"inner_shadow": 30},
		# the reusable PROGRESS BAR — its own building-block component (track + honey fill). height / art /
		# star_knob are the saved style; frac is a preview-only fill slider. The Level dialog reads this style.
		"progress_bar": {"height": 20, "art": true, "star_knob": false, "frac": 50},
		"card": {"title": 20, "body": 15, "badge": "auto", "icon_badge": "disc light", "claim_text": "Claim", "icon_on": false, "icon": "gem"},
		# the shared FRAME is its OWN standalone component (banner · card border/art · ✕ · scroll/list ·
		# padding). EVERY dialog reuses it. width here is just for the frame's own preview; each dialog
		# carries its own width. snap is the drag-grid for the banner/✕ handles.
		"frame": {
			"width_pct": 75,   # the GLOBAL dialog width (% of screen) — drives EVERY dialog
			# the SHARED cut-paper edge knob set (CUT_PAPER_KNOBS) — the SAME keys the button + toggle bar use.
			# `deckle` on replaces the flat card with a live deckled paper sheet; `corner` is the shared corner
			# (drives the flat card too). Migrated from the old cut_paper / card_corner / frame_shadow keys.
			"deckle": true, "corner": 22, "deckle_amp": 5, "deckle_freq": 5, "rim_width": 2, "edge_shadow": true, "shadow_reach": 10, "shadow_strength": 5,
			"border": "parchment", "card_art": true,
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
		"dialog": {"entries": 4, "empty_font": 28},
		# the small CARD is its own component, shared by daily + shop (cell size, highlight badges, and a
		# preview state/ribbon for trying it as a shop pack). preview + ribbon are workbench-only view toggles.
		"daily_card": {"preview": "today", "ribbon": "", "cell_w": 96, "cell_h": 116, "cell_slice": 28,
			"cell_art": true, "today_badge": "gold glow", "milestone_badge": "amber glow", "sparkle": true,
			"label_y": 12, "label_x": 0, "claim_y": 14, "info_icon": false,
			"ribbon_scale": 100, "ribbon_x": 0, "ribbon_y": -10},
		# the SETTINGS ROW style (a label + the shared switch on the rugged sage row surface). Edited on the
		# Settings item now (the standalone Toggle-card element is retired); read via Kit.toggle_card_opts_from_config.
		"toggle_card": {"label_font": 28, "switch_h": 44, "card_art": true,
			# the SHARED cut-paper edge knob set (CUT_PAPER_KNOBS) — same keys as button + frame; a finer tear
			# for the thin row strip. Drives BOTH the row surface AND the switch track/knob.
			"deckle": true, "corner": 20, "deckle_amp": 3, "deckle_freq": 5, "rim_width": 2, "edge_shadow": true, "shadow_reach": 10, "shadow_strength": 5},
		# the QUEST-GIVER card (giver_stand.gd) — the shared paper-panel card plus
		# the live portrait (left) / item-in-bubble (right) / reward pill the board draws on it. The
		# LAYOUT fractions (card/bust/bubble/item/plaque) ARE saved and the board reads them (giver_lay_from_config).
		# The DEMO knobs only preview: bust picks from the scene's giver pool on the left; tier is the asked item's
		# tier (the demo item is the Wildflower line); stars is the plaque reward; stand_w/fence_h preview the
		# board's size; met toggles the ready ✓.
		"quest_card": {"bust": 1, "tier": 3, "stars": 25, "stand_w": 480, "fence_h": 410, "met": false,
			"card_w": 92, "card_h": 65,
			"bust_size": 94, "bust_x": 27, "bust_y": 53,
			"bubble_size": 66, "bubble_x": 70, "bubble_y": 35,
			"item_size": 32, "item_x": 70, "item_y": 32, "plaque_w": 40, "plaque_x": 70, "plaque_y": 81},
		# the MAIL / reward-row card — the SHARED cut-paper edge knob set (deckle · corner · amp · freq · rim ·
		# edge_shadow) in its OWN tint (the paper fill; rim is derived a shade darker). Read by mail_card +
		# every mail_dialog row via Kit.mail_card_opts_from_config. icon/title/body/chip_text are DEMO content
		# (test-only) so the preview shows a real reward row; the game supplies each entry's own content.
		"mail_card": {"deckle": true, "corner": 18, "deckle_amp": 4, "deckle_freq": 5, "rim_width": 2, "edge_shadow": true, "shadow_reach": 10, "shadow_strength": 5,
			"tint": "F6EBDD", "icon": "gem", "title": "Acorns", "body": "premium currency for shortcuts", "chip_text": "400"},
		# …the daily DIALOG reuses the shared frame + that card, adding the grid knobs + its OWN scroll cap
		# (list_max_h 0 = no scroll, tall enough for every day; the frame's mail-list cap doesn't apply)…
		"daily": {"cols": 3, "list_max_h": 0},
		# the MYSTERY spin-reveal dialog (login_mystery.gd) — the shared frame + a row of reward cards the spin
		# lands on. NO saved knobs (the frame is the shared one; width is the engine's min(560, 94%) cap). `preview`
		# picks the pool (day 4 = 3 cards/1 win · day 7 = 5 cards/2 wins) and the state (all shown · winners landed).
		"mystery": {"preview": "day 7 · revealed"},
		# …and the SHOP dialog reuses the SAME frame + the SAME card with bigger cells, its own scroll cap
		# (list_max_h 0 = no scroll, show every item), and the GAME's real items.
		"shop": {"icon_size": 100, "card_pad": 12, "grid_gap": 14, "corner": 18},
		# the LEVEL dialog — the game's REAL sheet (level_popup.gd), screen-fraction sized off the shared
		# frame-width knob: NO own saved knobs (the old parchment level_dialog's fonts/pads are retired).
		# preview_level / into / span / mode are workbench-only preview state; the game sets them from save.
		"level": {"preview_level": 1, "into": 0, "span": 6, "mode": "info",
			"med_size": 100, "med_dy": 0, "earned_size": 100, "earned_dy": 0,
			"bar_size": 100, "bar_dy": 0, "hint_size": 100, "hint_dy": 0},
		# the DISCOVERY dialog — the STANDARD shared frame (border, banner, ✕ — all tuned on the Frame item),
		# wrapping the discovery content: the tier grid (cols, gap, scroll cap) of SHARED slot cells. The tile's
		# piece size + well face are INHERITED from the Slot cell item; only the discovery-specific knobs live
		# here — the square cell size, plain tier number, and marked-tier sparkle (percents for the sliders).
		# The grid fills the frame's inner width, derived from the Frame's chosen border padding.
		"tiers": {"cols": 3, "cell_gap": 16, "list_max_h": 0,
			"cell_w": 150, "cell_h": 150, "show_num": true, "mark_glow": 60, "mark_twinkle": 50},
		# the bottom-bar INFO BAR — the LAYOUT is the saved design; the frame is the shared gold badge skin.
		# height matches the Bag/Home wells; inner_scale / sell_icon / item_icon_scale are % of that height.
		# `filled` previews state.
		"info_bar": {"height": 130, "inner_scale": 48, "item_icon_scale": 80, "info_x": 0, "info_y": 0, "info_button_scale": 100, "name_font": 32, "sep": 10, "sell_font": 24, "sell_label_font": 22, "sell_icon": 30, "sell_badge_radius": 10, "pad_right": 16,
			"icon_scale_pct": 50, "pad_x_pct": 0, "pad_y_pct": 0, "info_x_pct": 0,
			"hide_info_button": false,
			"filled": true},
		# the RUSH BAR — plain cut-paper cards (Time · Score · Mult); the leaf / coin / crown deco art is retired
		"rush_bar": {"height": 116, "score_w": 300, "side_w": 224, "gap": 18, "label_size": 24, "value_size": 46,
			"pad": 16, "burn": 0},
		# the SETTINGS dialog = the shared frame + a column of toggle rows (one per persisted flag). width_pct
		# like every dialog; the row label + switch style are on this Settings item, the chrome on the Frame item.
		"settings": {"row_gap": 12},
		# the VAULT dialog — the shared frame in the NEW twig border + the jar hero. width_pct + the twig
		# slice/pad + the jar/plate sizes are saved; balance/claimable just preview the read. The banner / ✕
		# styling is inherited from the Frame item (like the other dialogs).
		"vault": {"card_slice": 64, "panel_pad_x": 40, "panel_pad_y": 34,
			"jar_px": 200, "plate_px": 250, "balance_font": 34, "row_gap": 12,
			"balance": 320, "claimable": true},
		# the INFO detail sheet — now the shared MAIL DIALOG (parchment cards, NO Claim) with a "Got it" footer.
		# Its face is inherited wholesale from the Frame/Card elements; only the sheet WIDTH is info-specific (a
		# 1–2 row sheet is narrower than the inbox). Read by the game's _info_sheet via Kit.info_opts_from_config.
		"info": {},
		# the BAG CELL — the slot tile, its own component (the Bag dialog reuses it). Cell size plus the
		# content/lock/cost metrics are saved; `preview` just picks which state the standalone tile shows.
		"bag_card": {"cell_w": 116, "cell_h": 120,
			"content_frac": 62, "cost_font": 24, "cost_icon": 26, "cost_y": 0, "cost_x": 0, "cost_scale": 100, "level_frac": 44},
		# the BAG dialog — the shared frame + the reused currency pill (acorn balance) + a grid of bag cells.
		# width_pct/cols/gaps/caption are saved; balance/owned/filled preview the slot ladder (the game sets
		# each from save). The banner / ✕ styling is inherited from the Frame item (like the other dialogs).
		"bag": {"cols": 6, "cell_gap": 12, "grid_inset": 70, "row_gap": 14, "list_max_h": 0,
			"caption": "Open a slot with acorns.", "owned": 8, "filled": 5},
	}
# drag-to-move (banner icon / ✕), with snap-to-grid
var _drag_kind := ""
var _drag_node: Control = null
var _drag_grab := Vector2.ZERO

## Give EVERY component a `shadow` on/off key (default ON for the elements that ship a drop shadow, OFF
## otherwise), so the universal Shadow toggle persists through _save / _load (which only round-trip keys
## present in _params). Run BEFORE _load_settings so a saved file can still override the default.
func _ensure_shadow_keys() -> void:
	var on_by_default := {"home_button": true, "board": true, "quest_card": true}
	for id in _params.keys():
		if id == "shadow":
			continue
		if not (_params[id] as Dictionary).has("shadow"):
			_params[id]["shadow"] = bool(on_by_default.get(id, false))

## A dialog's preview width in PIXELS at its AUTHORED design baseline (Kit.DIALOG_DESIGN_PCT). The frame
## then scales content to the SINGLE global width (_dlg_scale); in-game the same baseline × the live
## viewport feeds the builder while content_scale resizes to the global frame.width_pct.
func _dlg_px(id: String) -> float:
	return PHONE_W * float(Kit.DIALOG_DESIGN_PCT.get(id, 75.0)) / 100.0

## The content scale for a previewed dialog = the global frame width / the dialog's design baseline.
func _dlg_scale(id: String) -> float:
	return Kit.dialog_content_scale(_params, id)

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
		var pill_surface := pill as Control if pill.name == "GoldCurrencyPill" else pill.find_child("GoldCurrencyPill", true, false) as Control
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
		"focus_ring":
			# a sample board cell (the shared slot well + a coin) wearing the focus ring, tuned through the
			# SAME Kit transform the board reads — so the preview matches the focused-cell look in-game 1:1.
			var fo := Kit.focus_ring_opts_from_config({"focus_ring": p})
			var fcell := float(p.get("cell", 150))
			var fwrap := CenterContainer.new()
			fwrap.custom_minimum_size = Vector2(fcell + 90, fcell + 90)
			var stack := Control.new()
			stack.custom_minimum_size = Vector2(fcell, fcell)
			stack.size = Vector2(fcell, fcell)
			stack.add_child(Kit.slot_cell({"state": "empty"}, _focus_slot_opts(fcell)))
			stack.add_child(PieceView.make_piece(902, fcell))   # a tier-2 coin sits in the cell
			var ring := FocusRing.new()
			ring.size = Vector2(fcell, fcell)
			ring.color = fo.color
			ring.halo_color = fo.halo_color
			ring.halo_a = fo.halo_a
			ring.arm_frac = fo.arm_frac
			ring.thick_frac = fo.thick_frac
			ring.pad_frac = fo.pad_frac
			ring.halo = fo.halo
			stack.add_child(ring)
			fwrap.add_child(stack)
			return fwrap
		"button":
			return _button_gallery(p)
		"home_button":
			return _home_bar_preview(p)
		"hud_layout":
			return _hud_layout_preview()
		"gold_currency_pill":
			return _gold_currency_wallet_preview(p)
		"progress_bar":
			# the reusable bar at the previewed fill — built from the SAME config transform the game reads
			var po := Kit.progress_bar_opts_from_config({"progress_bar": p})
			var bar := Kit.progress_bar(float(p.frac) / 100.0, po)
			bar.custom_minimum_size.x = 320
			return bar
		"frame":
			# the SHARED frame on its own, with placeholder content — the one chrome every dialog reuses
			var fo := Kit.dialog_opts_from_config(_params)
			fo["banner_text"] = String(p.get("preview_text", "Frame"))   # type any title to test the ribbon width-scaling
			var fr := Kit.dialog_frame(_frame_placeholder(), PHONE_W * Kit.frame_width_pct(_params) / 100.0, fo)
			_attach_dialog_drag(fr)
			return fr
		"dialog":
			# build from the SHARED kit transform (same one the game uses) + the test-only preview count
			var opts := Kit.dialog_opts_from_config(_params)
			opts["entries_count"] = int(p.entries)
			opts["empty_text"] = "No mail right now — check back soon."   # so entries=0 previews the empty note (+ its font)
			opts["content_scale"] = _dlg_scale("dialog")
			# NOT draggable — the frame (banner / ✕ positions) is edited on the Frame item, not here
			return Kit.mail_dialog(Kit.DEMO_MAIL, _dlg_px("dialog"), opts)
		"daily":
			# the REAL game daily dialog — the shared frame (edited on the Frame item) wrapping LoginUI's
			# own grid + capstone (LoginUI._rebuild), the SAME renderer the daily login screen uses. The
			# old Kit.daily_dialog here was orphaned (the game builds this from login.gd, not the kit).
			return _daily_dialog_preview()
		"mystery":
			# the spin-reveal dialog (login_mystery.gd build_reveal) — the SAME face the game animates, rendered
			# STATIC so it's visual-checkable. The preview picks a pool + a state; the demo roll is DETERMINISTIC
			# (no shuffle) so the capture is repeatable. Frame edits flow through via frame_cfg: _params.
			return _mystery_preview(String(p.preview))
		"shop":
			# the REAL game storefront (shop.gd) — the SAME Shop.build_body the shop screen renders: sage
			# art-left offer cards, a 2-column grid, plain navy all-caps section headers, bespoke green price
			# slabs. The old Kit.shop_dialog here was orphaned (3-col daily-card cells, sprig dividers,
			# ribbons) — the game diverged to shop.gd. Demo data mirrors the game's sections.
			var width := _dlg_px("shop")
			var scale := _dlg_scale("shop")
			var inner := width - 2.0 * float(Kit.frame_border("parchment")["pad_x"]) / scale
			var fopts := Kit.dialog_opts_from_config(_params)
			fopts["banner_text"] = "Shop"
			fopts["content_scale"] = scale
			fopts["clip_below_banner"] = true   # rows clip UNDER the title band, like the game
			fopts["list_max_h"] = 2600.0        # show the whole storefront (the game caps to 72% of the viewport)
			return Kit.dialog_frame(ShopUI.build_body(Kit, inner, _shop_demo_sections(), ShopUI.shop_layout(_params)), width, fopts)
		"level":
			# the game's REAL level dialog sheet (level_popup.gd _sheet) — byte-for-byte what tapping
			# the Lv badge opens; only the preview state (level · progress · mode) is workbench-side.
			return _level_dialog_preview(p)
		"rush_bar":
			# the Expedition top HUD, from the SAME kit builder the game uses: plain cut-paper cards
			# (Time · Score · Mult) on the shared flat paper recipe.
			var rbo := Kit.rush_bar_opts_from_config({"rush_bar": p})
			return Kit.rush_bar(rbo, {"time": "0:58", "score": "1,250", "mult": "x2.0"})
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
				"lay": Kit.giver_lay_from_config({"quest_card": p, "shadow": _params["shadow"]}),
			}
			var made := GiverStand.make(maxi(1, int(p.bust)), demo_q, qcfg)
			var stand: Control = made.chip
			if bool(p.met):                       # preview the ready state (the board drives this live)
				var met: Control = (made.item as Dictionary).get("met")
				if met != null and is_instance_valid(met):
					met.visible = true
			return stand
		"mail_card":
			# a SINGLE reward-row card in isolation (the Welcome-gift Acorns/Water row): icon + title + body
			# + a read-only value chip, NO Claim. Built from the SAME Kit.mail_card the mail dialog uses,
			# reading this component's LIVE cut-paper edge + tint (Kit.mail_card_opts_from_config(_params)),
			# so tuning here matches the dialog rows 1:1. Content (icon/title/body/chip) is demo-only.
			var mc := Kit.mail_card_opts_from_config(_params)
			var entry := {
				"icon": String(p.get("icon", "gem")),
				"title": String(p.get("title", "Acorns")),
				"body": String(p.get("body", "premium currency for shortcuts")),
				"chip": {"icon": String(p.get("icon", "gem")), "text": String(p.get("chip_text", "400"))},
			}
			var card := Kit.mail_card(entry, 22, 16, mc)
			# a light parchment cell behind it so the deckled edge + its soft shadow read
			var cell := PanelContainer.new()
			var cbg := StyleBoxFlat.new()
			cbg.bg_color = Color("#EFE6D2")
			cbg.set_corner_radius_all(12)
			for m in ["left", "top", "right", "bottom"]:
				cbg.set("content_margin_" + m, 24)
			cell.add_theme_stylebox_override("panel", cbg)
			cell.custom_minimum_size = Vector2(460, 0)
			cell.add_child(card)
			return cell
		"tiers":
			# the REAL Discovery ladder (ladder.gd) — the SAME renderer the game opens: corner tier CHIPs
			# (cream seen / grey locked), a generator-icon header, mock-measured layout. The old
			# Kit.tiers_dialog here showed a plain-number grid with no chip/header (the game diverged to
			# ladder.gd for the flagship discovery screen). Demo: line 1, seen through tier 6, tier 6 marked.
			var tentries: Array = []
			for t in range(1, 13):
				tentries.append({"tier": t, "code": 100 + t, "seen": t <= 6})
			return LadderUI._build(Kit, _dlg_px("tiers"), {
				"header": {"kind": "tiers", "name": "Wildflower", "gid": "seed_satchel"},
				"mark_tier": 6, "entries": tentries})
		"info_bar":
			# The merged Workbench target previews the LIVE board bottom bar as one shared tray: Home · Info ·
			# Bag. The inner Home/Info/Bag frames are transparent so only the parent tray paints a border.
			return _action_bar_preview()
		"settings":
			# the SHARED frame + a column of toggle cards (the SAME builder the game's settings.gd uses)
			var setopts := Kit.settings_opts_from_config(_params)
			setopts["banner_text"] = "Settings"
			setopts["content_scale"] = _dlg_scale("settings")
			return Kit.settings_dialog(Kit.DEMO_SETTINGS, _dlg_px("settings"), setopts)
		"vault":
			# the SHARED frame in the NEW twig border + the jar hero (the SAME builder ui/vault.gd uses)
			var vopts := Kit.vault_opts_from_config(_params)
			vopts["banner_text"] = "Vault"
			vopts["content_scale"] = _dlg_scale("vault")
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
			iopts["content_scale"] = _dlg_scale("info")
			iopts["banner_icon_on"] = false
			iopts["got_it"] = "Got it"
			iopts["note"] = "Claimable just once — a warm start to the grove."
			iopts["on_close"] = func() -> void: print("WORKBENCH: info closed")
			var demo := [
				{"icon": "gem", "title": "Acorns", "body": "premium currency for shortcuts", "chip": {"icon": "gem", "text": "400"}},
				{"icon": "water", "title": "Water", "body": "tops up your watering can", "chip": {"icon": "water", "text": "60"}}]
			return Kit.mail_dialog(demo, _dlg_px("info"), iopts)
		"bag_card":
			return _slot_cell_gallery(p)
		"bag":
			# the SHARED frame + a grid of bag cells + the stored-generators row — the SAME Kit.bag_dialog the
			# game's bag_overlay.gd builds. owned/filled compose the slot ladder; the generators row is fed
			# through opts.extra (like the game) via the shared Kit.bag_generators_section, with demo generators.
			var bopts := Kit.bag_opts_from_config(_params)
			bopts["banner_text"] = "Bag"
			bopts["content_scale"] = _dlg_scale("bag")
			bopts["banner_min_w"] = PHONE_W * Kit.BANNER_MIN_W_FRAC   # 25% of the screen — matches bag_overlay.gd
			bopts["extra"] = func(co: Dictionary) -> Control:
				var gens: Array = []
				# REAL generator ids from the game roster (Game.DATA.GENERATORS) so the demo shows the
				# actual generator art, not a "?" placeholder — the game does the same via make_content.
				for gid in ["gen_1", "gen_2"]:
					var gid_str := String(gid)
					gens.append({"kind": "filled", "icon": gid_str,
						"make_content": func(sz: float) -> Control: return PieceView.make_generator(gid_str, sz)})
				return Kit.bag_generators_section("Generators", gens, co)
			return Kit.bag_dialog(_bag_demo_entries(int(p.owned), int(p.filled)), 0, _dlg_px("bag"), bopts)
	return Control.new()

# The home BOTTOM BAR exactly as map.gd builds it (`_build_bottom_bar`): the real HomeChrome tile set,
# each on its own paper role, icon over caption inside a rect Kit.home_button, with the shipped badges —
# a bare red DOT on Daily + Vault, a numbered pill only on Mail — at the same halved offset the game uses
# (map.gd:2342 `badge_dx * 0.5`). No orange play disc: every shipped tile is a rect now, Board included.
const HOME_BAR_TILES := [
	{"icon": "map", "caption": "Map", "surface": "sky"},
	{"icon": "house", "caption": "Residents", "surface": "green"},
	{"icon": "daily", "caption": "Daily", "surface": "gold", "badge": "dot"},
	{"icon": "vault", "caption": "Vault", "surface": "purple", "badge": "dot"},
	{"icon": "mail", "caption": "Mail", "surface": "kraft", "badge": "pill"},
	{"icon": "board", "caption": "Play", "surface": "coral"},
]
func _home_bar_preview(p: Dictionary) -> Control:
	# build the tiles through the SAME shared helper the game's bottom bar uses (Kit.home_bar_tile_opts),
	# so the caption font / icon scale / padding are derived from the tile width identically — the preview
	# and the shipped bar align exactly (a long caption like "Residents" fits + centres the same way).
	var tile := float(p.get("px", 158))
	var ho := Kit.home_bar_tile_opts({"home_button": p, "badge": _params["badge"], "shadow": _params["shadow"]}, tile)
	var badge_off := Vector2(float(ho.get("badge_dx", -26.0)) * 0.5, float(ho.get("badge_dy", -26.0)) * 0.5)
	var badge_opts := {"dot_px": int(ho.get("badge_dot_px", 14)), "num_size": int(ho.get("badge_num_size", 14))}
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for spec in HOME_BAR_TILES:
		var o := ho.duplicate()
		o["shape"] = "rect"
		o["surface_role"] = String(spec.surface)
		o["shadow"] = true
		var btn := Kit.home_button({"icon": String(spec.icon), "caption": String(spec.caption), "sparkle": bool(p.sparkle)}, o)
		if spec.has("badge"):
			# the SAMPLE badge count only feeds a "pill" tile (Mail); a "dot" tile is always the bare dot,
			# exactly as the game builds them (map.gd Daily/Vault → dot, Mail → pill).
			var bg := Look.badge("pill", maxi(1, int(p.get("badge_count", 3))), badge_opts) if String(spec.badge) == "pill" else Look.badge("dot", 0, badge_opts)
			Look.attach_badge(btn, bg, badge_off)
		row.add_child(btn)
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_bottom", int(p.caption_font) + 26)
	mc.add_child(row)
	return mc

# The board's own layout law, mirrored so the preview shows what the board WILL render (board wins): the
# same absolute-px clamps board.gd applies, computed on the real 1080×1920 viewport then scaled to the
# preview. Only the knobs the live board actually reads drive a region — level width, the wallet band, the
# side rail, and the info-bar width are NOT board knobs, so they draw nothing here (they were preview-only).
const HUD_BOTTOM_BAR_H := 166.0     # board.gd BOTTOM_BAR_H (fallback bar height)
const HUD_BOTTOM_BTN_PX := 130.0    # board.gd BOTTOM_BTN_PX (fallback well size)
const HUD_BOTTOM_BAR_MIN := 150.0   # board.gd BOTTOM_BAR_MIN / MAX
const HUD_BOTTOM_BAR_MAX := 200.0
const HUD_BOTTOM_BTN_MIN := 110.0
const HUD_QUEST_H_MIN := 150.0      # board.gd QUEST_H_MIN / MAX
const HUD_QUEST_H_MAX := 300.0
const HUD_UNLOCK_BAR_TOP := 122.0   # board.gd UNLOCK_BAR_TOP — the next-unlock strip's top, below the pills
const HUD_UNLOCK_BAR_H := 108.0     # a representative next-unlock strip height (board's _unlock_bar_h_px band)
func _hud_layout_preview() -> Control:
	var p: Dictionary = _params["hud_layout"]
	var layout := Kit.hud_layout_opts_from_config({"hud_layout": p})
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
	var edge := float(p.get("edge_margin_px", 18)) * s

	# --- top HUD: the level badge (sized to the currency pill height, hud.gd) + the wallet band, whose 3
	# pills are CENTRED in the currency area (hud.gd centres them; they are not left-packed). ---
	var pill_slot_w := PHONE_W * float(layout.get("currency_pill_w_frac", 0.25))
	var pill_body_w := maxf(1.0, pill_slot_w - float(p.get("edge_margin_px", 18))) * s
	var pill_h := 74.0 * s   # the shipped gold-currency-pill height (hud.gd sizes the badge to it)
	var pill_gap := float(p.get("edge_margin_px", 18)) * s
	var wallet_w := w * clampf(float(layout.get("currency_area_frac", 0.75)), 0.0, 1.0)
	var wallet_x := w - wallet_w
	var pill_run := pill_body_w * 3.0 + pill_gap * 2.0
	var pills_x := wallet_x + maxf(0.0, (wallet_w - pill_run) / 2.0)   # CENTRED in the currency band
	for i in 3:
		root.add_child(_layout_preview_box(Rect2(pills_x + (pill_body_w + pill_gap) * i, edge, pill_body_w, pill_h), Color("#F8F1C9", 0.82), "pill"))
	# the level badge is a pill-height SQUARE tucked at the top-left margin (hud.gd: lv_px = pill.pill_h)
	root.add_child(_layout_preview_box(Rect2(edge, edge, pill_h, pill_h), Color("#F6C76F", 0.72), "Lv"))
	var hud_clear_y := edge + pill_h + edge

	# --- the NEXT-UNLOCK strip: the board's single largest top-reserve consumer, below the pills. ---
	var unlock_y := HUD_UNLOCK_BAR_TOP * s
	var unlock_h := HUD_UNLOCK_BAR_H * s
	root.add_child(_layout_preview_box(Rect2(edge, unlock_y, w - edge * 2.0, unlock_h), Color("#CBB89A", 0.34), "next unlock", "HudLayoutUnlockBar"))
	var stack_top := maxf(hud_clear_y, unlock_y + unlock_h + 8.0 * s)

	# --- bottom bar + quest + board: bottom-anchored, with the board's REAL absolute-px clamps applied on
	# the full viewport then scaled — so the sliders show what the board will actually render, not a raw %. ---
	var btn_px := clampf(roundf(PHONE_W * float(layout.get("button_w_frac", 0.15))), HUD_BOTTOM_BTN_MIN, HUD_BOTTOM_BAR_MAX - (HUD_BOTTOM_BAR_H - HUD_BOTTOM_BTN_PX))
	var bottom_raw := maxf(HUD_BOTTOM_BAR_H, btn_px + (HUD_BOTTOM_BAR_H - HUD_BOTTOM_BTN_PX))
	var bottom_frac := float(layout.get("bottom_row_h_frac", 0.0))
	if bottom_frac > 0.0:
		bottom_raw = maxf(btn_px, roundf(PHONE_H * bottom_frac))
	var bottom_h := clampf(bottom_raw, HUD_BOTTOM_BAR_MIN, HUD_BOTTOM_BAR_MAX) * s
	var btn_w := btn_px * s
	var quest_h := clampf(roundf(PHONE_H * float(layout.get("quest_bar_h_frac", 0.13))), HUD_QUEST_H_MIN, HUD_QUEST_H_MAX) * s
	var gap := 8.0 * s
	var bottom_y := h - bottom_h - edge
	var live_board_size := Kit.live_board_frame_size(Vector2(PHONE_W, PHONE_H), _params) * s
	var board_max_h := maxf(1.0, (bottom_y - stack_top) - quest_h - gap * 2.0)
	var board_h := minf(live_board_size.y, board_max_h)
	var board_w := minf(w, live_board_size.x * board_h / maxf(1.0, live_board_size.y))   # keep aspect if capped
	var board_x := (w - board_w) / 2.0
	var board_y := bottom_y - gap - board_h
	root.add_child(_layout_preview_box(Rect2(board_x, board_y, board_w, board_h), Color("#A8D29B", 0.48), "board", "HudLayoutBoard"))
	# quest fence: full width (small inset), height from quest_bar_h_pct, packed just above the board.
	var quest_x := 6.0 * s
	var quest_w := maxf(1.0, w - quest_x * 2.0)
	var quest_y := board_y - gap - quest_h
	root.add_child(_layout_preview_box(Rect2(quest_x, quest_y, quest_w, quest_h), Color("#E7B36B", 0.58), "quest", "HudLayoutQuestBar"))
	# the bottom bar: a Bag well (left) + Home well (right), the info bar FILLING the space between them
	# (board.gd: the tray is SIZE_EXPAND_FILL — it takes whatever is left between the two wells).
	var info_x := btn_w
	var info_w := maxf(1.0, w - btn_w * 2.0)
	root.add_child(_layout_preview_box(Rect2(0, bottom_y, btn_w, bottom_h), Color("#B9D5FF", 0.72), "bag", "HudLayoutBottomRow"))
	root.add_child(_layout_preview_box(Rect2(info_x, bottom_y, info_w, bottom_h), Color("#F2D59A", 0.78), "info (fills)", "HudLayoutInfoBar"))
	root.add_child(_layout_preview_box(Rect2(w - btn_w, bottom_y, btn_w, bottom_h), Color("#B9D5FF", 0.72), "home"))
	return root

func _action_bar_preview_style(bar_h: float, ao: Dictionary) -> StyleBox:
	return ActionBar.bar_style(bar_h, ao)

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

func _action_bar_preview() -> Control:
	var p: Dictionary = _params["info_bar"]
	var ao := Kit.action_bar_opts_from_config({"info_bar": p})
	var layout := Kit.hud_layout_opts_from_config({"hud_layout": _params["hud_layout"]})
	var ho := Kit.home_button_opts_from_config({"home_button": _params["home_button"], "badge": _params["badge"], "shadow": _params["shadow"]})
	var preview_w := PHONE_W
	var btn_px := maxf(80.0, float(ho.get("px", roundf(preview_w * float(layout.get("button_w_frac", 0.15))))))
	var bar_h := maxf(166.0, btn_px + 36.0)

	# Mirrors the live board: a TRANSPARENT holder, with the Home/Bag tiles standing free at the two ends and
	# the painted cream tray (the info bar alone) filling the centre between them.
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(preview_w, bar_h)
	bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.name = "ActionBarPreviewRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", ActionBar.well_gap(btn_px))
	bar.add_child(ActionBar.content_host(row, bar_h, ao, "ActionBarPreviewContent"))

	ho["px"] = btn_px
	ho["shape"] = "rect"
	ho["shadow"] = true
	ho["icon_scale"] = float(ao.get("icon_scale", 0.5))
	var home_opts := ho.duplicate()
	home_opts["surface_role"] = "green"
	var home_btn := Kit.home_button({"icon": "house", "caption": ""}, home_opts)
	home_btn.name = "ActionBarPreviewHome"
	home_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	home_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_action_bar_clear_button_frame(home_btn)
	row.add_child(home_btn)
	var io := Kit.info_bar_opts_from_config({"info_bar": _params["info_bar"], "gold_currency_pill": _params["gold_currency_pill"], "shadow": _params["shadow"]})
	var ib: PanelContainer = Kit.info_bar({}, io)
	ib.name = "ActionBarPreviewInfoBar"
	ib.custom_minimum_size.x = 1.0
	ib.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ib.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ib.add_theme_stylebox_override("panel", _action_bar_transparent_info_frame(io))
	var inner := float(ib.get_meta("inner_px", 62.0))
	var item_scale := float(ib.get_meta("item_icon_scale", 0.80))
	var item_icon_px := float(ib.get_meta("item_icon_px", inner * item_scale))
	if bool(p.get("filled", true)):
		(ib.get_meta("info_icon") as CenterContainer).add_child(PieceView.make_piece(102, item_icon_px, 0.0))
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
	var ib_tray := ActionBar.info_tray(ib, bar_h, ao)
	ib_tray.name = "ActionBarPreviewInfoTray"
	ib_tray.add_theme_stylebox_override("panel", _action_bar_preview_style(bar_h, ao))
	row.add_child(_action_bar_nudge(ib_tray, float(ao.get("info_x_frac", 0.0)), "ActionBarPreviewInfoOffset"))
	var bag_opts := ho.duplicate()
	bag_opts["surface_role"] = "purple"
	var bag_btn := Kit.home_button({"icon": "bag", "caption": "", "count": "0/6"}, bag_opts)
	bag_btn.name = "ActionBarPreviewBag"
	bag_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bag_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_action_bar_clear_button_frame(bag_btn)
	row.add_child(bag_btn)
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
	l.add_theme_font_size_override("font_size", FS.TOOL)
	l.add_theme_color_override("font_color", Pal.INK if color.get_luminance() > 0.45 else Pal.CREAM)
	l.add_theme_constant_override("outline_size", 0)
	l.clip_text = true
	p.add_child(l)
	return p

# (The legacy hud_layout AUTO-derivation — _live_*_pct/_px helpers + _sync_legacy_hud_board_layout — was
# retired with the board/quest position+height knobs: the live layout is fully responsive now, so there is
# nothing to snap the workbench preview back to.)

## A faithful BOARD preview — the bamboo frame (board_frame.png nine-patch) + the cell grid (the SHARED
## slot-cell well the board + bag use) + a few demo merge pieces (PieceView), the SAME art the live board
## renders. Live board sizing is `scale`; preview-only `cell`/`cols`/`rows` let the workbench inspect
## alternate footprints. Piece size comes from the Slot-cell content_frac setting.
## --- the SHARED shadow preview + the per-component wrap ------------------------------------------

## Components whose KIT builder already casts the shared shadow internally (from opts.shadow + shadow_params);
## the view must NOT also wrap them, or the shadow would double up. (info_bar is NOT here: it returns a
## PanelContainer and builds its own frame directly, so its shadow comes from the
## view-level wrap below, like the other unwired components.)
const SHADOW_WIRED := {"home_button": true, "board": true, "button": true, "gold_currency_pill": true, "quest_card": true}

## Cast the SHARED shadow behind a component's preview when its Shadow toggle is on. Skips the wired
## components (their builder casts it) and the Shadow item itself. A rounded-rect cast (corner ~ a card's)
## suits the panel/card/dialog family; the dedicated Shadow item demos the circular shape, and the disc
## home buttons cast their own circle via the builder.
func _maybe_wrap_shadow(el: Control, id: String) -> Control:
	if id == "shadow" or SHADOW_WIRED.has(id):
		return el
	if not bool((_params[id] as Dictionary).get("shadow", false)):
		return el
	# The cut-paper frame casts its OWN shape-true deckled shadow (edge_shadow, inside CutPaperPanel), so
	# the shared rectangular box-shadow wrap would double it up with a mismatched rounded-rect. Skip it and
	# let the sheet own the shadow — the shared cut-paper "Edge shadow" toggle controls it.
	if id == "frame" and bool((_params["frame"] as Dictionary).get("deckle", false)):
		return el
	var corner := 28.0
	return Look.with_shadow(el, corner, Look.shadow_params({"shadow": _params["shadow"]}))

## The SHARED shadow on its own — a circle sample + a rounded-rect sample, both casting it, over a light cell.
func _shadow_preview() -> Control:
	# THE shadow previewed on the REAL elements that cast it (not abstract shapes): the star level
	# badge (shape-true silhouette), a live currency pill, and the giver quest card — each built by
	# the SAME builder the game calls, reading the LIVE (unsaved) shadow sliders. What this shows is
	# exactly what ships when saved.
	var cell := ColorRect.new()
	cell.color = Color("#EFE6D2")                # a light parchment so the dark soft shadow reads
	cell.custom_minimum_size = Vector2(560, 700)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 44)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(col)
	var center := func(node: Control) -> Control:
		var h := CenterContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(node)
		return h
	# the star level badge — irregular cutout, so its shadow is the baked alpha silhouette
	var live_cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH).duplicate(true)
	live_cfg["shadow"] = _params["shadow"]
	col.add_child(center.call(Look.make_level_badge(8, 120, -1, live_cfg)))
	# a live currency pill (the wallet builder)
	var popts := Kit.gold_currency_pill_opts_from_config({
		"gold_currency_pill": _params["gold_currency_pill"],
		"shadow": _params["shadow"],
	})
	popts["icon"] = "water"
	popts["count"] = 128
	popts["shadow"] = true
	col.add_child(center.call(Kit.gold_currency_pill(popts, {"water": 128})))
	# the giver quest card (the board's own GiverStand.make)
	var qp: Dictionary = _params["quest_card"]
	var noop := func(_a: Variant, _b: Variant) -> void: pass
	var demo_q := {"line": maxi(1, int(qp.bust)), "tier": int(qp.tier), "reward": {"stars": int(qp.stars)}}
	var qlay: Dictionary = Kit.giver_lay_from_config({"quest_card": qp, "shadow": _params["shadow"]})
	qlay["shadow"] = true
	var qcfg := {
		"ask_tap": noop, "stand_tap": noop,
		"wire_tap": func(node: Control, action: Callable) -> void:
			node.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and not (ev as InputEventMouseButton).pressed:
					action.call()),
		"stand_w": float(qp.stand_w) * 0.75, "fence_h": float(qp.fence_h) * 0.75,
		"lay": qlay,
	}
	col.add_child(center.call(GiverStand.make(maxi(1, int(qp.bust)), demo_q, qcfg).chip))
	return cell

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
	root.add_child(Kit.board_panel(total, Kit.board_panel_opts_from_config({"board": p, "shadow": _params["shadow"]})))

	# the wells — the SHARED slot cell (Kit.slot_cell), at the LIVE Slot-cell (bag_card) style. Preview the
	# board's outer locked/frontier cells too, so Slot-cell locked-background knobs are visible on Board.
	var opts: Dictionary = Kit.bag_card_opts_from_config(_params)
	opts["cell_w"] = cell
	opts["cell_h"] = cell
	opts["flat_board_cells"] = true
	var demo_by_cell := {}
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
				cell_data = {"state": "filled", "make_content": func(px: float) -> Control:
					return PieceView.make_piece(piece_code, px, 0.0)}
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

# The slot cell in every state + treatment the SHIPPED game renders — so the workbench shows the real
# repertoire, not one editable cell. Two rows: the BOARD treatment (flat_board_cells — the merge grid's
# thicker inset + double-weight rim) and the DIALOG treatment (dialog_cells — the sage face the bag /
# discovery / residents grids draw), plus the discovery `marked` sparkle and the Producing `dim_bg` well.
# Rendered at 2× so the cells stay comfortable to edit while the saved cell_w/cell_h stay the game size.
func _slot_cell_gallery(p: Dictionary) -> Control:
	var z := 2.0
	var base := Kit.bag_card_opts_from_config(_params)
	base["cell_w"] = float(base["cell_w"]) * z
	base["cell_h"] = float(base["cell_h"]) * z
	base["cost_font"] = int(float(base["cost_font"]) * z)
	base["cost_icon"] = float(base["cost_icon"]) * z
	base["cost_y"] = float(base["cost_y"]) * z
	base["cost_x"] = float(base["cost_x"]) * z   # cost_scale is a ratio; it stays unzoomed.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	# BOARD wells — the merge grid (board.gd / piece_view.gd pass flat_board_cells). A deep lock recedes.
	var board_opts := base.duplicate()
	board_opts["flat_board_cells"] = true
	col.add_child(_slot_row("board wells (flat)", [
		["empty", {"state": "empty"}],
		["filled", {"state": "filled", "icon": "leaf"}],
		["openable", {"state": "unlockable"}],   # the contained warm-gold well + rim (the board's highlight)
		["frontier lock", {"state": "locked", "frontier": true}],
		["deep lock", {"state": "locked", "dim": 0.6}],
	], board_opts))
	# DIALOG cells — the bag / discovery / residents grids (dialog_cells: the sage face + thin rim).
	var dlg_opts := base.duplicate()
	dlg_opts["dialog_cells"] = true
	col.add_child(_slot_row("dialog cells", [
		["empty", {"state": "empty"}],
		["filled", {"state": "filled", "icon": "leaf"}],
		["locked + cost", {"state": "locked", "cost": 120}],
		["marked", {"state": "filled", "icon": "leaf", "marked": true}],
	], dlg_opts))
	# PRODUCING line — the gen_lines dialog recedes just the well behind a full-colour piece (dim_bg).
	col.add_child(_slot_row("producing (dim_bg)", [
		["dim well", {"state": "filled", "icon": "leaf", "dim_bg": true}],
	], dlg_opts))
	return col

func _slot_row(label: String, cells: Array, opts: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", FS.TOOL)
	l.add_theme_color_override("font_color", Color(Pal.INK, 0.7))
	box.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for entry in cells:
		var cell_box := VBoxContainer.new()
		cell_box.add_theme_constant_override("separation", 2)
		cell_box.add_child(Kit.slot_cell((entry[1] as Dictionary), opts))
		var cl := Label.new()
		cl.text = String(entry[0])
		cl.add_theme_font_size_override("font_size", FS.TOOL)
		cl.add_theme_color_override("font_color", Color(Pal.INK, 0.5))
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell_box.add_child(cl)
		row.add_child(cell_box)
	box.add_child(row)
	return box

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
			# the NEXT slot is the ONLY tile that shows its acorn cost — matches bag_overlay.gd (the lone
			# price in the ladder is the buy cue); every deeper locked slot is a bare padlock, no cost.
			out.append({"kind": "next", "cost": _bag_price(k, PRICES, START)})
		else:
			out.append({"kind": "locked"})
	return out

## The acorn price to unlock 1-based slot `k` (0 for a starting/past slot) — mirrors BagOverlay._price_at.
func _bag_price(k: int, prices: Array, start: int) -> int:
	var idx := (k - 1) - start
	return int(prices[idx]) if idx >= 0 and idx < prices.size() else 0

## A demo day for the standalone Daily-card preview, in the chosen state (today shows the today badge,
## mystery shows the milestone badge + chest).
## The full 7-day demo ladder for the daily-dialog preview — days 1-2 done, day 3 today (claimable), a
## slot-4 mystery gift, days 5-6 future, day 7 the capstone milestone.
func _daily_demo_days() -> Array:
	var rewards := [{"water": 10}, {"coins": 50}, {"coins": 150}, {"gems": 30}, {"coins": 100}, {"water": 40}, {"gems": 100}]
	var out: Array = []
	for i in 7:
		var day := i + 1
		var st := "done" if day < 3 else ("today" if day == 3 else "future")
		var d := {"day": day, "label": "Day %d" % day, "reward": rewards[i], "state": st}
		if day == 4:
			d["mystery"] = true
			d["mystery_icon"] = LoginUI.ART_GIFT   # slot-4 mystery gift
		if day == 7:
			d["mystery"] = true                    # the capstone milestone chest
		out.append(d)
	return out

## The daily dialog exactly as the game builds it: the shared dialog frame (edited on the Frame item)
## wrapping LoginUI's own grid + capstone (LoginUI._rebuild), so the preview matches the daily login screen.
## The REAL level dialog sheet at the game's width rule (viewport width × the shared frame-width
## knob — level_popup.gd sizes every part as a fraction of that width, no other config).
func _level_dialog_preview(p: Dictionary) -> Control:
	var w: float = PHONE_W * Kit.frame_width_pct(_params) / 100.0
	var into: int = maxi(0, int(p.into))
	var span: int = maxi(1, int(p.span))
	return LevelPopup._sheet(w, {
		"level": maxi(1, int(p.preview_level)), "earned": into, "next": span,
		"into": into, "span": span, "remaining": maxi(0, span - into),
		"mode": String(p.mode), "gift": {"water": 30, "gems": 1}, "on_button": Callable(),
		"frame_cfg": _params,   # carries the saved "level" layout block (per-element size/dy) into _sheet
	})

## Demo section data for the shop preview — the SAME {caption, cards[]} shape shop.gd builds from live
## state (Free refill · Quick help · Acorn pouches), so Shop.build_body renders the real storefront.
func _shop_demo_sections() -> Array:
	return [
		{"caption": "Free refill", "cards": [
			{"icon": "shop_can", "count": 30, "price": "Free", "affordable": true}]},
		{"caption": "Quick help", "cards": [
			{"title": "Fill water", "icon": "shop_can", "count": 30, "price": "25", "price_icon": "gem"},
			{"title": "Coin pouch", "icon": "shop_pouch", "count": 150, "price": "5", "price_icon": "gem"}]},
		{"caption": "Acorn pouches", "cards": [
			{"icon": "pack_t1", "count": 80, "cash": true, "price": "$0.99"},
			{"icon": "pack_t2", "count": 450, "cash": true, "price": "$4.99"},
			{"icon": "pack_t3", "count": 1000, "cash": true, "price": "$9.99"},
			{"icon": "pack_t4", "count": 2200, "cash": true, "price": "$19.99"},
			{"icon": "pack_t5", "count": 6000, "cash": true, "price": "$49.99"},
			{"icon": "pack_t6", "count": 13000, "cash": true, "price": "$99.99"}]},
	]

func _daily_dialog_preview() -> Control:
	var width := _dlg_px("daily")
	var scale := _dlg_scale("daily")
	var inner := width - 2.0 * float(Kit.frame_border("parchment")["pad_x"]) / scale
	var body := VBoxContainer.new()
	body.name = "DailyBody"
	body.add_theme_constant_override("separation", int(LoginUI.GAP))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fo := Kit.dialog_opts_from_config(_params)
	fo["banner_text"] = "Daily"
	fo["content_scale"] = scale
	fo["list_max_h"] = 2000.0   # tall enough to show the whole 7-day grid + capstone (the game caps to 84% of the viewport)
	var dialog := Kit.dialog_frame(body, width, fo)
	LoginUI._rebuild(Kit, body, inner, _daily_demo_days())
	return dialog

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
	var built: Dictionary = LoginMystery.build_reveal(options, range(win), LoginMystery.reveal_width(PHONE_W), {"frame_cfg": _params, "viewport_w": PHONE_W})
	var reels: Array = built["reels"]
	var dialog: Control = built["dialog"]
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
		# the SHARED cut-paper edge from the LIVE button params (so the deckle sliders preview unsaved)
		"cp": Kit.cut_paper_opts_from_config({"button": b}, "button", Kit.BUTTON_CP_DEFAULTS),
	}
	if overrides.has("icon"):
		o["icon"] = String(overrides["icon"])      # the Card's saved icon choice ("" = none)
	# a specific badge forces art mode and overrides the default bg-based sprite
	if badge != "auto" and Kit.BADGES.has(badge) and String(Kit.BADGES[badge]) != "":
		o["art"] = true
		o["art_rel"] = String(Kit.BADGES[badge])
	# the hidden kit options, exposed as preview knobs: a paper role routes through the flat paper-cut
	# surface (borderless when Border is off), pad_scale shrinks/grows padding, static makes a display chip.
	var role := String(b.get("paper", "none"))
	if role != "none":
		o["paper"] = role
		o["art"] = false                            # paper + baked nine-patch are mutually exclusive
		o.erase("art_rel")
		if String(o["bg"]) == "green":              # the green primary branch wins over paper — step off it
			o["bg"] = "cream"
	if not bool(b.get("border", true)):
		o["border"] = 0.0
	o["pad_scale"] = float(b.get("pad_scale", 100)) / 100.0
	if bool(b.get("static", false)):
		o["static"] = true
	return o

# The shared button in every shape the KIT can already build — so the workbench governs the whole family,
# not one green pill. The FIRST tile is the live-tunable button (drives every sidebar knob); the rest are
# fixed samples of the other constructions (danger red, the cta_button's level-badge CTA, the paper roles,
# a static display chip, and the reward/amount chips) so their looks are visible in one place.
func _button_gallery(_p: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(300, 0)
	# 1) the paper-cut ROLES — green + cream + purple + coral + gold, all the SAME borderless paper surface.
	# The green tile is the LIVE, knob-driven one (the primary CTA is just the green paper role): every
	# shipped green CTA (Claim / Collect) resolves to it, and the cream "Cancel" secondary is likewise just
	# the cream paper role — so they all live in this one row, not as separate tiles.
	# (The old separate green / cta_button / danger / cream tiles are gone — danger was unused by the game.)
	var paper_row := HBoxContainer.new()
	paper_row.add_theme_constant_override("separation", 10)
	paper_row.add_child(Kit.pill_button(String(_params["button"].text), _btn_opts({"bg": "green", "paper": "green", "border": 0.0})))
	for role in ["cream", "purple", "coral", "gold"]:
		paper_row.add_child(Kit.pill_button(String(role).capitalize(), {"bg": "cream", "paper": role, "border": 0.0, "font": int(_params["button"].font)}))
	col.add_child(_button_sample("paper roles (borderless) — ● green is live", paper_row))
	# 2) a static display CHIP is NOT a separate component — it is a paper role (cream) + an icon in front
	# + static (looks like a button, not pressable). The game's reward / shop / bag / cost chips
	# (Kit.reward_chip / amount_chip) are exactly pill_button(text, {bg:"cream", icon:…, static:true}), so
	# they show here as the same paper button with an icon, not a distinct mechanism.
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 10)
	chip_row.add_child(Kit.pill_button("120", {"bg": "cream", "icon": "coin", "static": true, "border": 0.0, "font": int(_params["button"].font)}))
	chip_row.add_child(Kit.pill_button("60", {"bg": "cream", "icon": "water", "static": true, "border": 0.0, "font": int(_params["button"].font)}))
	col.add_child(_button_sample("cream role + icon + static (= the game's chips)", chip_row))
	return col

func _button_sample(label: String, btn: Control) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", FS.TOOL)
	l.add_theme_color_override("font_color", Color(Pal.INK, 0.7))
	box.add_child(l)
	var holder := HBoxContainer.new()
	holder.add_child(btn)
	box.add_child(holder)
	return box

## --- gallery (left) ------------------------------------------------------------------------------

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

## The per-element explanatory notes shown under the caption.
func _sidebar_notes(_id: String) -> void:
	if _selected == "dialog" or _selected == "daily" or _selected == "mystery" or _selected == "shop" or _selected == "settings":
		var note := Label.new()
		var card_src := ""
		if _selected == "daily" or _selected == "shop":
			card_src = " the mail-card style is on the Mail dialog item;"
		elif _selected == "settings":
			card_src = " the row label + switch size are below;"
		note.text = "The frame (banner · border · ✕ · scroll · padding) is SHARED — edit it on the Frame item.%s Here: this dialog's content." % card_src
		note.add_theme_font_size_override("font_size", FS.TOOL)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	if _selected == "dialog":
		var note := Label.new()
		note.text = "Claim inherits the Button's STYLE (font / corner / art / shadow). Its badge + icon are the Card's own saved choice."
		note.add_theme_font_size_override("font_size", FS.TOOL)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	if _selected == "tiers":
		var note := Label.new()
		note.text = "This is the game's REAL Discovery ladder (ladder.gd): each cell wears a corner tier CHIP (cream when seen, grey when locked), a generator-icon header sits on top, and the layout is mock-measured — all fixed in ladder.gd. The grid + cell knobs below tune the SHARED tiers style (also used by the resident ladder + the Producing dialog); the Discovery ladder overrides the cell gap + swaps the plain tier number for its chip, so those two do not change this preview."
		note.add_theme_font_size_override("font_size", FS.TOOL)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	if _selected == "bag_card":
		var note := Label.new()
		note.text = "ONE cell shared by the board wells and every dialog grid (bag · discovery · residents). The preview shows both treatments — the board's flat wells and the dialogs' sage cells — plus the discovery marked sparkle and the Producing dim-well. The well faces + rim are fixed in the kit; only the sizes below are tunable."
		note.add_theme_font_size_override("font_size", FS.TOOL)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	if _selected == "bag":
		var note := Label.new()
		note.text = "Reuses the SHARED frame (banner · border · ✕ — edit on the Frame item) + the REUSED currency pill (the acorn balance — edit on the Currency pill item). The tile is the Bag cell item. Here: the grid + the preview ladder."
		note.add_theme_font_size_override("font_size", FS.TOOL)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	if _selected == "board":
		var note := Label.new()
		note.text = "A live preview of the merge board: the frame + the shared Slot cell states (open wells, frontier locks, deep locks) + demo pieces. Edit piece size and cell background on the Slot cell item. SCALE zooms the live board; CELL/COLS/ROWS are preview-only."
		note.add_theme_font_size_override("font_size", FS.TOOL)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)

## The UNIVERSAL Shadow toggle — every component casts the ONE shared shadow (tuned on the Shadow item).
## Skipped on the Shadow item itself (that IS the editor).
func _sidebar_common_rows(_id: String) -> void:

	# the UNIVERSAL Shadow toggle — every component casts the ONE shared shadow (tuned on the Shadow item).
	# Skipped on the Shadow item itself (that IS the editor).
	if _selected != "shadow":
		_sidebar_body.add_child(_toggle_row("Shadow", "shadow"))
		var sn := Label.new()
		sn.text = "Casts the shared drop shadow — tune its look on the Shadow item."
		sn.add_theme_font_size_override("font_size", FS.TOOL)
		sn.add_theme_color_override("font_color", Color(Pal.STRAW, 0.7))
		sn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(sn)
		_sidebar_body.add_child(HSeparator.new())

	# Every element splits its controls into the two buckets (see TEST_KEYS): the persisted design
	# config first, then the transient test/preview scaffolding that the config file never touches.

func _element_sidebar(_id: String) -> void:
	match _selected:
		"shadow":
			_group_header("Saved to config", true)
			_section_header("Cast (offset-based — size-independent)")
			_sidebar_body.add_child(_slider_row(["offset_x", -40, 40]))   # horizontal cast (px): −left / +right
			_sidebar_body.add_child(_slider_row(["offset_y", -40, 40]))   # vertical cast (px): −up / +down
			_section_header("Shape")
			_sidebar_body.add_child(_slider_row(["blur", 0, 40]))         # soft feather radius (px)
			_sidebar_body.add_child(_slider_row(["spread", -20, 0]))      # tighten the shadow (px; 0 = full blur reach — growing outward reads as a collar, so it is not offered)
			_section_header("Tint")
			_sidebar_body.add_child(_slider_row(["alpha", 0, 80]))        # opacity (%) — the tint is fixed slate (skin.gd)
		"board":
			_group_header("Saved to config", true)
			_section_header("Size")
			_sidebar_body.add_child(_slider_row(["scale", 30, 200]))   # overall zoom (% — frame + cells together)
			_sidebar_body.add_child(_slider_row(["gap", 0, 30]))       # gutter between cells (px)
			_sidebar_body.add_child(_slider_row(["frame", 0, 120]))    # bamboo frame overhang (px)
			_group_header("Preview only — not saved", false)
			_sidebar_body.add_child(_slider_row(["cell", 28, 120]))    # preview cell width (px)
			_sidebar_body.add_child(_slider_row(["cols", 1, 9]))
			_sidebar_body.add_child(_slider_row(["rows", 1, 12]))
			_sidebar_body.add_child(_toggle_row("Demo pieces", "pieces"))
			_group_header("Saved to config", true)
			_section_header("Frame")
			_sidebar_body.add_child(_option_row("Style", "frame_style", ["meadow", "code"]))
			_sidebar_body.add_child(_slider_row(["frame_corner", 0, 90]))         # corner radius (both styles)
			_section_header("Code border (when Style = code)")
			_sidebar_body.add_child(_slider_row(["frame_border_w", 0, 16]))       # outer border width
			_sidebar_body.add_child(_slider_row(["frame_inner_w", 0, 10]))        # inner hairline — the border of the border
			_sidebar_body.add_child(_slider_row(["frame_top_shadow", 0, 100]))    # top inset shadow — depth near the top
		"focus_ring":
			_group_header("Saved to config", true)     # flows to the LIVE board (Kit.focus_ring_opts_from_config)
			_section_header("Colour")
			_sidebar_body.add_child(_color_row("Bracket", "color"))         # the corner-bracket colour
			_sidebar_body.add_child(_color_row("Halo", "halo_color"))       # the light outline behind the brackets
			_sidebar_body.add_child(_slider_row(["halo_a", 0, 100]))        # halo opacity %
			_sidebar_body.add_child(_toggle_row("Halo underlay", "halo"))   # turn the light underlay on/off
			_section_header("Proportions (% of cell)")
			_sidebar_body.add_child(_slider_row(["arm_pct", 5, 50]))        # bracket arm length
			_sidebar_body.add_child(_slider_row(["thick_pct", 1, 20]))      # bracket line thickness
			_sidebar_body.add_child(_slider_row(["pad_pct", 0, 20]))        # inset from the cell edge
			_group_header("Test only — not saved", false)
			_sidebar_body.add_child(_slider_row(["cell", 90, 240]))         # preview size (px)
		"button":
			_group_header("Saved to config", true)            # only the shared STYLE persists
			_sidebar_body.add_child(_toggle_row("Use art", "art", true))   # sprite (scaled whole) vs code-drawn
			_sidebar_body.add_child(_slider_row(["font", 12, 40]))
			_group_header("Test only — not saved", false)      # preview props; text/badge/icon live on the Card
			_sidebar_body.add_child(_text_row("Text", "text"))
			_sidebar_body.add_child(_option_row("Background", "bg", ["green", "cream", "danger"]))
			if bool(_params["button"]["art"]):
				_sidebar_body.add_child(_option_row("Badge", "badge", Kit.BADGES.keys()))
			_sidebar_body.add_child(_option_row("Icon", "icon", ICONS))
			_sidebar_body.add_child(_slider_row(["icon_size", 8, 60]))
			_sidebar_body.add_child(_toggle_row("Enabled", "enabled"))
			_cut_paper_section("button")   # the shared edge knob set (corner + deckle amp/freq/rim + edge shadow)
			_sidebar_body.add_child(_toggle_row("Drop shadow (non-deckle)", "shadow"))   # global box shadow, used when the edge is off
			_section_header("Paper-cut surface (overrides bg/art)")
			_sidebar_body.add_child(_option_row("Paper role", "paper", ["none", "cream", "sky", "green", "purple", "coral", "gold", "kraft", "slate"], true))
			_sidebar_body.add_child(_toggle_row("Border", "border"))    # off = the borderless paper button
			_sidebar_body.add_child(_slider_row(["pad_scale", 40, 140]))  # % padding (the cost chip uses < 100 to fit a card)
			_sidebar_body.add_child(_toggle_row("Static (display chip)", "static"))   # looks like a button, not pressable
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
			_section_header("Tile badge (dot on Daily/Vault, count pill on Mail)")
			_sidebar_body.add_child(_slider_row(["badge_dx", -30, 20]))   # badge x past the disc corner (neg tucks in)
			_sidebar_body.add_child(_slider_row(["badge_dy", -30, 20]))   # badge y past the disc corner (neg tucks in)
			_sidebar_body.add_child(_slider_row(["badge_dot_px", 8, 28]))     # the bare-dot badge diameter
			_sidebar_body.add_child(_slider_row(["badge_num_size", 8, 28]))   # the count-badge number size (pill tracks it)
			_section_header("Board bag/home well count (the in-tile \"x/y\", board screen)")
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
			_sidebar_body.add_child(_slider_row(["badge_count", 1, 99]))   # sample count for the Mail pill (dot tiles ignore it)
		"hud_layout":
			_group_header("Saved to config", true)
			_section_header("Top HUD")
			_sidebar_body.add_child(_slider_row(["currency_area_pct", 50, 90]))    # wallet's right-side band (% screen width)
			_sidebar_body.add_child(_slider_row(["currency_pill_w_pct", 12, 35]))  # each currency pill width (% screen width)
			_sidebar_body.add_child(_slider_row(["edge_margin_px", 0, 48]))        # shared wallet + rail right-edge inset (px)
			_section_header("Buttons + board bottom")
			_sidebar_body.add_child(_slider_row(["button_w_pct", 8, 25]))          # rail/nav/back/bag/home width (% screen width)
			_sidebar_body.add_child(_slider_row(["bottom_row_h_pct", 8, 22]))      # board-only bottom tray height (% screen height)
			_section_header("Quest bar")
			# Position/board-height knobs retired — the board fills the width / auto-rotates and the quest+board
			# stack is bottom-anchored, so only the quest band HEIGHT (% screen height, clamped in board.gd) is tunable.
			_sidebar_body.add_child(_slider_row(["quest_bar_h_pct", 5, 25]))       # quest fence height (% screen height)
		"gold_currency_pill":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["overall_scale", 60, 220]))
			_sidebar_body.add_child(_slider_row(["pill_w", 180, 380]))
			_sidebar_body.add_child(_slider_row(["pill_h", 64, 132]))
			_cut_paper_section("gold_currency_pill")   # the shared rugged-edge knobs (deckle · corner · amp · freq · rim · shadow)
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
			_sidebar_body.add_child(_slider_row(["num_size", 16, 72]))
			_sidebar_body.add_child(_slider_row(["amount_x", -40, 120]))
			_section_header("Plus button")
			_sidebar_body.add_child(_slider_row(["plus_x", -200, 40]))
			_sidebar_body.add_child(_slider_row(["plus_y", -60, 60]))   # move the whole green button up/down
			_sidebar_body.add_child(_slider_row(["plus_radius", 8, 44]))
			_sidebar_body.add_child(_slider_row(["plus_shine", 0, 60]))
			_sidebar_body.add_child(_slider_row(["plus_stroke", 0, 5]))
			_sidebar_body.add_child(_slider_row(["plus_font", 50, 160]))
			_sidebar_body.add_child(_slider_row(["plus_button", 40, 135]))
			_sidebar_body.add_child(_slider_row(["plus_round", 0, 18]))
			_sidebar_body.add_child(_slider_row(["plus_hue", 55, 82]))
			_sidebar_body.add_child(_slider_row(["plus_label_y", -20, 20]))   # nudge the "+" up/down within the green button
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
			_sidebar_body.add_child(_slider_row(["empty_font", 12, 48]))   # the empty-state note size ("No mail …")
			# the MAIL CARD style (folded in from the retired Card item — still saved under config["card"],
			# read by mail_dialog + reused by daily/shop/settings/info). Every row targets the "card" dict.
			_section_header("Mail card")
			_sidebar_body.add_child(_option_row("Icon badge", "icon_badge", Kit.ICON_BADGES.keys(), false, "card"))
			_sidebar_body.add_child(_option_row("Button badge", "badge", Kit.BADGES.keys(), false, "card"))
			_sidebar_body.add_child(_text_row("Claim text", "claim_text", "card"))
			_sidebar_body.add_child(_toggle_row("Claim icon", "icon_on", true, "card"))   # whether the Claim shows an icon
			if bool(_params["card"]["icon_on"]):
				_sidebar_body.add_child(_option_row("Icon", "icon", ICONS.slice(1), false, "card"))   # ICONS minus "none"
			_sidebar_body.add_child(_slider_row(["title", 12, 30], "card"))
			_sidebar_body.add_child(_slider_row(["body", 10, 24], "card"))
			_group_header("Test only — not saved", false)
			_sidebar_body.add_child(_slider_row(["entries", 0, 12]))   # how many rows to preview (0 = the empty state)
		"daily":
			# the daily dialog is the game's real login screen (LoginUI's grid + capstone) inside the shared
			# frame. The frame (banner · border · ✕) is edited on the Frame item; the day grid + capstone
			# layout is fixed in login.gd, so there are no grid knobs here.
			_sidebar_note("The daily dialog is the game's real login screen (login.gd) — the day grid + capstone are fixed there. Edit the shared frame on the Frame item.")
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
			# the shop is the game's real storefront (shop.gd Shop.build_body). Each offer-card metric is
			# SAVED config the game reads (shop.gd shop_layout), so tuning here flows to the live shop:
			# the product icon size, the card's inner padding, the grid gap/margin, and the card corner.
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["icon_size", 50, 160]))   # product art size, % of default
			_sidebar_body.add_child(_slider_row(["card_pad", 2, 40]))      # inner padding (px)
			_sidebar_body.add_child(_slider_row(["grid_gap", 2, 48]))      # gap / margin between cards + sections (px)
			_sidebar_body.add_child(_slider_row(["corner", 0, 40]))        # card corner radius (px)
		"level":
			# the sheet is the game's real level_popup.gd. Each element's SIZE (% of its default) and its
			# vertical NUDGE (px, +down) are SAVED — the game reads them from the level config, so tuning
			# here flows to the live level-up dialog. (Title font + position are the shared Frame banner.)
			_group_header("Saved to config", true)
			_section_header("Medallion")
			_sidebar_body.add_child(_slider_row(["med_size", 40, 160]))   # % of the default rosette diameter
			_sidebar_body.add_child(_slider_row(["med_dy", -40, 80]))     # nudge down(+) / up(−), px
			_section_header("Earned pill")
			_sidebar_body.add_child(_slider_row(["earned_size", 50, 160]))
			_sidebar_body.add_child(_slider_row(["earned_dy", -40, 80]))
			_section_header("Progress bar")
			_sidebar_body.add_child(_slider_row(["bar_size", 50, 160]))
			_sidebar_body.add_child(_slider_row(["bar_dy", -40, 80]))
			_section_header("Hint / reward line")
			_sidebar_body.add_child(_slider_row(["hint_size", 50, 160]))
			_sidebar_body.add_child(_slider_row(["hint_dy", -40, 80]))
			_group_header("Test only — not saved", false)
			_sidebar_body.add_child(_option_row("Mode", "mode", ["info", "levelup"]))
			_sidebar_body.add_child(_slider_row(["preview_level", 1, 50]))
			_sidebar_body.add_child(_slider_row(["into", 0, 30]))
			_sidebar_body.add_child(_slider_row(["span", 1, 30]))
		"rush_bar":
			_group_header("Saved to config", true)
			_section_header("Cells — plain cut-paper cards")
			_sidebar_body.add_child(_slider_row(["height", 60, 180]))    # cell height
			_sidebar_body.add_child(_slider_row(["score_w", 160, 460]))  # centred Score cell width
			_sidebar_body.add_child(_slider_row(["side_w", 120, 380]))   # Time / Mult cell width
			_sidebar_body.add_child(_slider_row(["gap", 0, 60]))         # spacing between cells
			_sidebar_body.add_child(_slider_row(["pad", 4, 40]))         # cell content inset
			_section_header("Text")
			_sidebar_body.add_child(_slider_row(["label_size", 12, 48]))  # the Time / Score / Mult caption
			_sidebar_body.add_child(_slider_row(["value_size", 20, 80]))  # the numerals
			_sidebar_body.add_child(_slider_row(["burn", 0, 100]))         # engraved burn (dark ink + emboss + outline)
		"tiers":
			_group_header("Saved to config", true)
			_section_header("Layout (grid — no vines)")
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
			_sidebar_body.add_child(_slider_row(["info_x_pct", -30, 30]))          # Info pill horizontal nudge
			_section_header("Info content")
			_sidebar_body.add_child(_slider_row(["height", 90, 180]))       # bar height (matches the Bag/Home wells)
			_sidebar_body.add_child(_slider_row(["inner_scale", 30, 70]))   # the info ⓘ + piece box as % of the height
			_sidebar_body.add_child(_slider_row(["item_icon_scale", 50, 160]))  # selected item/generator art as % of the bar height
			_sidebar_body.add_child(_slider_row(["info_x", -120, 120]))     # nudge the info ⓘ button left(−) / right(+)
			_sidebar_body.add_child(_slider_row(["info_y", -120, 120]))     # nudge the info ⓘ button up(−) / down(+)
			_sidebar_body.add_child(_slider_row(["info_button_scale", 50, 160]))  # resize the info ⓘ button inside its slot
			_sidebar_body.add_child(_toggle_row("Hide info button", "hide_info_button"))  # hide the floating ⓘ in workbench + game
			_sidebar_body.add_child(_slider_row(["name_font", 18, 44]))     # the "<name> · Tier N" font
			_sidebar_body.add_child(_slider_row(["sep", 0, 30]))            # gap between the bar's controls
			_sidebar_body.add_child(_slider_row(["sell_label_font", 14, 34]))  # the plain "Sell" caption font
			_sidebar_body.add_child(_slider_row(["sell_font", 16, 40]))     # the sell badge's payout number font
			_sidebar_body.add_child(_slider_row(["sell_icon", 15, 50]))     # the payout coin as % of the height
			_sidebar_body.add_child(_slider_row(["sell_badge_radius", 0, 30]))  # the green badge corner radius
			_sidebar_body.add_child(_slider_row(["pad_right", 0, 80]))      # right padding — how near the Sell button sits to the edge
			_group_header("Test only — not saved", false)                  # preview selected vs empty state
			_sidebar_body.add_child(_toggle_row("Filled (vs empty)", "filled", true))   # preview the selected vs empty state
		"settings":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["row_gap", 0, 40]))       # gap between toggle rows
			# the settings ROW style (the retired standalone Toggle-card item folded in here): the row's
			# label size + the switch height. Stored under the "toggle_card" config block, read by
			# Kit.toggle_card_opts_from_config, so the game's rows and this preview stay in lockstep.
			_section_header("Row (label + switch)")
			_sidebar_body.add_child(_slider_row(["label_font", 16, 44], "toggle_card"))
			_sidebar_body.add_child(_slider_row(["switch_h", 28, 72], "toggle_card"))
			_cut_paper_section("toggle_card")   # the shared edge for the row surface AND the switch track/knob
		"vault":
			_vault_sidebar()         # the vault's own layout + twig-border knobs (chrome on the Frame item)
		"info":
			# the info sheet IS the mail dialog: its border/banner/✕/card art + fonts are tuned on the Frame +
			# Card elements, and its width is the global frame width. No info-specific knobs remain.
			_section_header("Face shared with the Mail dialog — tune the Frame + Card elements")
		"bag_card":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["cell_w", 60, 180]))
			_sidebar_body.add_child(_slider_row(["cell_h", 60, 200]))
			_sidebar_body.add_child(_slider_row(["content_frac", 30, 95]))   # the piece size (% of cell)
			_sidebar_body.add_child(_slider_row(["level_frac", 20, 70]))     # the level badge size (% of cell)
			_sidebar_body.add_child(_slider_row(["cost_font", 12, 48]))
			_sidebar_body.add_child(_slider_row(["cost_icon", 16, 56]))
			_sidebar_body.add_child(_slider_row(["cost_y", -60, 60]))        # nudge the acorn cost up(-) / down(+)
			_sidebar_body.add_child(_slider_row(["cost_x", -60, 60]))        # nudge the acorn cost left(-) / right(+)
			_sidebar_body.add_child(_slider_row(["cost_scale", 30, 130]))    # the cost pill's overall size (% — shrink to fit the card)
			# (The cell background fills + rim + depth and the old unlockable glow/sparkle were retired: the
			# kit hard-codes the well faces, and every shipped caller suppresses the highlight — the sliders
			# tuned nothing the game read. The preview above shows the real board / dialog / marked / dim_bg
			# states instead.)
		"bag":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["cols", 1, 8]))
			_sidebar_body.add_child(_slider_row(["cell_gap", 0, 40]))
			_sidebar_body.add_child(_slider_row(["grid_inset", 0, 200]))    # how far the parchment border eats the grid width
			_sidebar_body.add_child(_slider_row(["row_gap", 0, 40]))        # gap between grid / generators / footer
			_sidebar_body.add_child(_slider_row(["list_max_h", 0, 1200]))   # height cap; 0 = no scroll
			_sidebar_body.add_child(_text_row("Caption", "caption"))
			_group_header("Test only — not saved", false)                  # the game sets each from save
			# (the bag has no acorn-balance pill — the HUD carries the counter; the only price is the next
			# slot's cost chip, so the old balance / acorn_x knobs were dead and are removed.)
			_sidebar_body.add_child(_slider_row(["owned", 0, 18]))          # how many slots are owned
			_sidebar_body.add_child(_slider_row(["filled", 0, 18]))         # how many owned slots hold a piece
		"quest_card":
			# The LAYOUT block (card_w..plaque_y) are the giver-card fractions, in PERCENT. They are SAVED to
			# config; the board reads them live via Kit.giver_lay_from_config, so a tweak here flows straight to
			# the live giver card on Save. (giver_stand.LAY stays the shipped fallback for an empty config.)
			_group_header("Layout — saved to config (board reads it live)", true)
			_sidebar_body.add_child(_slider_row(["card_w", 40, 300]))      # box width  (% of stand) — independent of height
			_sidebar_body.add_child(_slider_row(["card_h", 40, 300]))      # box height (% of stand) — independent of width
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
			# (the card drop-shadow is the UNIVERSAL Shadow toggle added below — the one shared shadow, tuned on
			# the Shadow item — not a per-card control.)
			_group_header("Demo (preview only)", false)
			_sidebar_body.add_child(_slider_row(["bust", 0, 15]))          # which giver (0..15) — also the asked line
			_sidebar_body.add_child(_slider_row(["tier", 1, 12]))          # the asked item's tier
			_sidebar_body.add_child(_slider_row(["stars", 1, 99]))         # the +N reward on the plaque
			_sidebar_body.add_child(_slider_row(["stand_w", 200, 640]))    # preview stand width
			_sidebar_body.add_child(_slider_row(["fence_h", 160, 460]))    # preview stand height
			_sidebar_body.add_child(_toggle_row("Ready (✓)", "met"))       # preview the deliverable state
		"mail_card":
			# SAME shared edge knob set as the settings bar (Kit.CUT_PAPER_KNOBS) — one section, no
			# duplication; a new knob appears here automatically — plus this card's OWN tint. The card's
			# saved STYLE is the edge + tint; the content rows below are demo, to preview a real reward row.
			_group_header("Saved to config", true)
			_cut_paper_section("mail_card")                                # the shared cut-paper edge
			_sidebar_body.add_child(_color_row("Tint", "tint"))            # the paper fill (rim derives from it)
			_group_header("Demo content — not saved", false)               # the game supplies each entry's content
			_sidebar_body.add_child(_option_row("Icon", "icon", ICONS.slice(1)))   # the reward icon (ICONS minus "none")
			_sidebar_body.add_child(_text_row("Title", "title"))
			_sidebar_body.add_child(_text_row("Body", "body"))
			_sidebar_body.add_child(_text_row("Chip value", "chip_text"))


## The shared FRAME's options: the saved-to-config bucket (sub-grouped by function), then test-only.
## The SHARED cut-paper edge section — rendered from Kit.CUT_PAPER_KNOBS (the ONE knob-set definition), so
## the Button, Frame, and Settings-row inspectors show the SAME rows and a new schema knob appears in all
## three automatically. `target` is the component's config block; each writes its own values. The enable
## toggle + corner always show; the deckle-only knobs (amp · freq · rim · edge shadow) show when on.
func _cut_paper_section(target: String) -> void:
	_section_header("Cut-paper edge (shared)")
	var on := bool((_params[target] as Dictionary).get("deckle", true))
	for knob in Kit.CUT_PAPER_KNOBS:
		var key := String(knob["key"])
		if not on and key != "deckle" and key != "corner":
			continue   # edge off → only the enable toggle + the general corner stay tunable
		if String(knob.get("kind", "slider")) == "toggle":
			_sidebar_body.add_child(_toggle_row(String(knob["label"]), key, key == "deckle", target))
		else:
			_sidebar_body.add_child(_slider_row([key, knob["min"], knob["max"]], target))

func _frame_sidebar() -> void:
	_group_header("Saved to config", true)
	_section_header("Dialog width (all dialogs)")
	_sidebar_body.add_child(_slider_row(["width_pct", 30, 100]))   # the SINGLE global dialog width — % of screen
	_cut_paper_section("frame")   # the shared edge knob set (replaces the frame's bespoke cut-paper rows)
	# The Card section (border · 9-slice · slice L/T/R/B · H/V stretch) is retired: the code-drawn cut-paper
	# sheet is the frame face now, so the baked 9-slice card knobs no longer shape anything. The keys stay in
	# config for the fallback baked path when the edge is off — they're just no longer tunable here.

	# TITLE — the dialog title text only (there is no ribbon banner behind it in the cut-paper frame): its
	# size, position, and engrave style. Ribbon/icon knobs (band height, banner icon, tail padding, banner
	# node offset) are retired with the ribbon; their config values persist for the fallback face.
	_section_header("Title")
	_sidebar_body.add_child(_slider_row(["banner_font", 16, 56]))          # size
	_sidebar_body.add_child(_slider_row(["banner_text_x", -150, 150]))     # position — horizontal
	_sidebar_body.add_child(_slider_row(["banner_text_y", -80, 80]))       # position — vertical
	_sidebar_body.add_child(_slider_row(["banner_burn", 0, 100]))          # style — engrave intensity (0 = off)

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

# Slot-well opts for the focus-ring preview: the SAME shared slot cell the board draws, sized to the
# preview cell so the brackets frame a real board well.
func _focus_slot_opts(fcell: float) -> Dictionary:
	var o := Kit.bag_card_opts_from_config(_params)
	o["cell_w"] = fcell
	o["cell_h"] = fcell
	return o

