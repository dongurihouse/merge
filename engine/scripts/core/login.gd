extends RefCounted
## THE DAILY LOGIN CALENDAR — the forgiving streak (Core §18). A gentle ESCALATING
## reward ladder for consecutive days played, with bigger MILESTONES (day 7 / 30). It
## drives RETURN, not a self-sustaining faucet: rewards obey the §4/§10 discipline —
## energy (water) stays modest (under the "sessions extend, never self-sustain"
## invariant), milestones lean cosmetic / premium. Pairs with the piggy bank (§10):
## both reward the daily open.
##
## FORGIVING (locked, §18): a missed day NEVER resets the streak to day 1 — it soft-
## decays one step. That rule lives in Save.daily() (the rollover); this module READS
## the resolved streak and maps it to the ladder, so the decay is single-sourced.
##
## PURE engine (core/ layer — no ui/, no scenes/): the ladder MATH + the claim live
## here; the streak/claim state persists via Save.daily()/claim_daily(); the OWNER-
## TUNABLE ladder + milestones live in the active game's data (games/grove/grove_data.gd
## · LOGIN_*). The diegetic calendar popup is ui/login.gd.
##
## A reward is a small dict — any of {coins, water, gems, cosmetic} — so one ladder can
## mix soft currency, modest energy, and a premium/cosmetic capstone. The repeating WEEK
## ladder (LOGIN_LADDER, 7 entries) gives the day-in-week reward; LOGIN_MILESTONES keys
## ABSOLUTE streak days (7, 30, …) and OVERRIDES the week slot when the streak lands on one.

const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const D = Game.DATA                                  # the active game's data (§18 LOGIN_*)

# --- streak + "what day am I on" ----------------------------------------------------

## The resolved streak: how many consecutive days have been CLAIMED (forgiving — a gap
## soft-decays it, never to 0 mid-run). Read straight off the daily rollover.
static func streak() -> int:
	return int(Save.daily().get("streak", 0))

## Whether today's reward has already been claimed.
static func claimed_today() -> bool:
	return bool(Save.daily().get("claimed", false))

## The ladder day the player would claim NEXT (the streak counts claimed days, so the
## next claim advances to streak+1). This is the "today's reward" rung on the calendar.
static func today_day() -> int:
	return streak() + 1

# --- the ladder + milestones (owner-tunable in grove_data) --------------------------

## The reward dict for absolute streak `day` (>= 1). A milestone day overrides the
## repeating week slot; otherwise it's the week ladder indexed by (day-1) mod 7.
static func reward_for(day: int) -> Dictionary:
	if day < 1:
		return {}
	var ms: Dictionary = D.LOGIN_MILESTONES
	if ms.has(day):
		return ms[day]
	var ladder: Array = D.LOGIN_LADDER
	if ladder.is_empty():
		return {}
	return ladder[(day - 1) % ladder.size()]

## Today's claimable reward (the rung at today_day()).
static func today_reward() -> Dictionary:
	return reward_for(today_day())

## Whether absolute streak `day` is a milestone (a bigger, premium/cosmetic payout).
static func is_milestone(day: int) -> bool:
	return (D.LOGIN_MILESTONES as Dictionary).has(day)

# --- the claim ----------------------------------------------------------------------

## Grant today's reward (once per day) and bump the streak. Refuses a second claim the
## same day (returns false, grants nothing). Mirrors Save.claim_daily but pays the full
## REWARD DICT (coins / water / gems / cosmetic), not just a flat coin number. The claim
## + streak-bump persist in one write (via Save). Returns whether a reward was granted.
static func claim_today() -> bool:
	var d := Save.daily()
	if bool(d.get("claimed", false)):
		return false
	var rew := today_reward()                # the rung for streak+1 (today's day)
	d["claimed"] = true
	d["streak"] = int(d.get("streak", 0)) + 1
	_grant(rew)                              # pays coins/water/gems/cosmetic, then persists
	return true

# Pay out a reward dict. Coins/gems go to the wallet; water tops up the grove can (capped,
# never over the cap). Each grant persists via Save.
static func _grant(rew: Dictionary) -> void:
	if int(rew.get("coins", 0)) > 0:
		Save.add_coins(int(rew.coins))       # persists
	if int(rew.get("gems", 0)) > 0:
		Save.add_diamonds(int(rew.gems))     # persists
	if int(rew.get("water", 0)) > 0:
		_grant_water(int(rew.water))
	Save.grove_write()                       # one final flush for the in-grove grants

# Water lives in the grove blob, capped at WATER_CAP (a modest top-up, never self-sustaining).
static func _grant_water(n: int) -> void:
	var g := Save.grove()
	g["water"] = mini(int(D.WATER_CAP), int(g.get("water", 0)) + n)

# --- faucet-discipline + test helpers ----------------------------------------------

## The largest single-day water gift the ladder is ALLOWED to pay (the §4/§10 self-sustain
## guard — the calendar tops up, it never refills). Owner-tunable; asserted by the tests.
static func water_safe_max() -> int:
	return int(D.LOGIN_WATER_SAFE_MAX)

## A single comparable scalar for a day's reward VALUE, used to assert the ladder escalates
## (coins + water + a premium weight for gems/cosmetic). Tuning/test aid — not game-facing.
static func day_value(day: int) -> int:
	var r := reward_for(day)
	return int(r.get("coins", 0)) \
		+ int(r.get("water", 0)) * 10 \
		+ int(r.get("gems", 0)) * 100 \
		+ (200 if String(r.get("cosmetic", "")) != "" else 0)
