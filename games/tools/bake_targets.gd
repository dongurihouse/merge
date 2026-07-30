extends RefCounted
## Single source of truth for WHAT the texture bake covers: every kit dialog, built with its demo
## data + the real config opts (the same transforms the game uses). Building a dialog drives
## Kit.clean_tex_path for each sprite it draws, so Kit._clean_cache ends up holding the exact
## (path, max_dim) set those dialogs polish. Both the bake tool (games/tools/bake_textures.gd) and
## the guard test (engine/tests/kit_bake_freshness_tests.gd) call build_all() and read the cache keys,
## so they discover the SAME asset set with no hand-maintained manifest.
##
## Add a NEW top-level dialog here and it is automatically baked AND guarded — against the first-open
## freeze (no mirror) and against a mirror that has drifted from its source. Nothing else to update.

const Kit = preload("res://games/grove/ui_kit.gd")
const HomeChrome = preload("res://games/grove/home_chrome.gd")   # the canonical home-chrome icon set (shared with map.gd)
const LoginUI = preload("res://engine/scripts/ui/login.gd")      # the REAL runtime daily dialog (not the daily_card mock)
const LevelPopup = preload("res://engine/scripts/ui/level_popup.gd")  # the REAL runtime level dialog (not the kit level_dialog mock)
const Look = preload("res://engine/scripts/ui/skin.gd")

static func _level_data(mode: String) -> Dictionary:
	return {
		"level": 7, "earned": 130, "next": 160, "into": 10, "span": 40, "remaining": 30,
		"mode": mode, "gift": ({"water": 20, "gems": 3} if mode == "levelup" else {}),
		"on_button": Callable(),
	}

## Build every kit dialog (demo data + config opts). Returns the built nodes so the caller keeps them
## alive while it reads Kit._clean_cache. Side effect: the cache holds every sprite the dialogs polish.
## LEVEL is built in both modes — "levelup" adds the reward-chip art that "info" never shows.
static func build_all(cfg: Dictionary) -> Array:
	var out: Array = [
		Kit.daily_dialog(Kit.DEMO_DAILY, 460.0, Kit.daily_opts_from_config(cfg)),
		Kit.shop_dialog(Kit.demo_shop(), 520.0, Kit.shop_opts_from_config(cfg)),
		Kit.mail_dialog(Kit.DEMO_MAIL, 560.0, Kit.dialog_opts_from_config(cfg)),
		Kit.settings_dialog(Kit.DEMO_SETTINGS, 540.0, Kit.settings_opts_from_config(cfg)),
		Kit.vault_dialog(Kit.DEMO_VAULT, 460.0, Kit.vault_opts_from_config(cfg)),
		Kit.tiers_dialog(Kit.DEMO_TIERS, 620.0, Kit.tiers_opts_from_config(cfg)),
		Kit.level_dialog(_level_data("info"), 460.0, Kit.level_opts_from_config(cfg)),
		Kit.level_dialog(_level_data("levelup"), 460.0, Kit.level_opts_from_config(cfg)),
	]
	out.append_array(_chrome(cfg))
	# The REAL daily-login dialog (engine/scripts/ui/login.gd) draws a DIFFERENT sprite set than the
	# daily_card mock above — its reward + leaf sprites polish live on first open unless baked. It needs
	# a host + live state to build headless, so instead we drive clean_tex_path over the exact sprites it
	# declares (LoginUI.bake_sprites): that lands them in Kit._clean_cache the same way, so the bake writes
	# their mirrors and the guard test holds them baked. @256 matches _sprite's clean_tex_path cap.
	for rel in LoginUI.bake_sprites():
		Kit.clean_tex_path(Look.kit(String(rel)), 256)
	# The REAL level dialog (engine/scripts/ui/level_popup.gd) draws the v2 medallion art set —
	# same live-polish trap. LevelPopup.bake_sprites declares [rel, cap] pairs (caps differ per sprite).
	for spec in LevelPopup.bake_sprites():
		Kit.clean_tex_path(Look.kit(String(spec[0])), int(spec[1]))
	# The HUD's top-left star level badge (Look.make_star_level_badge) polishes its sprite on first draw
	# like the dialogs; bake it so the board/map open freeze-free (kit_bake_freshness_tests holds it baked). @256
	# matches the make_star_level_badge clean_tex_path cap.
	Kit.clean_tex_path(Look.kit(Look.STAR_BADGE_ART), 256)
	# The board/bag CELL FACES — every slot_cell draws one, so an un-baked set polishes live on the
	# first board open. Driving clean_tex_path over the declared paths lands them in _clean_cache the
	# same way the dialogs do, so the bake writes their mirrors and kit_bake_freshness_tests holds them baked.
	for cell_path in Kit.CELL_SPRITE_PATHS.values():
		Kit.clean_tex_path(String(cell_path), Kit.CELL_SPRITE_CAP)
	return out

## The home-screen CHROME — the bottom nav + the live-ops rail — is what cost ~480ms to build on a cold
## boot (each disc shell + icon polished live). They are all the SAME shared home button (Kit.home_button:
## the cream/gold disc shell + a polished icon), so building one per chrome icon id drives clean_tex_path
## for the disc AND every nav/rail icon → the bake covers them and the guard test holds them covered.
## The icon ids come from HomeChrome (the SAME constant map.gd's chrome builders read), so this list can't
## drift from what the home actually renders. The back button carries its arrow via icon_rel; the Play CTA
## (board/vine marks) + the calendar/chest rail icons all polish a sprite live on a cold boot unless baked.
static func _chrome(cfg: Dictionary) -> Array:
	var opts := Kit.home_button_opts_from_config(cfg)
	var out: Array = []
	# Every home-surface icon mark — bottom nav, live-ops rail, HUD affordances (HomeChrome.BAKE_ICONS).
	for icon_id in HomeChrome.BAKE_ICONS:
		out.append(Kit.home_button({"icon": icon_id, "caption": "", "action": Callable()}, opts))
	out.append(Kit.home_button({"icon": "", "icon_rel": HomeChrome.BACK_ICON_REL, "caption": "", "action": Callable()}, opts))
	# the RECT-badge shell (shared/badge_rect.png) — worn by the Settings gear (HUD) + the Map / side-rail
	# buttons. shell_texture still POLISHES that sprite (clean_tex_path @256); building one rect button bakes
	# badge_rect@256 so the gear + rail load it pre-baked instead of polishing it live on every cold boot.
	var ropts := Kit.home_button_opts_from_config(cfg)
	ropts["shape"] = "rect"
	out.append(Kit.home_button({"icon": HomeChrome.ICON_SETTINGS, "caption": "Settings", "action": Callable()}, ropts))
	return out
