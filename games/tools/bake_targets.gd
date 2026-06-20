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
## Icon ids mirror map.gd._build_chrome / _build_liveops_rail; the back button carries its arrow via
## icon_rel. (The centre Play leaf is loaded raw — no polish — so it needs no bake.)
static func _chrome(cfg: Dictionary) -> Array:
	var opts := Kit.home_button_opts_from_config(cfg)
	var out: Array = []
	for icon_id in ["gear", "shop", "map", "piggy", "gift", "faucet", "mail"]:
		out.append(Kit.home_button({"icon": icon_id, "caption": "", "action": Callable()}, opts))
	out.append(Kit.home_button({"icon": "", "icon_rel": "map/back_arrow.png", "caption": "", "action": Callable()}, opts))
	return out
