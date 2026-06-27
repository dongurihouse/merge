extends RefCounted
## Residents HABITAT model — the payback half of the residents expansion (v1 slice).
## Pure logic over the persisted `grove` blob, mirroring content.gd's boost_taps pattern
## (reads/writes Save.grove() directly; no save.gd change, no schema bump, no migration —
## new keys default-on-read). v1 RARITY IS PARKED: a spirit is {kind, tier}; merge is
## same kind + same tier; production is tier-only. The Rush/boxes (acquisition) is a
## separate build — until it ships, hand_add() is the stand-in that drops a spirit in hand.
##
## Owned grove-blob keys:
##   hand     : Array of {kind, tier}              — unplaced spirits (the holding area, UNBOUNDED)
##   habitat  : { map_id: Array of {kind, tier} }  — spirits PLACED on a map (len <= cap)
##   hab_prod : { map_id: {acc: float, last: float} } — per-map idle-production accrual state

const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Content = preload("res://engine/scripts/core/content.gd")   # §1 the spot-scaled roster capacity ramp
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")   # the generator's tier roll (roll_tier) — chests reuse the SAME curve
const D = Game.DATA

const DEFAULT_CAP := 8                  # full habitat slots (= RESIDENT_SLOTS_MAX); the roster RAMPS up to this as the map is restored
const MAX_TIER: int = D.RESIDENT_MAX_TIER   # reuse the existing cascade cap (12) as the v1 tier band

# PROVISIONAL feel dials — the slice plays with these; final values come from the parked grove_sim/economy pass.
# The production model: each map matures a FIXED reward UNIT; TIER speeds the cadence, COUNT raises the cap,
# the per-unit AMOUNT never scales — which is what keeps water/diamonds bounded (I2 / IAP safe).
const UNITS_PER_HOUR_PER_TIER := 0.25   # production UNITS/hour per placed TIER (Σtiers × this) — TIER speeds the cadence
const BASE_CAP_UNITS := 4.0             # accrued-UNIT ceiling with a single spirit placed (the daily-return floor)
const CAP_UNITS_PER_SPIRIT := 1.0       # extra UNIT ceiling per ADDITIONAL placed spirit — the COUNT lever
const SELL_PER_TIER := 5                # coins returned when selling a placed spirit, per housed tier

# Hard caps on the rewards (the economy guards). PROVISIONAL — the economy pass tunes them.
const DIAMOND_DAILY_CAP := 3            # max diamonds COLLECTABLE from habitats per calendar day (the IAP guard)
const BOOST_CHARGE_CAP := 5            # max stockpiled generator-boost charges (map 3 stock ceiling)

# Per-map FIXED reward per matured unit (residents_spec Reward table; amount is TIER-INDEPENDENT). Each
# currency is hard-capped at the grant (see _grant). Map 5 (meadow) is special — it pays a resident CHEST.
const REWARD := {
	"farmhouse": {"currency": "coins",     "per_unit": 5},   # map 1
	"barn":      {"currency": "water",     "per_unit": 3},   # map 2 — clamped to WATER_CAP
	"pond":      {"currency": "boost",     "per_unit": 1},   # map 3 — a generator-boost charge, click to use
	"orchard":   {"currency": "diamonds",  "per_unit": 1},   # map 4 — DIAMOND_DAILY_CAP per day
	"meadow":    {"currency": "residents", "per_unit": 1},   # map 5 — a chest of chest_size() random spirits
}

# --- the in-hand holding area (unbounded) ----------------------------------------
static func hand() -> Array:
	return Save.grove().get("hand", [])

static func _set_hand(list: Array) -> void:
	Save.grove()["hand"] = list
	Save.grove_write()

## Acquire stub (stands in for Rush -> mystery boxes): drop one {kind, tier} into the hand.
## Returns the new hand size. tier is clamped to [1, MAX_TIER].
static func hand_add(kind: String, tier: int = 1) -> int:
	var list := hand()
	list.append({"kind": kind, "tier": clampi(tier, 1, MAX_TIER)})
	_set_hand(list)
	return list.size()

## Merge a same-kind + same-tier PAIR in the hand into one a tier up (the explicit drag-merge).
## Returns true iff a pair was consumed. No-op at MAX_TIER, or with fewer than 2 of the pair.
static func hand_merge(kind: String, tier: int) -> bool:
	if tier >= MAX_TIER:
		return false
	var list := hand()
	var idxs: Array = []
	for i in list.size():
		if String(list[i].kind) == kind and int(list[i].tier) == tier:
			idxs.append(i)
			if idxs.size() == 2:
				break
	if idxs.size() < 2:
		return false
	list.remove_at(idxs[1])   # remove the higher index first so the first removal doesn't shift it
	list.remove_at(idxs[0])
	list.append({"kind": kind, "tier": tier + 1})
	_set_hand(list)
	return true

# --- per-map placement & capacity -------------------------------------------------
static func cap(map_id: String) -> int:
	var override: Dictionary = Save.grove().get("hab_cap", {})
	if override.has(map_id):
		return int(override[map_id])                  # explicit per-map override (parked upgrades) wins
	# §1 EARLY POPULATION: the roster opens at the FIRST restored spot with 1 slot and RAMPS to DEFAULT_CAP
	# once every spot is restored (the shared content ramp; a full roster forces a merge or a sell to make room).
	var z := Content.map_for_id(map_id)
	if z < 0:
		return DEFAULT_CAP
	return Content.resident_capacity(z, Save.grove().get("unlocks", {}))

static func placed(map_id: String) -> Array:
	return Save.grove().get("habitat", {}).get(map_id, [])

static func _set_placed(map_id: String, list: Array) -> void:
	var g := Save.grove()
	if not g.has("habitat"):
		g["habitat"] = {}
	g["habitat"][map_id] = list
	Save.grove_write()

static func is_full(map_id: String) -> bool:
	return placed(map_id).size() >= cap(map_id)

## Place hand[index] onto map_id if it has a free slot. Settles that map's production at the OLD
## rate first so the rate change is clean, then moves the instance hand -> map.
static func place(map_id: String, index: int, now: float = -1.0) -> bool:
	var h := hand()
	if index < 0 or index >= h.size() or is_full(map_id):
		return false
	_settle(map_id, now)
	var inst: Dictionary = h[index]
	h.remove_at(index)
	_set_hand(h)
	var p := placed(map_id)
	p.append({"kind": String(inst.kind), "tier": int(inst.tier)})
	_set_placed(map_id, p)
	return true

## Sell placed[index] on map_id: settle production, free the slot, credit + return the coin value
## (SELL_PER_TIER * tier). Returns 0 on a bad index.
static func sell(map_id: String, index: int, now: float = -1.0) -> int:
	var p := placed(map_id)
	if index < 0 or index >= p.size():
		return 0
	_settle(map_id, now)
	var tier := int(p[index].tier)
	p.remove_at(index)
	_set_placed(map_id, p)
	var coins := SELL_PER_TIER * tier
	Save.add_coins(coins)
	return coins

## Move placed[index] from one map to another that has room. Settles BOTH maps' production.
## Returns true on success (false on a bad index or a full target).
static func move(from_id: String, index: int, to_id: String, now: float = -1.0) -> bool:
	var src := placed(from_id)
	if index < 0 or index >= src.size() or is_full(to_id):
		return false
	_settle(from_id, now)
	_settle(to_id, now)
	var inst: Dictionary = src[index]
	src.remove_at(index)
	_set_placed(from_id, src)
	var dst := placed(to_id)
	dst.append({"kind": String(inst.kind), "tier": int(inst.tier)})
	_set_placed(to_id, dst)
	return true

## Bring placed[index] back UP into the hand ("bring out"). Settles production at the old rate first,
## then moves the instance map -> hand (frees the slot, keeps the tier). Returns false on a bad index.
static func unplace(map_id: String, index: int, now: float = -1.0) -> bool:
	var p := placed(map_id)
	if index < 0 or index >= p.size():
		return false
	_settle(map_id, now)
	var inst: Dictionary = p[index]
	p.remove_at(index)
	_set_placed(map_id, p)
	var h := hand()
	h.append({"kind": String(inst.kind), "tier": int(inst.tier)})
	_set_hand(h)
	return true

## On-map merge (the drag-onto-a-match drop): consume hand[h_index] INTO placed[p_index] on map_id when
## they are the same kind + tier, bumping the placed spirit one tier up. Settles production first (the
## tier-sum, thus the rate, changes). Returns true iff merged; no-op on a mismatch, a bad index, or a
## placed spirit already at MAX_TIER.
static func place_merge(map_id: String, h_index: int, p_index: int, now: float = -1.0) -> bool:
	var h := hand()
	var p := placed(map_id)
	if h_index < 0 or h_index >= h.size() or p_index < 0 or p_index >= p.size():
		return false
	var a: Dictionary = h[h_index]
	var b: Dictionary = p[p_index]
	if String(a.kind) != String(b.kind) or int(a.tier) != int(b.tier):
		return false
	if int(b.tier) >= MAX_TIER:
		return false
	_settle(map_id, now)
	h.remove_at(h_index)
	_set_hand(h)
	p[p_index] = {"kind": String(b.kind), "tier": int(b.tier) + 1}
	_set_placed(map_id, p)
	return true

# --- idle production: TIER speeds the cadence, COUNT raises the cap, the per-unit AMOUNT is FIXED -----
## A map's production SPEED = sum of its placed spirits' tiers. Higher tier (and, naturally, more spirits)
## = a faster cadence; the per-unit reward AMOUNT stays fixed (see REWARD), which is what keeps water and
## diamonds bounded. (Kept named `rate` — every existing caller reads the tier-sum from here.)
static func rate(map_id: String) -> int:
	var r := 0
	for inst in placed(map_id):
		r += int(inst.tier)
	return r

static func _now() -> float:
	return Time.get_unix_time_from_system()

static func _prod(map_id: String) -> Dictionary:
	return Save.grove().get("hab_prod", {}).get(map_id, {"acc": 0.0, "last": -1.0})

## The accrued-UNIT ceiling. COUNT is the lever: one placed spirit caps at BASE_CAP_UNITS; each extra
## spirit adds CAP_UNITS_PER_SPIRIT. An EMPTY map produces nothing (cap 0 — the ≥1-spirit gate). Map 5
## (residents) banks at most ONE ready chest, keeping the free-resident faucet slow so Explore stays primary.
static func accrual_cap(map_id: String) -> float:
	if rate(map_id) <= 0:
		return 0.0
	if reward_currency(map_id) == "residents":
		return 1.0
	return BASE_CAP_UNITS + CAP_UNITS_PER_SPIRIT * float(placed(map_id).size() - 1)

## Production UNITS accrued and not yet collected, as of `now` (defaults to wall clock; tests pass an
## explicit `now`). Banked `acc` is kept whole; only the fresh flow since `last` is clamped on top of it,
## so a speed drop (sell/move-away) never erases already-earned units.
static func pending(map_id: String, now: float = -1.0) -> float:
	if now < 0.0:
		now = _now()
	var pr := _prod(map_id)
	var last := float(pr.get("last", -1.0))
	var acc := float(pr.get("acc", 0.0))
	if last < 0.0:
		last = now                                       # first observation: start the clock, no back-pay
	var hours := maxf(0.0, (now - last) / 3600.0)
	var flow := float(rate(map_id)) * UNITS_PER_HOUR_PER_TIER * hours
	var room := maxf(0.0, accrual_cap(map_id) - acc)
	return acc + minf(flow, room)

## Bank pending into stored `acc` and reset `last` = now. Called before any speed change (place/move/
## sell/unplace) and inside collect, so accrual is always integrated at the correct speed.
static func _settle(map_id: String, now: float = -1.0) -> void:
	if now < 0.0:
		now = _now()
	var banked := pending(map_id, now)
	var g := Save.grove()
	if not g.has("hab_prod"):
		g["hab_prod"] = {}
	g["hab_prod"][map_id] = {"acc": banked, "last": now}
	Save.grove_write()

# --- the per-map reward (residents_spec Reward table; all five maps wired) ------------------------
## The reward currency each map pays: coins / water / boost / diamonds / residents. "" for an unknown id.
static func reward_currency(map_id: String) -> String:
	return String(REWARD.get(map_id, {}).get("currency", ""))

## The FIXED reward amount per matured unit (tier-independent; the economy pass tunes it).
static func reward_per_unit(map_id: String) -> int:
	return int(REWARD.get(map_id, {}).get("per_unit", 0))

# --- generator-boost charges (map 3 / pond stock) -----------------------------------------------
## Stockpiled generator-boost charges minted by map 3. A charge arms the temporary boost for FREE (no
## coin cost) via use_boost_charge; the stock is capped at BOOST_CHARGE_CAP.
static func boost_charges() -> int:
	return int(Save.grove().get("boost_charges", 0))

static func _set_boost_charges(n: int) -> void:
	Save.grove()["boost_charges"] = clampi(n, 0, BOOST_CHARGE_CAP)
	Save.grove_write()

## Spend one stockpiled charge to arm the generator boost for free. Refuses (keeps the charge) when the
## stock is empty or a boost is already live (one boost at a time, mirroring content.try_activate_boost).
static func use_boost_charge() -> bool:
	if boost_charges() <= 0:
		return false
	if not Content.arm_boost_free():
		return false
	_set_boost_charges(boost_charges() - 1)
	return true

# --- diamond daily cap (map 4 / orchard — the IAP guard) ----------------------------------------
static func _day_index(now: float) -> int:
	return int(floor(now / 86400.0))

## Diamonds still collectable from habitats today (resets each calendar day).
static func diamond_daily_remaining(now: float = -1.0) -> int:
	if now < 0.0:
		now = _now()
	var g := Save.grove()
	var spent := int(g.get("hab_dia_count", 0)) if int(g.get("hab_dia_day", -1)) == _day_index(now) else 0
	return maxi(0, DIAMOND_DAILY_CAP - spent)

static func _spend_diamond_allowance(now: float, n: int) -> void:
	var g := Save.grove()
	if int(g.get("hab_dia_day", -1)) != _day_index(now):
		g["hab_dia_day"] = _day_index(now)
		g["hab_dia_count"] = 0
	g["hab_dia_count"] = int(g.get("hab_dia_count", 0)) + n
	Save.grove_write()

# --- map 5 resident chest ------------------------------------------------------------------------
## The chest size map 5 yields, set by the placed COUNT (more spirits = a better chest): 1 / 4 / 8.
static func chest_size(map_id: String) -> int:
	var n := placed(map_id).size()
	if n >= 8:
		return 8
	if n >= 4:
		return 4
	if n >= 1:
		return 1
	return 0

## The kinds map 5 may roll: the union of every populatable map's offered residents (mirrors the box pool).
static func _resident_pool() -> Array:
	var unlocks: Dictionary = Save.grove().get("unlocks", {})
	var kinds := {}
	for z in Content.MAPS.size():
		if Content.map_spots_restored(z, unlocks) >= 1:
			for ln in Content.resident_lines(z):
				kinds[String(ln.id)] = true
	return kinds.keys()

# A shared loot rng for chest grants — NOT the board's seeded+persisted rng (chest loot is cosmetic and
# never replayed, so a fresh randomized stream is fine).
static var _loot_rng: RandomNumberGenerator = null

static func _rng() -> RandomNumberGenerator:
	if _loot_rng == null:
		_loot_rng = RandomNumberGenerator.new()
		_loot_rng.randomize()
	return _loot_rng

## The SHARED chest grant for BOTH the map-5 habitat chest and the rush Trade boxes (they are one system).
## Drops `count` spirits into the hand; each rolls a KIND from the unlocked pool and a TIER off the
## generator's OWN curve (BoardLogic.roll_tier → TIER_ODDS: t1-heavy, capped at t4 — higher tiers still only
## via in-hand merges). Returns the granted {kind, tier} instances (for the reveal). Empty if the pool is empty.
static func grant_chest(count: int) -> Array:
	var pool := _resident_pool()
	if pool.is_empty():
		return []
	var rng := _rng()
	var out: Array = []
	for _i in maxi(0, count):
		var kind := String(pool[rng.randi() % pool.size()])
		var tier := BoardLogic.roll_tier(rng)
		hand_add(kind, tier)
		out.append({"kind": kind, "tier": tier})
	return out

# --- grant + collect -----------------------------------------------------------------------------
## Grant `amount` of `currency`, applying each currency's HARD CAP. Returns what was ACTUALLY granted
## (after clamping). `now` drives the diamond daily window. Residents are handled in collect, not here.
static func _grant(currency: String, amount: int, now: float) -> int:
	match currency:
		"coins":
			Save.add_coins(amount)
			return amount
		"water":
			var before := Save.water()
			Save.add_water(amount)                       # add_water clamps to WATER_CAP
			return Save.water() - before
		"diamonds":
			var give := mini(amount, diamond_daily_remaining(now))
			if give > 0:
				Save.add_diamonds(give)
				_spend_diamond_allowance(now, give)
			return give
		"boost":
			var was := boost_charges()
			_set_boost_charges(was + amount)             # clamps to BOOST_CHARGE_CAP
			return boost_charges() - was
		_:
			return 0

## Collect a map's matured production into its reward. Floors pending to whole UNITS, banks the fractional
## remainder, resets the clock. Currency maps grant floor(units) × per_unit (each hard-capped). Map 5 yields
## ONE resident chest of chest_size() random spirits when a unit is ready. Returns {currency, amount[, chest]}.
static func collect(map_id: String, now: float = -1.0) -> Dictionary:
	if now < 0.0:
		now = _now()
	var cur := reward_currency(map_id)
	if cur == "":
		return {"currency": "", "amount": 0}
	var p := pending(map_id, now)
	var whole := int(floor(p))
	var g := Save.grove()
	if not g.has("hab_prod"):
		g["hab_prod"] = {}
	g["hab_prod"][map_id] = {"acc": p - float(whole), "last": now}
	Save.grove_write()
	if cur == "residents":
		# map 5: a matured unit = a ready CHEST; collecting grants a chest_size() chest via the SHARED grant.
		if whole < 1:
			return {"currency": "residents", "amount": 0, "chest": 0}
		var size := chest_size(map_id)
		var granted := grant_chest(size)
		return {"currency": "residents", "amount": granted.size(), "chest": size}
	if whole <= 0:
		return {"currency": cur, "amount": 0}
	var granted := _grant(cur, whole * reward_per_unit(map_id), now)
	return {"currency": cur, "amount": granted}
