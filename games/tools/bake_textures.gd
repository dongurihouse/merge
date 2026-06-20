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
## Idempotent: always re-bakes FROM the (un-polished) source, so re-running just overwrites.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const BakeTargets = preload("res://games/tools/bake_targets.gd")

func _initialize() -> void:
	var cfg := Kit.load_config(Kit.CONFIG_PATH)
	Kit.clear_clean_cache()
	var nodes := BakeTargets.build_all(cfg)        # drives clean_tex_path → populates _clean_cache
	var keys: Array = Kit._clean_cache.keys()

	var ok := 0
	var failed := 0
	for k in keys:
		var at := String(k).rfind("@")
		var src := String(k).substr(0, at)
		var cap := int(String(k).substr(at + 1))
		if not ResourceLoader.exists(src):
			print("  SKIP  %s  (source missing)" % src); failed += 1; continue
		var tex := load(src) as Texture2D
		if tex == null:
			print("  SKIP  %s  (not a Texture2D)" % src); failed += 1; continue
		var clean: Image = Kit._clean_image(tex.get_image(), cap)   # SAME polish the runtime would do
		var out_res := Kit.baked_path(src, cap)
		var out_abs := ProjectSettings.globalize_path(out_res)
		DirAccess.make_dir_recursive_absolute(out_abs.get_base_dir())
		var err := clean.save_png(out_abs)
		if err != OK:
			print("  FAIL  %s  (save_png err %d)" % [out_res, err]); failed += 1; continue
		print("  BAKE  %-44s @%-4d -> %s" % [src.replace("res://games/grove/assets/", ""), cap, out_res.replace("res://games/grove/assets/baked/", "")])
		ok += 1

	for n in nodes:
		if n is Node:
			(n as Node).queue_free()

	print("== %d dialogs → %d sprites discovered; baked %d, failed %d ==" % [nodes.size(), keys.size(), ok, failed])
	print("   next: run `godot --headless --path . --import` so the baked PNGs get .import sidecars")
	quit(1 if failed > 0 else 0)
