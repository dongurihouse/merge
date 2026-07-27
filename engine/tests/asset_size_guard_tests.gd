extends "res://engine/tests/test_base.gd"
## Build-size guard: no shipped texture is stored LOSSLESS.
##
## The single biggest lever on this app's download size is texture compression: the game
## once shipped 522 textures at compress/mode=0 (Lossless) for 151.6 MB, and moving them to
## lossy WebP (mode 1) cut the pack from 176.7 MB to 60.5 MB. project.godot's
## [importer_defaults] now makes new textures lossy automatically, but a default is only a
## default — someone can override one .import, or the default block can be removed. This
## test is the mechanism that makes the win stick: it fails the build if any texture that
## actually SHIPS is stored lossless.
##
## "Ships" is defined the same way the exporter defines it (tools/export_asset_pack.sh):
## ANY texture under res:// that is NOT inside a .gdignore subtree and NOT dropped by the
## iOS preset's exclude_filter. Both selectors must agree, so this reads the real
## exclude_filter out of export_presets.cfg rather than hardcoding it.
##
## The walk is repo-wide ON PURPOSE. It used to start at games/grove/assets, which made the
## headline claim above false: textures that ship from outside that directory were invisible
## to it, so the empty LOSSLESS_ALLOWLIST asserted nothing about them. res://icon_small.png
## (project.godot's config/icon) was exactly that blind spot — exclude_filter drops the
## literal `icon.png` but not `icon_small.png`, so it shipped at compress/mode=0 and this
## guard could not see it. Do NOT re-narrow ROOT to make a finding go away; allowlist the
## texture with a reason, or compress it.

const ROOT := "res://"
const PRESETS := "res://export_presets.cfg"

# Set false to land a new offender as a WARNING instead of a failure (prints the list, suite
# still passes). Must stay true: this guard is the only thing standing between a stray
# compress/mode=0 and a re-inflated download.
const FAIL_ON_LOSSLESS := true

# Textures that legitimately must stay lossless (data masks, normal maps, hard-edged pixel
# art). Add the res:// path of the SOURCE image here, with a reason, when you pin one to
# compress/mode=0. Empty today — every shipped texture is compressed.
const LOSSLESS_ALLOWLIST := {
	# "res://games/grove/assets/…/some_mask.png": "alpha mask read as data, artifacts bleed",
}

## Every exclude_filter entry that keeps a path out of the shipped build: directory prefixes
## (`build/**` → `build`) AND bare file entries (`icon.png`), which a repo-wide walk must
## honour — the narrow walk never reached the root so it could drop them. Mirrors the parse
## in tools/export_asset_pack.sh, INCLUDING its one special case: the main preset excludes
## `games/grove/assets/**` so its own pack stays code-only, but those files still ship — in
## the SEPARATE grove_assets.pck. That entry is a split artifact, not a "never ship" rule,
## so it must be ignored here or this guard would check nothing.
func _excluded_prefixes() -> Array:
	var out: Array = []
	var f := FileAccess.open(PRESETS, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if not line.begins_with("exclude_filter="):
			continue
		var raw := line.substr("exclude_filter=".length()).trim_prefix("\"").trim_suffix("\"")
		for pat in raw.split(","):
			pat = pat.strip_edges()
			if pat.is_empty() or pat == "games/grove/assets/**":
				continue                       # split artifact — these ship in grove_assets.pck
			if pat.ends_with("/**"):
				out.append(pat.substr(0, pat.length() - 3))
			else:
				out.append(pat)                # bare file (icon.png) or a glob (map/*/reference)
		break                                  # the first (iOS) preset's filter is the shipping one
	return out

func _is_excluded(rel: String, prefixes: Array) -> bool:
	for p in prefixes:
		if "*" in p:                           # the one glob form in use: map/*/reference
			continue
		if rel == p or rel.begins_with(p + "/"):
			return true
	return "/reference/" in rel or rel.ends_with("/reference")

## Every shipped texture's .import path, skipping .gdignore subtrees. Uses path_join, not
## string concatenation, so the repo root ("res://") does not become "res:///name".
func _shipped_textures(dir: String, prefixes: Array, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	if d.file_exists(dir.path_join(".gdignore")):
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var path := dir.path_join(name)
		var rel := path.replace("res://", "")
		if d.current_is_dir():
			if not name.begins_with(".") and not _is_excluded(rel, prefixes):
				_shipped_textures(path, prefixes, out)
		elif name.ends_with(".png.import") and not _is_excluded(rel.trim_suffix(".import"), prefixes):
			out.append(path)
		name = d.get_next()
	d.list_dir_end()

func _mode_of(import_path: String) -> int:
	var f := FileAccess.open(import_path, FileAccess.READ)
	if f == null:
		return -1
	var is_texture := false
	var mode := -1
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == 'type="CompressedTexture2D"':
			is_texture = true
		elif line.begins_with("compress/mode="):
			mode = int(line.substr("compress/mode=".length()))
	return mode if is_texture else -1

func _initialize() -> void:
	print("== asset_size_guard ==")
	var prefixes := _excluded_prefixes()
	ok(not prefixes.is_empty(), "read exclude_filter prefixes from export_presets.cfg (%d)" % prefixes.size())
	# the bare-file entries are what a repo-wide walk needs and the /**-only parse dropped;
	# if this regresses, root-level textures get scanned that the export actually drops.
	ok(prefixes.has("icon.png"), "exclude_filter parse keeps bare file entries (icon.png)")

	var imports: Array = []
	_shipped_textures(ROOT, prefixes, imports)
	var outside := 0
	for imp in imports:
		if not (imp as String).begins_with("res://games/grove/assets/"):
			outside += 1
	ok(imports.size() > 100, "found the shipped texture set (%d imports)" % imports.size())
	# the walk must reach past games/grove/assets — a zero here means someone re-narrowed
	# ROOT and the guard is back to asserting nothing about root-level shipped textures.
	ok(outside > 0, "walk is repo-wide, not assets-only (%d shipped imports outside games/grove/assets)" % outside)

	var lossless: Array = []
	for imp in imports:
		if _mode_of(imp) == 0:                 # 0 == Lossless; 1 == lossy WebP; 2 == VRAM
			var src: String = imp.trim_suffix(".import")
			if not LOSSLESS_ALLOWLIST.has(src):
				lossless.append(src.replace("res://", ""))
	var detail := "" if lossless.is_empty() else " — %d found (set compress/mode=1 or allowlist): %s" \
		% [lossless.size(), str(lossless.slice(0, 15))]
	if not FAIL_ON_LOSSLESS and not lossless.is_empty():
		print("  WARN  lossless shipped textures (FAIL_ON_LOSSLESS is off)%s" % detail)
	else:
		ok(lossless.is_empty(), "no shipped texture is lossless%s" % detail)

	finish()
