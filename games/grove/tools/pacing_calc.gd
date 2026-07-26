extends SceneTree
## Ghibli Grove — PACING CALCULATOR: days ⇄ clicks ⇄ coins ⇄ levels ⇄ scenes.
##
## THE BINDING RESOURCE IS WATER, NOT TIME. A generator pop costs G.POP_COST water and a session's
## can holds G.WATER_CAP, so a tier-t item costs 2^(t-1) POPS = 2^(t-1) water. Tapping speed only
## decides how fast you can SPEND a can, not how much you get. At 2 clicks/sec a full can is ~100
## seconds of popping plus its merges — about 2 minutes — so three sessions is ~6 minutes of tapping
## a day. Any play-time assumption above that buys nothing; the can is empty either way.
##
## SO THE GLOBAL ASSUMPTIONS ARE:
##   1. SESSIONS PER DAY       — how many times the can is refilled and spent (× WATER_CAP = water/day)
##   2. CLICKS PER SECOND      — only used to check the player HAS time to spend that water
##   3. MINUTES PER DAY        — the same check, from the other side
## Assumptions 2 and 3 do not move the pacing. They are a FEASIBILITY GATE: if the minutes available
## cannot spend the water, the tool says so and the water figure is the one that is wrong.
##
## The chain, all of it read off the LIVE dials (never re-stated here, so this tool cannot drift
## from the game the way a spreadsheet does):
##   water   → a tier-t item costs G.tier_clicks(t) = 2^(t-1) pops = that many water (merge is 2:1,
##             gens pop t1, POP_COST is 1). A SPECIAL line has no generator: it is CRAFTED from two
##             ingredients at the same tier, so it costs 2× that.
##   coins   → delivering it pays G.gen_quest(...).reward.coins — the real generated-quest reward,
##             sampled through the real ask distribution (line window + tier bell) at each level.
##   level   → G.coins_at_level(L) — the coin clock. QUEST coins only, exactly as the game counts it.
##   scene   → G.cluster_min_level(z, id) — the level each cluster unlocks at, so a scene is "fully
##             unlocked" at the level of its LAST cluster.
##
## So: coins_per_water(L) is measured, the clock says how many coins the level costs, and water/day
## turns that into days. Reported per level, per zone and per scene.
##
##   godot --headless --path . -s res://games/grove/tools/pacing_calc.gd -- [sessions/day] [clicks/sec] [minutes/day] [target-days]
##
## `target-days` (optional) flips the tool INVERSE: give it a comma-separated day per scene
## (e.g. 3,12,30,60,100 = "Fairy Hollow done day 3 … Cherry Blossom done day 100") and it reports
## the LEVEL each scene must complete at to hit those days, plus the coin clock that implies. That
## is the dial-setting direction: pick the days you want, read off the curve you need.
##
## MODELLING NOTE — this is the CEILING, not a forecast. It assumes every click lands inside an item
## that gets delivered. Real play loses clicks to junk pops, stock that never gets asked for, and
## merges that end in a sell. grove_sim measures the lossy reality; the gap between the two is
## printed at the end as the implied quest-productive click fraction. Use this tool to SHAPE the
## curve and grove_sim to VERIFY it.

const G = preload("res://engine/scripts/core/content.gd")

const SAMPLES := 400        # gen_quest draws per level — enough to settle the ask distribution
const RNG_SEED := 12345     # fixed: the same inputs must always print the same table
## How much bigger the WALLET is than the CLOCK. The level clock counts quest coins only, but the
## ladder is paid from every coin — sells, chests, treats, habitat yield. grove_sim measures the
## split directly (seed 1 at day 60: clock 12,543 vs spendable 14,590), so the wallet runs ~2.2× the
## clock. That gap is why a floor derived from cumulative cost in CLOCK coins binds long before the
## price does. Re-read it off grove_sim's "Z coins" line if the faucets are re-tuned.
const WALLET_MULTIPLE := 2.2
## How much of the wallet the cover-up ladder is allowed to eat. The rest funds the other sinks the
## sim already models — boosts, expeditions, residents. At 1.0 the ladder would consume every coin
## the player ever sees and nothing else could be bought.
const LADDER_WALLET_SHARE := 0.6

var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var sessions: float = float(args[0]) if args.size() >= 1 else 3.0
	var cps: float = float(args[1]) if args.size() >= 2 else 2.0
	var mins: float = float(args[2]) if args.size() >= 3 else 20.0
	var targets: Array = []
	if args.size() >= 4:
		for part in String(args[3]).split(",", false):
			targets.append(float(part))
	var probes: Array = []          # bare LEVELS to report the day for (compare any other gate table)
	if args.size() >= 5:
		for part2 in String(args[4]).split(",", false):
			probes.append(int(part2))
	# SOLVE mode: a top level here means "arg 4 is DAYS PER SCENE, not cumulative target days —
	# find the coin curve that lands each scene on its day with this many levels in the game".
	var solve_top: int = int(args[5]) if args.size() >= 6 else 0
	rng.seed = RNG_SEED

	# THE FAUCET: sessions × the can. This is what sets the pace.
	var water_per_day := sessions * float(G.WATER_CAP) / float(maxi(1, G.POP_COST))
	print("== Grove pacing calculator ==")
	print("  FAUCET: %.1f sessions/day × %d water (WATER_CAP, POP_COST %d) = %.0f pops/day" % \
		[sessions, G.WATER_CAP, G.POP_COST, water_per_day])
	print("  CURVE: level n→n+1 costs %d + (n-1)×%d coins (LEVEL_BASE_COINS / LEVEL_STEP_COINS)" % [G.LEVEL_BASE_COINS, G.LEVEL_STEP_COINS])
	# FEASIBILITY GATE: can the player actually spend that water in the time they play? A pop is one
	# click; merging a tier-t item up costs about one more click per pop, so ~2 clicks per water.
	var secs_needed := water_per_day * 2.0 / maxf(cps, 0.01)
	var secs_have := mins * 60.0
	if secs_needed <= secs_have:
		print("  TIME CHECK: spending that water takes ~%.0f min at %.1f clicks/sec — inside the %.0f min/day budget, so WATER binds, not time." % \
			[secs_needed / 60.0, cps, mins])
	else:
		print("  TIME CHECK: **TIME BINDS** — spending that water needs ~%.0f min at %.1f clicks/sec but only %.0f min/day is played. Every day below is optimistic; cut the faucet to %.0f pops/day to match the time budget." % \
			[secs_needed / 60.0, cps, mins, secs_have * cps / 2.0])

	if solve_top > 0:
		_solve(targets, solve_top, water_per_day)
		quit(0)
		return

	# --- how far the ladder runs: the level of the LAST cluster, and of the last zone ---
	var top_level := 1
	for z in G.coverup_pages():
		for c in G.clusters(int(z)):
			top_level = maxi(top_level, G.cluster_min_level(int(z), String((c as Dictionary).id)))
	top_level = maxi(top_level, G.zone_unlock_level(G.ZONE_COUNT - 1))

	# --- walk the levels, measuring the coin value of one water at each ---
	# day_at[L] = cumulative days to REACH level L (day_at[1] = 0.0)
	var day_at: Array = []
	var cpw_at: Array = []          # coins per water at each level (the measured ask mix)
	day_at.resize(top_level + 2)
	cpw_at.resize(top_level + 2)
	day_at[1] = 0.0
	cpw_at[1] = 0.0
	for lv in range(1, top_level + 1):
		var cpw := _coins_per_water(lv)
		cpw_at[lv] = cpw
		var need := G.coins_at_level(lv + 1) - G.coins_at_level(lv)
		var water := float(need) / maxf(cpw, 0.0001)
		day_at[lv + 1] = float(day_at[lv]) + water / water_per_day

	# --- the answer: days to fully unlock each scene ---
	print("\n== DAYS TO FULLY UNLOCK EACH SCENE ==")
	print("  %-24s %-15s %-6s %-11s %-13s %s" % ["scene", "last cluster", "level", "cumul.days", "days in scene", "what binds"])
	var book_day := 0.0
	var prev_day := 0.0
	var pages := G.coverup_pages()
	var cum_cost := 0
	var gi := 0
	for p in pages.size():
		var z := int(pages[p])
		var cls: Array = G.clusters(z)
		if cls.is_empty():
			continue
		for c in cls:
			cum_cost += G.cluster_cost(z, String((c as Dictionary).id))
			gi += 1
		var last_id := String((cls[cls.size() - 1] as Dictionary).id)
		var lv := G.cluster_min_level(z, last_id)
		var d := float(day_at[clampi(lv, 1, top_level + 1)])
		print("  %-24s %-15s L%-5d %-11s %-13s %s" % [String(G.MAPS[z].get("name", "?")), last_id, lv,
			_fmt_days(d), _fmt_days(d - prev_day), _binds(cum_cost, G.coins_at_level(lv))])
		prev_day = d
	book_day = prev_day
	print("  TOTAL: the book is finished on day %s" % _fmt_days(book_day))
	print("  \"what binds\" — the LEVEL floor, or the coin PRICE? The clock counts QUEST coins only, but")
	print("  the ladder is paid from the whole wallet, which runs about %.1f× the clock (sells, chests," % WALLET_MULTIPLE)
	print("  treats, habitat yield). So the price binds only once cumulative cost exceeds that multiple.")

	# --- when each item line arrives (the content arc, against the same clock) ---
	print("\n== DAYS TO EACH ZONE (the content arc) ==")
	var zi := 0
	for p in G.ZONE_BAND.size():
		var line_days: Array = []
		for _j in int(G.ZONE_BAND[p]):
			var zlv := G.zone_unlock_level(zi)
			line_days.append("z%d L%d = day %s" % [zi, zlv, _fmt_days(float(day_at[clampi(zlv, 1, top_level + 1)]))])
			zi += 1
		print("  scene %d: %s" % [p + 1, ", ".join(PackedStringArray(line_days))])
	var last_zone_day := float(day_at[clampi(G.zone_unlock_level(G.ZONE_COUNT - 1), 1, top_level + 1)])
	print("  the LAST item line arrives on day %s — %.0f%% of the way through the book" % \
		[_fmt_days(last_zone_day), 100.0 * last_zone_day / maxf(book_day, 0.001)])

	# --- per-scene water budget (the shape of the effort, not just the calendar) ---
	print("\n== EFFORT PER SCENE ==")
	var tot_water := book_day * water_per_day
	prev_day = 0.0
	for p in pages.size():
		var z2 := int(pages[p])
		var cls2: Array = G.clusters(z2)
		if cls2.is_empty():
			continue
		var lv2 := G.cluster_min_level(z2, String((cls2[cls2.size() - 1] as Dictionary).id))
		var d2 := float(day_at[clampi(lv2, 1, top_level + 1)])
		var scene_water := (d2 - prev_day) * water_per_day
		print("  scene %d %-24s %9.0f pops (%2.0f%% of the game) · %.2f coins/water at its end" % \
			[p + 1, String(G.MAPS[z2].get("name", "?")), scene_water, 100.0 * scene_water / maxf(tot_water, 1.0),
			 float(cpw_at[clampi(lv2, 1, top_level)])])
		prev_day = d2
	print("  whole book: %.0f pops (%.0f water)" % [tot_water, tot_water * float(G.POP_COST)])

	# --- INVERSE: the days you WANT → the levels that would produce them ---
	if not targets.is_empty():
		print("\n== INVERSE: target days → the level each scene must complete at ==")
		print("  (at %.0f pops/day, using the SAME measured coins/water per level)" % water_per_day)
		for p in mini(targets.size(), pages.size()):
			var want := float(targets[p])
			var lv3 := 1
			for l in range(1, top_level + 1):
				if float(day_at[l]) <= want:
					lv3 = l
				else:
					break
			var z3 := int(pages[p])
			print("  scene %d %-24s day %-6s → complete at L%-4d (clock: %d quest coins earned)" % \
				[p + 1, String(G.MAPS[z3].get("name", "?")), _fmt_days(want), lv3, G.coins_at_level(lv3)])
		print("  NOTE: if a target day exceeds the whole book's %s, the level is capped at L%d." % [_fmt_days(float(day_at[top_level + 1])), top_level])

	# --- plain lookup: what day is level N reached? (for comparing against any other gate table) ---
	if not probes.is_empty():
		print("\n== LEVEL → DAY ==")
		for l4 in probes:
			var li := clampi(int(l4), 1, top_level + 1)
			print("  L%-4d = day %-8s (clock: %d quest coins)" % [int(l4), _fmt_days(float(day_at[li])), G.coins_at_level(int(l4))])

	# --- honesty line: this is the ceiling; grove_sim measures the lossy reality ---
	var reach_day := float(day_at[clampi(top_level, 1, top_level + 1)])
	var coins_per_day := (float(G.coins_at_level(top_level)) / reach_day) if reach_day > 0.0 else 0.0
	print("\n== MODEL CEILING ==")
	print("  This assumes EVERY pop lands in an item that gets delivered: %.0f quest-coins/day." % coins_per_day)
	print("  grove_sim measures the lossy reality (junk pops, unasked stock, merges that end in a sell),")
	print("  and it also earns EXTRA water the faucet above ignores (level gifts, §6 drops, free refills).")
	print("  Divide the sim's measured quest-coins/day by %.0f to read the productive-pop fraction;" % coins_per_day)
	print("  multiply these days by its reciprocal for a realistic calendar.")
	quit(0)

# The coin value of ONE water at `level`, measured through the REAL ask pipeline: draw SAMPLES quests
# from the live line window + tier bell, and divide the coins they pay by the pops they cost. A
# special-line ask costs 2× the tier's pops (no generator — it is crafted from two ingredients).
func _coins_per_water(level: int) -> float:
	var pool: Array = G.cap_quest_lines(G.active_lines(level))
	if pool.is_empty():
		return 0.0001
	var coins := 0.0
	var pops := 0.0
	for _i in SAMPLES:
		var q: Dictionary = G.gen_quest(level, pool, rng, [])
		var it: Dictionary = G.quest_item(q)
		if it.is_empty():
			continue
		var t := int(it.tier)
		var c := float(G.tier_clicks(t))
		if G.ZONE_SPECIAL_LINES.has(int(it.line)):
			c *= 2.0
		coins += float((q.reward as Dictionary).coins)
		pops += c
	if pops <= 0.0:
		return 0.0001
	return coins / pops

# === SOLVE: days per scene → the coin curve, the scene levels, the whole gate table ==================
# `days_per_scene` is what the owner actually wants to dial ("scene 1 takes 3 days, scene 2 takes 4…").
# `top` is how many levels the game should span — the "more levels than clusters" requirement, since
# 25 clusters means top must comfortably exceed 25. Everything else is solved.
#
# The curve keeps its SHAPE (step/base stays at the shipped ratio) and only its SCALE moves, so the
# feel of "each level costs a bit more than the last" is preserved; the scale is what sets calendar
# length. Binary search on the scale, because coins-per-water varies by level and there is no closed
# form. The coins-per-water table is measured ONCE against the LIVE cadence and held fixed — moving
# the gates does move it a little (a later scene's lines pay more per pop), so re-run this tool after
# applying the result and expect a small correction on the second pass.
func _solve(days_per_scene: Array, top: int, wpd: float) -> void:
	var pages := G.coverup_pages()
	if days_per_scene.is_empty():
		print("\n  SOLVE: no days given. Pass them as arg 4, one per scene, e.g. \"3,4,5,6,7\".")
		return
	var cum: Array = []
	var acc := 0.0
	for d in days_per_scene:
		acc += float(d)
		cum.append(acc)
	var total_days := acc

	print("\n== SOLVE: days per scene → the curve that produces them ==")
	print("  WANT: %s days per scene = the book finished on day %.0f" % [str(days_per_scene), total_days])
	print("  LEVELS: %d (25 clusters, so %.1f levels per cluster)" % [top, float(top) / 25.0])

	var cpw := _cpw_table(top)
	var ratio := float(G.LEVEL_STEP_COINS) / maxf(float(G.LEVEL_BASE_COINS), 1.0)

	# binary search the curve SCALE (base; step follows the shipped ratio) for the target calendar
	var lo := 0.01
	var hi := 10000.0
	var base := 1.0
	for _i in 60:
		base = (lo + hi) / 2.0
		var got := _walk_f(base, base * ratio, top, wpd, cpw)
		if float(got[top]) > total_days:
			hi = base
		else:
			lo = base
	var step := base * ratio
	# The dials are INTEGERS, and at a short calendar they are small enough that rounding the float
	# solve is badly lossy (4.40/1.76 → 4/2 overshot by 12%). Search the integer pairs directly and
	# keep the one whose calendar lands closest, preferring the shape nearest the solved ratio on a tie.
	var b_i := maxi(1, int(round(base)))
	var s_i := maxi(0, int(round(step)))
	var best := INF
	for bb in range(1, maxi(8, int(base * 4.0) + 2)):
		for ss in range(0, maxi(8, int(step * 4.0) + 2)):
			var d := _walk_i(bb, ss, top, wpd, cpw)
			var err := absf(float(d[top]) - total_days)
			var shape := absf(float(ss) / maxf(float(bb), 1.0) - ratio) * 0.25   # tie-break toward the shipped shape
			if err + shape < best:
				best = err + shape
				b_i = bb
				s_i = ss
	print("  → LEVEL_BASE_COINS %d · LEVEL_STEP_COINS %d   (float solve %.2f / %.2f; best INTEGER pair searched, not rounded)" % [b_i, s_i, base, step])

	# verify the chosen integers through the real G.coins_at_level
	var day_at := _walk_i(b_i, s_i, top, wpd, cpw)
	print("  verified at those integers: the book lands on day %.1f (wanted %.0f)" % [float(day_at[top]), total_days])

	print("\n  %-24s %-9s %-7s %-11s %s" % ["scene", "want day", "level", "actual day", "clock (quest coins)"])
	var lvls: Array = []
	for p in mini(cum.size(), pages.size()):
		var want := float(cum[p])
		var lv := 1
		for l in range(1, top + 1):
			if float(day_at[l]) <= want:
				lv = l
			else:
				break
		lvls.append(lv)
		print("  %-24s %-9.0f L%-6d %-11.1f %d" % [String(G.MAPS[int(pages[p])].get("name", "?")),
			want, lv, float(day_at[lv]), _coins_f(lv, b_i, s_i)])

	# the gate tables that fall out: clusters and zones spread inside each scene's LEVEL BAND
	print("\n  THE GATE TABLES THIS PRODUCES (clusters and zones spread inside each scene's level band):")
	var start := 1
	var all_floors: Array = []
	var all_zones: Array = []
	for p in pages.size():
		if p >= lvls.size():
			break
		var end_lv := int(lvls[p])
		var span := maxi(1, end_lv + 1 - start)
		var ncl := G.clusters(int(pages[p])).size()
		var nz := int(G.ZONE_BAND[p]) if p < G.ZONE_BAND.size() else 0
		var f: Array = []
		for j in ncl:
			f.append(mini(end_lv, start + int(round(float(j) * float(span) / float(maxi(1, ncl))))))
		var zs: Array = []
		for j2 in nz:
			zs.append(mini(end_lv, start + int(round(float(j2) * float(span) / float(maxi(1, nz))))))
		all_floors.append_array(f)
		all_zones.append_array(zs)
		print("    scene %d %-24s L%d-%-4d clusters %s · zones %s" % [p + 1, String(G.MAPS[int(pages[p])].get("name", "?")), start, end_lv, str(f), str(zs)])
		start = end_lv + 1
	if not all_zones.is_empty():
		all_zones[0] = 1
	print("    cluster floors : %s" % str(all_floors))
	print("    zone unlocks   : %s" % str(all_zones))

	# Does the coin PRICE still fit inside the wallet at these levels? A shorter calendar earns fewer
	# coins, so the ladder's prices have to come down with it or the PRICE gates instead of the level
	# — which is the failure this whole exercise exists to avoid. Report the single scale factor that
	# makes the tightest scene fit inside LADDER_WALLET_SHARE of the wallet, leaving the rest for the
	# other sinks (boosts, expeditions, residents).
	print("\n  PRICE CHECK (the ladder must stay affordable, or the price gates instead of the level):")
	var cc := 0
	var need_scale := 1.0
	var binds := ""
	for p in pages.size():
		for c in G.clusters(int(pages[p])):
			cc += G.cluster_cost(int(pages[p]), String((c as Dictionary).id))
		if p < lvls.size():
			var clock := _coins_f(int(lvls[p]), b_i, s_i)
			var wallet := float(clock) * WALLET_MULTIPLE
			var budget := wallet * LADDER_WALLET_SHARE
			var ok := float(cc) <= budget
			print("    scene %d: cumulative cost %-7d vs wallet ~%-7.0f (ladder budget %.0f) → %s" % \
				[p + 1, cc, wallet, budget, "ok" if ok else "PRICE BINDS"])
			if not ok and binds == "":
				binds = "scene %d" % (p + 1)
			need_scale = minf(need_scale, budget / maxf(float(cc), 1.0))
	if binds == "":
		print("    the ladder fits: the LEVEL floor is the gate everywhere, which is the intent.")
		return
	print("    ⚠ the cluster COSTS do not fit this calendar — from %s on the player cannot pay even at" % binds)
	print("      the level, so the PRICE would gate instead of the level. Scale every `cost` by:")
	print("      → ×%.3f  (about 1/%.0f)" % [need_scale, 1.0 / maxf(need_scale, 0.0001)])
	var scaled: Array = []
	var tot_scaled := 0
	for p in pages.size():
		var row: Array = []
		for c in G.clusters(int(pages[p])):
			var nc := maxi(1, int(round(float(G.cluster_cost(int(pages[p]), String((c as Dictionary).id))) * need_scale)))
			row.append(nc)
			tot_scaled += nc
		scaled.append(row)
		print("      scene %d %-24s %s" % [p + 1, String(G.MAPS[int(pages[p])].get("name", "?")), str(row)])
	print("      whole ladder: %d coins (was %d)" % [tot_scaled, cc])

# Coins to REACH `level` on a candidate integer curve (the closed form G.coins_at_level uses).
func _coins_f(level: int, b: int, s: int) -> int:
	if level <= 1:
		return 0
	var m := level - 1
	return m * b + (m * (m - 1) / 2) * s

# Cumulative days to reach each level on a FLOAT candidate curve (search inner loop).
func _walk_f(b: float, s: float, top: int, wpd: float, cpw: Array) -> Array:
	var out: Array = []
	out.resize(top + 2)
	out[0] = 0.0
	out[1] = 0.0
	for lv in range(1, top + 1):
		var m := float(lv - 1)
		var m2 := float(lv)
		var need := (m2 * b + m2 * (m2 - 1.0) / 2.0 * s) - (m * b + m * (m - 1.0) / 2.0 * s)
		out[lv + 1] = float(out[lv]) + need / maxf(float(cpw[mini(lv, cpw.size() - 1)]), 0.0001) / wpd
	return out

# The same walk on the ROUNDED integers, through the real G.coins_at_level — the verification pass.
func _walk_i(b: int, s: int, top: int, wpd: float, cpw: Array) -> Array:
	var b0 := G.LEVEL_BASE_COINS
	var s0 := G.LEVEL_STEP_COINS
	G.LEVEL_BASE_COINS = b
	G.LEVEL_STEP_COINS = s
	var out: Array = []
	out.resize(top + 2)
	out[0] = 0.0
	out[1] = 0.0
	for lv in range(1, top + 1):
		var need := G.coins_at_level(lv + 1) - G.coins_at_level(lv)
		out[lv + 1] = float(out[lv]) + float(need) / maxf(float(cpw[mini(lv, cpw.size() - 1)]), 0.0001) / wpd
	G.LEVEL_BASE_COINS = b0
	G.LEVEL_STEP_COINS = s0
	return out

# Coins-per-water at every level, measured ONCE against the LIVE cadence before any dial is moved.
func _cpw_table(top: int) -> Array:
	var out: Array = []
	out.resize(top + 2)
	out[0] = 0.0001
	for lv in range(1, top + 2):
		out[lv] = _coins_per_water(lv)
	return out

# Which gate actually stops the player at this point in the ladder: the LEVEL floor, or the coin
# PRICE? `cum_cost` is what the ladder has cost through this scene; `clock_coins` is what the clock
# has counted by the floor's level. The wallet holds about WALLET_MULTIPLE × the clock, so the price
# only binds once the cost passes that.
func _binds(cum_cost: int, clock_coins: int) -> String:
	var affordable := float(clock_coins) * WALLET_MULTIPLE
	if float(cum_cost) <= affordable:
		return "LEVEL (cost %d ≤ wallet ~%.0f)" % [cum_cost, affordable]
	return "PRICE (cost %d > wallet ~%.0f)" % [cum_cost, affordable]

func _fmt_days(d: float) -> String:
	if d < 10.0:
		return "%.1f" % d
	return "%.0f" % d
