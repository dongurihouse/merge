extends SceneTree
## Headless tests for the pre-baked texture polish — Kit.baked_path() key derivation, the bake
## manifest ⇄ baked-file consistency, and that Kit.clean_tex_path() loads a baked sprite directly
## (skipping the live defringe/feather) while still falling back to the live polish for un-baked art.
##   godot --headless -s res://engine/tests/kit_bake_tests.gd

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const MANIFEST := "res://games/tools/bake_textures.json"

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _read_manifest() -> Array:
	var f := FileAccess.open(MANIFEST, FileAccess.READ)
	if f == null:
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Array else []

func _initialize() -> void:
	print("== Kit texture-bake tests ==")
	Kit.clear_clean_cache()

	# 1. baked_path maps a source under the game's assets root to baked/<subpath>@<max>.png
	ok(Kit.baked_path(Look.kit("kit/level_wreath.png"), 512) == Game.art("baked/ui/kit/level_wreath@512.png"),
		"baked_path mirrors the subpath and tags the max_dim")
	# 2. the SAME source at a different cap is a DIFFERENT baked file (the cap is part of the key)
	ok(Kit.baked_path(Look.kit("kit/level_wreath.png"), 256) == Game.art("baked/ui/kit/level_wreath@256.png"),
		"baked_path key includes max_dim (same source, two caps = two files)")
	# 3. a path outside the assets root flattens to just the filename (no crash)
	ok(Kit.baked_path("res://elsewhere/foo.png", 128) == Game.art("baked/foo@128.png"),
		"baked_path flattens a non-assets source to its filename")

	# 4. every manifest entry has its baked file committed (catches "added to manifest, forgot to bake")
	var manifest := _read_manifest()
	ok(not manifest.is_empty(), "bake manifest parses and is non-empty")
	var all_present := true
	for e in manifest:
		var bp: String = Kit.baked_path(String(e["path"]), int(e["max"]))
		if not ResourceLoader.exists(bp):
			all_present = false
			print("        MISSING baked file: ", bp, "  (for ", e["path"], ")")
	ok(all_present, "every manifest entry has a baked file present")

	# 5. clean_tex_path on a BAKED asset loads the baked resource (non-empty resource_path) — the
	#    live defringe/feather is skipped. A live-polished ImageTexture has an EMPTY resource_path.
	Kit.clear_clean_cache()
	var baked_src: String = Look.kit("kit/level_wreath.png")
	var baked_tex := Kit.clean_tex_path(baked_src, 512)
	ok(baked_tex != null and baked_tex.resource_path != "",
		"clean_tex_path returns the baked resource for a baked asset")

	# 6. an UN-baked asset still works via the live-polish fallback (in-memory ImageTexture, no path)
	Kit.clear_clean_cache()
	var live_src: String = Look.kit("kit/mail_pill_cream.png")   # not in the manifest
	ok(not ResourceLoader.exists(Kit.baked_path(live_src, 256)), "fallback asset is genuinely un-baked")
	var live_tex := Kit.clean_tex_path(live_src, 256)
	ok(live_tex != null and live_tex.resource_path == "",
		"clean_tex_path falls back to live polish for an un-baked asset")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
