# Residents Shop + Map-Unlock Reward Dialog — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a map is fully unlocked, show a one-time reward dialog (coins + diamonds + a free signature spirit, scaling per map), add a "Residents" nav button, and open the resident roster as a shop-style dialog (replacing the always-on bottom panel).

**Architecture:** Pure-logic helpers go in `content.gd` (reward scaling, free-spirit grant, one-time claim, shop card data) — fully headless-testable. The map scene (`map.gd`) builds the dialogs/buttons from those helpers using the existing Kit components (`dialog_frame`, `shop_dialog`) over a veil overlay. Tests live in the **active** `grove_shop_ads_tests` suite (the resident tests in the base are wired only to the parked `grove_placement_tests`).

**Tech Stack:** Godot 4 / GDScript. Tests are headless SceneTree scripts run via `make test-fast` (engine) and `make test` (engine + active grove suites).

---

## File Structure

- `games/grove/grove_data.gd` — add `map_unlock_reward(z)`; remove the flat `MAP_TASK_REWARD` (Task 4).
- `engine/scripts/core/content.gd` — add `map_unlock_reward(z)` passthrough, `grant_resident(z,id)`, `claim_unlock_reward(z)`, `residents_shop_cards(z)`; refactor `welcome_resident`.
- `engine/scripts/scenes/map.gd` — unlock dialog, Residents nav button, residents shop dialog, `_spirit_icon` helper; remove the old welcome panel.
- `games/grove/strings.json` — new UI strings.
- `games/grove/tests/grove_test_base.gd` — new test helpers `_test_unlock_rewards()`, `_test_residents_shop_cards()`.
- `games/grove/tests/grove_shop_ads_tests.gd` — call the new test helpers (active suite).

A note on baseline: a fresh worktree must run `make import` once before tests pass (baked-texture cache is per-checkout). This has already been done for this worktree.

---

## Task 1: Per-map unlock reward data

**Files:**
- Modify: `games/grove/grove_data.gd` (add a static function near `MAP_TASK_REWARD`, line ~502)
- Modify: `engine/scripts/core/content.gd` (add a passthrough near `resident_lines`, line ~400)
- Test: `games/grove/tests/grove_test_base.gd` (new helper) + `games/grove/tests/grove_shop_ads_tests.gd` (call it)

- [ ] **Step 1: Write the failing test**

In `games/grove/tests/grove_test_base.gd`, add a new function (anywhere after `_test_residents`):

```gdscript
# §1 · the per-map UNLOCK reward scales with the map index and names the map's signature spirit.
func _test_unlock_rewards() -> void:
	fresh("unlock_reward_scale")
	for z in G.MAPS.size():
		var rew: Dictionary = G.map_unlock_reward(z)
		ok(int(rew.coins) == 120 + 80 * z, "map %d unlock grants %d coins (120 + 80*%d)" % [z, 120 + 80 * z, z])
		ok(int(rew.gems) == 2 + z, "map %d unlock grants %d diamonds (2 + %d)" % [z, 2 + z, z])
		var sig: Array = G.RESIDENT_SIGNATURE.get(String(G.MAPS[z].id), [])
		var want := String(sig[0].id) if sig.size() > 0 else ""
		ok(String(rew.spirit) == want, "map %d unlock's free spirit is its signature[0] (%s)" % [z, want])
```

In `games/grove/tests/grove_shop_ads_tests.gd`, add this call at the end of `_initialize()` (before the `finish()`/end — match the file's existing closing pattern):

```gdscript
	_test_unlock_rewards()
```

Note: `G.RESIDENT_SIGNATURE` must be reachable through content.gd. It already aliases the data consts (`const RESIDENT_MAX_TIER = D.RESIDENT_MAX_TIER`, etc., line ~44). Add alongside them in `content.gd`:

```gdscript
const RESIDENT_SIGNATURE = D.RESIDENT_SIGNATURE
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_shop_ads_tests`
Expected: FAIL — `G.map_unlock_reward` (and/or `G.RESIDENT_SIGNATURE`) does not exist (parse/lookup error or failed asserts).

- [ ] **Step 3: Write minimal implementation**

In `games/grove/grove_data.gd`, just below `const MAP_TASK_REWARD := {"coins": 120, "gems": 2}` (line ~502):

```gdscript
# The one-time gift for fully unlocking a map (all spots restored + gate delivered). Escalates with the
# map index z: more coins/diamonds on later maps, plus one free signature spirit (the map's non-premium
# critter). z=0 (120 coins / 2 gems) equals the old flat MAP_TASK_REWARD, so the first map is unchanged.
static func map_unlock_reward(z: int) -> Dictionary:
	var sig: Array = RESIDENT_SIGNATURE.get(String(MAPS[z].id), [])
	var spirit: String = String(sig[0].id) if sig.size() > 0 else ""
	return {"coins": 120 + 80 * z, "gems": 2 + z, "spirit": spirit}
```

In `engine/scripts/core/content.gd`, near the other `RESIDENT_*` aliases (line ~44-48) add:

```gdscript
const RESIDENT_SIGNATURE = D.RESIDENT_SIGNATURE
```

And near `resident_lines` (line ~400) add the passthrough:

```gdscript
## The per-map one-time unlock gift {coins, gems, spirit}. Delegates to the game data.
static func map_unlock_reward(z: int) -> Dictionary:
	return D.map_unlock_reward(z)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `make test-one SUITE=games/grove/tests/grove_shop_ads_tests`
Expected: PASS (all `_test_unlock_rewards` asserts green).

- [ ] **Step 5: Commit**

```bash
git add games/grove/grove_data.gd engine/scripts/core/content.gd games/grove/tests/grove_test_base.gd games/grove/tests/grove_shop_ads_tests.gd
git commit -m "Add per-map unlock reward data (scaling coins/gems + signature spirit)"
```

---

## Task 2: Extract `grant_resident` (free spirit grant)

**Files:**
- Modify: `engine/scripts/core/content.gd:452-473` (refactor `welcome_resident`, add `grant_resident`)
- Test: `games/grove/tests/grove_test_base.gd` (extend `_test_unlock_rewards`)

- [ ] **Step 1: Write the failing test**

Append to `_test_unlock_rewards()` in `grove_test_base.gd`:

```gdscript
	# grant_resident adds a t1 WITHOUT spending, and still cascades merges.
	fresh("grant_resident_free")
	var z0 := 0
	var mid := String(G.MAPS[z0].id)
	var gid := String(G.RESIDENT_CORE[0].id)
	var coins_before := Save.coins()
	var ev1: Array = G.grant_resident(z0, gid)
	ok(Save.coins() == coins_before, "grant_resident does NOT spend coins")
	ok(Save.resident_counts(mid, gid)[0] == 1, "grant_resident adds one t1")
	ok(ev1.is_empty(), "a lone grant produces no merge event")
	var ev2: Array = G.grant_resident(z0, gid)
	ok(ev2.size() == 1 and int(ev2[0].to) == 2, "a second grant cascades t1+t1 -> t2")
	# welcome_resident still SPENDS then grants (paid path unchanged).
	fresh("welcome_still_spends")
	Save.add_coins(1000)
	var wc_before := Save.coins()
	var wr: Dictionary = G.welcome_resident(z0, gid)
	ok(bool(wr.ok) and Save.coins() == wc_before - G.RESIDENT_BASE_COST, "welcome_resident still debits the cost")
	ok(Save.resident_counts(mid, gid)[0] == 1, "welcome_resident still lands a t1")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_shop_ads_tests`
Expected: FAIL — `G.grant_resident` does not exist.

- [ ] **Step 3: Write minimal implementation**

In `engine/scripts/core/content.gd`, replace the body of `welcome_resident` (lines ~452-473) and add `grant_resident` directly above it:

```gdscript
## Add one tier-1 instance of `type_id` to map z's roster and cascade two-of-a-kind merges. The shared
## spend-free core of welcome_resident (paid) and the unlock gift (free). Returns the merge events.
static func grant_resident(z: int, type_id: String) -> Array:
	var map_id := String(MAPS[z].id)
	var counts: Array = Save.resident_counts(map_id, type_id).duplicate()
	counts[0] = int(counts[0]) + 1
	Save.set_resident_counts(map_id, type_id, counts)
	return resolve_resident_merges(z)

## Welcome (buy) one t1 resident of `type_id` on map `z`: charge the cost (coins or diamonds via Save),
## then grant_resident. Returns {ok, events}: ok=false with no events on insufficient funds; ok=true with
## the merge events on success.
static func welcome_resident(z: int, type_id: String) -> Dictionary:
	var type_def: Dictionary = {}
	for td in resident_lines(z):
		if String(td.id) == type_id:
			type_def = td
			break
	if type_def.is_empty():
		return {"ok": false, "events": []}
	var cost: Dictionary = resident_cost(type_def)
	var paid: bool
	if String(cost.currency) == "diamonds":
		paid = Save.spend_diamonds(int(cost.cost))
	else:
		paid = Save.spend(int(cost.cost), "welcome_resident")
	if not paid:
		return {"ok": false, "events": []}
	var events := grant_resident(z, type_id)
	return {"ok": true, "events": events}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `make test-one SUITE=games/grove/tests/grove_shop_ads_tests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/core/content.gd games/grove/tests/grove_test_base.gd
git commit -m "Extract grant_resident; welcome_resident reuses it (free-spirit grant path)"
```

---

## Task 3: One-time `claim_unlock_reward`

**Files:**
- Modify: `engine/scripts/core/content.gd` (add after `welcome_resident`)
- Test: `games/grove/tests/grove_test_base.gd` (extend `_test_unlock_rewards`)

- [ ] **Step 1: Write the failing test**

Append to `_test_unlock_rewards()` in `grove_test_base.gd`:

```gdscript
	# claim_unlock_reward grants coins + gems + the free spirit ONCE per map; a second claim is a no-op.
	fresh("claim_unlock_once")
	var cz := 1                                       # map 1 (Orchard): 200 coins, 3 gems, signature "bee"
	var cmid := String(G.MAPS[cz].id)
	var coins0 := Save.coins()
	var gems0 := Save.diamonds()
	var got: Dictionary = G.claim_unlock_reward(cz)
	ok(int(got.coins) == 200 and int(got.gems) == 3, "first claim returns the scaled reward (200c / 3g)")
	ok(Save.coins() == coins0 + 200, "coins credited")
	ok(Save.diamonds() == gems0 + 3, "diamonds credited")
	ok(Save.resident_counts(cmid, String(got.spirit))[0] == 1, "the free signature spirit lands in the roster")
	var coins1 := Save.coins()
	var gems1 := Save.diamonds()
	var again: Dictionary = G.claim_unlock_reward(cz)
	ok(again.is_empty(), "a second claim returns {} (already claimed)")
	ok(Save.coins() == coins1 and Save.diamonds() == gems1, "a second claim grants nothing more")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_shop_ads_tests`
Expected: FAIL — `G.claim_unlock_reward` does not exist.

- [ ] **Step 3: Write minimal implementation**

In `engine/scripts/core/content.gd`, add after `welcome_resident`:

```gdscript
## Grant map z's one-time unlock gift if still unclaimed: coins + diamonds + the free signature spirit.
## Sets the per-map `task_reward` flag so it pays exactly once (shared with the legacy completion gift).
## Returns the granted reward {coins, gems, spirit, events} on the first claim, or {} if already claimed
## (so the scene knows whether to show the celebration dialog). Pure model; no FX, no UI.
static func claim_unlock_reward(z: int) -> Dictionary:
	var g := Save.grove()
	var claimed: Dictionary = g.get("task_reward", {})
	var key := String(MAPS[z].id)
	if claimed.has(key):
		return {}
	claimed[key] = true
	g["task_reward"] = claimed
	Save.grove_write()
	var rew: Dictionary = D.map_unlock_reward(z)
	var coins := int(rew.get("coins", 0))
	var gems := int(rew.get("gems", 0))
	var spirit := String(rew.get("spirit", ""))
	if coins > 0:
		Save.add_coins(coins)
	if gems > 0:
		Save.add_diamonds(gems)
	var events: Array = []
	if spirit != "":
		events = grant_resident(z, spirit)
	return {"coins": coins, "gems": gems, "spirit": spirit, "events": events}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `make test-one SUITE=games/grove/tests/grove_shop_ads_tests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/core/content.gd games/grove/tests/grove_test_base.gd
git commit -m "Add claim_unlock_reward: one-time per-map gift (coins + gems + free spirit)"
```

---

## Task 4: Unlock reward dialog in `map.gd`

**Files:**
- Modify: `engine/scripts/scenes/map.gd` (replace `_grant_map_task_reward`, add dialog + `_spirit_icon`; update call sites at lines ~341 and ~649)
- Modify: `games/grove/grove_data.gd` (remove now-unused `MAP_TASK_REWARD`)

No new unit test (the grant is covered by Task 3). Verify via `make test` + `make smoke` + a manual run.

- [ ] **Step 1: Add the spirit-icon helper and reward-row helper**

In `engine/scripts/scenes/map.gd`, add these helpers near the other small UI builders (e.g. just above `_grant_map_task_reward`, line ~1498):

```gdscript
# A fixed-size resident icon: the type's art when present, else a soft cream disc (signature spirits ship
# without art yet — this keeps the row reading as "a spirit" rather than a broken/empty box).
func _spirit_icon(type_id: String, px: float) -> Control:
	var path := G.resident_art(type_id)
	if path != "" and ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.custom_minimum_size = Vector2(px, px)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	var disc := Panel.new()
	disc.custom_minimum_size = Vector2(px, px)
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(STRAW, 0.9)
	ds.set_corner_radius_all(int(px / 2.0))
	disc.add_theme_stylebox_override("panel", ds)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return disc

# The resident's localized display name for map z (falls back to the raw id if unlisted).
func _resident_name(z: int, type_id: String) -> String:
	for td in G.resident_lines(z):
		if String(td.id) == type_id:
			return tr(String(td.name))
	return type_id

# One reward-reveal row: [icon] · label (expands) · amount (right). Used by the unlock dialog.
func _reward_row(icon: Control, label: String, amount: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", INK)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	var a := Label.new()
	a.text = amount
	a.add_theme_font_size_override("font_size", 22)
	a.add_theme_color_override("font_color", Color(BARK, 0.95))
	a.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(a)
	return row
```

- [ ] **Step 2: Replace `_grant_map_task_reward` with `_maybe_show_unlock_reward` + the dialog**

Replace the whole `_grant_map_task_reward(z)` function (lines ~1498-1518) with:

```gdscript
# One-time map-UNLOCK celebration. Grants the scaled reward (coins + gems + free signature spirit) via the
# model the instant the map first completes (robust to interruption — the grant is committed before any
# UI), then reveals it in a parchment dialog. Idempotent: claim_unlock_reward returns {} after the first
# time, so a revisit shows nothing. Safe in headless rebuilds (the dialog is deferred + tree-guarded).
func _maybe_show_unlock_reward(z: int) -> void:
	var rew: Dictionary = G.claim_unlock_reward(z)
	if rew.is_empty():
		return
	_update_hud()
	if not is_inside_tree():
		return
	_show_unlock_dialog.call_deferred(z, rew)

func _show_unlock_dialog(z: int, rew: Dictionary) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var coins := int(rew.get("coins", 0))
	var gems := int(rew.get("gems", 0))
	var spirit := String(rew.get("spirit", ""))
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		_task_reward_fx(coins, gems)          # defensive: at least play the float FX if the kit is absent
		return
	var overlay := Control.new()
	overlay.name = "UnlockRewardOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dismiss := func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
		_task_reward_fx(coins, gems)
	var veil := ColorRect.new()
	veil.color = Color(INK, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			dismiss.call())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	if coins > 0:
		col.add_child(_reward_row(Look.icon("coin", 44.0), Strings.t("map.unlock.coins"), "+%d" % coins))
	if gems > 0:
		col.add_child(_reward_row(Look.icon("gem", 44.0), Strings.t("map.unlock.diamonds"), "+%d" % gems))
	if spirit != "":
		col.add_child(_reward_row(_spirit_icon(spirit, 44.0), _resident_name(z, spirit), "+1"))
	var collect := Kit.pill_button(Strings.t("map.unlock.collect"), {"bg": "green", "font": 22})
	collect.pressed.connect(func() -> void: dismiss.call())
	var btn_wrap := CenterContainer.new()
	btn_wrap.add_child(collect)
	col.add_child(btn_wrap)
	var width: float = minf(get_viewport_rect().size.x * 0.86, 520.0)
	var opts := {"banner_text": Strings.t("map.unlock.title"), "banner_icon_on": false,
		"on_close": func() -> void: dismiss.call()}
	var dialog: Control = Kit.dialog_frame(col, width, opts)
	cc.add_child(dialog)
	FX.pop_in(dialog)
```

- [ ] **Step 3: Move the trigger to the full-unlock (can_populate) gate**

In `_build_map`, at the `if G.can_populate(z, unlocks, _gates()):` block (line ~344-346), the body currently calls `_add_welcome_panel(z)`. Replace that body so the unlock dialog fires here (the welcome panel is removed in Task 6):

```gdscript
	# §1 residents: a COMPLETED map pays its one-time unlock gift (dialog) and offers the Residents shop.
	if G.can_populate(z, unlocks, _gates()):
		_maybe_show_unlock_reward(z)
```

Then remove the now-stale earlier call at line ~341 (inside the `if map_spots_done(z):` block):

```gdscript
	# DELETE these two lines (the gift now fires on full unlock above, not on spots-done):
	if map_spots_done(z):
		_grant_map_task_reward(z)
```

And update the dead `_map_title_plank` reference at line ~649 (the progress pill is disabled, but the file must still parse): replace `_grant_map_task_reward(z)` there with `_maybe_show_unlock_reward(z)`.

- [ ] **Step 4: Remove the unused `MAP_TASK_REWARD`**

In `games/grove/grove_data.gd`, delete the line:

```gdscript
const MAP_TASK_REWARD := {"coins": 120, "gems": 2}
```

Confirm no other references remain:

Run: `grep -rn "MAP_TASK_REWARD" engine games` — expect no matches.

- [ ] **Step 5: Verify it parses, tests pass, scene smokes**

Run: `make test-fast`
Expected: ALL SUITES PASSED.

Run: `make test`
Expected: ALL SUITES PASSED (engine + active grove suites).

Run: `make smoke`
Expected: the smoke script instantiates the UI/board without error (no crash, exit clean).

- [ ] **Step 6: Commit**

```bash
git add engine/scripts/scenes/map.gd games/grove/grove_data.gd
git commit -m "Show one-time map-unlock reward dialog on full unlock; retire flat MAP_TASK_REWARD"
```

---

## Task 5: Residents nav button

**Files:**
- Modify: `engine/scripts/scenes/map.gd` (`_build_chrome` line ~1264; add `_make_residents_button`, `_refresh_residents_btn`, `_residents_btn`)

- [ ] **Step 1: Declare the button field**

Near the top-of-file chrome state vars (next to `_play_btn`), add:

```gdscript
var _residents_btn: Button = null
```

- [ ] **Step 2: Build the button and insert it into the nav**

In `_build_chrome()` (line ~1264), change the `NavBar.build` spec list from `[Map, Play]` to `[Map, Residents, Play]`:

```gdscript
	var nav := NavBar.build(self, [
		{"make": _make_map_button, "label": Strings.t("map.nav.map")},
		{"make": _make_residents_button, "label": Strings.t("map.nav.residents")},
		{"make": _make_play_button, "label": Strings.t("map.nav.play")}])
```

The Play button is now index 2, not 1. Update the breathe line just below (line ~1274) to target the play button by identity:

```gdscript
	if is_instance_valid(_play_btn):
		FX.breathe_once(_play_btn)
```

Then add the builder + refresh near `_make_map_button` (line ~1288):

```gdscript
# The Residents button (bottom nav, between Map and Play) — opens the resident roster shop. Built like the
# Map button (rounded-rect badge), carrying the `residents` icon (glyph fallback if no png) + a "Residents"
# label. Hidden until the open map is fully unlocked (G.can_populate); a hidden child collapses out of the
# nav HBox, so an incomplete map shows just [Map, Play].
func _make_residents_button() -> Button:
	var open := func() -> void:
		Audio.play("button_tap", -2.0)
		_open_residents_shop(_map_idx)
	var Kit: GDScript = load(KIT_PATH)
	var b: Button
	if Kit == null:
		b = NavBar._make_nav_button("nav_residents.png", 140.0, open)   # defensive
	else:
		var opts: Dictionary = Kit.home_button_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
		opts["px"] = 140.0
		opts["shape"] = "rect"
		opts["calm"] = FX.calm()
		b = Kit.home_button({"icon": "residents", "caption": Strings.t("map.nav.residents"), "action": open}, opts)
	_residents_btn = b
	_refresh_residents_btn()
	return b

# Show the Residents button only when the open map is fully unlocked (same gate as the population layer).
func _refresh_residents_btn() -> void:
	if _residents_btn != null and is_instance_valid(_residents_btn):
		_residents_btn.visible = G.can_populate(_map_idx, _unlocks(), _gates())
```

Note: confirm the unlocks accessor name. `_build_map` reads `unlocks` from somewhere — check whether the scene exposes `_unlocks()` or reads `Save`/a field. If there is no `_unlocks()` helper, use the same source `_build_map` uses (e.g. `Save.grove().get("unlocks", {})`). Match the existing pattern exactly; do not invent a new accessor.

- [ ] **Step 3: Refresh visibility on map open**

In `_open_map(z)` (line ~258) — after the view/index is set — call the refresh so navigating between a complete and incomplete map toggles the button. Add near the end of `_open_map`:

```gdscript
	_refresh_residents_btn()
```

(If `_build_chrome` runs after `_open_map` on first boot, the `_refresh_residents_btn()` inside `_make_residents_button` already covers the initial state; this call handles subsequent navigation.)

- [ ] **Step 4: Verify**

Run: `make test-fast`
Expected: ALL SUITES PASSED.

Run: `make smoke`
Expected: clean instantiation (no crash). The `_open_residents_shop` referenced by the button is added in Task 6 — to keep this task compiling, add a temporary stub now and replace it in Task 6:

```gdscript
func _open_residents_shop(_z: int) -> void:
	pass
```

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/scenes/map.gd
git commit -m "Add Residents nav button (shown when the map is fully unlocked)"
```

---

## Task 6: Residents shop dialog (replaces the welcome panel)

**Files:**
- Modify: `engine/scripts/core/content.gd` (add `residents_shop_cards(z)`)
- Modify: `engine/scripts/scenes/map.gd` (implement `_open_residents_shop`; remove the old welcome panel + `resident_hits` machinery)
- Test: `games/grove/tests/grove_test_base.gd` (new helper) + `grove_shop_ads_tests.gd` (call it)

- [ ] **Step 1: Write the failing test for the card data**

In `grove_test_base.gd`, add:

```gdscript
# §1 · the residents shop card DATA: one card per offered resident, correct price/currency, and an
# affordability flag that reflects the live wallet.
func _test_residents_shop_cards() -> void:
	fresh("residents_shop_cards")
	var z := 0
	var lines := G.resident_lines(z)
	Save.add_coins(G.RESIDENT_BASE_COST)        # enough for a core, not for nothing else
	var cards := G.residents_shop_cards(z)
	ok(cards.size() == lines.size(), "one shop card per offered resident")
	for c in cards:
		var td := {}
		for t in lines:
			if String(t.id) == String(c.id):
				td = t
		var prem := bool(td.get("premium", false))
		ok(int(c.cost) == (G.RESIDENT_PREMIUM_COST if prem else G.RESIDENT_BASE_COST), "card %s has the right cost" % c.id)
		ok(String(c.currency) == ("diamonds" if prem else "coins"), "card %s has the right currency" % c.id)
	# the lone core we can afford is affordable; the premium (diamonds, wallet=0) is not.
	for c in cards:
		if String(c.currency) == "coins":
			ok(bool(c.affordable), "a coin card is affordable with exactly its cost banked")
		else:
			ok(not bool(c.affordable), "a diamond card is unaffordable with 0 diamonds")
```

In `grove_shop_ads_tests.gd`, add the call next to `_test_unlock_rewards()`:

```gdscript
	_test_residents_shop_cards()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_shop_ads_tests`
Expected: FAIL — `G.residents_shop_cards` does not exist.

- [ ] **Step 3: Implement the card-data helper**

In `engine/scripts/core/content.gd`, add after `residents_shop_cards`'s neighbors (near `resident_cost`):

```gdscript
## The data behind the residents SHOP: one card per offered resident on map z — {id, name, cost, currency,
## affordable}. Affordability reads the live wallet (coins/diamonds). Pure model; the scene turns each into
## a Kit shop card (icon node + price pill + on_buy).
static func residents_shop_cards(z: int) -> Array:
	var out: Array = []
	for td in resident_lines(z):
		var cost: Dictionary = resident_cost(td)
		var cur := String(cost.currency)
		var have := Save.diamonds() if cur == "diamonds" else Save.coins()
		out.append({"id": String(td.id), "name": String(td.name), "cost": int(cost.cost),
			"currency": cur, "affordable": have >= int(cost.cost)})
	return out
```

- [ ] **Step 4: Run test to verify it passes**

Run: `make test-one SUITE=games/grove/tests/grove_shop_ads_tests`
Expected: PASS.

- [ ] **Step 5: Implement `_open_residents_shop` in `map.gd` (replace the Task 5 stub)**

```gdscript
# The residents SHOP: the roster as a shop-style dialog (one cell per offered resident — spirit icon, name,
# cost). Buying welcomes a t1 (G.welcome_resident: spend → add → auto-merge), then rebuilds the population
# layer and refreshes the shop's affordability in place. Built over a veil overlay with the shared Kit
# shop_dialog chrome — the same frame the coin/gem store wears.
func _open_residents_shop(z: int) -> void:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return
	var overlay := Control.new()
	overlay.name = "ResidentsShopOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(INK, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)
	var width: float = minf(get_viewport_rect().size.x * 0.92, 520.0)
	# rebuild closure: clears + rebuilds the storefront so a buy refreshes affordability in place.
	var rebuild := {"fn": Callable()}
	rebuild.fn = func() -> void:
		if not is_instance_valid(cc):
			return
		for c in cc.get_children():
			c.queue_free()
		var cards: Array = []
		for cd in G.residents_shop_cards(z):
			var id := String(cd.id)
			cards.append({
				"node": _spirit_icon(id, width / 3.0 * 0.52),
				"label": tr(String(cd.name)),
				"price": str(int(cd.cost)),
				"price_icon": ("gem" if String(cd.currency) == "diamonds" else "coin"),
				"affordable": bool(cd.affordable),
				"on_buy": func() -> void: _buy_resident(z, id, rebuild.fn),
			})
		var sopts: Dictionary = Kit.shop_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
		sopts["banner_text"] = Strings.t("map.welcome.title")
		sopts["on_close"] = func() -> void: overlay.queue_free()
		if float(sopts.get("list_max_h", 0)) <= 0.0:
			sopts["list_max_h"] = get_viewport_rect().size.y * 0.72
		var dialog: Control = Kit.shop_dialog([{"caption": "", "cards": cards}], width, sopts)
		cc.add_child(dialog)
		FX.pop_in(dialog)
	rebuild.fn.call()

# Buy one resident from the shop: welcome (spend + add + auto-merge), rebuild the population layer + refresh
# the open shop, and play the warm success / merge / can't-afford feedback (the old panel's feel).
func _buy_resident(z: int, type_id: String, refresh: Callable) -> void:
	var res := G.welcome_resident(z, type_id)
	if not bool(res.get("ok", false)):
		Audio.play("invalid_soft", -4.0)
		FX.floating_text(self, get_global_rect().get_center() - Vector2(0, 40),
			Strings.t("map.welcome.not_enough"), Color(CREAM, 0.9), 26)
		return
	Audio.play("level_complete", -6.0, 1.15)
	_build_map()
	_update_hud()
	if refresh.is_valid():
		refresh.call()
	var events: Array = res.get("events", [])
	if not events.is_empty():
		var amb: Control = content.get_node_or_null("AmbientLayer")
		Ambient.merge_poof(amb, events.size())
		Audio.play("tidy_poof", -2.0, 1.1)
		FX.floating_text(self, get_global_rect().get_center() - Vector2(0, 40),
			Strings.t("map.welcome.two_became_one"), CREAM, 26)
	else:
		FX.floating_text(self, get_global_rect().get_center() - Vector2(0, 40),
			Strings.t("map.welcome.new_friend"), STRAW, 26)
```

- [ ] **Step 6: Remove the old always-on welcome panel + `resident_hits` machinery**

In `engine/scripts/scenes/map.gd`:

1. Delete the functions `_add_welcome_panel` (lines ~1076-1102), `_welcome_row` (~1106-1144), and `_on_welcome_tap` (~1150-1171).
2. Delete the `resident_hits` field declaration (line ~90) and its `resident_hits.clear()` calls (lines ~303 and ~824).
3. In `_map_tap` (line ~950), delete the resident_hits resolution block (lines ~951-957) so taps fall through to spots/spirits as before:

```gdscript
	# DELETE this block:
	for hit in resident_hits:
		var rn: Control = hit.node
		if rn.get_global_rect().grow(6.0).has_point(gpos):
			_on_welcome_tap(int(hit.z), String(hit.type), rn, gpos)
			return
```

4. Confirm the `if G.can_populate(...)` block in `_build_map` (Task 4 Step 3) no longer references `_add_welcome_panel`.

Run: `grep -rn "resident_hits\|_add_welcome_panel\|_welcome_row\|_on_welcome_tap" engine games` — expect no matches.

- [ ] **Step 7: Verify**

Run: `make test-fast`
Expected: ALL SUITES PASSED.

Run: `make test`
Expected: ALL SUITES PASSED.

Run: `make smoke`
Expected: clean instantiation.

- [ ] **Step 8: Commit**

```bash
git add engine/scripts/core/content.gd engine/scripts/scenes/map.gd games/grove/tests/grove_test_base.gd games/grove/tests/grove_shop_ads_tests.gd
git commit -m "Replace always-on welcome panel with a button-opened Residents shop dialog"
```

---

## Task 7: Strings

**Files:**
- Modify: `games/grove/strings.json` (add under the existing `map` block — `map.nav.residents`, `map.unlock.*`)

- [ ] **Step 1: Add the keys**

Open `games/grove/strings.json`. The existing `map.welcome.*` block (lines ~106-111) and `map.nav.*` (map/play) keys show the nesting. Add:

- under `map.nav`: `"residents": "Residents"`
- a new `map.unlock` block:
  - `"title": "A place restored ✿"`
  - `"collect": "Collect ✿"`
  - `"coins": "Coins"`
  - `"diamonds": "Diamonds"`

(There is no `map.unlock.spirit` string — the spirit row uses the resident's own name via `_resident_name`.)

Match the file's existing JSON structure exactly (nested objects, trailing-comma rules). If keys are flat dotted strings rather than nested, follow whichever form the file already uses for `map.welcome.title`.

- [ ] **Step 2: Verify strings load**

Run: `make test-one SUITE=engine/tests/strings_tests`
Expected: PASS (the strings file parses and required keys resolve).

Run: `make test`
Expected: ALL SUITES PASSED.

- [ ] **Step 3: Commit**

```bash
git add games/grove/strings.json
git commit -m "Add residents-shop + unlock-dialog UI strings"
```

---

## Task 8: Final verification + visual confirmation

- [ ] **Step 1: Full sweep**

Run: `make test`
Expected: ALL SUITES PASSED (engine + active grove suites).

- [ ] **Step 2: Manual visual check (the user verifies, per "verify, don't eyeball")**

Launch the grove game (`make g` or the project's run skill). On a fresh save, fully unlock a map (restore all spots + deliver the gate) and confirm:
- the one-time reward dialog appears with three icon rows (coins, diamonds, spirit) + a "Collect ✿" button;
- after collecting, the Residents button appears next to Map; opening it shows the shop dialog with a cell per resident (icon + cost), buying spends + auto-merges, and unaffordable cells dim;
- revisiting the completed map does NOT re-show the reward dialog.

Capture a screenshot for the user to confirm the look (do not self-judge the visual).

- [ ] **Step 3: Final commit (if any cleanup)**

```bash
git add -A
git commit -m "Residents shop + unlock reward dialog: final cleanup"
```

---

## Self-Review notes

- **Spec coverage:** reward scaling (T1), free spirit grant (T2), one-time dialog + grant (T3/T4), Residents button (T5), shop dialog replacing the panel (T6), strings (T7), tests routed to the active suite (T1/T2/T3/T6). All spec sections map to a task.
- **Type consistency:** `claim_unlock_reward` returns `{coins, gems, spirit, events}` (T3) and `_show_unlock_dialog` reads exactly those keys (T4). `residents_shop_cards` returns `{id, name, cost, currency, affordable}` (T6) consumed verbatim by `_open_residents_shop`. `grant_resident(z, type_id) -> Array` (T2) is called by both `welcome_resident` (T2) and `claim_unlock_reward` (T3).
- **Open verification points flagged in-task:** the unlocks accessor name in `_refresh_residents_btn` (T5 Step 2) and `Kit.pill_button`/`Kit.home_button` opt keys must be confirmed against the live Kit signatures during implementation — match existing call sites, don't invent.
