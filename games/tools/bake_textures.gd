extends SceneTree
## Dev tool: PRE-BAKE the runtime texture polish (defringe + feather) that clean_tex_path() would
## otherwise run live on first use — the per-pixel GDScript pass that hitches a dialog open.
##
##   godot --headless --path . -s res://games/tools/bake_textures.gd
##   (or `make bake-textures`, which also runs the follow-up --import pass)
##
## Reads games/tools/bake_textures.json — a list of { "path": "res://…png", "max": <cap> } — and for
## each entry runs the SAME Kit._clean_image() the runtime uses, writing the result to the baked
## mirror (Kit.baked_path). The runtime then loads that mirror directly instead of polishing.
##
## Idempotent: always re-bakes FROM the (un-polished) source, so re-running just overwrites. To add a
## sprite, add a line to the manifest with the cap used at its clean_tex_path() call site, then re-run.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const MANIFEST := "res://games/tools/bake_textures.json"

func _initialize() -> void:
	var f := FileAccess.open(MANIFEST, FileAccess.READ)
	if f == null:
		push_error("bake_textures: cannot open manifest %s" % MANIFEST)
		quit(1); return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Array):
		push_error("bake_textures: manifest is not a JSON array")
		quit(1); return

	var ok := 0
	var failed := 0
	for entry in parsed:
		var src := String((entry as Dictionary).get("path", ""))
		var cap := int((entry as Dictionary).get("max", 256))
		if not ResourceLoader.exists(src):
			print("  SKIP  %s  (source missing)" % src)
			failed += 1
			continue
		var tex := load(src) as Texture2D
		if tex == null:
			print("  SKIP  %s  (not a Texture2D)" % src)
			failed += 1
			continue
		var clean: Image = Kit._clean_image(tex.get_image(), cap)
		var out_res := Kit.baked_path(src, cap)
		var out_abs := ProjectSettings.globalize_path(out_res)
		DirAccess.make_dir_recursive_absolute(out_abs.get_base_dir())
		var err := clean.save_png(out_abs)
		if err != OK:
			print("  FAIL  %s  (save_png err %d)" % [out_res, err])
			failed += 1
			continue
		print("  BAKE  %-46s -> %s  (%dx%d)" % [src.get_file(), out_res.replace("res://", ""), clean.get_width(), clean.get_height()])
		ok += 1

	print("== baked %d, failed %d ==" % [ok, failed])
	print("   next: run `godot --headless --path . --import` so the baked PNGs get .import sidecars")
	quit(1 if failed > 0 else 0)
