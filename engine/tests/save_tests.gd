extends "res://engine/tests/test_base.gd"
## Headless tests for the Save persistence layer.
##   godot --headless -s res://engine/tests/save_tests.gd

const Save = preload("res://engine/scripts/core/save.gd")
const Vault = preload("res://engine/scripts/core/vault.gd")   # T44 — the piggy-bank accrual vault
const Feat = preload("res://engine/scripts/core/features.gd") # the vault is parked (flag OFF); flipped ON for its section
const Login = preload("res://engine/scripts/core/login.gd")   # T44 — the forgiving daily-login ladder
const UILogin = preload("res://engine/scripts/ui/login.gd")   # the calendar popup face (day-state mapping)
const G = preload("res://engine/scripts/core/content.gd")     # map-progression queries (gate/unlock chain)
const BoardModel = preload("res://engine/scripts/core/board_model.gd")   # §29 — the board-size-mismatch wipe

# Point Save at a clean temp dir (never touches the real save or progress.cfg).
# This suite's own user:// save-dir tree — kept distinct so the parallel
# runner can never let two suites clobber each other's saves.
func save_prefix() -> String:
	return "tu_test_"

func _initialize() -> void:
	print("== Save tests ==")

	# 1. fresh load → defaults
	fresh("fresh")
	ok(Save.coins() == 0, "fresh load: coins default 0")

	# 2. persistence across an explicit reload
	fresh("persist")
	Save.add_coins(120)
	Save._loaded = false              # force a reload from disk
	ok(Save.coins() == 120, "coins persist across reload")

	# 3. corruption of the live file recovers from .bak
	fresh("corrupt")
	Save.add_coins(200)               # 1st write: creates save.json (no .bak yet)
	Save.add_coins(0)                 # 2nd write: rotates save.json -> save.bak
	var bad := FileAccess.open(Save.path, FileAccess.WRITE)
	bad.store_string("{ this is not json")
	bad.close()
	Save._loaded = false
	ok(Save.coins() == 200, "corrupt primary recovers from .bak")

	# 4. spend
	fresh("spend")
	Save.add_coins(100)
	ok(Save.spend(30) and Save.coins() == 70, "spend deducts when affordable")
	ok(not Save.spend(1000) and Save.coins() == 70, "spend refused when too poor")

	# 7. delete-and-recreate: a save written under an OLDER schema is discarded + recreated
	# fresh on load (no migration — the stars→exp rework bumped the schema).
	fresh("schema_reset")
	Save.add_coins(500)
	Save.grove()["exp"] = 99
	Save.save_now()
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Save.path))
	raw["schema_version"] = Save.SCHEMA_VERSION - 1     # pretend it's an old-schema save
	var wf := FileAccess.open(Save.path, FileAccess.WRITE)
	wf.store_string(JSON.stringify(raw)); wf.close()
	Save._loaded = false
	Save.load_now()
	ok(Save.coins() == 0 and Save.exp_total() == 0, "an older-schema save is wiped + recreated fresh (no migration)")
	ok(int(Save.data["schema_version"]) == Save.SCHEMA_VERSION, "the recreated save carries the current schema_version")

	# 13b. settings: defaults true, set persists across reload
	fresh("settings")
	ok(Save.get_setting("music") and Save.get_setting("sfx"), "settings default to ON")
	Save.set_setting("music", false)
	Save._loaded = false
	ok(not Save.get_setting("music") and Save.get_setting("sfx"), "setting persists across reload")

	# 14. exp is the single cumulative progression total (no migration — it persists as-is).
	fresh("exp_total")
	ok(Save.exp_total() == 0, "a fresh save starts at 0 exp")
	Save.add_exp(15)
	Save.add_exp(7)
	ok(Save.exp_total() == 22 and int(Save.grove().get("exp", -1)) == 22, \
		"add_exp accumulates into the persisted grove.exp")


	# 18. bag-slot count (§5: 6 owned at start, +1 per 💎 buy, hard cap 18). Stored in the
	# grove blob (default-on-read, like hub levels) — accessor + buy path + cap + persistence.
	fresh("bag_slots")
	ok(Save.bag_slots() == 6, "owned bag slots default to 6")
	Save.set_bag_slots(9)
	Save._loaded = false                      # force a reload from disk
	ok(Save.bag_slots() == 9, "owned bag slots persist across reload")
	# set_bag_slots clamps to the 6..18 band (never below the floor, never above the cap)
	Save.set_bag_slots(2)
	ok(Save.bag_slots() == 6, "set_bag_slots clamps below the 6 floor")
	Save.set_bag_slots(99)
	ok(Save.bag_slots() == 18, "set_bag_slots clamps above the 18 cap")

	# 18b. the buy path: spends 💎, +1 slot, refuses when broke or already maxed.
	fresh("bag_buy")
	Save.set_bag_slots(6)
	Save.spend_diamonds(Save.diamonds())      # drain the small new-save seed → start from a known 0
	Save.add_diamonds(10)
	ok(Save.buy_bag_slot(10) and Save.bag_slots() == 7 and Save.diamonds() == 0, \
		"buying a slot spends diamonds and grows the owned count by 1")
	ok(not Save.buy_bag_slot(10) and Save.bag_slots() == 7, \
		"a broke buy is refused and leaves the count untouched")
	Save.add_diamonds(500)
	Save.set_bag_slots(17)
	ok(Save.buy_bag_slot(25) and Save.bag_slots() == 18, "the 12th expansion reaches the 18 cap")
	var dia_at_cap := Save.diamonds()
	ok(not Save.buy_bag_slot(25) and Save.bag_slots() == 18 and Save.diamonds() == dia_at_cap, \
		"a buy at the cap is refused and never charges diamonds")

	# 18c. migration from an OLD save: no bag_slots key (and the legacy bag3 world) reads as the
	# default 6 — strictly >= the old 2/3 capacity, so no data and no capacity is lost.
	fresh("bag_migrate")
	var bg := Save.grove()
	bg["bag3"] = true                         # the retired single-3rd-slot flag
	bg["bag"] = [101, 102]                     # bagged CONTENTS must survive untouched
	Save.grove_write()
	Save._loaded = false                      # reload the way a returning OLD save would
	ok(Save.bag_slots() == 6, "an OLD save (no bag_slots key) migrates to the default 6")
	var kept: Array = Save.grove().get("bag", [])   # JSON round-trips ints as floats; code reads int(bag[i])
	ok(kept.size() == 2 and int(kept[0]) == 101 and int(kept[1]) == 102, \
		"the bagged contents survive the migration")

	# ── T44 · the piggy bank (the accrual vault) — §10 ──────────────────────────
	# Vault.skim(earned) banks a CONFIGURED FRACTION (num/den) of premium earned at
	# the level-up / map-restore / t8-sell sites; the fill grows with play, the
	# crack price is fixed. Vault.crack() releases the banked diamonds and resets.
	var SK_N := Vault.skim_num()
	var SK_D := Vault.skim_den()
	# The feature is parked (`piggy_vault` OFF): skim is a no-op at the default. Prove that
	# first, then flip the flag ON for the accrual math below (an N3 flip smoke).
	fresh("vault_parked")
	Vault.skim(40)
	ok(Vault.balance() == 0, "with the piggy_vault flag OFF, skim banks nothing (the jar sleeps)")
	Feat.FLAGS["piggy_vault"] = true

	# 19a. a fresh vault is empty.
	fresh("vault_fresh")
	ok(Vault.balance() == 0, "a fresh vault banks nothing")

	# 19b. skim banks floor(earned * num/den) and carries the remainder so small
	# earns aren't truncated to nothing — the fractional skim accrues honestly.
	fresh("vault_skim")
	# one big earn → its exact rational floor
	var big := 40
	Vault.skim(big)
	ok(Vault.balance() == int(big * SK_N / float(SK_D)) and Vault.balance() == (big * SK_N) / SK_D, \
		"skim banks floor(earned * num/den) of a single earn")

	# 19c. the remainder carries: SK_D earns of 1💎 each bank exactly SK_N (no loss).
	fresh("vault_carry")
	for _i in SK_D:
		Vault.skim(1)
	ok(Vault.balance() == SK_N, "the fractional remainder carries across many small earns (no truncation loss)")

	# 19d. balance accrues across multiple earns (the three sites add into one jar).
	# The carry makes the cumulative banked total EXACTLY floor(total_earned * num/den) —
	# the clean accrual invariant (no per-call truncation, no over-credit).
	fresh("vault_accrue")
	Vault.skim(3)                              # a level-up's premium
	Vault.skim(10)                             # a map-restore's premium
	Vault.skim(1)                              # a t8 sell
	ok(Vault.balance() == ((3 + 10 + 1) * SK_N) / SK_D, \
		"the vault accrues to floor(total_earned * num/den) across multiple earns")

	# 19e. skim of 0 / negative is a safe no-op (never banks, never goes negative).
	fresh("vault_safe")
	Vault.skim(0)
	Vault.skim(-50)
	ok(Vault.balance() == 0, "skim of 0 / negative banks nothing (safe)")

	# 19f. crack grants the banked diamonds to the wallet, then resets the vault to 0.
	fresh("vault_crack")
	var d0 := Save.diamonds()
	Vault.skim(40)
	var banked := Vault.balance()
	ok(banked > 0, "the vault has a positive balance before cracking")
	var got := Vault.crack()
	ok(got == banked, "crack returns the banked total")
	ok(Save.diamonds() == d0 + banked, "crack grants the banked diamonds to the wallet")
	ok(Vault.balance() == 0, "crack resets the vault to 0")

	# 19g. cracking an empty vault grants nothing (no free diamonds).
	fresh("vault_crack_empty")
	var de := Save.diamonds()
	ok(Vault.crack() == 0 and Save.diamonds() == de, "cracking an empty vault grants nothing")

	# 19h. the balance (and the carry) persist across a reload.
	fresh("vault_persist")
	Vault.skim(7)
	Vault.skim(7)                              # exercise the carry too
	var bp := Vault.balance()
	Save._loaded = false                      # force a reload from disk
	ok(Vault.balance() == bp, "the vault balance persists across a reload")

	# 19i. the crack is claimable only at/above the fill threshold (an empty pig isn't sold).
	fresh("vault_threshold")
	ok(not Vault.claimable(), "a fresh (sub-threshold) vault is not claimable")
	Vault.skim(Vault.claim_min() * SK_D / SK_N + SK_D)   # earn well past the threshold
	ok(Vault.balance() >= Vault.claim_min() and Vault.claimable(), "the vault is claimable once it fills past the threshold")
	Feat.FLAGS["piggy_vault"] = false          # restore the shipped default (parked)

	# ── T44 · the daily login calendar — the forgiving streak (§18) ─────────────
	# Login reads Save.daily()'s streak and pays an ESCALATING ladder with day-7/30
	# MILESTONES; a missed day SOFT-DECAYS the streak one step (never resets to day 1).

	# 20a. the ladder reward escalates with the streak (later days pay more value).
	#   value() is a single comparable scalar across coins/water/💎 (for the test only).
	fresh("login_escalate")
	var v_lo := Login.day_value(1)
	var v_mid := Login.day_value(5)
	ok(v_mid > v_lo, "the ladder reward escalates by streak (day 5 > day 1)")

	# 20b. a milestone day pays its bigger reward (day 30 carries premium 💎).
	#   day 7 is no longer a FIXED milestone — it is now a mystery day (T46 below).
	fresh("login_milestone")
	ok(Login.is_milestone(30), "day 30 is a milestone")
	ok(int(Login.reward_for(30).get("gems", 0)) > 0, "the day-30 milestone pays premium diamonds")
	ok(Login.day_value(30) > Login.day_value(29), "the milestone day pays more than the day before it")
	ok(not Login.is_milestone(7), "day 7 is no longer a fixed milestone (it is now a mystery day)")

	# 20c. energy (water) stays modest — under the self-sustain invariant (§4/§10).
	#   the largest single-day water gift must stay well under a day's natural regen.
	fresh("login_faucet")
	var max_water := 0
	for dd in range(1, 8):
		max_water = maxi(max_water, int(Login.reward_for(dd).get("water", 0)))
	ok(max_water <= Login.water_safe_max(), "daily water gifts stay modest (under the self-sustain cap)")

	# 20d. claim grants the day's reward exactly once per day; a second claim is refused.
	fresh("login_claim_once")
	var c0 := Save.coins()
	var first := Login.claim_today()
	ok(first and Save.coins() > c0, "the first claim grants the day's reward")
	var c1 := Save.coins()
	var second := Login.claim_today()
	ok(not second and Save.coins() == c1, "a second claim the same day is refused (once per day)")

	# 20e. a claim bumps the streak (today's claim advances the ladder by one).
	fresh("login_streak_bump")
	ok(Login.streak() == 0, "a fresh streak is 0")
	Login.claim_today()
	ok(Login.streak() == 1, "claiming bumps the streak to 1")

	# 20f. FORGIVING: a missed day SOFT-DECAYS the streak by one step — never to day 1/0.
	#   simulate a 5-day streak, then a one-day gap, and prove it drops to 4 (not 0).
	fresh("login_forgiving")
	var g := Save.data
	# plant a claimed streak of 5 as of YESTERDAY, then read today (the rollover).
	var yesterday := int(Time.get_unix_time_from_system() / 86400.0) - 2   # a one-DAY gap (missed 1)
	g["daily"] = {"day": yesterday, "jobs": 0, "merges": 0, "coins": 0, "claimed": true, "streak": 5}
	Save.save_now()
	Save._loaded = false
	ok(Login.streak() == 4, "a missed day soft-decays the streak one step (5 → 4), never resets to 0")

	# 20g. a missed day still leaves a claimable reward (the calendar keeps paying after a gap):
	# the streak decays (5 → 3 after a 2-day gap) but the ladder RESUMES — today's claim
	# succeeds and bumps from the decayed streak (3 → 4), not from 0.
	fresh("login_gap_claim")
	var g2 := Save.data
	g2["daily"] = {"day": int(Time.get_unix_time_from_system() / 86400.0) - 3, "jobs": 0, "merges": 0, "coins": 0, "claimed": true, "streak": 5}
	Save.save_now()
	Save._loaded = false
	ok(Login.streak() == 3, "a 2-day gap soft-decays the streak by two steps (5 → 3)")
	ok(Login.claim_today() and Login.streak() == 4, "after a gap the calendar still pays and the ladder resumes from the decayed streak (3 → 4)")

	# 20h. the streak (and claim state) persist across a reload.
	fresh("login_persist")
	Login.claim_today()
	var sp := Login.streak()
	Save._loaded = false
	ok(Login.streak() == sp, "the streak persists across a reload")

	# 20i. CALENDAR FACE mapping (regression): claiming TODAY must not also mark TOMORROW
	#   as claimed. today_day() advances to streak+1 on claim while the per-day `claimed`
	#   flag is still set, so the day-after card used to render "done" off a stale read.
	fresh("login_ui_claim_mapping")
	var ui_host := Control.new()
	var ui_rb := {"fn": Callable()}
	var ui_before: Array = UILogin._days(ui_host, ui_rb, {})
	ok(String(ui_before[0].get("state", "")) == "today", "before claiming: day 1 is the claimable 'today' card")
	ok(String(ui_before[1].get("state", "")) == "future", "before claiming: day 2 is a future card")
	Login.claim_today()
	var ui_after: Array = UILogin._days(ui_host, ui_rb, {})
	ok(String(ui_after[0].get("state", "")) == "done", "after claiming day 1: day 1 is 'done'")
	ok(String(ui_after[1].get("state", "")) == "future", "after claiming day 1: day 2 is STILL future (not auto-claimed)")
	ui_host.free()

	# ── T46 · mystery daily gifts (slots 4 & 7) — the auto-spin reveal ──────────
	# Slots 4 and 7 of every weekly cycle are MYSTERY days: roll_mystery() reveals
	# `show` DISTINCT rewards and picks `win` winners; claim_mystery() grants ONLY the
	# winners and bumps the streak once. This replaces the old fixed day-7 milestone.

	# 21a. the mystery slots recur every week (days 4/7/11/14 are mystery; 1/3/5 are not).
	fresh("login_mystery_slots")
	ok(Login.is_mystery(4), "day 4 is a mystery day")
	ok(Login.is_mystery(7), "day 7 is a mystery day")
	ok(Login.is_mystery(11) and Login.is_mystery(14), "the mystery slots recur next week (days 11 & 14)")
	ok(not Login.is_mystery(1) and not Login.is_mystery(5), "ordinary ladder days are not mystery")

	# 21b. a roll reveals `show` distinct options and picks `win` distinct winners in range.
	fresh("login_mystery_roll")
	var roll4 := Login.roll_mystery(4)
	ok(int(roll4.get("show", 0)) == 3 and int(roll4.get("win", 0)) == 1, "day-4 mystery shows 3, wins 1")
	ok((roll4.get("options", []) as Array).size() == 3, "day-4 roll reveals 3 option cards")
	var w4: Array = roll4.get("winners", [])
	ok(w4.size() == 1 and int(w4[0]) >= 0 and int(w4[0]) < 3, "day-4 roll picks exactly one winner in range")
	var roll7 := Login.roll_mystery(7)
	var w7: Array = roll7.get("winners", [])
	ok(int(roll7.get("show", 0)) == 5 and w7.size() == 2, "day-7 mystery shows 5, wins 2")
	ok(int(w7[0]) != int(w7[1]), "day-7 winners are two DISTINCT cards")

	# 21c. the revealed options are distinct draws from the slot's pool.
	fresh("login_mystery_distinct")
	var opts7: Array = Login.roll_mystery(7).get("options", [])
	var seen_opts: Array = []
	var all_distinct := true
	for o in opts7:
		if seen_opts.has(o):
			all_distinct = false
		seen_opts.append(o)
	ok(all_distinct, "a day-7 roll reveals distinct (non-duplicated) reward cards")

	# 21d. claim_mystery grants EXACTLY the won rewards, once, and bumps the streak.
	fresh("login_mystery_claim")
	var roll := Login.roll_mystery(4)
	var won: Array = Login.won_rewards(roll)
	var want_coins := 0
	var want_gems := 0
	for r in won:
		want_coins += int(r.get("coins", 0))
		want_gems += int(r.get("gems", 0))
	var c_before := Save.coins()
	var g_before := Save.diamonds()
	var s_before := Login.streak()
	ok(Login.claim_mystery(won), "the first mystery claim succeeds")
	ok(Save.coins() - c_before == want_coins, "a mystery claim grants exactly the won coins")
	ok(Save.diamonds() - g_before == want_gems, "a mystery claim grants exactly the won gems")
	ok(Login.streak() == s_before + 1, "a mystery claim bumps the streak by one")
	ok(not Login.claim_mystery(won), "a second mystery claim the same day is refused")

	# 21e. claim_today() on a mystery day still pays + advances (the headless fallback).
	fresh("login_mystery_today")
	var gd46 := Save.data
	gd46["daily"] = {"day": int(Time.get_unix_time_from_system() / 86400.0), "jobs": 0, "merges": 0, "coins": 0, "claimed": false, "streak": 3}
	Save.save_now()
	Save._loaded = false
	ok(Login.today_day() == 4 and Login.is_mystery(Login.today_day()), "the streak reaches a mystery day (day 4)")
	ok(Login.claim_today(), "claim_today resolves a mystery day headlessly")
	ok(Login.claimed_today() and Login.streak() == 4, "the headless mystery claim advances the ladder (streak 3 → 4)")

	# 21f. mystery pool water gifts also obey the §4/§10 faucet guard.
	fresh("login_mystery_faucet")
	var max_pool_water := 0
	for slot in [4, 7]:
		for r in Login.mystery_pool(slot):
			max_pool_water = maxi(max_pool_water, int(r.get("water", 0)))
	ok(max_pool_water <= Login.water_safe_max(), "mystery water gifts stay under the self-sustain cap")

	# 21g. debug fast-forward: today is claimable again with the streak advanced (no decay).
	fresh("login_debug_ff")
	Login.claim_today()
	var s_ff := Login.streak()
	Login.debug_advance_day()
	ok(not Login.claimed_today(), "debug fast-forward reopens today's claim")
	ok(Login.streak() == s_ff, "debug fast-forward keeps the advanced streak (no decay)")
	ok(Login.today_day() == s_ff + 1, "debug fast-forward lands on the next ladder day")

	# 22. map gates survive a save→load — the reported "locked into map 1 on restart" bug.
	# The auto-recorded map gate is an int in memory ([0]), but JSON reloads every number as a float
	# ([0.0]). map_complete checked gates.has(z) with an INT z, which Array.has fails on a float — so the
	# next map re-locked on restart. Round-trip a real save and assert the completion chain still holds.
	fresh("gates_roundtrip")
	var grt := Save.grove()
	var ulr := {}
	for msp in G.MAPS[0].spots:                # claim every spot of map 0 → map 0 spots-done
		ulr[String(msp.id)] = true
	grt["unlocks"] = ulr
	grt["gates"] = [0]                          # int, exactly as the live auto-gate writes it
	Save.save_now()
	Save.load_now()                            # simulate a restart: re-parse from disk (ints → floats)
	var gl: Array = Save.grove().get("gates", [])
	var ul2: Dictionary = Save.grove().get("unlocks", {})
	ok(gl.size() == 1 and typeof(gl[0]) == TYPE_FLOAT, \
		"precondition: the reloaded gate index is a JSON float (0.0), not an int")
	ok(G.map_complete(0, ul2, gl), \
		"map 0 stays complete after a save→load (float gate index is tolerated)")
	ok(G.map_unlocked(1, ul2, gl), \
		"map 2 stays UNLOCKED across a restart (the reported bug)")

	# 23. reconcile_gates heals a save STRANDED with spots-done but an EMPTY `gates` — the reported
	# "stuck on map one, can't move forward" bug. Every spot of map 0 was restored, yet gates stayed []
	# (the gate write was missed when the spot ids were remapped between builds), so map 1 never unlocked
	# and the last-spot auto-record could never re-fire (no unclaimed spot left to tap). The boot reconcile
	# must back-fill the missing gate, and it must be idempotent.
	fresh("reconcile_gates")
	# The picture-book pages after the first are `open` (browse freely), so the classic stuck
	# state can't occur at z=1 in live data — exercise the reconcile against a TEMP gated map
	# appended past the pages (the machinery is data-independent and must stay healthy for the
	# frontier gate the pages build system brings back).
	G.MAPS.append({"id": "_test_gated", "name": "Test Gated", "spots": []})
	var gated_z := G.MAPS.size() - 1
	var rg := Save.grove()
	var rul := {}
	for rsp in G.MAPS[0].spots:                 # claim every spot of map 0 → map 0 spots-done
		rul[String(rsp.id)] = true
	rg["unlocks"] = rul
	rg["gates"] = []                            # spots done, gate never recorded — the stranded state
	ok(G.map_spots_done(0, rul) and not G.map_unlocked(gated_z, rul, rg["gates"]), \
		"precondition: predecessor spots done but the gated map stays locked (empty gates) — the stuck state")
	ok(G.reconcile_gates(rg), "reconcile_gates back-fills the missing gate for map 0")
	ok(G.gate_recorded(rg["gates"], 0), "map 0 is now recorded in gates")
	ok(G.map_unlocked(1, rg["unlocks"], rg["gates"]), "the next page unlocks after the reconcile")
	ok(not G.reconcile_gates(rg), "reconcile_gates is idempotent on an already-healed save")
	G.MAPS.remove_at(gated_z)

	# 24. THE COIN CLOCK (home build-and-upgrade redesign): level derives from LIFETIME ORGANIC
	# coin earnings. earn_coins (organic faucets) bumps balance AND the lifetime counter;
	# add_coins (purchases/neutral credits) bumps balance only; spending never reduces the clock.
	fresh("coin_clock")
	ok(Save.coins_earned_lifetime() == 0, "fresh save: lifetime earned coins default 0")
	Save.earn_coins(50)
	ok(Save.coins() == 50 and Save.coins_earned_lifetime() == 50, \
		"earn_coins credits the balance AND the lifetime clock")
	Save.add_coins(150)                             # a purchased pack — spendable, clock-inert
	ok(Save.coins() == 200 and Save.coins_earned_lifetime() == 50, \
		"add_coins (purchased) credits the balance only — the clock never moves")
	ok(Save.spend(120) and Save.coins_earned_lifetime() == 50, \
		"spending never reduces the lifetime clock")
	Save._loaded = false
	ok(Save.coins_earned_lifetime() == 50, "the lifetime clock persists across reload")

	# 25. level = f(lifetime earned coins) via the arithmetic curve (level_at_coins/coins_at_level).
	fresh("coin_level")
	ok(G.level() == 1, "fresh save: level 1 at 0 earned")
	ok(G.coins_at_level(1) == 0, "curve: level 1 starts at 0")
	ok(G.coins_at_level(3) > G.coins_at_level(2) and G.coins_at_level(2) > 0, \
		"curve: thresholds are positive and monotone")
	var lu := G.earn_coins(G.coins_at_level(2))     # earn exactly to the L2 threshold
	ok(G.level() == 2 and lu == 1, "earning to the L2 threshold levels up once (reported)")
	Save.add_coins(100000)                          # a whale-sized purchase
	ok(G.level() == 2, "purchased coins never advance the level")

	# ══════════════════════════════════════════════════════════════════════════
	# 26–29 · THE FOUR SILENT PERSISTENCE FAILURES (loudness + data preservation)
	# Each section drives the REAL failure path, not a happy path with a flag poked.
	# ══════════════════════════════════════════════════════════════════════════

	# 26. A FAILED SAVE IS LOUD. _save_data has three abort points (open / verify / dir) that used
	# to `return` in silence, so an unwritable user:// (full disk, a sandbox change after an OS
	# update) made EVERY save_now() a no-op — the player lost a whole session with no signal.
	# Each branch now push_error()s and leaves Save.last_save_failed / last_save_error readable.
	# (Diagnostics only: nothing renders these yet, by design.)

	# 26a. the OPEN stage — the temp file cannot be created because its directory does not exist.
	fresh("save_fail_open")
	Save.add_coins(10)                                     # one healthy write first
	ok(not Save.last_save_failed, "a healthy save leaves last_save_failed false")
	var good_tmp := Save.tmp
	Save.tmp = "user://tu_test_no_such_dir/save.tmp"        # genuinely unwritable: no such directory
	Save.data["currencies"]["coins"] = 999
	Save.save_now()
	ok(Save.last_save_failed, "an unwritable temp path sets last_save_failed")
	ok(Save.last_save_error.begins_with("open"), \
		"the failure names the OPEN stage (%s)" % Save.last_save_error)
	var disk_open: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Save.path))
	ok(int(disk_open["currencies"]["coins"]) == 10, \
		"the failed save really did not reach disk (the file still holds the last good value)")
	Save.tmp = good_tmp
	Save.save_now()
	ok(not Save.last_save_failed, "the failure flag clears once a save succeeds again")

	# 26b. the VERIFY stage — the temp file is written but cannot be read back. Made real by
	# chmod-ing the temp file WRITE-ONLY (0200): FileAccess.open(WRITE) still succeeds, the
	# store_string still lands, and the read-back verify sees nothing — exactly the half-written
	# temp the verify step exists to catch.
	fresh("save_fail_verify")
	Save.add_coins(10)
	var seed_tmp := FileAccess.open(Save.tmp, FileAccess.WRITE)
	seed_tmp.store_string("{}")
	seed_tmp.close()
	var abs_tmp := ProjectSettings.globalize_path(Save.tmp)
	var chmod_out: Array = []
	OS.execute("/bin/chmod", ["200", abs_tmp], chmod_out, true)
	ok(FileAccess.get_file_as_string(Save.tmp) == "" and FileAccess.file_exists(Save.tmp), \
		"precondition: the temp file is now write-only (it exists but reads back empty)")
	Save.data["currencies"]["coins"] = 777
	Save.save_now()
	ok(Save.last_save_failed and Save.last_save_error.begins_with("verify"), \
		"a temp file that will not read back is reported at the VERIFY stage (%s)" % Save.last_save_error)
	var disk_verify: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Save.path))
	ok(int(disk_verify["currencies"]["coins"]) == 10, "the unverifiable save never swapped into place")
	OS.execute("/bin/chmod", ["644", abs_tmp], chmod_out, true)   # leave the dir cleanable

	# 26c. the DIR stage — the temp write + verify both succeed, but the destination directory
	# the atomic rename targets is gone.
	fresh("save_fail_dir")
	Save.add_coins(10)
	var good_path := Save.path
	Save.path = "user://tu_test_no_such_dir/save.json"
	Save.data["currencies"]["coins"] = 555
	Save.save_now()
	ok(Save.last_save_failed and Save.last_save_error.begins_with("dir"), \
		"a missing destination directory is reported at the DIR stage (%s)" % Save.last_save_error)
	ok(not FileAccess.file_exists(Save.path), "nothing was created at the unreachable destination")
	Save.path = good_path
	Save.save_now()
	ok(not Save.last_save_failed and int(Save.coins()) == 555, "the save lands again once the path is reachable")

	# 27. A STRUCTURALLY WRONG saved value can no longer crash the hard-indexing accessors.
	# `"settings": 5` / `"currencies": []` passes the schema-version check and used to survive
	# _merge verbatim, so the next get_setting() / coins() indexed an int or an Array by name.
	# The base shape now wins, the repair is flagged, and load_now's save_now writes it back.

	# 27a. settings.
	fresh("merge_shape_settings")
	Save.set_setting("music", false)
	var raw_s: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Save.path))
	raw_s["settings"] = 5                                  # a truncated / hand-edited save
	var ws := FileAccess.open(Save.path, FileAccess.WRITE)
	ws.store_string(JSON.stringify(raw_s)); ws.close()
	Save._loaded = false
	Save.load_now()
	ok(Save.data["settings"] is Dictionary, "a non-Dictionary `settings` is replaced by the default shape")
	ok(Save.get_setting("music"), "get_setting still works after the repair (back at its default)")
	ok(Save.last_load_repaired and Save.last_load_repairs.has("settings"), \
		"the repair is flagged and names the key")
	var back_s: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Save.path))
	ok(back_s["settings"] is Dictionary, "the corrected shape is written back to disk")

	# 27b. currencies — the wallet coins()/diamonds() hard-index.
	fresh("merge_shape_currencies")
	Save.add_coins(250)
	var raw_c: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Save.path))
	raw_c["currencies"] = []                               # an Array where the wallet belongs
	var wc := FileAccess.open(Save.path, FileAccess.WRITE)
	wc.store_string(JSON.stringify(raw_c)); wc.close()
	Save._loaded = false
	Save.load_now()
	ok(Save.data["currencies"] is Dictionary, "a non-Dictionary `currencies` is replaced by the default wallet")
	ok(Save.last_load_repaired and Save.last_load_repairs.has("currencies"), \
		"the currencies repair is flagged and names the key")
	ok(Save.coins() == 0 and Save.diamonds() == Save.NEW_SAVE_GEMS, \
		"coins()/diamonds() still read after the repair (the wallet fell back to the fresh default)")

	# 27c. a HEALTHY save is never flagged as repaired (the guard has no happy-path effect).
	fresh("merge_shape_clean")
	Save.add_coins(40)
	Save._loaded = false
	Save.load_now()
	ok(not Save.last_load_repaired and Save.last_load_repairs.is_empty() and Save.coins() == 40, \
		"a well-shaped save loads with no repair flagged")

	# 28. A BOARD-DIMENSION CHANGE is a real migration, not a silent wipe. On a terrain/items size
	# mismatch the whole restore is skipped and the fresh starter layout stands; `changed` stayed
	# false, so board.gd's save_dirty never fired and nothing warned. It now reports and returns
	# changed=true (the same signal every other discard path in from_dict uses).
	fresh("board_size_mismatch")
	var bm_ref := BoardModel.new()
	var blob_ok: Dictionary = bm_ref.to_dict()
	ok(not BoardModel.new().from_dict(blob_ok), \
		"precondition: a matching blob restores cleanly (changed=false)")
	var blob_small: Dictionary = bm_ref.to_dict()
	blob_small["terrain"] = Array(blob_small["terrain"]).slice(0, 4)   # a smaller board's save
	blob_small["items"] = Array(blob_small["items"]).slice(0, 4)
	var bm_small := BoardModel.new()
	ok(bm_small.from_dict(blob_small), \
		"a wrong-size terrain/items blob returns changed=true (the caller treats it as a migration)")
	ok(bm_small.terrain.size() == bm_ref.terrain.size(), \
		"the board keeps this build's dimensions after the mismatch")
	# and the other half of the blob still restores, which is exactly why it read as a bug
	var blob_big: Dictionary = bm_ref.to_dict()
	blob_big["items"] = Array(blob_big["items"]) + [0, 0]              # a LARGER board's save
	ok(BoardModel.new().from_dict(blob_big), "an oversize items blob is reported as changed too")

	# 29. LOWERING RESIDENT_MAX_TIER must not delete residents above the new cap. resident_counts
	# used to truncate on read and set_resident_counts wrote the truncation back, so the first
	# grant after a cap-lowering balance edit permanently deleted every over-cap resident. A saved
	# array LONGER than the cap now rides along untouched.
	fresh("resident_tail")
	var rz := 0
	var rmid := String(G.MAPS[rz].id)
	var rtid := String(G.resident_lines(rz)[0].id)
	var over_cap := int(G.RESIDENT_MAX_TIER) + 2           # written as if the cap were later lowered by 2
	var planted: Array = []
	for _i in over_cap:
		planted.append(0)
	planted[int(G.RESIDENT_MAX_TIER)] = 3                  # residents one tier above the current cap
	planted[int(G.RESIDENT_MAX_TIER) + 1] = 1              # …and two tiers above
	Save.set_resident_counts(rmid, rtid, planted)
	Save._loaded = false                                   # cold reload from disk
	var kept_tail: Array = Save.resident_counts(rmid, rtid)
	ok(kept_tail.size() == over_cap, "a roster array longer than RESIDENT_MAX_TIER keeps its length on read")
	ok(int(kept_tail[int(G.RESIDENT_MAX_TIER)]) == 3 and int(kept_tail[int(G.RESIDENT_MAX_TIER) + 1]) == 1, \
		"residents past the cap survive the READ (no truncation)")
	G.grant_resident(rz, rtid)                             # the read-truncate-write-back path
	var after_grant: Array = Save.resident_counts(rmid, rtid)
	ok(int(after_grant[0]) == 1, "the grant still lands its tier-1 resident")
	ok(int(after_grant[int(G.RESIDENT_MAX_TIER)]) == 3 and int(after_grant[int(G.RESIDENT_MAX_TIER) + 1]) == 1, \
		"a grant no longer DELETES the residents past the cap (the write-back preserves the tail)")
	Save._loaded = false
	var tail_on_disk: Array = Save.resident_counts(rmid, rtid)
	ok(tail_on_disk.size() == over_cap and int(tail_on_disk[int(G.RESIDENT_MAX_TIER)]) == 3, \
		"the preserved tail is really on disk after a cold reload")
	# the SHORT direction (the documented old-save right-pad) is unchanged
	Save.set_resident_counts(rmid, rtid, [2, 1])
	ok(Save.resident_counts(rmid, rtid).size() == int(G.RESIDENT_MAX_TIER), \
		"a short saved array still right-pads to exactly RESIDENT_MAX_TIER")

	# 30. THE ROUND TRIP still works end to end through the real Save.save_now()/load path.
	fresh("roundtrip")
	Save.earn_coins(310)
	Save.add_diamonds(4)
	Save.set_setting("sfx", false)
	Save.grove()["water"] = 7
	Save.save_now()
	ok(not Save.last_save_failed, "the round-trip save reports no failure")
	Save._loaded = false
	Save.load_now()
	ok(Save.coins() == 310 and Save.coins_earned_lifetime() == 310, "round trip: coins + the lifetime clock")
	ok(Save.diamonds() == Save.NEW_SAVE_GEMS + 4, "round trip: diamonds")
	ok(not Save.get_setting("sfx") and Save.get_setting("music"), "round trip: settings")
	ok(Save.water() == 7 and not Save.last_load_repaired, "round trip: the grove blob, with no repair flagged")

	finish()
