extends "res://games/grove/tests/grove_test_base.gd"
## grove · shop — split from the grove_tests monolith; shares grove_test_base.gd. Covers the IAP
## ladder, the free claims (water refill + free acorns), the 💎 doubler pricing, and the shop cards.

const Iap = preload("res://engine/scripts/core/iap.gd")   # cash-pack prices/ids live in the IAP catalog now
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")   # the water regen rule (over-cap pause)
const Kit = preload("res://games/grove/ui_kit.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const SpritePanel = preload("res://engine/scripts/ui/sprite_panel.gd")   # the two card/art shadow shapes
const ShopScreen = preload("res://engine/scripts/ui/shop_screen.gd")      # the storefront painting + its hit-region names
const HitOverlay = preload("res://engine/scripts/ui/shop_hit_overlay.gd")
const DebugUI = preload("res://engine/scripts/ui/debug.gd")
const Design = preload("res://engine/scripts/core/design.gd")   # THE design-viewport owner — never re-type the canvas

func _initialize() -> void:
	begin("grove · shop")
	fresh("iap_ladder")
	ok(Data.CASH_PACKS.size() >= 5, "the cash ladder has many tiers (entry → whale ceiling)")
	var prev_rate := -1.0
	var top_price := 0.0
	for pk in Data.CASH_PACKS:
		var price := Iap.usd(String(pk.key))         # price lives in the catalog, keyed by pk.key
		var usd := float(price.substr(1))            # "$4.99" → 4.99
		var rate := float(int(pk.gems)) / usd
		ok(int(pk.gems) > 0 and usd > 0.0, "ladder tier %s grants %d💎" % [price, int(pk.gems)])
		ok(rate > prev_rate - 0.001, "ladder 💎/$ rises at %s (%.1f ≥ prev)" % [price, rate])
		prev_rate = rate
		top_price = maxf(top_price, usd)
	ok(top_price >= 49.99, "the ladder reaches a $49.99+/$99.99-class whale tier (%.2f)" % top_price)

	# T-B: each ladder tier grants exactly its 💎 (once the first-buy doubler is spent).
	fresh("iap_grant")
	Save.set_first_purchase_made()       # past the doubler — steady-state grants
	for ti in Data.CASH_PACKS.size():
		var before := Save.diamonds()
		var got: int = ShopS.grant_cash_pack(ti)
		ok(got == int(Data.CASH_PACKS[ti].gems), "tier %s grants exactly %d💎" % [Iap.usd(String(Data.CASH_PACKS[ti].key)), int(Data.CASH_PACKS[ti].gems)])
		ok(Save.diamonds() == before + int(Data.CASH_PACKS[ti].gems), "...and the wallet ticks up by that much")

	# T-C: the first-purchase DOUBLER doubles the first ladder pack EXACTLY once, then stops.
	fresh("iap_first_buy")
	ok(ShopS.first_buy_doubled(), "a fresh player's first pack is doubled (the offer is live)")
	var fb_before := Save.diamonds()
	var fb_got: int = ShopS.grant_cash_pack(0)
	ok(fb_got == int(Data.CASH_PACKS[0].gems) * int(Data.FIRST_BUY_MULT), \
		"the FIRST pack grants ×%d (%d💎)" % [int(Data.FIRST_BUY_MULT), fb_got])
	ok(Save.diamonds() == fb_before + fb_got, "...credited in full")
	ok(not ShopS.first_buy_doubled(), "the doubler is now spent")
	var fb2_before := Save.diamonds()
	var fb2_got: int = ShopS.grant_cash_pack(0)
	ok(fb2_got == int(Data.CASH_PACKS[0].gems), "the SECOND pack grants ×1 (doubler does not re-fire)")
	ok(Save.diamonds() == fb2_before + int(Data.CASH_PACKS[0].gems), "...the steady-state amount")

	# T-D: the STARTER PACK is claimable exactly ONCE — grants 💎 + banks the water credit.
	fresh("iap_starter")
	ok(ShopS.starter_available(), "the starter pack is offered to a new player")
	var st_gem_b := Save.diamonds()
	var st_got: int = ShopS.grant_starter()
	ok(st_got == int(Data.STARTER_PACK.gems) and Save.diamonds() == st_gem_b + int(Data.STARTER_PACK.gems), \
		"the starter grants its %d💎" % int(Data.STARTER_PACK.gems))
	ok(Save.water_pending() == int(Data.STARTER_PACK.water), "...and banks its water credit for the board")
	ok(not ShopS.starter_available(), "the starter is claimed (own-once)")
	var st_after := Save.diamonds()
	ok(ShopS.grant_starter() == 0 and Save.diamonds() == st_after, "a second starter claim grants nothing")
	# the board applies the banked water credit on open, then clears it.
	ok(Save.take_water_pending() == int(Data.STARTER_PACK.water), "the board drains the banked water credit")
	ok(Save.water_pending() == 0, "...and the credit is cleared (applied exactly once)")

	# T-D(ii): the real-money purchase confirm wears the SAME shared dialog frame as Mail/Daily/Shop:
	# named banner + close controls from Kit.dialog_frame, with the cash-specific Cancel/Confirm body inside.
	fresh("iap_confirm_frame")
	var chost := Control.new()
	chost.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(chost)
	ShopS._confirm_cash(chost, {"opts": {}, "host": chost}, 0)
	var cov: Control = chost.get_child(chost.get_child_count() - 1)
	await process_frame
	ok(cov.find_child("DialogBanner", true, false) != null, "cash confirm uses the shared dialog banner")
	ok(cov.find_child("DialogClose", true, false) != null, "...and the shared dialog close button")
	var cbtns := _button_texts(cov)
	ok(cbtns.has("Cancel") and cbtns.has("Confirm"), "...while keeping its Cancel/Confirm purchase actions")
	chost.queue_free()

	fresh("iap_confirm_real_tap")
	Save.set_first_purchase_made()
	var thost := Control.new()
	thost.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(thost)
	ShopS._confirm_cash(thost, {"opts": {}, "host": thost}, 0)
	var tov: Control = thost.get_child(thost.get_child_count() - 1)
	await process_frame
	await process_frame
	var confirm := _button_with_text(tov, "Confirm")
	ok(confirm != null, "cash confirm has a visible Confirm button for real taps")
	if confirm != null:
		ok(confirm.get_global_rect().size.x > 0.0 and confirm.get_global_rect().size.y > 0.0,
			"cash Confirm has a real hit rect")
		var gems_before := Save.diamonds()
		var expected_gems := int(Data.CASH_PACKS[0].gems)
		_push_tap(confirm.get_global_rect().get_center())
		await process_frame
		await process_frame
		ok(Save.diamonds() == gems_before + expected_gems,
			"real tap on cash Confirm grants the selected pack")
	thost.queue_free()

	# T-E: free rain is a once-daily claim. A successful claim exhausts today's
	# allowance regardless of elapsed cooldown; a new day restores it.
	fresh("claims_refill")
	ok(Claims.can_show("refill_water"), "a fresh refill claim is offerable")
	var rr: Dictionary = Claims.claim("refill_water")
	ok(bool(rr.ok) and int(rr.water) == G.WATER_CAP, "claiming the free refill yields a full can (%d💧)" % G.WATER_CAP)
	ok(Claims.remaining_today("refill_water") == 0, "one claim exhausts the daily free-rain allowance")
	ok(not Claims.can_show("refill_water"), "...and the claim is refused for the rest of the day")
	ok(not bool(Claims.claim("refill_water").ok), "a second same-day claim grants nothing")
	# Even after the old cooldown window, the one-per-day cap remains authoritative.
	Save.grove()["claim_ledger"]["refill_water"]["last"] = Time.get_unix_time_from_system() - Data.CLAIMS.refill_water.cooldown - 1.0
	ok(not Claims.can_show("refill_water"), "elapsed cooldown does not create a second daily free rain")
	# a NEW day resets the cap (the day-rollover in the ledger).
	Save.grove()["claim_ledger"]["refill_water"]["day"] = int(Time.get_unix_time_from_system() / 86400.0) - 1
	Save.grove()["claim_ledger"]["refill_water"]["last"] = 0.0
	ok(Claims.can_show("refill_water") and Save.claim_used_today("refill_water") == 0, "a new day resets the daily cap")

	# T-F: the quest-reward 2× DOUBLER is now a 💎 PURCHASE, gated so the deal always beats the shop
	# coin pouch. The pure helpers (content.gd) decide whether to offer it and what it costs:
	#   • offered only when got >= COLLECT_2X_COIN_RATE (a small reward can't beat the shop),
	#   • price = floor(got / rate) 💎, so the effective coins-per-💎 (got / cost) stays >= rate.
	fresh("collect_2x_pricing")
	var rate := int(Data.COLLECT_2X_COIN_RATE)
	var shop_rate := float(ShopS.COIN_PACK) / float(ShopS.COIN_PACK_GEM_COST)   # 150/5 = 30 coins per 💎
	ok(float(rate) > shop_rate, "the doubler's guaranteed rate (%d) beats the shop pouch (%.0f coins/💎)" % [rate, shop_rate])
	ok(not G.collect_2x_offered(rate - 1), "a reward below the rate is NOT offered (would lose to the shop)")
	ok(G.collect_2x_offered(rate), "a reward at the rate IS offered (the deal beats the shop)")
	ok(G.collect_2x_cost(rate) == 1, "at the threshold the price is 1💎")
	# across a spread of reward sizes the effective coins-per-💎 is ALWAYS >= the guaranteed rate.
	for got2 in [rate, rate + 5, rate * 2, rate * 3 + 7, 500]:
		var cost2 := G.collect_2x_cost(got2)
		ok(cost2 >= 1 and float(got2) / float(cost2) >= float(rate), \
			"doubling %d coins costs %d💎 → %.0f coins/💎 (>= %d, beats the shop)" % [got2, cost2, float(got2) / float(cost2), rate])

	# T-J: the live board surfaces the empty-water stack — the free/💎 refill button exists and the
	# starter water credit is drained on open. The credit is ADDED OVER-CAP (a fresh board starts at a
	# full can, so a clamping drain would silently swallow the paid water — regression guard).
	fresh("oow_board")
	Save.add_water_pending(int(Data.STARTER_PACK.water))
	var bw = board_host()
	ok(bw.refill_btn != null, "the board builds the refill surface")
	ok(Save.water_pending() == 0 and bw.water == G.WATER_CAP + int(Data.STARTER_PACK.water), \
		"the board banks the starter water over-cap on open (%d = full can + %d, not clamped)" % [bw.water, int(Data.STARTER_PACK.water)])
	# drive to empty and surface the stack (water<=0 reveals the refill stack).
	bw.water = 0
	bw._update_water_hud()
	ok(bw._refill_stack.visible, "at empty the refill stack is shown (the friction point)")
	# A ready daily free rain takes priority even when the player can afford the paid fill.
	var free_acorns_before := Save.diamonds()
	ok(bw.refill_btn.text == Strings.t("board.refill.free"), "a ready daily rain labels the empty-board action FREE")
	bw._on_refill()
	var free_overlay: Control = bw.find_child("ShopOverlay", true, false)
	ok(free_overlay != null, "the FREE board action opens the water stall to claim the daily rain")
	ok(bw.water == 0 and Save.diamonds() == free_acorns_before, "the FREE board action spends no acorns and grants no bypass refill")
	if free_overlay != null:
		free_overlay.queue_free()
	Claims.claim("refill_water")                         # exhaust today's free rain without applying its reward
	# option 1 — no silent wall: with today's free rain spent AND too few 🌰 for the paid fill, the
	# refill offer STAYS visible while empty and INVITES the water stall (instead of the old dead wobble).
	# Two always-present cues ride along: the water pill breathes, and a one-time text hint drifts on screen.
	Save.add_diamonds(-Save.diamonds())                 # and too few 🌰 for the paid fill
	bw._empty_hint_shown = false
	bw._update_water_hud()
	ok(bw.refill_btn.visible, "the refill offer stays visible when empty even if unaffordable")
	ok(bw.refill_btn.text == Strings.t("board.refill.shop"), "the unaffordable empty state invites the water stall")
	ok(bw._water_pill != null and bw._water_pill.has_meta("_fx_breathing"), "the water pill breathes while the can is empty")
	# the blocked-tap hint is anchored to the empty water pill and fires ONCE per empty episode — a
	# second dry tap this episode must not stack another floater (the throttle over a naive per-tap cue).
	bw._cue_empty_water()
	var hint_after_1st := 0
	for ch in bw.get_children():
		if ch is Label and String(ch.text) == Strings.t("board.refill.hint"):
			hint_after_1st += 1
	ok(hint_after_1st == 1 and bw._empty_hint_shown, "a tap on the dry can drifts one water hint (anchored to the pill)")
	bw._cue_empty_water()                                # a second dry tap this same empty episode
	var hint_after_2nd := 0
	for ch in bw.get_children():
		if ch is Label and String(ch.text) == Strings.t("board.refill.hint"):
			hint_after_2nd += 1
	ok(hint_after_2nd == 1, "repeated dry taps don't stack the hint (throttled once per empty episode)")
	bw._open_water = Callable()                          # neutralize the stall-open → assert the tap itself grants nothing
	bw._on_refill()
	ok(bw.water == 0, "an unaffordable refill tap grants no water (it routes to the stall)")
	# restoring water settles the pill, hides the offer, and re-arms the hint for the next empty episode
	bw.water = G.WATER_CAP
	bw._update_water_hud()
	ok(not bw._water_pill.has_meta("_fx_breathing"), "the water pill rests once the can is refilled")
	ok(not bw.refill_btn.visible and not bw._empty_hint_shown, "refilled → the offer hides and the hint re-arms")
	# MASTERED can (§3 tier-scaled pop cost): a pop can cost more than 1💧, so a can that still reads
	# 3💧 can be unable to pop at all. "Empty" means "can't pay the pop you just tried" — otherwise a
	# mastered player's can floors at cost-1 and the friction surface stops firing (the no-silent-wall
	# rule above). At the rank-0 cost of 1💧 the same expression is exactly water<=0.
	bw.water = int(G.pop_cost(5)) - 1                       # short of the dearest pop, but NOT empty
	bw._water_short = int(G.pop_cost(5))                    # what _pop_seed records when it refuses
	bw._update_water_hud()
	ok(bw.refill_btn.visible and bw._refill_stack.visible, \
		"a can too thin for a mastered pop (%d💧 of %d) still surfaces the refill offer" % [bw.water, bw._water_short])
	bw.water = int(G.pop_cost(5))                           # now it can pay that pop
	bw._update_water_hud()
	ok(bw._water_short == 0 and not bw.refill_btn.visible, \
		"the offer self-clears the moment the can can pay the refused pop again")
	bw.water = 0
	bw._update_water_hud()
	ok(bw.refill_btn.visible, "an actually-empty can surfaces the offer with no pop recorded (rank-0 behaviour)")
	bw.queue_free()
	# T-J(ii): water is a Save-backed CURRENCY now (like coins/gems). The free refill ADDS a full can
	# over-cap (banks a spare); a plain add clamps to the cap; the 💎 fill tops to full without trimming
	# a spare; and regen pauses above the cap (BoardLogic), so the banked spare is kept.
	fresh("water_currency")
	Save.set_water(G.WATER_CAP - 10)                       # nearly full
	ok(Save.water() == G.WATER_CAP - 10, "Save.water() reads the stored level")
	var after_add := Save.add_water(G.WATER_CAP, true)     # free refill: additive, over-cap
	ok(after_add == G.WATER_CAP * 2 - 10 and Save.water() > G.WATER_CAP, \
		"add_water(over_cap) banks OVER the cap (%d > %d)" % [Save.water(), G.WATER_CAP])
	var regen := BoardLogic.regen(Save.water(), 0.0, Time.get_unix_time_from_system())   # huge elapsed time
	ok(int(regen.water) == Save.water(), "regen is paused while over the cap (the spare is not topped or trimmed)")
	Save.set_water(50)
	ok(Save.add_water(G.WATER_CAP) == G.WATER_CAP, "add_water (no over_cap) clamps to the cap")
	Save.set_water(G.WATER_CAP * 2)
	ok(Save.fill_water() == G.WATER_CAP * 2, "the 💎 fill never trims a banked over-cap spare")
	Save.set_water(30)
	ok(Save.fill_water() == G.WATER_CAP, "the 💎 fill tops a low can to full")
	# Scissors stock unlocks from mastery rank 2. From a map-opened shop it banks a pending tool;
	# from a board-opened shop it calls the board placement hook before spending.
	fresh("scissors_shop")
	var sc_host := Control.new()
	get_root().add_child(sc_host)
	var saw_scissors := false
	for sec in Shop._sections({"host": sc_host, "opts": {}}):
		for cardx in (sec as Dictionary).get("cards", []):
			if String((cardx as Dictionary).get("title", "")) == Strings.t("shop.scissors.title"):
				saw_scissors = true
	ok(not saw_scissors and not Shop.scissors_available(), "scissors stay hidden before any line reaches mastery rank 2")
	Save.grove()["mastery"] = {"1": 60}
	Save.grove_write()
	saw_scissors = false
	for sec in Shop._sections({"host": sc_host, "opts": {}}):
		for cardy in (sec as Dictionary).get("cards", []):
			if String((cardy as Dictionary).get("title", "")) == Strings.t("shop.scissors.title"):
				saw_scissors = true
	ok(saw_scissors and Shop.scissors_available(), "scissors appear once any line reaches mastery rank 2")
	Feat.FLAGS["scissors"] = false
	saw_scissors = false
	for sec_off in Shop._sections({"host": sc_host, "opts": {}}):
		for card_off in (sec_off as Dictionary).get("cards", []):
			if String((card_off as Dictionary).get("title", "")) == Strings.t("shop.scissors.title"):
				saw_scissors = true
	var coins_off := Save.coins()
	ok(not saw_scissors and not Shop.scissors_available()
		and not Shop.buy_scissors()
		and Save.coins() == coins_off and Save.scissors_pending() == 0,
		"the scissors feature flag hides the shop row and refuses purchases before spend")
	Feat.FLAGS["scissors"] = true
	Save.add_coins(G.SCISSORS_COST)
	var coins_before := Save.coins()
	ok(Shop.buy_scissors(), "map-opened scissors purchase succeeds when stocked and affordable")
	ok(Save.coins() == coins_before - G.SCISSORS_COST and Save.scissors_pending() == 1,
		"map-opened scissors purchase spends coins and banks one pending tool")
	var placed := {"count": 0}
	var place_hook := func(commit: bool) -> bool:
		if commit:
			placed.count = int(placed.count) + 1
		return true
	Save.add_coins(G.SCISSORS_COST)
	ok(Shop.buy_scissors(place_hook) and int(placed.count) == 1 and Save.scissors_pending() == 1,
		"board-opened scissors purchase places through the hook instead of banking another pending tool")
	var no_room := func(_commit: bool) -> bool:
		return false
	Save.add_coins(G.SCISSORS_COST)
	var coins_room := Save.coins()
	ok(not Shop.buy_scissors(no_room) and Save.coins() == coins_room,
		"board-opened scissors purchase refuses before spend when there is nowhere to place it")
	sc_host.queue_free()
	fresh("scissors_pending_board")
	Feat.FLAGS["scissors"] = false
	Save.add_scissors_pending(1)
	var sc_code := G.SCISSORS_LINE * 100 + 1
	var scn_off = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(scn_off)
	if scn_off.board == null:
		scn_off._ready()
	ok(Save.scissors_pending() == 1 and (scn_off.board.count_of(sc_code) + scn_off.bag.count(sc_code)) == 0,
		"board entry leaves pending scissors banked while the scissors flag is off")
	scn_off.queue_free()
	Feat.FLAGS["scissors"] = true
	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(scn)
	if scn.board == null:
		scn._ready()
	ok(Save.scissors_pending() == 0 and (scn.board.count_of(sc_code) + scn.bag.count(sc_code)) == 1,
		"board entry drains one pending scissors tool onto the board or into the bag")
	scn.queue_free()
	# T-J(iii): the water cards are HOST-AGNOSTIC, and FREE takes precedence: the paid fill is hidden
	# while today's free rain is ready, then appears after the free claim is consumed.
	fresh("refill_card")
	var wh := Control.new()
	get_root().add_child(wh)
	var saw_refill := false
	var saw_fill := false
	for sec in Shop._sections({"host": wh, "opts": {}}):
		for cardx in (sec as Dictionary).get("cards", []):
			# the free-refill card states the full can it pours and carries NO currency price
			if int((cardx as Dictionary).get("count", 0)) == Shop.refill_amount() \
					and String((cardx as Dictionary).get("price_icon", "")) == "":
				saw_refill = true
			elif int((cardx as Dictionary).get("count", 0)) == int(G.WATER_CAP) \
					and String((cardx as Dictionary).get("price_icon", "")) == "gem":   # the 💎 fill card
				saw_fill = true
	ok(saw_refill, "the storefront offers the free-refill card (no host callback needed)")
	ok(not saw_fill, "the storefront hides the paid fill while the free rain is ready")
	Claims.claim("refill_water")
	saw_fill = false
	for sec in Shop._sections({"host": wh, "opts": {}}):
		for cardx in (sec as Dictionary).get("cards", []):
			if int((cardx as Dictionary).get("count", 0)) == int(G.WATER_CAP) \
					and String((cardx as Dictionary).get("price_icon", "")) == "gem":
				saw_fill = true
	ok(saw_fill, "the paid fill appears after today's free rain is used")
	wh.queue_free()
	# T-J(iv): pressing the free refill in the REAL stall GRANTS THROUGH SAVE (over-cap), end-to-end —
	# no host callback. Start full so the refill banks a spare; assert Save's water doubles.
	fresh("refill_card_live")
	var wsh = map_host()
	Save.set_water(G.WATER_CAP)                            # full → a refill banks a spare
	ShopS.open_water(wsh, {})
	var w_overlay: Control = wsh.find_child("ShopOverlay", true, false)
	ok(w_overlay != null and _press_offer(w_overlay, ShopS.OFFER_REFILL), "the storefront offers the free refill")
	ok(Save.water() == G.WATER_CAP * 2, "pressing the free refill banks a full can over-cap via Save (%d💧)" % Save.water())
	wsh.queue_free()
	# T-J(v): the stall is reachable from BOTH the board AND the hub (map), and grants through Save from
	# each — the host-agnostic win (regression: the hub HUD used to lack the free card entirely). Drive each
	# scene's REAL `_open_water` (the SAME callable the water pill + fires) and assert the grant lands in Save.
	for host_scene in ["res://engine/scenes/Map.tscn", "res://engine/scenes/Board.tscn"]:
		var is_map: bool = "Map" in host_scene
		var where: String = "map" if is_map else "board"
		fresh("refill_card_%s" % where)
		var h = mount(host_scene, map_unready if is_map else board_unready)
		Save.set_water(G.WATER_CAP)                        # full → a refill banks a spare
		ok(h._open_water.is_valid(), "the %s HUD wires an _open_water callable" % where)
		h._open_water.call()                               # the exact path the water pill + fires
		var ov: Control = h.find_child("ShopOverlay", true, false)
		ok(ov != null and _press_offer(ov, ShopS.OFFER_REFILL), "the %s storefront offers the free refill" % where)
		ok(Save.water() == G.WATER_CAP * 2, "...and pressing it grants a full can over-cap via Save (%s)" % where)
		h.queue_free()
	# T-J(vi): the board keeps a live water cache for gameplay; when a shop grant ticks the HUD refresh,
	# the board re-syncs that cache from Save (the on_refresh hook) — no per-currency callback, and it
	# can't undo a pop (the board never fires the refresh mid-pop).
	fresh("board_water_resync")
	var brd = board_host()
	brd.water = G.WATER_CAP
	Save.add_water(G.WATER_CAP, true)                      # a shop grant lands in Save; the cache is now stale
	ok(brd.water == G.WATER_CAP and Save.water() == G.WATER_CAP * 2, "the board's live cache is stale until refresh")
	brd._hud_refresh.call()                                # the post-grant HUD refresh fires on_refresh
	ok(brd.water == Save.water() and brd.water == G.WATER_CAP * 2, "the board re-syncs its live water cache from Save on refresh")
	brd.queue_free()
	# §4: a runtime-opened cell reveals a seed of an OPEN quest LINE (mimics one generator pop), not
	# the old positional 1-2 anchor. Force a single open quest on line 6 → the unlocked cell carries
	# line 6 (the positional formula would yield line 2 at (2,3)).
	fresh("bramopen")
	var bq = board_host()
	bq.quests = [{"line": 6, "tier": 4}]
	bq._open_bramble(Vector2i(2, 3))
	ok(BoardModel.line_of(bq.board.item_at(Vector2i(2, 3))) == 6, \
		"an unlocked cell reveals a seed of an OPEN quest line (6), not the positional 1-2 anchor")
	bq.queue_free()
	# debug affordance: in debug mode the panel's "Drop coin" button calls board.debug_drop_coin(), which
	# lands a tier-1 coin on a free cell AND persists it (so the dropped coin survives the next save/reload).
	fresh("debug_drop_coin")
	var bd = board_host()
	for ci in bd.board.items.size():           # clear the playfield so the only coin is the debug drop
		bd.board.items[ci] = 0
	bd._rebuild_pieces()
	bd.debug_drop_coin()
	await create_timer(0.3).timeout
	var dc := Vector2i(-1, -1)
	for i in bd.board.items.size():
		if bd.board.items[i] > 0 and G.is_coin(bd.board.items[i]):
			dc = BoardModel.cell_of(i)
			break
	ok(dc != Vector2i(-1, -1), "debug_drop_coin lands a coin on an empty board cell")
	ok(bd.piece_nodes.has(dc), "the debug-dropped coin gets a piece node")
	var saved_coin := false
	for v in Save.grove().get("board", {}).get("items", []):
		if int(v) > 0 and G.is_coin(int(v)):
			saved_coin = true
	ok(saved_coin, "debug_drop_coin persists the coin to the save (survives a reload)")
	# coins (and any future collectable) are POCKETED by a tap-to-FOCUS then tap-AGAIN gesture,
	# never by a drag (board.gd _on_release keys off G.is_collectable + the focused cell).
	ok(G.is_collectable(bd.board.item_at(dc)), "the dropped coin counts as a collectable")

	bd.debug_drop_acorn()
	await create_timer(0.3).timeout
	var da := Vector2i(-1, -1)
	for i in bd.board.items.size():
		if int(bd.board.items[i] / 100.0) == 13:
			da = BoardModel.cell_of(i)
			break
	ok(da != Vector2i(-1, -1), "debug_drop_acorn lands an acorn on an empty board cell")
	ok(bd.piece_nodes.has(da), "the debug-dropped acorn gets a piece node")
	var saved_acorn := false
	for v in Save.grove().get("board", {}).get("items", []):
		if int(int(v) / 100.0) == 13:
			saved_acorn = true
	ok(saved_acorn, "debug_drop_acorn persists the acorn to the save (survives a reload)")
	ok(G.is_collectable(bd.board.item_at(da)), "the dropped acorn counts as a collectable")

	var coin_val := G.coin_value(bd.board.item_at(dc))
	var wallet0 := Save.coins()
	var chalf := Vector2(bd.csz, bd.csz) / 2.0
	var dcpos: Vector2 = bd._cell_pos(dc) + chalf
	bd._on_press(dcpos)
	bd._on_release(dcpos)                                   # first tap → focus only
	ok(Save.coins() == wallet0, "first tap on a coin does not pocket it")
	ok(bd.board.item_at(dc) != 0 and bd._selected_cell == dc, "first tap only brings up the info bar")
	bd._on_press(dcpos)
	bd._on_release(dcpos)                                   # second tap, now focused → collect
	ok(Save.coins() == wallet0 + coin_val and bd.board.item_at(dc) == 0, "a second tap on the focused coin pockets it")
	# a drag never collects, even when the coin is already focused
	bd.debug_drop_coin()
	await create_timer(0.3).timeout
	var dc2 := Vector2i(-1, -1)
	for i in bd.board.items.size():
		if bd.board.items[i] > 0 and G.is_coin(bd.board.items[i]):
			dc2 = BoardModel.cell_of(i)
			break
	ok(dc2 != Vector2i(-1, -1), "a second coin dropped for the drag check")
	var wallet1 := Save.coins()
	var dc2pos: Vector2 = bd._cell_pos(dc2) + chalf
	bd._on_press(dc2pos)
	bd._on_release(dc2pos)                                  # focus it
	bd._on_press(dc2pos)
	bd._on_release(dc2pos + Vector2(bd.csz, 0.0))           # drag away (>18px) — must not collect
	ok(Save.coins() == wallet1, "dragging a coin does not pocket it")

	# Opening a chest is a second TAP (the key line is retired): the focused chest opens and
	# credits its COINS-ONLY payout DIRECTLY to the wallet (spendable — the quest clock does not move).
	for ci in bd.board.items.size():
		bd.board.items[ci] = 0
	var chest_spots: Array = bd.board.empty_ground_cells()
	ok(chest_spots.size() >= 1, "test setup: the chest has an open cell")
	var chest_cell := Vector2i(chest_spots[0])
	bd.board.place(chest_cell, 1003)
	bd._rebuild_pieces()
	var chest_wallet := Save.coins()
	var chest_clock := Save.coins_earned_lifetime()
	var chest_acorns := Save.diamonds()
	var chest_range := G.chest_open_range(1003)   # the payout is ROLLED — assert range membership, not a number
	var chest_pos: Vector2 = bd._cell_pos(chest_cell) + chalf
	bd._on_press(chest_pos)
	bd._on_release(chest_pos)               # first tap: focus only
	ok(bd.board.item_at(chest_cell) == 1003 and Save.coins() == chest_wallet, "first tap focuses the chest (no open)")
	bd._on_press(chest_pos)
	bd._on_release(chest_pos)               # second tap: OPEN
	await create_timer(0.1).timeout
	ok(bd.board.item_at(chest_cell) == 0, "the second tap opens (consumes) the chest — no key needed")
	var opened_coins := Save.coins() - chest_wallet
	ok(opened_coins >= maxi(0, int((chest_range.coins as Array)[0])) and opened_coins <= int((chest_range.coins as Array)[1]),
		"the open credits coins rolled from the chest tier's range (%d)" % opened_coins)
	# THE CLOCK IS QUESTS ONLY (owner call 2026-07-25): a chest is a board pickup, so its coins are fully
	# spendable but must NOT advance progression. Only delivering a quest moves the level clock.
	ok(Save.coins_earned_lifetime() == chest_clock, "chest coins are SPENDABLE-ONLY — the level clock does not advance (quests only)")
	# COINS ONLY (owner call 2026-07-27): the chest acorn payout is DELETED — an open must leave
	# the premium wallet exactly where it was.
	var opened_acorns := Save.diamonds() - chest_acorns
	ok(opened_acorns == 0, "opening a chest does NOT move the premium wallet (delta %d)" % opened_acorns)
	# nothing is left behind: the open credits the wallet directly (the old face-value item spawn
	# died with the 12-tier coin ladder), so the board holds no spawned reward items.
	var leftover := 0
	for i2 in bd.board.items.size():
		if int(bd.board.items[i2]) > 0:
			leftover += 1
	ok(leftover == 0, "a tap-opened chest leaves no board items behind (direct wallet credit)")

	# TOUCH SLOP: a press only ARMS the drag — the tile must NOT lift until the pointer travels past
	# _drag_slop_px, so a wobbly tap stays a tap (select / collect / deliver, never an accidental drag).
	var slop_spots: Array = bd.board.empty_ground_cells()
	ok(slop_spots.size() >= 1, "test setup: the slop check has an open cell")
	var slop_cell := Vector2i(slop_spots[0])
	bd.board.place(slop_cell, 101)
	bd._rebuild_pieces()
	var slop_pos: Vector2 = bd._cell_pos(slop_cell) + chalf
	bd._on_press(slop_pos)
	ok(bd._drag_pending and bd._drag_node == null,
		"a press arms the drag but does not lift the tile (touch slop)")
	bd._on_release(slop_pos)
	ok(not bd._drag_pending and bd._selected_cell == slop_cell,
		"releasing inside the slop is a TAP — it selects instead of dragging")
	ok(bd._drag_slop_px() >= 24.0, "the touch slop is at least a fingertip-wobble wide")
	var drag_down := InputEventMouseButton.new()
	drag_down.button_index = MOUSE_BUTTON_LEFT
	drag_down.pressed = true
	drag_down.position = slop_pos
	bd._on_board_input(drag_down)
	var drag_move := InputEventMouseMotion.new()
	drag_move.position = slop_pos + Vector2(bd._drag_slop_px() + 8.0, 0.0)
	bd._on_board_input(drag_move)
	var drag_up := InputEventMouseButton.new()
	drag_up.button_index = MOUSE_BUTTON_LEFT
	drag_up.pressed = false
	drag_up.position = slop_pos
	bd._on_board_input(drag_up)
	ok(bd.get_node_or_null("LadderOverlay") == null,
		"a drag gesture that returns to its selected item does not open the tier ladder")
	bd.queue_free()

	# The board's bottom-bar Home + Bag wells build through the SAME shared code-drawn
	# Kit.action_button as the home bottom bar (T5 of the action-button rollout) — a CutPaperPanel
	# rugged edge + centered glyph, not a baked nav_<x>.png sprite. The Bag well additionally keeps
	# its BagContent overlay host (the most-recent stashed item) intact.
	fresh("board_action_wells")
	var bx = board_host()
	var home_tile := bx.find_child("BoardHomeTile", true, false) as Button
	ok(home_tile != null and home_tile.find_child("ActionButtonDeckleSurface", true, false) != null,
		"the board Home well wears the shared code-drawn rugged edge")
	var bag_well := bx.find_child("BagWell", true, false) as Button
	ok(bag_well != null and bag_well.find_child("ActionButtonDeckleSurface", true, false) != null,
		"the board Bag well wears the shared code-drawn rugged edge")
	ok(bag_well != null and bag_well.get_node_or_null("BagContent") != null,
		"the Bag well keeps its stashed-item overlay host")
	# …and both wells are made of the SAME MATERIAL as the bottom nav tabs — the shared paper-button
	# surface treatment (engine/scripts/ui/paper_button.gd), minus the tab geometry that only makes sense
	# for a tile anchored to the screen edge. Verified against the mock on the like-for-like rig
	# (`make shot-mock CELLS="mock:infobar_bag infobar_bag:fill=#A798C0"`; the mock draws this same bag
	# well in its info bar): left-side rms 0.009 against the mock's own paper grain of 0.009.
	assert_paper_button(home_tile, "the board Home well", true)
	assert_paper_button(bag_well, "the board Bag well", true)
	var unlock_bar := bx.find_child("NextUnlockBar", true, false) as Control
	ok(unlock_bar != null and unlock_bar.find_child("UnlockDeckleSurface", true, false) != null,
		"the NEXT UNLOCK bar wears a code-drawn rugged paper edge")
	# the strip's bar IS the shared Kit.progress_bar (the level dialog's component): one track + one
	# fill node, named off the "UnlockBar" base — the two bars can never drift apart.
	ok(unlock_bar != null and unlock_bar.find_child("UnlockBarTrack", true, false) != null,
		"the NEXT UNLOCK strip wears the shared Kit.progress_bar track")
	ok(unlock_bar != null and unlock_bar.find_child("UnlockBarFill", true, false) != null,
		"the NEXT UNLOCK strip wears the shared Kit.progress_bar fill")
	# the strip is the FIRST ROW of the content stack now: strip → quest fence → board flow relative
	# to each other, with the stack's top edge as the page's one absolute anchor below the HUD.
	var bar_slot := unlock_bar.get_parent() as Control if unlock_bar != null else null
	ok(bar_slot != null and bar_slot.name == "UnlockBarSlot"
		and bar_slot.get_parent() == bx._stack and bar_slot.get_index() == 0,
		"the NEXT UNLOCK bar leads the content stack (strip → quests → board relative flow)")
	# the stack's top edge sits EDGE_GAP below the HUD's measured bottom (Hud.bottom_px — the Lv
	# badge), so the NEXT UNLOCK strip can never slide behind the pills; and the rows centre in the
	# region so spare room splits equally above and below (matching top/bottom page margins).
	var HudMod = load("res://engine/scripts/ui/hud.gd")
	ok(bx._stack != null and bx._stack.offset_top - Look.safe_top(bx) >= HudMod.bottom_px() + 8.0,
		"the content stack anchors clear of the HUD pills / level badge")
	ok(bx._stack != null and bx._stack.alignment == BoxContainer.ALIGNMENT_CENTER,
		"the content stack centres its rows (equal top/bottom page margins)")
	var info_tray := bx.find_child("ActionBarInfoTray", true, false) as Control
	ok(info_tray != null and info_tray.find_child("ActionBarInfoDeckleSurface", true, false) != null,
		"the bottom info tray wears a code-drawn rugged paper edge")
	var info_bar := bx.find_child("ActionBarInfoBar", true, false) as Control
	var info_btn := info_bar.get_meta("info_btn") as Button if info_bar != null else null
	ok(info_btn != null and info_btn.find_child("InfoIconShadow", true, false) != null,
		"the bottom info icon casts a shadow")
	await create_timer(0.05).timeout          # the row's geometry is what is under test: let it settle
	await _check_bottom_row_is_a_tab_bar(bx, home_tile, info_tray, bag_well)
	bx.queue_free()
	# ── T44 · the diegetic return surfaces build + drive (§10/§13 · §18) ─────────
	# Both surfaces are world objects (parchment cards), not bare chrome. Open them on a
	# REAL tree-attached host so the kit + viewport resolve, then drive the actual buttons
	# end-to-end: the piggy-bank Claim→Confirm cracks the jar; the calendar Claim claims today's rung.
	fresh("vault_surface")
	Feat.FLAGS["piggy_vault"] = true   # the vault is parked (flag OFF); flip on to drive its surface
	var vhost = map_host()
	# fill the jar past the threshold, open the surface, and assert it framed a parchment card.
	Vault.skim(Vault.claim_min() * Vault.skim_den() * 4)   # well past claimable
	var v_before := Save.diamonds()
	var v_banked := Vault.balance()
	VaultUI.open(vhost)
	var v_overlay: Control = vhost.get_child(vhost.get_child_count() - 1)
	ok(v_overlay.find_children("*", "PanelContainer", true, false).size() >= 1, \
		"the piggy bank opens as a framed parchment card (diegetic, §13)")
	# press the green PRICE CTA (the claim button wears the jar's fixed price now, not the word "Claim") →
	# then Confirm on the spawned crack confirm → the jar cracks.
	ok(_press_label(v_overlay, Vault.price_usd()), "the piggy bank shows its claim CTA (the fixed price)")
	var v_confirm: Control = vhost.get_child(vhost.get_child_count() - 1)
	ok(_press_label(v_confirm, "Confirm"), "the crack confirm shows a Confirm button")
	ok(Save.diamonds() == v_before + v_banked and Vault.balance() == 0, \
		"cracking the jar through the surface grants the banked 💎 and empties it")
	vhost.queue_free()
	Feat.FLAGS["piggy_vault"] = false  # restore the shipped default (parked)

	fresh("login_surface")
	var lhost = map_host()
	var l_coins := Save.coins()
	var l_streak := Login.streak()
	LoginUI.open(lhost)
	var l_overlay: Control = lhost.get_child(lhost.get_child_count() - 1)
	# the reskinned day cells are baked cut-paper sprite panels (Controls named DailyCell_*) plus the wide
	# DailyCapstone — a full week of reward slots.
	ok(l_overlay.find_children("DailyCell_*", "Control", true, false).size() >= 6 \
		and l_overlay.find_child("DailyCapstone", true, false) != null, \
		"the calendar opens as a framed card with a week of reward cells (diegetic, §13)")
	var daily_grid := l_overlay.find_child("DailyGrid", true, false) as GridContainer
	var daily_cells := l_overlay.find_children("DailyCell_*", "Control", true, false)
	ok(daily_grid != null and daily_grid.get_theme_constant("h_separation") >= 24 \
		and daily_grid.get_theme_constant("v_separation") >= 24, \
		"the daily grid leaves a slightly larger gutter between cards")
	var first_daily_cell := daily_cells[0] as Control if daily_cells.size() > 0 else null
	ok(first_daily_cell != null and first_daily_cell.custom_minimum_size.y / maxf(1.0, first_daily_cell.custom_minimum_size.x) <= 1.30, \
		"daily cards are shorter and closer to square")
	var today_icon_host := l_overlay.find_child("DailyRewardIconHost", true, false) as Control
	var today_amount := l_overlay.find_child("DailyAmount", true, false) as Control
	var today_inner := today_icon_host.get_parent() as Control if today_icon_host != null else null
	ok(today_icon_host != null and today_amount != null and today_inner != null \
		and today_icon_host.anchor_top >= 0.48 and today_amount.anchor_top >= 0.80, \
		"today's reward icon and amount sit lower in the card with more top breathing room")
	ok(today_icon_host != null and today_icon_host.offset_top >= 15.0 and today_icon_host.offset_bottom >= 15.0, \
		"today's reward icon is nudged down 15px")
	ok(today_amount != null and today_amount.offset_top >= 35.0 and today_amount.offset_bottom >= 35.0, \
		"today's reward amount is nudged down another 10px")
	var done_cell := LoginUI._day_cell(Kit, {"state": "done", "reward": {"coins": 50}, "day": 1, "label": "Day 1"}, 120.0, 150.0)
	var done_check := done_cell.find_child("DailyClaimedCheck", true, false) as TextureRect
	ok(done_check != null and done_check.custom_minimum_size.x >= 89.0, \
		"a claimed day uses a 20% larger central check mark")
	ok(done_check != null and is_equal_approx(done_cell.modulate.a, 1.0) and is_equal_approx(done_check.modulate.a, 1.0), \
		"the claimed-day check mark is fully opaque")
	var done_cover := done_cell.find_child("DailyClaimedCover", true, false) as ColorRect
	ok(done_cover == null, "the claimed day no longer uses a separate transparent cover")
	var done_face := done_cell.find_child("DailyClaimedCardFace", true, false) as Control
	ok(done_face != null and done_face.modulate.a < 1.0 and done_face.modulate.a >= 0.55, \
		"the claimed day recedes by making the card face semi-transparent")
	var done_check_host := done_cell.find_child("DailyClaimedCheckHost", true, false) as Control
	ok(done_check_host != null and absf(done_check_host.anchor_top - 0.50) <= 0.01, \
		"the claimed-day check mark is centered in the card")
	done_cell.free()
	# today's card is claimed by TAPPING the highlighted card (a transparent full-cell DailyClaimButton),
	# not a labelled Claim pill.
	var claim_btn := l_overlay.find_child("DailyClaimButton", true, false) as Button
	ok(claim_btn != null, "today's card exposes a claim tap-target")
	if claim_btn != null:
		claim_btn.pressed.emit()
	ok(Login.streak() == l_streak + 1 and Save.coins() >= l_coins, \
		"collecting through the surface claims today's rung and bumps the streak")
	lhost.queue_free()

	# (T-K free-acorn faucet tests removed 2026-06-23 — the faucet was retired; acorns are earned-only, Option A.)

	# --- UI redesign P2: the empty-cell well reads the role token on the Sunk plane ---
	var cell_sb := BoardScript._cell_style()
	ok(cell_sb.bg_color.is_equal_approx(Pal.CELL_EMPTY), "empty cell well uses Pal.CELL_EMPTY (not the old hardcoded tan)")
	ok(cell_sb.shadow_size == 0, "empty cell sits on the Sunk plane (no drop shadow)")
	# the backdrop is one of the cut-paper scene plates, picked at random per board entry, covering
	# the viewport (KEEP_ASPECT_COVERED — full-bleed art, not a tile).
	var backdrop := BoardScript._field_backdrop()
	var backdrop_path := String((backdrop as TextureRect).texture.resource_path) if backdrop is TextureRect and (backdrop as TextureRect).texture != null else ""
	var backdrop_known := false
	for bg_rel: String in BoardScript.FIELD_BACKDROPS:
		if backdrop_path.ends_with(bg_rel):
			backdrop_known = true
	ok(backdrop_known and (backdrop as TextureRect).stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, \
		"board backdrop is one of the cut-paper scene plates, full-bleed covered")
	# Board locked/unlocked wells now use the same torn-cell component as the bag, so all cell states share
	# one code-drawn surface instead of the old receding-blue board-only background. (sprites: false keeps
	# the code-drawn torn coverage; the generated paper-sprite faces are asserted separately below.)
	var slot_opts := Kit.board_cell_opts_from_config({"bag_card": {"cell_w": 100, "cell_h": 100}, "torn_cell": {"sprites": false}})
	var border_slot: Control = Kit.slot_cell({"state": "locked", "frontier": true}, slot_opts)
	ok(border_slot.find_child("TornCell", true, false) != null \
		and border_slot.find_child("TornCellLock", true, false) != null \
		and border_slot.find_child("SlotCellBackground", true, false) == null, \
		"border locked cells use the shared torn-cell locked face")
	var deep_slot: Control = Kit.slot_cell({"state": "locked", "frontier": false}, slot_opts)
	ok(deep_slot.find_child("TornCell", true, false) != null \
		and deep_slot.find_child("TornCellLock", true, false) != null \
		and deep_slot.find_child("SlotCellBackground", true, false) == null, \
		"deep locked cells keep the same shared torn-cell locked face")
	var open_slot: Control = Kit.slot_cell({"state": "empty"}, slot_opts)
	ok(open_slot.find_child("TornCell", true, false) != null \
		and open_slot.find_child("TornCellWell", true, false) != null \
		and open_slot.find_child("SlotCellBackground", true, false) == null, \
		"board open cells use the shared torn-cell open well")
	border_slot.free()
	deep_slot.free()
	open_slot.free()
	# The GENERATED paper-sprite faces (torn_cell.sprites, the default): open/alt checker mates and
	# light/deep locked variants — the face becomes one TextureRect off CELL_SPRITE_PATHS.
	var sprite_opts := Kit.board_cell_opts_from_config({"bag_card": {"cell_w": 100, "cell_h": 100}})
	var sprite_open: Control = Kit.slot_cell({"state": "empty"}, sprite_opts)
	var sprite_alt: Control = Kit.slot_cell({"state": "empty", "alt": true}, sprite_opts)
	var sprite_lock: Control = Kit.slot_cell({"state": "locked", "frontier": true}, sprite_opts)
	var sprite_deep: Control = Kit.slot_cell({"state": "locked", "frontier": false}, sprite_opts)
	# the face goes through Kit.clean_tex_path (defringe + alpha feather), so the texture is the
	# committed BAKED mirror — compare on the stem, which both "<name>.png" and "<name>@256.png" share.
	var sprite_stem := func(n: Control) -> String:
		var tr := n.find_child("SlotCellSprite", true, false) as TextureRect
		if tr == null or tr.texture == null:
			return ""
		return String(tr.texture.resource_path).get_file().get_basename().split("@")[0]
	ok(String(sprite_stem.call(sprite_open)) == "cell_paper_open", \
		"default open cells wear the generated open paper sprite")
	ok(String(sprite_stem.call(sprite_alt)) == "cell_paper_open_alt", \
		"alt-parity open cells wear the checker-mate paper sprite")
	ok(String(sprite_stem.call(sprite_lock)) == "cell_paper_locked", \
		"frontier locked cells wear the light locked paper sprite")
	ok(String(sprite_stem.call(sprite_deep)) == "cell_paper_locked_deep", \
		"deep interior locks wear the receded locked paper sprite")
	# and the polish must actually be applied — a raw load would be the un-feathered source
	var polished := (sprite_open.find_child("SlotCellSprite", true, false) as TextureRect).texture
	ok(String(polished.resource_path).find("/baked/") >= 0, \
		"cell faces draw the baked, edge-feathered mirror (not the raw binary-alpha cut)")
	sprite_open.free()
	sprite_alt.free()
	sprite_lock.free()
	sprite_deep.free()
	var bramble_node: Control = PieceViewScript.make_bramble(Vector2i(0, 0), 100.0)
	ok(bramble_node.find_child("SlotCellSprite", true, false) != null \
		and bramble_node.find_child("SlotCellBackground", true, false) == null, \
		"frontier locked cell wears the shared locked cell face (paper sprite by default)")
	var lv_num: Label = bramble_node.find_child("lv_num", true, false) as Label
	ok(lv_num == null, "frontier locked cell omits the old shared level-badge marker")
	ok(not _tree_has(bramble_node, "PanelContainer"), "locked cell has no dark cream-on-bark gate chip (the loud badge is gone)")
	ok(_all_ignore(bramble_node), "frontier locked cell ignores mouse so the board input surface receives taps")
	bramble_node.free()

	# The bag dialog uses the torn-cell component for open and locked slots. The next purchasable slot is
	# still tappable/costed, but it wears the locked torn face rather than the board's unlockable background.
	var bag_opts := Kit.bag_opts_from_config({"bag_card": {"cell_w": 100, "cell_h": 100}, "torn_cell": {"sprites": false}})
	var empty_bag_slot: Control = Kit.bag_card({"kind": "empty"}, bag_opts)
	var next_bag_slot: Control = Kit.bag_card({"kind": "next", "cost": 25, "on_tap": func() -> void: pass}, bag_opts)
	var locked_bag_slot: Control = Kit.bag_card({"kind": "locked"}, bag_opts)
	ok(empty_bag_slot.find_child("TornCell", true, false) != null \
		and empty_bag_slot.find_child("TornCellWell", true, false) != null,
		"bag available cells use the torn-cell open well")
	ok(locked_bag_slot.find_child("TornCell", true, false) != null \
		and locked_bag_slot.find_child("TornCellLock", true, false) != null \
		and locked_bag_slot.find_child("TornCellWell", true, false) == null,
		"bag locked cells use the torn-cell locked face")
	ok(next_bag_slot.find_child("TornCellLock", true, false) != null \
		and next_bag_slot.find_child("SlotCellBackground", true, false) == null \
		and next_bag_slot.find_child("SlotCellCostCluster", true, false) != null,
		"bag next-unlock cells keep the locked torn face while showing the price")
	empty_bag_slot.free()
	next_bag_slot.free()
	locked_bag_slot.free()
	var tier_opts := Kit.tiers_opts_from_config({"bag_card": {"cell_w": 100, "cell_h": 100}, "torn_cell": {"sprites": false}})
	var tier_grid: Control = Kit.tiers_grid([
		{"tier": 1, "seen": true, "icon": "coin"},
		{"tier": 2, "seen": false},
	], 260.0, tier_opts)
	var tier_open := tier_grid.find_child("TornCellWell", true, false) as Control
	var tier_lock := tier_grid.find_child("TornCellLock", true, false) as Control
	ok(tier_open != null and tier_lock != null \
		and tier_grid.find_child("SlotCellBackground", true, false) == null, \
		"tier dialog cells inherit the bag's torn-cell open and locked faces")
	tier_grid.free()
	# §1 residents: unlock reward + free-spirit grant + residents shop card data (active-suite coverage).
	_test_unlock_rewards()
	_test_residents_shop_cards()

	# T57 — the boost moved off the water shop onto the board's generator info bar. The storefront
	# carries the water refill + 💎 fill (water grants through Save now), but NO coin-priced card.
	fresh("burst_shop")
	var bhost := Control.new()
	get_root().add_child(bhost)
	var saw_coin_card := false
	for sec in Shop._sections({"host": bhost, "hero_px": 100.0, "opts": {}}):
		for cardx in (sec as Dictionary).get("cards", []):
			if String((cardx as Dictionary).get("price_icon", "")) == "coin":
				saw_coin_card = true
	ok(not saw_coin_card, "the storefront carries no coin-priced card (the boost is a board action now)")
	bhost.queue_free()

	# v3 clean-up: the storefront carries NO merchandising chrome — no ribbons, no info discs, no
	# Welcome card (the starter grant machinery stays backend-only).
	fresh("no_merch_chrome")
	var rhost := Control.new()
	rhost.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(rhost)
	ShopS.open(rhost, {})
	await create_timer(0.15).timeout
	ok(rhost.find_children("ShopOfferRibbon", "", true, false).is_empty(), "no merchandising ribbons")
	ok(rhost.find_children("ShopInfoButton", "", true, false).is_empty(), "no per-card info discs")
	ok(rhost.find_children("ShopFooterNote", "", true, false).is_empty(), "no first-buy footer note")
	rhost.queue_free()

	# ── THE STOREFRONT IS THE PAINTING (2026-07-30) ─────────────────────────────────────────────────
	# Owner: "use the whole image from the mock". The shop screen is the approved concept art itself and
	# the game draws nothing on it — so what this block asserts is no longer a material (there is no
	# cut-paper sheet left to check) but the two things a picture-as-a-screen can silently get wrong:
	# what is actually on the screen, and where the taps are.
	fresh("screen_is_the_painting")
	var dhost := Control.new()
	dhost.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(dhost)
	ShopS.open(dhost, {})
	await create_timer(0.15).timeout
	var screen: Control = dhost.find_child(ShopScreen.ROOT_NODE, true, false) as Control
	ok(screen != null, "the storefront builds the shop screen")
	var art := screen.find_child(ShopScreen.ART_NODE, true, false) as TextureRect
	ok(art != null and art.texture != null, "…and it is ONE TextureRect carrying the storefront picture")
	if art != null and art.texture != null:
		ok(art.texture.get_size() == ShopScreen.art_size(),
			"…the picture at the size the registry measured (%s)" % str(art.texture.get_size()))
		ok(art.get_global_rect().is_equal_approx(screen.get_global_rect()),
			"…filling the screen root exactly, so there is no letterbox INSIDE the art")
	# NOTHING ELSE IS DRAWN. The rejected pass re-built this design out of code-drawn cut-paper
	# primitives and the game's own sprites and text; the whole point of the redo is that none of that
	# is here. A stray Label or cut-paper panel would be exactly that regression coming back.
	var cp_script := load("res://engine/scripts/ui/cut_paper.gd")
	var drawn := 0
	for n in screen.find_children("*", "Control", true, false):
		if (n as Node).get_script() == cp_script:
			drawn += 1
	ok(drawn == 0, "no cut-paper sheet is drawn over the painting (%d)" % drawn)
	ok(screen.find_children("*", "Label", true, false).is_empty(),
		"…and no text is typeset over it — every word on this screen is the picture's own")
	var textures := 0
	for tr in screen.find_children("*", "TextureRect", true, false):
		if (tr as TextureRect).texture != null:
			textures += 1
	ok(textures == 1, "…and exactly ONE texture: the picture (%d)" % textures)
	# THE SCREEN FITS, and keeps the picture's aspect: it is letterboxed, never cropped or stretched.
	var vp: Vector2 = dhost.get_viewport_rect().size
	ok(screen.size.x <= vp.x + 0.5 and screen.size.y <= vp.y + 0.5,
		"the screen fits the viewport (%.0fx%.0f in %.0fx%.0f)" % [screen.size.x, screen.size.y, vp.x, vp.y])
	var art_size := ShopScreen.art_size()
	ok(is_equal_approx(screen.size.x / screen.size.y, art_size.x / art_size.y),
		"…at the picture's own aspect (%.4f vs %.4f)" % [screen.size.x / screen.size.y, art_size.x / art_size.y])
	ok(dhost.find_children("*", "ScrollContainer", true, false).is_empty(),
		"…and carries no scroll container (a picture does not scroll)")
	# THE CLOSE ✕ still closes, and is a fingertip. The picture's own disc is 93px on a 1080px canvas,
	# under the platform floor, so the region is deliberately opened past the art it covers.
	var close := screen.find_child(ShopScreen.CLOSE_NODE, true, false) as Button
	ok(close != null, "the painting's ✕ carries a live close region")
	if close != null:
		var cr := close.get_global_rect()
		ok(cr.size.x >= 44.0 and cr.size.y >= 44.0,
			"…at least a fingertip (%.0fx%.0f)" % [cr.size.x, cr.size.y])
		_push_tap(cr.get_center())
		await process_frame
		await process_frame
		ok(dhost.find_child(ShopScreen.ROOT_NODE, true, false) == null,
			"…and a real tap on it closes the storefront")
	dhost.queue_free()

	# ── THE REGIONS TRACK THE ART, NOT THE VIEWPORT ─────────────────────────────────────────────────
	# The picture is 1080x1920 and a phone rarely is, so it is letterboxed — and a hit box derived from
	# the VIEWPORT instead of the picture's own drawn rect drifts off the goods by exactly the letterbox.
	# Build at four aspects (the design canvas, a tall modern phone, a short one, a tablet) and assert
	# every region is still the registry's fraction of the ART.
	await _regions_track_the_art()

	# ── WHAT THE PAINTING CLAIMS vs WHAT THE CONFIG GRANTS ─────────────────────────────────────────
	# The amounts and the prices are BAKED into this picture. That is fine today and wrong the moment
	# anyone re-tunes the ladder, so the two are pinned to each other.
	_art_claims_match_the_live_config()
	await _only_the_known_offers_are_unplaceable()

	# ── HIT TESTING: every tappable region triggers exactly the purchase it appears to ───────────────
	# This is the screen that takes real money, so geometry is not enough. Each region is driven through
	# the REAL input path — get_root().push_input at the region's own centre — and the assertion is on
	# what the WALLET did, not on which callable was wired.
	await _test_stall_hit_regions()

	# ── …and the ✕, which buys nothing and therefore had no such check ──────────────────────────────
	await _test_close_region()

	# ── the region ↔ purchase OVERLAY (the owner's read-out) ────────────────────────────────────────
	await _test_hit_overlay_is_gated_and_honest()

	finish()

## THE PAINTING'S PRICES ARE BAKED IN, so the registry transcribes what each offer's art says and this
## asserts the live config still grants exactly that. Without it a re-tuned ladder — a new tier, a
## re-priced pack, a bigger free refill — leaves a storefront that quietly misstates what a player gets
## for their money, and nothing in the build would notice.
##
## IT DOES NOT, AND CANNOT, FIX THE CURRENCY. "$0.99" is painted into the picture, and the App Store
## shows every user their own currency at their own local price point — so this screen is wrong outside
## the US as drawn, whatever this test says. That is a decision for the owner (live text composited over
## the eight price plates only, leaving the rest of the picture untouched, is the small version) and is
## written up in the registry's own _doc. This guard covers the half that CAN be mechanised.
func _art_claims_match_the_live_config() -> void:
	fresh("art_claims_vs_config")
	var checked := 0
	# the two soft-currency offers
	var refill: Dictionary = ShopScreen.art_claims(ShopS.OFFER_REFILL)
	ok(int(refill.get("amount", -1)) == ShopS.refill_amount(),
		"the art's free refill says %d and the claim grants %d" % [int(refill.get("amount", -1)), ShopS.refill_amount()])
	ok(String(refill.get("price", "")) == "FREE", "…and it is drawn as FREE, which it is")
	checked += 1
	var pouch: Dictionary = ShopScreen.art_claims(ShopS.OFFER_POUCH)
	ok(int(pouch.get("amount", -1)) == ShopS.COIN_PACK,
		"the art's coin pouch says %d coins and the pouch grants %d" % [int(pouch.get("amount", -1)), ShopS.COIN_PACK])
	ok(int(String(pouch.get("price", "0"))) == ShopS.COIN_PACK_GEM_COST,
		"…at the %s acorns the ladder charges (%d)" % [String(pouch.get("price", "")), ShopS.COIN_PACK_GEM_COST])
	checked += 1
	# …and every real-money tier
	ok(Data.CASH_PACKS.size() == 6,
		"the painting draws six cash tiers and the ladder has %d" % Data.CASH_PACKS.size())
	for i in Data.CASH_PACKS.size():
		var claims: Dictionary = ShopScreen.art_claims(ShopS.cash_offer_id(i))
		ok(not claims.is_empty(), "tier %d has a shelf on the painting" % i)
		if claims.is_empty():
			continue
		ok(int(claims.get("amount", -1)) == int(Data.CASH_PACKS[i].gems),
			"the art's tier %d says %d acorns and the pack grants %d"
				% [i, int(claims.get("amount", -1)), int(Data.CASH_PACKS[i].gems)])
		ok(String(claims.get("price", "")) == Iap.usd(String(Data.CASH_PACKS[i].key)),
			"…at the catalog's own price (%s vs %s)"
				% [String(claims.get("price", "")), Iap.usd(String(Data.CASH_PACKS[i].key))])
		# the POPULAR ribbon is painted beside ONE tier; the ladder marks one tier `pop`. They must agree,
		# or the picture merchandises a pack the config is not merchandising.
		var art_pop := String(claims.get("flag", "")) == "POPULAR"
		ok(art_pop == bool(Data.CASH_PACKS[i].get("pop", false)),
			"…and tier %d's painted POPULAR ribbon matches the ladder's `pop` (%s)" % [i, art_pop])
		checked += 1
	ok(checked == 8, "every offer the painting draws was checked against the config (%d of 8)" % checked)

## THE PAINTING IS FIXED, so it presents exactly the eight offers it draws — and the storefront can
## produce more than eight. Those extras are not dropped silently: they are named in the registry with
## what each one costs, and this fails if the set ever changes, so a NEW unreachable purchase has to be
## a decision someone made rather than one nobody saw.
func _only_the_known_offers_are_unplaceable() -> void:
	fresh("unplaceable_offers")
	var declared: Array = []
	for u in ShopScreen.registry().get("unplaceable", []):
		declared.append(String((u as Dictionary).get("id", "")))
	declared.sort()
	ok(declared == ["scissors", "water_fill"],
		"the registry names the offers the painting cannot sell (%s)" % str(declared))
	# a FRESH player sees only what the picture draws — nothing is lost in the default state.
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	ShopS.open(host, {})
	await create_timer(0.15).timeout
	var screen: Control = host.find_child(ShopScreen.ROOT_NODE, true, false) as Control
	ok(screen != null and (screen.get_meta(ShopScreen.UNPLACED_META, ["?"]) as Array).is_empty(),
		"a fresh storefront places every offer it produced (%s)"
			% str(screen.get_meta(ShopScreen.UNPLACED_META, ["?"]) if screen != null else "no screen"))
	host.queue_free()
	# …and once the free refill is spent, the 💎 water fill appears with nowhere to stand. Asserted, not
	# assumed: this is the exact loss the report to the owner names.
	Claims.claim("refill_water")
	var spent := ShopS.unplaceable_offers(ShopS._sections({"host": null, "opts": {}}))
	ok(spent == ["water_fill"],
		"with the free refill spent, exactly the 💎 water fill has no shelf (%s)" % str(spent))

## THE REGIONS TRACK THE ART. The picture keeps its own aspect and is letterboxed inside the viewport,
## so a rect derived from the VIEWPORT would sit off the goods by exactly the letterbox on every device
## that is not 1080x1920. Built at four aspects; each region must be the registry's own fraction of the
## PICTURE's drawn rect, and the picture must never be cropped or stretched.
func _regions_track_the_art() -> void:
	fresh("regions_track_the_art")
	var art := ShopScreen.art_size()
	var offers := {}
	for id in ShopScreen.offer_ids():
		offers[id] = {"offer_id": id, "on_buy": func() -> void: pass}
	# aspects EXPRESSED AS THE DESIGN CANVAS TIMES A RATIO — the canvas itself is Design.size()'s to
	# state (engine/tests/const_ssot_tests.gd), and what matters here is the ratio anyway.
	var canvas := Design.size()
	var boxes := {
		"the design canvas": canvas,
		"a tall phone (canvas × 1.22 tall)": Vector2(canvas.x, canvas.y * 1.22),
		"a short phone (canvas × 0.84 tall)": Vector2(canvas.x, canvas.y * 0.84),
		"a tablet (canvas × 1.42 wide, × 1.07 tall)": Vector2(canvas.x * 1.42, canvas.y * 1.07),
	}
	for label in boxes:
		var box: Vector2 = boxes[label]
		var screen: Control = ShopScreen.build(box, offers, {})
		get_root().add_child(screen)
		# CENTRE IT the way the modal's CenterContainer does, so the letterbox is REAL: on every box but
		# the design canvas the picture starts somewhere other than the screen's own origin, and a region
		# derived from the viewport instead of the art would be off by exactly this offset.
		screen.position = ((box - screen.size) * 0.5).floor()
		await process_frame
		ok(is_equal_approx(screen.size.x, box.x) != is_equal_approx(screen.size.y, box.y) \
			or is_equal_approx(box.x / box.y, art.x / art.y),
			"[%s] …letterboxed on exactly one axis (offset %s)" % [label, str(screen.position)])
		ok(screen.size.x <= box.x + 0.5 and screen.size.y <= box.y + 0.5,
			"[%s] the picture fits (%.0fx%.0f)" % [label, screen.size.x, screen.size.y])
		ok(is_equal_approx(screen.size.x / screen.size.y, art.x / art.y),
			"[%s] …keeping its own aspect (never cropped, never stretched)" % label)
		# it fills ONE axis exactly — a fit that shrank on both would be leaving room for nothing.
		ok(is_equal_approx(screen.size.x, box.x) or is_equal_approx(screen.size.y, box.y),
			"[%s] …filling the box on its limiting axis" % label)
		var k: float = screen.size.x / art.x
		var checked := 0
		for entry in ShopScreen.registry().get("offers", []):
			var o := entry as Dictionary
			for kind in ["cell", "price"]:
				var node_name: String = "%s_%s" % [
					ShopScreen.SLOT_NODE if kind == "cell" else ShopScreen.PRICE_NODE, String(o["id"])]
				var n := screen.find_child(node_name, true, false) as Control
				ok(n != null, "[%s] %s has its %s region" % [label, String(o["id"]), kind])
				if n == null:
					continue
				# the region's rect, in the PICTURE's own pixels, read back off the built node
				var r := n.get_global_rect()
				var back := Rect2((r.position - screen.get_global_rect().position) / k, r.size / k)
				var want: Array = o[kind]
				ok(is_equal_approx(back.position.x, float(want[0])) and is_equal_approx(back.position.y, float(want[1])) \
					and is_equal_approx(back.size.x, float(want[2])) and is_equal_approx(back.size.y, float(want[3])),
					"[%s] %s's %s lands on the picture's %s (read back %s)"
						% [label, String(o["id"]), kind, str(want), str(back)])
				checked += 1
		ok(checked == 16, "[%s] all sixteen regions were read back (%d)" % [label, checked])
		screen.queue_free()

# THE BOARD'S BOTTOM ROW IS A TAB BAR bled to the screen edge — the same format the home/map nav row
# wears (mock: _concepts/screens/palette_a_meadow_sky_board.png). All three of its sheets — the Home
# well, the cream info tray, the Bag well — must:
#   * end their BOX on the safe-area line, with no margin under the row at all;
#   * run their PAPER on through that line, a full corner radius past it, so only the TOP corners round;
#   * flare into a trapezoid at the SAME lean as each other (they are three different shapes, and
#     `flare` is a fraction of each one's own width — see EdgeTab);
#   * still be tappable over every pixel of paper the player can see;
# …without the board's own grid landing under the band or leaving a hole above it.
# Control geometry is float32 → is_equal_approx or a strict inequality, never ==.
func _check_bottom_row_is_a_tab_bar(bx, home_tile: Button, info_tray: Control, bag_well: Button) -> void:
	await create_timer(0.02).timeout
	var base_y: float = bx._view_size().y - Look.safe_bottom(bx)     # the row's baseline: the screen edge
	var sheets := {"Home well": home_tile, "info tray": info_tray, "Bag well": bag_well}
	var leans: Array[float] = []
	for label in sheets:
		var node: Control = sheets[label]
		ok(node != null, "the bottom row carries the %s" % label)
		if node == null:
			continue
		# 1. the BOX bottom lands on the screen's own bottom edge
		var box := node.get_global_rect()
		ok(is_equal_approx(box.end.y, base_y),
			"the %s reaches the screen bottom (%.1f of %.1f)" % [label, box.end.y, base_y])
		# 2. …and the PAPER runs on past it. Read off the drawn sheet, not off the opts.
		# the TRAY's own sheet is looked for FIRST: the almanac chip lives inside it and carries an
		# "ActionButtonDeckleSurface" of its own, which a depth-first search finds instead (measured — the
		# whole tray block then profiled a 65px chip and reported it as the tray).
		var panel := node.find_child("ActionBarInfoDeckleSurface", true, false) as Control
		if panel == null:
			panel = node.find_child("ActionButtonDeckleSurface", true, false) as Control
		ok(panel != null, "the %s draws a cut-paper sheet" % label)
		if panel == null:
			continue
		var sheet := panel.get_global_rect()
		ok(sheet.end.y >= base_y + panel.corner - 0.5,
			"the %s bleeds a full corner radius past the screen edge, so only its TOP corners round (%.1f ≥ %.1f)"
				% [label, sheet.end.y - base_y, panel.corner])
		# 3. the TRAPEZOID, measured off the outline the panel actually draws — not off the knob. The lean
		# is read between two bands of the STRAIGHT sides (inside the top corner arc, above the bottom one),
		# which is the only stretch where the silhouette is the taper and nothing else.
		var pts: PackedVector2Array = panel.call("_deckle_polygon", panel.size, panel.corner)
		ok(pts.size() > 8, "the %s draws a real sheet outline (%d points)" % [label, pts.size()])
		if pts.size() <= 8:
			continue
		var y_hi: float = float(panel.corner) + 4.0
		var y_lo := maxf(y_hi + 20.0, node.size.y - 6.0)
		var hi := _span_x_at(pts, y_hi)
		var lo := _span_x_at(pts, y_lo)
		ok(lo.y - lo.x > hi.y - hi.x + 1.0,
			"the %s tapers: wider low than high (%.1f > %.1f)" % [label, lo.y - lo.x, hi.y - hi.x])
		var lean := ((lo.y - lo.x) - (hi.y - hi.x)) * 0.5 / maxf(y_lo - y_hi, 1.0)
		leans.append(lean)
		# a LITERAL band, per rule 12 — writing it as EdgeTab.LEAN × k would move with the constant under
		# test, and a row re-leaned to a different angle would sail through.
		ok(lean > 0.026 and lean < 0.037,
			"…at the nav tab's own angle (%.4f px in per px down; the row's own is 0.0311)" % lean)
		# 4. the TAP TARGET covers every pixel of paper on screen. The sheet only ever narrows INSIDE its
		# box and only ever grows DOWNWARD past it, so the button's rect must contain the whole visible run.
		var min_x := 1e9
		var max_x := -1e9
		for p in pts:
			if p.y <= node.size.y:
				min_x = minf(min_x, p.x)
				max_x = maxf(max_x, p.x)
		ok(min_x > -0.5 and max_x < node.size.x + 0.5,
			"the %s's tap target covers all of its visible paper (x %.1f…%.1f in a %.0f box)"
				% [label, min_x, max_x, node.size.x])
	# every sheet in the row leans the SAME, which is the whole reason the flare is asked for by lean and
	# not by the nav tab's 5.5%-of-width figure: these are a square, a square and a ~4:1 tray.
	if leans.size() == 3:
		leans.sort()
		ok(leans[2] - leans[0] < 0.004,
			"all three sheets lean alike (%.4f … %.4f — one bar, not three trapezoids)" % [leans[0], leans[2]])
	# 5. THE BAND. The board's own frame clears the row with a real gap and no overlap — the bar is taller
	# than its sheets by design, so the clearance is measured to the BAR, which is what the board reserves.
	var bar := bx.bottom_bar as Control
	ok(bar != null and is_equal_approx(bar.get_global_rect().end.y, base_y),
		"the bar's band ends on the safe-area line — nothing floats above it")
	var frame := bx._board_center as Control
	if bar != null and frame != null:
		var slack := bar.get_global_rect().position.y - frame.get_global_rect().end.y
		ok(slack >= 0.0, "the board grid does not run under the bottom row (%.1f px clear)" % slack)
		ok(slack < bx._view_size().y * 0.10,
			"…and does not leave a hole above it either (%.1f px, under a tenth of the screen)" % slack)
	# 6. the ALMANAC CHIP lives INSIDE the tray, so it takes the material and NOT the geometry: it has no
	# screen edge to bleed off and a tapered chip inside a tapered sheet would read as a mistake.
	var chip := bx._info_almanac as Button
	if chip != null:
		var chip_panel := chip.find_child("ActionButtonDeckleSurface", true, false) as Control
		ok(chip_panel != null and is_equal_approx(chip_panel.flare, 0.0)
				and is_equal_approx(chip_panel.offset_bottom, 0.0),
			"the almanac chip keeps the material without the tab geometry — it sits inside the tray")

## The outline's left/right extent in a 3px band around `y` (the sheet's own local space).
func _span_x_at(pts: PackedVector2Array, y: float) -> Vector2:
	var lo := 1e9
	var hi := -1e9
	for p in pts:
		if absf(p.y - y) <= 3.0:
			lo = minf(lo, p.x)
			hi = maxf(hi, p.x)
	return Vector2(lo, hi) if hi > lo else Vector2.ZERO

func _button_with_text(overlay: Control, text: String) -> Button:
	for b in overlay.find_children("*", "Button", true, false):
		if String((b as Button).text) == text:
			return b as Button
	return null

func _push_tap(gpos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = gpos
	get_root().push_input(down, true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = gpos
	get_root().push_input(up, true)

## Press the storefront region for `offer_id`. The picture-era replacement for `_press_label`, which
## found a CTA by its rendered text: every word on this screen is painted into the art now, so a region
## is found by the offer meta it carries — the SAME meta its buy callable was wired from. Both of an
## offer's regions (its cell and its price plate) carry it and share one callable, so either will do.
func _press_offer(overlay: Control, offer_id: String) -> bool:
	for b in overlay.find_children("*", "Button", true, false):
		var btn := b as Button
		if String(btn.get_meta(ShopScreen.OFFER_META, "")) == offer_id and not btn.disabled:
			btn.pressed.emit()
			return true
	return false

# ── the storefront's HIT REGIONS ───────────────────────────────────────────────────────────────────
## Every tappable region must trigger exactly the purchase it appears to, and no purchase may become
## unreachable. That is the invariant this screen exists under — it takes real money — so it is driven
## through the REAL input path (get_root().push_input at the region's own centre, the same events a
## finger produces) and asserted on what the WALLET did, never on which callable was wired.
##
## Both entry points are driven over the whole storefront: the shelf CELL (a tap anywhere on the goods,
## the tag or the plank under them) and the green PRICE BUTTON pinned to the lip. They must agree.
func _test_stall_hit_regions() -> void:
	for via in ["cell", "price"]:
		await _drive_every_offer(via)

func _drive_every_offer(via: String) -> void:
	fresh("stall_hit_%s" % via)
	Save.set_first_purchase_made()          # past the first-buy doubler: each tier grants exactly its own
	Save.add_diamonds(500)                  # …and the quick-help offers are affordable
	Save.set_water(G.WATER_CAP)             # full, so the free refill banks a spare and the delta is exact
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	ShopS.open(host, {})
	await create_timer(0.25).timeout

	# the FREE refill: a claim, not a purchase — it grants on the tap itself.
	var water_before := Save.water()
	await _tap_offer(host, ShopS.OFFER_REFILL, via)
	ok(Save.water() == water_before + ShopS.refill_amount(),
		"[%s] the free refill's region claims the refill and nothing else (%d -> %d)"
			% [via, water_before, Save.water()])

	# the COIN POUCH: a soft-currency purchase — coins up, acorns down, both exact.
	var coins_before := Save.coins()
	var gems_before := Save.diamonds()
	await _tap_offer(host, ShopS.OFFER_POUCH, via)
	ok(Save.coins() == coins_before + ShopS.COIN_PACK
		and Save.diamonds() == gems_before - ShopS.COIN_PACK_GEM_COST,
		"[%s] the coin pouch's region buys the pouch (%d coins for %d acorns)"
			% [via, ShopS.COIN_PACK, ShopS.COIN_PACK_GEM_COST])

	# THE SIX REAL-MONEY TIERS, one at a time, each through its OWN region. A cash region must open the
	# honest confirm and grant NOTHING until Confirm is pressed — a region that granted on the tap would
	# be a charge without a decision.
	for i in Data.CASH_PACKS.size():
		var before := Save.diamonds()
		var tapped := await _tap_offer(host, ShopS.cash_offer_id(i), via)
		ok(tapped, "[%s] tier %d (%s) has a live region" % [via, i, Iap.usd(String(Data.CASH_PACKS[i].key))])
		ok(Save.diamonds() == before, "[%s] …and tapping it grants nothing before the confirm" % via)
		var confirm := _button_with_text(host, Strings.t("shop.confirm.confirm"))
		ok(confirm != null, "[%s] …it opens the honest cash confirm" % via)
		if confirm == null:
			continue
		_push_tap(confirm.get_global_rect().get_center())
		await process_frame
		await process_frame
		ok(Save.diamonds() == before + int(Data.CASH_PACKS[i].gems),
			"[%s] …and confirming grants EXACTLY tier %d's %d acorns (%+d)"
				% [via, i, int(Data.CASH_PACKS[i].gems), Save.diamonds() - before])
		await create_timer(0.12).timeout      # the storefront rebuilds in place after a buy
	host.queue_free()

## Tap one offer's region through the real input path. `via` picks the entry point: "cell" is the shelf
## cell (the goods + tag + plank), "price" is the green button pinned to the lip. Returns false when the
## offer has no live region at all — which is itself a failure worth naming (a purchase gone unreachable).
func _tap_offer(host: Control, offer_id: String, via: String) -> bool:
	var node := _region_for(host, offer_id, via)
	if node == null:
		return false
	var rect := node.get_global_rect()
	# a region a finger cannot reliably hit is a wiring bug too. 44 CSS px is the platform floor; the
	# storefront's own cells are many times that, and its price buttons clear it on both axes.
	ok(rect.size.x >= 44.0 and rect.size.y >= 44.0,
		"the %s region for %s is at least a fingertip (%.0fx%.0f)" % [via, offer_id, rect.size.x, rect.size.y])
	_push_tap(rect.get_center())
	await process_frame
	await process_frame
	return true

## The live region for an offer: the shelf cell (`shop_slot`) or its price button (`shop_buy`). Read off
## the BUILT tree by the meta the storefront stamped from the same card dict that supplied `on_buy`.
func _region_for(host: Control, offer_id: String, via: String) -> Control:
	for n in host.find_children("*", "Control", true, false):
		var c := n as Control
		if String(c.get_meta(ShopScreen.OFFER_META, "")) != offer_id:
			continue
		if c.mouse_filter == Control.MOUSE_FILTER_IGNORE or not c.is_visible_in_tree():
			continue
		if via == "cell" and c.has_meta(ShopScreen.SLOT_META):
			return c
		if via == "price" and c.has_meta("shop_buy"):
			return c
	return null

# ── the ✕ ("what about the close button", 2026-07-30) ──────────────────────────────────────────────
## THE CLOSE REGION, driven through the real input path like every purchase — plus the check the offers
## do not need: that a tap just OUTSIDE it does NOT dismiss. That is the half a shifted rect or a drifted
## wiring actually breaks; the centre tap passes almost however wrong the region is.
##
## THE SCREEN IS BUILT STANDALONE HERE, on a bare host with no modal, and that is load-bearing. On the
## live shop the painting stops nothing of its own (the art and the screen root are both
## MOUSE_FILTER_IGNORE), so a tap that misses every region falls through to the modal's dismiss veil and
## the storefront closes ANYWAY. A "just outside" assertion run inside the modal would therefore pass
## wherever the ✕ was — it would be measuring the veil. With the screen alone, the ONLY thing that can
## call on_close is the ✕, so the assertion is about the ✕.
func _test_close_region() -> void:
	fresh("close_region")
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	var tally := {"close": 0, "buy": 0}
	var offers := {}
	for id in ShopScreen.offer_ids():
		offers[String(id)] = {"on_buy": func() -> void: tally.buy += 1}
	var screen: Control = ShopScreen.build(host.get_viewport_rect().size, offers,
		{"on_close": func() -> void: tally.close += 1})
	host.add_child(screen)
	await process_frame
	var close := screen.find_child(ShopScreen.CLOSE_NODE, true, false) as Button
	ok(close != null, "the storefront builds a ✕ region")
	if close == null:
		host.queue_free()
		return
	var cr := close.get_global_rect()

	# IT IS BIGGER THAN THE DISC THE PICTURE DRAWS, around the same centre. The overlay draws both, and
	# it is handed this rect rather than re-reading the registry — so this is the number it will show.
	var drawn: Rect2 = close.get_meta(ShopScreen.CLOSE_DRAWN_META, Rect2())
	ok(drawn.size.x > 0.0 and drawn.size.x < close.size.x and drawn.size.y < close.size.y,
		"…over a SMALLER painted disc (%.0fx%.0f drawn inside a %.0fx%.0f tap rect)"
			% [drawn.size.x, drawn.size.y, close.size.x, close.size.y])
	ok(drawn.get_center().distance_to(Rect2(close.position, close.size).get_center()) <= 1.0,
		"…grown around the SAME centre, so the ✕ stays under the finger")
	ok(cr.size.x >= 44.0 and cr.size.y >= 44.0,
		"…and the tap rect clears the fingertip floor (%.0fx%.0f)" % [cr.size.x, cr.size.y])

	# IT STEALS NOTHING. The widened rect sits top-right, above every shelf; if it ever grew down into an
	# offer it would be selling a dismiss where a purchase is painted.
	var overlaps: Array = []
	for n in screen.find_children("*", "Control", true, false):
		var c := n as Control
		if c == close or String(c.get_meta(ShopScreen.OFFER_META, "")) == "":
			continue
		if c.get_global_rect().intersects(cr):
			overlaps.append("%s/%s" % [String(c.get_meta(ShopScreen.OFFER_META, "")), c.name])
	ok(overlaps.is_empty(), "…and overlaps no offer region (%s)"
		% ("none" if overlaps.is_empty() else ",".join(PackedStringArray(overlaps))))

	# A TAP AT ITS CENTRE DISMISSES…
	_push_tap(cr.get_center())
	await process_frame
	await process_frame
	ok(tally.close == 1 and tally.buy == 0,
		"a tap at the ✕'s centre dismisses, once, and buys nothing (close=%d buy=%d)" % [tally.close, tally.buy])

	# …AND A TAP JUST OUTSIDE IT DOES NOT. Eight px beyond each edge's midpoint — outside on one axis,
	# squarely inside on the other, so a rect that has slid in any direction is caught.
	var out := 8.0
	var probes := {
		"above": Vector2(cr.get_center().x, cr.position.y - out),
		"below": Vector2(cr.get_center().x, cr.end.y + out),
		"left": Vector2(cr.position.x - out, cr.get_center().y),
		"right": Vector2(cr.end.x + out, cr.get_center().y),
	}
	for where in probes:
		var before: int = tally.close
		_push_tap(probes[where])
		await process_frame
		await process_frame
		ok(tally.close == before,
			"…and a tap %s it (%.0f,%.0f) does not (%d dismisses)"
				% [where, probes[where].x, probes[where].y, tally.close - before])
	ok(tally.buy == 0, "…nor does any of them buy anything (%d)" % tally.buy)
	host.queue_free()

	# …WHICH IS NOT THE SAME AS "NOTHING HAPPENS" ON THE LIVE SHOP. Same miss, real modal: the painting
	# stops no taps of its own, so a point inside no region reaches the veil under it and the storefront
	# dismisses. The overlay labels those points "veil · dismisses" from the veil's own gui_input
	# connection; this asserts the BEHAVIOUR, so the label is backed by a tap and not by an inference.
	fresh("close_region_miss")
	var live := Control.new()
	live.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(live)
	ShopS.open(live, {})
	await create_timer(0.25).timeout
	var lscreen: Control = live.find_child(ShopScreen.ROOT_NODE, true, false) as Control
	ok(lscreen != null, "the live storefront opens")
	if lscreen != null:
		# the hung signboard's own centre — painted, prominent, and part of no offer's cell
		var art := ShopScreen.art_size()
		var box := lscreen.get_global_rect()
		var pt := box.position + Vector2(557.5 / art.x * box.size.x, 271.0 / art.y * box.size.y)
		var claimed := ""
		for n in lscreen.find_children("*", "Control", true, false):
			var c := n as Control
			if c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(pt):
				claimed = c.name
		ok(claimed == "", "the signboard's centre is inside no region (%s)" % ("none" if claimed == "" else claimed))
		_push_tap(pt)
		await process_frame
		await process_frame
		ok(live.find_child(ShopScreen.ROOT_NODE, true, false) == null,
			"…and a tap there dismisses the storefront through the modal's veil — a MISS is not inert on this screen")
	live.queue_free()

# ── the HIT-REGION OVERLAY (deliverable 3) ─────────────────────────────────────────────────────────
## The overlay must be ABSENT from an ordinary run and PRESENT (and honest) under the authoring gate.
## "Honest" is the whole point: it reports what the ENGINE's picker returns for points inside each
## region, so a region drawn over the wrong purchase shows up as a mismatch instead of a tidy label.
func _test_hit_overlay_is_gated_and_honest() -> void:
	fresh("hit_overlay_gate")
	var plain := Control.new()
	plain.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(plain)
	ShopS.open(plain, {})
	await create_timer(0.2).timeout
	ok(plain.find_child(HitOverlay.OVERLAY_NAME, true, false) == null,
		"the hit overlay is absent from an ordinary storefront open")
	plain.queue_free()

	fresh("hit_overlay_honest")
	DebugUI.force = true                     # the capture tool's own gate (map_shot MODE=shophits)
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	ShopS.open(host, {})
	await create_timer(0.3).timeout
	var ov: Control = host.find_child(HitOverlay.OVERLAY_NAME, true, false) as Control
	ok(ov != null, "the authoring gate mounts the hit overlay over the storefront")
	if ov != null:
		var regions: Array = ov.call("regions_for_test")
		var by_kind := {}
		var mismatched: Array = []
		var close_region := {}
		for r in regions:
			var d := r as Dictionary
			var k := String(d["kind"])
			by_kind[k] = int(by_kind.get(k, 0)) + 1
			if k == "close":
				close_region = d
			if not bool(d["good"]):
				mismatched.append("%s->%s" % [String(d["declared"]), ",".join(PackedStringArray(d["resolved"]))])
		ok(int(by_kind.get("slot", 0)) == 8, "…covering all eight offers' shelf cells (%d)" % int(by_kind.get("slot", 0)))
		ok(int(by_kind.get("price", 0)) == 8, "…and all eight price buttons (%d)" % int(by_kind.get("price", 0)))
		# THE ✕ IS IN THE PICTURE TOO. It carries neither purchase meta, and collecting only those two is
		# exactly what kept it out of the owner's read-out until they asked "what about the close button".
		ok(int(by_kind.get("close", 0)) == 1, "…and the ✕, which is not a purchase (%d)" % int(by_kind.get("close", 0)))
		ok(int(by_kind.get("?", 0)) == 0,
			"…and nothing hit-testable is left unlabelled (%d unnamed regions)" % int(by_kind.get("?", 0)))
		ok(mismatched.is_empty(),
			"…and every region resolves, through the engine's own picker, to the purchase it is labelled with (%s)"
				% ("none mismatched" if mismatched.is_empty() else ",".join(PackedStringArray(mismatched))))
		# THE LABEL COMES FROM THE PICKER, not from the registry: `good` above already required the five
		# probes inside the ✕ to come back as the ✕, and this names the answer so a silent "—" cannot pass.
		ok(not close_region.is_empty()
			and String(close_region.get("declared", "")) == ShopScreen.CLOSE_ID
			and PackedStringArray(close_region.get("resolved", [])) == PackedStringArray([ShopScreen.CLOSE_ID]),
			"…the ✕'s own probes resolve, through that picker, to `%s` (%s)" % [ShopScreen.CLOSE_ID,
				"absent" if close_region.is_empty() else ",".join(PackedStringArray(close_region.get("resolved", [])))])
		# …and it is drawn as an ENLARGED tap target over the smaller disc the picture paints. Both rects
		# must reach the overlay or the gap — the whole reason the region was opened up — is invisible.
		var hit_rect: Rect2 = close_region.get("rect", Rect2())
		var drawn_rect: Rect2 = close_region.get("drawn", Rect2())
		ok(drawn_rect.size.x > 0.0 and hit_rect.encloses(drawn_rect) and drawn_rect.size.x < hit_rect.size.x,
			"…and the overlay is handed BOTH the tap rect (%.0fpx) and the disc inside it (%.0fpx)"
				% [hit_rect.size.x, drawn_rect.size.x])
		# WHAT A MISS DOES. The painting stops no taps of its own, so most of this screen is the modal's
		# veil — and the overlay says so instead of showing a screen that looks nine-tenths inert.
		var elsewhere: Array = ov.call("elsewhere_for_test")
		var answers: Array = []
		for e in elsewhere:
			if not answers.has(String((e as Dictionary)["hit"])):
				answers.append(String((e as Dictionary)["hit"]))
		ok(elsewhere.size() > 0, "…the overlay also probes where there is NO region (%d points)" % elsewhere.size())
		ok(answers == ["veil · dismisses"],
			"…and every one of them resolves to the modal's dismiss veil (%s)" % ",".join(PackedStringArray(answers)))
	host.queue_free()
	DebugUI.force = false                    # never leave the gate armed for a later suite
