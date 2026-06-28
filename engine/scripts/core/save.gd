extends RefCounted
## THE persistence layer (single owner of all saved state).
## Static singleton (like Audio): everything reads/writes via Save.* — no other save file,
## no other format. Versioned JSON at user://save.json with atomic writes + a .bak fallback
## Older schema versions are discarded and recreated fresh on load.
##
## NOT a tree autoload: pure data needs no scene presence, and autoloads don't resolve in
## headless `-s` test runs. Tests call configure_for_test() to redirect the paths.

# The active game's DATA (for WATER_CAP — water is a capped grove currency). game.gd is a core/
# leaf that only exposes DATA/PALETTE; it never imports Save, so this is not the circular content.gd
# dependency the bag band below avoids — just a one-way read of a tuning constant.
const Game = preload("res://engine/scripts/core/game.gd")

const SCHEMA_VERSION := 4   # v4: force a one-time profile wipe on the new release (no migration — see load_now)
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

static var data: Dictionary = {}
static var _loaded := false

static func _default() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"currencies": {"coins": 0, "diamonds": NEW_SAVE_GEMS},
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
	# No migration: a save from an older schema is DISCARDED and recreated fresh (delete-and-recreate).
	if int(loaded.get("schema_version", 0)) != SCHEMA_VERSION:
		loaded = {}
	data = _merge(_default(), loaded)
	save_now()

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
	_save_data(data)

static func _save_data(next_data: Dictionary) -> void:
	next_data["schema_version"] = SCHEMA_VERSION
	var text := JSON.stringify(next_data, "  ")
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

# --- the grove (v3) -------------------------------------------------------------

# The grove's persistent state blob (board/bag/unlocks/quests/rng/exp) — a live ref. No
# migrations: a save from an older schema was already discarded + recreated in load_now().
static func grove() -> Dictionary:
	_ensure_loaded()
	if not data.has("grove"):
		data["grove"] = {}
	return data["grove"]

static func grove_write() -> void:
	_ensure_loaded()
	save_now()

# The single cumulative progression total (replaces stars_earned + the spendable balance).
# Only ever increases; every world unlock gates on reaching a threshold of it.
static func exp_total() -> int:
	return int(grove().get("exp", 0))

static func add_exp(n: int) -> void:
	var g := grove()
	g["exp"] = int(g.get("exp", 0)) + maxi(0, n)
	grove_write()

# --- residents: the per-map population roster (§1 population sub-game) -------------
# Residents WELCOMED on a completed map, auto-merging two-of-a-kind a tier up. Stored in
# the grove blob as residents = {map_id: {type_id: [t1count, t2count, … t<MAX>count]}} — a count
# array of length RESIDENT_MAX_TIER per type. Defaulted on read (like hub levels / bag slots
# above): an OLD save with no `residents` key reads as empty, no migration. The merge MATH +
# the welcome/cost logic live in content.gd; this is the pure persistence (read with defaults,
# write + persist). NO roster cap — the ambient display rebuilds from this stateless.
static func residents(map_id: String) -> Dictionary:
	return grove().get("residents", {}).get(map_id, {})

# Always returns a length-RESIDENT_MAX_TIER int array: a shorter saved array (e.g. a pre-12-tier
# save, or absent) right-pads with zeros, so old saves migrate on read with no schema bump and
# resolve_resident_merges (which indexes up to counts[MAX-1]) never runs past the end.
static func resident_counts(map_id: String, type_id: String) -> Array:
	var c: Array = residents(map_id).get(type_id, [])
	var out: Array = []
	# JSON reloads ints as floats — cast so callers (and == tests) see a clean int array.
	for i in int(Game.DATA.RESIDENT_MAX_TIER):
		out.append(int(c[i]) if i < c.size() else 0)
	return out

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

# (The FTUE feature-spotlight seen-state API — spotlights_seen / spotlight_seen /
# mark_spotlight_seen — was removed 2026-06-23 with the dormant spotlight subsystem. The
# redesign is specced + parked (docs/superpowers/specs/2026-06-23-ftue-hand-gesture-spotlight-
# design.md); the rebuild re-adds it here. A leftover "spotlights_seen" key on old saves is
# harmless — the deep-merge-over-defaults load never drops unknown keys.)

# --- settings -----------------------------------------------------------------

static func get_setting(key: String, def: bool = true) -> bool:
	_ensure_loaded()
	return bool(data["settings"].get(key, def))

static func set_setting(key: String, v: bool) -> void:
	_ensure_loaded()
	data["settings"][key] = v
	save_now()

# --- quest counters (daily bundle + silent milestones) --------------------------

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

# ════════════════════════════════════════════════════════════════════════════
# T43 — STORE / FREE-CLAIM state (ADDITIVE accessor block)
# ════════════════════════════════════════════════════════════════════════════
# A self-contained, append-only persistence block for the §10 monetization layer:
#   • free-claim per-type DAILY usage + cooldown timestamps (Claims, core/claims.gd),
#   • one-time purchase flags (starter pack claimed, first cash pack made).
# Everything lives in the grove blob (grove()), so it is test-redirected with the
# rest of the save and DEFAULTED on old saves by the deep-merge-over-defaults path —
# NO SCHEMA bump, no migration. The per-type cap rollover uses the same day index
# (unix/86400) as daily(); cooldowns compare wall-clock seconds.

# The per-type claim ledger: {type -> {day, used, last}} (a live ref in the grove blob).
static func _claim_ledger() -> Dictionary:
	var g := grove()
	if not g.has("claim_ledger"):
		g["claim_ledger"] = {}
	return g["claim_ledger"]

# This type's row for TODAY — rolls `used` back to 0 on the first touch of a new day
# (so a daily cap resets at the day boundary, like the daily bundle). `last` is the
# unix time of the most recent claim (0 = never), kept across days for the cooldown.
static func _claim_row(kind: String) -> Dictionary:
	var today := int(Time.get_unix_time_from_system() / 86400.0)
	var led := _claim_ledger()
	var r: Dictionary = led.get(kind, {})
	if int(r.get("day", -1)) != today:
		r = {"day": today, "used": 0, "last": float(r.get("last", 0.0))}
		led[kind] = r
	return r

# How many times this claim type was taken TODAY (after the day-rollover check).
static func claim_used_today(kind: String) -> int:
	return int(_claim_row(kind).get("used", 0))

# Whether this claim type may be shown right now: under its daily `cap` AND past its
# `cooldown_s` since the last claim. Pure read — no state change. A cap/cooldown of 0
# means "unlimited / no wait" on that axis.
static func claim_can_show(kind: String, cap: int, cooldown_s: float) -> bool:
	var r := _claim_row(kind)
	if cap > 0 and int(r.get("used", 0)) >= cap:
		return false
	if cooldown_s > 0.0:
		var since := Time.get_unix_time_from_system() - float(r.get("last", 0.0))
		if since < cooldown_s:
			return false
	return true

# Seconds remaining on this claim type's cooldown (0 if ready) — for a cozy "ready in…"
# read, never a punitive countdown.
static func claim_cooldown_left(kind: String, cooldown_s: float) -> float:
	if cooldown_s <= 0.0:
		return 0.0
	var since := Time.get_unix_time_from_system() - float(_claim_row(kind).get("last", 0.0))
	return maxf(0.0, cooldown_s - since)

# Record one claim of this type: bump today's `used` and stamp `last` = now. The
# caller checks claim_can_show first; this is the commit half.
static func claim_record(kind: String) -> void:
	var r := _claim_row(kind)
	r["used"] = int(r.get("used", 0)) + 1
	r["last"] = Time.get_unix_time_from_system()
	_claim_ledger()[kind] = r
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

static func board_tutorial_seen() -> bool:
	return bool(grove().get("board_tutorial_seen", false))

static func mark_board_tutorial_seen() -> void:
	grove()["board_tutorial_seen"] = true
	grove_write()

# --- rush teaching popup: how many times the "Tap to Merge!" intro has shown ------
# A small counter in the grove blob (defaulted to 0 on old saves, no migration) gating the
# rush-start teaching popup to a player's first few rushes. The threshold lives in explore.gd
# (Explore.rush_intro_should_show); this is the pure persistence — read with a default, bump + save.
static func rush_intro_seen() -> int:
	return int(grove().get("rush_intro_seen", 0))

static func mark_rush_intro_seen() -> void:
	grove()["rush_intro_seen"] = rush_intro_seen() + 1
	grove_write()

# --- water — a Save-backed currency (grove energy) -------------------------
# Water lives in the grove blob, capped at WATER_CAP. It is the SINGLE source of truth: the shop
# grants through these accessors (like coins/diamonds), the HUD reads them, and the board keeps a
# live cache it re-syncs from here (gameplay regen/pop write back through it). A grant may exceed
# WATER_CAP when `over_cap` (the free refill banks a spare); regen pauses above the cap
# (board_logic.regen), so the spare is kept until spent. Default = a full can (a fresh save reads full).
static func water() -> int:
	return int(grove().get("water", int(Game.DATA.WATER_CAP)))

static func set_water(n: int) -> void:
	grove()["water"] = maxi(0, n)
	grove_write()

# Add `n` water; clamped to WATER_CAP unless `over_cap`. Returns the new total.
static func add_water(n: int, over_cap := false) -> int:
	var v := water() + n
	if not over_cap:
		v = mini(v, int(Game.DATA.WATER_CAP))
	set_water(v)
	return water()

# Top the can to full (the 💎 fill) — never reduces a banked over-cap spare. Returns the new total.
static func fill_water() -> int:
	set_water(maxi(water(), int(Game.DATA.WATER_CAP)))
	return water()

# A banked WATER credit (e.g. the starter pack's water bonus, bought from the map where
# no live board exists). The board adds + clears it on its next open (capped to WATER_CAP
# there) — survives the map→board hop, drained exactly once.
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

# --- test support ----------------------------------------------------------

static func configure_for_test(dir: String) -> void:
	path = dir + "save.json"
	bak = dir + "save.bak"
	tmp = dir + "save.tmp"
	data = {}
	_loaded = false
