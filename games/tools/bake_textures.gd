extends SceneTree
## Dev tool: PRE-BAKE the runtime texture polish (defringe + feather) that clean_tex_path() would
## otherwise run live on first use — the per-pixel GDScript pass that hitches a dialog open.
##
##   godot --headless --path . -s res://games/tools/bake_textures.gd
##   (or `make bake-textures`, which also runs the follow-up --import pass)
##
## AUTO-DISCOVERY (no manifest): builds every kit dialog via BakeTargets.build_all(), which drives
## clean_tex_path for each sprite the dialogs draw. Kit._clean_cache then holds the exact
## (path, max_dim) set to bake; for each we run the SAME Kit._clean_image() the runtime uses and write
## the result to the baked mirror (Kit.baked_path). The runtime loads that mirror directly instead of
## polishing. Add a new dialog to bake_targets.gd and it is covered automatically.
##
## Idempotent: always re-bakes FROM the (un-polished) source. Only writes (and prints) the sprites
## that are NEW or whose bytes CHANGED — re-runs over already-baked art are silent, so the output
## shows just what this run actually added.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const BakeTargets = preload("res://games/tools/bake_targets.gd")
const ASSETS := "res://games/grove/assets/"
const BAKED := "res://games/grove/assets/baked/"

func _initialize() -> void:
	var cfg := Kit.load_config(Kit.CONFIG_PATH)
	Kit.clear_clean_cache()
	var nodes := BakeTargets.build_all(cfg)        # drives clean_tex_path → populates _clean_cache
	var keys: Array = Kit._clean_cache.keys()

	var added := 0
	var changed := 0
	var unchanged := 0
	var failed := 0
	for k in keys:
		var at := String(k).rfind("@")
		var src := String(k).substr(0, at)
		var cap := int(String(k).substr(at + 1))
		if not ResourceLoader.exists(src):
			print("  SKIP    %s  (source missing)" % src.replace(ASSETS, "")); failed += 1; continue
		var tex := load(src) as Texture2D
		if tex == null:
			print("  SKIP    %s  (not a Texture2D)" % src.replace(ASSETS, "")); failed += 1; continue
		var clean: Image = Kit._clean_image(tex.get_image(), cap)   # SAME polish the runtime would do
		var bytes := clean.save_png_to_buffer()
		var out_abs := ProjectSettings.globalize_path(Kit.baked_path(src, cap))
		var rel := Kit.baked_path(src, cap).replace(BAKED, "")
		# new sprite, or its source changed? otherwise leave the committed file untouched.
		var status := ""
		if not FileAccess.file_exists(out_abs):
			status = "NEW"
		elif FileAccess.get_file_as_bytes(out_abs) != bytes:
			status = "CHANGED"
		if status == "":
			unchanged += 1
			continue
		DirAccess.make_dir_recursive_absolute(out_abs.get_base_dir())
		var f := FileAccess.open(out_abs, FileAccess.WRITE)
		if f == null:
			print("  FAIL    %s  (cannot write)" % rel); failed += 1; continue
		f.store_buffer(bytes); f.close()
		print("  %-7s %-44s (%dx%d)" % [status, rel, clean.get_width(), clean.get_height()])
		if status == "NEW": added += 1
		else: changed += 1

	for n in nodes:
		if n is Node:
			(n as Node).queue_free()

	if added == 0 and changed == 0 and failed == 0:
		print("== %d dialogs → %d sprites; all up to date (nothing to bake) ==" % [nodes.size(), keys.size()])
	else:
		print("== %d dialogs → %d sprites; %d new, %d changed, %d unchanged, %d failed ==" % [nodes.size(), keys.size(), added, changed, unchanged, failed])
		if added + changed > 0:
			print("   next: run `godot --headless --path . --import` so the new/changed PNGs get .import sidecars")
	quit(1 if failed > 0 else 0)
