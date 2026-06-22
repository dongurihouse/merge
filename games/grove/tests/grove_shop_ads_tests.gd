extends "res://games/grove/tests/grove_test_base.gd"
## grove · shop+ads — split from the grove_tests monolith; shares grove_test_base.gd.

func _initialize() -> void:
	begin("grove · shop+ads")
	fresh("iap_ladder")
	ok(Data.CASH_PACKS.size() >= 5, "the cash ladder has many tiers (entry → whale ceiling)")
	var prev_rate := -1.0
	var top_price := 0.0
	for pk in Data.CASH_PACKS:
		var usd := float(String(pk.usd).substr(1))   # "$4.99" → 4.99
		var rate := float(int(pk.gems)) / usd
		ok(int(pk.gems) > 0 and usd > 0.0, "ladder tier %s grants %d💎" % [pk.usd, int(pk.gems)])
		ok(rate > prev_rate - 0.001, "ladder 💎/$ rises at %s (%.1f ≥ prev)" % [pk.usd, rate])
		prev_rate = rate
		top_price = maxf(top_price, usd)
	ok(top_price >= 49.99, "the ladder reaches a $49.99+/$99.99-class whale tier (%.2f)" % top_price)

	# T-B: each ladder tier grants exactly its 💎 (once the first-buy doubler is spent).
	fresh("iap_grant")
	Save.set_first_purchase_made()       # past the doubler — steady-state grants
	for ti in Data.CASH_PACKS.size():
		var before := Save.diamonds()
		var got: int = ShopS.grant_cash_pack(ti)
		ok(got == int(Data.CASH_PACKS[ti].gems), "tier %s grants exactly %d💎" % [Data.CASH_PACKS[ti].usd, int(Data.CASH_PACKS[ti].gems)])
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

	# T-E: rewarded ads — a watch grants the reward, then the type is REFUSED until its
	# cooldown elapses AND under its daily cap; the per-type daily cap holds.
	fresh("ads_refill")
	ok(Ads.can_show("refill_water"), "a fresh refill ad is offerable")
	var rr: Dictionary = Ads.claim("refill_water")
	ok(bool(rr.ok) and int(rr.water) == G.WATER_CAP, "watching the refill ad yields a full can (%d💧)" % G.WATER_CAP)
	ok(not Ads.can_show("refill_water"), "...and the ad is refused immediately after (cooldown)")
	ok(not bool(Ads.claim("refill_water").ok), "a claim during cooldown is refused (no over-grant)")
	# backdate the last-watch to simulate the cooldown elapsing → offerable again.
	Save.grove()["ad_ledger"]["refill_water"]["last"] = Time.get_unix_time_from_system() - Data.ADS.refill_water.cooldown - 1.0
	ok(Ads.can_show("refill_water"), "past the cooldown the refill ad is offerable again")
	# exhaust the daily cap (clearing cooldown each time) → refused for the rest of the day.
	var cap_n := int(Data.ADS.refill_water.cap)
	for k in range(Ads.remaining_today("refill_water")):
		Save.grove()["ad_ledger"]["refill_water"]["last"] = 0.0   # ignore cooldown for the cap probe
		ok(bool(Ads.claim("refill_water").ok), "refill watch within the daily cap")
	ok(Save.ad_used_today("refill_water") == cap_n, "the daily cap is reached (%d/day)" % cap_n)
	Save.grove()["ad_ledger"]["refill_water"]["last"] = 0.0
	ok(not Ads.can_show("refill_water"), "the per-type DAILY CAP refuses further watches")
	ok(not bool(Ads.claim("refill_water").ok), "...and a capped claim grants nothing")
	# a NEW day resets the cap (the day-rollover in the ledger).
	Save.grove()["ad_ledger"]["refill_water"]["day"] = int(Time.get_unix_time_from_system() / 86400.0) - 1
	Save.grove()["ad_ledger"]["refill_water"]["last"] = 0.0
	ok(Ads.can_show("refill_water") and Save.ad_used_today("refill_water") == 0, "a new day resets the daily cap")

	# T-F: the 2×-collection ad is the board quest-reward doubler's faucet — it still claims
	# (capped+cooled, no currency granted here), but the hub-yield "arm a flag the hub-collect
	# reads" machinery is gone (the hub-collect was removed; residents replace the hub yield).
	fresh("ads_2x")
	var x2: Dictionary = Ads.claim("collect_2x")
	ok(bool(x2.ok), "the 2× quest ad still claims (capped+cooled)")
	ok(not Save.grove().has("collect_2x_armed"), "claiming no longer arms a hub-collect flag (hub yield removed)")

	# (The free-reroll "shop_reroll" ad was removed with the Featured rotation/refresh — the
	# storefront's featured band is now a fixed set, so there is no reroll surface to watch.)

	# T-H: the event top-up ad grants a small 💎, capped at 1/day.
	fresh("ads_event")
	var ev_b := Save.diamonds()
	var ev: Dictionary = Ads.claim("event_topup")
	ok(bool(ev.ok) and Save.diamonds() == ev_b + int(Data.ADS.event_topup.gems), \
		"the event top-up grants +%d💎" % int(Data.ADS.event_topup.gems))
	ok(not Ads.can_show("event_topup"), "the event top-up is 1/day (capped after one watch)")

	# T-I: the OUT-OF-WATER triggered offer — fires inside its low cap + cooldown, refuses
	# past the cap; cozy by construction (a single gentle top-up, no countdown state here).
	fresh("oow_offer")
	var oc := int(Data.OOW_OFFER.cap)
	var ocd := float(Data.OOW_OFFER.cooldown)
	ok(Save.oow_can_show(oc, ocd), "the out-of-water offer may fire at the wall (within cap/cooldown)")
	Save.oow_record()
	ok(not Save.oow_can_show(oc, ocd), "...then it's on cooldown (no repeat shakedown)")
	# exhaust the daily cap, clearing the cooldown between probes.
	while Save.oow_used_today() < oc:
		var g_oow: Dictionary = Save.grove()["oow_offer"]
		g_oow["last"] = 0.0
		if Save.oow_can_show(oc, ocd):
			Save.oow_record()
	Save.grove()["oow_offer"]["last"] = 0.0
	ok(Save.oow_used_today() == oc, "the offer reaches its low daily cap (%d/day)" % oc)
	ok(not Save.oow_can_show(oc, ocd), "...and is refused past the cap (a low, cozy ceiling)")
	# the offer's discount is real value: a full can PLUS premium for the entry price.
	ok(int(Data.OOW_OFFER.water) > 0 and int(Data.OOW_OFFER.gems) > 0, \
		"the offer bundles water + a little 💎 (a gentle discount, §10)")

	# T-J: the live board surfaces the empty-water stack — the ad refill + the offer button
	# exist and the starter water credit is drained on open (the energy-wall wiring, §10).
	fresh("oow_board")
	Save.add_water_pending(int(Data.STARTER_PACK.water))
	var bw = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(bw)
	if bw.board == null:
		bw._ready()
	ok(bw.ad_refill_btn != null and bw.oow_offer_btn != null, "the board builds the watch-ad + offer surfaces")
	ok(Save.water_pending() == 0 and bw.water >= int(Data.STARTER_PACK.water), \
		"the board applies the banked starter water on open")
	# drive to empty and surface the stack (water<=0 reveals the refill stack).
	bw.water = 0
	bw._update_water_hud()
	ok(bw._refill_stack.visible, "at empty the refill stack is shown (the friction point)")
	bw.queue_free()
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

	# T-K: the FREE-ACORN faucet moved OFF the side rail INTO the premium (acorn) shop. The mechanic is
	# unchanged (the free_gems ADS row — cap/cooldown/reward); only the surface moved. The pure status +
	# claim helpers drive the card; the card itself is then asserted through the REAL shop below.
	fresh("free_gems_helpers")
	var fg_amt := int(Data.ADS.free_gems.gems)
	ok(ShopS.free_gems_amount() == fg_amt, "free_gems_amount reports the ADS reward (%d🌰)" % fg_amt)
	var fg0: Dictionary = ShopS.free_gems_status()
	ok(bool(fg0.available) and String(fg0.kind) == "ready", "a fresh faucet reads available (kind 'ready')")
	var fg_before := Save.diamonds()
	var fg_got: int = ShopS.claim_free_gems()
	ok(fg_got == fg_amt and Save.diamonds() == fg_before + fg_amt, "claiming the faucet grants %d🌰 to the wallet" % fg_amt)
	ok(ShopS.claim_free_gems() == 0 and Save.diamonds() == fg_before + fg_amt, "an immediate second claim is refused (no over-grant)")
	var fg1: Dictionary = ShopS.free_gems_status()
	ok(not bool(fg1.available) and String(fg1.kind) == "cooldown" and int(fg1.minutes) >= 1, \
		"right after a watch the faucet is on cooldown (a 'Ready in Nm' read)")
	# exhaust the daily cap (clearing the cooldown between claims) → the faucet reads 'capped' (Back tomorrow).
	for _k in range(Ads.remaining_today("free_gems")):
		Save.grove()["ad_ledger"]["free_gems"]["last"] = 0.0
		ShopS.claim_free_gems()
	Save.grove()["ad_ledger"]["free_gems"]["last"] = 0.0
	var fg2: Dictionary = ShopS.free_gems_status()
	ok(not bool(fg2.available) and String(fg2.kind) == "capped", "with the daily cap spent the faucet reads 'capped' (Back tomorrow)")

	# T-K(ii): the faucet card is REACHABLE in the real premium shop and grants end-to-end. Open the acorn
	# stall on a tree-attached Map host (kit + viewport resolve), find the green "Free" CTA, press it, and
	# assert the wallet gains the reward — proving the rail→shop move wired through.
	fresh("free_gems_card")
	var sh = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(sh)
	if sh.content == null:
		sh._ready()
	ShopS.open_premium(sh, {})
	var sh_overlay: Control = sh.get_child(sh.get_child_count() - 1)
	var fg_card_before := Save.diamonds()
	ok(_press_label(sh_overlay, "Free"), "the premium shop shows a 'Free' acorn faucet CTA")
	ok(Save.diamonds() == fg_card_before + fg_amt, "pressing the shop faucet grants the %d🌰 reward" % fg_amt)
	sh.queue_free()

	# --- UI redesign P2: the empty-cell well reads the role token on the Sunk plane ---
	var cell_sb := BoardScript._cell_style()
	ok(cell_sb.bg_color.is_equal_approx(Pal.CELL_EMPTY), "empty cell well uses Pal.CELL_EMPTY (not the old hardcoded tan)")
	ok(cell_sb.shadow_size == 0, "empty cell sits on the Sunk plane (no drop shadow)")
	var backdrop := BoardScript._field_backdrop()
	ok(backdrop is TextureRect or (backdrop is ColorRect and (backdrop as ColorRect).color.is_equal_approx(Pal.SURFACE)), \
		"board backdrop is either the painted grove board art or the flat SURFACE fallback")
	# the locked-cell WELL unified into the SHARED slot cell (Kit.slot_cell); a recessive `_locked_fill`
	# Panel now backs its rounded corners (the painted slot_locked padlock + the Level badge ride ON TOP).
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
	# the gate marker is the SHARED level-badge medal (Look.make_level_badge) carrying this cell's
	# required Level — same component as the HUD chip, different number (not the old numbered atlas).
	var lv_num: Label = bramble_node.find_child("lv_num", true, false) as Label
	ok(lv_num != null, "frontier locked cell shows the shared level-badge marker (medal + number)")
	ok(lv_num != null and lv_num.text == str(clampi(G.cell_min_level(Vector2i(0, 0)), 1, 25)), \
		"the level-badge marker carries this cell's gate Level number")
	ok(not _tree_has(bramble_node, "PanelContainer"), "locked cell has no dark cream-on-bark gate chip (the loud badge is gone)")
	bramble_node.free()
	ok(BoardScript._quest_band_style().bg_color.v > 0.70, "quest band is a light Rest-plane strip (not the dark fence)")

	finish()
