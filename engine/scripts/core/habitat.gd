extends RefCounted
## Residents HABITAT model — the payback half of the residents expansion (v1 slice).
## Pure logic over the persisted `grove` blob, mirroring content.gd's boost_taps pattern
## (reads/writes Save.grove() directly; no save.gd change, no schema bump, no migration —
## new keys default-on-read). v1 RARITY IS PARKED: a spirit is {kind, tier}; merge is
## same kind + same tier; production scales with Σtier (speed AND cap) × a per-map MULT. The Rush/boxes (acquisition) is a
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
# The production model: a map matures CURRENCY at speed = UNITS_PER_HOUR_PER_TIER × Σtier × MULT, banked up to a
# cap = (3 + Σtier) × MULT (Σtier = sum of placed tiers). BOTH tier and count feed Σtier, so each raises speed AND
# cap; the per-map MULT scales the whole stream into that map's currency. Overflow past the cap is dropped.
const UNITS_PER_HOUR_PER_TIER := 0.25   # base production/HOUR per point of Σtier (before the per-map MULT)
const BASE_CAP_UNITS := 4.0             # cap (in base units) at Σtier = 1
const CAP_UNITS_PER_TIER := 1.0         # +base-unit cap per point of Σtier above 1 (so cap = 3 + Σtier)
const SELL_PER_TIER := 5                # coins returned when selling a placed spirit, per housed tier

# Per-map reward: the currency each map pays and the plain MULT that scales the base stream into it. The MULT
# REPLACES the old per-unit value + the hard caps (a small fraction throttles a premium currency in place of a
# clamp). Ladder [5, 1, 0.2, 0.1, 0.2]. Map 5 (meadow) pays residents via the SHARED rush grant (grant_chest).
const REWARD := {
	"farmhouse": {"currency": "coins",     "mult": 5.0},    # map 1
	"barn":      {"currency": "water",     "mult": 1.0},    # map 2 — Save.add_water still clamps the TOTAL to WATER_CAP
	"pond":      {"currency": "boost",     "mult": 0.2},    # map 3 — a generator-boost charge, click to use
	"orchard":   {"currency": "diamonds",  "mult": 0.1},    # map 4
	"meadow":    {"currency": "residents", "mult": 0.2},    # map 5 — floor(pending) residents, rolled like the rush
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
## When a drop target is supplied, the upgraded spirit replaces that target side of the pair instead of
## being appended. Returns true iff a pair was consumed. No-op at MAX_TIER, or with fewer than 2 of the pair.
static func hand_merge(kind: String, tier: int, target_index: int = -1, source_index: int = -1) -> bool:
	if tier >= MAX_TIER:
		return false
	var list := hand()
	var keep_idx := -1
	var remove_idx := -1
	if target_index >= 0 and target_index < list.size():
		var target: Dictionary = list[target_index]
		if String(target.kind) == kind and int(target.tier) == tier:
			keep_idx = target_index
			if source_index >= 0 and source_index < list.size() and source_index != keep_idx:
				var source: Dictionary = list[source_index]
				if String(source.kind) == kind and int(source.tier) == tier:
					remove_idx = source_index
			if remove_idx < 0:
				for i in list.size():
					if i == keep_idx:
						continue
					if String(list[i].kind) == kind and int(list[i].tier) == tier:
						remove_idx = i
						break
	if keep_idx < 0:
		var idxs: Array = []
		for i in list.size():
			if String(list[i].kind) == kind and int(list[i].tier) == tier:
				idxs.append(i)
				if idxs.size() == 2:
					break
		if idxs.size() < 2:
			return false
		keep_idx = int(idxs[0])
		remove_idx = int(idxs[1])
	if remove_idx < 0:
		return false
	list[keep_idx] = {"kind": kind, "tier": tier + 1}
	list.remove_at(remove_idx)
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

## True when `inst` belongs on `map_id`. Unknown resident kinds cannot be newly placed.
static func can_place_on(map_id: String, inst: Dictionary) -> bool:
	var kind := String(inst.get("kind", ""))
	if kind == "":
		return false
	return Content.resident_home_map_id(kind) == map_id

## Place hand[index] onto map_id if it has a free slot. Settles that map's production at the OLD
## rate first so the rate change is clean, then moves the instance hand -> map.
static func place(map_id: String, index: int, now: float = -1.0) -> bool:
	var h := hand()
	if index < 0 or index >= h.size() or is_full(map_id):
		return false
	var inst: Dictionary = h[index]
	if not can_place_on(map_id, inst):
		return false
	_settle(map_id, now)
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

## Sell hand[index] (an in-hand spirit) for the SAME coin value as a placed one (SELL_PER_TIER * tier):
## drop it from the hand, credit + return the coins. Returns 0 on a bad index.
static func sell_hand(index: int) -> int:
	var h := hand()
	if index < 0 or index >= h.size():
		return 0
	var tier := int(h[index].tier)
	h.remove_at(index)
	_set_hand(h)
	var coins := SELL_PER_TIER * tier
	Save.add_coins(coins)
	return coins

## Move placed[index] from one map to another that has room. Settles BOTH maps' production.
## Returns true on success (false on a bad index or a full target).
static func move(from_id: String, index: int, to_id: String, now: float = -1.0) -> bool:
	var src := placed(from_id)
	if index < 0 or index >= src.size() or is_full(to_id):
		return false
	var inst: Dictionary = src[index]
	if not can_place_on(to_id, inst):
		return false
	_settle(from_id, now)
	_settle(to_id, now)
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
	if not can_place_on(map_id, a):
		return false
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

# --- idle production: Σtier drives BOTH speed and cap; the per-map MULT scales it into currency ---------
## A map's Σtier = the sum of its placed spirits' tiers — the single production driver. Both higher tier and
## more spirits raise it, so each raises speed (units/hr) AND the cap. (Kept named `rate` — every existing
## caller reads the tier-sum from here.)
static func rate(map_id: String) -> int:
	var r := 0
	for inst in placed(map_id):
		r += int(inst.tier)
	return r

static func _now() -> float:
	return Time.get_unix_time_from_system()

static func _prod(map_id: String) -> Dictionary:
	return Save.grove().get("hab_prod", {}).get(map_id, {"acc": 0.0, "last": -1.0})

## The accrual ceiling, in the map's CURRENCY: cap = (3 + Σtier) × MULT. An EMPTY map produces nothing
## (Σtier 0 → cap 0, the ≥1-spirit gate). Overflow past this is dropped on accrual (no deferral).
static func accrual_cap(map_id: String) -> float:
	return _cap_units(rate(map_id)) * reward_mult(map_id)

## Base-unit ceiling for a given Σtier (before the per-map MULT): 0 when empty, else 3 + Σtier.
static func _cap_units(stier: int) -> float:
	if stier <= 0:
		return 0.0
	return BASE_CAP_UNITS + CAP_UNITS_PER_TIER * float(stier - 1)

## Production accrued and not yet collected, IN THE MAP'S CURRENCY (MULT baked in), as of `now` (defaults to
## wall clock; tests pass an explicit `now`). Banked `acc` is kept; only the fresh flow since `last` is clamped
## on top of it, so a speed drop (sell/move-away) never erases already-earned production.
static func pending(map_id: String, now: float = -1.0) -> float:
	if now < 0.0:
		now = _now()
	var pr := _prod(map_id)
	var last := float(pr.get("last", -1.0))
	var acc := float(pr.get("acc", 0.0))
	if last < 0.0:
		last = now                                       # first observation: start the clock, no back-pay
	var hours := maxf(0.0, (now - last) / 3600.0)
	var flow := float(rate(map_id)) * UNITS_PER_HOUR_PER_TIER * reward_mult(map_id) * hours
	var room := maxf(0.0, accrual_cap(map_id) - acc)
	return acc + minf(flow, room)

## Seconds until `pending / accrual_cap` reaches the cap shown by the map-card collection bar.
## Returns -1 when the map has no meaningful timer yet (no cap or no production speed).
static func seconds_until_full(map_id: String, now: float = -1.0) -> float:
	if now < 0.0:
		now = _now()
	var capf := accrual_cap(map_id)
	var speed_per_second := float(rate(map_id)) * UNITS_PER_HOUR_PER_TIER * reward_mult(map_id) / 3600.0
	if capf <= 0.0 or speed_per_second <= 0.0:
		return -1.0
	var remaining := capf - pending(map_id, now)
	if remaining <= 0.0:
		return 0.0
	return remaining / speed_per_second

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

## The per-map MULT that scales the base production stream into the map's currency (REWARD ladder).
static func reward_mult(map_id: String) -> float:
	return float(REWARD.get(map_id, {}).get("mult", 0.0))

# --- generator-boost charges (map 3 / pond stock) -----------------------------------------------
## Stockpiled generator-boost charges minted by map 3. A charge arms the temporary boost for FREE (no
## coin cost) via use_boost_charge. No stock ceiling — the small map-3 MULT throttles the mint instead.
static func boost_charges() -> int:
	return int(Save.grove().get("boost_charges", 0))

static func _set_boost_charges(n: int) -> void:
	Save.grove()["boost_charges"] = maxi(0, n)
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

# --- map 5 resident grant (the SHARED rush pool) -------------------------------------------------

## Weighted resident reward entries for Rush and resident-producing map rewards.
static func resident_reward_pool(source_map_id: String = "") -> Array:
	var unlocks: Dictionary = Save.grove().get("unlocks", {})
	var out: Array = []
	for z in Content.MAPS.size():
		if Content.map_spots_restored(z, unlocks) < 1:
			continue
		var map_id := String(Content.MAPS[z].id)
		for ln in Content.resident_lines(z):
			var kind := String(ln.get("id", ""))
			if kind == "":
				continue
			out.append({"kind": kind, "map_id": map_id, "weight": 3 if map_id == source_map_id else 1})
	return out

static func roll_reward_kind(source_map_id: String, rng: RandomNumberGenerator) -> String:
	var pool := resident_reward_pool(source_map_id)
	var total := 0
	for entry in pool:
		total += maxi(0, int(entry.get("weight", 0)))
	if total <= 0:
		return ""
	var pick := rng.randi_range(1, total)
	var acc := 0
	for entry in pool:
		acc += maxi(0, int(entry.get("weight", 0)))
		if pick <= acc:
			return String(entry.get("kind", ""))
	return ""

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
static func grant_chest(count: int, source_map_id: String = "") -> Array:
	var rng := _rng()
	var out: Array = []
	for _i in maxi(0, count):
		var kind := roll_reward_kind(source_map_id, rng)
		if kind == "":
			return out
		var tier := BoardLogic.roll_tier(rng)
		hand_add(kind, tier)
		out.append({"kind": kind, "tier": tier})
	return out

# --- grant + collect -----------------------------------------------------------------------------
## Grant `amount` (already whole CURRENCY) of `currency`. Returns what was ACTUALLY credited (water clamps to
## the WATER_CAP headroom; the rest credit in full — no per-currency caps). Residents are handled in collect.
static func _grant(currency: String, amount: int) -> int:
	match currency:
		"coins":
			Save.add_coins(amount)
			return amount
		"water":
			var before := Save.water()
			Save.add_water(amount)                       # add_water clamps the TOTAL to WATER_CAP
			return Save.water() - before
		"diamonds":
			Save.add_diamonds(amount)
			return amount
		"boost":
			var was := boost_charges()
			_set_boost_charges(was + amount)
			return boost_charges() - was
		_:
			return 0

## Collect a map's matured production. `pending` is already in the map's CURRENCY (MULT baked in): floor it to
## whole currency, bank the sub-one-unit remainder, reset the clock, and credit it. Map 5 mints floor(pending)
## residents via the SHARED rush grant (grant_chest — kind from the pool, tier off the generator curve).
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
		var granted := grant_chest(whole, map_id)       # grant_chest(0) is a harmless no-op below the threshold
		return {"currency": "residents", "amount": granted.size()}
	if whole <= 0:
		return {"currency": cur, "amount": 0}
	return {"currency": cur, "amount": _grant(cur, whole)}
