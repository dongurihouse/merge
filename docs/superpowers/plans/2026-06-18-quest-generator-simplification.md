# Quest + generator simplification — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce quests to a single "one item from one line" type with a level-based reward, make generators persist (storable in a new bag section), and grant the next map's generator from an ordinary near-end quest — removing the gate and grant quest types.

**Architecture:** A quest is `{line, tier, reward, featured}` where `tier` is its level (1–`TOP_TIER`). `quest_item(q)` returns `{line, tier}`. Reward is `{stars: min(level,3), coins: max(0,level-3), gems?}`. Generators are never consumed; the persisted `gen_bag` array holds stored ones; the next map's generator rides on `reward.generators` of a near-end quest and lands in `gen_bag`. `TOP_TIER` rises to 12 while a new `PREMIUM_TIER=8` pins the diamond/sell economy.

**Tech Stack:** Godot 4.6 / GDScript. Headless `SceneTree` test suites run via `make test-fast` (engine) and `make test` (full). Spec: `docs/superpowers/specs/2026-06-18-quest-generator-simplification-design.md`.

**GDScript constraint:** `preload`ed scripts are type-checked on load. Removing or re-signing a symbol that any loaded script references breaks ALL suites until every reference is updated in the same commit. Tasks below are sized to those atomic boundaries.

**Working dir:** the worktree `/Users/xup/dh/merge/.claude/worktrees/quest-simplify` on branch `worktree-quest-simplify`. Run all commands from there.

---

## File structure

| File | Responsibility | Change |
|------|----------------|--------|
| `games/grove/grove_data.gd` | tunable constants | retune (TOP_TIER, PREMIUM_TIER, premium/gen-grant tunables; drop gate/2count) |
| `engine/scripts/core/content.gd` | quest engine + generator roster logic | `quest_item`, level reward, flat `gen_quest`, remove gate/grant/hand-in fns, `askable_lines` current-map-only, pin sell/diamond to PREMIUM_TIER |
| `engine/scripts/core/board_logic.gd` | pure board predicates | `quest_payable(board,q)`, `wanted_lines/tiers` via `quest_item` |
| `engine/scripts/core/quests.gd` | fence composition | `refill` avoid loop via `quest_item`; near-end generator quest; remove grant/gate refill; spots-done unlock helper |
| `engine/scripts/core/board_model.gd` | board state | `gen_bag` persistence; remove `grant_gen`/`place_surplus_gen`/`grow_surplus_gens`; store/place generator moves |
| `engine/scripts/scenes/board.gd` | board scene wiring | single-item delivery; gen reward → `gen_bag`; drag generator to/from bag; remove `_deliver_gate`/`_deliver_grant`; spots-done unlock |
| `engine/scripts/ui/giver_stand.gd` | one giver card | single item render + level badge + generator-reward preview; drop `_count_badge`/multi-ask |
| `engine/scripts/ui/bag_overlay.gd` | bag modal | generator section region |
| `games/grove/tools/grove_sim.gd` | balance sim | read flat quest shape |
| `engine/tests/*`, `games/grove/tests/*` | suites | updated per task |

---

## Task 1: Flatten the quest shape + level-based reward

Collapse every quest to a single flat item and replace the expected-clicks reward with the
level-based formula. The gate quest survives this task as a single-item quest (removed in Task 4);
its reward stays authored. Generators still arrive the old way (untouched here).

**Files:**
- Modify: `games/grove/grove_data.gd` (constants ~120-140)
- Modify: `engine/scripts/core/content.gd` (`quest_asks` 290-293, `avg_pop_value` 298-302, `quest_expected_clicks` 306-310, `quest_reward` 316-318, `gen_quest` 350-369, `gate_quest` 387-404)
- Modify: `engine/scripts/core/board_logic.gd` (`wanted_lines` 66-72, `wanted_tiers` 78-89, `quest_payable` 136-140)
- Modify: `engine/scripts/core/quests.gd` (`refill` avoid loop 73-77)
- Modify: `engine/scripts/scenes/board.gd` (`_on_giver_tap` asks loop 1856-1877, `_deliver_gate` asks loop 2025-2033, `_giver_is_payable` 858-879)
- Modify: `engine/scripts/ui/giver_stand.gd` (`make` asks loop 64-115; remove `_count_badge` 195-220)
- Test: `engine/tests/quest_tests.gd`, `engine/tests/featured_tests.gd`, `games/grove/tests/grove_model_tests.gd`, `games/grove/tests/grove_placement_tests.gd`

- [ ] **Step 1: Update grove_data constants**

In `games/grove/grove_data.gd`, delete the line `const QUEST_2COUNT_RATE := 0.2 ...` and add near the other quest tunables:

```gdscript
const QUEST_PREMIUM_MIN_LEVEL := 10       # at this asked level and above a quest also pays premium 💎
const QUEST_PREMIUM_GEMS := 1             # the 💎 a high-level quest pays (provisional, sim-tuned)
```

Leave `STAR_CAP`, `QUEST_TIER_BASE`, `QUEST_LEVELS_PER_TIER`, `QUEST_DEBUT_TIER_CAP`, the `GATE_*`
and `CLICK_TO_VALUE` constants for now (removed in later tasks). Remove the
`const QUEST_2COUNT_RATE = D.QUEST_2COUNT_RATE` re-export in `content.gd` (line ~30) and add:

```gdscript
const QUEST_PREMIUM_MIN_LEVEL = D.QUEST_PREMIUM_MIN_LEVEL
const QUEST_PREMIUM_GEMS = D.QUEST_PREMIUM_GEMS
```

- [ ] **Step 2: Rewrite the quest_tests reward + generation assertions (failing test)**

In `engine/tests/quest_tests.gd` replace the reward/clicks/generation block (lines ~24-104) with:

```gdscript
	# --- level-based reward: stars=min(level,CAP), coins=max(0,level-CAP), +gems at >=10 ---
	var r1 := G.quest_reward(1)
	ok(int(r1.stars) == 1 and int(r1.coins) == 0 and not r1.has("gems"), "a level-1 quest pays 1★, no coins, no gems")
	var r6 := G.quest_reward(6)
	ok(int(r6.stars) == int(G.STAR_CAP) and int(r6.coins) == 6 - int(G.STAR_CAP), "level 6 caps stars and pays the surplus in coins")
	var r10 := G.quest_reward(10)
	ok(int(r10.get("gems", 0)) == int(G.QUEST_PREMIUM_GEMS), "level 10 also pays premium 💎")
	ok(not G.quest_reward(9).has("gems"), "level 9 pays no premium 💎")
	var capped := true
	for L in range(1, 13):
		if int(G.quest_reward(L).stars) > int(G.STAR_CAP):
			capped = false
	ok(capped, "stars never exceed STAR_CAP across levels 1–12 (§3 pacing)")

	# --- gen_quest: flat {line, tier}, single item, level-scaled, deterministic ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var q1 := G.gen_quest(1, [1, 2, 3, 4], rng)
	ok(q1.has("line") and q1.has("tier") and not q1.has("asks"), "a quest is flat {line, tier} (no asks array)")
	rng.seed = 999
	var hi_lines := [1, 2, 3, 4, 5, 6]
	var all_in_lines := true
	var tier_ok := true
	for _i in 400:
		var q := G.gen_quest(20, hi_lines, rng)
		if not hi_lines.has(int(q.line)):
			all_in_lines = false
		if int(q.tier) < 1 or int(q.tier) > G.TOP_TIER:
			tier_ok = false
	ok(all_in_lines, "every quest draws a live line")
	ok(tier_ok, "every quest's tier is within 1..TOP_TIER")
	var rA := RandomNumberGenerator.new(); rA.seed = 42
	var rB := RandomNumberGenerator.new(); rB.seed = 42
	ok(str(G.gen_quest(10, hi_lines, rA)) == str(G.gen_quest(10, hi_lines, rB)), "gen_quest is deterministic for a seed")
	# avoid steers the single ask off a fenced line
	rng.seed = 31
	var newest_free := 0
	var newest_avoided := 0
	for _i in 600:
		if int(G.gen_quest(20, hi_lines, rng).line) == 6:
			newest_free += 1
		if int(G.gen_quest(20, hi_lines, rng, [6]).line) == 6:
			newest_avoided += 1
	ok(newest_avoided * 3 < newest_free, "avoid steers the ask off the fenced line (%d→%d)" % [newest_free, newest_avoided])
```

Keep the `active_giver_count` and gate-quest assertions below (gate becomes single-item — adjust in
Step 7 of this task). Keep `avg pop value` assertion? No — remove the `avg_pop_value` /
`quest_expected_clicks` assertions (those functions are deleted).

- [ ] **Step 3: Run the test to confirm it fails**

Run: `make test-one SUITE=engine/tests/quest_tests.gd` (or `godot --headless --path . -s res://engine/tests/quest_tests.gd`)
Expected: parse/FAIL — `quest_reward` takes a Dictionary, `gen_quest` returns `asks`.

- [ ] **Step 4: Rewrite content.gd reward + generation**

In `engine/scripts/core/content.gd`:

Replace `quest_asks` (290-293) with:

```gdscript
static func quest_item(q: Dictionary) -> Dictionary:
	if q.has("line"):
		return {"line": int(q.line), "tier": int(q.tier)}
	if q.has("asks") and not q.asks.is_empty():   # tolerate a stale pre-change save
		return {"line": int(q.asks[0].line), "tier": int(q.asks[0].tier)}
	return {}
```

Delete `avg_pop_value` (298-302) and `quest_expected_clicks` (306-310). Replace `quest_reward`
(316-318) with:

```gdscript
## The level-based reward: capped stars (§3 pacing), the surplus in coins, premium 💎 at high levels.
## All numbers PROVISIONAL (sim-tuned).
static func quest_reward(level: int) -> Dictionary:
	var r := {"stars": clampi(level, 1, STAR_CAP), "coins": maxi(0, level - STAR_CAP)}
	if level >= QUEST_PREMIUM_MIN_LEVEL:
		r["gems"] = QUEST_PREMIUM_GEMS
	return r
```

Replace the body of `gen_quest` (350-369). The line-pick (`_weighted_line_pick`) and tier band stay;
drop the `count` roll and return flat. Ceiling stays `TOP_TIER - 1` for now (raised in Task 2):

```gdscript
static func gen_quest(level: int, live_lines: Array, rng: RandomNumberGenerator, avoid: Array = []) -> Dictionary:
	var lines: Array = live_lines.duplicate()
	lines.sort()
	var tier_hi: int = clampi(QUEST_TIER_BASE + int(level / float(QUEST_LEVELS_PER_TIER)), QUEST_TIER_BASE, TOP_TIER - 1)
	var newest: int = int(lines[lines.size() - 1])
	var li := _weighted_line_pick(lines, rng, avoid)
	var tier := rng.randi_range(QUEST_TIER_BASE, tier_hi)
	if li == newest:
		tier = mini(tier, QUEST_DEBUT_TIER_CAP)
	var reward: Dictionary = quest_reward(tier)
	var featured: bool = rng.randf() < QUEST_FEATURED_RATE
	if featured:
		reward["coins"] = int(reward.coins) + QUEST_FEATURED_COIN_BONUS
		if rng.randf() < QUEST_FEATURED_GEM_ODDS:
			reward["gems"] = int(reward.get("gems", 0)) + QUEST_FEATURED_GEM_BONUS
	return {"line": li, "tier": tier, "reward": reward, "featured": featured}
```

In `gate_quest` (387-404) collapse to a single line and drop the redundant top-level `stars`:

```gdscript
static func gate_quest(roster: Array, map: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var lines: Array = lines_for_map(roster, map)
	lines.sort()
	var li: int
	if rng == null:
		li = int(lines[lines.size() - 1])                 # deterministic richest line
	else:
		li = int(lines[rng.randi_range(0, lines.size() - 1)])
	var gate_t: int = mini(GATE_TIER_BASE + map, TOP_TIER)
	var coins: int = int(quest_reward(gate_t).coins) + GATE_COIN_BONUS
	return {"line": li, "tier": gate_t, "gate": true, "reward": {"stars": GATE_STARS, "coins": coins}}
```

- [ ] **Step 5: Update board_logic + quests consumers**

In `board_logic.gd`, `quest_payable` (136-140):

```gdscript
static func quest_payable(board: BoardModel, q: Dictionary) -> bool:
	var it := G.quest_item(q)
	if it.is_empty():
		return true
	return board.count_of(int(it.line) * 100 + int(it.tier)) >= 1
```

`wanted_lines` (66-72):

```gdscript
static func wanted_lines(pool: Array, quests: Array) -> Array:
	var wanted: Array = []
	for q in quests:
		var it := G.quest_item(q)
		if it.is_empty():
			continue
		if pool.has(int(it.line)) and not wanted.has(int(it.line)):
			wanted.append(int(it.line))
	return wanted
```

`wanted_tiers` (78-89):

```gdscript
static func wanted_tiers(pool: Array, quests: Array) -> Dictionary:
	var out: Dictionary = {}
	for q in quests:
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
```

In `quests.gd` `refill`, replace the avoid loop (73-77):

```gdscript
		var avoid: Array = []
		for q in out:
			var it := G.quest_item(q)
			if not it.is_empty():
				avoid.append(int(it.line))
```

- [ ] **Step 6: Update board.gd delivery + payability**

In `board.gd` `_on_giver_tap`, replace the asks block (1856-1877) — payability now takes the quest, delivery takes one item:

```gdscript
	var it: Dictionary = G.quest_item(q)
	if not BoardLogic.quest_payable(board, q):
		FX.wobble(chip)
		Audio.play("invalid_soft", -6.0)
		return
	var code := int(it.line) * 100 + int(it.tier)
	var cell := board.first_item_of(code)
	board.take(cell)
	var n: Control = piece_nodes.get(cell)
	piece_nodes.erase(cell)
	if n != null and is_instance_valid(n):
		var dest := chip.get_global_rect().get_center() - board_area.get_global_transform().origin - Vector2(csz, csz) / 2.0
		var t := n.create_tween()
		t.set_parallel(true)
		t.tween_property(n, "position", dest, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(n, "scale", Vector2(0.4, 0.4), 0.3)
		t.chain().tween_callback(n.queue_free)
```

In `_deliver_gate` replace the asks block (2025-2033) with the same single-item take:

```gdscript
	if not BoardLogic.quest_payable(board, q):
		FX.wobble(chip)
		Audio.play("invalid_soft", -6.0)
		return
	var git: Dictionary = G.quest_item(q)
	board.take(board.first_item_of(int(git.line) * 100 + int(git.tier)))
```

In `_giver_is_payable` (858-879), the giver entry now carries a single `item` (set in Step 7). Replace the loop body:

```gdscript
func _giver_is_payable(e: Dictionary) -> bool:
	var item: Dictionary = e.get("item", {})
	if item.is_empty():
		return true                       # a generator-reward-only card with no item ask
	var have := board.count_of(int(item.code))
	var met_ok := have >= 1
	var met: Control = item.get("met")
	if met != null and is_instance_valid(met):
		met.visible = met_ok
	return met_ok
```

- [ ] **Step 7: Rewrite giver_stand single-item render + level badge**

In `giver_stand.gd` `make`, replace the asks loop (64-115) with a single-item render plus a level
badge. Result carries `item` not `asks`:

```gdscript
	var it: Dictionary = G.quest_item(q)
	var item_ui: Dictionary = {}
	var bub := Vector2(cx + cardW * 0.82, cy + cardH * 0.41)
	if q.has("grant"):                        # (still drawn for now; grant type removed in Task 4)
		var gdef: Dictionary = G.gen_def(G.GENERATORS, String(q.grant.grants))
		var gtex := Game.art(String(gdef.get("tex", "")))
		if ResourceLoader.exists(gtex):
			var gicon := TextureRect.new()
			gicon.texture = load(gtex)
			gicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			gicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			gicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var gs := cardH * 0.5
			gicon.size = Vector2(gs, gs)
			gicon.position = bub - Vector2(gs, gs) / 2.0
			stand.add_child(gicon)
	elif not it.is_empty():
		var isz := cardH * 0.46
		var acode := int(it.line) * 100 + int(it.tier)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(isz, isz)
		icon.size = Vector2(isz, isz)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.position = Vector2(bub.x - isz / 2.0, bub.y - isz / 2.0)
		var piece := PieceView.make_piece(acode, isz)
		icon.add_child(piece)
		var mpx := isz * 0.85
		var met := _ask_met_check(mpx)
		met.position = Vector2((isz - mpx) / 2.0, (isz - mpx) / 2.0)
		icon.add_child(met)
		wire_tap.call(icon, func() -> void: ask_tap.call(int(it.line), int(it.tier)))
		stand.add_child(icon)
		item_ui = {"code": acode, "piece": piece, "met": met}
		# level badge — the quest's tier reads as its difficulty level
		var lvl := _level_badge(int(it.tier))
		lvl.position = Vector2(cx + 8.0, cy + cardH - 34.0)
		stand.add_child(lvl)
```

Change the final `return` (140) to carry `item`:

```gdscript
	return {"chip": stand, "qi": qi, "item": item_ui, "check": null, "bust": bust}
```

Delete `_count_badge` (195-220). Add a level-badge helper next to `_ask_met_check`:

```gdscript
static func _level_badge(level: int) -> Control:
	var chip := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = BARK
	cs.set_corner_radius_all(10)
	cs.content_margin_left = 8.0; cs.content_margin_right = 8.0
	cs.content_margin_top = 1.0; cs.content_margin_bottom = 1.0
	chip.add_theme_stylebox_override("panel", cs)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = "Lv %d" % level
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", CREAM)
	chip.add_child(lbl)
	return chip
```

- [ ] **Step 8: Update grove_model_tests + grove_placement_tests + featured_tests**

In `featured_tests.gd`, change `G.quest_reward(G.quest_asks(q))` / `G.quest_reward(asks)` to
`G.quest_reward(int(G.quest_item(q).tier))` and any built `asks` to a `tier` int.

In `grove_model_tests.gd`: the giver entry uses `e.item` not `e.asks` (lines ~184-189); delivery
sims iterate one item via `G.quest_item(dq)` taking 1 (lines ~201-203, 277-279).

In `grove_placement_tests.gd`: replace the X3 multi-pair assertions (171-173) with a single-item
render check, and `xb_giver.asks[0].met` → `xb_giver.item.met` (201, 209):

```gdscript
	ok(x3_1.item.has("code"), "a quest renders one item on the giver card")
	ok(not (xb_giver.item.met as Control).visible, "the ✓ is hidden while not payable")
```

- [ ] **Step 9: Run the engine + grove suites green**

Run: `make test-fast` then `make test-grove`
Expected: all PASS.

- [ ] **Step 10: Commit**

```bash
git add -A && git commit -m "Flatten quests to one item from one line + level-based reward"
```

---

## Task 2: Raise TOP_TIER to 12, pin the premium economy

**Files:**
- Modify: `games/grove/grove_data.gd` (`TOP_TIER` line 9; add `PREMIUM_TIER`)
- Modify: `engine/scripts/core/content.gd` (`TOP_TIER` re-export line 17; `sell_reward` 643-648; `water_to_earn_diamond` 657-658; `gen_quest` tier ceiling)
- Test: `engine/tests/quest_tests.gd`, `games/grove/tests/grove_economy_tests.gd`

- [ ] **Step 1: Add the failing economy test**

In `engine/tests/quest_tests.gd` add:

```gdscript
	ok(int(G.TOP_TIER) == 12, "the merge/ask ceiling is 12")
	ok(G.water_to_earn_diamond() == int(pow(2, int(G.PREMIUM_TIER) - 1)), "diamond-earn rate pins to PREMIUM_TIER, not TOP_TIER")
	ok(G.sell_reward(int(G.PREMIUM_TIER)) == Vector2i(0, 1), "the flat-1💎 pinnacle is PREMIUM_TIER")
	ok(int(G.sell_reward(int(G.PREMIUM_TIER) + 1).y) == 0, "a tier above PREMIUM_TIER still sells for coins (not premium)")
	# a high-level quest can now be generated and asks up to 12
	var rngc := RandomNumberGenerator.new(); rngc.seed = 5
	var saw_high := false
	for _i in 800:
		if int(G.gen_quest(40, [1,2,3,4,5,6], rngc).tier) >= int(G.PREMIUM_TIER):
			saw_high = true
	ok(saw_high, "a high-level player can be asked at or above the old ceiling")
```

- [ ] **Step 2: Run to confirm it fails**

Run: `godot --headless --path . -s res://engine/tests/quest_tests.gd`
Expected: FAIL — `TOP_TIER == 8`, `PREMIUM_TIER` undefined.

- [ ] **Step 3: Make the constant + pin changes**

In `grove_data.gd`: change `const TOP_TIER := 8` → `const TOP_TIER := 12` and add `const PREMIUM_TIER := 8`.

In `content.gd`: add `const PREMIUM_TIER = D.PREMIUM_TIER` by the other re-exports (line ~17). In
`sell_reward` (645) change `if tier >= TOP_TIER:` → `if tier >= PREMIUM_TIER:`. In
`water_to_earn_diamond` (658) change `pow(2, TOP_TIER - 1)` → `pow(2, PREMIUM_TIER - 1)`. In
`gen_quest` change the tier ceiling `TOP_TIER - 1` → `TOP_TIER` (any level now askable).

Check the other `TOP_TIER` uses (`content.gd:645` done; `board.gd:843` sell-hint, `board_model.gd:206,228`
top-tier checks, `grove_sim.gd:608`): these intend "the merge ceiling," so they correctly follow
`TOP_TIER` to 12 — leave them. Only the diamond rate and sell pinnacle re-point to `PREMIUM_TIER`.

- [ ] **Step 4: Run quest + economy suites**

Run: `make test-fast` then `make test-grove`
Expected: PASS. If `grove_economy_tests` asserts the old t8 pinnacle/diamond numbers, update those
assertions to `PREMIUM_TIER` (they should already match since PREMIUM_TIER == 8).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Raise TOP_TIER to 12; pin diamond rate + sell pinnacle to PREMIUM_TIER"
```

---

## Task 3: The bag's generator section (gen_bag)

Add the persisted `gen_bag` and the store/place moves and overlay region. Generators still arrive
the old way; this only adds storage.

**Files:**
- Modify: `engine/scripts/core/board_model.gd` (add `gen_bag`; `to_dict`/`from_dict` 234-249; add `store_gen`/`place_gen_from_bag`)
- Modify: `engine/scripts/scenes/board.gd` (persist `gen_bag`; drag-to-bag for generators in `_release_gen`; drag-out from overlay)
- Modify: `engine/scripts/ui/bag_overlay.gd` (generator section)
- Test: `games/grove/tests/grove_model_tests.gd`

- [ ] **Step 1: Failing test for gen_bag round-trip + moves**

In `grove_model_tests.gd` add:

```gdscript
	# gen_bag: store a board generator and place it back
	var bm := BoardModel.new()
	bm.seed_gens(0)
	var first_cell: Vector2i = bm.gens.keys()[0]
	var gid := String(bm.gens[first_cell])
	ok(bm.store_gen(first_cell) and not bm.gens.has(first_cell) and bm.gen_bag.has(gid), "store_gen moves a generator board→gen_bag")
	var open_cell := bm.empty_ground_cells()[0]
	ok(bm.place_gen_from_bag(gid, Vector2i(open_cell)) and bm.gens.values().has(gid) and not bm.gen_bag.has(gid), "place_gen_from_bag moves it gen_bag→board")
	var round := BoardModel.new(); round.from_dict(bm.to_dict())
	ok(str(round.gen_bag) == str(bm.gen_bag), "gen_bag survives to_dict/from_dict")
```

- [ ] **Step 2: Run to confirm it fails**

Run: `godot --headless --path . -s res://games/grove/tests/grove_model_tests.gd`
Expected: FAIL — `gen_bag` / `store_gen` undefined.

- [ ] **Step 3: Implement in board_model.gd**

Add the field near `gens` (line ~12): `var gen_bag: Array = []   # stored generator ids (§ bag section, cap soft 100)`.

Add the moves:

```gdscript
## Move a board generator into the bag's generator section (frees its cell). No-op on a bad cell.
func store_gen(cell: Vector2i) -> bool:
	if not gens.has(cell):
		return false
	gen_bag.append(String(gens[cell]))
	gens.erase(cell)
	return true

## Place a stored generator from the bag onto an open, empty, non-generator cell.
func place_gen_from_bag(id: String, cell: Vector2i) -> bool:
	if not gen_bag.has(id) or gens.has(cell) or not is_open(cell) or item_at(cell) != 0:
		return false
	gen_bag.erase(id)
	gens[cell] = id
	if terrain[idx(cell)] > 0:
		terrain[idx(cell)] = 0
		items[idx(cell)] = 0
	return true
```

In `to_dict` (234-238) add `"gen_bag": gen_bag.duplicate()` to the returned dict; in `from_dict`
(247-249 area) add `gen_bag = Array(d.get("gen_bag", []))`.

- [ ] **Step 4: Persist + wire in board.gd**

In `_persist` (452-462) add `g["gen_bag"] = board.gen_bag`. In the load block (310-326) `from_dict`
already restores it. In `_release_gen` (where a generator drag ends on the bag well), when the drop
target is the bag button, call `board.store_gen(from)` and `_persist()` + `_rebuild_all()`. In the
bag overlay open call, pass `gen_bag` and an `on_place_gen` callable that calls
`board.place_gen_from_bag(id, target_cell)`. (Drag-from-overlay-to-board can reuse the existing
piece-drag plumbing; if that is too large for one step, place via tapping a section tile to drop the
generator on the first open cell: `board.place_gen_from_bag(id, Vector2i(board.empty_ground_cells()[0]))`.)

- [ ] **Step 5: Generator section in bag_overlay.gd**

In `bag_overlay.gd` `open`, after the item slot grid, append a generator region: a label
("Generators") and a row of tiles, one per `gen_bag` id, each showing the generator art and wired to
`on_place_gen.call(id)` on tap. Read `gen_bag` and `on_place_gen` from `cfg`.

- [ ] **Step 6: Run the suites**

Run: `make test-fast` then `make test-grove`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "Add bag generator section (gen_bag) with store/place moves"
```

---

## Task 4: Persist generators + rework arrival (remove gate, grant, hand-in)

The big atomic refactor. Remove the gate and grant quest types and all hand-in machinery; unlock the
next map on spots-done; grant the next generator from a near-end ordinary quest into `gen_bag`; make
`askable_lines` current-map-only.

**Files:**
- Modify: `games/grove/grove_data.gd` (remove `GATE_*`, `CLICK_TO_VALUE`; add `GEN_GRANT_REMAINING_STARS`)
- Modify: `engine/scripts/core/content.gd` (remove `gate_quest`, `grant_quests_for_map`, `grant_map`, `surplus_gen_ids`, `gen_grant`, `gen_can_grant`, `anchor_lines`; simplify `gen_cell_of`; `askable_lines` current-map-only; add `gens_to_grant`)
- Modify: `engine/scripts/core/board_model.gd` (remove `grant_gen`, `place_surplus_gen`, `grow_surplus_gens`)
- Modify: `engine/scripts/core/quests.gd` (remove `pending_grant_quests`, gate branch; add near-end generator quest; spots-done unlock; `refill` rework)
- Modify: `engine/scripts/scenes/board.gd` (remove `_deliver_gate`/`_deliver_grant`/`grow_surplus_gens` call; gate/grant routing; generator-reward delivery; spots-done unlock)
- Modify: `engine/scripts/ui/giver_stand.gd` (remove the `grant` branch; show generator-reward preview on a quest that carries `reward.generators`)
- Test: `engine/tests/quest_tests.gd`, `engine/tests/anchor_tests.gd`, `engine/tests/mechanics_tests.gd`, `engine/tests/quest_fence_tests.gd`, `games/grove/tests/grove_model_tests.gd`

- [ ] **Step 1: Add the generator-grant helper + current-map askable (content.gd)**

In `content.gd`:

`askable_lines` (143-149) → current-map only:

```gdscript
static func askable_lines(roster: Array, map: int, level: int = APPEAR_ALL) -> Array:
	var out: Array = lines_for_map(roster, map, level)
	out.sort()
	return out
```

Delete `anchor_lines` (128-136), `gate_quest` (387-404), `grant_quests_for_map` (184-189),
`grant_map` (164-169), `surplus_gen_ids` (172-177), `gen_grant` (238-246), `gen_can_grant`
(227-231). Simplify `gen_cell_of` (250-254) to `return gen_def(roster, id).get("cell", Vector2i(-1, -1))`.
Add:

```gdscript
## The generator ids that map `map`'s near-end quest should grant: the NEXT map's generators not
## already owned (on the board or in the gen_bag). Empty on the final map or once all are owned.
static func gens_to_grant(roster: Array, map: int, owned: Array) -> Array:
	var out: Array = []
	if map + 1 >= MAPS.size():
		return out
	for g in generators_for_map(roster, map + 1):
		if not owned.has(String(g.id)):
			out.append(String(g.id))
	return out
```

- [ ] **Step 2: grove_data constants**

In `grove_data.gd` remove `GATE_ASK_COUNT`, `GATE_STARS`, `GATE_COIN_BONUS`, `GATE_TIER_BASE`,
`CLICK_TO_VALUE`, `QUEST_DEBUT_TIER_CAP`? (keep DEBUT). Add:

```gdscript
const GEN_GRANT_REMAINING_STARS := 4      # surface the next-generator quest when this few ★ remain to finish the map
```

Remove the matching `content.gd` re-exports for the deleted `GATE_*`/`CLICK_TO_VALUE` (lines ~30-40)
and add `const GEN_GRANT_REMAINING_STARS = D.GEN_GRANT_REMAINING_STARS`.

- [ ] **Step 3: board_model — drop hand-in/surplus placement**

Delete `grant_gen` (82-86), `place_surplus_gen` (92-103), `grow_surplus_gens` (116-124).

- [ ] **Step 4: quests.gd — spots-done unlock + near-end generator quest + refill rework**

Remove `gate_pending` (22-23) and `pending_grant_quests` (37-43) and the gate/grant branches of
`refill` (49-82). Reuse the EXISTING `content.gd` helpers — do NOT invent new ones:
`G.map_stars_left(z, unlocks)` already sums the cost of map z's unowned spots, and the unlock chain
(`G.map_complete(z, unlocks, gates)` / `G.map_unlocked` / `G.frontier_map`) already keys off the
`gates` list. The next map unlocks by **auto-appending z to `gates` on spots-done** (Step 5), so that
chain is left untouched. New helpers in `quests.gd`:

```gdscript
# Stars the player still has to EARN to finish map z (its unowned spot costs, minus what is banked).
static func stars_remaining(z: int, unlocks: Dictionary, banked: int) -> int:
	return maxi(0, G.map_stars_left(z, unlocks) - banked)

# The owned generator ids = on the board ∪ stored in the gen_bag.
static func owned_gens(board_gens: Dictionary, gen_bag: Array) -> Array:
	var out: Array = []
	for id in board_gens.values():
		out.append(String(id))
	for id in gen_bag:
		out.append(String(id))
	return out
```

`refill` (49-82) becomes (no gate/grant special quests; EXACTLY ONE quest may carry the generator
reward — guard against re-attaching to a second quest on a later refill):

```gdscript
static func refill(quests: Array, z: int, unlocks: Dictionary, gates: Array, board_gens: Dictionary, gen_bag: Array, banked_stars: int, level: int, rng: RandomNumberGenerator) -> Array:
	if map_done(unlocks, gates):
		return []
	var out: Array = quests.filter(func(q): return not q.has("grant") and not bool(q.get("gate", false)))
	var lines := G.askable_lines(G.GENERATORS, z, level)
	var target := meter_target(z, banked_stars, unlocks)
	while out.size() < target:
		var avoid: Array = []
		for q in out:
			var it := G.quest_item(q)
			if not it.is_empty():
				avoid.append(int(it.line))
		out.append(G.gen_quest(level, lines, rng, avoid))
	while out.size() > target:
		out.pop_back()
	# near the end of the map, ONE quest also rewards the next generator(s) — idempotent: skip if a
	# quest already carries it (so a later refill never duplicates the reward onto a second quest)
	var already := false
	for q in out:
		if q.has("reward") and q.reward.has("generators"):
			already = true
	var grant := G.gens_to_grant(G.GENERATORS, z, owned_gens(board_gens, gen_bag))
	if not already and not grant.is_empty() and stars_remaining(z, unlocks, banked_stars) <= G.GEN_GRANT_REMAINING_STARS and not out.is_empty():
		var q0: Dictionary = out[0].duplicate(true)
		var rw: Dictionary = (q0.get("reward", {}) as Dictionary).duplicate(true)
		rw["generators"] = grant
		q0["reward"] = rw
		out[0] = q0
	return out
```

No new spot-cost function is needed — `G.map_stars_left` already exists (`content.gd:580`).

- [ ] **Step 5: board.gd — delivery, unlock, routing**

In `_on_giver_tap` (1846-1855) remove the `grant`/`gate` routing branches (those methods are gone).
After paying the reward in `_on_giver_tap`, grant any generators and record the unlock:

```gdscript
	if q.has("reward") and q.reward.has("generators"):
		for gid in q.reward.generators:
			board.gen_bag.append(String(gid))
```

Delete `_deliver_gate` (2024-2058) and `_deliver_grant` (2004-2019). Remove the `grow_surplus_gens`
call (~919). Where the board seeds on a fresh game (332-333) keep `seed_gens` (first map only).
Update the `refill` call site (board.gd ~429) to pass `board.gen_bag`.

**Spots-done auto-unlock (map.gd:1192-1204).** Today, on the spot purchase that completes a map,
`map.gd` calls `Save.set_gate_pointer(z)` so the board can pulse the (now-removed) gate stand.
Replace that block: when `map_spots_done(z)` and `not _gates().has(z)`, record the unlock directly:

```gdscript
		if not _gates().has(z):
			var gg := Save.grove()
			var gl: Array = gg.get("gates", [])
			gl.append(z)
			gg["gates"] = gl
			Save.grove_write()
```

This advances `frontier_map` (which already keys off `gates`) the moment the map's spots are done —
no gate quest needed. Remove the now-dead gate-pointer machinery: the map.gd:1204 `set_gate_pointer`
call (replaced above), the board's consumer at `board.gd:400-406` (`take_gate_pointer` → pulse the
gate stand), and the `Save` helpers at `save.gd:374-391` (`gate_pointer` / `set_gate_pointer` /
`clear_gate_pointer` / `take_gate_pointer`).

**`refill` signature change.** It gains a `gen_bag` parameter after `board_gens`:
`refill(quests, z, unlocks, gates, board_gens, gen_bag, banked_stars, level, rng)`. Update ALL six
callers: the live one at `board.gd:429` (pass `board.gen_bag`) and the five in
`quest_fence_tests.gd` (lines 55, 66, 73, 90, 99 — insert `[]` for `gen_bag`).

- [ ] **Step 6: giver_stand — generator-reward preview, drop grant branch**

In `giver_stand.gd` `make`, remove the `if q.has("grant")` branch. Add, after the item render, a
small generator icon when the quest carries `reward.generators` (reuse the icon code, reading the
first id from `q.reward.generators` via `G.gen_def`).

- [ ] **Step 7: Update tests**

- `quest_tests.gd`: delete the entire gate-quest block (127-171). Add: `gens_to_grant` returns map
  z+1's unowned generators and empties once owned; `askable_lines(roster, 1)` excludes map-0 lines.
- `anchor_tests.gd`: drop the anchor-exemption expectations; assert `askable_lines` == `lines_for_map`.
- `mechanics_tests.gd`: delete grant-quest assertions (48-59, 73-77, 98); assert the hand-in
  functions no longer exist by testing the new path (a map's near-end quest lists z+1 generators).
- `quest_fence_tests.gd`: rewrite to the new `refill` signature (insert `gen_bag`); delete the
  grant-quest-lead assertions (84-100); assert no grant/gate quest is produced, and that with
  `stars_remaining <= GEN_GRANT_REMAINING_STARS` and an unowned next generator, exactly one quest
  carries `reward.generators`.
- `grove_model_tests.gd`: the gate-delivery test (248, 277-294) becomes: restoring the last spot
  appends `z` to `gates` (next map unlocks); the near-end quest grants the generator into `gen_bag`.
- **Delete `engine/tests/gate_unveil_tests.gd`** entirely — it tests the gate-pointer cross-screen
  handoff, which is removed. Drop its suite entry from `engine/tools/run_suites.py` if listed there.

- [ ] **Step 8: Run the full sweep**

Run: `make test`
Expected: every suite PASS. Fix references the compiler flags (removed symbols) until green.

- [ ] **Step 9: Commit**

```bash
git add -A && git commit -m "Persist generators; remove gate+grant types; near-end generator grant"
```

---

## Task 5: Update grove_sim + final verification

**Files:**
- Modify: `games/grove/tools/grove_sim.gd` (quest-shape reads 389-440)
- Test: full sweep

- [ ] **Step 1: Update grove_sim quest reads**

In `grove_sim.gd` replace the `q.asks` / `a.count` loops (389, 398, 408, 419-420, 438-440) with the
single-item shape via `G.quest_item(q)` (one item, count 1) and the payability check
`board.count_of(int(it.line)*100+int(it.tier)) >= 1`. Read reward via `Quests.stars/coins/gems`.

- [ ] **Step 2: Run the sim smoke + full sweep**

Run: `make test` (and, if present, the sim smoke target)
Expected: PASS; the sim runs to completion without referencing `asks`/`count`/gate.

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "Update grove_sim to the flat quest shape"
```

- [ ] **Step 4: Self-check against the spec**

Re-read `docs/superpowers/specs/2026-06-18-quest-generator-simplification-design.md` and confirm:
one quest type, level-based reward + premium gems, generators persist + gen_bag, near-end generator
grant, spots-done unlock, TOP_TIER=12 with PREMIUM_TIER pin. Note any deferred items
(roster re-author, t9–12 art, balance pass) are untouched, as intended.

---

## Notes for the executor

- After each task run `make test-fast` (engine) and `make test-grove` (grove) before committing; run
  the full `make test` at Task 4 and Task 5. The runner fails on any FAIL/crash and never trusts a
  zero exit alone.
- GDScript loads the whole program: if a suite errors with "Invalid call"/"nonexistent function" for
  a symbol you removed, you missed a caller — grep for it and update in the same commit.
- Keep `quest_item` tolerant of a stale `asks` save throughout — it is the only migration shim.
- Generator art for the new section reuses the existing `gen_def(...).tex` sprites.
