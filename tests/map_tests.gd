extends SceneTree
## Headless tests for the Districts→Clients→Jobs spine.
##   godot --headless --path . -s res://tests/map_tests.gd

const Save = preload("res://scripts/save.gd")
const Levels = preload("res://scripts/levels.gd")
const Districts = preload("res://scripts/districts.gd")

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
	var dir := "user://tu_test_map_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func clear_district(d: int, leave_last := false) -> void:
	var jobs: Array = Districts.DISTRICTS[d].jobs
	var upto := jobs.size() - (1 if leave_last else 0)
	for i in upto:
		Save.record_job(jobs[i], 2, 5)

func _initialize() -> void:
	print("== Map/spine tests ==")

	# 1. data integrity: every job id resolves; the 3 runs partition ALL levels
	var seen := {}
	var all_resolve := true
	for d in Districts.DISTRICTS.size():
		for id in Districts.DISTRICTS[d].jobs:
			if Districts.level_index(id) < 0:
				all_resolve = false
			seen[id] = true
	ok(all_resolve, "every district job id resolves to a level")
	ok(seen.size() == Levels.LEVELS.size(), "district runs cover every level exactly once")

	# 2. fresh save: only the first district is open
	fresh("doors")
	ok(Districts.unlocked(0), "district 1 open from the start")
	ok(not Districts.unlocked(1) and not Districts.unlocked(2), "districts 2/3 locked on fresh save")
	ok(Districts.next_job(0) == 0, "next job is the first job")

	# 3. jobs door: all-but-one of the previous district
	clear_district(0, true)                  # 3 of Wren's 4 jobs
	ok(Districts.unlocked(1), "district 2 opens via jobs door (all but one)")
	ok(not Districts.unlocked(2), "district 3 still needs district 2 progress")
	ok(not Districts.district_complete(0), "district 1 not complete with one job left")

	# 4. room door: a finished bedroom opens district 2 with zero jobs cleared
	fresh("roomdoor")
	Save.add_coins(700)
	for slot in ["rug", "bed", "lamp", "shelf"]:
		Save.buy_decor("bedroom", slot, 100)
	ok(Districts.unlocked(1), "district 2 opens via room door (bedroom complete)")
	ok(not Districts.unlocked(2), "room door only opens the district the room funds")

	# 5. client lump: pending only when the run completes; pays exactly once
	fresh("lump")
	clear_district(0, true)
	ok(not Districts.lump_pending(0), "no lump while the run is unfinished")
	var last_job: String = Districts.DISTRICTS[0].jobs[Districts.DISTRICTS[0].jobs.size() - 1]
	Save.record_job(last_job, 3, 4)
	ok(Districts.lump_pending(0), "lump pending when the whole run clears")
	var before := Save.coins()
	ok(Save.collect_client_lump("wren", 150), "lump collects")
	ok(Save.coins() == before + 150, "lump pays the right amount")
	ok(not Save.collect_client_lump("wren", 150), "lump never pays twice")
	ok(not Districts.lump_pending(0), "collected lump is no longer pending")
	Save._loaded = false
	ok(Save.client_paid("wren"), "lump flag persists across reload")

	# 6. content integrity: every level is clearable (per-family weight % 2^top == 0,
	#    counting drawer contents)
	var all_clearable := true
	for lv in Levels.LEVELS:
		var weights := {}                    # family -> total weight
		var codes: Array = lv.grid.duplicate()
		for k in lv.get("drawers", {}):
			codes.append(int(lv["drawers"][k]))
		for code in codes:
			if int(code) <= 0:
				continue
			var fam := int(code) / 100
			var tier := int(code) % 100
			weights[fam] = int(weights.get(fam, 0)) + (1 << (tier - 1))
		for fam in weights:
			if int(weights[fam]) % (1 << int(lv.top)) != 0:
				all_clearable = false
				print("    !! %s family %d weight %d not divisible by %d" % \
					[lv.id, fam, weights[fam], 1 << int(lv.top)])
	ok(all_clearable, "every level's families fully vaporize (weight rule)")

	# 7. district tile identity: only families debuted so far; the signature family dominates
	var identity_ok := true
	for d in Districts.DISTRICTS.size():
		var debuted := {}
		for e in d + 1:
			debuted[int(Districts.DISTRICTS[e].family)] = true
		var sig := int(Districts.DISTRICTS[d].family)
		for id in Districts.DISTRICTS[d].jobs:
			var lv: Dictionary = Levels.LEVELS[Districts.level_index(id)]
			var counts := {}                 # family -> piece count (incl drawer contents)
			var codes: Array = lv.grid.duplicate()
			for k in lv.get("drawers", {}):
				codes.append(int(lv["drawers"][k]))
			for code in codes:
				if int(code) > 0:
					var fam := int(code) / 100
					counts[fam] = int(counts.get(fam, 0)) + 1
			for fam in counts:
				if not debuted.has(fam):
					identity_ok = false
					print("    !! %s uses family %d before its district debuts it" % [id, fam])
			for fam in counts:
				if fam != sig and int(counts[fam]) > int(counts.get(sig, 0)):
					identity_ok = false
					print("    !! %s: family %d outnumbers the signature family %d" % [id, fam, sig])
	ok(identity_ok, "district tile identity: debuted-only families, signature dominant")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
