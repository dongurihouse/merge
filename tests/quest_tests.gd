extends SceneTree
## Headless tests for the M8 quest layer (session chip + daily bundle + milestones).
##   godot --headless --path . -s res://tests/quest_tests.gd

const Save = preload("res://scripts/save.gd")
const Levels = preload("res://scripts/levels.gd")
const Quests = preload("res://scripts/quests.gd")

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
	var dir := "user://tu_test_quest_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func level(id: String) -> Dictionary:
	for lv in Levels.LEVELS:
		if String(lv.get("id", "")) == id:
			return lv
	return {}

func _initialize() -> void:
	print("== Quest tests ==")

	# 1. session chip picks the board's flavor: friction-specific beats generic
	fresh("pick")
	Quests.start_session(level("tidy_03"))
	ok(Quests.kind == "drawer" and Quests.need == 2, "drawers level -> 'pop 2 drawers' chip")
	Quests.start_session(level("tidy_06"))
	ok(Quests.kind == "cover" and Quests.need == 2, "covers level -> 'lift 2 covers' chip")
	Quests.start_session(level("tidy_02"))
	ok(Quests.kind == "merge" and Quests.need == 8, "plain 16-piece board -> 'merge 8 times' chip")

	# 2. the chip progresses, completes once, and pays once
	fresh("chip")
	Quests.start_session(level("tidy_02"))         # merge x8
	var fired := 0
	for i in 12:                                    # more events than needed
		if Quests.on_event("merge"):
			fired += 1
	ok(fired == 1, "chip completion fires exactly once")
	ok(Save.coins() == Quests.SESSION_REWARD, "chip pays the session reward once")
	ok(Quests.on_event("drawer") == false, "off-kind events never complete the chip")

	# 3. milestones accrue silently regardless of the chip
	ok(Save.stat("merge") == 12 and Save.stat("drawer") == 1, "milestone counters accrue per event")

	# 4. daily bundle: counters -> complete -> claim pays once
	fresh("daily")
	Quests.start_session(level("tidy_01"))
	for i in 30:
		Quests.on_event("merge")
	for i in 3:
		Quests.on_event("clear")
	Quests.on_event("coins", 100)
	ok(Quests.daily_complete(), "bundle complete at 3 jobs / 30 merges / 100 coins")
	var before := Save.coins()
	ok(Quests.try_claim_daily(), "bundle claims when complete")
	ok(Save.coins() == before + Quests.DAILY_REWARD, "bundle pays the daily reward")
	ok(int(Save.daily()["streak"]) == 1, "first claim starts the streak")
	ok(not Quests.try_claim_daily(), "bundle never pays twice in a day")

	# 5. rollover: a claimed yesterday keeps the streak, counters reset
	Save.data["daily"]["day"] = int(Save.data["daily"]["day"]) - 1
	var d := Save.daily()                            # rolls over to "today"
	ok(int(d["merges"]) == 0 and not bool(d["claimed"]), "new day resets the counters")
	ok(int(d["streak"]) == 1, "claimed yesterday carries the streak")

	# 6. a missed day (or unfinished yesterday) resets the streak
	Save.data["daily"]["day"] = int(Save.data["daily"]["day"]) - 3
	Save.data["daily"]["claimed"] = true
	ok(int(Save.daily()["streak"]) == 0, "a missed day resets the streak")
	fresh("unfinished")
	Save.bump_daily("merges", 5)                     # touch today, never claim
	Save.data["daily"]["day"] = int(Save.data["daily"]["day"]) - 1
	Save.data["daily"]["streak"] = 4
	ok(int(Save.daily()["streak"]) == 0, "an unclaimed yesterday resets the streak")

	# 7. restart farming: the chip flips to done but pays once per board per day
	fresh("farm")
	Quests.start_session(level("tidy_02"))
	for i in 8:
		Quests.on_event("merge")
	var paid := Save.coins()
	ok(paid == Quests.SESSION_REWARD, "first completion pays")
	Quests.start_session(level("tidy_02"))      # restart re-arms the chip…
	var refired := false
	for i in 8:
		if Quests.on_event("merge"):
			refired = true
	ok(not refired and Save.coins() == paid, "restarted board completes silently, pays nothing")
	Quests.start_session(level("tidy_03"))      # a DIFFERENT board still pays
	Quests.on_event("drawer")
	Quests.on_event("drawer")
	ok(Save.coins() == paid + Quests.SESSION_REWARD, "a different board's chip pays")
	Save.data["daily"]["day"] = int(Save.data["daily"]["day"]) - 1
	Quests.start_session(level("tidy_02"))      # …and a NEW DAY re-arms it
	var day2 := false
	for i in 8:
		if Quests.on_event("merge"):
			day2 = true
	ok(day2, "a new day re-arms the same board's chip")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
