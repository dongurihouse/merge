extends SceneTree
## Ghibli Grove — headless PACING SIM (TIDY_UP_V2_SPEC §9 P2; the economy's tables
## are validated here, not by vibes). A greedy bot plays the MODEL for N days and
## reports water→stars→chapter rates, then checks the EconConfig invariants:
##   I1 zero jams (board full + no merge + nothing deliverable + no coins)
##   I2 every chapter's water gift < WATER_REWARD_MAX_RATIO of its measured spend
##   I3 the map's authored runway (days to finish all chapters) — reported
##   godot --headless --path . -s res://tools/grove_sim.gd -- [days] [seed]

const G = preload("res://engine/scripts/content.gd")
const BoardModel = preload("res://engine/scripts/board_model.gd")

var rng := RandomNumberGenerator.new()
var board: BoardModel
var unlocks := {}              # home spots bought — chapter = unlocks.size()
var chapter := 0
var qdone: Array = []
var stars := 0
var coins := 0
var diamonds := 0          # Y1: a t8 sells for 1💎, tracked for the abuse tripwire
var greedy := false        # AA3: do the chapter's FULL pool before decorating
var water := 0
var stars_earned := 0          # cumulative stars EARNED — drives the uncapped Level
var level_gift_water := 0      # level-up water (reported, separate from chapter gifts)

var jams := 0
var merchant_sells := 0
var chapter_spend := {}        # chapter -> water spent while it was active
var chapter_gift := {}
var open_low_mark := 999
var gen_reveal_ch := {}        # V2: gen index -> first chapter its gate-line was REVEALED (adjacent-open)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var days: int = int(args[0]) if args.size() >= 1 else 7
	rng.seed = int(args[1]) if args.size() >= 2 else 42
	greedy = args.has("greedy")
	board = BoardModel.new()
	_reset_qdone()
	print("== Grove pacing sim: %d days, 3 sessions/day, %d💧/session ==" % [days, G.WATER_CAP])

	var map_done_day := -1
	for day in days:
		var day_stars := 0
		var day_water := 0
		var day_chapters := 0
		for session in 3:
			water = G.WATER_CAP
			var r := _play_session()
			day_stars += r.stars
			day_water += r.water
			day_chapters += r.chapters
		if map_done_day < 0 and chapter >= G.chapters().size():
			map_done_day = day + 1
		print("  day %d: spent %d💧 · earned %d★ · %d spot(s) · zone %d · coins %d · brambles left %d" % \
			[day + 1, day_water, day_stars, day_chapters, G.zone_of_chapter(mini(chapter, G.chapters().size() - 1)) + 1, coins, board.bramble_count()])

	print("\n== results ==")
	print("  spots bought: %d/%d%s" % [mini(chapter, G.chapters().size()), G.chapters().size(),
		("  (map runway: day %d)" % map_done_day) if map_done_day > 0 else "  (runway exceeds the window)"])
	if map_done_day > 0 and (map_done_day < 4 or map_done_day > 14):
		print("  WARN I3: runway day %d outside the 4-14 engaged-day window (tuning signal)" % map_done_day)
	print("  merchant sells: %d · open-cell low-water-mark: %d · jams: %d" % [merchant_sells, open_low_mark, jams])
	print("  level: %d (stars earned %d) · level-up water gifts: %d💧 (separate from chapter gifts)" % \
		[G.level_for_stars(stars_earned), stars_earned, level_gift_water])

	# Generators now arrive PER ZONE (§6, the merge-to-evolve roster) — the live set is the
	# current zone's generators, evolving on zone entry, not a per-chapter `appears_at`
	# reveal. (The old V2 arrival-gap report is retired with that model.)
	print("  -- generators: per-zone roster, %d live in the final zone reached --" % G.active_gen_indices(chapter).size())

	var pass_all := true

	# Y4: selling is CLEANUP, never income — the abuse tripwires.
	var total_water := 0
	for ch in chapter_spend:
		total_water += int(chapter_spend[ch])
	var cpw := (float(coins) * 100.0 / float(total_water)) if total_water > 0 else 0.0
	print("  -- Y selling --  diamonds earned: %d · coins/100💧: %.1f (tripwire < 25) · earn-1💎=%d💧 vs buy=%d💧 (>=10x)" % \
		[diamonds, cpw, G.water_to_earn_diamond(), G.water_a_diamond_buys()])
	if cpw >= 25.0:
		print("  FAIL Y: coins/100💧 %.1f >= 25 — selling became an income pump" % cpw)
		pass_all = false
	if G.water_to_earn_diamond() < 10 * G.water_a_diamond_buys():
		print("  FAIL Y: the water<->diamond round trip is abusable (<10x loss)")
		pass_all = false
	# Z4: coins need a SINK — the wayside sink must comfortably absorb the lifetime
	# faucet (so coins never pile up useless), and waysides must NEVER gate progression.
	var sink := G.wayside_sink_capacity()
	var faucet := coins                     # the bot never spends coins → end coins == lifetime faucet
	print("  -- Z coin sink --  lifetime faucet: %d🪙 · wayside sink capacity: %d🪙 (%d plots) · absorbs %.0f%% of faucet" % \
		[faucet, sink, G.waysides().size(), (100.0 * float(sink) / float(maxi(1, faucet)))])
	if faucet > 0 and sink < int(0.6 * float(faucet)):
		print("  FAIL Z: the coin sink (%d) absorbs <60%% of the faucet (%d) — coins pile up" % [sink, faucet])
		pass_all = false
	var way_ids := {}
	for w in G.waysides():
		way_ids[String(w.id)] = true
	var gate_clean := true
	for z in G.ZONES.size():
		for sp in G.ZONES[z].spots:
			if way_ids.has(String(sp.id)):
				gate_clean = false           # a wayside id must never be a progression spot
	if not gate_clean:
		print("  FAIL Z: a wayside id collides with a progression spot — coins would gate the map")
		pass_all = false
	if jams > 0:
		print("  FAIL I1: %d jam(s) — a full, merge-less, deliver-less board occurred" % jams)
		pass_all = false
	else:
		print("  PASS I1: zero jams")
	# I2 at ZONE grain: per-chapter denominators are tiny and seed-noisy for an
	# optimal bot; the design intent (sessions extend, never self-sustain) is a
	# totals property. Gifts must stay under the ratio of each ZONE's spend.
	var zone_spend := {}
	var zone_gift := {}
	for ch in chapter_spend:
		var z := G.zone_of_chapter(int(ch))
		zone_spend[z] = int(zone_spend.get(z, 0)) + int(chapter_spend[ch])
	for ch in chapter_gift:
		var z := G.zone_of_chapter(int(ch))
		zone_gift[z] = int(zone_gift.get(z, 0)) + int(chapter_gift[ch])
	for z in zone_gift:
		var spend: int = int(zone_spend.get(z, 0))
		var gift: int = int(zone_gift.get(z, 0))
		if gift > 0 and (spend == 0 or float(gift) / float(spend) >= G.WATER_REWARD_MAX_RATIO):
			print("  FAIL I2: zone %d gifts %d💧 vs spend %d💧 (ratio %.2f >= %.2f)" % \
				[z + 1, gift, spend, float(gift) / float(spend), G.WATER_REWARD_MAX_RATIO])
			pass_all = false
	if pass_all:
		print("  PASS I2: every zone's water gifts under %.0f%% of its measured spend" % (G.WATER_REWARD_MAX_RATIO * 100))
	print("== sim %s ==" % ("PASS" if pass_all else "FAIL"))
	quit(0 if pass_all else 1)

# --- the bot -----------------------------------------------------------------------

func _reset_qdone() -> void:
	qdone = []
	if chapter < G.chapters().size():
		for q in G.chapters()[chapter].quests:
			qdone.append(false)

func _ch() -> Dictionary:
	return G.chapters()[mini(chapter, G.chapters().size() - 1)]

func _gate_cost() -> int:
	return G.cheapest_spot_cost(unlocks, G.level_for_stars(stars_earned))

func _active_quests() -> Array:
	var out: Array = []
	var cost := _gate_cost()
	if chapter >= G.chapters().size() or (not greedy and cost > 0 and stars >= cost):
		return out
	var done := 0
	for f in qdone:
		if f:
			done += 1
	if done >= (99 if greedy else _ch().quests.size() - int(_ch().slack)):
		return out         # greedy: the idxs filter below governs (it does every SINGLE)
	# X: a rational player pursues the SINGLE-ask quests first (fewest lines to
	# assemble), in order — exactly the proven pre-X path. The multi-LINE STRETCH
	# sorts last and is skipped via slack, so the bot never dilutes its pops chasing
	# its extra lines (which would congest the board and stall progress).
	var idxs: Array = []
	for i in qdone.size():
		if not qdone[i]:
			if greedy and G.quest_asks(_ch().quests[i]).size() > 1:
				continue   # AA3: greedy does every completable SINGLE; the multi-line stretch is the optional cherry
			idxs.append(i)
	idxs.sort_custom(func(a, b):
		var sa := G.quest_asks(_ch().quests[a]).size()
		var sb := G.quest_asks(_ch().quests[b]).size()
		if sa != sb:
			return sa < sb
		return a < b)
	return idxs.slice(0, 2)

func _play_session() -> Dictionary:
	var s_stars := 0
	var s_water := 0
	var s_chapters := 0
	var guard := 0
	while guard < 3000:
		guard += 1
		open_low_mark = mini(open_low_mark, board.empty_ground_cells().size())
		# V2: record the FIRST chapter each later generator's gate-line is revealed
		# (a line-gated edge bramble sits adjacent to an open cell — the player can
		# SEE the demand). Cheap once both are recorded.
		for gi2 in [1, 2]:
			if not gen_reveal_ch.has(gi2) and _line_revealed(gi2):
				gen_reveal_ch[gi2] = chapter
		# 1. deliver (multi-count asks take all their items)
		var delivered := false
		for qi in _active_quests():
			var q: Dictionary = _ch().quests[qi]
			var asks: Array = G.quest_asks(q)
			var payable := true
			for ask in asks:
				if board.count_of(int(ask.line) * 100 + int(ask.tier)) < int(ask.count):
					payable = false
					break
			if payable:
				for ask in asks:
					var code := int(ask.line) * 100 + int(ask.tier)
					for k in int(ask.count):
						board.take(board.first_item_of(code))
				qdone[qi] = true
				stars += int(q.stars)
				s_stars += int(q.stars)
				var lvl_b := G.level_for_stars(stars_earned)   # Level rides stars EARNED
				stars_earned += int(q.stars)
				if G.level_for_stars(stars_earned) > lvl_b:
					var up := G.level_for_stars(stars_earned) - lvl_b
					water = mini(G.WATER_CAP, water + G.LEVEL_WATER_GIFT * up)
					level_gift_water += G.LEVEL_WATER_GIFT * up
				delivered = true
				break
		if delivered:
			continue
		# 2. the gate: buy the frontier zone's cheapest spot (this IS the chapter)
		var gcost := _gate_cost()
		# AA3: the greedy merger does the FULL pool first, but the soft gate is always
		# an ESCAPE — if it can no longer progress the pool (board full, no merge, the
		# multi-line stretch won't assemble), it decorates rather than jam.
		if gcost > 0 and stars >= gcost and (not greedy or _active_quests().is_empty() \
				or (board.empty_ground_cells().is_empty() and _best_pair().is_empty())):
			var lvl := G.level_for_stars(stars_earned)
			for z in G.ZONES.size():
				var bought := false
				var cheapest_id := ""
				var cheapest := 99
				var missing := false
				for k in G.ZONES[z].spots.size():
					var sp: Dictionary = G.ZONES[z].spots[k]
					if unlocks.has(String(sp.id)):
						continue
					missing = true
					if G.spot_level_req(z, k) > lvl:
						continue                     # asleep until the level comes
					if int(sp.cost) < cheapest:
						cheapest = int(sp.cost)
						cheapest_id = String(sp.id)
				if missing:
					if cheapest_id == "":
						break                        # whole frontier level-locked (gate not ready)
					stars -= cheapest
					unlocks[cheapest_id] = true
					var gift := int(_ch().get("gift", 0))
					chapter_gift[chapter] = int(chapter_gift.get(chapter, 0)) + gift
					water = mini(G.WATER_CAP, water + gift)
					chapter = unlocks.size()
					board.set_active_gens(chapter)
					s_chapters += 1
					_reset_qdone()
					bought = true
				if bought:
					break
			continue
		# 3. sell tops (free space + reward) — Y1: a t8 trades for 1💎, not coins
		var tops := board.top_tier_cells()
		if not tops.is_empty():
			var rw := G.sell_reward(board.item_at(tops[0]))
			board.take(tops[0])
			coins += rw.x
			diamonds += rw.y
			merchant_sells += 1
			continue
		# 4. collect coins
		var coin_cell := _first_coin()
		if coin_cell != Vector2i(-1, -1):
			coins += G.coin_value(board.take(coin_cell))
			continue
		# 5. merge (prefer asked lines, lowest tier; dst beside an openable bramble)
		var pair := _best_pair()
		if not pair.is_empty():
			var produced: int = board.merge(pair[0], pair[1])
			for br in board.openable_brambles(pair[1], produced):
				board.open_bramble(br)
			if not G.is_coin(produced) and rng.randf() < G.COIN_DROP_RATE:
				var empt := board.empty_ground_cells()
				if not empt.is_empty():
					board.place(empt[rng.randi_range(0, empt.size() - 1)], G.COIN_LINE * 100 + 1)
			continue
		# 6. pop (from a generator carrying a wanted line when possible)
		if water >= G.POP_COST and not board.empty_ground_cells().is_empty() and chapter < G.chapters().size():
			water -= G.POP_COST
			s_water += G.POP_COST
			chapter_spend[chapter] = int(chapter_spend.get(chapter, 0)) + G.POP_COST
			_pop()
			continue
		# 7. nothing left to do
		if water > 0 and board.empty_ground_cells().is_empty() and chapter < G.chapters().size():
			jams += 1
		break
	return {"stars": s_stars, "water": s_water, "chapters": s_chapters}

# V2: is a bramble GATED on generator gi's line revealed (adjacent to an open
# cell)? Mirrors grove.gd `_gen_line_revealed` exactly so the sim measures what the
# player actually sees previewed.
func _line_revealed(gi: int) -> bool:
	var lines: Array = G.GENERATORS[gi].lines
	for r in G.ROWS:
		for c in G.COLS:
			var cell := Vector2i(r, c)
			if not board.is_bramble(cell):
				continue
			if not lines.has(BoardModel.gate_line_of(board.terrain[BoardModel.idx(cell)])):
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = cell + d
				if board.in_bounds(n) and board.is_open(n):
					return true
	return false

func _first_coin() -> Vector2i:
	for i in board.items.size():
		if board.items[i] > 0 and G.is_coin(board.items[i]):
			return BoardModel.cell_of(i)
	return Vector2i(-1, -1)

func _wanted_lines() -> Array:
	var out: Array = []
	for qi in _active_quests():
		for ask in G.quest_asks(_ch().quests[qi]):
			var l := int(ask.line)
			if not out.has(l):
				out.append(l)
	return out

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
	var produced_code := best_code + 1
	if not board.openable_brambles(b, produced_code).is_empty():
		return [a, b]
	if not board.openable_brambles(a, produced_code).is_empty():
		return [b, a]
	return [a, b]

func _pop() -> void:
	var empties := board.empty_ground_cells()
	var cell: Vector2i = empties[rng.randi_range(0, empties.size() - 1)]
	var wanted := _wanted_lines()
	var gens := G.active_gen_indices(chapter)
	var gi: int = gens[rng.randi_range(0, gens.size() - 1)]
	for cand in gens:                       # prefer a generator that serves a wanted line
		var ok := false
		for l in G.GENERATORS[cand].lines:
			if wanted.has(int(l)):
				ok = true
		if ok:
			gi = cand
			break
	var pool: Array = G.GENERATORS[gi].lines
	var line: int
	var pw: Array = []
	for l in pool:
		if wanted.has(int(l)):
			pw.append(int(l))
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
	board.place(cell, line * 100 + tier)
