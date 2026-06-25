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
const D = Game.DATA

const DEFAULT_CAP := 8                      # starting slots per habitat (per-map upgrades: parked)
const MAX_TIER: int = D.RESIDENT_MAX_TIER   # reuse the existing cascade cap (3) as the v1 tier band

# PROVISIONAL feel dials — the slice plays with these; final values come from the parked grove_sim pass.
const YIELD_PER_HOUR := 6.0                 # reward units per hour a TIER-1 spirit yields (rate scales with tier)
const ACCRUAL_HOURS := 8.0                  # idle accrual ceiling, in hours of current output (daily-return cap)
const SELL_PER_TIER := 5                    # coins returned when selling a placed spirit, per housed tier

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
	list.remove_at(idxs[1])
	list.remove_at(idxs[0])
	list.append({"kind": kind, "tier": tier + 1})
	_set_hand(list)
	return true

# --- per-map placement & capacity -------------------------------------------------
static func cap(map_id: String) -> int:
	return int(Save.grove().get("hab_cap", {}).get(map_id, DEFAULT_CAP))

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
## rate first (Task 3) so the rate change is clean, then moves the instance hand -> map.
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

## Pick a placed spirit back UP into the hand (the other capacity door, for re-merging). Settles
## production first. Returns true on success.
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

# --- idle production ---------------------------------------------------------------
## A map's production RATE = sum of its placed spirits' tiers (v1 tier-only yield).
static func rate(map_id: String) -> int:
	var r := 0
	for inst in placed(map_id):
		r += int(inst.tier)
	return r

static func _now() -> float:
	return Time.get_unix_time_from_system()

static func _prod(map_id: String) -> Dictionary:
	return Save.grove().get("hab_prod", {}).get(map_id, {"acc": 0.0, "last": -1.0})

## The fresh-flow ceiling (units) = ACCRUAL_HOURS of the CURRENT rate's output.
static func accrual_cap(map_id: String) -> float:
	return float(rate(map_id)) * YIELD_PER_HOUR * ACCRUAL_HOURS

## Units accrued and not yet collected, as of `now` (defaults to wall clock; tests pass an explicit
## `now`). Banked `acc` is kept whole; only the fresh flow since `last` is clamped on top of it, so a
## rate drop (sell/move-away) never erases already-earned units.
static func pending(map_id: String, now: float = -1.0) -> float:
	if now < 0.0:
		now = _now()
	var pr := _prod(map_id)
	var last := float(pr.get("last", -1.0))
	var acc := float(pr.get("acc", 0.0))
	if last < 0.0:
		last = now
	var hours := maxf(0.0, (now - last) / 3600.0)
	var flow := float(rate(map_id)) * YIELD_PER_HOUR * hours
	var room := maxf(0.0, accrual_cap(map_id) - acc)
	return acc + minf(flow, room)

## Bank pending into stored `acc` and reset `last` = now. Called before any rate change (place/move/
## sell/unplace) and inside collect, so accrual is always integrated at the correct rate.
static func _settle(map_id: String, now: float = -1.0) -> void:
	if now < 0.0:
		now = _now()
	var banked := pending(map_id, now)
	var g := Save.grove()
	if not g.has("hab_prod"):
		g["hab_prod"] = {}
	g["hab_prod"][map_id] = {"acc": banked, "last": now}
	Save.grove_write()

## The reward currency each map pays (residents_spec Reward table). v1 wires ONLY map 1 (farmhouse ->
## coins). Maps 2-5 are PARKED on the Economy pass (water reopens I2; diamonds reopen the IAP economy;
## maps 3/5 are net-new content), so they return "" and pay nothing — they accrue, and light up with a
## one-line change here once their reward is decided.
static func reward_currency(map_id: String) -> String:
	match map_id:
		"farmhouse": return "coins"
		_: return ""

static func _grant(currency: String, amount: int) -> void:
	match currency:
		"coins":
			Save.add_coins(amount)
		# "water"/"diamonds" intentionally NOT wired in v1 — parked (I2 / IAP economy).
		# Do not add here without the Economy pass; doing so reopens a base invariant.
		_:
			pass

## Collect a map's accrued production into its reward currency: grant floor(pending), keep the
## fractional remainder, reset the clock. Returns {currency, amount} (amount 0 when nothing accrued
## or the map's reward is parked).
static func collect(map_id: String, now: float = -1.0) -> Dictionary:
	if now < 0.0:
		now = _now()
	var p := pending(map_id, now)
	var whole := int(floor(p))
	var g := Save.grove()
	if not g.has("hab_prod"):
		g["hab_prod"] = {}
	g["hab_prod"][map_id] = {"acc": p - float(whole), "last": now}
	Save.grove_write()
	var cur := reward_currency(map_id)
	if whole > 0:
		_grant(cur, whole)
	return {"currency": cur, "amount": (whole if cur != "" else 0)}
