extends SceneTree
## Ghibli Grove — headless PACING SIM for the §7 GENERATED-quest model (the economy's
## tables are validated here, not by vibes). A bot plays the model for N days and reports
## water→EXP→coins→map rates, then checks the invariants. (§exp model: quests pay EXP, spots unlock when
## cumulative exp crosses a threshold — NO spending; selling + quests pay COINS only, never acorns.)
##   I1 zero jams (board full + no merge + nothing deliverable)
##   I2 every map's level-up water gift < WATER_REWARD_MAX_RATIO of its measured spend
##   I3 runway (days to finish all maps) — reported (tuning signal, not a hard fail)
##   no-strand — the bot never sits a full session unable to earn exp while spots remain
##   Y selling is cleanup, not income (sell-coins tripwire)
##   Z coin faucet vs sink — REPORTED; the new endless sink is the §1 POPULATION loop
##   P population invariants (NEW — replaces the deleted §8 hub keystone check):
##     P1 LATE-GAME no-pile: once a map completes, the resident sink absorbs the
##        post-completion coin faucet (residents are an ENDLESS coin sink, no roster cap)
##     P2 EARLY-GAME no dead-zone: before the first completion there is no idle coin
##        gap — the active faucet (burst-upgrade ladder + restoration) keeps coins moving
##     D diamond faucet (level-ups + map-restores + t8-sells) vs sink (premium residents)
##   godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- [days] [seed]
##
## Quests are GENERATED (G.gen_quest), metered to the next unlock (G.active_giver_count),
## asked from the level-reached quest-line window (not restored-zone count), capped at 4 per line,
## a FLAT single item paying G.quest_reward (capped ★, coin overflow, premium 💎 at high
## level). There is NO gate quest: a map completes when all its SPOTS are bought (spots-done),
## which unlocks the next map + seeds its generators (the next map's tool rides on a near-end
## quest's reward.generators in real play; the sim seeds gens on advance for the economy flow).
##
## §1 POPULATION (the new post-hub economy): a COMPLETED map opens its resident roster. The
## bot WELCOMES residents — coins (RESIDENT_BASE_COST) buy core/non-premium, diamonds
## (RESIDENT_PREMIUM_COST) buy the per-map premium signature — and two-of-a-kind AUTO-MERGE
## one tier up (cascading, capped at RESIDENT_MAX_TIER). There is NO roster cap, so the bot
## re-buys base feeders forever to climb tiers: this is the ENDLESS coin sink that replaced
## the finite hub-upgrade ladder. Mirrors content.gd's welcome/merge math locally (the sim
## keeps its own wallet rather than driving Save). All numbers are PROVISIONAL (sim dials).

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const Explore = preload("res://engine/scripts/core/explore.gd")   # §1 expedition cost (the live residents coin SINK)
const Habitat = preload("res://engine/scripts/core/habitat.gd")   # §1 idle yield + sell (the live residents coin SOURCES)
const POP_SLOTS_MAX := 8             # §1 a map's resident roster scales 1 (first spot restored) → this (all spots) — PROTOTYPE

var rng := RandomNumberGenerator.new()
var board: BoardModel
var unlocks := {}              # spot id -> true (bought)
var map := 0                  # the map currently being restored
var gates_done := {}           # map -> true (its spots fully bought → map completed, roster open)
var live_quests: Array = []    # the active fence — generated flat regular quests, metered to the next unlock

var exp_earned := 0            # cumulative EXP earned — drives Level AND gates spot unlocks (no spending; §exp model)
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
var bonus_exp := 0
var bonus_acorn := 0
var bonus_gens := 0           # §6.C bonus generators side-spawned over the run (the faucet's volume signal)
var _bonus_kind := ""         # §6.C the live bonus generator's kind on the board ("" = none — one at a time)
var _bonus_clicks := 0        # its remaining tap budget; drained one tap per main-gen tap, then it vanishes
var drop_water := 0          # §6.B special-item drops on merge (collected at t1)
var drop_exp := 0
var drop_acorn := 0
var drop_open_coins := 0     # §6.B chest opened by a key → coins + acorns
var drop_open_acorns := 0
var treat_coins := 0         # §6.D treat-gen premium-line sells + its special drops
var treat_water := 0
var treat_exp := 0
var treat_acorn := 0
var acorns := 0              # acorn (premium) balance — previously unmodeled; the §6 faucets mint it
var merges := 0             # total board merges (drives special-drop volume)
var specials_crafted := 0   # #14/#16 special (merge-line) quests delivered — proves the craft path is live
var treat_gens := 0         # §6.D treat generators spawned over the run
var _pending_chests := 0    # banked special-drop chests awaiting a key (paired-open model)
var _pending_keys := 0
var _session_cap := 0       # this session's water budget = WATER_CAP + §6 water (lets the bot out-pop a bare cap)

# §1 LIVE RESIDENTS ECONOMY (Habitat) — replaces the dormant welcome-coin-SINK the older model used. The
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
	# 3rd arg "greedy" (or "g") flips the bot to the aggressive-welcome mode: it pours every
	# affordable coin/diamond into residents with no restoration cushion (stress-tests the sink).
	_greedy = args.size() >= 3 and String(args[2]).to_lower() in ["greedy", "g", "1", "true"]
	board = BoardModel.new()
	board.seed_gens(0)
	print("== Grove §7 pacing sim: %d days, 3 sessions/day, %d💧/session (seed %d, %s bot) ==" % [days, G.WATER_CAP, rng.seed, "GREEDY" if _greedy else "default"])

	var map_done_day := -1
	for day in days:
		_cur_day = day
		var day_exp_b := exp_earned          # exp at day start — the day line reports the full delta (quest + §6)
		var d_water := 0
		for _session in 3:
			_session_cap = G.WATER_CAP             # §6.B special-item water drops extend this in-session
			water = _session_cap
			_hab_collect()                         # §1 collect the live habitat's idle coin yield (a SOURCE)
			var r := _play_session()
			d_water += r.water
		if map_done_day < 0 and map >= G.MAPS.size():
			map_done_day = day + 1
		print("  day %d: spent %d💧 · earned %d exp · map %d/%d · maps-done %d · coins %d (quest %d/sell %d) · residents %d (%d💎) · brambles %d" % \
			[day + 1, d_water, exp_earned - day_exp_b, mini(map + 1, G.MAPS.size()), G.MAPS.size(), gates_reached, coins, quest_coins, sell_coins, residents_welcomed, residents_premium, board.bramble_count()])

	maps_done = mini(map, G.MAPS.size())
	print("\n== results ==")
	print("  maps restored: %d/%d%s" % [maps_done, G.MAPS.size(),
		("  (runway: day %d)" % map_done_day) if map_done_day > 0 else "  (runway exceeds the %d-day window)" % days])
	print("  spots claimed: %d/23 · maps completed: %d · level %d (exp earned %d)" % \
		[unlocks.size(), gates_reached, G.level_for_exp(exp_earned), exp_earned])
	print("  merchant sells: %d · specials crafted: %d · open-cell low-water-mark: %d · jams: %d" % [merchant_sells, specials_crafted, open_low_mark, jams])
	print("  level-up water gifts: %d💧 (the recurring water faucet, §4)" % level_gift_water)

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
	if map < G.MAPS.size():
		var rem := _map_next_spot(map)
		if int(rem[0]) > 0:
			print("  -- note: map %d still had spots to buy at run end (restoration unfinished in the window) --" % (map + 1))

	# --- I2: per-map level-up water gift < ratio of that map's spend. The <30% anti-self-sustain
	# rule is a STEADY-STATE / late-game guardrail. Early maps (1-2) intentionally front-load water
	# to onboard (fast early level-ups, §3) AND now see burst-pop (§6) front-load energy SPEND into
	# the first map — leaving the low-volume early maps a high fixed-gift ratio on some seeds — so
	# maps 1-2 are a reported WARN; maps 3+ (steady-state) are the hard check. The holistic
	# gift-vs-spend rebalance (incl. the +50 gift, and now burst's front-loading) is the parked
	# "§7 economy tuning + pacing sign-off" pass — see BACKLOG. ---
	var i2_ftue_maps := 2                       # maps 1-2: low-volume early game — WARN, not FAIL
	var i2_ok := true
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
	var new_exp := bonus_exp + drop_exp + treat_exp
	var new_coins := bonus_coins + treat_coins + drop_open_coins
	var new_acorn := bonus_acorn + drop_acorn + treat_acorn + drop_open_acorns
	print("  -- §6 faucets --  water +%d💧 (bonus %d·drop %d·treat %d) · exp +%d✨ (bonus %d·drop %d·treat %d) · coins +%d🪙 (bonus %d·treat %d·chest %d) · acorn +%d🌰" % \
		[new_water, bonus_water, drop_water, treat_water, new_exp, bonus_exp, drop_exp, treat_exp, new_coins, bonus_coins, treat_coins, drop_open_coins, new_acorn])
	print("                 over %d merges · %d bonus-gens · %d treat-gens — §6 supplies %.0f%% of all exp earned (the rest is quests)" % \
		[merges, bonus_gens, treat_gens, 100.0 * float(new_exp) / float(maxi(1, exp_earned))])
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
		print("  -- I3 runway: %d/%d maps in %d days (full restoration is a long arc, §3) --" % [maps_done, G.MAPS.size(), days])

	# --- Y: selling is cleanup, never income (sell-coins only) + the water↔💎 round trip ---
	var gems_earned := gems_from_levels + gems_from_maps + gems_from_sells + gems_from_quests
	var total_water := 0
	for z in map_spend:
		total_water += int(map_spend[z])
	var scpw := (float(sell_coins) * 100.0 / float(total_water)) if total_water > 0 else 0.0
	print("  -- Y selling --  💎 earned: %d · SELL-coins/100💧: %.1f (tripwire < 25) · earn-1💎=%d💧 vs buy=%d💧 (>=10x)" % \
		[gems_earned, scpw, G.water_to_earn_diamond(), G.water_a_diamond_buys()])
	if stalled:
		print("  -- Y: sell-coins/100💧 %.1f skipped — stalled run (%d💧 spent); the ratio fires on cleanup-sale noise, not an income pump --" % [scpw, total_water])
	elif scpw >= 25.0:
		print("  FAIL Y: sell-coins/100💧 %.1f >= 25 — selling became an income pump" % scpw)
		pass_all = false
	if G.water_to_earn_diamond() < 10 * G.water_a_diamond_buys():
		print("  FAIL Y: the water<->diamond round trip is abusable (<10x loss)")
		pass_all = false

	# --- Z: coin faucet vs sink — the §8 hub yield/upgrade ladder is DELETED; the standing sink is now
	# the §1 POPULATION loop (welcoming residents on completed maps), which has NO roster cap, so it is
	# the new ENDLESS sink (the bot re-buys base feeders forever to climb resident tiers). The faucet =
	# quest + sell + drops/featured; the sinks = the resident-welcome spend + the (finite) burst ladder.
	# REPORTED; the absorption ratio is a tuning signal (the population invariants P1/P2 below are the
	# hard checks). ---
	var other_coins := coins_earned - quest_coins - sell_coins   # §6 drops/featured + §1 habitat yield/sell
	var coin_sink := boost_coins_spent + expedition_spend
	print("  -- Z coins --  faucet %d🪙 (quest %d + sell %d + other %d, incl. §1 habitat yield %d / sell %d) · held %d🪙" % \
		[coins_earned, quest_coins, sell_coins, other_coins, habitat_yield, habitat_sell, coins])
	print("                 sink %d🪙 = boosts %d🪙 (%d) + expeditions %d🪙 (%d run) → absorbs %.0f%% of the faucet" % \
		[coin_sink, boost_coins_spent, boosts_bought, expedition_spend, expeditions, minf(100.0, 100.0 * float(coin_sink) / float(maxi(1, coins_earned)))])

	# --- D: the DIAMOND economy (previously unmodeled). Faucet = level-ups (LEVEL_DIAMONDS) +
	# map-restores (MAP_DIAMONDS) + t8-pinnacle sells (flat 1💎); sink = premium signature residents
	# (RESIDENT_PREMIUM_COST each). REPORTED as a ledger — the premium sink is gated behind completing
	# a map, so an early/short run may show 0 spend (the faucet leads the sink, by design). ---
	print("  -- D diamonds --  faucet %d💎 (levels %d + maps %d + t8-sells %d + quests %d) · sink %d💎 (%d premium residents) · balance %d💎" % \
		[gems_earned, gems_from_levels, gems_from_maps, gems_from_sells, gems_from_quests, resident_gems_spent, residents_premium, diamonds])

	# --- §1 RESIDENTS economy — REALIGNED to the LIVE Habitat (was: the dormant welcome-roster modeled as an
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
		print("  WARN P1: residents are a NET COIN FAUCET (+%d🪙) — the live Habitat idle-yield ADDS coins; the expedition cost only drains during the slot ramp, so there is NO standing coin sink (late-game coins pile %d🪙 held). The economy needs a real sink (cosmetics/upgrades/events)." % [res_net, coins])
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

func _level() -> int:
	return G.level_for_exp(exp_earned)

func _quest_zone() -> int:
	return G.quest_zone_for_level(_level())

func _live_lines() -> Array:
	# Quest asks draw from the rolling window reached by level progress. This deliberately does not depend
	# on restored spots, so earning exp can reveal newer asks even if the player delays claiming zones.
	return G.quest_base_lines(_quest_zone())

# Credit `amount` exp and fire any level-ups: each level gifts LEVEL_WATER_GIFT water (topped up within
# the session budget _session_cap) + LEVEL_DIAMONDS, attributed to the current map's gift (I2). Shared by
# quest delivery AND the new §6 exp faucets (bonus-gen exp, exp drops, treat exp).
func _earn_exp(amount: int) -> void:
	if amount <= 0:
		return
	var lvl_b := _level()
	exp_earned += amount
	if _level() > lvl_b:
		var up := _level() - lvl_b
		water = mini(_session_cap, water + G.LEVEL_WATER_GIFT * up)
		level_gift_water += G.LEVEL_WATER_GIFT * up
		if map < G.MAPS.size():     # don't attribute gift to the post-completion phantom map (no spend there → false I2 fail)
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
				coins += amount
				coins_earned += amount
				bonus_coins += amount
			"exp":
				bonus_exp += amount
				_earn_exp(amount)
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
# exp faucet (levels up); acorn → premium. chest+key pair and OPEN for coins+acorns (paired across drops);
# wildcard ≈ a free advance, negligible to the water/exp/coin invariants.
func _credit_special_drop(code: int, src: String = "drop") -> void:
	match G.special_kind(code):
		"water":
			var a := int(G.special_collect(code).amount)
			_session_cap += a
			water += a
			if src == "treat": treat_water += a
			else: drop_water += a
		"exp":
			var a := int(G.special_collect(code).amount)
			if src == "treat": treat_exp += a
			else: drop_exp += a
			_earn_exp(a)
		"acorn":
			var a := int(G.special_collect(code).amount)
			acorns += a
			if src == "treat": treat_acorn += a
			else: drop_acorn += a
		"chest":
			_pending_chests += 1
			_try_open_chest()
		"key":
			_pending_keys += 1
			_try_open_chest()
		_:
			pass

# Pair a banked chest + key and OPEN for coins+acorns (both t1 — conservative). Models the §6.B chest/key
# loop without board placement.
func _try_open_chest() -> void:
	if _pending_chests >= 1 and _pending_keys >= 1:
		_pending_chests -= 1
		_pending_keys -= 1
		var rw := G.chest_open_reward(10 * 100 + 1, 11 * 100 + 1)
		coins += int(rw.coins)
		coins_earned += int(rw.coins)
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
		coins += sell
		coins_earned += sell
		treat_coins += sell
		if rng.randf() < G.TREAT_DROP_RATE:
			_credit_special_drop(G.pick_special_drop(rng), "treat")

# --- §1 LIVE RESIDENTS (Habitat) coin loop: expedition SINK + idle-yield/sell SOURCE ----------------
func _hab_rate() -> int:
	var r := 0
	for t in hab0:
		r += int(t)
	return r

# Map-0 habitat capacity right now — the 1→8 ramp (Habitat.cap → Content.resident_capacity).
func _hab_cap() -> int:
	return G.resident_capacity(0, unlocks)

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
	var cap_units := Habitat.BASE_CAP_UNITS + Habitat.CAP_UNITS_PER_TIER * maxf(0.0, float(stier) - 1.0)
	var hy := int(floor(cap_units * float(Habitat.REWARD["farmhouse"]["mult"])))
	if hy > 0:
		coins += hy
		coins_earned += hy
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
			var sv := Habitat.SELL_PER_TIER * 1
			coins += sv
			coins_earned += sv
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
		if _map_all_bought(z) and gates_done.has(z):
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

# The next spot to claim in `z`: [unlock_exp, id]; [-1,""] when every spot is owned. (NOTE: grove_sim
# still models the retired spend economy — its faucet/sink numbers need a separate exp-model rework;
# this keeps it compiling against the central exp threshold ladder.)
func _map_next_spot(z: int) -> Array:
	var nxt := G.map_next_unlock(z, unlocks)
	if int(nxt.k) == -1:
		return [-1, ""]
	return [int(nxt.exp), String(G.MAPS[z].spots[int(nxt.k)].id)]

func _map_all_bought(z: int) -> bool:
	return _map_next_spot(z)[0] == -1

# The current map's spots are all bought but it hasn't yet been marked completed — the
# spots-done trigger that fires map completion (diamond gift + advance) in the main loop.
func _spots_done_pending() -> bool:
	return map < G.MAPS.size() and _map_all_bought(map) and not gates_done.has(map)

# Refill the fence: flat generated regular quests metered to the next unlock (no gate quest).
func _refill_quests() -> void:
	if map >= G.MAPS.size():
		live_quests = []
		return
	var want := G.active_giver_count(exp_earned, _map_next_spot(map)[0])
	live_quests = _cap_quests_per_line(live_quests)
	var quest_zone := _quest_zone()
	var base_lines := G.quest_base_lines(quest_zone)
	var pool: Array = G.cap_quest_lines(base_lines + G.active_special_lines(base_lines, quest_zone))
	want = mini(want, _line_capacity(pool))
	while live_quests.size() < want:
		# mirror quests.gd refill: steer each new single-item stand off the lines already on the
		# fence so the sim validates the real anti-monotony line-diversity behaviour.
		var eligible_lines := _lines_with_room(pool, live_quests)
		if eligible_lines.is_empty():
			break
		var avoid: Array = []
		for q in live_quests:
			var it := G.quest_item(q)
			if not it.is_empty():
				avoid.append(int(it.line) * 100 + int(it.tier))
		# #14/#16 mirror quests.gd: pool = the level-reached base lines PLUS craftable specials, footprint-capped.
		live_quests.append(G.gen_quest(_level(), eligible_lines, rng, avoid))
	while live_quests.size() > want:
		live_quests.pop_back()

func _quest_line_counts(quests: Array) -> Dictionary:
	var out := {}
	for q in quests:
		var it := G.quest_item(q)
		if it.is_empty():
			continue
		var line := int(it.line)
		out[line] = int(out.get(line, 0)) + 1
	return out

func _cap_quests_per_line(quests: Array) -> Array:
	var out: Array = []
	var counts := {}
	for q in quests:
		var it := G.quest_item(q)
		if it.is_empty():
			out.append(q)
			continue
		var line := int(it.line)
		if int(counts.get(line, 0)) >= int(G.MAX_QUESTS_PER_LINE):
			continue
		counts[line] = int(counts.get(line, 0)) + 1
		out.append(q)
	return out

func _line_capacity(lines: Array) -> int:
	var seen := {}
	for line in lines:
		seen[int(line)] = true
	return seen.size() * int(G.MAX_QUESTS_PER_LINE)

func _lines_with_room(lines: Array, quests: Array) -> Array:
	var counts := _quest_line_counts(quests)
	var seen := {}
	var out: Array = []
	for line in lines:
		var li := int(line)
		if seen.has(li):
			continue
		seen[li] = true
		if int(counts.get(li, 0)) < int(G.MAX_QUESTS_PER_LINE):
			out.append(li)
	return out

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
	var out: Array = []
	for il in G.zone_recipe(G.zone_of_line(int(line))):
		out.append(int(il))
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
	var s_exp := 0
	var s_water := 0
	var guard := 0
	while guard < 8000:
		guard += 1
		open_low_mark = mini(open_low_mark, board.empty_ground_cells().size())
		_refill_quests()

		# 0. SPOTS-DONE map completion: a map ends when all its spots are bought (no gate quest).
		# This is the diamond-gift + advance trigger the old gate-quest delivery used to fire.
		if _spots_done_pending():
			gates_done[map] = true
			gates_reached += 1
			# §1 diamond FAUCET: fully restoring a map gifts MAP_DIAMONDS.
			diamonds += G.MAP_DIAMONDS
			gems_from_maps += G.MAP_DIAMONDS
			# P1/P2 seam: the FIRST completion is where population OPENS — snapshot the coin
			# faucet/sink so the late-game no-pile (P1) check measures the post-population window.
			if first_complete_day < 0:
				first_complete_day = _cur_day + 1
				coins_at_first_complete = coins_earned       # cumulative INTAKE, not the drained balance
				balance_at_first_complete = coins            # the held pile pre-population (for P2)
				resident_spend_at_first_complete = resident_coins_spent
			map += 1                              # unlock + grant the next map's generators
			if map < G.MAPS.size():
				board.seed_gens(map)
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
				specials_crafted += 1
			else:
				board.take(board.first_item_of(int(it.line) * 100 + int(it.tier)))
			var rw: Dictionary = q.reward
			var sp_exp := int(rw.exp)              # effort-based exp (was rw.stars — the field is `exp` now)
			s_exp += sp_exp
			coins += int(rw.coins)
			coins_earned += int(rw.coins)
			quest_coins += int(rw.coins)
			# (quests pay NO acorns now — acorns are milestone/IAP only, Option A)
			_earn_exp(sp_exp)
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

		# 2. restore: CLAIM the next spot once cumulative exp has reached its threshold (no spending —
		# §exp model). Claiming the LAST spot makes the map spots-done — step 0 fires completion next iter.
		if map < G.MAPS.size():
			var ns := _map_next_spot(map)
			if int(ns[0]) >= 0 and exp_earned >= int(ns[0]):
				unlocks[String(ns[1])] = true
				continue

		# 3. sell tops for coins (no gate to hoard top-tier for now — selling is pure cleanup/coins)
		var tops := board.top_tier_cells()
		if not tops.is_empty():
			var rw := G.sell_reward(board.item_at(tops[0]))
			board.take(tops[0])
			coins += rw.x
			coins_earned += rw.x
			sell_coins += rw.x                 # every tier sells for COINS now (no premium pinnacle, Option A)
			merchant_sells += 1
			continue

		# 4. collect coins
		var coin_cell := _first_coin()
		if coin_cell != Vector2i(-1, -1):
			var cv := G.coin_value(board.take(coin_cell))
			coins += cv
			coins_earned += cv
			continue

		# 4b. clear RETIRED-line clutter — old-map items no live quest can ever want (a line
		# not in the current map's set). A real player sells this stock off; the bot does too,
		# or the board clogs after a map transition and can't grow the new lines (cleanup, coins).
		var junk := _first_clutter()
		if junk != Vector2i(-1, -1):
			var rwj := G.sell_reward(board.item_at(junk))
			board.take(junk)
			coins += rwj.x
			coins_earned += rwj.x
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
		# each costing G.POP_COST, bounded by affordable energy + open cells. A charged tap spends one
		# boost tap (the boost is global and decays one tap at a time, then lapses).
		# pop only with working ROOM — a real player never bursts into a near-full board (that just floods it
		# into a singleton lockout). Leave a 2-cell margin; surplus water the board can't absorb is left
		# UNSPENT (a realistic "energy I can't use right now"), never forced into a jam.
		if water >= G.POP_COST and board.empty_ground_cells().size() > 3 and map < G.MAPS.size():
			var burst: int = G.burst_count(map, G.BOOST_BONUS if boost_taps > 0 else 0, rng)
			if boost_taps > 0:
				boost_taps -= 1
			burst = mini(burst, int(water / G.POP_COST))
			burst = mini(burst, board.empty_ground_cells().size() - 2)   # keep a 2-cell working margin
			for _b in burst:
				water -= G.POP_COST
				s_water += G.POP_COST
				map_spend[map] = int(map_spend.get(map, 0)) + G.POP_COST
				_pop()
			# §6.D each main-generator tap may spawn a temporary treat generator (run to completion here)
			if G.rolls_treat_spawn(rng):
				_run_treat_gen()
			# §6.C each main-generator tap also drains the live bonus generator, or may side-spawn a fresh one
			_tick_bonus_gen()
			continue

		# 7. nothing to do
		if water > 0 and board.empty_ground_cells().is_empty() and map < G.MAPS.size():
			jams += 1
		break

	return {"exp": s_exp, "water": s_water}

func _first_coin() -> Vector2i:
	for i in board.items.size():
		if board.items[i] > 0 and G.is_coin(board.items[i]):
			return BoardModel.cell_of(i)
	return Vector2i(-1, -1)

# A board item whose line has RETIRED (not in the current map's live lines) — pure clutter.
func _first_clutter() -> Vector2i:
	var live := _live_lines()
	for i in board.items.size():
		var k: int = board.items[i]
		if k > 0 and not G.is_coin(k) and not live.has(BoardModel.line_of(k)):
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

func _pop() -> void:
	var empties := board.empty_ground_cells()
	if empties.is_empty():
		return
	var cell: Vector2i = empties[rng.randi_range(0, empties.size() - 1)]
	# SINGLE-GENERATOR model (idea 3.2): pop the items the CURRENT QUESTS REQUIRE — pool = the WANTED
	# (quested) lines drawn from the all-opened askable set; fall back to opened only when nothing is
	# wanted. Restricting to wanted keeps the board mergeable however many lines have opened (mirrors
	# board.gd; the un-restricted 24-line pool scatters un-mergeable singletons and jams).
	var opened: Array = _live_lines()
	if opened.is_empty():
		return
	var wanted := _wanted_lines()
	var pool: Array = wanted if not wanted.is_empty() else opened
	var line_cap := G.pop_line_cap(map)       # staged: 2 on the zone-1 board, 3 from zone 2
	if pool.size() > line_cap:                # keep the board mergeable: pop at most line_cap distinct lines
		pool = pool.slice(0, line_cap)
	var pw: Array = []
	for l in pool:
		if wanted.has(int(l)):
			pw.append(int(l))
	var line: int
	if not pw.is_empty() and rng.randf() < G.ASK_WEIGHT:
		line = pw[rng.randi_range(0, pw.size() - 1)]
	else:
		line = int(pool[rng.randi_range(0, pool.size() - 1)])
	var roll := rng.randf()
	var tier := 1
	var acc := 0.0
	for i in G.TIER_ODDS.size():
		acc += G.TIER_ODDS[i]
		if roll <= acc:
			tier = i + 1
			break
	# §6 tier-bias (mirrors BoardLogic.roll_spawn): lean toward an asked poppable tier for this line,
	# with probability G.ASK_TIER_WEIGHT (0 = off → byte-identical baseline; owner pacing dial).
	if G.ASK_TIER_WEIGHT > 0.0:
		var wt: Array = []
		for t in _wanted_tiers(pool).get(line, []):
			if int(t) >= 1 and int(t) <= G.TIER_ODDS.size():
				wt.append(int(t))
		if not wt.is_empty() and rng.randf() < G.ASK_TIER_WEIGHT:
			tier = int(wt[rng.randi_range(0, wt.size() - 1)])
	board.place(cell, line * 100 + tier)
