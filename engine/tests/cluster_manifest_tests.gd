extends SceneTree
## Guard: every cover-up page's hand-typed MAPS cluster ids must match the GENERATED page manifest.
## The manifest (built from workbench region names by games/grove/tools/build_page_manifests.py) is
## the source of truth for cluster keys — map.gd keys its lock badges by the manifest's `cluster`,
## while content.next_locked_cluster walks MAPS. If the two sets drift, the page registers ZERO tap
## targets and progression walls there permanently (Desert Oasis shipped that way: MAPS said
## "adobe"/"caravan", the manifest said "adobe_compound"/"camel_caravan").
##   godot --headless --path . -s res://engine/tests/cluster_manifest_tests.gd

const Content = preload("res://engine/scripts/core/content.gd")
const HomePageView = preload("res://engine/scripts/ui/home_page_view.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# The distinct `cluster` keys the page manifest's coverups declare, loaded through the same
# loader the game uses (home_page_view.load_manifest) so the test exercises the real path.
func _manifest_clusters(path: String) -> Array:
	var manifest: Dictionary = HomePageView.load_manifest(path)
	var out: Array = []
	for cov_v in manifest.get("coverups", []):
		var cl := String((cov_v as Dictionary).get("cluster", ""))
		if cl != "" and not out.has(cl):
			out.append(cl)
	out.sort()
	return out

func _maps_clusters(z: int) -> Array:
	var out: Array = []
	for c in Content.clusters(z):
		var id := String((c as Dictionary).id)
		if not out.has(id):
			out.append(id)
	out.sort()
	return out

func _initialize() -> void:
	var pages := Content.coverup_pages()
	ok(pages.size() >= 1, "there is at least one cover-up page to check")

	for z_v in pages:
		var z := int(z_v)
		var name := String(Content.MAPS[z].get("name", "map %d" % z))
		var path := String(Content.MAPS[z].get("page_manifest", ""))
		ok(path != "", "%s declares a page_manifest" % name)
		ok(FileAccess.file_exists(path), "%s page manifest exists on disk (%s)" % [name, path])

		var from_manifest := _manifest_clusters(path)
		var from_maps := _maps_clusters(z)
		ok(not from_manifest.is_empty(), "%s manifest declares at least one coverup cluster" % name)
		ok(not from_maps.is_empty(), "%s MAPS declares at least one cluster" % name)

		# MAPS -> manifest: a MAPS id with no manifest art is an unreachable unlock step.
		for id in from_maps:
			ok(from_manifest.has(id),
				"%s MAPS cluster '%s' is covered by manifest art" % [name, id])
		# manifest -> MAPS: a manifest cluster absent from MAPS is dead art, never revealable.
		for id in from_manifest:
			ok(from_maps.has(id),
				"%s manifest cluster '%s' has a MAPS unlock step" % [name, id])

		if from_manifest != from_maps:
			print("    MAPS:     ", from_maps)
			print("    manifest: ", from_manifest)

	print("\n== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
