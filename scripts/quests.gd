extends RefCounted
## Tidy Up — M8 quests: ONE session micro-chip per board, the merged Daily bundle,
## and silent milestone counters. Quests are pure GRAVY — board-clear stays the only
## win, nothing here ever gates — and they respect the meta surface budget: one chip
## on the board, one Today line on the Jobs map.
##   const Quests = preload("res://scripts/quests.gd")

const Save = preload("res://scripts/save.gd")

const SESSION_REWARD := 5
const DAILY_REWARD := 50
const DAILY_TARGETS := {"jobs": 3, "merges": 30, "coins": 100}

# --- the one session chip ------------------------------------------------------
# Picked from what the board actually contains — friction-flavored when possible,
# a merge count otherwise. State is per-board; start_session resets it.

static var kind := ""          # merge | drawer | cover | tangle | shelf | floor
static var need := 0
static var have := 0
static var rewarded := false
static var _paid_key := ""     # "q_<level id>" — the chip pays once per board per DAY,
                               # so restart-looping a quick board can't farm the reward

static func start_session(lv: Dictionary) -> void:
	rewarded = false
	have = 0
	_paid_key = "q_" + String(lv.get("id", ""))
	if not lv.get("drawers", {}).is_empty():
		kind = "drawer"
		need = lv.get("drawers", {}).size()
	elif not lv.get("covers", []).is_empty():
		kind = "cover"
		need = lv.get("covers", []).size()
	elif not lv.get("tangles", {}).is_empty():
		kind = "tangle"
		need = lv.get("tangles", {}).size()
	elif not lv.get("floor", []).is_empty():
		kind = "floor"
		need = 1
	elif not lv.get("shelf", []).is_empty():
		kind = "shelf"
		need = lv.get("shelf", []).size()
	else:
		kind = "merge"
		var pieces := 0
		for c in lv.get("grid", []):
			if int(c) > 0:
				pieces += 1
		need = maxi(1, pieces / 2)   # ≈ the board's tier-1 merge count (always achievable)

## Feed a game event ("merge"/"drawer"/"cover"/"tangle"/"shelf"/"floor"/"clear"/"coins").
## Accrues the silent milestone counters + the Daily bundle, progresses the session
## chip, and returns true EXACTLY once: when the chip completes (the reward is paid
## here; the caller owns the celebration).
static func on_event(ev: String, n: int = 1) -> bool:
	Save.bump_stat(ev, n)                # silent milestones (the v2 Collections data)
	match ev:                            # the Daily bundle's three counters
		"merge": Save.bump_daily("merges", n)
		"clear": Save.bump_daily("jobs", 1)
		"coins": Save.bump_daily("coins", n)
	if rewarded or ev != kind:
		return false
	have = mini(need, have + n)
	if have < need:
		return false
	rewarded = true
	var d := Save.daily()
	if d.has(_paid_key):
		return false               # chip flips to ✓ but a restarted board pays nothing
	d[_paid_key] = true            # persisted with the coin write below
	Save.add_coins(SESSION_REWARD)
	return true

# --- the Daily bundle ------------------------------------------------------------

static func daily_complete() -> bool:
	var d := Save.daily()
	for k in DAILY_TARGETS:
		if int(d.get(k, 0)) < int(DAILY_TARGETS[k]):
			return false
	return true

## Pays the bundle exactly once per day, once its three counters are met.
static func try_claim_daily() -> bool:
	if not daily_complete():
		return false
	return Save.claim_daily(DAILY_REWARD)
