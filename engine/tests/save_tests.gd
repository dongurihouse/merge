extends SceneTree
## Headless tests for the Save persistence layer.
##   godot --headless -s res://engine/tests/save_tests.gd

const Save = preload("res://engine/scripts/core/save.gd")
const Vault = preload("res://engine/scripts/core/vault.gd")   # T44 — the piggy-bank accrual vault
const Login = preload("res://engine/scripts/core/login.gd")   # T44 — the forgiving daily-login ladder
const UILogin = preload("res://engine/scripts/ui/login.gd")   # the calendar popup face (day-state mapping)

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# Point Save at a clean temp dir (never touches the real save or progress.cfg).
func fresh(name: String) -> void:
	var dir := "user://tu_test_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

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

	# 7. migrate a legacy progress.cfg, exactly once
	fresh("migrate")
	var c := ConfigFile.new()
	c.set_value("progress", "cleared", 5)
	c.save(Save.legacy)                      # temp legacy file (NOT the real one)
	Save._loaded = false
	Save.load_now()
	ok(Save.coins() == 5 * Save.COINS_PER_CLEAR_SEED, "migration seeds coins from past clears")
	ok(bool(Save.data["migrated_v2"]), "migration sets the once-guard")
	var after := Save.coins()
	Save._loaded = false
	Save.load_now()                          # reloading must NOT re-grant
	ok(Save.coins() == after, "migration does not double-grant on reload")

	# 13b. settings: defaults true, set persists across reload
	fresh("settings")
	ok(Save.get_setting("music") and Save.get_setting("sfx"), "settings default to ON")
	Save.set_setting("music", false)
	Save._loaded = false
	ok(not Save.get_setting("music") and Save.get_setting("sfx"), "setting persists across reload")

	# 14. exp→stars_earned: an old save stored level as `exp` (=10×stars). The clock
	# is now stars EARNED, so the level carries over (exp/10) and `exp` is dropped.
	fresh("exp_mig")
	Save.grove()["exp"] = 240                 # an old ~L4 save
	Save.grove()                              # the accessor migrates on read
	ok(not Save.grove().has("exp") and int(Save.grove().get("stars_earned", -1)) == 24, \
		"exp→stars_earned migration carries the old level and drops exp")

	# 16. T38 zone→map sweep: the two persisted grove keys migrate (value carried, old key dropped).
	fresh("map_keys_rename")
	var gm := Save.grove()
	gm["last_zone"] = "farmhouse"
	gm["quests_zone"] = 3
	Save._migrate_map_keys(gm)
	ok(not gm.has("last_zone") and String(gm.get("last_map", "")) == "farmhouse", \
		"last_zone → last_map carries the value and drops the old key")
	ok(not gm.has("quests_zone") and int(gm.get("quests_map", -99)) == 3, \
		"quests_zone → quests_map carries the value and drops the old key")
	# idempotent + non-clobbering: an existing new key wins, a re-run is a no-op.
	gm["last_zone"] = "stale"; gm["last_map"] = "barn"
	Save._migrate_map_keys(gm)
	ok(not gm.has("last_zone") and String(gm.get("last_map", "")) == "barn", \
		"migration never clobbers an existing last_map")

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

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
