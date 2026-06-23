extends SceneTree
## Pre-bake the warped vine REGION-INDEX MAP for every authored vine map. _rebuild_region_map rasterizes a
## per-pixel noise-warped polygon test over the whole image (~1.1s for the 941×1672 farm) on the first home
## render — the boot spike. The raster is a pure function of (image_size, region polygons), so this writes it
## once to a committed PNG that VineMapView.load_map loads instead (see VineMapView._load_baked_region_map).
##
## Auto-discovered from VineMaps (no manifest) and idempotent like bake_textures.gd: re-renders from source,
## compares bytes, writes only NEW/CHANGED files, and prunes region_map_*.png whose content no longer maps to
## any current map (a geometry edit moves the content hash → the old file is dead). Headless:
##   godot --headless --path . -s res://games/tools/bake_vine_region_maps.gd

const VineMaps = preload("res://games/grove/vine/vine_maps.gd")
const VineMapView = preload("res://games/grove/vine/vine_map_view.gd")

func _initialize() -> void:
	print("== Vine region-map bake ==")
	var entries := VineMaps.entries()
	var added := 0
	var changed := 0
	var unchanged := 0
	var failed := 0
	var keep := {}        # globalized paths the live maps want — everything else in the dir is stale

	for entry in entries:
		var id := String(entry.get("id", "?"))
		var regions := VineMaps.regions_for(entry)
		if regions.is_empty():
			continue
		# image_size is the MASK's dimensions (load_map derives it the same way), so the bake and the runtime
		# agree on size + on the content-addressed path. Build the mask via a throwaway view, then discard it.
		var view := VineMapView.new()
		view._load_art(entry)
		var isize: Vector2i = view.image_size
		view.free()
		if isize.x <= 1 or isize.y <= 1:
			print("  SKIP    %-14s (no mask / image size)" % id); failed += 1; continue

		var image := VineMapView.render_region_map_image(isize, regions)
		var bytes := image.save_png_to_buffer()
		var out_path := VineMapView.baked_region_map_path(isize, regions)
		var out_abs := ProjectSettings.globalize_path(out_path)
		keep[out_abs] = true

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
			print("  FAIL    %-14s (cannot write %s)" % [id, out_path.get_file()]); failed += 1; continue
		f.store_buffer(bytes); f.close()
		print("  %-7s %-14s %s (%dx%d)" % [status, id, out_path.get_file(), image.get_width(), image.get_height()])
		if status == "NEW": added += 1
		else: changed += 1

	var pruned := _prune_stale(keep)

	if added == 0 and changed == 0 and failed == 0 and pruned == 0:
		print("== %d vine maps; all up to date (nothing to bake) ==" % entries.size())
	else:
		print("== %d vine maps; %d new, %d changed, %d unchanged, %d pruned, %d failed ==" % [entries.size(), added, changed, unchanged, pruned, failed])
		if added + changed > 0:
			print("   next: run `godot --headless --path . --import` so the new/changed PNGs get .import sidecars")
	quit(1 if failed > 0 else 0)

# Delete any region_map_*.png in the bake dir that no current map asked us to keep — the leftovers from a
# geometry edit that moved the content hash. Keeps the committed bake dir == exactly the live map set.
func _prune_stale(keep: Dictionary) -> int:
	var dir_abs := ProjectSettings.globalize_path(VineMapView.BAKED_REGION_DIR)
	if not DirAccess.dir_exists_absolute(dir_abs):
		return 0
	var pruned := 0
	for file in DirAccess.get_files_at(dir_abs):
		if not (file.begins_with("region_map_") and file.ends_with(".png")):
			continue
		var abs := dir_abs.path_join(file)
		if keep.has(abs):
			continue
		if DirAccess.remove_absolute(abs) == OK:
			DirAccess.remove_absolute(abs + ".import")   # drop the orphaned sidecar with its png
			print("  PRUNE   %s (no live map maps to it)" % file); pruned += 1
	return pruned
