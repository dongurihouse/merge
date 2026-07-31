extends "res://engine/tests/test_base.gd"
## Guard: every committed baked mirror under assets/baked/ matches a FRESH bake of its source.
##   godot --headless --path . -s res://engine/tests/kit_bake_freshness_tests.gd
##
## Kit.clean_tex_path PREFERS the committed mirror over the live defringe/feather. So the mirror is
## not a cache the runtime can re-derive — it IS the shipped pixels. When a source texture changes,
## or its IMPORT changes (commit 9e4e23f9 moved every source to lossy WebP, which changes what
## load(src).get_image() decodes to), the mirror keeps shipping the old pixels and nothing complains:
## the tree is green, the art looks plausible, and the source + bake recipe no longer describe what
## the player sees. That drift is invisible by construction — this is what makes it visible.
##
## Discovery is the bake tool's own: Kit.clear_clean_cache() → BakeTargets.build_all(cfg) →
## Kit._clean_cache keys. Not a copy of its list, the SAME call, so the guard cannot cover a
## different asset set than `make bake-textures` writes. Add a dialog to bake_targets.gd and it is
## baked and guarded together.
##
## The freshness criterion is byte equality against Kit._clean_image(...).save_png_to_buffer() —
## deliberately the SAME comparison bake_textures.gd uses to decide whether to rewrite a file, so
## the tool and the guard can never disagree about what "current" means. EXISTENCE is checked too,
## which subsumes the deleted engine/tests/kit_bake_tests.gd ("a drawn sprite has no mirror at all",
## the cold-boot live-polish freeze): a missing mirror fails here as well as a stale one.

const Kit = preload("res://games/grove/ui_kit.gd")
const BakeTargets = preload("res://games/tools/bake_targets.gd")
const BAKED := "res://games/grove/assets/baked/"

## The bake covers 53 sprites today. A discovery that collapses (a build_all that throws, a cache
## key format change) would report a clean tree over nothing at all — floor it well under the real
## count but far above zero.
const MIN_SPRITES := 30
const MIN_SHADOWS := 7

func _initialize() -> void:
	print("== Baked-mirror freshness guard ==")
	var cfg := Kit.load_config(Kit.CONFIG_PATH)
	Kit.clear_clean_cache()
	Kit._live_shadow_log.clear()
	var nodes := BakeTargets.build_all(cfg)          # drives clean_tex_path → populates _clean_cache
	var keys: Array = Kit._clean_cache.keys()
	var shadow_specs: Array = BakeTargets.shadow_specs()

	# Anti-Potemkin: an empty dialog list or an empty key set makes every check below vacuous, and a
	# guard that discovers nothing passes loudest.
	ok(nodes.size() > 0, "BakeTargets.build_all() built the kit dialogs (%d)" % nodes.size())
	ok(keys.size() >= MIN_SPRITES, "discovered the bakeable sprite set (%d, floor %d)" % [keys.size(), MIN_SPRITES])
	ok(shadow_specs.size() >= MIN_SHADOWS,
		"discovered the finished Daily shadow set (%d, floor %d)" % [shadow_specs.size(), MIN_SHADOWS])

	var missing: Array = []      # no mirror committed at all — the cold-boot live-polish case
	var stale: Array = []        # mirror exists, bytes differ from a fresh bake
	var unreadable: Array = []   # source gone / not a Texture2D — the bake tool would FAIL on these too
	var compared := 0
	for k in keys:
		var at := String(k).rfind("@")
		var src := String(k).substr(0, at)
		var cap := int(String(k).substr(at + 1))
		var rel := Kit.baked_path(src, cap).replace(BAKED, "")
		var tex: Texture2D = null
		if ResourceLoader.exists(src):
			tex = load(src) as Texture2D
		if tex == null:
			unreadable.append(rel)
			continue
		var bytes := Kit._clean_image(tex.get_image(), cap).save_png_to_buffer()   # SAME polish the bake runs
		var out_abs := ProjectSettings.globalize_path(Kit.baked_path(src, cap))
		if not FileAccess.file_exists(out_abs):
			missing.append(rel)
			continue
		compared += 1
		if FileAccess.get_file_as_bytes(out_abs) != bytes:
			stale.append(rel)

	var shadow_missing: Array = []
	var shadow_stale: Array = []
	var shadow_unreadable: Array = []
	var shadow_compared := 0
	for raw_spec in shadow_specs:
		var spec: Dictionary = raw_spec
		var src := String(spec.path)
		var cap := int(spec.clean_cap)
		var opts := Dictionary(spec.opts)
		var rel := Kit.shadowed_baked_path(src, cap, opts).replace(BAKED, "")
		var tex := load(src) as Texture2D if ResourceLoader.exists(src) else null
		if tex == null:
			shadow_unreadable.append(rel)
			continue
		var base: Image = Kit._clean_image(tex.get_image(), cap) if cap > 0 else tex.get_image()
		var bytes := Kit.add_drop_shadow(base, opts).save_png_to_buffer()
		var out_abs := ProjectSettings.globalize_path(Kit.shadowed_baked_path(src, cap, opts))
		if not FileAccess.file_exists(out_abs):
			shadow_missing.append(rel)
			continue
		shadow_compared += 1
		if FileAccess.get_file_as_bytes(out_abs) != bytes:
			shadow_stale.append(rel)

	for n in nodes:
		if n is Node:
			(n as Node).queue_free()

	# Second known-positive: the byte comparison has to have actually RUN. If every mirror were
	# missing, `stale` would be empty for the wrong reason.
	ok(compared > 0, "read and re-baked the committed mirrors (%d compared)" % compared)
	ok(shadow_compared > 0, "read and re-baked the committed Daily shadows (%d compared)" % shadow_compared)

	if not missing.is_empty() or not stale.is_empty():
		print("  ----------------------------------------------------------------")
		if not missing.is_empty():
			print("  sprites the dialogs polish with NO committed mirror (%d):" % missing.size())
			for m in missing:
				print("    ", m)
		if not stale.is_empty():
			print("  committed mirrors whose bytes differ from a fresh bake (%d):" % stale.size())
			for s in stale:
				print("    ", s)
		print("  these are the SHIPPED pixels; the source says something else.")
		print("  remedy: `make bake-textures` then `make import`, and commit the changed PNGs.")
		print("  ----------------------------------------------------------------")
	if not unreadable.is_empty():
		print("  sources that no longer load as a Texture2D: ", ", ".join(unreadable))
	if not shadow_missing.is_empty() or not shadow_stale.is_empty():
		print("  Daily finished shadows missing/stale: ", ", ".join(shadow_missing + shadow_stale))
	if not shadow_unreadable.is_empty():
		print("  Daily shadow sources that no longer load: ", ", ".join(shadow_unreadable))

	ok(missing.is_empty(), "every bakeable sprite has a committed mirror (%d missing)" % missing.size())
	ok(stale.is_empty(), "every committed mirror matches a fresh bake (%d stale)" % stale.size())
	ok(unreadable.is_empty(), "every discovered source still loads (%d unreadable)" % unreadable.size())
	ok(shadow_missing.is_empty(), "every Daily shape shadow has a committed mirror (%d missing)" % shadow_missing.size())
	ok(shadow_stale.is_empty(), "every Daily shape shadow matches a fresh bake (%d stale)" % shadow_stale.size())
	ok(shadow_unreadable.is_empty(), "every Daily shadow source still loads (%d unreadable)" % shadow_unreadable.size())
	ok(Kit._live_shadow_log.is_empty(),
		"building the real dialog targets uses no live shape-shadow fallback (%s)" % str(Kit._live_shadow_log))
	finish()
