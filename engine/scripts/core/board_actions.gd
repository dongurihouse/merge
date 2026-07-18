extends RefCounted
## Board ACTIONS — the pure player-action layer. Where board_model.gd owns the primitive
## mutations (take/place/merge) and board_logic.gd owns the stateless decisions (rolls, hints),
## this owns the COMPOSITE state transitions a player action performs: the full sequence of
## model + economy writes that defines what an action DOES to the game. Backend layer:
## STATELESS statics that take the model + save in and return an OUTCOME dict out — no Node /
## Control / Tween / FX. The scene calls these, then renders the returned outcome. Lifted out of
## scenes/board.gd so the RULES are headless-testable (grove_board_actions_tests.gd) — change a
## rule and assert it without instantiating the Board scene.

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const Quests = preload("res://engine/scripts/core/quests.gd")
const Save = preload("res://engine/scripts/core/save.gd")

# Deliver quest `qi` by consuming the tile at `cell`: drop the quest from the live fence, remember
# the asked item (anti-monotony window, ≤5), and pay the COIN reward through the coin clock (the
# quest coin faucet IS the progression clock — coin-clock redesign, spec 2026-07-17). Mutates
# `board`, `quests`, and `recent_items` in place. Returns the OUTCOME the scene needs to render —
# {code, coins, levels_up, cell} — so the fly-to-giver, reward FX, coin float, and Level dialog
# read facts off one dict instead of recomputing them.
static func deliver_quest(board: BoardModel, quests: Array, recent_items: Array, qi: int, cell: Vector2i) -> Dictionary:
	var q: Dictionary = quests[qi]
	var it: Dictionary = G.quest_item(q)
	var has_item := not it.is_empty()
	var code := (int(it.line) * 100 + int(it.tier)) if has_item else 0
	board.take(cell)
	quests.remove_at(qi)                          # §7: the delivered quest leaves the live fence
	if has_item:                                  # only a real ask enters the anti-monotony window
		recent_items.append(code)                 # remember this ask so the next ≤5 quests avoid it
		while recent_items.size() > 5:
			recent_items.pop_front()
	var sp_coins := Quests.coins(q)
	var levels_up := G.earn_coins(sp_coins)       # organic earn — credits the wallet + the clock
	return {"code": code, "coins": sp_coins, "levels_up": levels_up, "cell": cell}

# Collect the coin at `cell`: take it off the board and credit its value (a stashed collect-reward
# overrides the face value). Returns {got, code} for the fly-to-HUD reward FX.
static func collect_coin(board: BoardModel, cell: Vector2i) -> Dictionary:
	var reward := board.take_collect_reward(cell)
	var code := board.take(cell)
	var got := int(reward.amount) if String(reward.get("kind", "")) == "coins" else G.coin_value(code)
	Save.earn_coins(got)                          # organic — merge-drop/chest coins advance the clock
	return {"got": got, "code": code}

# Collect the special drop at `cell` (water / acorn / coins). A stashed collect-reward overrides the
# item's own face reward. acorn + coins write Save here; "water" is RETURNED for the caller to fold into
# its live water mirror (a scene field, capped — not a Save currency). Returns {} when nothing collects.
static func collect_special(board: BoardModel, cell: Vector2i) -> Dictionary:
	var got: Dictionary = G.special_collect(board.item_at(cell))
	var reward := board.take_collect_reward(cell)
	if not reward.is_empty():
		got = reward
	if got.is_empty():
		return {}
	board.take(cell)
	var amount := int(got.amount)
	match String(got.kind):
		"acorn":
			Save.add_diamonds(amount)
		"coins":
			Save.earn_coins(amount)               # organic — the Spark's coins advance the clock
	return {"kind": String(got.kind), "amount": amount}

# Birth-on-tap placement: the generator the board owes (Quests.due_gen — the anchor self-heals first,
# then the first quest-required gen the player lacks) lands on a free cell, or falls into the bag when
# the board is full. Mutates the model. Returns {due, landed:[cells], bagged:[ids]} for the pop-in render.
static func produce_due_generators(board: BoardModel, quests: Array) -> Dictionary:
	var gid := Quests.due_gen(quests, Quests.owned_gens(board.gens, board.gen_bag))
	if gid == "":
		return {"due": false, "landed": [], "bagged": []}
	var landed: Array = []
	var bagged: Array = []
	for id in [gid]:                              # one owed gen per tap (kept as a loop to mirror the source)
		var dest := Vector2i(-1, -1)
		for c in board.empty_ground_cells():     # gen redesign: NO board cap — place freely on any open cell
			if not board.gens.has(c):
				dest = c
				break
		if dest == Vector2i(-1, -1):
			board.bag_add(id)                     # board genuinely full → hold it in the bag
			bagged.append(id)
		else:
			board.place_gen(id, dest)
			landed.append(dest)
	return {"due": true, "landed": landed, "bagged": bagged}

# Gen stranding fix — SELF-DUP (the merge fuel). The duplicate spawns at the LINE's TOP tier
# (top_gen_tier across board+bag) so every self-dup feeds ONE lineage and merges up — no sub-tier strand
# forms, and a maxed line breeds nothing. Lands on a free cell, else the bag. Mutates the model; returns
# {landed, bagged} for the scene's pop-in render (mirrors produce_due_generators).
static func self_dup_generator(board: BoardModel, src: Vector2i) -> Dictionary:
	var dup_id := board.gen_id_at(src)
	if dup_id == "" or G.gen_def(G.GENERATORS, dup_id).is_empty():
		return {"landed": [], "bagged": []}
	var line := int(G.gen_def(G.GENERATORS, dup_id).get("line", 0))
	var tier := board.top_gen_tier(line)
	if tier <= 0 or tier >= G.GEN_TOP_TIER:
		return {"landed": [], "bagged": []}          # maxed line → no merge fuel, no new strand
	for c in board.empty_ground_cells():
		if not board.gens.has(c):
			board.place_gen(dup_id, c, tier)
			return {"landed": [c], "bagged": []}
	if not board.gen_bag.has(dup_id):
		board.bag_add(dup_id, tier)
		return {"landed": [], "bagged": [dup_id]}
	return {"landed": [], "bagged": []}

# Gen stranding fix — SELL a redundant generator (one that has a strictly-higher same-line sibling, so the
# line keeps its top producer). Guarded: a non-redundant generator is refused. Removes it from the model and
# credits GEN_SELL_COINS. Returns {sold, coins} for the scene's poof + coin float.
static func sell_generator(board: BoardModel, cell: Vector2i) -> Dictionary:
	if not board.is_redundant_gen(cell):
		return {"sold": false, "coins": 0}
	var coins := G.gen_sell_coins(board.gen_tier_at(cell))
	board.remove_gen(cell)
	if coins > 0:
		Save.earn_coins(coins)                    # organic — a sell refund advances the clock
	return {"sold": true, "coins": coins}
