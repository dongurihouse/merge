extends SceneTree
## Ghibli Grove — headless PACING SIM for the §7 GENERATED-quest model (the economy's
## tables are validated here, not by vibes). A bot plays the model for N days and reports
## water→coins→level→cluster rates, then checks the invariants.
##
## THE COIN CLOCK (re-spined 2026-07-25). Coins are the ONE currency: quests and sells pay coins, LEVEL
## derives from LIFETIME ORGANIC coin earnings (content.level_at_coins), and restoration is the GLOBAL
## COVER-UP CLUSTER ladder — each cluster gated by a level floor (cluster_min_level) AND a coin COST it
## pays, making the ladder the game's dominant coin sink. The old exp clock (quests paying {exp, coins},
## free spots claimed at cumulative-exp thresholds) is RETIRED: no live faucet mints exp, no live gate
## reads it, and MAPS[z].spots is save-compat legacy (page 1 only; pages 2-5 are empty). The sim modelled
## that retired spine until this re-spine and crashed on the first delivery reading `reward.exp`.
##   I1 zero jams (board full + no merge + nothing deliverable)
##   I2 every page's level-up water gift < WATER_REWARD_MAX_RATIO of its measured spend
##   I3 runway (days to unlock the whole cluster ladder) — reported (tuning signal, not a hard fail)
##   no-strand — the bot never sits a full session unable to earn coins while clusters remain
##   Y THE CLOCK IS QUESTS ONLY — no non-quest coin may advance progression (structural check)
##   Z coin faucet vs sink — REPORTED; clock coins vs spendable coins broken out
##   P population invariants:
##     P1 LATE-GAME no-pile: once a page completes, the residents loop absorbs the
##        post-completion coin faucet rather than letting coins pile up
##     P2 EARLY-GAME no dead-zone: before the first completion there is no idle coin
##        gap — the active faucet (burst ladder + the cluster ladder) keeps coins moving
##     D diamond faucet (level-ups + page-restores) vs sink — FAUCET-ONLY, see the report note
##   godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- [days] [seed]
##
## Quests come from the LIVE ENGINE: the sim calls Quests.refill (quests.gd) with the same arguments
## board.gd passes, so the fence it measures IS the shipped fence — asks GENERATED (G.gen_quest) from the
## ACTIVE-LINE WINDOW (G.active_lines — 3 lines, base or crafted-special alike), capped at
## MAX_QUESTS_PER_LINE per line, on a flat endless fence of MAX_GIVERS stands (Quests.meter_target — the
## old exp-metered active_giver_count is vestigial), paid at the level's BAND. Each is a
## single item paying COINS only. Generators are abstracted: _pop pops the BASE lines the live asks need
## (a special expands to its two ingredients, exactly as birth-on-tap delivers them), so the sim measures
## the economy, not the tool logistics.
##
## §1 POPULATION — the live global Bucket: coins buy an EXPEDITION (Explore.MIN_COST, the coin SINK) →
## spirits → placed into habitat cells → they YIELD coins (a SOURCE). Cells come ONLY from completed
## cover-up pages (G.cells_from_scenes). KNOWN GAP: the per-map WELCOME roster the diamond sink still
## models (residents/_resident_capacity, keyed off the legacy MAPS[z].spots) is retired live and now runs
## inert, so the D ledger is faucet-only — the parked §5 bucket economy pass owns re-authoring it.
## All numbers are PROVISIONAL (sim dials).

const G = preload("res://engine/scripts/core/content.gd")
const Quests = preload("res://engine/scripts/core/quests.gd")   # §7 the LIVE fence engine — the sim CALLS it (refill / current_band), never mirrors it
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")
const Mastery = preload("res://engine/scripts/core/mastery.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Explore = preload("res://engine/scripts/core/explore.gd")   # §1 expedition cost (the live residents coin SINK)
const RB = preload("res://engine/scripts/core/resident_bucket.gd")   # §1 idle yield + sell dials (the live residents coin SOURCES) — NOTE the full bucket re-author is the parked §5 economy pass
const POP_SLOTS_MAX := 8             # §1 a map's resident roster scales 1 (first spot restored) → this (all spots) — PROTOTYPE

var rng := RandomNumberGenerator.new()
var board: BoardModel
var unlocks := {}              # spot id -> true (bought)
var map := 0                  # the map currently being restored
var gates_done := {}           # map -> true (its spots fully bought → map completed, roster open)
var live_quests: Array = []    # the active fence — generated flat regular quests, metered to the next unlock
var _recent_items: Array = []  # §7 anti-monotony window: the last ≤5 asked item codes (line*100+tier), fed to Quests.refill exactly as board.gd feeds its own (maintained on delivery, mirroring BoardActions.deliver_quest)

var clusters_unlocked := 0     # cover-up clusters unlocked over the run (the restoration ladder's progress)
var cluster_spend := 0         # coins PAID for those clusters — the game's dominant coin SINK
var coins_spendable := 0       # lifetime NON-clock coins (sells, pickups, gifts, yield) — spendable only
var coins := 0                 # spendable wallet BALANCE (faucet minus the sinks spent in-session)
var coins_earned := 0          # cumulative coin INTAKE over the run (the faucet total — balance never goes negative, so the report reads intake, not the drained balance)
var quest_coins := 0           # coins from quest rewards (the §7 faucet)
var sell_coins := 0            # coins from selling only (the Y "cleanup, not income" tripwire)
var boost_taps := 0            # generator taps left on the live temporary boost (§6 coin sink)
var boost_coins_spent := 0     # coins sunk into boost activations (a repeatable Z sink)
var boosts_bought := 0         # how many boosts the bot has activated over the run
# §1 POPULATION loop: once a map COMPLETES, its resident roster opens. Welcoming spends coins
# (base/core) or diamonds (premium signature); two-of-a-kind auto-merges a tier up. NO roster cap,
# so the bot re-buys base feeders forever — this is the ENDLESS coin sink that replaced the hub.
# residents[z] = { type_id -> [t1,t2,t3] } — the per-map roster, mirroring Save.resident_counts.
var residents := {}            # map index -> { type_id -> Array[RESIDENT_MAX_TIER] }
var resident_coins_spent := 0  # coins sunk into welcoming base residents (the new endless coin SINK)
var resident_gems_spent := 0   # diamonds sunk into premium residents (the new diamond SINK)
var residents_welcomed := 0    # total t1 residents welcomed (coin + premium) over the run
var residents_premium := 0     # of those, how many were premium (diamond) welcomes
var resident_merges := 0       # auto-merge events fired (two-of-a-kind → a tier up)
# §1 diamond ECONOMY (previously unmodeled): a faucet (level-ups + map-restores + t8 sells) vs the
# new premium-resident sink. Tracked so the report shows BOTH ledgers, not just coins.
var diamonds := 0              # spendable 💎 balance (faucet minus the premium sink)
var gems_from_levels := 0      # 💎 from level-ups (LEVEL_DIAMONDS each)
var gems_from_maps := 0        # 💎 from fully restoring a map (MAP_DIAMONDS each)
var gems_from_sells := 0       # RETIRED (always 0) — t8 sells for COINS now, no premium pinnacle
var gems_from_quests := 0      # RETIRED (always 0) — quests pay no acorns now (milestone/IAP only)
# the coin faucet measured ONCE the FIRST map completes (drives the P1 late-game no-pile check) —
# coins earned AFTER population opens must have somewhere to go.
var coins_at_first_complete := -1   # cumulative coin INTAKE the moment the first map completed (-1 = not yet)
var balance_at_first_complete := 0  # held coin BALANCE at that moment (the pre-population pile, for P2)
var resident_spend_at_first_complete := 0
var first_complete_day := -1
var _deliv_day := 0            # deliveries this day (reported on the day line — the late-fence health signal)
# PACING MILESTONES (tuning signals for the level-curve sweep). The content arc and the restoration
# ladder now ride the SAME spine: both derive from the owner-authored SCENE_END_LEVEL band (re-spined
# 2026-07-26 — was the cluster COST ladder through the coin curve, which ran ~2x too late). That does
# NOT mean 'when the last item line lands' and 'when the book is finished' track together — re-measure
# after this re-spine; SCENE_END_LEVEL and ZONE_BAND are the dials that would narrow any gap.
var content_end_day := -1      # first day the player reaches the LAST zone's unlock level (all lines seen)
var half_book_day := -1        # first day half the cluster ladder is unlocked
var scene_done_day := {}       # cover-up page index -> the day that page's last cluster was unlocked
var water := 0
var level_gift_water := 0
var _greedy := false           # bot mode: greedy welcomes residents whenever affordable (no cushion)
var _cur_day := 0              # the current day index (0-based), for the P1 first-completion stamp

# §6 NEW FAUCETS (B/C/D) — folded in so the invariants see the REAL water/exp/coin/acorn income, not
# just quests + the level-gift. Collected the way real play does: limited-use BONUS generators that
# side-spawn off a main-generator tap (§6.C; gen redesign 2026-06-28 — was constant-accrual accumulators),
# special items on merge (§6.B), treat bursts on pop (§6.D). Tallied separately so the report shows how
# much each moves the exp arc and the water pinch. (Conservative: drops/treats credited at their t1/head
# tier, bonus gens collected at mult 1 — the live boost-burst stacking is not modeled — a floor on the real yield.)
var bonus_water := 0          # §6.C bonus-generator faucets (collected by draining the live side-spawn)
var bonus_coins := 0
var bonus_acorn := 0
var bonus_gens := 0           # §6.C bonus generators side-spawned over the run (the faucet's volume signal)
var _bonus_kind := ""         # §6.C the live bonus generator's kind on the board ("" = none — one at a time)
var _bonus_clicks := 0        # its remaining tap budget; drained one tap per main-gen tap, then it vanishes
var drop_water := 0          # §6.B special-item drops on merge (collected at t1)
var drop_acorn := 0
var drop_open_coins := 0     # §6.B chest opened by a key → coins + acorns
var drop_open_acorns := 0
var treat_coins := 0         # §6.D treat-gen premium-line sells + its special drops
var treat_water := 0
var treat_acorn := 0
var acorns := 0              # acorn (premium) balance — previously unmodeled; the §6 faucets mint it
var merges := 0             # total board merges (drives special-drop volume)
var specials_crafted := 0   # #14/#16 special (merge-line) quests delivered — proves the craft path is live
var treat_gens := 0         # §6.D treat generators spawned over the run
var _pending_chests := 0    # banked special-drop chests (tap-opened — the key line is retired)
var _session_cap := 0       # this session's water budget = WATER_CAP + §6 water (lets the bot out-pop a bare cap)

# §1 LIVE RESIDENTS ECONOMY (the global Bucket) — replaces the dormant welcome-coin-SINK the older model used. The
# live loop: pay coins to run an EXPEDITION (the only coin SINK) → acquire spirits → PLACE into cap-limited
# habitat slots → they YIELD coins over time (idle production) + SELL for coins (both SOURCES). Modeled on
# map 0 (the only map whose habitat pays coins; maps 2-5 yield is parked). Abstraction: an expedition costs
# Explore.MIN_COST and yields EXP_SPIRITS t1 spirits; the Rush skill layer is collapsed (parked sim).
const EXP_SPIRITS := 2        # spirits an expedition yields (abstracts the Rush→boxes chain; provisional)
var hab0: Array = []          # placed spirit TIERS on map 0 (the coin habitat); rate = sum, cap = resident_capacity(0)
var expedition_spend := 0     # coins spent launching expeditions — the ONLY live residents coin SINK
var expeditions := 0          # expeditions run over the run
var habitat_yield := 0        # coins from idle production collected (a recurring SOURCE)
var habitat_sell := 0         # coins from selling un-housed spirits (a SOURCE)

var jams := 0
var merchant_sells := 0
var map_spend := {}           # map -> water spent while restoring it
var map_gift := {}            # map -> level-up water credited while in it
var open_low_mark := 999
var gates_reached := 0
var maps_done := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var days: int = int(args[0]) if args.size() >= 1 else 7
	rng.seed = int(args[1]) if args.size() >= 2 else 42
	Save.configure_for_test("user://grove_sim_%d_" % int(rng.seed))
	Save.reset()
	# 3rd arg "greedy" (or "g") flips the bot to the aggressive-welcome mode: it pours every
	# affordable coin/diamond into residents with no restoration cushion (stress-tests the sink).
	_greedy = args.size() >= 3 and String(args[2]).to_lower() in ["greedy", "g", "1", "true"]
	board = BoardModel.new()
	board.seed_gens(0)
	print("== Grove §7 pacing sim: %d days, 3 sessions/day, %d💧/session (seed %d, %s bot) ==" % [days, G.WATER_CAP, rng.seed, "GREEDY" if _greedy else "default"])

	var map_done_day := -1
	for day in days:
		_cur_day = day
		var day_coins_b := coins_earned      # lifetime coins at day start — the day line reports the delta
		var d_water := 0
		for _session in 3:
			_session_cap = G.WATER_CAP             # §6.B special-item water drops extend this in-session
			water = _session_cap
			_hab_collect()                         # §1 collect the live habitat's idle coin yield (a SOURCE)
			var r := _play_session()
			d_water += r.water
		if map_done_day < 0 and _book_done():
			map_done_day = day + 1
		if content_end_day < 0 and _level() >= G.zone_unlock_level(G.ZONE_COUNT - 1):
			content_end_day = day + 1
		if half_book_day < 0 and clusters_unlocked * 2 >= _cluster_total():
			half_book_day = day + 1
		print("  day %d: spent %d💧 · earned %d🪙 · L%d · deliv %d · page %d/%d · clusters %d/%d · pages-done %d · coins %d (quest %d/sell %d) · brambles %d" % \
			[day + 1, d_water, coins_earned - day_coins_b, _level(), _deliv_day, mini(map + 1, G.MAPS.size()), G.MAPS.size(), clusters_unlocked, _cluster_total(), gates_reached, coins, quest_coins, sell_coins, board.bramble_count()])
		_deliv_day = 0

	maps_done = gates_reached
	print("\n== results ==")
	print("  maps restored: %d/%d%s" % [maps_done, G.MAPS.size(),
		("  (runway: day %d)" % map_done_day) if map_done_day > 0 else "  (runway exceeds the %d-day window)" % days])
	print("  clusters unlocked: %d/%d (%d🪙 paid — the dominant sink) · pages completed: %d · level %d (%d🪙 earned lifetime)" % \
		[clusters_unlocked, _cluster_total(), cluster_spend, gates_reached, _level(), coins_earned])
	print("  merchant sells: %d · specials crafted: %d · open-cell low-water-mark: %d · jams: %d" % [merchant_sells, specials_crafted, open_low_mark, jams])
	print("  mastery ranks: %s" % _mastery_report())
	print("  level-up water gifts: %d💧 (the recurring water faucet, §4)" % level_gift_water)
	print("  PACING  curve base/step %d/%d · L%d at day %d · last content zone (L%d): %s · half the book: %s · whole book: %s" % \
		[G.LEVEL_BASE_COINS, G.LEVEL_STEP_COINS, _level(), days, G.zone_unlock_level(G.ZONE_COUNT - 1),
		 ("day %d" % content_end_day) if content_end_day > 0 else "NOT REACHED",
		 ("day %d" % half_book_day) if half_book_day > 0 else "NOT REACHED",
		 ("day %d" % map_done_day) if map_done_day > 0 else "NOT REACHED"])
	# THE SCENE LADDER, scene by scene — the pacing view that matters now the gates are derived: each
	# scene owns a LEVEL WINDOW (from its clusters' cumulative cost) and the zones that unlock inside it.
	# The health signal is that the last zone's day and the book's day are close, not 40 days apart.
	print("  SCENES  (level window · zones inside it · day completed)")
	var _zi := 0
	for _p in G.coverup_pages().size():
		var _win := G.scene_level_window(int(_p))
		var _zl: Array = []
		var _k := int(G.ZONE_BAND[_p]) if _p < G.ZONE_BAND.size() else 0
		for _j in _k:
			_zl.append("L%d" % G.zone_unlock_level(_zi))
			_zi += 1
		var _pg := int(G.coverup_pages()[_p])
		print("    scene %d %-22s L%d-%-3d · zones %-16s · %s" % [_p + 1, String(G.MAPS[_pg].get("name", "?")),
			int(_win.x), int(_win.y), str(_zl),
			("done day %d" % int(scene_done_day[_pg])) if scene_done_day.has(_pg) else "NOT COMPLETED"])
	var pass_all := true

	# --- STALL guard: if the bot barely spent any water over the WHOLE run, the early board never opened
	# up (a bootstrap stall — pre-2026-06-29 this hit ~50% of seeds; fixed by the quest_base_lines rework).
	# The economy RATIO checks below (Y sell-coins/100💧, I2 gift/spend, the water self-sustain line) divide
	# by that spend, so on a near-zero denominator they fire on noise — a spurious "income pump" FAIL (e.g.
	# 3 cleanup-sale coins / 7💧 = 42.9) or an equally meaningless PASS. Detect the degenerate run up front,
	# report it honestly as a STALL, and SKIP those ratio checks. Floor = 2 sessions' water; a healthy run
	# spends that on day 1 alone, a stall never reaches it. ---
	var total_water_spent := 0
	for z in map_spend:
		total_water_spent += int(map_spend[z])
	var stall_floor := 2 * G.WATER_CAP
	var stalled := total_water_spent < stall_floor
	if stalled:
		print("  FAIL STALL: the bot spent only %d💧 over the whole run (< %d floor = 2 sessions) — a bootstrap stall: the early board never opened up, so no maps could be restored. The spend-ratio checks (Y / I2 / water self-sustain) are not meaningful on so little spend and are skipped below." % [total_water_spent, stall_floor])
		pass_all = false

	# --- I1: no jams ---
	if jams > 0:
		print("  FAIL I1: %d jam(s) — a full, merge-less, deliver-less board occurred" % jams)
		pass_all = false
	else:
		print("  PASS I1: zero jams")

	# --- no-strand: gen_quest only ever asks LIVE lines (producible) and the board never jams,
	# so the bot can always earn ★ → level → unlock → buy spots. A map left partly bought at run
	# end is a RUNWAY signal (the restoration grind is long), not a strand. ---
	if jams == 0:
		print("  PASS no-strand: producible asks + a never-jammed board — the bot can always progress")
	if not _book_done():
		var rem := _next_cluster()
		print("  -- note: page %d still had clusters locked at run end (next: %s, %d🪙 at L%d; held %d🪙 at L%d) --" % \
			[int(rem.z) + 1, String(rem.id), int(rem.cost), G.cluster_min_level(int(rem.z), String(rem.id)), coins, _level()])

	# --- I2: per-map level-up water gift < ratio of that map's spend. The <30% anti-self-sustain
	# rule is a STEADY-STATE / late-game guardrail. Early maps (1-2) intentionally front-load water
	# to onboard (fast early level-ups, §3) AND now see burst-pop (§6) front-load energy SPEND into
	# the first map — leaving the low-volume early maps a high fixed-gift ratio on some seeds — so
	# maps 1-2 are a reported WARN; maps 3+ (steady-state) are the hard check. The holistic
	# gift-vs-spend rebalance (incl. the +50 gift, and now burst's front-loading) is the parked
	# "§7 economy tuning + pacing sign-off" pass — see BACKLOG. ---
	var i2_ftue_maps := 2                       # maps 1-2: low-volume early game — WARN, not FAIL
	var i2_ok := true
	# Report EVERY map's ratio, not just the breaches: the margin under 0.30 is what a pop-cost /
	# gift re-tune is steered by, and a bare "PASS I2" hides whether map 3 sits at 0.05 or 0.29.
	var i2_row: Array = []
	for z in (map_gift.keys() if not stalled else []):
		var sp: int = int(map_spend.get(z, 0))
		i2_row.append("m%d %d/%d=%.2f" % [int(z) + 1, int(map_gift.get(z, 0)), sp,
			(float(map_gift.get(z, 0)) / float(sp)) if sp > 0 else 999.0])
	if not i2_row.is_empty():
		print("  -- I2 per map (gift💧/spend💧=ratio, limit %.2f on maps %d+) --  %s" % \
			[G.WATER_REWARD_MAX_RATIO, i2_ftue_maps + 1, " · ".join(i2_row)])
	for z in (map_gift.keys() if not stalled else []):   # skip per-map ratios on a stall (tiny denominators)
		var spend: int = int(map_spend.get(z, 0))
		var gift: int = int(map_gift.get(z, 0))
		var ratio := (float(gift) / float(spend)) if spend > 0 else 999.0
		if gift > 0 and ratio >= G.WATER_REWARD_MAX_RATIO:
			if z < i2_ftue_maps:
				print("  WARN I2: early map %d gifts %d💧 vs spend %d💧 (ratio %.2f) — onboarding + burst front-loads spend; the <%.0f%% rule is steady-state (parked pacing pass)" % \
					[z + 1, gift, spend, ratio, G.WATER_REWARD_MAX_RATIO * 100])
			else:
				print("  FAIL I2: map %d gifts %d💧 vs spend %d💧 (ratio %.2f >= %.2f)" % \
					[z + 1, gift, spend, ratio, G.WATER_REWARD_MAX_RATIO])
				i2_ok = false
				pass_all = false
	if stalled:
		print("  -- I2: skipped — stalled run (%d💧 spent); per-map gift/spend ratios are not meaningful --" % total_water_spent)
	elif i2_ok:
		print("  PASS I2: every steady-state map (3+) keeps its water gift under %.0f%% of spend (early maps 1-2 noted above)" % (G.WATER_REWARD_MAX_RATIO * 100))

	# --- §6 NEW FAUCETS (B/C/D): the water/exp/coin/acorn the bonus generators, special drops, and treats add
	# ON TOP of quests + the level-gift. The exp arc (runway/level above) already reflects this exp; here we
	# surface the magnitude and the WATER self-sustain risk. NOTE: these water faucets BYPASS the level-gift,
	# so I2's gift-ratio no longer captures total water income — the self-sustain line below is the real
	# pinch check now. Reported as tuning signals (WARN, not hard fails — the §7 tuning pass owns the dials). ---
	var new_water := bonus_water + drop_water + treat_water
	var new_coins := bonus_coins + treat_coins + drop_open_coins
	var new_acorn := bonus_acorn + drop_acorn + treat_acorn + drop_open_acorns
	print("  -- §6 faucets --  water +%d💧 (bonus %d·drop %d·treat %d) · coins +%d🪙 (bonus %d·treat %d·chest %d) · acorn +%d🌰" % \
		[new_water, bonus_water, drop_water, treat_water, new_coins, bonus_coins, treat_coins, drop_open_coins, new_acorn])
	print("                 over %d merges · %d bonus-gens · %d treat-gens — §6 supplies %.0f%% of all coins earned (the rest is quests + sells)" % \
		[merges, bonus_gens, treat_gens, 100.0 * float(new_coins) / float(maxi(1, coins_earned))])
	# WATER self-sustain: gift + the §6 water faucets vs total spend. I2 guards the GIFT alone at <30%; these
	# faucets are ADDITIONAL income, so if (gift + §6) climbs toward spend the early water pinch is gone.
	var total_spend := 0
	for z in map_spend:
		total_spend += int(map_spend[z])
	var gift_plus_new := level_gift_water + new_water
	var sustain := 100.0 * float(gift_plus_new) / float(maxi(1, total_spend))
	if stalled:
		print("  -- water self-sustain: skipped — stalled run (%d💧 spent); gift-vs-spend ratio not meaningful --" % total_spend)
	elif sustain >= G.WATER_REWARD_MAX_RATIO * 100.0:
		print("  WARN water self-sustain: gift+§6 water %d💧 vs spend %d💧 (%.0f%% ≥ %.0f%%) — the §6 faucets erase the early water pinch; budget them against I2 in the tuning pass" % \
			[gift_plus_new, total_spend, sustain, G.WATER_REWARD_MAX_RATIO * 100.0])
	else:
		print("  PASS water self-sustain: gift+§6 water %d💧 vs spend %d💧 (%.0f%% < %.0f%%)" % \
			[gift_plus_new, total_spend, sustain, G.WATER_REWARD_MAX_RATIO * 100.0])

	# --- I3: runway (reported, not a hard fail — the full game is long by design, §3) ---
	if map_done_day > 0:
		print("  -- I3 runway: all maps restored by day %d --" % map_done_day)
	else:
		print("  -- I3 runway: %d/%d clusters in %d days (full restoration is a long arc, §3) --" % [clusters_unlocked, _cluster_total(), days])

	# --- Y: selling is cleanup, never income (sell-coins only) + the water↔💎 round trip ---
	var gems_earned := gems_from_levels + gems_from_maps + gems_from_sells + gems_from_quests
	var total_water := 0
	for z in map_spend:
		total_water += int(map_spend[z])
	var scpw := (float(sell_coins) * 100.0 / float(total_water)) if total_water > 0 else 0.0
	print("  -- Y clock --  💎 earned: %d · clock 🪙 %d (quest) vs spendable 🪙 %d (sell %d + pickups/gifts %d) · SELL-coins/100💧: %.1f (signal only now) · earn-1💎=%d💧 vs buy=%d💧 (>=10x)" % \
		[gems_earned, coins_earned, coins_spendable, sell_coins, coins_spendable - sell_coins, scpw, G.water_to_earn_diamond(), G.water_a_diamond_buys()])
	# THE CLOCK IS QUESTS ONLY — the hard check is now STRUCTURAL, not a ratio: every coin that advanced the
	# level clock must have come from delivering a quest. Any other path leaking into coins_earned (a sell, a
	# pickup, a gift, habitat yield) is a real regression, and no amount of junk-selling can level the player.
	# The sell/100💧 ratio stays PRINTED as a board-hygiene signal (how much stock retires unused), not a fail.
	if coins_earned != quest_coins:
		print("  FAIL Y: %d🪙 advanced the clock but only %d🪙 came from quests — a non-quest coin path is leaking into progression" % [coins_earned, quest_coins])
		pass_all = false
	else:
		print("  PASS Y: the clock advanced on quest coins ALONE (%d🪙); %d🪙 of sells/pickups/gifts stayed spendable-only" % [coins_earned, coins_spendable])
	if G.water_to_earn_diamond() < 10 * G.water_a_diamond_buys():
		print("  FAIL Y: the water<->diamond round trip is abusable (<10x loss)")
		pass_all = false

	# --- Z: coin faucet vs sink — the §8 hub yield/upgrade ladder is DELETED; the standing sink is now
	# the §1 POPULATION loop (welcoming residents on completed maps), which has NO roster cap, so it is
	# the new ENDLESS sink (the bot re-buys base feeders forever to climb resident tiers). The faucet =
	# quest + sell + drops/featured; the sinks = the resident-welcome spend + the (finite) burst ladder.
	# REPORTED; the absorption ratio is a tuning signal (the population invariants P1/P2 below are the
	# hard checks). ---
	var other_coins := coins_spendable - sell_coins               # §6 drops/chests/treats + §1 habitat yield/sell
	var faucet := coins_earned + coins_spendable
	var coin_sink := boost_coins_spent + expedition_spend + cluster_spend
	print("  -- Z coins --  faucet %d🪙 = CLOCK %d (quest) + SPENDABLE %d (sell %d + other %d, incl. §1 habitat yield %d / sell %d) · held %d🪙" % \
		[faucet, coins_earned, coins_spendable, sell_coins, other_coins, habitat_yield, habitat_sell, coins])
	print("                 sink %d🪙 = clusters %d🪙 + boosts %d🪙 (%d) + expeditions %d🪙 (%d run) → absorbs %.0f%% of the faucet" % \
		[coin_sink, cluster_spend, boost_coins_spent, boosts_bought, expedition_spend, expeditions, minf(100.0, 100.0 * float(coin_sink) / float(maxi(1, faucet)))])

	# --- D: the DIAMOND economy (previously unmodeled). Faucet = level-ups (LEVEL_DIAMONDS) +
	# map-restores (MAP_DIAMONDS) + t8-pinnacle sells (flat 1💎); sink = premium signature residents
	# (RESIDENT_PREMIUM_COST each). REPORTED as a ledger — the premium sink is gated behind completing
	# a map, so an early/short run may show 0 spend (the faucet leads the sink, by design). ---
	print("  -- D diamonds --  faucet %d💎 (levels %d + maps %d + t8-sells %d + quests %d) · sink %d💎 (%d premium residents) · balance %d💎" % \
		[gems_earned, gems_from_levels, gems_from_maps, gems_from_sells, gems_from_quests, resident_gems_spent, residents_premium, diamonds])
	print("                 NOTE the premium SINK reads 0 by construction: it models the retired per-map WELCOME roster")
	print("                 (MAPS[z].spots, now save-compat legacy), so this ledger is faucet-only until the parked")
	print("                 §5 bucket economy pass re-authors the live premium sink. Do not read 0 as a finding.")

	# --- §1 RESIDENTS economy — REALIGNED to the LIVE Bucket (was: the dormant welcome-roster modeled as an
	# ENDLESS coin sink). The live loop is the OPPOSITE: an EXPEDITION (Explore.MIN_COST) is the only coin
	# SINK and it STOPS once the habitat fills, while placed spirits YIELD coins forever (idle production) and
	# SELL for coins. So the question flips from "does the sink absorb the faucet?" to "are residents a net
	# coin SINK or a net FAUCET?" — a net faucet means the game still has NO standing coin sink (P1 unsolved).
	var res_source := habitat_yield + habitat_sell
	var res_net := res_source - expedition_spend          # > 0 ⇒ residents are a net coin FAUCET
	print("  -- §1 residents --  SINK expeditions %d🪙 (%d run; stop when the habitat fills) · SOURCE yield %d🪙 + sell %d🪙 = %d🪙 · NET %s%d🪙" % \
		[expedition_spend, expeditions, habitat_yield, habitat_sell, res_source, ("+" if res_net >= 0 else ""), res_net])
	# P1 — the late-game standing-sink check, re-derived. With the live model residents ADD coins (idle yield),
	# so res_net > 0 means there is NO endless coin sink and late coins pile. REPORTED (not a hard fail): this
	# is the realignment finding the economy pass must answer, not a sim bug.
	if res_net > 0:
		print("  WARN P1: residents are a NET COIN FAUCET (+%d🪙) — the live Bucket idle-yield ADDS coins; the expedition cost only drains during the slot ramp, so there is NO standing coin sink (late-game coins pile %d🪙 held). The economy needs a real sink (cosmetics/upgrades/events)." % [res_net, coins])
	else:
		print("  PASS P1: residents are a net coin SINK (%d🪙) — expeditions out-drain the habitat yield+sell." % res_net)

	# P2 — early-game no dead-zone: at the first completion, did the surplus have somewhere to go (the boost
	# ladder + the expedition entry cost)? A pile beyond those early sinks is the early coin gap.
	if first_complete_day > 0:
		var early_sink := G.BOOST_COST * 4 + Explore.MIN_COST * 2
		var pre_pop_pile := balance_at_first_complete
		if pre_pop_pile <= early_sink:
			print("  PASS P2: at the first completion the held pile (%d🪙) stayed within the early sinks (boosts + expedition, %d🪙) — no early coin dead-zone" % [pre_pop_pile, early_sink])
		else:
			print("  WARN P2: at the first completion the bot held %d🪙 — beyond the early sinks (%d🪙); early coins pile (raise the expedition cost or open it sooner)" % [pre_pop_pile, early_sink])
	else:
		print("  -- P2: no completion in the %d-day window — no pre/post boundary to check (see I3 runway) --" % days)

	print("== sim %s ==" % ("PASS" if pass_all else "FAIL"))
	quit(0 if pass_all else 1)

# --- the bot -----------------------------------------------------------------------

# THE COIN CLOCK (2026-07-25 re-spine). Level derives from LIFETIME ORGANIC coin earnings, exactly as
# the live game does (content.level() → level_at_coins(Save.coins_earned_lifetime())). The sim has no
# purchases, so every coin it books is organic — which is why ALL coin income must route through
# _earn_coins, never straight into `coins`, or the clock silently runs slow.
func _level() -> int:
	return G.level_at_coins(coins_earned)

func _live_lines() -> Array:
	# Quest asks draw from the ACTIVE-LINE WINDOW reached by level progress. This deliberately does not
	# depend on restored spots, so earning exp can reveal newer asks even if the player delays claiming
	# zones. Base and crafted-special lines share the window (§7, 2026-07-25).
	return G.active_lines(_level())

func _mastery_report() -> String:
	var parts: Array = []
	for line in G.ZONE_BASE_LINES:
		parts.append("%d:r%d/%d" % [int(line), Mastery.rank(int(line)), Mastery.meter(int(line))])
	return ", ".join(parts)

# Credit `amount` ORGANIC coins and fire any level-ups: each level gifts LEVEL_WATER_GIFT water (topped up
# within the session budget _session_cap) + LEVEL_DIAMONDS, attributed to the current page's gift (I2).
# THE SINGLE COIN-INCOME DOOR — quest rewards, sells, coin pickups, bonus gens, chests, treats and habitat
# yield all come through here, so `coins` (the spendable balance), `coins_earned` (the lifetime organic
# total that IS the clock) and the level-up gifts can never drift apart. Spending touches `coins` only.
# THE CLOCK IS QUESTS ONLY (owner call 2026-07-25). _earn_coins is the QUEST door: it credits the wallet
# AND coins_earned (the level clock), mirroring Save.earn_coins. _gain_coins below is every other coin —
# selling, pickups, chests, treats, habitat yield — spendable but NEVER clock-advancing (Save.add_coins).
func _gain_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	coins_spendable += amount

func _earn_coins(amount: int) -> void:
	if amount <= 0:
		return
	var lvl_b := _level()
	coins += amount
	coins_earned += amount
	if _level() > lvl_b:
		var up := _level() - lvl_b
		water = mini(_session_cap, water + G.LEVEL_WATER_GIFT * up)
		level_gift_water += G.LEVEL_WATER_GIFT * up
		if not _book_done():        # don't attribute gift past the book's end (no spend there → false I2 fail)
			map_gift[map] = int(map_gift.get(map, 0)) + G.LEVEL_WATER_GIFT * up
		diamonds += G.LEVEL_DIAMONDS * up
		gems_from_levels += G.LEVEL_DIAMONDS * up

# §6.C BONUS GENERATORS (gen redesign 2026-06-28) — replaces the retired constant-accrual accumulators.
# A main-generator tap (the burst block in _play_session) MAY side-spawn a limited-use bonus generator
# (G.rolls_bonus_spawn — the ~3% band), ONE at a time. Each grants G.bonus_value(kind) per tap for a random
# G.pick_bonus_clicks budget, then VANISHES. The bot drains the live one (one collect-tap per main-gen tap)
# before a new one can spawn — exactly the live "one at a time" lockout, so the spawn rate is suppressed
# while a gen is outstanding. Kind is uniform over all 4 (ungated by unlocks now; unlock_spot is vestigial).
# Conservative: collected at mult 1 (live multiplies by the burst count while a boost is live — not stacked).
func _tick_bonus_gen() -> void:
	if _bonus_clicks > 0:                                # a live bonus gen on the board → drain one tap
		var amount := G.bonus_value(_bonus_kind)
		match _bonus_kind:
			"water":
				water = mini(G.WATER_CAP, water + amount)   # caps at WATER_CAP, like the live _collect_accumulator
				bonus_water += amount
			"coins":
				_gain_coins(amount)
				bonus_coins += amount
			"acorn":
				acorns += amount
				bonus_acorn += amount
		_bonus_clicks -= 1
		if _bonus_clicks <= 0:                           # spent its budget → it vanishes (a new one may now spawn)
			_bonus_kind = ""
		return
	if G.rolls_bonus_spawn(rng):                         # no live one → this tap may side-spawn a fresh bonus gen
		_bonus_kind = G.pick_bonus_kind(rng)
		_bonus_clicks = G.pick_bonus_clicks(rng)
		bonus_gens += 1

# A §6.B special item shaken loose by a merge (or a treat tap). Modeled at its t1 collect value — a
# conservative FLOOR (real play merges drops up first). water → extends the session pop-budget; exp → the
# exp faucet (levels up); acorn → premium. chest+key pair and OPEN for coins+acorns (paired across drops).
func _credit_special_drop(code: int, src: String = "drop") -> void:
	match G.special_kind(code):
		"water":
			var a := int(G.special_collect(code).amount)
			_session_cap += a
			water += a
			if src == "treat": treat_water += a
			else: drop_water += a
		"acorn":
			var a := int(G.special_collect(code).amount)
			acorns += a
			if src == "treat": treat_acorn += a
			else: drop_acorn += a
		"chest":
			_pending_chests += 1
			_try_open_chest()
		_:
			pass

# Open a banked chest for coins+acorns (t1 — conservative). Models the §6.B tap-open chest
# (the key line is retired) without board placement.
func _try_open_chest() -> void:
	while _pending_chests >= 1:
		_pending_chests -= 1
		var rw := G.chest_open_reward(10 * 100 + 1)
		_gain_coins(int(rw.coins))
		drop_open_coins += int(rw.coins)
		acorns += int(rw.acorns)
		drop_open_acorns += int(rw.acorns)

# §6.D a temporary treat generator: TREAT_CLICKS taps, each popping the map's treasure line at the
# head-start tier (TREAT_POP_TIER) and TREAT_DROP_RATE of the time shaking a §6.B special loose. The
# treasure items are merged up + sold at the premium band; we credit a conservative per-tap sell at the
# POP tier (real play merges them higher) plus the special drops.
func _run_treat_gen() -> void:
	treat_gens += 1
	var clicks := G.pick_treat_clicks(rng)
	var line := G.pick_treat_line(map)
	for _c in clicks:
		var sell := int(G.sell_reward(line * 100 + G.TREAT_POP_TIER).x)
		_gain_coins(sell)
		treat_coins += sell
		if rng.randf() < G.TREAT_DROP_RATE:
			_credit_special_drop(G.pick_special_drop(rng), "treat")

# --- §1 LIVE RESIDENTS (Bucket) coin loop: expedition SINK + idle-yield/sell SOURCE ----------------
func _hab_rate() -> int:
	var r := 0
	for t in hab0:
		r += int(t)
	return r

# Bucket capacity right now — ONE cell per COMPLETED map (mirrors content.cells_from_scenes:
# one habitat cell per fully-unlocked scene; the sim models scene completion as all-spots-bought).
# Habitat cells come from COMPLETED COVER-UP SCENES (content.cells_from_scenes) — the live global bucket's
# only capacity source, replacing the retired per-map roster count.
func _hab_cap() -> int:
	return G.cells_from_scenes(unlocks)

# Cascade 2-of-a-tier → one a tier up (mirrors the hand/auto merge), raising rate + freeing a slot.
func _hab_merge() -> void:
	var changed := true
	while changed:
		changed = false
		for tier in range(1, G.RESIDENT_MAX_TIER):
			var same: Array = []
			for i in hab0.size():
				if int(hab0[i]) == tier:
					same.append(i)
			if same.size() >= 2:
				hab0.remove_at(same[1]); hab0.remove_at(same[0])
				hab0.append(tier + 1)
				changed = true
				break

# One session's idle-production collect (map 0 pays coins): a full accrual cap, per check-in. The cap (in
# coins) = (3 + Σtier) × MULT — Σtier (sum of placed tiers) drives both speed and cap; the per-map MULT scales.
func _hab_collect() -> void:
	var stier := _hab_rate()
	if stier <= 0:
		return
	var lc: Dictionary = RB.DEFAULTS["lines"]["coin"]
	var hy := int(floor(float(lc.bank_base) + float(lc.bank_per_tier) * float(stier)))
	if hy > 0:
		_gain_coins(hy)
		habitat_yield += hy

# Launch an expedition: pay the base cost (the SINK), acquire EXP_SPIRITS t1 spirits, PLACE what fits in
# map-0's cap (then auto-merge), SELL the overflow (a small SOURCE).
func _run_expedition() -> void:
	if coins < Explore.MIN_COST:
		return
	coins -= Explore.MIN_COST
	expedition_spend += Explore.MIN_COST
	expeditions += 1
	for _s in EXP_SPIRITS:
		if hab0.size() < _hab_cap():
			hab0.append(1)
			_hab_merge()
		else:
			var sv := RB.SELL_PER_TIER * 1
			_gain_coins(sv)
			habitat_sell += sv

# --- §1 POPULATION (DORMANT welcome-roster — kept only for the unlock-gift grant; NOT the live sink) ---
# The sim keeps its OWN resident roster (residents[z] = {type_id -> [t1..tMAX]}) rather than
# driving Save, but mirrors content.gd's welcome + auto-merge math exactly: welcome adds a t1,
# then two-of-a-kind cascade up to RESIDENT_MAX_TIER. Cost is read off G.resident_cost (coins for
# core/non-premium, diamonds for the per-map premium signature).

# The list of COMPLETED maps (all spots bought) — used for the diamond/map-reward bookkeeping.
func _completed_maps() -> Array:
	var out: Array = []
	for z in G.MAPS.size():
		if _page_done(z) and gates_done.has(z):
			out.append(z)
	return out

# §1 EARLY POPULATION (prototype): how many of map z's spots are restored — drives both when its roster
# OPENS (≥1) and its CAPACITY (1 at the first spot → POP_SLOTS_MAX at all spots).
func _spots_restored(z: int) -> int:
	var n := 0
	for sp in G.MAPS[z].spots:
		if unlocks.has(String(sp.id)):
			n += 1
	return n

# A map is welcomeable once its FIRST spot is restored (not full completion — the early sink that closes P2).
func _populatable_maps() -> Array:
	var out: Array = []
	for z in G.MAPS.size():
		if _spots_restored(z) >= 1:
			out.append(z)
	return out

# The resident SLOT capacity on map z: 1 at the first restored spot, scaling linearly to POP_SLOTS_MAX
# once every spot is restored. 0 while nothing is restored (roster not open yet).
func _resident_capacity(z: int) -> int:
	var total := int(G.MAPS[z].spots.size())
	var done := _spots_restored(z)
	if done <= 0 or total <= 0:
		return 0
	if total <= 1:
		return POP_SLOTS_MAX
	return 1 + int(floor(float(POP_SLOTS_MAX - 1) * float(done - 1) / float(total - 1)))

# The total resident TOKENS currently on map z (every type, every tier) — what the capacity caps. Merges
# REDUCE this (2→1), so climbing tiers frees slots; a roster of all-max-tier tokens at cap is saturated.
func _resident_tokens(z: int) -> int:
	if not residents.has(z):
		return 0
	var n := 0
	for tid in residents[z]:
		for c in residents[z][tid]:
			n += int(c)
	return n

# The roster array for (map z, type_id), defaulting to all-zero counts (length RESIDENT_MAX_TIER).
func _resident_counts(z: int, type_id: String) -> Array:
	if not residents.has(z):
		residents[z] = {}
	if not residents[z].has(type_id):
		var zero: Array = []
		for _i in G.RESIDENT_MAX_TIER:
			zero.append(0)
		residents[z][type_id] = zero
	return residents[z][type_id]

# Resolve cascading two-of-a-kind merges for (z, type_id) in place — mirrors resolve_resident_merges.
# Returns the number of merge events fired.
func _resolve_merges(z: int, type_id: String) -> int:
	var counts: Array = _resident_counts(z, type_id)
	var fired := 0
	for tier in range(1, G.RESIDENT_MAX_TIER):     # 1..(MAX-1): the top tier never merges further
		while int(counts[tier - 1]) >= 2:
			counts[tier - 1] = int(counts[tier - 1]) - 2
			counts[tier] = int(counts[tier]) + 1
			fired += 1
	return fired

# Welcome one t1 resident of type_def on completed map z, paying from the sim wallet (coins or
# diamonds). Mirrors content.gd.welcome_resident: charge → add a t1 → cascade merges. Returns true
# on a successful welcome (funds available), false when broke for that currency.
func _welcome(z: int, type_def: Dictionary) -> bool:
	var cost: Dictionary = G.resident_cost(type_def)
	var premium := String(cost.currency) == "diamonds"
	var amt := int(cost.cost)
	if premium:
		if diamonds < amt:
			return false
		diamonds -= amt
		resident_gems_spent += amt
		residents_premium += 1
	else:
		if coins < amt:
			return false
		coins -= amt
		resident_coins_spent += amt
	var counts: Array = _resident_counts(z, String(type_def.id))
	counts[0] = int(counts[0]) + 1
	residents_welcomed += 1
	resident_merges += _resolve_merges(z, String(type_def.id))
	return true

# The cheapest BASE (coin) resident the bot can welcome on any completed map, given the coin balance,
# or {} when none affordable / no completed map. Premium picks are handled separately (diamonds).
func _next_base_welcome() -> Dictionary:
	for z in _populatable_maps():
		if _resident_tokens(z) >= _resident_capacity(z):   # roster full at the current capacity
			continue
		for td in G.resident_lines(z):
			if bool(td.get("premium", false)):
				continue
			if coins >= int(G.resident_cost(td).cost):
				return {"z": z, "def": td}
	return {}

# The cheapest PREMIUM (diamond) resident the bot can welcome on any populatable map with room, or {}.
func _next_premium_welcome() -> Dictionary:
	for z in _populatable_maps():
		if _resident_tokens(z) >= _resident_capacity(z):
			continue
		for td in G.resident_lines(z):
			if not bool(td.get("premium", false)):
				continue
			if diamonds >= int(G.resident_cost(td).cost):
				return {"z": z, "def": td}
	return {}

# --- THE CLUSTER LADDER (2026-07-25 re-spine) ---------------------------------------------------------
# Restoration is the GLOBAL cover-up cluster sequence, not the retired free spot ladder. Each cluster is
# gated by BOTH a level floor (cluster_min_level, DERIVED from the ladder's cumulative cost) AND that cost
# — so the ladder is the game's dominant coin SINK, and `map` here means the page currently being unlocked
# (content.current_unlock_map), not a map being "bought out". MAPS[z].spots is save-compat legacy: page 1
# still carries a list, pages 2-5 are empty, so the old spot loop was simulating nothing on 4 of 5 pages.

# The next cluster in the global order: {z, id, cost}; {} once the whole book is unlocked.
func _next_cluster() -> Dictionary:
	var z := G.current_unlock_map(unlocks)
	var id := G.next_locked_cluster(z, unlocks)
	if id == "":
		return {}
	return {"z": z, "id": id, "cost": G.cluster_cost(z, id)}

func _book_done() -> bool:
	return _next_cluster().is_empty()

# Every cluster of page z unlocked.
func _page_done(z: int) -> bool:
	return G.next_locked_cluster(z, unlocks) == ""

# The page the bot is currently unlocking is finished but not yet credited — the completion trigger
# (diamond gift + habitat cell) the old spots-done check used to fire.
func _page_done_pending() -> bool:
	return _page_done(map) and not gates_done.has(map)

# Total clusters in the book (the denominator for the ladder progress report).
func _cluster_total() -> int:
	var n := 0
	for z in G.coverup_pages():
		n += G.clusters(int(z)).size()
	return n

# Refill the fence — by CALLING THE LIVE ENGINE (Quests.refill), not a mirror of it. The sim used to
# re-implement refill plus its four helpers (_cap_quests_per_line / _line_capacity / _lines_with_room /
# _quest_line_counts); the copy drifted from quests.gd (it lost the recent-items avoid window and paid
# every reward at BAND 0), so the economy was being tuned against a model the shipped game no longer
# matched. Arguments mirror the live call site, board.gd _refill_quests:
#   band  = Quests.current_band(level)   — board.gd _quest_map(); drives the per-band coin curve
#   earned= coins_earned                 — board.gd _earned() = Save.coins_earned_lifetime()
#   level = _level()                     — board.gd _quest_level() = G.level() (the coin clock)
#   recent_items = _recent_items         — the ≤5 anti-monotony window the sim now keeps on delivery
func _refill_quests() -> void:
	live_quests = Quests.refill(live_quests, Quests.current_band(_level()), board.gens, board.gen_bag,
		coins_earned, _level(), rng, _recent_items)

func _wanted_lines() -> Array:
	var out: Array = []
	for q in live_quests:
		var it := G.quest_item(q)
		if it.is_empty():
			continue
		for li in _quest_pop_lines(int(it.line)):   # a special expands to its two ingredient base lines (what's popped)
			if not out.has(int(li)):
				out.append(int(li))
	return out

# The base lines the bot must POP to satisfy a quest: the line itself (a base ask), or its two ingredient
# base lines (a SPECIAL ask — the special has no generator; it is CRAFTED from the ingredients, Core §6.G).
func _quest_pop_lines(line: int) -> Array:
	if G.gen_for_line(int(line)) != "":
		return [int(line)]
	# RECURSE to the BASE lines (mirrors G.gens_for_quest_line). An ingredient may itself be a special with
	# no generator — tea cups (19) <- spices (8) <- wild berries + woolens — and a special can never be
	# popped, only crafted. Returning [8, 2] made the sim pop line 8 directly, fabricating an item no
	# generator in the game can produce (the board ended runs holding L8.t1..t9).
	var out: Array = []
	for il in G.zone_recipe(G.zone_of_line(int(line))):
		for b in _quest_pop_lines(int(il)):
			if not out.has(int(b)):
				out.append(int(b))
	return out

# §6 mirror of BoardLogic.wanted_tiers: the poppable asked tiers per pool line — so the sim's
# spawn applies the same line-AND-tier bias the live board does, and validates its economy.
func _wanted_tiers(pool: Array) -> Dictionary:
	var out: Dictionary = {}
	for q in live_quests:
		var it := G.quest_item(q)
		if it.is_empty():
			continue
		var t := int(it.tier)
		if t < 1 or t > G.TIER_ODDS.size():
			continue
		for li in _quest_pop_lines(int(it.line)):   # a special biases the pop tier on its ingredient lines
			if pool.has(int(li)):
				if not out.has(int(li)):
					out[int(li)] = []
				if not out[int(li)].has(t):
					out[int(li)].append(t)
	return out

func _payable(q: Dictionary) -> bool:
	var it := G.quest_item(q)
	var line := int(it.line)
	var tier := int(it.tier)
	if G.gen_for_line(line) == "":   # a SPECIAL → craftable once BOTH ingredient base lines sit at the asked tier
		var r := G.zone_recipe(G.zone_of_line(line))
		return r.size() == 2 and board.count_of(int(r[0]) * 100 + tier) >= 1 and board.count_of(int(r[1]) * 100 + tier) >= 1
	return board.count_of(line * 100 + tier) >= 1

func _play_session() -> Dictionary:
	var s_coins := 0
	var s_water := 0
	var guard := 0
	while guard < 8000:
		guard += 1
		open_low_mark = mini(open_low_mark, board.empty_ground_cells().size())
		_refill_quests()

		# 0. PAGE COMPLETION: a cover-up page ends when every one of its clusters is unlocked. This is the
		# diamond-gift + habitat-cell trigger (cells_from_scenes grants one cell per completed page).
		if _page_done_pending():
			gates_done[map] = true
			gates_reached += 1
			if not scene_done_day.has(map):
				scene_done_day[map] = _cur_day + 1
			# §1 diamond FAUCET: fully restoring a page gifts MAP_DIAMONDS.
			diamonds += G.MAP_DIAMONDS
			gems_from_maps += G.MAP_DIAMONDS
			# P1/P2 seam: the FIRST completion is where population OPENS — snapshot the coin
			# faucet/sink so the late-game no-pile (P1) check measures the post-population window.
			if first_complete_day < 0:
				first_complete_day = _cur_day + 1
				coins_at_first_complete = coins_earned       # cumulative INTAKE, not the drained balance
				balance_at_first_complete = coins            # the held pile pre-population (for P2)
				resident_spend_at_first_complete = resident_coins_spent
			map = G.current_unlock_map(unlocks)   # the frontier moves to the next page in the book
			continue

		# 1. deliver any payable regular quest — pay its reward, then erase it from the fence.
		var delivered := false
		for q in live_quests:
			if not _payable(q):
				continue
			var it := G.quest_item(q)
			if G.gen_for_line(int(it.line)) == "":   # craft + deliver a special: consume BOTH ingredient base items
				var r := G.zone_recipe(G.zone_of_line(int(it.line)))
				board.take(board.first_item_of(int(r[0]) * 100 + int(it.tier)))
				board.take(board.first_item_of(int(r[1]) * 100 + int(it.tier)))
				Mastery.credit_craft(int(r[0]) * 100 + int(it.tier), int(r[1]) * 100 + int(it.tier))
				specials_crafted += 1
			else:
				board.take(board.first_item_of(int(it.line) * 100 + int(it.tier)))
				Mastery.credit_delivery(int(it.line) * 100 + int(it.tier))
			# The reward is COINS ONLY (quest_reward_for_line) — the old {exp, coins} pair is retired with
			# the exp clock, and coins ARE the clock now, so _earn_coins is what fires the level-ups.
			var rw: Dictionary = q.reward
			var got := int(rw.coins)
			s_coins += got
			quest_coins += got
			# (quests pay NO acorns now — acorns are milestone/IAP only, Option A)
			_earn_coins(got)
			_deliv_day += 1
			# §7 anti-monotony window — mirrors BoardActions.deliver_quest: remember this ask (≤5) so the
			# next few generated quests steer off it. Quests.refill reads this list.
			_recent_items.append(int(it.line) * 100 + int(it.tier))
			while _recent_items.size() > 5:
				_recent_items.pop_front()
			live_quests.erase(q)
			delivered = true
			break
		if delivered:
			continue

		# 1b. SINK surplus coins. Live sinks: the repeatable §6 BOOST (re-armed whenever none is live), and the
		# §1 EXPEDITION (pay Explore.MIN_COST to acquire spirits) — the ONLY live residents coin sink. The bot
		# runs an expedition only while map-0's habitat has ROOM to place (once full, an expedition is pure loss
		# — a rational player stops, so the sink STOPS and the habitat just keeps YIELDING coins). This is the
		# realignment: the old welcome-roster sink is dormant; the live loop is acquire(sink)→place→yield(source).
		var net := coins - boost_coins_spent
		if boost_taps <= 0 and net >= G.BOOST_COST:
			boost_coins_spent += G.BOOST_COST
			boost_taps = G.BOOST_TAPS
			boosts_bought += 1
			continue
		# §1 EXPEDITION — the live residents coin SINK: pay Explore.MIN_COST to acquire spirits, only while
		# map-0's habitat has ROOM to place (once full, an expedition is pure loss, so a rational player stops —
		# the sink STOPS and the habitat just keeps YIELDING). Draining surplus here (vs post-session) also keeps
		# the boost from over-fuelling on the big habitat-coin faucet.
		if hab0.size() < _hab_cap() and coins >= Explore.MIN_COST + (0 if _greedy else G.BOOST_COST):
			_run_expedition()
			continue

		# 2. restore: UNLOCK the next cover-up cluster once its level floor is reached AND it is affordable
		# — and PAY its cost (the game's dominant coin sink). Unlocking a page's last cluster makes the page
		# done; step 0 credits completion next iteration.
		var nc := _next_cluster()
		if not nc.is_empty() and G.cluster_ready(int(nc.z), String(nc.id), unlocks, _level(), coins):
			coins -= int(nc.cost)
			cluster_spend += int(nc.cost)
			clusters_unlocked += 1
			unlocks[String(nc.id)] = true
			# Do NOT advance `map` here — step 0 must first see the page it just finished and credit its
			# completion (diamond gift + habitat cell). Advancing on the spot skips that page forever.
			continue

		# 3. sell tops for coins (no gate to hoard top-tier for now — selling is pure cleanup/coins)
		var tops := board.top_tier_cells()
		if not tops.is_empty():
			var rw := G.sell_reward(board.item_at(tops[0]))
			board.take(tops[0])
			_gain_coins(rw.x)
			sell_coins += rw.x                 # every tier sells for COINS now (no premium pinnacle, Option A)
			merchant_sells += 1
			continue

		# 4. collect coins
		var coin_cell := _first_coin()
		if coin_cell != Vector2i(-1, -1):
			var cv := G.coin_value(board.take(coin_cell))
			_gain_coins(cv)
			continue

		# 4b. clear RETIRED-line clutter — old-map items no live quest can ever want (a line
		# not in the current map's set). A real player sells this stock off; the bot does too,
		# or the board clogs after a map transition and can't grow the new lines (cleanup, coins).
		var junk := _first_clutter()
		if junk != Vector2i(-1, -1):
			var rwj := G.sell_reward(board.item_at(junk))
			board.take(junk)
			_gain_coins(rwj.x)
			sell_coins += rwj.x
			merchant_sells += 1
			continue

		# 5. merge (prefer wanted lines, lowest tier; dst beside an openable bramble)
		var pair := _best_pair()
		if not pair.is_empty():
			var produced: int = board.merge(pair[0], pair[1])
			merges += 1
			for br in board.openable_brambles(pair[1], _level()):
				board.open_bramble(br)
			if not G.is_coin(produced) and rng.randf() < G.COIN_DROP_RATE:
				var empt := board.empty_ground_cells()
				if not empt.is_empty():
					board.place(empt[rng.randi_range(0, empt.size() - 1)], G.COIN_LINE * 100 + 1)
			# §6.B a merge sometimes shakes a special item loose (modeled by collect-yield, not placed)
			if G.rolls_special_drop(rng):
				_credit_special_drop(G.pick_special_drop(rng))
			continue

		# 6. pop — one tap throws a BURST (§6): burst_count items (scales with map + the live boost),
		# each costing G.pop_cost(window low) — G.POP_COST for an unmastered line, more once mastery
		# raises the line's pop window (§3 tier-scaled cost). A charged tap spends one boost tap (the
		# boost is global and decays one tap at a time, then lapses).
		# pop only with working ROOM — a real player never bursts into a near-full board (that just floods it
		# into a singleton lockout). Leave a 2-cell margin; surplus water the board can't absorb is left
		# UNSPENT (a realistic "energy I can't use right now"), never forced into a jam.
		if water >= G.POP_COST and board.empty_ground_cells().size() > 3 and not _book_done():
			var burst: int = G.burst_count(map, G.BOOST_BONUS if boost_taps > 0 else 0, rng)
			if boost_taps > 0:
				boost_taps -= 1
			# Clamp by the CHEAPEST a pop can be (G.POP_COST) first — that is the old clamp exactly, so an
			# unmastered run never enters _pop unaffordably and its RNG stream is untouched. A mastered
			# line can cost more than the floor, so _pop re-checks against the live can and returns 0.
			burst = mini(burst, int(water / G.POP_COST))
			burst = mini(burst, board.empty_ground_cells().size() - 2)   # keep a 2-cell working margin
			var popped := 0
			for _b in burst:
				# the bot picks a line per item (single-generator model), so the cost is per item too:
				# _pop charges what its own window costs and returns 0 rather than overdraw the can.
				var cost := _pop(water)
				if cost <= 0:
					break
				popped += 1
				water -= cost
				s_water += cost
				map_spend[map] = int(map_spend.get(map, 0)) + cost
			# A tap that popped NOTHING (every line's mastered window costs more than the can still holds)
			# is not a tap: the board wobbles and returns. It must not tick the §6 faucets, and it must not
			# re-enter this branch with the state unchanged — that spins the guard loop and mints phantom
			# bonus generators (measured: 509 of them, dragging §6 to 98% of all coins earned). Falling
			# through ends the session with the unspendable remainder left in the can, as designed above.
			if popped > 0:
				# §6.D each main-generator tap may spawn a temporary treat generator (run to completion here)
				if G.rolls_treat_spawn(rng):
					_run_treat_gen()
				# §6.C each main-generator tap also drains the live bonus generator, or may side-spawn a fresh one
				_tick_bonus_gen()
				continue

		# 7. nothing to do
		if water > 0 and board.empty_ground_cells().is_empty() and not _book_done():
			jams += 1
		break

	return {"coins": s_coins, "water": s_water}

func _first_coin() -> Vector2i:
	for i in board.items.size():
		if board.items[i] > 0 and G.is_coin(board.items[i]):
			return BoardModel.cell_of(i)
	return Vector2i(-1, -1)

# A board item whose line has RETIRED (not in the current map's live lines) — pure clutter.
# Clutter = an item NO live ask can ever use. The test must be the live NEEDED-LINES expansion
# (G.quest_needed_lines — the same read behind the board's item grey / generator fade / bag breathe),
# not the raw active window: a SPECIAL ask needs its two INGREDIENT lines on the board, and those
# ingredients are usually outside the window. Testing the bare window made the bot sell the very
# ingredients it had just popped for a merge quest — a pop→sell churn loop that crafted no special and
# turned junk-selling into the dominant coin faucet.
func _first_clutter() -> Vector2i:
	var needed := G.quest_needed_lines(_live_lines())
	for i in board.items.size():
		var k: int = board.items[i]
		if k > 0 and not G.is_coin(k) and not needed.has(BoardModel.line_of(k)):
			return BoardModel.cell_of(i)
	return Vector2i(-1, -1)

func _best_pair() -> Array:
	var by_code := {}
	for i in board.items.size():
		var k: int = board.items[i]
		if k <= 0 or G.is_coin(k):
			continue
		if BoardModel.tier_of(k) >= G.TOP_TIER:
			continue
		if not by_code.has(k):
			by_code[k] = []
		by_code[k].append(BoardModel.cell_of(i))
	var wanted := _wanted_lines()
	var best_code := -1
	var best_score := -999
	for k in by_code:
		if by_code[k].size() < 2:
			continue
		var score := 0
		if wanted.has(BoardModel.line_of(k)):
			score += 10
		score -= BoardModel.tier_of(k)        # build from the bottom
		if score > best_score:
			best_score = score
			best_code = k
	if best_code < 0:
		return []
	var cells: Array = by_code[best_code]
	var a: Vector2i = cells[0]
	var b: Vector2i = cells[1]
	# prefer the dst beside an openable (level-met) sealed cell — grow the board on this merge
	if not board.openable_brambles(b, _level()).is_empty():
		return [a, b]
	if not board.openable_brambles(a, _level()).is_empty():
		return [b, a]
	return [a, b]

## One pop. Returns the WATER it charged, or 0 when it could not pop at all (no room, no pool, or the
## line's window costs more than `budget`) — the caller subtracts the return value, so a burst can
## never overdraw the can however the per-item window moves.
func _pop(budget: int) -> int:
	var empties := board.empty_ground_cells()
	if empties.is_empty():
		return 0
	var cell: Vector2i = empties[rng.randi_range(0, empties.size() - 1)]
	# SINGLE-GENERATOR model (idea 3.2): pop the items the CURRENT QUESTS REQUIRE — pool = the WANTED
	# (quested) lines drawn from the all-opened askable set; fall back to opened only when nothing is
	# wanted. Restricting to wanted keeps the board mergeable however many lines have opened (mirrors
	# board.gd; the un-restricted 24-line pool scatters un-mergeable singletons and jams).
	# A generator pops only its own BASE line — a SPECIAL is never popped, only crafted by merging its two
	# ingredients (Core §6.G). `wanted` is already ingredient-expanded (_wanted_lines); the fallback pool
	# must be too, or an idle tap can pop an item no generator in the game could produce.
	var opened: Array = []
	for l in _live_lines():
		for b in _quest_pop_lines(int(l)):
			if not opened.has(int(b)):
				opened.append(int(b))
	if opened.is_empty():
		return 0
	var wanted := _wanted_lines()
	# NO POP-LINE CAP. G.pop_line_cap is a single-generator-era leftover with no live caller left: under the
	# per-line generator model each generator pops its own line, and the real bound is QUEST_GEN_CAP on the
	# generator footprint, already applied upstream by cap_quest_lines. Truncating here to 3 deterministically
	# dropped the tail of the pool, and the FINAL window needs FIVE base lines — 18, plus 7+3 for corals,
	# plus 2+4 for tea cups via spices — so two of the five could never be produced and the late fence went
	# permanently undeliverable (zero deliveries from ~day 55 while still burning 330 water/day).
	var pool: Array = wanted if not wanted.is_empty() else opened
	# AFFORDABILITY IS PER LINE now: a mastered line pops from a raised window and costs
	# G.pop_cost(low), so with 10💧 left a player taps a CHEAP generator rather than putting the can
	# down. Filtering the pool is that choice. Pure — no rng — and with every line at G.POP_COST
	# (unmastered, or the flag off) it keeps the arrays intact, so that stream is untouched.
	var cost_of := {}
	var affordable: Array = []
	for l in pool:
		var c := G.pop_cost(Mastery.window(int(l), live_quests).x)
		cost_of[int(l)] = c
		if c <= budget:
			affordable.append(int(l))
	if affordable.is_empty():
		return 0
	var pw: Array = []
	for l in affordable:
		if wanted.has(int(l)):
			pw.append(int(l))
	var line: int
	if not pw.is_empty() and rng.randf() < G.ASK_WEIGHT:
		line = pw[rng.randi_range(0, pw.size() - 1)]
	else:
		line = int(affordable[rng.randi_range(0, affordable.size() - 1)])
	var mastery_window := Mastery.window(line, live_quests)
	# §3 tier-scaled cost, same helper the board charges: a raised window means a dearer pop.
	var cost := int(cost_of[line])
	var tier := BoardLogic.roll_tier_window(rng, mastery_window.x, mastery_window.y - mastery_window.x + 1)
	# §6 tier-bias (mirrors BoardLogic.roll_spawn): lean toward an asked poppable tier for this line,
	# with probability G.ASK_TIER_WEIGHT (0 = off → byte-identical baseline; owner pacing dial).
	if G.ASK_TIER_WEIGHT > 0.0:
		var wt: Array = []
		for t in _wanted_tiers(pool).get(line, []):
			if int(t) >= mastery_window.x and int(t) <= mastery_window.y:
				wt.append(int(t))
		if not wt.is_empty() and rng.randf() < G.ASK_TIER_WEIGHT:
			tier = int(wt[rng.randi_range(0, wt.size() - 1)])
	board.place(cell, line * 100 + tier)
	return cost
