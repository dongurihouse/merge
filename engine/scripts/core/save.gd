extends RefCounted
## THE persistence layer (single owner of all saved state).
## Static singleton (like Audio): everything reads/writes via Save.* — no other save file,
## no other format. Versioned JSON at user://save.json with atomic writes + a .bak fallback
## and a one-time migration from the legacy progress.cfg.
##
## NOT a tree autoload: pure data needs no scene presence, and autoloads don't resolve in
## headless `-s` test runs. Tests call configure_for_test() to redirect the paths.

const SCHEMA_VERSION := 2
const COINS_PER_CLEAR_SEED := 35   # migration: coins granted per past board clear

# Paths are static vars (not consts) so tests can redirect them to a temp dir.
static var path := "user://save.json"
static var bak := "user://save.bak"
static var tmp := "user://save.tmp"
static var legacy := "user://progress.cfg"

static var data: Dictionary = {}
static var _loaded := false

static func _default() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"migrated_v2": false,
		"currencies": {"coins": 0},
		"jobs": {},                       # job_id -> {best_stars, best_drags, completed, plays, first_clear_paid}
		"rooms": {},                      # room_id -> {decor: {slot_id: item_id}}
		"clients": {},                    # client_id -> {lump_paid}
		"stats": {"boards_cleared": 0},
		"settings": {},
	}

# --- lifecycle -------------------------------------------------------------

static func _ensure_loaded() -> void:
	if not _loaded:
		load_now()

static func load_now() -> void:
	_loaded = true
	var loaded := _read(path)
	if loaded.is_empty():
		loaded = _read(bak)            # primary unreadable/corrupt → try the backup
	data = _merge(_default(), loaded)
	# First run with a legacy progress.cfg present and not yet migrated → carry it over once.
	if not bool(data["migrated_v2"]) and FileAccess.file_exists(legacy):
		_migrate_legacy()
	save_now()

static func _migrate_legacy() -> void:
	var c := ConfigFile.new()
	var cleared := 0
	if c.load(legacy) == OK:
		cleared = int(c.get_value("progress", "cleared", 0))
	data["stats"]["boards_cleared"] = cleared
	data["currencies"]["coins"] = coins_raw() + cleared * COINS_PER_CLEAR_SEED
	data["migrated_v2"] = true

# Reads coins WITHOUT _ensure_loaded re-entrancy (used during load_now, where _loaded is set).
static func coins_raw() -> int:
	return int(data["currencies"]["coins"])

static func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var text := FileAccess.get_file_as_string(p)
	if text == "":
		return {}
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}                              # garbage/truncated → treat as missing

static func save_now() -> void:
	data["schema_version"] = SCHEMA_VERSION
	var text := JSON.stringify(data, "  ")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()
	if _read(tmp).is_empty():               # verify the temp file re-parses
		return
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return
	if FileAccess.file_exists(path):
		dir.rename(path.get_file(), bak.get_file())   # keep last-good as backup
	dir.rename(tmp.get_file(), path.get_file())        # atomic swap-in

static func flush() -> void:
	if _loaded:
		save_now()

## DEBUG: wipe ALL progress back to a fresh install (the base debug panel's Reset).
static func reset() -> void:
	data = _default()
	_loaded = true
	save_now()

# Deep additive merge: fills keys missing from `over` using `base`, never drops `over`'s data.
static func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in over:
		if out.has(k) and out[k] is Dictionary and over[k] is Dictionary:
			out[k] = _merge(out[k], over[k])
		else:
			out[k] = over[k]
	return out

# --- accessors -------------------------------------------------------------

static func coins() -> int:
	_ensure_loaded()
	return int(data["currencies"]["coins"])

static func add_coins(n: int) -> void:
	_ensure_loaded()
	data["currencies"]["coins"] = coins() + n
	save_now()

static func spend(n: int, _reason := "") -> bool:
	_ensure_loaded()
	if coins() < n:
		return false
	data["currencies"]["coins"] = coins() - n
	save_now()
	return true

static func boards_cleared() -> int:
	_ensure_loaded()
	return int(data["stats"]["boards_cleared"])

static func record_board_clear(n := 1) -> void:
	_ensure_loaded()
	data["stats"]["boards_cleared"] = boards_cleared() + n
	save_now()

static func record_job(id: String, stars: int, drags: int) -> void:
	_ensure_loaded()
	var jobs: Dictionary = data["jobs"]
	var j: Dictionary = jobs.get(id, {
		"best_stars": 0, "best_drags": -1, "completed": false, "plays": 0, "first_clear_paid": false,
	})
	j["plays"] = int(j["plays"]) + 1
	j["completed"] = true
	j["best_stars"] = maxi(int(j["best_stars"]), stars)
	var bd := int(j["best_drags"])
	j["best_drags"] = drags if bd < 0 else mini(bd, drags)
	j["first_clear_paid"] = true
	jobs[id] = j
	save_now()

static func job(id: String) -> Dictionary:
	_ensure_loaded()
	return data["jobs"].get(id, {})

static func clear_paid(id: String) -> bool:
	_ensure_loaded()
	return bool(data["jobs"].get(id, {}).get("first_clear_paid", false))

# --- rooms / decor -----------------------------------------------------------
# Shape per spec: rooms = {room_id: {decor: {slot_id: item_id}}}. v1 has one item
# per slot, stored as "default", so future style variants stay representable.

static func room_decor(room_id: String) -> Dictionary:
	_ensure_loaded()
	var r: Dictionary = data["rooms"].get(room_id, {})
	return r.get("decor", {})

static func decor_owned(room_id: String, slot_id: String) -> bool:
	return room_decor(room_id).has(slot_id)

static func decor_count(room_id: String) -> int:
	return room_decor(room_id).size()

# Spend + grant in ONE write so a crash can never take the coins without the decor.
static func buy_decor(room_id: String, slot_id: String, cost: int) -> bool:
	_ensure_loaded()
	if decor_owned(room_id, slot_id) or coins() < cost:
		return false
	data["currencies"]["coins"] = coins() - cost
	var rooms: Dictionary = data["rooms"]
	var r: Dictionary = rooms.get(room_id, {"decor": {}})
	r["decor"][slot_id] = "default"
	rooms[room_id] = r
	save_now()
	return true

# --- diamonds (v2 — earned-only; no IAP wired) -----------------------------------

static func diamonds() -> int:
	_ensure_loaded()
	return int(data["currencies"].get("diamonds", 0))

static func add_diamonds(n: int) -> void:
	_ensure_loaded()
	data["currencies"]["diamonds"] = diamonds() + n
	save_now()

static func spend_diamonds(n: int) -> bool:
	_ensure_loaded()
	if diamonds() < n:
		return false
	data["currencies"]["diamonds"] = diamonds() - n
	save_now()
	return true

# --- stars + the grove (v2) -----------------------------------------------------

static func stars() -> int:
	_ensure_loaded()
	return int(data["currencies"].get("stars", 0))

static func add_stars(n: int) -> void:
	_ensure_loaded()
	data["currencies"]["stars"] = stars() + n
	save_now()

static func spend_stars(n: int) -> bool:
	_ensure_loaded()
	if stars() < n:
		return false
	data["currencies"]["stars"] = stars() - n
	save_now()
	return true

# The grove's persistent state blob (board/bag/chapter/quests/rng) — a live ref.
# Spot-id renames: barn = Order Q (placement-law v2); farmhouse = T21 (the §8 home-hub
# roster — chest/bed/table… → hearth/kitchen/well/larder/porch/boxes/lantern/fence). This
# is the ONE permitted code mention of the retired ids — every reader shares grove(), so the
# rename runs here, once a save touches it, and is naturally idempotent (key and value id
# sets are disjoint; after the rename the old keys are gone). Migrates BOTH unlocks
# (ownership) and custom (chosen variant) so counts/stars/looks survive. (A save from a
# naming TWO renames back isn't chained — pre-launch, disposable; the live model is what matters.)
const _SPOT_ID_RENAMES := {
	"fh_chest": "fh_hearth", "fh_bed": "fh_kitchen", "fh_table": "fh_well", "fh_rug": "fh_larder",
	"fh_plant": "fh_porch", "fh_wheel": "fh_boxes", "fh_chair": "fh_lantern", "fh_picture": "fh_fence",
	"bn_doors": "bn_bales", "bn_loft": "bn_stool",
	"bn_stalls": "bn_churns", "bn_weathervane": "bn_plow",
}

static func grove() -> Dictionary:
	_ensure_loaded()
	if not data.has("grove"):
		data["grove"] = {}
	_migrate_spot_ids(data["grove"])
	_migrate_exp_to_stars(data["grove"])
	return data["grove"]

# Old saves stored level as `exp` (= 10 × stars earned). The clock is now the
# cumulative `stars_earned`, so carry the old level over (exp/10) and drop exp.
static func _migrate_exp_to_stars(g: Dictionary) -> void:
	if g.has("exp"):
		if not g.has("stars_earned"):
			g["stars_earned"] = int(int(g["exp"]) / 10.0)
		g.erase("exp")

static func _migrate_spot_ids(g: Dictionary) -> void:
	for blob_key in ["unlocks", "custom"]:
		var blob: Dictionary = g.get(blob_key, {})
		for old in _SPOT_ID_RENAMES:
			if blob.has(old):
				blob[_SPOT_ID_RENAMES[old]] = blob[old]
				blob.erase(old)

static func grove_write() -> void:
	_ensure_loaded()
	save_now()

# --- settings -----------------------------------------------------------------

static func get_setting(key: String, def: bool = true) -> bool:
	_ensure_loaded()
	return bool(data["settings"].get(key, def))

static func set_setting(key: String, v: bool) -> void:
	_ensure_loaded()
	data["settings"][key] = v
	save_now()

# --- quest counters (daily bundle + silent milestones) --------------------------

# In-memory bump; persisted by the NEXT save_now (clears, purchases, claims, flush).
# Quest counters aren't worth a disk write per merge.
static func bump_stat(key: String, n: int = 1) -> void:
	_ensure_loaded()
	data["stats"][key] = int(data["stats"].get(key, 0)) + n

static func stat(key: String) -> int:
	_ensure_loaded()
	return int(data["stats"].get(key, 0))

# Today's bundle state, rolling over (and resolving the streak) on the first touch
# of a new day. {day, jobs, merges, coins, claimed, streak} — a live reference.
static func daily() -> Dictionary:
	_ensure_loaded()
	var today := int(Time.get_unix_time_from_system() / 86400.0)
	var d: Dictionary = data.get("daily", {})
	if int(d.get("day", -1)) != today:
		var streak := int(d.get("streak", 0))
		if int(d.get("day", -1)) != today - 1 or not bool(d.get("claimed", false)):
			streak = 0           # missed a day (or never finished yesterday)
		d = {"day": today, "jobs": 0, "merges": 0, "coins": 0, "claimed": false, "streak": streak}
		data["daily"] = d
	return d

static func bump_daily(key: String, n: int = 1) -> void:
	var d := daily()
	d[key] = int(d.get(key, 0)) + n      # in-memory; persisted with the next save_now

static func claim_daily(reward: int) -> bool:
	var d := daily()
	if bool(d.get("claimed", false)):
		return false
	d["claimed"] = true
	d["streak"] = int(d.get("streak", 0)) + 1
	data["currencies"]["coins"] = coins() + reward
	save_now()
	return true

# --- clients (story spine) ----------------------------------------------------
# A client's thank-you coin lump pays exactly once. Grant + flag in ONE write,
# same crash-safety shape as buy_decor.

static func client_paid(client_id: String) -> bool:
	_ensure_loaded()
	return bool(data["clients"].get(client_id, {}).get("lump_paid", false))

static func collect_client_lump(client_id: String, amount: int) -> bool:
	_ensure_loaded()
	if client_paid(client_id):
		return false
	data["currencies"]["coins"] = coins() + amount
	data["clients"][client_id] = {"lump_paid": true}
	save_now()
	return true

# --- test support ----------------------------------------------------------

static func configure_for_test(dir: String) -> void:
	path = dir + "save.json"
	bak = dir + "save.bak"
	tmp = dir + "save.tmp"
	legacy = dir + "progress.cfg"
	data = {}
	_loaded = false
