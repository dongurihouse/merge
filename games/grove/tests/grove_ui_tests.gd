extends "res://games/grove/tests/grove_test_base.gd"
## grove · ui — split from the grove_tests monolith; shares grove_test_base.gd.

func _initialize() -> void:
	begin("grove · ui")
	fresh("ladder")
	var s6 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s6)
	if s6.board == null:
		s6._ready()
	var lad: Array = s6._ladder_entries(1)
	ok(lad.size() == G.TOP_TIER, "the ladder lists every tier of the line")
	ok(bool(lad[0].seen) and not bool(lad[1].seen), "starters are known; tier 2 still a mystery")
	var h6: Vector2 = Vector2(s6.csz, s6.csz) / 2.0
	s6._on_press(s6._cell_pos(Vector2i(3, 2)) + h6)
	s6._on_release(s6._cell_pos(Vector2i(3, 4)) + h6)
	await create_timer(0.3).timeout
	ok(bool(s6._ladder_entries(1)[1].seen), "merging writes the produced tier into the log")
	ok(not bool(s6._ladder_entries(3)[0].seen), "an undebuted line stays fully unknown")
	var kids0: int = s6.get_child_count()
	s6._open_ladder(1, 2)
	ok(s6.get_child_count() == kids0 + 1, "the upgrade-path card opens over the board")
	var persisted: Dictionary = Save.grove().get("seen", {})
	ok(persisted.has("102"), "the discovery log persists in the save")

	# 17. the Shop: diamond packs grant, cash confirm grants directly (no rails yet)
	fresh("shop")
	Save.spend_diamonds(Save.diamonds())       # drain the small new-save seed → genuinely broke
	ok(not Shop.buy_coin_pack(), "the coin pack refuses without diamonds")
	Save.add_diamonds(30)
	var coins_before := Save.coins()
	ok(Shop.buy_coin_pack(), "the coin pack sells")
	ok(Save.coins() == coins_before + Shop.COIN_PACK and Save.diamonds() == 30 - Shop.COIN_PACK_GEM_COST, \
		"coin pack: -%d💎 +%d🪙" % [Shop.COIN_PACK_GEM_COST, Shop.COIN_PACK])
	# T43: the FIRST ladder pack is doubled (first-purchase offer — covered in order-T);
	# spend it first so this asserts the STEADY-STATE direct grant (×1).
	Save.set_first_purchase_made()
	var gems_before := Save.diamonds()
	Shop.grant_cash_pack(0)
	ok(Save.diamonds() == gems_before + int(Shop.CASH_PACKS[0].gems), \
		"confirming a cash pack adds the diamonds directly")
	ok(Shop.buy_water() and Save.diamonds() == gems_before + int(Shop.CASH_PACKS[0].gems) - G.REFILL_DIAMOND_COST, \
		"the water purchase spends its diamonds (price = G.REFILL_DIAMOND_COST)")
	var s7 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s7)
	if s7.board == null:
		s7._ready()
	# The shop is THREE stalls now (water / coin / premium), each opened from its own currency pill's +.
	# Each carries ONLY its corresponding cards — asserted against the same data the stalls read.
	var k: int = s7.get_child_count()
	Shop.open_premium(s7, {})
	ok(s7.get_child_count() == k + 1, "the premium stall opens over the board")
	var rows_premium := _shop_rows(s7)
	# +1 for the Free-acorn faucet card (the rewarded watch moved off the side rail into the stall's lead
	# slot; its CTA is always present — "Free" when offerable, the cozy timer when cooling/capped).
	var want_premium := 1 + Shop.offers_for("diamonds").size() \
		+ (1 if Shop.starter_available() else 0) + Shop.CASH_PACKS.size()
	ok(rows_premium == want_premium, \
		"premium stall = Free faucet + 💎 shortcut(s) + Welcome + the acorn ladder (%d == %d)" % [rows_premium, want_premium])
	# the coin stall = the Coin pouch + the coin-priced shortcuts, and NOTHING else (no acorn ladder):
	# the exact count proves the split — it equals pouch + shortcuts, so no cash/💎 card leaked in.
	k = s7.get_child_count()
	Shop.open_coin(s7, {})
	ok(s7.get_child_count() == k + 1, "the coin stall opens over the board")
	var rows_coin := _shop_rows(s7)
	var want_coin := 1 + Shop.offers_for("coins").size()
	ok(rows_coin == want_coin, \
		"coin stall = the Coin pouch + coin shortcuts, no ladder (%d == %d)" % [rows_coin, want_coin])
	# the water stall: the single Fill-water card, and ONLY when the host can grant water.
	Shop.open_water(s7, {})
	ok(_shop_rows(s7) == 0, "the water stall is empty without a water_grant")
	Shop.open_water(s7, {"water_grant": func() -> void: pass})
	ok(_shop_rows(s7) == 1, "the water stall = the single Fill-water card with a water_grant")

	# 18. the HUD module: same labels, same pixels, in BOTH scenes
	var h7 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h7)
	if h7.content == null:
		h7._ready()
	var kids_h7: int = h7.get_child_count()
	Shop.open_premium(h7, {})
	ok(h7.get_child_count() == kids_h7 + 1, "the storefront opens over the home map too")
	# the wallet is Water·Coin·Gem now (no star count); resolve it via coins_label, which both scenes bind.
	ok(s7.water_label != null and s7.coins_label != null and s7.diamonds_label != null, \
		"the board's HUD labels exist")
	ok(h7.coins_label != null, "home's HUD labels exist")
	Save.add_coins(3)
	h7._update_hud()
	await create_timer(0.6).timeout            # numbers TICK toward the target (§6)
	ok(h7.coins_label.text == str(Save.coins()), "the module refresh keeps the wallet live (ticked)")
	var p_grove: Control = s7.coins_label.get_parent().get_parent()
	var p_home: Control = h7.coins_label.get_parent().get_parent()
	ok(p_grove.offset_top == p_home.offset_top and p_grove.offset_right == p_home.offset_right, \
		"the wallet panel sits at IDENTICAL offsets in both scenes")
	var lv_grove: Control = s7.level_label
	while lv_grove != null and not (lv_grove is PanelContainer):
		lv_grove = lv_grove.get_parent()
	var lv_home: Control = h7.level_label
	while lv_home != null and not (lv_home is PanelContainer):
		lv_home = lv_home.get_parent()
	var lv_row_grove: Control = lv_grove.get_parent() if lv_grove != null else null
	var lv_row_home: Control = lv_home.get_parent() if lv_home != null else null
	ok(lv_row_grove != null and lv_row_grove.get_parent() == s7, \
		"the board Lv badge stays in the standalone top-left HUD row")
	ok(lv_row_home != null and lv_row_home.get_parent() == h7, \
		"the home Lv badge stays in the standalone top-left HUD row")
	ok(lv_row_grove != null and lv_row_home != null \
		and lv_row_grove.offset_left == lv_row_home.offset_left \
		and lv_row_grove.offset_top == lv_row_home.offset_top, \
		"the Lv top-left row sits at IDENTICAL offsets in both scenes")
	ok(lv_grove != null and lv_grove.get_global_rect().position.x < p_grove.get_global_rect().position.x, \
		"the board Lv badge remains separate from the wallet cluster")
	ok(lv_home != null and lv_home.get_global_rect().position.x < p_home.get_global_rect().position.x, \
		"the home Lv badge remains separate from the wallet cluster")
	# R1: the plank wraps the WHOLE cluster — even (symmetric) padding, the row
	# (store basket + ★/🪙/💧) fully inside (rect guard; the crop is the eye proof)
	await create_timer(0.05).timeout            # let the panel lay out
	var row_home: Control = h7.coins_label.get_parent()
	assert_wraps(p_home, row_home, 10.0, 4.0, "R1 wallet")
	var store_btn: Control = row_home.get_child(0)
	ok(p_home.get_global_rect().grow(-4.0).encloses(store_btn.get_global_rect()), \
		"R1: the store button sits fully inside the plank")

	# 19. order L — ambient life + weather
	fresh("ambient")
	var Ambient = load("res://engine/scripts/ui/ambient.gd")
	ok(G.completed_maps({}) == 0, "no maps done on a fresh save")
	var full0 := {}
	for sp0 in G.MAPS[0].spots:
		full0[String(sp0.id)] = true
	ok(G.completed_maps(full0) == 1 and G.character_count(full0) == 2, \
		"character count = 1 + completed maps")
	var alayer: Control = Ambient.build_layer(Vector2(1000, 1000), G.character_count(full0))
	ok(alayer.get_child_count() == 2, "the layer carries that many characters")
	ok(_all_ignore(alayer), "spirits never eat input")
	alayer.free()
	var ga := Save.grove()
	ga["winback_until"] = Time.get_unix_time_from_system() + 60.0
	ok(Ambient.weather_now(false) == "rain", "the win-back minute rains")
	ok(Ambient.weather_now(true) == "breeze", "calm mode WINS: breeze, never rain")
	Ambient.forced_weather = "snow"
	ok(Ambient.weather_now(true) == "snow", "shot tools can force a state")
	Ambient.forced_weather = ""
	var h8 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h8)
	if h8.content == null:
		h8._ready()
	ok(h8.content.get_node_or_null("AmbientLayer") != null, "the map carries the spirit layer")
	ok(h8.get_node_or_null("WeatherLayer") != null, "the map carries the weather layer")
	ok(_all_ignore(h8.content), "the map guard stays green with spirits wandering")
	var s8 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s8)
	if s8.board == null:
		s8._ready()
	ok(s8.get_node_or_null("WeatherLayer") != null, \
		"the board carries the weather layer (the ambient drift/spirit band was removed in the art reskin)")

	# 20. order N — feature flags: all-ON is proven by the whole sweep (zero
	# behavior change); two flip smokes prove the guards actually disconnect
	var Features = load("res://engine/scripts/core/features.gd")
	ok(Features.on("idle_hint") and Features.on("nonexistent_flag_xyz"), \
		"known flags read true; unknown ids warn + default ON (typo-proof)")
	Features.FLAGS["idle_hint"] = false
	ok(s8._hint_pair().is_empty(), "idle_hint OFF: _hint_pair returns [] and wiggles nothing")
	Features.FLAGS["idle_hint"] = true
	fresh("flagpop")
	Features.FLAGS["ftue_free_pops"] = false
	var s9 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s9)
	if s9.board == null:
		s9._ready()
	s9.board.take(Vector2i(3, 2))             # a virgin board has 2 empties — make room
	s9._rebuild_pieces()
	var s9b := 0
	for v in s9.board.items:
		if v > 0:
			s9b += 1
	s9._pop_seed()
	await create_timer(0.25).timeout
	var s9n := -s9b
	for v in s9.board.items:
		if v > 0:
			s9n += 1
	ok(s9n >= 1 and s9.water == G.WATER_CAP - s9n * G.POP_COST, "ftue_free_pops OFF: the FIRST pop costs water (no free intro)")
	Features.FLAGS["ftue_free_pops"] = true

	# 21. R4 — sweep the composited UI with the pixel-right asserts. Each element
	# now has PERMANENT rect coverage (the law's durable value); a failure here is
	# a real misalignment to fix. (wallet was R1; map pin R2.)
	fresh("r4")
	# water chip (board, top-left) — reveal past the FTUE stage, then assert it wraps
	var sb4 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sb4)
	if sb4.board == null:
		sb4._ready()
	Save.grove()["pops"] = 10                 # FTUE done → the water chip shows
	sb4._update_water_hud()
	await create_timer(0.05).timeout
	var wchip: Control = sb4.water_label.get_parent().get_parent()
	var wrow: Control = sb4.water_label.get_parent()
	assert_wraps(wchip, wrow, 5.0, 4.0, "R4 water chip")
	# level chip (home) — the badge belongs to the top-left HUD row, separate from the wallet.
	var h4 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h4)
	if h4.content == null:
		h4._ready()
	await create_timer(0.05).timeout
	var lchip: Control = h4.level_label
	while lchip != null and not (lchip is PanelContainer):
		lchip = lchip.get_parent()
	var wallet4: Control = h4.coins_label.get_parent().get_parent()
	ok(lchip != null and lchip.get_parent() != null and lchip.get_parent().get_parent() == h4, \
		"R4 level chip sits in the top-left HUD row")
	ok(lchip != null and h4.get_viewport_rect().encloses(lchip.get_global_rect()), \
		"R4 level chip sits on-screen")
	ok(lchip != null and not lchip.get_global_rect().intersects(wallet4.get_global_rect()), \
		"R4 level chip stays separate from the wallet plank")
	# §16 home: an unrestored hub building shows a ✿cost RESTORE BADGE (the mask-reveal home replaced
	# the old cutout price-pin; the badge is a farm_icons circle + the star cost).
	await create_timer(0.05).timeout
	var badge_found := false
	for hit in h4.spot_hits:
		var node: Control = hit.node
		if not node.find_children("*", "TextureRect", true, false).is_empty():
			badge_found = true
			break
	ok(badge_found, "R4/§16: an unrestored hub spot shows a restore badge")

	# 22. U1 — item backing (contrast): ON puts a soft dark ellipse UNDER the item
	# (first child = bottom); OFF leaves the item bare. Flag item_backing.
	Features.FLAGS["item_backing"] = true
	var pc_on: Control = sb4._make_piece(101, 100.0)
	ok(pc_on.get_child(0) is TextureRect and pc_on.get_child(0).modulate.a < 0.5, \
		"item_backing ON: a soft low-alpha ellipse sits under the item")
	ok(_all_ignore(pc_on), "U1: the backing never eats input")
	Features.FLAGS["item_backing"] = false
	var pc_off: Control = sb4._make_piece(101, 100.0)
	ok(pc_off.get_child(0).modulate.a > 0.9, "item_backing OFF: the item is bare (no backing)")
	Features.FLAGS["item_backing"] = true   # AF3: ON is the default (now a contact shadow)

	# 22b. Shared pipeline: a GENERATOR renders through the same path as a piece, so it gets
	# the same contact-shadow ellipse under it (child 0, low-alpha) when item_backing is ON,
	# and never eats input. (Was: only make_piece added the shadow — the seed satchel had none.)
	Features.FLAGS["item_backing"] = true
	var gen_on: Control = PieceViewScript.make_generator("seed_satchel", 100.0)
	ok(gen_on.get_child(0) is TextureRect and gen_on.get_child(0).modulate.a < 0.5, \
		"a generator gets the same contact shadow as a piece (child 0)")
	ok(_all_ignore(gen_on), "U1: the generator backing never eats input")
	Features.FLAGS["item_backing"] = false
	var gen_off: Control = PieceViewScript.make_generator("seed_satchel", 100.0)
	ok(gen_off.get_child(0).modulate.a > 0.9, "item_backing OFF: the generator is bare (no backing)")
	Features.FLAGS["item_backing"] = true

	# 22c. Resting vs picked-up. Idle is a TIGHT shadow hugging the item. Picking it up must read
	# clearly, so set_lifted does TWO things: the item ART RISES (offset_top moves up, opening a
	# gap) and the shadow drops + spreads beneath it. Dropping settles both back. A shadow that
	# only grew in place was invisible — it sits behind the item, so the item must lift off it.
	Features.FLAGS["item_backing"] = true
	var lift_pc: Control = sb4._make_piece(101, 100.0)
	var lift_shadow: TextureRect = lift_pc.get_child(0)
	var lift_art: Control = lift_pc.get_node("ItemArt")
	var idle_w := lift_shadow.size.x
	var art_rest_top := lift_art.offset_top
	PieceViewScript.set_lifted(lift_pc, true)
	ok(lift_shadow.size.x > idle_w, "picking the item up grows the shadow")
	ok(lift_art.offset_top < art_rest_top, "picking the item up RAISES the art (it lifts off its shadow)")
	PieceViewScript.set_lifted(lift_pc, false)
	ok(is_equal_approx(lift_shadow.size.x, idle_w), "dropping restores the tight resting shadow")
	ok(is_equal_approx(lift_art.offset_top, art_rest_top), "dropping settles the art back down")
	var lift_gen: Control = PieceViewScript.make_generator("seed_satchel", 100.0)
	var gen_art: Control = lift_gen.get_node("ItemArt")
	var gen_rest_top := gen_art.offset_top
	PieceViewScript.set_lifted(lift_gen, true)
	ok(gen_art.offset_top < gen_rest_top, "a generator lifts the same way (shared pipeline)")
	PieceViewScript.set_lifted(lift_gen, false)

	# 23. P — drag-to-swap two unlocked items (flag drag_swap)
	# P1: the model — swap trades codes, a coin swaps like anything, it persists
	var pb := BoardModel.new()
	var pa := Vector2i(4, 4)
	var pbc := Vector2i(4, 5)
	pb.terrain[BoardModel.idx(pa)] = 0
	pb.terrain[BoardModel.idx(pbc)] = 0
	pb.place(pa, 101)
	pb.place(pbc, 203)
	pb.swap(pa, pbc)
	ok(pb.item_at(pa) == 203 and pb.item_at(pbc) == 101, "P1: swap trades two item codes")
	var pcoin := G.COIN_LINE * 100 + 1
	pb.place(pa, pcoin)
	pb.swap(pa, pbc)                          # pbc held 101
	ok(pb.item_at(pa) == 101 and pb.item_at(pbc) == pcoin, "P1: a coin swaps like any item")
	var pb2 := BoardModel.new()
	pb2.from_dict(pb.to_dict())
	ok(pb2.item_at(pa) == 101 and pb2.item_at(pbc) == pcoin, "P1: to_dict/from_dict preserves the swapped board")

	# P2: the drop chain (real _on_press → _on_release drives)
	fresh("pswap")
	Features.FLAGS["drag_swap"] = true
	var sp = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sp)
	if sp.board == null:
		sp._ready()
	var phalf: Vector2 = Vector2(sp.csz, sp.csz) / 2.0
	var es: Array = sp.board.empty_ground_cells()
	var c1 := Vector2i(es[0])
	var c2 := Vector2i(es[1])
	# occupied-different → swap; BOTH piece_nodes update
	sp.board.place(c1, 101)
	sp.board.place(c2, 203)
	sp._rebuild_pieces()
	sp._on_press(sp._cell_pos(c1) + phalf)
	sp._on_release(sp._cell_pos(c2) + phalf)
	ok(sp.board.item_at(c1) == 203 and sp.board.item_at(c2) == 101, "P2: occupied-different target → swap")
	ok(sp.piece_nodes.has(c1) and sp.piece_nodes.has(c2), "P2: piece_nodes updated for BOTH cells")
	# same-code → MERGE keeps precedence (never swaps)
	sp.board.place(c1, 101)
	sp.board.place(c2, 101)
	sp._rebuild_pieces()
	sp._on_press(sp._cell_pos(c1) + phalf)
	sp._on_release(sp._cell_pos(c2) + phalf)
	ok(sp.board.item_at(c2) == 102 and sp.board.item_at(c1) == 0, "P2: same-code drop MERGES (precedence over swap)")
	# flag OFF → snap-back, nothing swaps
	Features.FLAGS["drag_swap"] = false
	sp.board.place(c1, 101)
	sp.board.place(c2, 203)
	sp._rebuild_pieces()
	sp._on_press(sp._cell_pos(c1) + phalf)
	sp._on_release(sp._cell_pos(c2) + phalf)
	ok(sp.board.item_at(c1) == 101 and sp.board.item_at(c2) == 203, "P2: drag_swap OFF → snap-back (no swap)")
	Features.FLAGS["drag_swap"] = true
	# drop on a generator cell → snap-back (never swaps with a generator)
	var gcell := Vector2i(G.GEN_CELL)
	sp.board.place(c1, 101)
	sp._rebuild_pieces()
	sp._on_press(sp._cell_pos(c1) + phalf)
	sp._on_release(sp._cell_pos(gcell) + phalf)
	ok(sp.board.item_at(c1) == 101, "P2: drop on a generator cell → snap-back")

	# 24. T — the Decorate jump goes to the MAP the player was decorating (NEW model:
	# decorate_map opens that MAP, not an interior). Boot lands ON a map view.
	var HomeScript = load("res://engine/scripts/scenes/map.gd")
	# T1: opening a map persists last_map
	fresh("tlast")
	var ht = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(ht)
	if ht.content == null:
		ht._ready()
	ht._open_map(0)
	ok(String(Save.grove().get("last_map", "")) == "farmhouse", "T1: opening a map persists last_map")
	# T1: sanitize — an unknown last_map never survives a boot. _load_state drops it,
	# then the boot opens the frontier and re-records a VALID map id in its place.
	Save.grove()["last_map"] = "atlantis"
	var ht2 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(ht2)
	if ht2.content == null:
		ht2._ready()
	ok(G.map_for_id(String(Save.grove().get("last_map", ""))) >= 0, \
		"T1: an unknown last_map is scrubbed on load (boot re-records a valid map)")
	ok(ht2._view == "map", "T1: fresh arrival (no jump request) lands on a map view")
	# T2: the Decorate jump — opens the named map directly, NO map-select flash
	# (asserted before any frame), and the request is one-shot
	HomeScript.decorate_map = "farmhouse"
	var ht3 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(ht3)
	if ht3.content == null:
		ht3._ready()
	ok(ht3._view == "map" and ht3._map_idx == 0, \
		"T2: Decorate opens the named map directly (asserted pre-frame: no select flash)")
	ok(HomeScript.decorate_map == "", "T2: the jump request is one-shot (consumed)")
	# T2: an unknown jump request falls through to the frontier map
	HomeScript.decorate_map = "atlantis"
	var ht4 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(ht4)
	if ht4.content == null:
		ht4._ready()
	ok(ht4._view == "map", "T2: an unknown jump request falls through to the frontier map")

	# 24b. item-3: the daily-login calendar fires once per APP LAUNCH, not once per Map open. A
	# Board→Map return re-runs Map._ready, but a per-launch guard means it never re-pops the calendar.
	# _login_popup_blocked() is the synchronous gate (launch guard · feature · claimed · cold-FTUE);
	# when nothing blocks, the deferred popup shows ONCE and arms the guard.
	fresh("login_launch")
	Feat.FLAGS["daily_login_popup"] = true
	Save.grove()["unlocks"] = {"fh_well": true}     # past the cold-FTUE gate (a rewarding beat happened)
	var hm = load("res://engine/scenes/Map.tscn").instantiate()
	hm.unlocks = {"fh_well": true}
	HomeScript._login_shown_launch = false
	ok(not hm._login_popup_blocked(), "item 3: first open this launch → the login calendar is due")
	HomeScript._login_shown_launch = true
	ok(hm._login_popup_blocked(), "item 3: after it shows once this launch, a Map re-open never re-pops it")
	hm.free()
	HomeScript._login_shown_launch = false          # leave the static clean for any later section

	# 25. order O — music degrades SILENTLY on a BARE engine. Audio is skin and the
	# real takes are archived, so ensure() must be a quiet no-op (never create a
	# player to crash on). The full A/B playlist-alternation logic ships + is tested
	# WITH the audio skin (needs takes on disk); here we only guard the engine never
	# crashes/hangs without it. (T16: this test used to assume real music on disk.)
	var Music = load("res://engine/scripts/core/music.gd")
	fresh("omusic")
	Music.stop()
	Music.ensure()
	ok(Music._player == null or not Music._player.playing, "O: no audio skin → ensure() is a silent no-op (no crash/hang)")
	Save.set_setting("music", false)
	Music.refresh()
	ok(Music._player == null or not Music._player.playing, "O: music Off → refresh() leaves the bed silent")
	Save.set_setting("music", true)
	Music.stop()
	Music.take_dir = "res://games/grove/assets/nonexistent/"
	Music.ensure()
	ok(Music._player == null or not Music._player.playing, "O: zero takes on disk → ensure() is a silent no-op (no crash)")
	Music.take_dir = "res://games/grove/assets/music_archived/"   # archived: the dir is gone → no takes resolve
	ok(Music._takes().size() == 0, "O: audio skin archived → no takes resolve (bare engine)")

	# 27. the currency pill is now CONFIG-DRIVEN through the shared kit: the workbench saves a
	# "currency_pill" block, Kit.currency_pill_opts_from_config resolves it (Tune.Hud values as the
	# defaults), and the HUD reads it. The DEFAULTS must equal Tune so an absent/empty config renders
	# the SHIPPED pill byte-for-byte — the R1 even-wrap contract above relies on that.
	var Kit = load("res://games/grove/tools/ui_workbench_kit.gd")
	var Hud = load("res://engine/scripts/core/tuning.gd").Hud
	var dflt: Dictionary = Kit.currency_pill_opts_from_config({})
	ok(is_equal_approx(float(dflt.pad_x), Hud.CLUSTER_PAD_X) and is_equal_approx(float(dflt.pad_y), Hud.PILL_PAD_Y), \
		"currency_pill default padding == Tune (CLUSTER_PAD_X / PILL_PAD_Y)")
	ok(int(dflt.radius) == Hud.PILL_RADIUS and int(dflt.border_w) == Hud.PILL_BORDER_W, \
		"currency_pill default border == Tune (radius / border width)")
	ok(int(dflt.num_size) == Hud.NUM_SIZE, "currency_pill default font == Tune.NUM_SIZE")
	ok(is_equal_approx(float(dflt.icon_box), Hud.CHIP_ICON_BOX) and int(dflt.row_sep) == Hud.CHIP_ROW_SEP \
		and int(dflt.pair_sep) == Hud.PAIR_SEP, "currency_pill default icon box / separations == Tune")
	ok(int(dflt.shadow_size) == Hud.PILL_SHADOW_SIZE, "currency_pill default shadow size == Tune")
	# a saved block overrides ONLY the named keys; every other key stays at its Tune default
	var over: Dictionary = Kit.currency_pill_opts_from_config({"currency_pill": {"pad_x": 5, "num_size": 99}})
	ok(is_equal_approx(float(over.pad_x), 5.0) and int(over.num_size) == 99, "currency_pill config overrides the named keys")
	ok(int(over.border_w) == Hud.PILL_BORDER_W, "currency_pill config leaves un-named keys at the Tune default")
	# the standalone preview builds a panel whose row carries every currency count
	var pill: Control = Kit.currency_pill(dflt, {"star": 12, "coin": 345, "gem": 6})
	get_root().add_child(pill)
	await create_timer(0.05).timeout
	var texts := _all_label_texts(pill)
	ok("12" in texts and "345" in texts and "6" in texts, "currency_pill preview renders the sample counts")
	pill.queue_free()

	# 28. the map-SELECT place-picker CARD (spec §8) is now CONFIG-DRIVEN through the shared kit: the
	# workbench saves a "map_card" block, Kit.map_card_opts_from_config resolves it (the shipped §8
	# constants as defaults), and map.gd builds EVERY place-picker card from Kit.map_card. The DEFAULTS
	# must equal the shipped constants so an absent/empty config renders the SHIPPED card byte-for-byte.
	var md: Dictionary = Kit.map_card_opts_from_config({})
	ok(is_equal_approx(float(md.frame_inset), 0.045) and is_equal_approx(float(md.art_radius), 0.058), \
		"map_card default frame inset / art radius == shipped (0.045 / 0.058)")
	ok(is_equal_approx(float(md.pill_w_frac), 0.30) and is_equal_approx(float(md.pill_min), 170.0) \
		and is_equal_approx(float(md.pill_max), 290.0) and is_equal_approx(float(md.pill_y_frac), 0.13), \
		"map_card default count-pill metrics == shipped")
	ok(is_equal_approx(float(md.veil_scrim), 0.42) and is_equal_approx(float(md.veil_deep), 0.66) \
		and is_equal_approx(float(md.veil_mark_alpha), 0.16) and is_equal_approx(float(md.veil_mark_size), 64.0), \
		"map_card default fog-veil look == shipped (§8)")
	ok(bool(md.use_art), "map_card defaults to the painted art (use_art)")
	# a saved block overrides ONLY the named keys; every other key stays at its shipped default
	var mover: Dictionary = Kit.map_card_opts_from_config({"map_card": {"frame_inset": 80, "pill_min": 99}})
	ok(is_equal_approx(float(mover.frame_inset), 0.080) and is_equal_approx(float(mover.pill_min), 99.0), \
		"map_card config overrides the named keys")
	ok(is_equal_approx(float(mover.art_radius), 0.058), "map_card config leaves un-named keys at the shipped default")
	# the standalone OPEN card wears the gold frame + the 'N left' pill and has NO fog veil…
	var mh: float = 460.0 / Kit.MAP_CARD_ASPECT
	var open_card: Control = Kit.map_card({"open": true, "done": false, "art": "", "stars_left": 4, "map_id": ""}, md, 460.0, mh)
	get_root().add_child(open_card)
	await create_timer(0.05).timeout
	ok(_has_tex_suffix(open_card, "card_active.png"), "map_card OPEN wears the gold frame (card_active)")
	ok("4 left" in str(_all_label_texts(open_card)), "map_card OPEN shows the 'N left' restore pill")
	ok(open_card.find_child("Veil", true, false) == null, "map_card OPEN has NO fog veil")
	open_card.queue_free()
	# …and the LOCKED card wears the dark panel + the 'after <prev>' line, no gold frame.
	var locked_card: Control = Kit.map_card({"open": false, "done": false, "art": "", "prereq": "✿ after Meadow", "map_id": ""}, md, 460.0, mh)
	get_root().add_child(locked_card)
	await create_timer(0.05).timeout
	ok(_has_tex_suffix(locked_card, "card_locked.png"), "map_card LOCKED wears the dark panel (card_locked)")
	ok("after" in str(_all_label_texts(locked_card)), "map_card LOCKED shows the 'after <prev>' line")
	ok(not _has_tex_suffix(locked_card, "card_active.png"), "map_card LOCKED has NO gold frame")
	locked_card.queue_free()
	# with the painted art OFF, the locked card falls back to the §8 code-drawn fog veil (the moved kit code)
	var mcode: Dictionary = md.duplicate()
	mcode["use_art"] = false
	var locked_code: Control = Kit.map_card({"open": false, "done": false, "art": "", "prereq": "✿ after X", "map_id": "meadow"}, mcode, 460.0, mh)
	get_root().add_child(locked_code)
	await create_timer(0.05).timeout
	ok(locked_code.find_child("Veil", true, false) != null, "map_card LOCKED w/o art falls back to the §8 fog veil")
	locked_code.queue_free()

	# 29. the unowned-spot restore disc is CONFIG-DRIVEN through the same kit: the workbench saves a
	# "home_unlock_button" block, Kit.home_unlock_opts_from_config resolves it (scales stored 0..100,
	# divided to 0..1 fractions of the disc), and map.gd reads it. The DEFAULTS reproduce the baked
	# badge (disc 16% of the map; "+" 30% / icon 26% / cost font 26% of the disc).
	var udf: Dictionary = Kit.home_unlock_opts_from_config({})
	ok(is_equal_approx(float(udf.disc_pct), 16.0), "home_unlock default disc_pct == 16 (% of map width)")
	ok(is_equal_approx(float(udf.plus_scale), 0.30) and is_equal_approx(float(udf.cost_font), 0.26) \
		and is_equal_approx(float(udf.icon_scale), 0.26), "home_unlock default +/icon/cost == 30/26/26% of disc")
	ok(is_equal_approx(float(udf.stack_gap), -0.01) and is_equal_approx(float(udf.icon_gap), 0.02), \
		"home_unlock default gaps resolve (stack -1% · icon 2% of disc)")
	# sparkle (glow/twinkle) defaults to 0 → the in-game disc is unchanged until a designer dials it up
	ok(is_equal_approx(float(udf.glow), 0.0) and is_equal_approx(float(udf.twinkle), 0.0), \
		"home_unlock default sparkle is OFF (glow/twinkle 0)")
	# a saved block overrides ONLY the named keys (and is divided to a fraction)
	var uov: Dictionary = Kit.home_unlock_opts_from_config({"home_unlock_button": {"disc_pct": 22, "plus_scale": 50, "glow": 40}})
	ok(is_equal_approx(float(uov.disc_pct), 22.0) and is_equal_approx(float(uov.plus_scale), 0.50) \
		and is_equal_approx(float(uov.glow), 0.40), "home_unlock config overrides the named keys (glow → /100)")
	ok(is_equal_approx(float(uov.cost_font), 0.26), "home_unlock config leaves un-named keys at the default")
	# the builder makes a real Button rendering the "+" and the cost number
	udf["px"] = 173.0
	var disc: Button = Kit.home_unlock_button({"cost": 4, "icon": "star"}, udf)
	get_root().add_child(disc)
	await create_timer(0.05).timeout
	var dtexts := _all_label_texts(disc)
	ok(disc is Button and "+" in dtexts and "4" in dtexts, "home_unlock disc is a Button rendering '+' and the cost")
	# sparkle is opt-in: no overlay when glow/twinkle are 0, an overlay child when asked AND tuned > 0
	var spk: Button = Kit.home_unlock_button({"cost": 4, "icon": "star", "sparkle": true}, \
		{"px": 173.0, "glow": 0.5, "twinkle": 0.5})
	get_root().add_child(spk)
	await create_timer(0.05).timeout
	ok(spk.get_child_count() > disc.get_child_count(), "home_unlock adds the sparkle overlay when sparkle + glow/twinkle > 0")
	disc.queue_free()
	spk.queue_free()

	# 26. order S — placement asserts (S1 bottom bar · S4 chips never clip)

	# 27. progress_bar — the reusable kit bar (track + fill, optional centered label)
	var KitP = load("res://games/grove/tools/ui_workbench_kit.gd")
	for frac in [0.0, 0.5, 1.0]:
		var bar: Control = KitP.progress_bar(float(frac), {"height": 20.0, "art": false})
		ok(bar != null and bar is Control, "progress_bar builds at frac=%.1f" % float(frac))
		bar.queue_free()
	var labelled: Control = KitP.progress_bar(0.75, {"height": 22.0, "art": false, "label": "75%"})
	get_root().add_child(labelled)
	await create_timer(0.02).timeout
	ok("75%" in _all_label_texts(labelled), "progress_bar shows its centered label")
	labelled.queue_free()

	# 28. level_medallion — wreath + ring + centered number
	var med: Control = KitP.level_medallion(7, 120.0, {})
	get_root().add_child(med)
	await create_timer(0.02).timeout
	ok(med != null and med is Control, "level_medallion builds")
	ok("7" in _all_label_texts(med), "level_medallion shows the level number")
	med.queue_free()

	# 29. level_dialog — builds in both modes; info shows Got it, levelup shows Collect
	var info_data := {"level": 1, "earned": 0, "next": 6, "into": 0, "span": 6, "remaining": 6, "mode": "info"}
	var di: Control = KitP.level_dialog(info_data, 460.0, KitP.level_opts_from_config({}))
	get_root().add_child(di)
	await create_timer(0.02).timeout
	ok(di != null and di is Control, "level_dialog builds in info mode")
	ok(_find_button_text(di, "Got it") != null, "info mode shows the Got it button")
	di.queue_free()
	var up_data := {"level": 2, "earned": 6, "next": 18, "into": 0, "span": 12, "remaining": 12,
		"mode": "levelup", "gift": {"water": 30, "gems": 1}}
	var du: Control = KitP.level_dialog(up_data, 460.0, KitP.level_opts_from_config({}))
	get_root().add_child(du)
	await create_timer(0.02).timeout
	ok(du != null, "level_dialog builds in levelup mode")
	ok(_find_button_text(du, "Collect") != null, "levelup mode shows the Collect button")
	du.queue_free()

	# 30. level_popup — info + levelup modes; Collect grants the gift exactly once
	var LevelPopupS = load("res://engine/scripts/ui/level_popup.gd")
	var lp_host := Control.new()
	lp_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(lp_host)
	await create_timer(0.02).timeout
	var ov: Control = LevelPopupS.open(lp_host)
	ok(ov != null and is_instance_valid(ov), "LevelPopup.open builds the info overlay")
	ok(_find_button_text(ov, "Got it") != null, "info overlay shows Got it")
	ov.queue_free()
	await create_timer(0.02).timeout
	var dia0 := Save.diamonds()
	var ov2: Control = LevelPopupS.open_levelup(lp_host, 1)
	var collect := _find_button_text(ov2, "Collect")
	ok(collect != null, "levelup overlay shows Collect (not Got it)")
	if collect != null:
		collect.emit_signal("pressed")
	ok(Save.diamonds() == dia0 + G.LEVEL_DIAMONDS, "Collect grants the level-up diamond gift once")
	lp_host.queue_free()
	finish()

## Every Label.text under `n` (depth-first) — lets a placement assert check that a built widget
## actually rendered the values it was handed.
func _all_label_texts(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		out.append_array(_all_label_texts(c))
	return out

## The first Button under `n` whose text contains `needle` (depth-first), or null. Button.text is not a
## child Label, so _all_label_texts can't see it — this finds the button itself (to assert / press it).
func _find_button_text(n: Node, needle: String) -> Button:
	if n is Button and String((n as Button).text).find(needle) != -1:
		return n as Button
	for c in n.get_children():
		var f := _find_button_text(c, needle)
		if f != null:
			return f
	return null

## True iff any TextureRect under `n` (depth-first) carries a texture whose path ends with `suffix` —
## names a shipped frame by its kit file without depending on node names (mirrors mapfx_tests._has_tex).
func _has_tex_suffix(n: Node, suffix: String) -> bool:
	if n is TextureRect:
		var t := (n as TextureRect).texture
		if t != null and String(t.resource_path).ends_with(suffix):
			return true
	for c in n.get_children():
		if _has_tex_suffix(c, suffix):
			return true
	return false
