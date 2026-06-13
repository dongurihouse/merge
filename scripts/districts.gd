extends RefCounted
## Tidy Up — the story spine: TOWN → DISTRICT → CLIENT → JOB (board). v1 ships
## 3 districts = the 3 item families, one debuting per district; each district is
## one client hiring you for a run of jobs (the existing level ladder, partitioned).
##
## Unlocking is the DOUBLE DOOR (keeps can't-lose airtight): district d+1 opens when
## you clear MOST (all but one) of district d's jobs OR finish the room district d
## funds — whichever comes first. A pure solver and a pure decorator both advance.
## Completing a client's whole run pays their thank-you coin lump exactly once.

const Levels = preload("res://scripts/levels.gd")
const Save = preload("res://scripts/save.gd")
const RoomScreen = preload("res://scripts/room.gd")

# Names/thanks are tr() keys (translated at display time in jobs.gd).
const DISTRICTS := [
	{
		"id": "linen_lane", "name": "Linen Lane", "family": 1,
		"card": "res://assets/map/district_clothes.png",
		"tray": "res://assets/ui/tray_clothes.png",     # board mat skin (fallback: board_tray)
		"bg": "res://assets/ui/bg_linen_lane.png",      # board backdrop (fallback: bedroom)
		"client": {"id": "wren", "name": "Wren",
			"bust": "res://assets/map/client_wren.png",
			"thanks": "You're a lifesaver — the laundry corner finally breathes!",
			"lump": 150},
		"jobs": ["tidy_01", "tidy_02", "tidy_03", "tidy_04", "tidy_10"],
		"funds_room": "bedroom",
	},
	{
		"id": "paperleaf_court", "name": "Paperleaf Court", "family": 2,
		"card": "res://assets/map/district_books.png",
		"tray": "res://assets/ui/tray_books.png",
		"bg": "res://assets/ui/bg_paperleaf.png",
		"client": {"id": "juniper", "name": "Juniper",
			"bust": "res://assets/map/client_juniper.png",
			"thanks": "Every book back on its shelf — you wonderful thing!",
			"lump": 150},
		"jobs": ["tidy_06", "tidy_11", "tidy_05", "tidy_12", "tidy_07"],
		"funds_room": "",
	},
	{
		"id": "tumble_park", "name": "Tumble Park", "family": 3,
		"card": "res://assets/map/district_toys.png",
		"tray": "res://assets/ui/tray_toys.png",
		"bg": "res://assets/ui/bg_tumble.png",
		"client": {"id": "pip", "name": "Pip",
			"bust": "res://assets/map/client_pip.png",
			"thanks": "My bear says thanks! You found ALL the pieces!",
			"lump": 150},
		"jobs": ["tidy_08", "tidy_09", "tidy_13", "tidy_14", "tidy_15"],
		"funds_room": "",
	},
]

static func district_of_level(idx: int) -> int:
	if idx < 0 or idx >= Levels.LEVELS.size():
		return -1
	var id := String(Levels.LEVELS[idx].get("id", ""))
	for d in DISTRICTS.size():
		if DISTRICTS[d].jobs.has(id):
			return d
	return -1

# District art with graceful fallback (the game ships before the art does).
static func tray_path(level_idx: int, fallback: String) -> String:
	var d := district_of_level(level_idx)
	if d >= 0 and ResourceLoader.exists(DISTRICTS[d].tray):
		return DISTRICTS[d].tray
	return fallback

static func bg_path(level_idx: int, fallback: String) -> String:
	var d := district_of_level(level_idx)
	if d >= 0 and ResourceLoader.exists(DISTRICTS[d].bg):
		return DISTRICTS[d].bg
	return fallback

static func level_index(job_id: String) -> int:
	for i in Levels.LEVELS.size():
		if String(Levels.LEVELS[i].get("id", "")) == job_id:
			return i
	return -1

static func job_count(d: int) -> int:
	return DISTRICTS[d].jobs.size()

static func jobs_cleared(d: int) -> int:
	var n := 0
	for id in DISTRICTS[d].jobs:
		if bool(Save.job(id).get("completed", false)):
			n += 1
	return n

static func district_complete(d: int) -> bool:
	return jobs_cleared(d) == job_count(d)

# "Most of the jobs" = all but one (generous on short runs, still real progress).
static func jobs_door(d: int) -> bool:
	return jobs_cleared(d) >= maxi(1, job_count(d) - 1)

static func room_door(d: int) -> bool:
	var room: String = DISTRICTS[d].funds_room
	return room == "bedroom" and RoomScreen.bedroom_complete()

static func unlocked(d: int) -> bool:
	if d <= 0:
		return true
	return jobs_door(d - 1) or room_door(d - 1)

# Index into the district's jobs of the first uncleared one, or -1 if all done.
static func next_job(d: int) -> int:
	for i in DISTRICTS[d].jobs.size():
		if not bool(Save.job(DISTRICTS[d].jobs[i]).get("completed", false)):
			return i
	return -1

static func lump_pending(d: int) -> bool:
	return district_complete(d) and not Save.client_paid(DISTRICTS[d].client.id)

# The first uncleared job the player can actually play, as a LEVELS index (-1 = all done).
static func next_open_level() -> int:
	for d in DISTRICTS.size():
		if not unlocked(d):
			continue
		var i := next_job(d)
		if i >= 0:
			return level_index(DISTRICTS[d].jobs[i])
	return -1
