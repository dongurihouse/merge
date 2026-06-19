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
# A small starting gem balance for a brand-new save, so the premium-currency wallet slot reads
# alive (not a dead 0) and a first acquire-button tap lands the player in a non-empty store. Kept
# deliberately small — a taste, not a giveaway. Only fresh saves get it (defaulted, never re-granted).
const NEW_SAVE_GEMS := 5
# §5 The Bag — the owned-slot floor/cap. The persistence layer is a pure leaf (no content.gd
# import — that would be circular), so the band lives here; the game's per-slot 💎 price
# schedule lives in grove_data and is passed into buy_bag_slot() by the scene.
const BAG_MIN_SLOTS := 6
const BAG_MAX_SLOTS := 18

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
		"currencies": {"coins": 0, "diamonds": NEW_SAVE_GEMS},
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

# --- the piggy bank / accrual vault (T44, section 10) ---------------------------
# A persistent vault that SKIMS a fraction of earned premium into a banked balance
# (claimable by one fixed real-money price). Storage only: {bank, carry} where `bank`
# is the whole claimable diamonds and `carry` is the sub-unit numerator remainder, so a
# fractional skim of many small earns never truncates to nothing (the skim MATH lives in
# core/vault.gd; this is the pure persistence). Absent on old saves -> {0,0} via the
# default-on-read path, no migration. Stored at the top level (sibling of currencies).
static func vault() -> Dictionary:
	_ensure_loaded()
	if not data.has("vault"):
		data["vault"] = {"bank": 0, "carry": 0}
	return data["vault"]

static func vault_bank() -> int:
	return int(vault().get("bank", 0))

static func vault_carry() -> int:
	return int(vault().get("carry", 0))

# Set both the banked whole and the sub-unit carry in ONE write (vault.gd computes them).
static func set_vault(bank: int, carry: int) -> void:
	var v := vault()
	v["bank"] = maxi(0, bank)
	v["carry"] = maxi(0, carry)
	save_now()

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

# The grove's persistent state blob (board/bag/unlocks/quests/rng) — a live ref.
# Spot-id renames: barn = Order Q (placement-law v2); farmhouse = T21 (the §8 home-hub
# roster — chest/bed/table… → hearth/kitchen/well/larder/porch/boxes/lantern/fence). This
# is the ONE permitted code mention of the retired ids — every reader shares grove(), so the
# rename runs here, once a save touches it, and is naturally idempotent (key and value id
# sets are disjoint; after the rename the old keys are gone). Migrates unlocks (ownership),
# custom (chosen variant) so counts/stars/looks survive.
# (A save from a naming TWO renames back isn't chained — pre-launch, disposable; the live model is what matters.)
const _SPOT_ID_RENAMES := {
	"fh_chest": "fh_hearth", "fh_bed": "fh_kitchen", "fh_table": "fh_well", "fh_rug": "fh_larder",
	"fh_plant": "fh_porch", "fh_wheel": "fh_boxes", "fh_chair": "fh_lantern",
	"bn_doors": "bn_bales", "bn_loft": "bn_stool",
	"bn_stalls": "bn_churns", "bn_weathervane": "bn_plow",
}

static func grove() -> Dictionary:
	_ensure_loaded()
	if not data.has("grove"):
		data["grove"] = {}
	_migrate_spot_ids(data["grove"])
	_migrate_exp_to_stars(data["grove"])
	_migrate_map_keys(data["grove"])
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

# T38: the zone→map vocabulary sweep renamed two persisted grove keys. Carry an old
# save's values over (idempotent — old key erased after the move).
const _MAP_KEY_RENAMES := {"last_zone": "last_map", "quests_zone": "quests_map"}
static func _migrate_map_keys(g: Dictionary) -> void:
	for old in _MAP_KEY_RENAMES:
		if g.has(old):
			if not g.has(_MAP_KEY_RENAMES[old]):
				g[_MAP_KEY_RENAMES[old]] = g[old]
			g.erase(old)

static func grove_write() -> void:
	_ensure_loaded()
	save_now()

# --- residents: the per-map population roster (§1 population sub-game) -------------
# Residents WELCOMED on a completed map, auto-merging two-of-a-kind a tier up. Stored in
# the grove blob as residents = {map_id: {type_id: [t1count, t2count, t3count]}} — a count
# array of length RESIDENT_MAX_TIER per type. Defaulted on read (like hub levels / bag slots
# above): an OLD save with no `residents` key reads as empty, no migration. The merge MATH +
# the welcome/cost logic live in content.gd; this is the pure persistence (read with defaults,
# write + persist). NO roster cap — the ambient display rebuilds from this stateless.
static func residents(map_id: String) -> Dictionary:
	return grove().get("residents", {}).get(map_id, {})

static func resident_counts(map_id: String, type_id: String) -> Array:
	var c: Array = residents(map_id).get(type_id, [])
	if c.size() < 3:
		return [0, 0, 0]
	# JSON reloads ints as floats — cast so callers (and == tests) see a clean int array.
	return [int(c[0]), int(c[1]), int(c[2])]

static func set_resident_counts(map_id: String, type_id: String, counts: Array) -> void:
	var g := grove()
	if not g.has("residents"):
		g["residents"] = {}
	var by_map: Dictionary = g["residents"]
	if not by_map.has(map_id):
		by_map[map_id] = {}
	by_map[map_id][type_id] = counts
	grove_write()

# --- the bag: owned-slot count (Core §5) -----------------------------------------
# How many bag slots the player OWNS (the spec capacity, §5): 6 at start, +1 per 💎 buy,
# hard cap 18. Stored in the grove blob, defaulted on read (like hub levels above) — so an
# OLD save with no key, or the retired `bag3` flag, reads as 6 with no migration and no data
# loss (6 >= the old 2/3 capacity). The bag CONTENTS stay in the separate `bag` array.
static func bag_slots() -> int:
	return clampi(int(grove().get("bag_slots", BAG_MIN_SLOTS)), BAG_MIN_SLOTS, BAG_MAX_SLOTS)

static func set_bag_slots(n: int) -> void:
	grove()["bag_slots"] = clampi(n, BAG_MIN_SLOTS, BAG_MAX_SLOTS)
	grove_write()

# Buy ONE expansion for `price` 💎: refuse at the cap (nothing left to buy) or when broke,
# else spend and grow the owned count by 1. Returns whether a slot was actually bought.
# Convenience, never possibility (§4/§5) — a refusal never blocks progress, only the speed-up.
static func buy_bag_slot(price: int) -> bool:
	if bag_slots() >= BAG_MAX_SLOTS:
		return false
	if not spend_diamonds(price):
		return false
	set_bag_slots(bag_slots() + 1)
	return true

# --- the gate-unveil pointer (Core §8 — the wordless map→board handoff) ----------
# Completing a map's spots unveils its great-spirit GATE quest, which now waits on the
# BOARD as the lone fence stand (§7). That handoff is silent across screens, so the map
# ARMS this pointer (the just-completed map index) on completion; the board CONSUMES it
# on its next open — playing a wordless cue toward the gate stand — and clears it. -1 =
# nothing pending. Persisted in the grove blob so it survives the map→board scene change.
static func gate_pointer() -> int:
	return int(grove().get("gate_pointer", -1))

static func set_gate_pointer(map: int) -> void:
	grove()["gate_pointer"] = map
	grove_write()

static func clear_gate_pointer() -> void:
	if grove().has("gate_pointer"):
		grove().erase("gate_pointer")
		grove_write()

# Consume the pointer: return the pending map (or -1) and clear it in the same step, so
# the board's wordless cue fires exactly once per unveil.
static func take_gate_pointer() -> int:
	var z := gate_pointer()
	if z >= 0:
		clear_gate_pointer()
	return z

# --- FTUE feature-spotlight seen-state (Core §14 / T28) -------------------------
# Which staged features have already been spotlit (so a feature is announced exactly
# ONCE, ever). Lives in the grove blob keyed by feature id; absent on old saves and
# defaulted empty via the deep-merge-over-defaults path (no migration). The §14
# first-appearance gate (engine/scripts/core/spotlight.gd) reads + records here.
static func spotlights_seen() -> Array:
	return Array(grove().get("spotlights_seen", []))

static func spotlight_seen(feature_id: String) -> bool:
	return spotlights_seen().has(feature_id)

static func mark_spotlight_seen(feature_id: String) -> void:
	var g := grove()
	var seen: Array = g.get("spotlights_seen", [])
	if not seen.has(feature_id):
		seen.append(feature_id)
		g["spotlights_seen"] = seen
		grove_write()

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
	var last := int(d.get("day", -1))
	if last != today:
		var streak := int(d.get("streak", 0))
		# FORGIVING STREAK (§18 — the login calendar's locked rule): a missed day NEVER
		# resets the streak to day 1; it SOFT-DECAYS one step per missed day (floored at 0).
		# A continued streak (claimed yesterday, today = yesterday+1) carries intact — the
		# claim then bumps it. The old code hard-zeroed on any miss; that punitive reset is
		# exactly what the spec forbids.
		if last < 0:
			streak = 0                              # never played → start fresh
		else:
			var missed := (today - last) - 1        # 0 = played yesterday (chain intact)
			if not bool(d.get("claimed", false)):
				missed += 1                          # never finished yesterday → one more miss
			streak = maxi(0, streak - maxi(0, missed))   # soft-decay one step per missed day
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

# ════════════════════════════════════════════════════════════════════════════
# T43 — STORE / REWARDED-ADS / OUT-OF-WATER state (ADDITIVE accessor block)
# ════════════════════════════════════════════════════════════════════════════
# A self-contained, append-only persistence block for the §10 monetization layer:
#   • rewarded-ad per-type DAILY usage + cooldown timestamps (Ads, core/ads.gd),
#   • the collect-2× "armed" flag the hub-collect reads (§8 / T42 hook),
#   • one-time purchase flags (starter pack claimed, first cash pack made),
#   • the out-of-water triggered-offer daily usage + cooldown (board energy-wall).
# Everything lives in the grove blob (grove()), so it is test-redirected with the
# rest of the save and DEFAULTED on old saves by the deep-merge-over-defaults path —
# NO SCHEMA bump, no migration. The per-type cap rollover uses the same day index
# (unix/86400) as daily(); cooldowns compare wall-clock seconds.

# The per-type ad ledger: {type -> {day, used, last}} (a live ref in the grove blob).
static func _ad_ledger() -> Dictionary:
	var g := grove()
	if not g.has("ad_ledger"):
		g["ad_ledger"] = {}
	return g["ad_ledger"]

# This type's row for TODAY — rolls `used` back to 0 on the first touch of a new day
# (so a daily cap resets at the day boundary, like the daily bundle). `last` is the
# unix time of the most recent watch (0 = never), kept across days for the cooldown.
static func _ad_row(ad_type: String) -> Dictionary:
	var today := int(Time.get_unix_time_from_system() / 86400.0)
	var led := _ad_ledger()
	var r: Dictionary = led.get(ad_type, {})
	if int(r.get("day", -1)) != today:
		r = {"day": today, "used": 0, "last": float(r.get("last", 0.0))}
		led[ad_type] = r
	return r

# How many times this ad type was watched TODAY (after the day-rollover check).
static func ad_used_today(ad_type: String) -> int:
	return int(_ad_row(ad_type).get("used", 0))

# Whether this ad type may be shown right now: under its daily `cap` AND past its
# `cooldown_s` since the last watch. Pure read — no state change. A cap/cooldown of 0
# means "unlimited / no wait" on that axis.
static func ad_can_show(ad_type: String, cap: int, cooldown_s: float) -> bool:
	var r := _ad_row(ad_type)
	if cap > 0 and int(r.get("used", 0)) >= cap:
		return false
	if cooldown_s > 0.0:
		var since := Time.get_unix_time_from_system() - float(r.get("last", 0.0))
		if since < cooldown_s:
			return false
	return true

# Seconds remaining on this ad type's cooldown (0 if ready) — for a cozy "ready in…"
# read, never a punitive countdown.
static func ad_cooldown_left(ad_type: String, cooldown_s: float) -> float:
	if cooldown_s <= 0.0:
		return 0.0
	var since := Time.get_unix_time_from_system() - float(_ad_row(ad_type).get("last", 0.0))
	return maxf(0.0, cooldown_s - since)

# Record one watch of this ad type: bump today's `used` and stamp `last` = now. The
# caller checks ad_can_show first; this is the commit half.
static func ad_record(ad_type: String) -> void:
	var r := _ad_row(ad_type)
	r["used"] = int(r.get("used", 0)) + 1
	r["last"] = Time.get_unix_time_from_system()
	_ad_ledger()[ad_type] = r
	grove_write()

# One-time purchase flags (§10 starter pack + first-purchase doubler). Defaulted false
# on old saves; flipped true once, never reset (cracking/refresh does not re-arm them).
static func starter_claimed() -> bool:
	return bool(grove().get("starter_claimed", false))

static func set_starter_claimed() -> void:
	grove()["starter_claimed"] = true
	grove_write()

static func first_purchase_made() -> bool:
	return bool(grove().get("first_purchase_made", false))

static func set_first_purchase_made() -> void:
	grove()["first_purchase_made"] = true
	grove_write()

# A banked WATER credit (e.g. the starter pack's water bonus, bought from the map where
# no live board exists). The board adds + clears it on its next open (capped to WATER_CAP
# there). Like shop_pending for items — survives the map→board hop, drained exactly once.
static func water_pending() -> int:
	return int(grove().get("water_pending", 0))

static func add_water_pending(n: int) -> void:
	if n <= 0:
		return
	var g := grove()
	g["water_pending"] = int(g.get("water_pending", 0)) + n
	grove_write()

# Return the banked water credit and clear it in the same step (so the board applies it
# exactly once). Returns 0 when there's nothing pending.
static func take_water_pending() -> int:
	var n := water_pending()
	if n > 0:
		grove().erase("water_pending")
		grove_write()
	return n

# The out-of-water triggered offer (§10) — its own daily-usage + cooldown ledger,
# mirroring the ad gate (low cap + long cooldown, cozy). {day, used, last} in the grove
# blob under `oow_offer`.
static func _oow_row() -> Dictionary:
	var today := int(Time.get_unix_time_from_system() / 86400.0)
	var g := grove()
	var r: Dictionary = g.get("oow_offer", {})
	if int(r.get("day", -1)) != today:
		r = {"day": today, "used": 0, "last": float(r.get("last", 0.0))}
		g["oow_offer"] = r
	return r

static func oow_used_today() -> int:
	return int(_oow_row().get("used", 0))

static func oow_can_show(cap: int, cooldown_s: float) -> bool:
	var r := _oow_row()
	if cap > 0 and int(r.get("used", 0)) >= cap:
		return false
	if cooldown_s > 0.0 and Time.get_unix_time_from_system() - float(r.get("last", 0.0)) < cooldown_s:
		return false
	return true

static func oow_record() -> void:
	var r := _oow_row()
	r["used"] = int(r.get("used", 0)) + 1
	r["last"] = Time.get_unix_time_from_system()
	grove()["oow_offer"] = r
	grove_write()

# --- test support ----------------------------------------------------------

static func configure_for_test(dir: String) -> void:
	path = dir + "save.json"
	bak = dir + "save.bak"
	tmp = dir + "save.tmp"
	legacy = dir + "progress.cfg"
	data = {}
	_loaded = false
