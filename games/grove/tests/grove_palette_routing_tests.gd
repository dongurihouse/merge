extends SceneTree
## Isolated contract tests for Meadow Sky palette roles and atlas routing.
## This suite deliberately avoids constructing Board/Map/UI scenes so it remains useful while
## grove_ui_tests has unrelated storefront/layout failures.

const Pal = preload("res://games/grove/grove_palette.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _assert_color(name: String, actual: Color, expected_hex: String) -> void:
	ok(actual == Color(expected_hex), "%s is fixed Meadow Sky %s (got %s)" % [name, expected_hex, actual.to_html(false)])

func _assert_route(source_name: String, canonical_rel: String) -> void:
	var source := "res://games/grove/assets/ui/meadow_v2/%s.png" % source_name
	var canonical := "res://games/grove/assets/ui/%s" % canonical_rel
	ok(FileAccess.file_exists(canonical), "%s canonical resource exists" % canonical_rel)
	if FileAccess.file_exists(canonical):
		ok(FileAccess.get_sha256(canonical) == FileAccess.get_sha256(source),
			"%s routes meadow_v2/%s.png without divergence" % [canonical_rel, source_name])
		ok(ResourceLoader.exists(canonical), "%s is imported as a Godot resource" % canonical_rel)

func _initialize() -> void:
	print("== Grove Meadow Sky palette/routing tests ==")

	var palette_roles := {
		"CREAM": [Pal.CREAM, "F6EBDD"], "STRAW": [Pal.STRAW, "D6A94C"],
		"INK": [Pal.INK, "243B4B"], "BARK": [Pal.BARK, "3F6D7D"],
		"SKY": [Pal.SKY, "6FA9C0"], "MEADOW": [Pal.MEADOW, "A8D3B9"],
		"LEAF": [Pal.LEAF, "5F9B6D"], "CLAY": [Pal.CLAY, "D87865"],
		"GROUND": [Pal.GROUND, "F6EBDD"], "GROUND_EDGE": [Pal.GROUND_EDGE, "3F6D7D"],
		"BRAMBLE_BG": [Pal.BRAMBLE_BG, "8296AF"], "BRAMBLE_EDGE": [Pal.BRAMBLE_EDGE, "3F6D7D"],
		"BG": [Pal.BG, "6FA9C0"], "BG_DEEP": [Pal.BG_DEEP, "3F6D7D"],
		"TEXT": [Pal.TEXT, "F6EBDD"], "TEXT_MUTED": [Pal.TEXT_MUTED, "8296AF"],
		"GOLD": [Pal.GOLD, "D6A94C"], "COIN_EDGE": [Pal.COIN_EDGE, "3F6D7D"],
		"PLANK": [Pal.PLANK, "3F6D7D"], "PLANK_EDGE": [Pal.PLANK_EDGE, "243B4B"],
		"PILL": [Pal.PILL, "F6EBDD"], "PILL_EDGE": [Pal.PILL_EDGE, "3F6D7D"],
		"BTN_PRIMARY": [Pal.BTN_PRIMARY, "5F9B6D"], "BTN_PRIMARY_EDGE": [Pal.BTN_PRIMARY_EDGE, "3F6D7D"],
		"SCREEN_BG": [Pal.SCREEN_BG, "6FA9C0"], "SURFACE": [Pal.SURFACE, "F6EBDD"],
		"SURFACE_FRAME": [Pal.SURFACE_FRAME, "3F6D7D"], "CELL_EMPTY": [Pal.CELL_EMPTY, "A8D3B9"],
		"LOCKED": [Pal.LOCKED, "8296AF"], "LOCKED_GLYPH": [Pal.LOCKED_GLYPH, "3F6D7D"],
		"NEAR_UNLOCK": [Pal.NEAR_UNLOCK, "A8D3B9"], "NEAR_HINT": [Pal.NEAR_HINT, "5F9B6D"],
		"CARD_PEDESTAL": [Pal.CARD_PEDESTAL, "F6EBDD"], "INK_MUTED": [Pal.INK_MUTED, "3F6D7D"],
		"ACCENT_CTA": [Pal.ACCENT_CTA, "5F9B6D"], "ACCENT_REWARD": [Pal.ACCENT_REWARD, "D6A94C"],
		"ACCENT_ALERT": [Pal.ACCENT_ALERT, "D87865"], "ACCENT_INFO": [Pal.ACCENT_INFO, "6FA9C0"],
	}
	for role in palette_roles:
		_assert_color(role, palette_roles[role][0], palette_roles[role][1])

	var routes := {
		# Currency, navigation, and controls used by Skin.icon().
		"water_drop": ["shared/icon_water.png"],
		"coin": ["currency/icon_coin.png", "currency/coin.png", "rush/bar_coin.png"],
		"acorn": ["currency/icon_gem.png", "rush/acorn.png"],
		"nav_home": ["shared/icon_home.png", "shared/icon_house.png"],
		"nav_board": ["shared/icon_board.png"], "nav_maps": ["shared/icon_map.png"],
		"nav_bag": ["shared/icon_bag.png"], "nav_shop": ["shared/icon_shop.png"],
		"button_plus": ["shared/icon_plus.png"], "button_info": ["shared/icon_info.png"],
		"button_confirm": ["shared/icon_check.png"], "button_back": ["map/back_arrow.png"],
		# Shared button, card, panel, progress, board-cell, and dialog atoms.
		"button_primary": ["kit/mail_pill.png", "kit/bag_pill_green.png", "kit/shop_buy.png", "kit/level_btn.png", "board/btn_pill_green.png"],
		"button_secondary": ["kit/mail_pill_cream.png", "kit/bag_pill.png"],
		"resource_pill": ["shared/panel_pill.png"],
		"button_close": ["kit/mail_close.png", "kit/shop_close.png"],
		"card_generic": ["kit/mail_card.png", "kit/daily_card.png", "kit/bag_card.png", "rush/score_card.png", "rush/score_card_plain.png"],
		"dialog_panel": ["shared/panel_parchment.png", "kit/panel_parchment_v2.png", "kit/bag_panel.png", "kit/tiers_panel.png", "kit/vault_panel.png"],
		"progress_track": ["kit/prog_track.png", "map/pill_progress.png"],
		"progress_fill": ["kit/prog_fill.png", "map/pill_progress_fill.png"],
		"board_frame": ["board/board_frame.png", "board/panel_grid.png"],
		"board_cell_open": ["board/slot_tile.png"],
		"board_cell_locked": ["board/slot_locked.png"],
		"board_cell_unlockable": ["board/slot_active.png"],
		"icon_padlock": ["board/locked_placeholder.png"],
		# Maps, banners, Rush, Vault, and Shop canonical consumers.
		"maps_card_open": ["map/left_card_frame_large.png"],
		"maps_card_locked": ["map/left_locked_preview.png"],
		"maps_status_pill": ["map/pill_left.png"], "maps_lock_flower": ["map/lock_flower.png"],
		"title_banner": ["mail/mail_banner.png", "rush/title_banner.png"],
		"icon_hourglass": ["rush/hourglass.png"], "icon_multiplier_crown": ["rush/bar_crown.png", "rush/mult_medallion.png"],
		"danger_chevron": ["rush/bottom_hint_3slice.png"],
		"vault_jar_shell": ["kit/vault_jar.png"], "vault_plate": ["kit/vault_plate.png"],
		"shop_product_card": ["kit/shop_card.png", "kit/shop_card_b.png", "kit/shop_card_wide.png"],
		"acorn_pouch": ["kit/shop_acorn.png"], "shop_promo_ribbon": ["kit/shop_tag.png"],
		"leaf_sprig": ["kit/shop_sprig.png"],
	}
	for source_name in routes:
		for canonical_rel in routes[source_name]:
			_assert_route(source_name, canonical_rel)

	ok(FileAccess.file_exists("res://games/grove/assets/ui/meadow_v2/canonical_mapping.json"),
		"deterministic one-to-many routing is documented beside the atlas manifest")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
