extends "res://engine/tests/test_base.gd"
## content.gd cell-source queries: habitat cells derive from COMPLETED cover-up scenes
## (one per fully-unlocked scene), and the board CTA reads whether the next cluster is
## unlockable now. Pure queries over the real grove MAPS — no scene instantiation.

const Content = preload("res://engine/scripts/core/content.gd")

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

func _initialize() -> void:
	print("== scene-derived habitat cells (content queries) ==")
	_test_cells_from_scenes()
	_test_any_cluster_ready()
	finish()
