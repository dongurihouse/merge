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
