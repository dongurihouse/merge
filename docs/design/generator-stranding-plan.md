# Generator stranding fix — Implementation Plan

> **For agentic workers:** Use TDD. Each task ends with an independently testable deliverable. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Stop generators from stranding a low-tier copy, and let the player sell a redundant generator.

**Architecture:** New decision logic as pure statics in `BoardModel` (`top_gen_tier`, `is_redundant_gen`) and `BoardActions` (`self_dup_generator`, `sell_generator`), headless-tested in the grove board-actions suite; `board.gd` only renders. Self-dups spawn at the line's top tier (no new strands); the info-bar sell button is un-hidden for redundant generators (the clear).

**Tech Stack:** Godot 4.6 GDScript. Tests headless via `make test-grove` (grove slices) + `make test-fast` (engine regression); `make test` before merge.

## Global Constraints

- `GEN_TOP_TIER = 3` (grove). Sellable generator tiers are exactly 1..2 (a tier-3 can never have a strictly-higher sibling).
- Generator → line: `G.gen_def(G.GENERATORS, id).get("line", 0)`.
- A generator is **redundant** iff a strictly-higher-tier generator of the same line exists (board or bag). Redundancy is the sell guard — it guarantees the line's top generator is never sold, so quests stay satisfiable.
- No save migration; redundancy is computed live.
- All test cycles run from the worktree root `/Users/xup/dh/worktrees/gen-stranding`.

---

### Task 1: Model helpers — `top_gen_tier` + `is_redundant_gen`

**Files:**
- Modify: `engine/scripts/core/board_model.gd` (after `gen_tier_at`, line 168)
- Test: `games/grove/tests/grove_board_actions_tests.gd`

**Interfaces:**
- Produces: `BoardModel.top_gen_tier(line: int) -> int` (max owned tier for a line across board+bag; 0 if none), `BoardModel.is_redundant_gen(cell: Vector2i) -> bool`.

- [ ] **Step 1: Write the failing tests** — add to `grove_board_actions_tests.gd`: register `_test_gen_redundancy()` in `_initialize()` (after `_test_produce_due_generators()`), and add:

```gdscript
# top_gen_tier = the line's highest owned tier across board + bag; is_redundant_gen flags any
# generator that has a strictly-higher same-line sibling (so it can never merge up to the top).
func _test_gen_redundancy() -> void:
	fresh("gen_redundancy")
	var b := BoardModel.new()
	var gid := G.anchor_gen()                          # gen_1, line 1
	var line := int(G.gen_def(G.GENERATORS, gid).get("line", 0))
	ok(b.top_gen_tier(line) == 0, "no generators of a line → top tier 0")
	var t1: Vector2i = b.empty_ground_cells()[0]
	b.place_gen(gid, t1, 1)
	ok(b.top_gen_tier(line) == 1 and not b.is_redundant_gen(t1), "a lone tier-1 is the top, not redundant")
	var t3: Vector2i = b.empty_ground_cells()[0]
	b.place_gen(gid, t3, 3)
	ok(b.top_gen_tier(line) == 3, "top_gen_tier reports the highest owned tier")
	ok(b.is_redundant_gen(t1) and not b.is_redundant_gen(t3), "the tier-1 is redundant under the tier-3; the tier-3 is not")
	# a bagged higher tier still makes a board leftover redundant (bag-aware top)
	var b2 := BoardModel.new()
	var lc: Vector2i = b2.empty_ground_cells()[0]
	b2.place_gen(gid, lc, 1)
	b2.bag_add(gid, 3)
	ok(b2.top_gen_tier(line) == 3 and b2.is_redundant_gen(lc), "a bagged tier-3 makes the board tier-1 redundant")
	# a non-generator cell is never redundant
	ok(not b2.is_redundant_gen(Vector2i(0, 0)), "an empty cell is not a redundant generator")
```

- [ ] **Step 2: Run, verify fail**

Run: `make test-grove`
Expected: FAIL — `Invalid call. Nonexistent function 'top_gen_tier'`.

- [ ] **Step 3: Implement** — in `board_model.gd`, insert after line 168 (`gen_tier_at`):

```gdscript
# The highest tier owned for a generator LINE, across the board AND the bag (0 when the line owns
# none). Drives self-dup (spawn at the line's top so duplicates feed ONE lineage and never strand)
# and redundancy. Gen stranding fix.
func top_gen_tier(line: int) -> int:
	var top := 0
	for cell in gens:
		if int(G.gen_def(G.GENERATORS, String(gens[cell])).get("line", 0)) == line:
			top = maxi(top, gen_tier_at(cell))
	for i in gen_bag.size():
		if int(G.gen_def(G.GENERATORS, String(gen_bag[i])).get("line", 0)) == line:
			top = maxi(top, _bag_tier_at(i))
	return top

# A generator is REDUNDANT when a strictly-higher-tier generator of its line exists (board or bag):
# it can never merge up to or past the top, so it is safe to sell — the line's top generator always
# remains. Gen stranding fix.
func is_redundant_gen(cell: Vector2i) -> bool:
	if not gens.has(cell):
		return false
	var line := int(G.gen_def(G.GENERATORS, gen_id_at(cell)).get("line", 0))
	return gen_tier_at(cell) < top_gen_tier(line)
```

- [ ] **Step 4: Run, verify pass**

Run: `make test-grove`
Expected: PASS (grove board-actions suite green).

- [ ] **Step 5: Commit**

```bash
cd /Users/xup/dh/worktrees/gen-stranding
git add engine/scripts/core/board_model.gd games/grove/tests/grove_board_actions_tests.gd
git commit -m "Add BoardModel.top_gen_tier + is_redundant_gen (bag-aware)"
```

---

### Task 2: Prevention — `BoardActions.self_dup_generator` spawns at the line top

**Files:**
- Modify: `engine/scripts/core/board_actions.gd` (new static)
- Modify: `engine/scripts/scenes/board.gd` (`_self_dup_generator`, ~2685; refresh stale doc at 2682-2683)
- Modify: `games/grove/grove_data.gd` (fix stale comment at line 165)
- Test: `games/grove/tests/grove_board_actions_tests.gd`

**Interfaces:**
- Consumes: `BoardModel.top_gen_tier` (Task 1).
- Produces: `BoardActions.self_dup_generator(board: BoardModel, src: Vector2i) -> Dictionary` returning `{landed: Array, bagged: Array}` (mirrors `produce_due_generators`).

- [ ] **Step 1: Write the failing tests** — register `_test_self_dup_at_top()` in `_initialize()` and add:

```gdscript
# Self-dup feeds the line's TOP lineage: the duplicate spawns at top_gen_tier (not the tapped
# generator's tier), so tapping a sub-top leftover never breeds more low tiers, and a maxed line
# breeds nothing at all.
func _test_self_dup_at_top() -> void:
	fresh("self_dup_at_top")
	var gid := G.anchor_gen()
	var line := int(G.gen_def(G.GENERATORS, gid).get("line", 0))
	# tapping a tier-1 leftover while a tier-2 top exists spawns at the TOP (tier 2), not tier 1
	var b := BoardModel.new()
	var low: Vector2i = b.empty_ground_cells()[0]
	b.place_gen(gid, low, 1)
	var top: Vector2i = b.empty_ground_cells()[0]
	b.place_gen(gid, top, 2)
	var out: Dictionary = BoardActions.self_dup_generator(b, low)
	ok(out.landed.size() == 1, "self-dup placed one duplicate")
	ok(b.gen_tier_at(out.landed[0]) == 2, "the duplicate spawns at the line top (tier 2), not the tapped tier 1")
	# a maxed line (top == GEN_TOP_TIER) breeds nothing
	var bm := BoardModel.new()
	var mx: Vector2i = bm.empty_ground_cells()[0]
	bm.place_gen(gid, mx, G.GEN_TOP_TIER)
	var leftover: Vector2i = bm.empty_ground_cells()[0]
	bm.place_gen(gid, leftover, 1)
	var outm: Dictionary = BoardActions.self_dup_generator(bm, leftover)
	ok(outm.landed.is_empty() and outm.bagged.is_empty(), "a maxed line breeds no duplicate (no new strand)")
	# board full → the duplicate falls into the bag at the top tier
	var bf := BoardModel.new()
	for i in bf.items.size():
		bf.items[i] = 101
	var only: Vector2i = bf.gens.keys()[0] if not bf.gens.is_empty() else Vector2i(-1, -1)
	bf.gens = {}; bf.gen_tiers = {}
	bf.place_gen(gid, Vector2i(4, 3), 1)               # place_gen clears the cell's item, leaving one gen, board else full
	var outf: Dictionary = BoardActions.self_dup_generator(bf, Vector2i(4, 3))
	ok(outf.landed.is_empty() and outf.bagged == [gid], "a full board bags the duplicate")
	ok(bf._bag_tier_at(0) == 1, "the bagged duplicate carries the line-top tier")
```

- [ ] **Step 2: Run, verify fail**

Run: `make test-grove`
Expected: FAIL — `Nonexistent function 'self_dup_generator'`.

- [ ] **Step 3: Implement the static** — add to `board_actions.gd` (after `produce_due_generators`):

```gdscript
# Gen stranding fix — SELF-DUP (the merge fuel). The duplicate spawns at the LINE's TOP tier
# (top_gen_tier across board+bag) so every self-dup feeds ONE lineage and merges up — no sub-tier
# strand forms, and a maxed line breeds nothing. Lands on a free cell, else the bag. Mutates the
# model; returns {landed, bagged} for the scene's pop-in render (mirrors produce_due_generators).
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
```

- [ ] **Step 4: Rewire the scene** — replace `board.gd` `_self_dup_generator` body (2685-2701) with a thin wrapper, and refresh the doc comment (2682-2683) to say the dup spawns at the line top:

```gdscript
# Gen stranding fix — SELF-DUP (the merge fuel). The pure action spawns a duplicate at the LINE's
# TOP tier so duplicates feed one lineage (no sub-tier strand); the scene renders the pop-in.
func _self_dup_generator(src: Vector2i) -> void:
	var out := BoardActions.self_dup_generator(board, src)
	if out.landed.is_empty() and out.bagged.is_empty():
		return
	for c in out.landed:
		_grown_cells.append(c)
	_persist()
	if not out.landed.is_empty():
		_rebuild_all()
```

- [ ] **Step 5: Fix the stale data comment** — in `grove_data.gd` line 165, change the parenthetical so it no longer claims a maxed generator "feeds another sub-max line" (that path is retired):

```gdscript
# GEN_SELF_DUP_RATE per tap (the merge fuel), spawned at the line's TOP tier; a maxed line breeds nothing.
```

- [ ] **Step 6: Run, verify pass (grove + engine regression)**

Run: `make test-grove && make test-fast`
Expected: PASS. The engine `mechanics_tests` `scene_gen_self_dup_tier` still passes (its fixture's tapped generator IS the line top, so spawn-at-top == its tier).

- [ ] **Step 7: Commit**

```bash
cd /Users/xup/dh/worktrees/gen-stranding
git add engine/scripts/core/board_actions.gd engine/scripts/scenes/board.gd games/grove/grove_data.gd games/grove/tests/grove_board_actions_tests.gd
git commit -m "Self-dup spawns at line top tier (prevent generator stranding)"
```

---

### Task 3: Clear — sell a redundant generator

**Files:**
- Modify: `games/grove/grove_data.gd` (new `GEN_SELL_COINS` dial)
- Modify: `engine/scripts/core/content.gd` (const + `gen_sell_coins` helper)
- Modify: `engine/scripts/core/board_actions.gd` (`sell_generator`)
- Modify: `engine/scripts/scenes/board.gd` (`_select_generator` un-hide sell for redundant; `_on_trash_pressed` route; new `_sell_generator`)
- Test: `games/grove/tests/grove_board_actions_tests.gd`

**Interfaces:**
- Consumes: `BoardModel.is_redundant_gen`, `BoardModel.remove_gen`, `BoardModel.gen_tier_at`, `Save.add_coins`, `G.gen_sell_coins`.
- Produces: `G.gen_sell_coins(tier: int) -> int`, `BoardActions.sell_generator(board, cell) -> Dictionary` returning `{sold: bool, coins: int}`.

- [ ] **Step 1: Write the failing test** — register `_test_sell_generator()` and add:

```gdscript
# Selling a redundant generator removes it + credits GEN_SELL_COINS; the guard refuses a non-redundant
# (last/highest) generator, so a line always keeps its top producer.
func _test_sell_generator() -> void:
	fresh("sell_generator")
	var gid := G.anchor_gen()
	var b := BoardModel.new()
	var low: Vector2i = b.empty_ground_cells()[0]
	b.place_gen(gid, low, 1)
	var top: Vector2i = b.empty_ground_cells()[0]
	b.place_gen(gid, top, 3)
	var coins_b := Save.coins()
	var out: Dictionary = BoardActions.sell_generator(b, low)
	ok(bool(out.sold) and int(out.coins) == G.gen_sell_coins(1), "selling a redundant tier-1 reports sold + its coin value")
	ok(not b.gens.has(low) and b.gens.has(top), "the redundant generator is removed; the top survives")
	ok(Save.coins() == coins_b + G.gen_sell_coins(1), "the sale credits GEN_SELL_COINS to the wallet")
	# guard: the lone/top generator is NOT sellable
	var out2: Dictionary = BoardActions.sell_generator(b, top)
	ok(not bool(out2.sold) and b.gens.has(top), "a non-redundant (top) generator cannot be sold")
	ok(G.gen_sell_coins(1) >= 0 and G.gen_sell_coins(2) >= 0, "gen_sell_coins is defined for the sellable tiers 1..2")
```

- [ ] **Step 2: Run, verify fail**

Run: `make test-grove`
Expected: FAIL — `Nonexistent function 'gen_sell_coins'` / `'sell_generator'`.

- [ ] **Step 3: Add the data dial** — in `grove_data.gd`, beside `GEN_SELF_DUP_RATE` (after line 169), add:

```gdscript
# Coins refunded when SELLING a redundant generator (a sub-top leftover). Indexed by tier 1..GEN_TOP_TIER-1
# (a tier-3 is never redundant, so never sold). Kept small so 0.5%/tap breeding is not a coin faucet.
const GEN_SELL_COINS := [2, 6]             # tier 1 → 2 coins, tier 2 → 6 coins
```

- [ ] **Step 4: Add the content const + helper** — in `content.gd`, beside the other `GEN_*` consts (near line 34) add `const GEN_SELL_COINS = D.GEN_SELL_COINS`, and beside `gen_burst_count` (near line 355) add:

```gdscript
# Coins refunded for selling a redundant generator of `tier` (sellable tiers are 1..GEN_TOP_TIER-1).
static func gen_sell_coins(tier: int) -> int:
	return int(GEN_SELL_COINS[clampi(tier, 1, GEN_TOP_TIER - 1) - 1])
```

- [ ] **Step 5: Add the sell action** — in `board_actions.gd` (after `self_dup_generator`):

```gdscript
# Gen stranding fix — SELL a redundant generator (one that has a strictly-higher same-line sibling, so
# the line keeps its top producer). Guarded: a non-redundant generator is refused. Removes it from the
# model and credits GEN_SELL_COINS. Returns {sold, coins} for the scene's poof + coin float.
static func sell_generator(board: BoardModel, cell: Vector2i) -> Dictionary:
	if not board.is_redundant_gen(cell):
		return {"sold": false, "coins": 0}
	var coins := G.gen_sell_coins(board.gen_tier_at(cell))
	board.remove_gen(cell)
	if coins > 0:
		Save.add_coins(coins)
	return {"sold": true, "coins": coins}
```

- [ ] **Step 6: Run, verify pass**

Run: `make test-grove`
Expected: PASS.

- [ ] **Step 7: Commit the backend**

```bash
cd /Users/xup/dh/worktrees/gen-stranding
git add games/grove/grove_data.gd engine/scripts/core/content.gd engine/scripts/core/board_actions.gd games/grove/tests/grove_board_actions_tests.gd
git commit -m "Add gen_sell_coins + BoardActions.sell_generator (sell redundant generator)"
```

- [ ] **Step 8: Wire the UI — un-hide the sell button for a redundant generator.** In `board.gd` `_select_generator`, replace line 1872 (`_info_trash.visible = false`) and the burst block (1875-1879) with:

```gdscript
	if board.is_redundant_gen(cell):
		var coins := G.gen_sell_coins(tier)            # show the sell button with its coin payout
		_info_trash_count.text = "%d" % coins
		for ic in _info_trash_coin.get_children():
			ic.queue_free()
		var pay_icon := Look.icon("coin", _info_trash_coin.custom_minimum_size.x)
		pay_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_info_trash_coin.add_child(pay_icon)
		_info_trash.visible = true
		if _info_burst != null and is_instance_valid(_info_burst):
			_info_burst.visible = false                # a generator you're clearing isn't boostable
	else:
		_info_trash.visible = false                    # a non-redundant generator is never sold
		if G.is_accumulator(gid) or G.is_treat_gen(gid):
			if _info_burst != null and is_instance_valid(_info_burst):
				_info_burst.visible = false
		else:
			_refresh_burst_chip()
```

(Leave the `_info_buy.visible = false` lines at 1873-1874 in place above this block.)

- [ ] **Step 9: Route the sell handler.** In `board.gd` `_on_trash_pressed` (2127), add a generator branch at the top (after the `_selected_cell.x < 0` guard and `var cell := _selected_cell`):

```gdscript
	if board.is_gen(cell):
		if board.is_redundant_gen(cell):
			_sell_generator(cell)
			_clear_selection()
		return
```

(The existing item path below — `var code := board.item_at(cell)` … `_sell_item` — is unchanged.)

- [ ] **Step 10: Add the scene sell method.** In `board.gd`, beside `_sell_item` (3625), add:

```gdscript
# Gen stranding fix — sell the selected REDUNDANT generator: the pure action removes it + credits coins;
# the scene poofs the node and floats the payout (mirrors _grant_sale's coin branch).
func _sell_generator(cell: Vector2i) -> void:
	var node: Control = gen_nodes.get(cell)
	var out := BoardActions.sell_generator(board, cell)
	if not bool(out.sold):
		return
	Audio.play("tidy_poof", -4.0, 1.1)
	var coins := int(out.coins)
	var target: Control = _info_trash if (_info_trash != null and is_instance_valid(_info_trash)) else null
	var center: Vector2 = target.get_global_rect().get_center() if (target != null and is_instance_valid(target)) else get_global_rect().get_center()
	if node != null and is_instance_valid(node):
		var dest: Vector2 = center - board_area.get_global_transform().origin - Vector2(csz, csz) / 2.0
		var t := node.create_tween()
		t.set_parallel(true)
		t.tween_property(node, "position", dest, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(node, "scale", Vector2(0.35, 0.35), 0.25)
		t.chain().tween_callback(node.queue_free)
	if coins > 0:
		var done := func() -> void:
			if is_instance_valid(self):
				_update_hud()
		FX.reward_arrival(self, center, "coin", coins, Color("#E3B23C"), coins_label, done, FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "sale_payout")
	_persist()
	_rebuild_all()
	_refresh_giver_lights()
	_refresh_generator_dim()
```

- [ ] **Step 11: Verify the coins HUD label name.** Confirm `coins_label` is the HUD field (grep). If it differs, use the actual field.

Run: `grep -nE "var coins_label|coins_label|diamonds_label" engine/scripts/scenes/board.gd | head`
Expected: a `coins_label` (or equivalent) HUD node; adjust the `FX.reward_arrival` arg to match.

- [ ] **Step 12: Run the full sweep**

Run: `make test`
Expected: PASS (every engine + grove suite).

- [ ] **Step 13: Commit the UI wiring**

```bash
cd /Users/xup/dh/worktrees/gen-stranding
git add engine/scripts/scenes/board.gd
git commit -m "Wire info-bar sell for redundant generators"
```

---

## Self-review notes

- **Spec coverage:** Prevent (Task 2), Clear/sell (Task 3), all unmerged cases (Task 1 redundancy is bag-aware + multi-tier; tested for t1+t3, bagged-top, lone-gen). Deferred bag-sell + drag-absorb explicitly out of scope.
- **Type consistency:** `top_gen_tier(int)->int`, `is_redundant_gen(Vector2i)->bool`, `self_dup_generator->{landed,bagged}`, `sell_generator->{sold,coins}`, `gen_sell_coins(int)->int` — used identically across tasks.
- **Guard:** sell refuses non-redundant generators (never sells the line's top), so quests stay satisfiable.
