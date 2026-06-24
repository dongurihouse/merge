extends "res://games/grove/tests/grove_test_base.gd"
## grove · placement — split from the grove_tests monolith; shares grove_test_base.gd.

func _initialize() -> void:
	begin("grove · placement")
	fresh("sui")
	var ss = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(ss)
	if ss.board == null:
		ss._ready()
	await create_timer(0.05).timeout
	var vp: Rect2 = ss.get_viewport_rect()
	# the board bottom bar is Bag (+count) · info bar · Home (bottom_bar IS the row). Selling moved to the
	# info bar's trashcan, so there is no merchant well. Check the row + Bag/Home sit on-screen and the
	# centre info bar (a framed pill) is present.
	ok(vp.encloses(ss.bottom_bar.get_global_rect()), "S1: the bottom bar sits fully on-screen")
	ok(ss.bag_btn != null and is_instance_valid(ss.bag_btn) and vp.encloses(ss.bag_btn.get_global_rect()), \
		"S1: the Bag well sits fully on-screen")
	ok(ss.home_btn != null and is_instance_valid(ss.home_btn) and vp.encloses(ss.home_btn.get_global_rect()), \
		"S1: the Home button sits fully on-screen")
	ok(ss.bottom_bar.find_children("*", "PanelContainer", true, false).size() >= 1, \
		"S1: the centre info bar (a framed pill) is present")
	var board_mat: Control = ss.board_area.get_child(0)
	ok(board_mat.get_global_rect().position.y >= ss.giver_bar.get_global_rect().end.y, \
		"S1: the board frame starts below the quest strip and does not cut off ready cards")
	ok(not board_mat.get_global_rect().intersects(ss.bottom_bar.get_global_rect()), \
		"S1: the board frame reserves its full height and stays clear of the bottom bar")
	# Home → the map you were last on (NOT hard-wired to the hub): the Home button and the Decorate/gate
	# handoff share ONE target = the persisted last_map (empty on a fresh save → the Map boot picks frontier).
	Save.grove()["last_map"] = "barn"
	ok(ss._decorate_target() == "barn", "Home/Decorate target the LAST played map, not the hub")
	Save.grove().erase("last_map")
	ok(ss._decorate_target() == "", "fresh save (no last_map) → empty target (boot picks the frontier)")
	# the Bag well is the SHARED home-button disc: the round target is painted by the button's `normal`
	# StyleBox — a textured disc, or the kit's flat cream-disc fallback (same metrics either way).
	var bag_sb: StyleBox = ss.bag_btn.get_theme_stylebox("normal")
	ok(bag_sb is StyleBoxTexture or bag_sb is StyleBoxFlat, \
		"S1: the bag well paints the round satchel disc (shared home-button disc)")
	# S4: every chip fully on-screen, both scenes (refill asserts when visible)
	Save.grove()["pops"] = 10
	ss._update_water_hud()
	await create_timer(0.05).timeout
	var wchip4: Control = ss.water_label.get_parent().get_parent()
	ok(vp.encloses(wchip4.get_global_rect()), "S4: the water chip sits fully on-screen (board)")
	ok(vp.encloses(ss.coins_label.get_parent().get_parent().get_global_rect()), \
		"S4: the wallet sits fully on-screen (board)")
	ok(vp.encloses(ss.level_label.get_parent().get_parent().get_global_rect()), \
		"S4/S10: the Lv chip sits fully on-screen (board — the module ships it to BOTH scenes)")
	ok(not wchip4.get_global_rect().intersects(ss.level_label.get_parent().get_parent().get_global_rect()), \
		"S4: the water chip and the Lv chip do NOT overlap (owner 2026-06-12)")
	var hs = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hs)
	if hs.content == null:
		hs._ready()
	await create_timer(0.05).timeout
	ok(hs.get_viewport_rect().encloses(hs.level_label.get_parent().get_parent().get_global_rect()), \
		"S4: the Lv chip sits fully on-screen (home)")
	ok(hs.get_viewport_rect().encloses(hs.coins_label.get_parent().get_parent().get_global_rect()), \
		"S4: the wallet sits fully on-screen (home)")

	# S-RESIZE: the home/map canvas must FOLLOW a live viewport resize (drag the window wider / rotate),
	# the way the board's anchored background does. The map is fitted once per build, so without a
	# size_changed re-fit it stays pinned to the old width. Drive two known widths and assert the map
	# rect tracks each (deferred one-frame coalesce → wait two frames). (Baseline set explicitly — the
	# headless start size is whatever Design.fit_desktop_window picked for the test monitor.)
	get_root().size = Vector2i(1080, 1920)
	await create_timer(0.06).timeout
	await create_timer(0.06).timeout
	ok(absf(hs._map_rect.size.x - 1080.0) < 2.0, \
		"S-RESIZE: the home map fits the 1080 width (baseline, got %.0f)" % hs._map_rect.size.x)
	get_root().size = Vector2i(1600, 1920)
	await create_timer(0.06).timeout
	await create_timer(0.06).timeout
	ok(absf(hs._map_rect.size.x - 1600.0) < 2.0, \
		"S-RESIZE: the home map re-fits to the new width on a live resize (got %.0f)" % hs._map_rect.size.x)
	ok(absf(hs._map_rect.position.x) < 2.0, "S-RESIZE: the re-fitted map is flush left (no side sky bars)")
	get_root().size = Vector2i(1080, 1920)
	await create_timer(0.06).timeout

	# S6 regression guard: primary buttons must be SOLID pills — the kit btn_leaf
	# nine-patch collapses invisibly at button heights (margins > the rect), which is
	# how buttons once shipped as floating text. (The chapter ribbon that shared this
	# trap is retired — T49.)
	var _skin = load("res://engine/scripts/ui/skin.gd")
	var _pbtn: Button = _skin.button("X", Callable(), true)
	ok(_pbtn.get_theme_stylebox("normal") is StyleBoxFlat, \
		"S6: primary buttons are solid pills (not the collapsing btn_leaf nine-patch)")
	ok(_pbtn.get_theme_constant("outline_size") == 0, \
		"S6: button labels carry no world-outline on the solid pill (panel-text law)")
	_pbtn.queue_free()
	var _sbtn: Button = _skin.button("Y", Callable(), false)
	ok(_sbtn.get_theme_stylebox("normal") is StyleBoxFlat, "S6: secondary buttons are solid pills too")
	ok(_sbtn.alignment == HORIZONTAL_ALIGNMENT_CENTER, "S6: button labels center in the pill")
	_sbtn.queue_free()

	# S4: the rain-refill chip never clips (it shipped as a half-off-screen sliver)
	ss.water = 0
	ss._update_water_hud()
	await create_timer(0.05).timeout
	ok(ss.refill_btn.visible, "S4: the refill offer shows when water is empty")
	ok(vp.encloses(ss.refill_btn.get_global_rect()), "S4: the refill button sits fully on-screen (was a sliver)")
	ss.water = G.WATER_CAP
	ss._update_water_hud()

	# S1: nothing clips at the TALLER aspect either (owner named 1080×1920 + 1080×2340)
	get_root().size = Vector2i(1080, 2340)
	await create_timer(0.06).timeout
	var vp2: Rect2 = ss.get_viewport_rect()
	ok(absf(vp2.size.y - 2340.0) < 2.0, "S1: viewport actually grew to the tall aspect (got %.0f)" % vp2.size.y)
	ok(vp2.encloses(ss.bottom_bar.get_global_rect()), "S1: bottom nav fully on-screen at 1080×2340")
	ok(vp2.encloses(ss.bag_btn.get_global_rect()), \
		"S1: the Bag well stays on-screen at 1080×2340")
	get_root().size = Vector2i(1080, 1920)
	await create_timer(0.06).timeout
	# (the home/map canvas width-fill geometry is guarded in engine/tests/map_canvas_tests.gd)

	# --- order W: board feel ----------------------------------------------------
	var ws = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(ws)
	if ws.board == null:
		ws._ready()
	await create_timer(0.05).timeout
	# W1: the idle merge hint comes SOONER and rocks gently (was 7s + a fast shake)
	ok(absf(float(ws.IDLE_HINT_SECS) - 4.5) < 0.01, "W1: first idle hint at 4.5s (was 7)")
	ok(int(ws.HINT_ROCK_CYCLES) >= 2 and float(ws.HINT_ROCK_DEG) <= 10.0, \
		"W1: the hint is a gentle multi-cycle rock, not a one-off fast shake")
	for cc in [Vector2i(1, 3), Vector2i(2, 3)]:
		ws.board.terrain[BoardModel.idx(cc)] = 0
		ws.board.place(cc, 101)
	ws._rebuild_pieces()
	ok(not ws._hint_pair().is_empty(), "W1: _hint_pair finds a mergeable pair to rock")
	# W2: rapid generator taps must NEVER be dropped by the animating gate. Open a
	# comfortable region, fire 5 board taps WITHOUT awaiting the 0.22s spawn flight.
	for wy in [1, 2, 4, 5]:                    # open a wide region so 5 bursts can never fill the board
		for wx in range(1, 8):
			var wc := Vector2i(wx, wy)
			ws.board.terrain[BoardModel.idx(wc)] = 0
			ws.board.items[BoardModel.idx(wc)] = 0
	ws._rebuild_pieces()
	var w_before := 0
	for v in ws.board.items:
		if v > 0:
			w_before += 1
	var ghalf := Vector2(ws.csz, ws.csz) / 2.0
	var gpos: Vector2 = ws._cell_pos(Vector2i(G.GEN_CELL)) + ghalf
	for i in 5:
		_tap_board(ws, gpos)
	var w_after := 0
	for v in ws.board.items:
		if v > 0:
			w_after += 1
	ok(w_after - w_before >= 5, \
		"W2: 5 rapid generator taps each land a burst — none eaten by the animating gate (≥5 items) — got %d" % (w_after - w_before))
	# W3: sell discoverability. (a) the first MAX-TIER item floats a one-time hint.
	var top_code := 100 + G.TOP_TIER
	Save.grove().erase("seen_sell_hint")
	var lbls0: int = ws.find_children("*", "Label", true, false).size()
	ws._note_item_landed(top_code)
	ok(bool(Save.grove().get("seen_sell_hint", false)), "W3: a max-tier landing sets the persisted seen flag")
	var lbls1: int = ws.find_children("*", "Label", true, false).size()
	ok(lbls1 > lbls0, "W3: the one-time sell hint floater appears on the first max-tier item")
	ws._note_item_landed(top_code)
	ok(ws.find_children("*", "Label", true, false).size() == lbls1, "W3: the sell hint never fires twice")
	# (b) selling moved to the bottom-bar INFO BAR's trashcan (the drag-to-merchant well is retired):
	# selecting a deletable board item shows the trashcan with its "+N" payout; the info button goes live.
	Feat.FLAGS["ftue_staged_chrome"] = false
	ws._rebuild_givers()
	await create_timer(0.05).timeout
	var sell_es: Array = ws.board.empty_ground_cells()
	var sell_cell := Vector2i(sell_es[0])
	ws.board.place(sell_cell, top_code)        # a top-tier spare with a real payout
	ws._rebuild_pieces()
	ws._select_item(sell_cell)
	ok(ws._selected_cell == sell_cell, "W3: tapping a board item selects it into the info bar")
	ok(ws._info_trash.visible and String(ws._info_trash_count.text).contains("+"), \
		"W3: a deletable item shows the trashcan with its +N sell payout")
	ok(not ws._info_btn.disabled, "W3: the info button goes live for a selected item (opens the Tiers ladder)")
	ws._clear_selection()
	ok(not ws._info_trash.visible and ws._selected_cell.x < 0, "W3: clearing the selection empties the info bar")
	# X3: the giver pill renders one item on the stand for a single-item quest
	var x3_1: Dictionary = ws._make_giver_stand(1, {"line": 1, "tier": 2, "reward": {"exp": 1, "coins": 0}})
	ok(x3_1.item.has("code"), "a quest renders one item on the giver card")
	x3_1.chip.queue_free()

	# XB (Tier 2 §2): the idle-bob carries readiness — ONLY a deliverable giver bobs.
	# A pure, asserted predicate (_giver_is_payable) gates both the ✓ and the bob, and
	# the gate is REACTIVE: it flips as the board gains/loses the asked items. We assert
	# the decision (the boolean) AND the effect (the live loop tween in the bob_tw meta).
	var xb_feat = load("res://engine/scripts/core/features.gd")
	xb_feat.FLAGS["giver_bob"] = true             # the bob is the thing under test
	# a clean board: clear every item, then build a single-ask giver wanting 2× code 102
	for r in G.ROWS:
		for c in G.COLS:
			if ws.board.is_open(Vector2i(r, c)):
				ws.board.place(Vector2i(r, c), 0)
	var xb_giver: Dictionary = ws._make_giver_stand(7, {"line": 1, "tier": 2, "reward": {"exp": 1, "coins": 0}})
	ws.add_child(xb_giver.chip)                    # in-tree so the bob can start immediately
	ws.giver_chips = [xb_giver]
	var bob_bust: Control = xb_giver.bust
	# helper: is a live (valid, running) loop tween parked on the bust?
	var bobbing := func(b: Control) -> bool:
		var tw: Variant = b.get_meta("bob_tw") if b.has_meta("bob_tw") else null
		return tw is Tween and (tw as Tween).is_valid()
	# (1) NOT payable (board holds zero 102) → no bob, ✓ hidden
	ws._refresh_giver_lights()
	ok(ws.board.count_of(102) == 0, "XB: board set up with the ask UNMET (0×102)")
	ok(not ws._giver_is_payable(xb_giver), "XB: an unmet quest is NOT payable")
	ok(not bobbing.call(bob_bust), "XB: a giver whose quest is NOT payable does NOT bob")
	ok(not (xb_giver.item.met as Control).visible, "XB: the ✓ is hidden while not payable")
	# (2) becomes payable (place the asked item) → bob starts, ✓ shows
	var free_cells: Array = ws.board.empty_ground_cells()
	ws.board.place(free_cells[0], 102)
	ws._refresh_giver_lights()
	ok(ws._giver_is_payable(xb_giver), "XB: the quest is payable once the asked item is present")
	ok(bobbing.call(bob_bust), "XB: a giver whose quest IS payable bobs (bob tween live)")
	ok((xb_giver.item.met as Control).visible, "XB: the ✓ shows on the same payable transition")
	# (3) payable → unmet again (remove item) → bob STOPS (reactive, not one-way)
	ws.board.place(free_cells[0], 0)
	ws._refresh_giver_lights()
	ok(not ws._giver_is_payable(xb_giver), "XB: removing the asked item makes it un-payable again")
	ok(not bobbing.call(bob_bust), "XB: the bob stops when the giver is no longer deliverable")
	xb_giver.chip.queue_free()
	ws.giver_chips = []

	# #3: the per-item ✓ is itself the CLAIM affordance. Tapping the asked item routes through
	# _on_item_tap: when the quest is READY (the ✓ is up) it DELIVERS (claims); otherwise it falls
	# back to opening the tier ladder (the inspect path). One controlled quest at index 0 so the
	# delivery is deterministic regardless of prior board state.
	Feat.FLAGS["discovery_ladder"] = true
	for r in G.ROWS:
		for c in G.COLS:
			if ws.board.is_open(Vector2i(r, c)):
				ws.board.place(Vector2i(r, c), 0)
	var claim_q := {"line": 1, "tier": 2, "reward": {"exp": 3, "coins": 0}}
	ws.quests = [claim_q]
	var claim_giver: Dictionary = ws._make_giver_stand(0, claim_q)
	ws.add_child(claim_giver.chip)
	ws.giver_chips = [claim_giver]
	ok(ws.has_method("_on_item_tap"), "#3: the board routes an item tap through _on_item_tap")
	# (a) NOT ready (no 102 on the board) → an item tap opens the ladder, never claims
	ws._refresh_giver_lights()
	ok(not (claim_giver.item.met as Control).visible, "#3: the ✓ is hidden while the ask is unmet")
	var exp_unready := Save.exp_total()
	ws._on_item_tap(0, 1, 2, claim_giver.chip)
	ok(Save.exp_total() == exp_unready and ws.quests.size() == 1, \
		"#3: tapping a NOT-ready item does not claim (it opens the tier ladder instead)")
	# (b) ready (place the asked 102) → the SAME item tap CLAIMS it: delivers + pays exp
	var claim_free: Array = ws.board.empty_ground_cells()
	ws.board.place(claim_free[0], 102)
	ws._rebuild_pieces()
	ws._refresh_giver_lights()
	ok((claim_giver.item.met as Control).visible, "#3: the ✓ shows once the asked item is on the board")
	var exp_ready := Save.exp_total()
	ws._on_item_tap(0, 1, 2, claim_giver.chip)
	ok(Save.exp_total() > exp_ready, "#3: tapping the READY ✓ CLAIMS the quest (delivers, pays exp)")
	ws.giver_chips = []

	Feat.FLAGS["ftue_staged_chrome"] = true
	ws.queue_free()

	# V1 (the locked-generator "after N spots" preview) is PARKED with T17: it was keyed on
	# the old per-spot-count `appears_at`; under per-map generators the next set arrives on map
	# COMPLETION, so the preview needs redefining alongside §6/§7. Test removed with the feature.

	# --- order Y: selling v2 — the diamond pinnacle + the porter's basket --------
	fresh("y")
	var Feat2 = load("res://engine/scripts/core/features.gd")
	Feat2.FLAGS["ftue_staged_chrome"] = false   # merchant + basket present on a fresh board
	Feat2.FLAGS["porter_collect"] = false        # test the MECHANICS, not the drift animation
	var ys = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(ys)
	if ys.board == null:
		ys._ready()
	await create_timer(0.05).timeout
	ys._rebuild_givers()
	await create_timer(0.05).timeout
	ok(ys.basket != null and ys.basket.is_empty(), "Y2: the sell basket starts empty (buy-back parked; no fence chip)")
	# Y1: a t8 (PREMIUM_TIER) sells for exactly 1💎 (no coins); a t5 for 5🪙
	var yt8 := 100 + G.PREMIUM_TIER
	var yd0: int = Save.diamonds()
	var yc0: int = Save.coins()
	ys._grant_sale(yt8, null)
	ok(Save.diamonds() == yd0 + 1 and Save.coins() == yc0, "Y1: a t8 sells for exactly 1💎, no coins")
	ys._grant_sale(105, null)
	ok(Save.coins() == yc0 + 5, "Y1: a t5 sells for 5🪙")
	ok(ys.basket.size() == 2, "Y2: sales land in the basket")
	# Y2: buy back the t8 — EXACT refund (the 1💎 returns), item back on a free cell
	var yd1: int = Save.diamonds()
	var yopen0: int = ys.board.empty_ground_cells().size()
	ys._buy_back(0)
	ok(Save.diamonds() == yd1 - 1, "Y2: buy-back refunds EXACTLY the 1💎 granted (no arbitrage)")
	ok(ys.board.empty_ground_cells().size() == yopen0 - 1, "Y2: the bought-back item returns to a free cell")
	ok(ys.basket.size() == 1, "Y2: the sale leaves the basket on buy-back")
	# Y2: a FULL board blocks buy-back (wobble, no refund, sale kept)
	for yfc in ys.board.empty_ground_cells():
		ys.board.place(yfc, 101)
	var ycfull: int = Save.coins()
	ys._buy_back(0)
	ok(Save.coins() == ycfull and ys.basket.size() == 1, "Y2: full-board buy-back is blocked (no refund, sale kept)")
	# Y2/Y3: a 4th sale overflows cap-3 → the porter collects at once
	ys.basket.clear()
	ys._rebuild_basket()
	for yi4 in 4:
		ys._record_sale(105, Vector2i(5, 0))
	ok(ys.basket.is_empty(), "Y2/Y3: a 4th sale overflows cap-3 → the porter collects (basket emptied)")
	# Y3: the timer collects after ~3 min (buy-back window closes)
	ys._record_sale(105, Vector2i(5, 0))
	ok(ys.basket.size() == 1, "Y3: a sale arms the porter timer")
	ys._porter_tick(ys.PORTER_SECS + 1.0)
	ok(ys.basket.is_empty(), "Y3: the porter collects the basket after ~3 min")
	Feat2.FLAGS["ftue_staged_chrome"] = true
	Feat2.FLAGS["porter_collect"] = true
	ys.queue_free()
	# Y4 invariant: the water↔diamond round trip loses >=10x — never a water pump
	ok(G.water_to_earn_diamond() >= 10 * G.water_a_diamond_buys(), \
		"Y4: water to EARN 1💎 (%d) >= 10x the water 1💎 BUYS (%d)" % [G.water_to_earn_diamond(), G.water_a_diamond_buys()])

	# --- order Z: the coin sink — spirit treats -----------------------------------
	# (Z1/Z2 wayside on-map decorations are RETIRED with the old free-pan overworld:
	# the NEW map model is one image with restoration spots, no on-map wayside plots —
	# G.waysides()/wayside_available/buy_wayside/_on_map_tap no longer exist.)
	var Feat3 = load("res://engine/scripts/core/features.gd")
	# Z3: spirit treats — a 10🪙 recurring sink. Spend deducts exactly, rapid-buy is
	# independent (graceful), and you can't overspend.
	fresh("z3")
	Feat3.FLAGS["spirit_treats"] = true
	var z3 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(z3)
	if z3.board == null:
		z3._ready()
	await create_timer(0.05).timeout
	Save.add_coins(40)
	var z3c0: int = Save.coins()
	z3._buy_treat()
	ok(Save.coins() == z3c0 - z3.TREAT_COST, "Z3: a treat costs exactly 10🪙")
	z3._buy_treat()
	z3._buy_treat()
	ok(Save.coins() == z3c0 - 3 * z3.TREAT_COST, "Z3: rapid treats each deduct independently (graceful)")
	Save.spend(Save.coins())                 # drain to 0
	z3._buy_treat()
	ok(Save.coins() == 0, "Z3: no treat without coins (no overspend)")
	z3.queue_free()

	# §1 · the RESIDENTS population sub-game (replaces the removed §8 home-hub coin-yield loop):
	# welcome (spend) + two-of-a-kind auto-merge + the flattened roster + the populate gate. Own fn.
	_test_residents()
	_test_resident_wiring()
	# T45 · the integration wiring: the 2×-collect doubler, the piggy-vault chrome entry, the
	# daily-login auto-popup — driven through the real Map scene. Own scope (its own fn).
	await _test_t45_wiring()
	_test_2x_doubler_rehome()
	# --- order T (T43): live-IAP ladder + starter + first-buy doubler + rewarded ads. §4 law:
	# --- premium & ads buy SPEED + LOOKS, never POSSIBILITY — every wall is free-passable
	# --- (slower); ads are capped+cooled.

	# T-A: the cash ladder is a real, well-formed escalating curve up to a $49.99/$99.99
	# top, with 💎-per-dollar RISING up the ladder (the whale always gets the best rate).
	finish()
