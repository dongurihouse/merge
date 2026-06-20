extends SceneTree
## Headless tests for the pre-baked texture polish. clean_tex_path()'s defringe/feather runs live on
## first use — the per-pixel pass that froze the level/daily/shop dialogs on first open. `make
## bake-textures` AUTO-DISCOVERS what to bake by building every kit dialog (BakeTargets.build_all) and
## reading the sprites they polish out of Kit._clean_cache — no hand-maintained manifest.
##
## The load-bearing test here is the GUARD: build every dialog and assert each sprite it polishes is
## baked. If a new dialog (or a changed one) polishes an un-baked sprite, this FAILS loudly instead of
## shipping a silent first-open freeze — telling you to run `make bake-textures`.
##   godot --headless -s res://engine/tests/kit_bake_tests.gd

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const BakeTargets = preload("res://games/tools/bake_targets.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Game = preload("res://engine/scripts/core/game.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _split(key: String) -> Array:
	var at := key.rfind("@")
	return [key.substr(0, at), int(key.substr(at + 1))]

func _initialize() -> void:
	print("== Kit texture-bake tests ==")

	# 1-3. baked_path() key derivation: mirror the subpath under the assets root, tag the cap.
	ok(Kit.baked_path(Look.kit("kit/level_wreath.png"), 512) == Game.art("baked/ui/kit/level_wreath@512.png"),
		"baked_path mirrors the subpath and tags the max_dim")
	ok(Kit.baked_path(Look.kit("kit/level_wreath.png"), 256) == Game.art("baked/ui/kit/level_wreath@256.png"),
		"baked_path key includes max_dim (same source, two caps = two files)")
	ok(Kit.baked_path("res://elsewhere/foo.png", 128) == Game.art("baked/foo@128.png"),
		"baked_path flattens a non-assets source to its filename")

	# 4. THE GUARD: every sprite any kit dialog polishes on open is pre-baked. A new/changed dialog
	#    that polishes an un-baked sprite fails here (run `make bake-textures`) — never a silent freeze.
	Kit.clear_clean_cache()
	var nodes := BakeTargets.build_all(Kit.load_config(Kit.CONFIG_PATH))
	var keys: Array = Kit._clean_cache.keys()
	ok(keys.size() >= 10, "dialogs polish a non-trivial sprite set (%d discovered)" % keys.size())
	var missing: Array = []
	for k in keys:
		var pm := _split(String(k))
		if not ResourceLoader.exists(Kit.baked_path(String(pm[0]), int(pm[1]))):
			missing.append("%s @%d" % [String(pm[0]).replace("res://games/grove/assets/", ""), int(pm[1])])
	if not missing.is_empty():
		print("        UN-BAKED (run `make bake-textures`): ", ", ".join(missing))
	ok(missing.is_empty(), "every sprite the dialogs polish is baked (%d un-baked)" % missing.size())

	# 4b. CHROME coverage: the bottom-nav + live-ops discs/icons (the cold-boot _build_chrome cost) are
	#     driven by build_all too, so the disc shell AND every nav/rail icon land in the bake set.
	var srcs: Array = []
	for k in keys:
		srcs.append(_split(String(k))[0])
	ok(srcs.has(Look.kit("shared/disc_round.png")), "the home-button disc shell is in the bake set")
	ok(srcs.has(Game.art("ui/shared/icon_gear.png")), "a nav icon (gear) is in the bake set")
	ok(srcs.has(Game.art("ui/shared/icon_mail.png")), "a rail icon (mail) is in the bake set")
	for n in nodes:
		if n is Node:
			(n as Node).queue_free()

	# 5. clean_tex_path loads the baked resource for a baked dialog sprite (non-empty resource_path —
	#    the live ImageTexture path leaves resource_path empty).
	Kit.clear_clean_cache()
	var baked_tex := Kit.clean_tex_path(Look.kit("kit/daily_card.png"), 256)
	ok(baked_tex != null and baked_tex.resource_path != "",
		"clean_tex_path returns the baked resource for a baked dialog sprite")

	# 6. an un-baked (path, max_dim) still works via the live-polish fallback. @999 is a cap no dialog
	#    requests, so it is never baked — exercises the fallback without depending on an unused asset.
	Kit.clear_clean_cache()
	var live_src: String = Look.kit("kit/daily_card.png")
	ok(not ResourceLoader.exists(Kit.baked_path(live_src, 999)), "the @999 variant is genuinely un-baked")
	var live_tex := Kit.clean_tex_path(live_src, 999)
	ok(live_tex != null and live_tex.resource_path == "",
		"clean_tex_path falls back to live polish for an un-baked (path, max_dim)")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
