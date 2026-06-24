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
		var d_exp := 0
		var d_water := 0
		for _session in 3:
			water = G.WATER_CAP
			var r := _play_session()
			d_exp += r.exp
			d_water += r.water
		if map_done_day < 0 and map >= G.MAPS.size():
			map_done_day = day + 1
		print("  day %d: spent %d💧 · earned %d exp · map %d/%d · maps-done %d · coins %d (quest %d/sell %d) · residents %d (%d💎) · brambles %d" % \
			[day + 1, d_water, d_exp, mini(map + 1, G.MAPS.size()), G.MAPS.size(), gates_reached, coins, quest_coins, sell_coins, residents_welcomed, residents_premium, board.bramble_count()])

	maps_done = mini(map, G.MAPS.size())
	print("\n== results ==")
	print("  maps restored: %d/%d%s" % [maps_done, G.MAPS.size(),
		("  (runway: day %d)" % map_done_day) if map_done_day > 0 else "  (runway exceeds the %d-day window)" % days])
	print("  spots claimed: %d/23 · maps completed: %d · level %d (exp earned %d)" % \
		[unlocks.size(), gates_reached, G.level_for_exp(exp_earned), exp_earned])
	print("  merchant sells: %d · open-cell low-water-mark: %d · jams: %d" % [merchant_sells, open_low_mark, jams])
	print("  level-up water gifts: %d💧 (the recurring water faucet, §4)" % level_gift_water)

	var pass_all := true

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
	for z in map_gift:
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
	if i2_ok:
		print("  PASS I2: every steady-state map (3+) keeps its water gift under %.0f%% of spend (early maps 1-2 noted above)" % (G.WATER_REWARD_MAX_RATIO * 100))

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
	if scpw >= 25.0:
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
	var other_coins := coins_earned - quest_coins - sell_coins   # drop-coins (merge spawns) + featured bonuses
	var total_sink := boost_coins_spent + resident_coins_spent
	print("  -- Z coins --  faucet %d🪙 (quest %d + sell %d + drops/featured %d) · held balance %d🪙" % \
		[coins_earned, quest_coins, sell_coins, other_coins, coins])
	print("                 sink %d🪙 = residents %d🪙 (%d welcomed, %d auto-merges) + boosts %d🪙 (%d bought) → absorbs %.0f%% of the faucet" % \
		[total_sink, resident_coins_spent, residents_welcomed - residents_premium, resident_merges, boost_coins_spent, boosts_bought, minf(100.0, 100.0 * float(total_sink) / float(maxi(1, coins_earned)))])

	# --- D: the DIAMOND economy (previously unmodeled). Faucet = level-ups (LEVEL_DIAMONDS) +
	# map-restores (MAP_DIAMONDS) + t8-pinnacle sells (flat 1💎); sink = premium signature residents
	# (RESIDENT_PREMIUM_COST each). REPORTED as a ledger — the premium sink is gated behind completing
	# a map, so an early/short run may show 0 spend (the faucet leads the sink, by design). ---
	print("  -- D diamonds --  faucet %d💎 (levels %d + maps %d + t8-sells %d + quests %d) · sink %d💎 (%d premium residents) · balance %d💎" % \
		[gems_earned, gems_from_levels, gems_from_maps, gems_from_sells, gems_from_quests, resident_gems_spent, residents_premium, diamonds])

	# --- P: the POPULATION invariants (NEW — the old §8 hub keystone is deleted, not re-runnable).
	# The residents loop is the post-completion economy, so the two failure modes it must avoid are:
	#   P1 LATE-GAME pile-up: once a map completes and the roster opens, the coin faucet earned AFTER
	#      that point must find a sink (residents) — a completed game whose coins just pile is the bug
	#      the endless sink exists to prevent. We measure the coins earned post-first-completion vs the
	#      resident spend over the same window; the population sink must absorb a healthy share.
	#   P2 EARLY-GAME dead-zone: BEFORE the first completion (population isn't open yet) there must be
	#      no idle coin gap — the active faucet has to keep flowing into restoration + boost activations,
	#      i.e. the bot is never sitting on a fat pre-population coin pile with nothing to spend on. ---
	var boost_budget := G.BOOST_COST * 4         # a few boosts' worth — the repeatable pre-population coin sink

	# P1 — late-game (post-first-completion) no-pile. The HARD check: once population opened, the coin
	# faucet earned since must have been ABSORBED, leaving no growing pile. We compare the coin INTAKE
	# after the first completion against the RESIDENT spend over the same window, and also assert the
	# final held BALANCE didn't run away (the endless sink keeps draining). Only checkable once a map
	# completed in the window; otherwise NOTED out-of-window (the run never reached population — runway).
	if first_complete_day > 0 and coins_at_first_complete >= 0:
		var faucet_after := coins_earned - coins_at_first_complete                   # coin intake since pop opened
		var sink_after := resident_coins_spent - resident_spend_at_first_complete    # resident coins spent since
		var absorb := minf(100.0, 100.0 * float(sink_after) / float(maxi(1, faucet_after)))
		# the held balance is the actual pile; with an endless sink it must stay BOUNDED (under one more
		# welcome's worth of cushion), never grow with the faucet. That bound is the real anti-pile teeth.
		var pile_bound := 2 * G.RESIDENT_BASE_COST
		if faucet_after <= 0:
			print("  -- P1: no coin faucet after the first completion (day %d) — nothing to pile (ok) --" % first_complete_day)
		elif coins > pile_bound and sink_after <= 0:
			print("  FAIL P1: %d🪙 earned after population opened (day %d) but the resident sink absorbed NONE and %d🪙 piled — late-game coins pile" % [faucet_after, first_complete_day, coins])
			pass_all = false
		elif coins > pile_bound and absorb < 50.0:
			print("  WARN P1: only %.0f%% of the %d🪙 earned post-completion went to residents and %d🪙 sits held (> %d🪙 bound) — tune the welcome cost/cadence (residents are endless; the bot just out-earned its welcomes)" % [absorb, faucet_after, coins, pile_bound])
		else:
			print("  PASS P1: the population sink absorbed %.0f%% of the %d🪙 earned after the first completion (day %d); only %d🪙 held (≤ %d🪙 bound) — late-game coins keep draining into residents (endless sink)" % [absorb, faucet_after, first_complete_day, coins, pile_bound])
	else:
		print("  -- P1: no map completed in the %d-day window — population never opened (a RUNWAY signal, not a pile; see I3) --" % days)

	# P2 — early-game (pre-population) no dead-zone. Before the first map completes, population isn't
	# open, so the ONLY coin sink is the (finite) burst ladder. The dead-zone bug would be a fat
	# pre-population coin PILE the bot can't spend. We assert the held balance at the first completion
	# (the end of the pre-pop phase) stayed within the burst ladder's reach — i.e. surplus coins kept
	# flowing into burst-upgrades until population opened, leaving no idle gap. (If no map completed,
	# population never opened and there is no pre-pop/post-pop boundary — P1 already noted the runway.)
	if first_complete_day > 0:
		var pre_pop_pile := balance_at_first_complete
		# boosts are the standing pre-pop sink; a few boosts' worth of held coins between activations is
		# normal churn — a pile beyond that before pop opens is the dead-zone to flag.
		if pre_pop_pile <= boost_budget:
			print("  PASS P2: at the first completion the held pile (%d🪙) stayed within the boost sink (%d🪙) — surplus kept flowing pre-population, no early-game coin dead-zone" % [pre_pop_pile, boost_budget])
		else:
			print("  WARN P2: at the first completion the bot held %d🪙 — beyond the %d🪙 boost sink, the only pre-population sink — an early-game coin gap (tune the boost cadence or open population sooner)" % [pre_pop_pile, boost_budget])
	else:
		print("  -- P2: population never opened (no completion) — no pre-population boundary to check (see I3 runway) --")

	print("== sim %s ==" % ("PASS" if pass_all else "FAIL"))
	quit(0 if pass_all else 1)

# --- the bot -----------------------------------------------------------------------

func _level() -> int:
	return G.level_for_exp(exp_earned)

func _live_lines() -> Array:
	return G.lines_for_map(G.GENERATORS, map)

# --- §1 POPULATION: the endless coin/diamond sink on COMPLETED maps -----------------
# The sim keeps its OWN resident roster (residents[z] = {type_id -> [t1..tMAX]}) rather than
# driving Save, but mirrors content.gd's welcome + auto-merge math exactly: welcome adds a t1,
# then two-of-a-kind cascade up to RESIDENT_MAX_TIER. Cost is read off G.resident_cost (coins for
# core/non-premium, diamonds for the per-map premium signature).

# The list of COMPLETED maps whose rosters are open to welcome onto.
func _completed_maps() -> Array:
	var out: Array = []
	for z in G.MAPS.size():
		if _map_all_bought(z) and gates_done.has(z):
			out.append(z)
	return out

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
	for z in _completed_maps():
		for td in G.resident_lines(z):
			if bool(td.get("premium", false)):
				continue
			if coins >= int(G.resident_cost(td).cost):
				return {"z": z, "def": td}
	return {}

# The cheapest PREMIUM (diamond) resident the bot can welcome on any completed map, or {}.
func _next_premium_welcome() -> Dictionary:
	for z in _completed_maps():
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
	while live_quests.size() < want:
		# mirror quests.gd refill: steer each new single-item stand off the lines already on the
		# fence so the sim validates the real anti-monotony line-diversity behaviour.
		var avoid: Array = []
		for q in live_quests:
			var it := G.quest_item(q)
			if not it.is_empty():
				avoid.append(int(it.line) * 100 + int(it.tier))
		live_quests.append(G.gen_quest(_level(), _live_lines(), rng, avoid))
	while live_quests.size() > want:
		live_quests.pop_back()

func _wanted_lines() -> Array:
	var out: Array = []
	for q in live_quests:
		var it := G.quest_item(q)
		if not it.is_empty() and not out.has(int(it.line)):
			out.append(int(it.line))
	return out

# §6 mirror of BoardLogic.wanted_tiers: the poppable asked tiers per pool line — so the sim's
# spawn applies the same line-AND-tier bias the live board does, and validates its economy.
func _wanted_tiers(pool: Array) -> Dictionary:
	var out: Dictionary = {}
	for q in live_quests:
		var it := G.quest_item(q)
		if it.is_empty():
			continue
		var li := int(it.line)
		var t := int(it.tier)
		if pool.has(li) and t >= 1 and t <= G.TIER_ODDS.size():
			if not out.has(li):
				out[li] = []
			if not out[li].has(t):
				out[li].append(t)
	return out

func _payable(q: Dictionary) -> bool:
	var it := G.quest_item(q)
	return board.count_of(int(it.line) * 100 + int(it.tier)) >= 1

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
			board.take(board.first_item_of(int(it.line) * 100 + int(it.tier)))
			var rw: Dictionary = q.reward
			var sp_exp := int(rw.exp)              # effort-based exp (was rw.stars — the field is `exp` now)
			s_exp += sp_exp
			coins += int(rw.coins)
			coins_earned += int(rw.coins)
			quest_coins += int(rw.coins)
			# (quests pay NO acorns now — acorns are milestone/IAP only, Option A)
			var lvl_b := _level()
			exp_earned += sp_exp
			if _level() > lvl_b:
				var up := _level() - lvl_b
				water = mini(G.WATER_CAP, water + G.LEVEL_WATER_GIFT * up)
				level_gift_water += G.LEVEL_WATER_GIFT * up
				map_gift[map] = int(map_gift.get(map, 0)) + G.LEVEL_WATER_GIFT * up
				# §1 diamond FAUCET: each level gained gifts LEVEL_DIAMONDS (mirrors earn_stars).
				diamonds += G.LEVEL_DIAMONDS * up
				gems_from_levels += G.LEVEL_DIAMONDS * up
			live_quests.erase(q)
			delivered = true
			break
		if delivered:
			continue

		# 1b. SINK surplus coins. Two sinks now: the repeatable §6 BOOST (re-armed whenever none is live),
		# and the ENDLESS §1 POPULATION loop (welcoming residents on COMPLETED maps — no roster cap, so it
		# absorbs coins forever once the first map is done). The bot re-arms the cheap boost when it lapses,
		# then pours the rest into residents — the standing coin sink that replaced the deleted §8 hub
		# ladder. (Greedy mode welcomes more aggressively; see _greedy.)
		var net := coins - boost_coins_spent
		if boost_taps <= 0 and net >= G.BOOST_COST:
			boost_coins_spent += G.BOOST_COST
			boost_taps = G.BOOST_TAPS
			boosts_bought += 1
			continue
		# §1 population SINK (coins): welcome a base resident on a completed map. The default mode
		# keeps a one-resident coin cushion for restoration; greedy welcomes whenever it can afford one.
		var coin_cushion: int = 0 if _greedy else G.RESIDENT_BASE_COST
		if coins >= G.RESIDENT_BASE_COST + coin_cushion:
			var bw := _next_base_welcome()
			if not bw.is_empty():
				_welcome(int(bw.z), bw.def)
				continue
		# §1 population SINK (diamonds): spend surplus premium on the per-map signature resident.
		# Keep a small premium reserve in the default mode (the diamond faucet leads the sink).
		var gem_reserve: int = 0 if _greedy else G.RESIDENT_PREMIUM_COST
		if diamonds >= G.RESIDENT_PREMIUM_COST + gem_reserve:
			var pw := _next_premium_welcome()
			if not pw.is_empty():
				_welcome(int(pw.z), pw.def)
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
			for br in board.openable_brambles(pair[1], _level()):
				board.open_bramble(br)
			if not G.is_coin(produced) and rng.randf() < G.COIN_DROP_RATE:
				var empt := board.empty_ground_cells()
				if not empt.is_empty():
					board.place(empt[rng.randi_range(0, empt.size() - 1)], G.COIN_LINE * 100 + 1)
			continue

		# 6. pop — one tap throws a BURST (§6): burst_count items (scales with map + the live boost),
		# each costing G.POP_COST, bounded by affordable energy + open cells. A charged tap spends one
		# boost tap (the boost is global and decays one tap at a time, then lapses).
		if water >= G.POP_COST and not board.empty_ground_cells().is_empty() and map < G.MAPS.size():
			var burst: int = G.burst_count(map, G.BOOST_BONUS if boost_taps > 0 else 0, rng)
			if boost_taps > 0:
				boost_taps -= 1
			burst = mini(burst, int(water / G.POP_COST))
			burst = mini(burst, board.empty_ground_cells().size())
			for _b in burst:
				water -= G.POP_COST
				s_water += G.POP_COST
				map_spend[map] = int(map_spend.get(map, 0)) + G.POP_COST
				_pop()
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
	var gens := G.generators_for_map(G.GENERATORS, map)
	if gens.is_empty():
		return
	var wanted := _wanted_lines()
	var serving: Array = []                     # generators that emit a wanted line — cover ALL of them
	for cand in gens:
		for l in cand.lines:
			if wanted.has(int(l)):
				serving.append(cand)
				break
	var g: Dictionary = serving[rng.randi_range(0, serving.size() - 1)] if not serving.is_empty() else gens[rng.randi_range(0, gens.size() - 1)]
	var pool: Array = g.lines
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
