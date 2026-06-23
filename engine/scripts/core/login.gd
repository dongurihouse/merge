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
## here; the streak/claim state persists via Save.daily(); the OWNER-TUNABLE ladder +
## milestones + mystery pools are DATA — `res://games/<active>/login_rewards.json` (read
## lazily below, mirroring core/strings.gd), so rewards re-tune without a code edit. The
## diegetic calendar popup is ui/login.gd; the spin-reveal dialog is ui/login_mystery.gd.
##
## A reward is a small dict — any of {coins, water, gems, cosmetic} — so one ladder can
## mix soft currency, modest energy, and a premium/cosmetic capstone. The repeating WEEK
## ladder (`ladder`, 7 entries) gives the day-in-week reward; `milestones` keys ABSOLUTE
## streak days (7, 30, …) and OVERRIDES the week slot when the streak lands on one. (JSON
## object keys are strings, so milestone/mystery-slot lookups go through str(day/slot).)

const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const D = Game.DATA                                  # the active game's data (WATER_CAP for the water grant)

# --- the reward config (data-tunable JSON, lazy-loaded + cached) ---------------------
# Mirrors core/strings.gd: one structured JSON per game, resolved off Game.active(), loaded
# once and cached. A missing/malformed file warns and yields empty tables (every accessor
# degrades to "no reward") instead of crashing. _reset() drops the cache for tests.

static var _cfg: Dictionary = {}
static var _cfg_loaded := false

## The active game's login-reward config path (mirrors Game.art / strings resolution).
static func _config_path() -> String:
	return "res://games/%s/login_rewards.json" % Game.active()

## The parsed reward config ({ladder, milestones, mystery, water_safe_max}), loaded once.
static func _config() -> Dictionary:
	if _cfg_loaded:
		return _cfg
	_cfg_loaded = true
	var p := _config_path()
	if not FileAccess.file_exists(p):
		push_warning("Login: no reward config at %s — the calendar pays nothing" % p)
		return _cfg
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if parsed is Dictionary:
		_cfg = parsed
	else:
		push_warning("Login: %s is not a JSON object" % p)
	return _cfg

## Test hook: drop the cache so a suite that points the active game elsewhere re-reads.
static func _reset() -> void:
	_cfg_loaded = false
	_cfg = {}

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
	var ms: Dictionary = _config().get("milestones", {})
	if ms.has(str(day)):                             # JSON keys are strings
		return ms[str(day)]
	var ladder: Array = _config().get("ladder", [])
	if ladder.is_empty():
		return {}
	return ladder[(day - 1) % ladder.size()]

## Today's claimable reward (the rung at today_day()).
static func today_reward() -> Dictionary:
	return reward_for(today_day())

## Whether absolute streak `day` is a milestone (a bigger, premium/cosmetic payout).
static func is_milestone(day: int) -> bool:
	return (_config().get("milestones", {}) as Dictionary).has(str(day))

# --- mystery gift days (§18 · T46) --------------------------------------------------
# Slots 4 and 7 of the repeating week are MYSTERY days: instead of a fixed grant the calendar
# opens an AUTO-SPIN reveal that draws `show` DISTINCT rewards from a pool and lands on `win`
# of them. The roll is pure (no grant); claim_mystery() pays the winners + bumps the streak.

## The 1-based slot a day falls on within the repeating week — (((day-1) % 7) + 1).
static func slot_of(day: int) -> int:
	return ((day - 1) % 7) + 1

## Whether `day` is a mystery day (its weekly slot has a mystery pool). Recurs every week.
static func is_mystery(day: int) -> bool:
	if day < 1:
		return false
	return (_config().get("mystery", {}) as Dictionary).has(str(slot_of(day)))   # JSON keys are strings

## The reward pool for a weekly slot (empty if the slot is not a mystery slot). Tuning/test aid.
static func mystery_pool(slot: int) -> Array:
	return mystery_config(slot).get("pool", [])

## A weekly slot's full mystery spec ({show, win, pool}), or {} if the slot is not a mystery slot.
## Read-only tuning/preview aid — the workbench builds a deterministic demo roll from it.
static func mystery_config(slot: int) -> Dictionary:
	return (_config().get("mystery", {}) as Dictionary).get(str(slot), {})

## Roll a mystery day's reveal: draw `show` DISTINCT rewards from the slot's pool, then pick
## `win` winners uniformly. Returns {show, win, options:[reward…], winners:[idx…]}. Grants
## NOTHING (pure). The UI animates the spin landing on `winners`; claim_mystery() pays them.
static func roll_mystery(day: int) -> Dictionary:
	var slot := slot_of(day)
	var cfg: Dictionary = (_config().get("mystery", {}) as Dictionary).get(str(slot), {})
	var pool: Array = cfg.get("pool", [])
	var show := mini(int(cfg.get("show", 0)), pool.size())
	var win := mini(int(cfg.get("win", 0)), show)
	# distinct options: shuffle the pool's indices, take the first `show`.
	var pool_idx: Array = range(pool.size())
	pool_idx.shuffle()
	var options: Array = []
	for i in range(show):
		options.append(pool[pool_idx[i]])
	# winners: shuffle the shown positions, take the first `win` (sorted for a stable display).
	var pos: Array = range(show)
	pos.shuffle()
	var winners: Array = []
	for i in range(win):
		winners.append(pos[i])
	winners.sort()
	return {"show": show, "win": win, "options": options, "winners": winners}

## The reward dicts a roll landed on (the `options` at the winner indices).
static func won_rewards(roll: Dictionary) -> Array:
	var options: Array = roll.get("options", [])
	var out: Array = []
	for i in roll.get("winners", []):
		out.append(options[int(i)])
	return out

## Grant a mystery day's WON rewards (once per day) and bump the streak. The single grant path
## for mystery days — both claim_today() and the spin dialog land here. Refuses a second claim.
static func claim_mystery(won: Array) -> bool:
	var d := Save.daily()
	if bool(d.get("claimed", false)):
		return false
	d["claimed"] = true
	d["streak"] = int(d.get("streak", 0)) + 1
	for rew in won:
		_grant(rew)                          # each grant persists (save_now writes data["daily"] too)
	Save.save_now()                          # persist the claim/streak bump even if `won` paid no currency
	return true

# --- the claim ----------------------------------------------------------------------

## Grant today's reward (once per day) and bump the streak. Refuses a second claim the
## same day (returns false, grants nothing). Pays the full REWARD DICT
## (coins / water / gems / cosmetic), not just a flat coin number. The claim
## + streak-bump persist in one write (via Save). Returns whether a reward was granted.
## A MYSTERY day (slot 4/7) resolves to its won rewards — the spin dialog drives the UI,
## but headless callers (and tests) auto-resolve through the same claim_mystery() path.
static func claim_today() -> bool:
	var d := Save.daily()
	if bool(d.get("claimed", false)):
		return false
	var day := today_day()
	if is_mystery(day):
		return claim_mystery(won_rewards(roll_mystery(day)))
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
	return int(_config().get("water_safe_max", 15))

## A single comparable scalar for a day's reward VALUE, used to assert the ladder escalates
## (coins + water + a premium weight for gems/cosmetic). Tuning/test aid — not game-facing.
static func day_value(day: int) -> int:
	var r := reward_for(day)
	return int(r.get("coins", 0)) \
		+ int(r.get("water", 0)) * 10 \
		+ int(r.get("gems", 0)) * 100 \
		+ (200 if String(r.get("cosmetic", "")) != "" else 0)

# --- debug -------------------------------------------------------------------------

## DEBUG-ONLY: fast-forward to the next day so a tester can keep claiming. Claims today (if
## still unclaimed) to advance the streak, then reopens the claim for the next day — the streak
## is kept intact (no soft-decay). Lets a tester walk the whole ladder, hitting mystery days
## repeatedly. The calendar gates the button behind OS.is_debug_build(); never ships in release.
static func debug_advance_day() -> void:
	var d := Save.daily()
	if not bool(d.get("claimed", false)):
		claim_today()                        # advance the streak by claiming the current day
		d = Save.daily()
	d["claimed"] = false                     # reopen: simulate the next day, streak intact
	Save.save_now()
