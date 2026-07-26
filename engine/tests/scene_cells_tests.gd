extends SceneTree
## content.gd cell-source queries: habitat cells derive from COMPLETED cover-up scenes
## (one per fully-unlocked scene), and the board CTA reads whether the next cluster is
## unlockable now. Pure queries over the real grove MAPS — no scene instantiation.

const Content = preload("res://engine/scripts/core/content.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# Unlock every cluster of cover-up page `z` in the shared `unlocks` dict.
func _unlock_scene(unlocks: Dictionary, z: int) -> void:
	for c in Content.clusters(z):
		unlocks[String((c as Dictionary).id)] = true

func _test_cells_from_scenes() -> void:
	var pages := Content.coverup_pages()
	ok(pages.size() >= 1, "there is at least one cover-up scene")

	ok(Content.cells_from_scenes({}) == 0, "no cells when nothing is unlocked")

	# A scene with any locked cluster grants nothing — unlock all but the last cluster of scene 0.
	var partial: Dictionary = {}
	var z0 := int(pages[0])
	var cls0: Array = Content.clusters(z0)
	for i in cls0.size() - 1:
		partial[String((cls0[i] as Dictionary).id)] = true
	ok(Content.cells_from_scenes(partial) == 0, "a partially-unlocked scene grants 0 cells")

	# Completing scene 0 grants exactly one cell.
	var one: Dictionary = {}
	_unlock_scene(one, z0)
	ok(Content.cells_from_scenes(one) == 1, "completing the first scene grants 1 cell")

	# Completing the first two scenes grants two.
	if pages.size() >= 2:
		var two: Dictionary = {}
		_unlock_scene(two, int(pages[0]))
		_unlock_scene(two, int(pages[1]))
		ok(Content.cells_from_scenes(two) == 2, "completing two scenes grants 2 cells")

	# Completing every scene grants one per scene, capped at the scene count.
	var all: Dictionary = {}
	for z in pages:
		_unlock_scene(all, int(z))
	ok(Content.cells_from_scenes(all) == pages.size(), "completing every scene grants one cell each")

func _test_any_cluster_ready() -> void:
	var pages := Content.coverup_pages()
	var z0 := int(pages[0])
	var cl0 := Content.next_locked_cluster(z0, {})
	ok(cl0 != "", "the first scene has a next locked cluster from a fresh start")
	var cost0 := Content.cluster_cost(z0, cl0)
	var lvl0 := Content.cluster_min_level(z0, cl0)

	ok(Content.any_cluster_ready({}, lvl0, cost0), "next cluster ready when level + coins meet its gate")
	ok(not Content.any_cluster_ready({}, lvl0 - 1, cost0), "not ready below the level floor")
	ok(not Content.any_cluster_ready({}, lvl0, cost0 - 1), "not ready when coins fall short")

	# Once every cluster is unlocked, nothing is ready to unlock.
	var all: Dictionary = {}
	for z in pages:
		for c in Content.clusters(int(z)):
			all[String((c as Dictionary).id)] = true
	ok(not Content.any_cluster_ready(all, 999, 9999999), "nothing ready once the book is fully unlocked")

# The cluster level floors are DERIVED from the cost ladder: a cluster's floor is the level a
# player stands at once they have EARNED what the ladder has cost up to and including it. No
# hand-authored level table, so the floors can never drift off the costs.
func _test_derived_cluster_floors() -> void:
	var pages := Content.coverup_pages()
	ok(pages.size() == 5, "the book has 5 cover-up scenes")

	# cumulative cost walks the clusters in GLOBAL order
	ok(Content.cumulative_cluster_cost(0) == 10, "cumulative cost at cluster 0 is the first cluster's cost")
	ok(Content.cumulative_cluster_cost(5) == 420, "cumulative cost through Fairy Hollow is 420")
	ok(Content.cumulative_cluster_cost(24) == 46740, "the whole ladder costs 46740 coins")
	ok(Content.cumulative_cluster_cost(999) == 46740, "an out-of-range index clamps to the whole ladder")

	# every floor equals level_at_coins of its own cumulative cost
	var i := 0
	var derived_ok := true
	var floors: Array = []
	for z in pages:
		for c in Content.clusters(int(z)):
			var id := String((c as Dictionary).id)
			var want := Content.level_at_coins(Content.cumulative_cluster_cost(i))
			if Content.cluster_min_level(int(z), id) != want:
				derived_ok = false
			floors.append(Content.cluster_min_level(int(z), id))
			i += 1
	ok(i == 25, "the ladder has 25 clusters")
	ok(derived_ok, "every cluster floor == level_at_coins(its cumulative cost)")
	ok(floors == [1, 2, 3, 4, 5, 7, 9, 11, 14, 16, 19, 22, 25, 29, 33, 37, 41, 46, 51, 56, 61, 67, 73, 80, 87],
		"the derived floor ladder at the shipped curve (got %s)" % str(floors))

	# non-decreasing: a later cluster is never cheaper in level terms than an earlier one
	var mono := true
	for j in range(1, floors.size()):
		if int(floors[j]) < int(floors[j - 1]):
			mono = false
	ok(mono, "the floor ladder is non-decreasing")

	# scene windows close at each scene's completion level
	ok(Content.scene_level_window(0) == Vector2i(1, 7), "Fairy Hollow spans L1-7")
	ok(Content.scene_level_window(1) == Vector2i(8, 19), "Snowy Village spans L8-19")
	ok(Content.scene_level_window(2) == Vector2i(20, 37), "Desert Oasis spans L20-37")
	ok(Content.scene_level_window(3) == Vector2i(38, 61), "Coral Reef spans L38-61")
	ok(Content.scene_level_window(4) == Vector2i(62, 87), "Cherry Blossom spans L62-87")

func _initialize() -> void:
	print("== scene-derived habitat cells (content queries) ==")
	_test_cells_from_scenes()
	_test_any_cluster_ready()
	_test_derived_cluster_floors()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
