extends "res://games/grove/tests/grove_test_base.gd"
## grove · shop — split from the grove_tests monolith; shares grove_test_base.gd. Covers the IAP
## ladder, the free claims (water refill + free acorns), the 💎 doubler pricing, and the shop cards.

const Iap = preload("res://engine/scripts/core/iap.gd")   # cash-pack prices/ids live in the IAP catalog now
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")   # the water regen rule (over-cap pause)

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

	# T-E: free claims — a claim grants the reward, then the type is REFUSED until its
	# cooldown elapses AND under its daily cap; the per-type daily cap holds.
	fresh("claims_refill")
	ok(Claims.can_show("refill_water"), "a fresh refill claim is offerable")
	var rr: Dictionary = Claims.claim("refill_water")
	ok(bool(rr.ok) and int(rr.water) == G.WATER_CAP, "claiming the free refill yields a full can (%d💧)" % G.WATER_CAP)
	ok(not Claims.can_show("refill_water"), "...and the claim is refused immediately after (cooldown)")
	ok(not bool(Claims.claim("refill_water").ok), "a claim during cooldown is refused (no over-grant)")
	# backdate the last-claim to simulate the cooldown elapsing → offerable again.
	Save.grove()["claim_ledger"]["refill_water"]["last"] = Time.get_unix_time_from_system() - Data.CLAIMS.refill_water.cooldown - 1.0
	ok(Claims.can_show("refill_water"), "past the cooldown the refill claim is offerable again")
	# exhaust the daily cap (clearing cooldown each time) → refused for the rest of the day.
	var cap_n := int(Data.CLAIMS.refill_water.cap)
	for k in range(Claims.remaining_today("refill_water")):
		Save.grove()["claim_ledger"]["refill_water"]["last"] = 0.0   # ignore cooldown for the cap probe
		ok(bool(Claims.claim("refill_water").ok), "refill claim within the daily cap")
	ok(Save.claim_used_today("refill_water") == cap_n, "the daily cap is reached (%d/day)" % cap_n)
	Save.grove()["claim_ledger"]["refill_water"]["last"] = 0.0
	ok(not Claims.can_show("refill_water"), "the per-type DAILY CAP refuses further claims")
	ok(not bool(Claims.claim("refill_water").ok), "...and a capped claim grants nothing")
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
	var bw = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(bw)
	if bw.board == null:
		bw._ready()
	ok(bw.refill_btn != null, "the board builds the refill surface")
	ok(Save.water_pending() == 0 and bw.water == G.WATER_CAP + int(Data.STARTER_PACK.water), \
		"the board banks the starter water over-cap on open (%d = full can + %d, not clamped)" % [bw.water, int(Data.STARTER_PACK.water)])
	# drive to empty and surface the stack (water<=0 reveals the refill stack).
	bw.water = 0
	bw._update_water_hud()
	ok(bw._refill_stack.visible, "at empty the refill stack is shown (the friction point)")
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
	# T-J(iii): the water stall is HOST-AGNOSTIC now — it ALWAYS shows the free refill + the 💎 fill, with
	# no per-scene `water_add`/`water_grant` gate (water grants through Save). _water_sections is the source.
	fresh("refill_card")
	var wh := Control.new()
	get_root().add_child(wh)
	var saw_refill := false
	var saw_fill := false
	for sec in Shop._water_sections({"host": wh, "hero_px": 100.0, "opts": {}}):
		for cardx in (sec as Dictionary).get("cards", []):
			if (cardx as Dictionary).has("node"):                                    # the free-refill card (custom node)
				saw_refill = true
			elif String((cardx as Dictionary).get("price_icon", "")) == "gem":       # the 💎 fill card
				saw_fill = true
	ok(saw_refill, "the water stall offers the free-refill card (no host callback needed)")
	ok(saw_fill, "...and the 💎 fill card")
	wh.queue_free()
	# T-J(iv): pressing the free refill in the REAL stall GRANTS THROUGH SAVE (over-cap), end-to-end —
	# no host callback. Start full so the refill banks a spare; assert Save's water doubles.
	fresh("refill_card_live")
	var wsh = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(wsh)
	if wsh.content == null:
		wsh._ready()
	Save.set_water(G.WATER_CAP)                            # full → a refill banks a spare
	ShopS.open_water(wsh, {})
	var w_overlay: Control = wsh.find_child("ShopOverlay", true, false)
	ok(w_overlay != null and _press_label(w_overlay, "Free"), "the water stall shows a green 'Free' refill CTA")
	ok(Save.water() == G.WATER_CAP * 2, "pressing the free refill banks a full can over-cap via Save (%d💧)" % Save.water())
	wsh.queue_free()
	# T-J(v): the stall is reachable from BOTH the board AND the hub (map), and grants through Save from
	# each — the host-agnostic win (regression: the hub HUD used to lack the free card entirely). Drive each
	# scene's REAL `_open_water` (the SAME callable the water pill + fires) and assert the grant lands in Save.
	for host_scene in ["res://engine/scenes/Map.tscn", "res://engine/scenes/Board.tscn"]:
		var is_map: bool = "Map" in host_scene
		var where: String = "map" if is_map else "board"
		fresh("refill_card_%s" % where)
		var h = load(host_scene).instantiate()
		get_root().add_child(h)
		if (h.get("content") if is_map else h.get("board")) == null:
			h._ready()
		Save.set_water(G.WATER_CAP)                        # full → a refill banks a spare
		ok(h._open_water.is_valid(), "the %s HUD wires an _open_water callable" % where)
		h._open_water.call()                               # the exact path the water pill + fires
		var ov: Control = h.find_child("ShopOverlay", true, false)
		ok(ov != null and _press_label(ov, "Free"), "the %s water stall shows the free-refill CTA" % where)
		ok(Save.water() == G.WATER_CAP * 2, "...and pressing it grants a full can over-cap via Save (%s)" % where)
		h.queue_free()
	# T-J(vi): the board keeps a live water cache for gameplay; when a shop grant ticks the HUD refresh,
	# the board re-syncs that cache from Save (the on_refresh hook) — no per-currency callback, and it
	# can't undo a pop (the board never fires the refresh mid-pop).
	fresh("board_water_resync")
	var brd = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(brd)
	if brd.board == null:
		brd._ready()
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
	var bq = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(bq)
	if bq.board == null:
		bq._ready()
	bq.quests = [{"line": 6, "tier": 4}]
	bq._open_bramble(Vector2i(2, 3))
	ok(BoardModel.line_of(bq.board.item_at(Vector2i(2, 3))) == 6, \
		"an unlocked cell reveals a seed of an OPEN quest line (6), not the positional 1-2 anchor")
	bq.queue_free()
	# ── T44 · the diegetic return surfaces build + drive (§10/§13 · §18) ─────────
	# Both surfaces are world objects (parchment cards), not bare chrome. Open them on a
	# REAL tree-attached host so the kit + viewport resolve, then drive the actual buttons
	# end-to-end: the piggy-bank Claim→Confirm cracks the jar; the calendar Claim claims today's rung.
	fresh("vault_surface")
	var vhost = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(vhost)
	if vhost.has_method("_ready") and vhost.content == null:
		vhost._ready()
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

	fresh("login_surface")
	var lhost = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(lhost)
	if lhost.has_method("_ready") and lhost.content == null:
		lhost._ready()
	var l_coins := Save.coins()
	var l_streak := Login.streak()
	LoginUI.open(lhost)
	var l_overlay: Control = lhost.get_child(lhost.get_child_count() - 1)
	ok(l_overlay.find_children("*", "PanelContainer", true, false).size() >= 8, \
		"the calendar opens as a framed card with a week of reward cells (diegetic, §13)")
	ok(_press_label(l_overlay, "Claim"), "the calendar shows a Claim button")
	ok(Login.streak() == l_streak + 1 and Save.coins() >= l_coins, \
		"collecting through the surface claims today's rung and bumps the streak")
	lhost.queue_free()

	# (T-K free-acorn faucet tests removed 2026-06-23 — the faucet was retired; acorns are earned-only, Option A.)

	# T-L: the Welcome bundle's detail sheet — now the SHARED mail dialog (parchment cards, NO Claim) with a
	# level-style "Got it" footer, replacing the dropped info_dialog. starter_info_items still itemizes the
	# acorns + water; the REAL _info_sheet renders each label (card title) + amount (a read-only chip), a
	# Got it footer, and NO Claim.
	fresh("starter_info")
	var ihost := Control.new()
	ihost.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(ihost)
	var items := ShopS.starter_info_items(ihost)
	ok(items.size() == 2, "the Welcome info lists two line items (acorns + water)")
	ok(String(items[0].icon) == "gem" and String(items[0].amount) == str(int(Data.STARTER_PACK.gems)), \
		"row 1 is the acorns (%d🌰)" % int(Data.STARTER_PACK.gems))
	ok(String(items[1].icon) == "water" and String(items[1].amount) == str(int(Data.STARTER_PACK.water)), \
		"row 2 is the water (%d💧)" % int(Data.STARTER_PACK.water))
	ShopS._info_sheet(ihost, "Welcome gift", items, "Claimable just once.")
	var iov: Control = ihost.get_child(ihost.get_child_count() - 1)
	var ibtns := _button_texts(iov)
	ok(ibtns.has(str(int(Data.STARTER_PACK.gems))) and ibtns.has(str(int(Data.STARTER_PACK.water))), \
		"the info sheet renders each item's amount on a read-only chip")
	ok(_label_texts(iov).has("Acorns") and _label_texts(iov).has("Water"), "...and each item's label as the card title")
	ok(not _press_label(iov, "Claim"), "the info sheet has NO Claim button (read-only)")
	ok(_press_label(iov, "Got it"), "the info sheet shows a Got it footer (which closes it)")
	ihost.free()

	# --- UI redesign P2: the empty-cell well reads the role token on the Sunk plane ---
	var cell_sb := BoardScript._cell_style()
	ok(cell_sb.bg_color.is_equal_approx(Pal.CELL_EMPTY), "empty cell well uses Pal.CELL_EMPTY (not the old hardcoded tan)")
	ok(cell_sb.shadow_size == 0, "empty cell sits on the Sunk plane (no drop shadow)")
	var backdrop := BoardScript._field_backdrop()
	ok(backdrop is TextureRect or (backdrop is ColorRect and (backdrop as ColorRect).color.is_equal_approx(Pal.SURFACE)), \
		"board backdrop is either the painted grove board art or the flat SURFACE fallback")
	# the locked-cell WELL unified into the SHARED slot cell (Kit.slot_cell); a recessive `_locked_fill`
	# Panel now backs its rounded corners (the painted slot_locked padlock rides ON TOP).
	# Assert that base fill — a solid Pal.LOCKED, on the Sunk plane (no shadow), distinct from an empty
	# cell, receding a hair for deeper rings (the standalone _locked_style stylebox accessor is retired).
	var lock_fill := PieceViewScript._locked_fill(100.0, 1)
	var lock_sb := lock_fill.get_theme_stylebox("panel") as StyleBoxFlat
	ok(lock_sb != null, "the locked-cell base is a solid StyleBoxFlat fill (a recessive well, not transparent art)")
	ok(lock_sb != null and lock_sb.bg_color.is_equal_approx(Pal.LOCKED), "locked cell well uses Pal.LOCKED (light recessive, not dark tan)")
	ok(lock_sb != null and lock_sb.shadow_size == 0, "locked cell sits on the Sunk plane (no drop shadow)")
	ok(lock_sb != null and not lock_sb.bg_color.is_equal_approx(BoardScript._cell_style().bg_color), "locked is visually distinct from an empty cell (LOCKED != CELL_EMPTY)")
	var deep_fill := PieceViewScript._locked_fill(100.0, 3)
	var deep_sb := deep_fill.get_theme_stylebox("panel") as StyleBoxFlat
	ok(deep_sb != null and deep_sb.bg_color.v <= lock_sb.bg_color.v, "deeper rings recede a hair (ring 3 no brighter than ring 1)")
	lock_fill.free()
	deep_fill.free()
	var bramble_node: Control = PieceViewScript.make_bramble(Vector2i(0, 0), 100.0)
	ok(bramble_node.get_child(0) is Panel, "frontier locked cell paints a full-cell locked background behind the gate marker")
	ok((bramble_node.get_child(0) as Panel).get_theme_stylebox("panel") is StyleBoxFlat, \
		"frontier locked cell background is a solid fill, not transparent art that exposes the board gutter")
	var lv_num: Label = bramble_node.find_child("lv_num", true, false) as Label
	ok(lv_num == null, "frontier locked cell omits the old shared level-badge marker")
	ok(not _tree_has(bramble_node, "PanelContainer"), "locked cell has no dark cream-on-bark gate chip (the loud badge is gone)")
	ok(_all_ignore(bramble_node), "frontier locked cell ignores mouse so the board input surface receives taps")
	bramble_node.free()
	ok(BoardScript._quest_band_style().bg_color.v > 0.70, "quest band is a light Rest-plane strip (not the dark fence)")

	# §1 residents: unlock reward + free-spirit grant + residents shop card data (active-suite coverage).
	_test_unlock_rewards()
	_test_residents_shop_cards()

	# T57 — the boost moved off the water shop onto the board's generator info bar. The water stall
	# carries the water refill + 💎 fill (water grants through Save now), but NO coin-priced card.
	fresh("burst_shop")
	var bhost := Control.new()
	get_root().add_child(bhost)
	var saw_coin_card := false
	for sec in Shop._water_sections({"host": bhost, "hero_px": 100.0, "opts": {}}):
		for cardx in (sec as Dictionary).get("cards", []):
			if String((cardx as Dictionary).get("price_icon", "")) == "coin":
				saw_coin_card = true
	ok(not saw_coin_card, "the water stall carries no coin-priced card (the boost is a board action now)")
	bhost.queue_free()

	finish()
