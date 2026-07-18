extends SceneTree
## Headless tests for the home build-and-upgrade progression: the PURE module
## (home_build.gd — state + rules, no Save/scene deps) and the Save-backed adapter
## (home.gd). Spec: docs/superpowers/specs/2026-07-17-home-build-upgrade-map-design.md
##   godot --headless --path . -s res://engine/tests/home_build_tests.gd

const HB = preload("res://engine/scripts/core/home_build.gd")
const Home = preload("res://engine/scripts/core/home.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func fresh(name: String) -> void:
	var dir := "user://tu_home_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

## A fixture def, independent of the live grove BUILDINGS table: 3 steps, 1 skin.
func _def() -> Dictionary:
	return {"id": "hut",
		"steps": [
			{"cost": 10, "min_level": 1, "shows": "site"},
			{"cost": 20, "min_level": 2, "shows": "site"},
			{"cost": 30, "min_level": 3, "shows": "built"},
		],
		"customizations": [{"id": "red_roof", "cost": 40, "currency": "coins"}]}

func _initialize() -> void:
	print("== Home build tests ==")
	var d := _def()

	# --- the PURE module -----------------------------------------------------------
	var st := HB.make_state()
	ok(HB.steps_done(st, "hut") == 0 and not HB.is_built(st, d), "fresh state: 0 steps, not built")
	ok(HB.state_id(st, d) == "empty", "fresh state renders the empty plot")

	var ns := HB.next_step(st, d)
	ok(int(ns.index) == 0 and int(ns.cost) == 10 and int(ns.min_level) == 1, \
		"next_step reports the first step's price + gate")

	ok(HB.can_buy_step(st, d, 0, 999) == "level", "below min_level → refused as 'level'")
	ok(HB.can_buy_step(st, d, 1, 9) == "coins", "too poor → refused as 'coins'")
	ok(HB.can_buy_step(st, d, 1, 10) == "", "at level + affordable → allowed")

	ok(HB.buy_step(st, d) and HB.steps_done(st, "hut") == 1, "buy_step advances one step")
	ok(HB.state_id(st, d) == "site", "mid-build renders the paid step's state (site)")
	ok(HB.cells_granted(st, [d]) == 0, "no cells before the final step")

	HB.buy_step(st, d)
	HB.buy_step(st, d)
	ok(HB.is_built(st, d), "all steps paid → built")
	ok(HB.state_id(st, d) == "built", "built renders the built state")
	ok(HB.next_step(st, d).is_empty(), "next_step is empty once built")
	ok(HB.can_buy_step(st, d, 99, 99999) == "built", "buying past the end → refused as 'built'")
	ok(not HB.buy_step(st, d) and HB.steps_done(st, "hut") == 3, "buy_step refuses past the end")
	ok(HB.cells_granted(st, [d]) == 1, "completing a zone's only building completes the zone → ONE cell")
	ok(HB.cells_granted(st, [d]) == 1, "cells_granted is a pure re-read — never double-grants")

	# per-ZONE capacity (decision 2026-07-17): a zone pays its single cell only when EVERY building
	# in it is built; each further zone is worth exactly one more cell.
	var shed := {"id": "shed", "steps": [{"cost": 5, "min_level": 1, "shows": "built"}], "customizations": []}
	ok(HB.cells_granted(st, [d, shed]) == 0, "an unbuilt sibling keeps the whole zone unpaid")
	HB.buy_step(st, shed)
	ok(HB.cells_granted(st, [d, shed]) == 1, "the zone completes with its LAST building — still one cell")
	var barn := {"id": "barn", "zone": "meadow", "steps": [{"cost": 5, "min_level": 1, "shows": "built"}], "customizations": []}
	ok(HB.cells_granted(st, [d, shed, barn]) == 1, "a second zone grants nothing while unbuilt")
	HB.buy_step(st, barn)
	ok(HB.cells_granted(st, [d, shed, barn]) == 2, "each completed zone unlocks exactly one cell")

	# customization: only on a BUILT building, and it becomes the rendered state
	var st2 := HB.make_state()
	ok(not HB.set_custom(st2, d, "red_roof"), "customization refused before built")
	ok(not HB.set_custom(st, d, "no_such_skin"), "unknown variant refused")
	ok(HB.set_custom(st, d, "red_roof"), "customization applies on a built building")
	ok(HB.state_id(st, d) == "red_roof", "customized building renders its variant")

	# --- the Save-backed adapter (live BUILDINGS table) -----------------------------
	fresh("adapter")
	var first: Dictionary = Home.defs()[0]
	var fid := String(first.id)
	ok(Home.defs().size() >= 7, "live BUILDINGS table carries the 7 farmhouse buildings")
	ok(Home.state_id(fid) == "empty", "fresh save: first building is an empty plot")

	var step: Dictionary = Home.next_step(fid)
	var out: Dictionary = Home.buy_step(fid)
	ok(not bool(out.ok) and String(out.reason) == "coins", "broke fresh save: buy refused for coins")

	Save.earn_coins(100000)                       # organic riches: level + wallet both high
	out = Home.buy_step(fid)
	ok(bool(out.ok), "funded + leveled: the first step buys")
	ok(Save.coins() == 100000 - int(step.cost), "the step's coin price was spent")
	ok(Home.state_id(fid) == String(step.shows), "the map now shows the paid step's state")

	while not bool(Home.buy_step(fid).get("built", false)):   # buy to completion
		pass
	ok(Home.cells_total() == 0, "one built building does not complete the zone — no cell yet")

	for d2 in Home.defs():                        # finish the whole farmhouse zone
		while not Home.next_step(String(d2.id)).is_empty():
			if not bool(Home.buy_step(String(d2.id)).ok):
				break                             # failsafe: a refused buy must not hang the suite
	ok(Home.cells_total() == 1, "completing every building of the zone unlocks its ONE cell")

	Save._loaded = false                          # adapter state survives a reload
	ok(Home.state_id(fid) != "empty" and Home.cells_total() == 1, \
		"home state round-trips through the save file")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
