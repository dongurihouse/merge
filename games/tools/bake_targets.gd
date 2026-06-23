extends RefCounted
## Single source of truth for WHAT the texture bake covers: every kit dialog, built with its demo
## data + the real config opts (the same transforms the game uses). Building a dialog drives
## Kit.clean_tex_path for each sprite it draws, so Kit._clean_cache ends up holding the exact
## (path, max_dim) set those dialogs polish. Both the bake tool (games/tools/bake_textures.gd) and
## the guard test (engine/tests/kit_bake_tests.gd) call build_all() and read the cache keys, so they
## discover the SAME asset set with no hand-maintained manifest.
##
## Add a NEW top-level dialog here and it is automatically baked AND guarded against the first-open
## freeze — nothing else to update.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const HomeChrome = preload("res://games/grove/home_chrome.gd")   # the canonical home-chrome icon set (shared with map.gd)

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
	return out

## The home-screen CHROME — the bottom nav + the live-ops rail — is what cost ~480ms to build on a cold
## boot (each disc shell + icon polished live). They are all the SAME shared home button (Kit.home_button:
## the cream/gold disc shell + a polished icon), so building one per chrome icon id drives clean_tex_path
## for the disc AND every nav/rail icon → the bake covers them and the guard test holds them covered.
## The icon ids come from HomeChrome (the SAME constant map.gd's chrome builders read), so this list can't
## drift from what the home actually renders. The back button carries its arrow via icon_rel; the Play CTA
## (board/vine on the orange play_disc) + the calendar/chest rail icons all polish a sprite live on a cold
## boot unless baked. (grove_vine_tests._test_boot_does_zero_live_work backstops any remaining drift.)
static func _chrome(cfg: Dictionary) -> Array:
	var opts := Kit.home_button_opts_from_config(cfg)
	var out: Array = []
	# Every home-surface icon mark — bottom nav, live-ops rail, HUD affordances (HomeChrome.BAKE_ICONS).
	for icon_id in HomeChrome.BAKE_ICONS:
		out.append(Kit.home_button({"icon": icon_id, "caption": "", "action": Callable()}, opts))
	out.append(Kit.home_button({"icon": "", "icon_rel": HomeChrome.BACK_ICON_REL, "caption": "", "action": Callable()}, opts))
	# the orange Play disc (HomeChrome.PLAY_SHELL) — the CAPTIONLESS centre CTA's shell. It is NOT the default
	# cream disc, so building a disc button with this shell override bakes play_disc@256; otherwise the home
	# polishes it live (clean_tex_path @256) on every cold boot, the spike _build_chrome paid.
	var popts := Kit.home_button_opts_from_config(cfg)
	popts["shell"] = HomeChrome.PLAY_SHELL
	out.append(Kit.home_button({"icon": HomeChrome.ICON_PLAY, "caption": "", "action": Callable()}, popts))
	# the RECT-badge shell (shared/badge_rect.png) — worn by the Settings gear (HUD) + the Map / side-rail
	# buttons. shell_texture still POLISHES that sprite (clean_tex_path @256); building one rect button bakes
	# badge_rect@256 so the gear + rail load it pre-baked instead of polishing it live on every cold boot.
	var ropts := Kit.home_button_opts_from_config(cfg)
	ropts["shape"] = "rect"
	out.append(Kit.home_button({"icon": HomeChrome.ICON_SETTINGS, "caption": "Settings", "action": Callable()}, ropts))
	return out
