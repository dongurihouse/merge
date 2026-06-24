extends SceneTree
## Shared base for the split grove suites: preloaded refs, assert helpers, the
## resident/T45 sub-tests, and begin()/finish() (header + Engine.time_scale + summary).
## NOT a runnable suite (no _tests suffix) — grove_*_tests.gd extend this.

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Vault = preload("res://engine/scripts/core/vault.gd")   # T44 — the piggy bank skims earned premium
const Login = preload("res://engine/scripts/core/login.gd")   # T44 — the forgiving daily-login ladder
const VaultUI = preload("res://engine/scripts/ui/vault.gd")   # T44 — the diegetic piggy-bank jar surface
const LoginUI = preload("res://engine/scripts/ui/login.gd")   # T44 — the diegetic login-calendar surface
const Pal = preload("res://games/grove/grove_palette.gd")      # UI redesign — role tiers
const BoardScript = preload("res://engine/scripts/scenes/board.gd")  # UI redesign — board component builders
const PieceViewScript = preload("res://engine/scripts/ui/piece_view.gd")  # UI redesign — locked-cell builder
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")  # flush prewarmed loads at teardown

# Script handles shared across the split suites (were per-section locals).
const Shop = preload("res://engine/scripts/ui/shop.gd")
const ShopS = preload("res://engine/scripts/ui/shop.gd")
const Ads = preload("res://engine/scripts/core/ads.gd")
const Feat = preload("res://engine/scripts/core/features.gd")
const Data = preload("res://games/active.gd").DATA

# Left at 1.0 deliberately. Fast-forwarding the headless clock breaks ~4 frame-dependent
# asserts (bramble-clear, merge->log) that settle over a fixed number of FRAMES flushed
# during the wait; a higher time_scale starves those frames. The split + parallel runner
# are the real speed-up. Raise ONLY if you re-verify the counts still hold.
const TIME_SCALE := 1.0

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# --- R3: pixel-right asserts (eng rule 14) -------------------------------------
# Composited UI (panel + icon + label + offsets) is where 10px misalignment hides
# at full-screen scale. These ASSERT the composition headlessly. Call after the
# host is in-tree and laid out (await a frame) so global rects are real.

# `panel` fully contains `content` with at least `minpad` on every side (nothing
# pokes out) AND symmetric gaps — left≈right, top≈bottom within tol (even, not
# lopsided). H and V padding may differ (a pill is fine); each axis must match
# itself. Returns true/logs.
func assert_wraps(panel: Control, content: Control, minpad: float, tol: float, label: String) -> bool:
	var p := panel.get_global_rect()
	var c := content.get_global_rect()
	var left := c.position.x - p.position.x
	var right := p.end.x - c.end.x
	var top := c.position.y - p.position.y
	var bottom := p.end.y - c.end.y
	var bad := ""
	for pair in [["left", left], ["right", right], ["top", top], ["bottom", bottom]]:
		if float(pair[1]) < minpad - tol:
			bad += " %s=%.1f<%.0f" % [pair[0], pair[1], minpad]
	if absf(left - right) > tol:
		bad += " L/R asym %.1f/%.1f" % [left, right]
	if absf(top - bottom) > tol:
		bad += " T/B asym %.1f/%.1f" % [top, bottom]
	ok(bad == "", "%s — plank wraps content (≥%.0f, symmetric ±%.0f)%s" % [label, minpad, tol, bad])
	return bad == ""

# `content`'s center sits on `box`'s center within tol, on the requested axes.
func assert_centered(box: Control, content: Control, axes: String, tol: float, label: String) -> bool:
	var b := box.get_global_rect().get_center()
	var c := content.get_global_rect().get_center()
	var bad := ""
	if "h" in axes and absf(b.x - c.x) > tol:
		bad += " dx=%.1f" % (c.x - b.x)
	if "v" in axes and absf(b.y - c.y) > tol:
		bad += " dy=%.1f" % (c.y - b.y)
	ok(bad == "", "%s — content centered (%s, ±%.0f)%s" % [label, axes, tol, bad])
	return bad == ""

# The map's single-input-surface invariant: every Control under `node` must
# IGNORE the mouse, or it silently eats taps before clip.gui_input (bug class ×3).
func _all_ignore(node: Node) -> bool:
	for child in node.get_children():
		if child is Control and (child as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			print("    offender: %s (%s)" % [child.get_path(), child.get_class()])
			return false
		if not _all_ignore(child):
			return false
	return true

# A still-tap (press+release, no drift) straight into the map's single input
# surface (content.gui_input → _on_input). `at` is a global point; content is a
# full-rect Control at the origin, so gui_input positions equal globals.
func _map_tap_at(h, at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	h._on_input(down)
	var up := down.duplicate()
	up.pressed = false
	h._on_input(up)

# The global-rect center of a hit node (spot/card) — where a player would tap.
func _hit_center(node: Control) -> Vector2:
	return node.get_global_rect().get_center()

# W2: a tap through the BOARD input surface (the animating gate lives here) — used
# to prove rapid generator taps are no longer dropped mid spawn-flight.
func _tap_board(h, at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	h._on_board_input(down)
	var up := down.duplicate()
	up.pressed = false
	h._on_board_input(up)

# Count the purchasable cards of the MOST RECENT shop overlay (meta shop_buy) —
# a UI-shape smoke that survives storefront restyles.
func _shop_rows(host: Control) -> int:
	var overlay: Control = host.get_child(host.get_child_count() - 1)
	var n := 0
	for b in overlay.find_children("*", "Button", true, false):
		if b.has_meta("shop_buy"):
			n += 1
	return n

# Direct Panel children of board_area = the ground tiles (mat/brambles/pieces
# are Control holders) — the J-bug parity counter.
func _panel_count(area: Control) -> int:
	var n := 0
	for c in area.get_children():
		if c is Panel:
			n += 1
	return n

func fresh(name: String) -> void:
	var dir := "user://tu_test_grove_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)


func begin(title: String) -> void:
	Engine.time_scale = TIME_SCALE
	print("== %s ==" % title)

func finish() -> void:
	# Subtests that instantiate the Map/Board scenes prewarm the OTHER scene off-thread; we never
	# navigate, so flush those loads (else they leak / crash WorkerThreadPool teardown at exit —
	# see scene_warm.gd::drain). Harmless when nothing was prewarmed.
	SceneWarm._clear()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


# ── §1 · the RESIDENTS population sub-game (own fn = its own scope) ────────────────────────
# Replaces the removed §8 home-hub coin-yield keystone. A COMPLETED map opens its resident
# roster: welcome (buy) a t1 — coins for a core/non-premium type, diamonds for the per-map
# premium signature — and two-of-a-kind AUTO-MERGE one tier up, cascading to RESIDENT_MAX_TIER.
# No roster cap (the endless coin sink). The merge + cost math is content.gd; storage is Save.
func _test_residents() -> void:
	var z := 0                                  # map 0 (Farmhouse) — populate it once it's complete
	var map_id := String(G.MAPS[z].id)

	# 0. the OFFER: the roster = the shared core (moss/acorn/lantern) + this map's signature, with
	# exactly one premium (diamond) signature per map. Costs come off resident_cost.
	var lines := G.resident_lines(z)
	ok(lines.size() >= G.RESIDENT_CORE.size() + 1, "the map's roster offers the core + its signature(s)")
	var premium_count := 0
	var core_def := {}
	var premium_def := {}
	for td in lines:
		if bool(td.get("premium", false)):
			premium_count += 1
			premium_def = td
		elif core_def.is_empty():
			core_def = td
	ok(premium_count == 1, "each map offers exactly one premium (💎) signature resident")
	ok(String(G.resident_cost(core_def).currency) == "coins" and int(G.resident_cost(core_def).cost) == G.RESIDENT_BASE_COST, \
		"a core resident costs %d🪙" % G.RESIDENT_BASE_COST)
	ok(String(G.resident_cost(premium_def).currency) == "diamonds" and int(G.resident_cost(premium_def).cost) == G.RESIDENT_PREMIUM_COST, \
		"a premium resident costs %d💎" % G.RESIDENT_PREMIUM_COST)
	var _rart := G.resident_art(String(core_def.id))   # "" under the placeholder art-root (engine draws its fallback), else a real .png
	ok(_rart == "" or _rart.ends_with(".png"), "resident_art resolves a type to an art path (or empty under the placeholder root)")

	# 1. the POPULATE GATE: can_populate is FALSE until the map is fully complete (spots done AND its
	# gate delivered) — the same bar as map_complete. An incomplete or gate-pending map stays closed.
	fresh("residents_gate")
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true                                # all spots restored…
	ok(not G.can_populate(z, unl, []), "can_populate is FALSE on a spot-done but gate-PENDING map")
	ok(not G.can_populate(z, {}, [z]), "can_populate is FALSE on a gated but spot-INCOMPLETE map")
	ok(G.can_populate(z, unl, [z]), "can_populate opens once the map is COMPLETE (spots done + gate delivered)")

	# 2. WELCOME spends + adds a t1. A core welcome debits coins and pushes the t1 count to 1.
	fresh("residents_welcome")
	Save.add_coins(1000)
	var cid := String(core_def.id)
	var coins_b := Save.coins()
	var r1: Dictionary = G.welcome_resident(z, cid)
	ok(bool(r1.ok) and r1.events.is_empty(), "welcoming the first t1 succeeds with NO merge event")
	ok(Save.coins() == coins_b - G.RESIDENT_BASE_COST, "the welcome debited the coin cost")
	ok(Save.resident_counts(map_id, cid)[0] == 1, "the welcomed t1 lands in the t1 count")

	# 3. TWO of a kind AUTO-MERGE to a t2 — the second welcome collapses the pair and returns an event.
	var r2: Dictionary = G.welcome_resident(z, cid)
	ok(bool(r2.ok), "the second welcome succeeds")
	ok(r2.events.size() == 1 and int(r2.events[0].from) == 1 and int(r2.events[0].to) == 2, \
		"two t1 of a kind auto-merge into one t2 (an event is returned)")
	var c_after2: Array = Save.resident_counts(map_id, cid)
	ok(int(c_after2[0]) == 0 and int(c_after2[1]) == 1, "the counts collapse: 0×t1, 1×t2")

	# 4. CASCADE to t3 — building a second t2 (two more t1s) cascades t2→t3 (capped at RESIDENT_MAX_TIER).
	G.welcome_resident(z, cid)                                    # → t1=1
	var r4: Dictionary = G.welcome_resident(z, cid)              # → second t2 forms, then cascades to t3
	var saw_t2 := false
	var saw_t3 := false
	for ev in r4.events:
		if int(ev.to) == 2:
			saw_t2 = true
		if int(ev.to) == 3:
			saw_t3 = true
	ok(saw_t2 and saw_t3, "a fourth t1 cascades t1→t2→t3 (RESIDENT_MAX_TIER=%d)" % G.RESIDENT_MAX_TIER)
	var c_after4: Array = Save.resident_counts(map_id, cid)
	ok(int(c_after4[0]) == 0 and int(c_after4[1]) == 0 and int(c_after4[2]) == 1, "after 4 welcomes the roster is a single t3")

	# 5. resident_members FLATTENS the persisted counts into one {type,tier} per instance. With a lone
	# t3 plus a fresh t1 of the same type, the flattened list is exactly those two members.
	G.welcome_resident(z, cid)                                    # add one more t1 alongside the t3
	var members := G.resident_members(z)
	var my := members.filter(func(m): return String(m.type) == cid)
	ok(my.size() == 2, "resident_members flattens to one entry per resident instance")
	var tiers := []
	for m in my:
		tiers.append(int(m.tier))
	tiers.sort()
	ok(tiers == [1, 3], "the flattened members carry the right tiers (a t1 + the merged t3)")

	# 6. INSUFFICIENT funds refuse cleanly — no count change, no event, ok=false.
	fresh("residents_broke")
	var before_broke: Array = Save.resident_counts(map_id, cid)
	var rb: Dictionary = G.welcome_resident(z, cid)             # 0 coins → refuse
	ok(not bool(rb.ok) and rb.events.is_empty(), "a broke welcome refuses (ok=false, no event)")
	ok(Save.resident_counts(map_id, cid) == before_broke, "a refused welcome leaves the roster untouched")

	# 7. a PREMIUM welcome spends DIAMONDS, not coins.
	fresh("residents_premium")
	Save.add_diamonds(20)
	var pid := String(premium_def.id)
	var gems_b := Save.diamonds()
	var coins_pb := Save.coins()
	var rp: Dictionary = G.welcome_resident(z, pid)
	ok(bool(rp.ok) and Save.diamonds() == gems_b - G.RESIDENT_PREMIUM_COST and Save.coins() == coins_pb, \
		"a premium welcome spends diamonds (coins untouched)")
	ok(Save.resident_counts(map_id, pid)[0] == 1, "the premium t1 lands in its own roster line")

	# 8. PERSISTENCE: the roster survives a cold reload (set → reload from disk → counts intact).
	fresh("residents_persist")
	Save.set_resident_counts(map_id, cid, [2, 1, 0])
	Save.set_resident_counts(map_id, pid, [0, 0, 1])
	Save._loaded = false                                         # force a reload from disk
	ok(Save.resident_counts(map_id, cid) == [2, 1, 0], "a core roster line persists across a reload")
	ok(Save.resident_counts(map_id, pid) == [0, 0, 1], "a premium roster line persists across a reload")
	ok(Save.resident_counts(map_id, "no_such_type") == [0, 0, 0], "an un-welcomed type defaults to all-zero counts")

# §1 · the per-map UNLOCK reward (scaling coins/gems + a free signature spirit), the free-spirit grant,
# and the one-time claim. Pure-model coverage routed into the ACTIVE shop+ads suite (the resident tests
# above run only from the parked placement suite).
func _test_unlock_rewards() -> void:
	fresh("unlock_reward_scale")
	for z in G.MAPS.size():
		var rew: Dictionary = G.map_unlock_reward(z)
		ok(int(rew.coins) == 120 + 80 * z, "map %d unlock grants %d coins (120 + 80*%d)" % [z, 120 + 80 * z, z])
		ok(int(rew.gems) == 2 + z, "map %d unlock grants %d diamonds (2 + %d)" % [z, 2 + z, z])
		var sig: Array = G.RESIDENT_SIGNATURE.get(String(G.MAPS[z].id), [])
		var want := String(sig[0].id) if sig.size() > 0 else ""
		ok(String(rew.spirit) == want, "map %d unlock's free spirit is its signature[0] (%s)" % [z, want])

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

# §1 · the residents SHOP card data: one card per offered resident, correct price/currency, and an
# affordability flag that reflects the live wallet.
func _test_residents_shop_cards() -> void:
	fresh("residents_shop_cards")
	var z := 0
	var lines := G.resident_lines(z)
	Save.add_coins(G.RESIDENT_BASE_COST)        # exactly one core coin card's worth
	Save.spend_diamonds(Save.diamonds())        # zero the NEW_SAVE_GEMS starter balance so the premium card reads unaffordable
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
	for c in cards:
		if String(c.currency) == "coins":
			ok(bool(c.affordable), "a coin card is affordable with exactly its cost banked")
		else:
			ok(not bool(c.affordable), "a diamond card is unaffordable with 0 diamonds")

# §1 · RESIDENTS wiring through the REAL Map scene — proves the UI path, not just the API: a
# completed map opens the "welcome a spirit" panel AND renders the roster as tier-tagged sprites
# (build_population_layer), and map.gd's welcome handler spends + cascades the persisted roster.
func _test_resident_wiring() -> void:
	fresh("residents_wiring")
	var z := 0
	var map_id := String(G.MAPS[z].id)
	# stand map 0 up as COMPLETE (all spots restored + its gate delivered) so it can populate.
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	g["last_map"] = map_id
	Save.grove_write()
	Save.add_coins(1000)
	ok(G.can_populate(z, unl, [z]), "map 0 complete → can_populate (the wiring's precondition)")

	# the first core (coin) kind, and PRE-POPULATE the roster via the API (3 welcomes → a t2 + a t1)
	# so the scene builds against a known non-empty roster (one clean build to inspect).
	var cid := ""
	for td in G.resident_lines(z):
		if not bool(td.get("premium", false)):
			cid = String(td.id)
			break
	G.welcome_resident(z, cid)
	G.welcome_resident(z, cid)
	G.welcome_resident(z, cid)
	ok(Save.resident_counts(map_id, cid) == [1, 1, 0], "3 welcomes leave a t1 + an auto-merged t2")

	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	if hx.content == null:
		hx._ready()
	hx.unlocks = unl
	hx._open_map(z)
	ok(G.residents_shop_cards(z).size() >= 1, "the Residents shop offers kind cards on a populatable map")
	ok(hx._residents_btn != null and hx._residents_btn.visible, "the Residents nav button shows on a populatable map")
	# map.gd rendered the roster as one tier-tagged sprite per member (the population layer).
	var sprites := _find_residents(hx.content, [])
	var has_t1 := false
	var has_t2 := false
	for s in sprites:
		if String(s.get_meta("resident", "")) == cid:
			if int(s.get_meta("tier", 0)) == 1:
				has_t1 = true
			if int(s.get_meta("tier", 0)) == 2:
				has_t2 = true
	ok(sprites.size() >= 2 and has_t1 and has_t2, "map.gd rendered the roster as resident sprites (a t1 + the merged t2)")

	# the REAL welcome handler spends + cascades the roster (asserted via the persisted roster — the
	# on-screen rebuild is frame-deferred, so we trust the durable state, not a re-count of nodes).
	var coins_b := Save.coins()
	_welcome_kind(hx, z, cid)                                     # a 4th t1 → cascades t1+t2 → a t3
	ok(Save.coins() == coins_b - G.RESIDENT_BASE_COST, "welcoming through map.gd spent the coin cost")
	ok(Save.resident_counts(map_id, cid) == [0, 0, 1], "the welcome cascaded the roster to a single t3")
	hx.queue_free()

# collect every rendered resident sprite under `n` (meta-tagged by build_population_layer).
func _find_residents(n: Node, acc: Array) -> Array:
	if n.has_meta("resident"):
		acc.append(n)
	for c in n.get_children():
		_find_residents(c, acc)
	return acc

# drive map.gd's REAL buy handler for kind `cid` (the Residents shop's on_buy path: spend + cascade +
# rebuild). A null refresh Callable is skipped (no open shop to refresh in this headless wiring check).
func _welcome_kind(hx, z: int, cid: String) -> void:
	hx._buy_resident(z, cid, Callable())

# §10 · the 2× DOUBLER re-homed to the board's quest COIN reward (was the removed hub yield-collect).
# Proves the moved card subsystem: a coin reward offers the doubler, accepting credits a SECOND N,
# a zero reward never offers. The one-line wiring (`if sp_coins > 0: _maybe_offer_2x(...)` in
# _on_giver_tap) rides on this; the risk is the moved card, which this drives directly.
# Every Label.text in `node`'s subtree (depth-first) — for asserting composited card copy.
func _label_texts(node: Node) -> Array:
	var out: Array = []
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		out.append_array(_label_texts(c))
	return out

# Every Button.text under `node` (depth-first). Button text is NOT a child Label, so _label_texts misses
# it — use this to assert a widget's button/chip labels (e.g. a read-only amount chip) without pressing.
func _button_texts(node: Node) -> Array:
	var out: Array = []
	if node is Button:
		out.append((node as Button).text)
	for c in node.get_children():
		out.append_array(_button_texts(c))
	return out

func _test_2x_doubler_rehome() -> void:
	fresh("rehome_2x")
	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(scn)
	if scn.board == null:
		scn._ready()
	ok(Ads.can_show("collect_2x"), "the 2× ad is offerable on a fresh save")
	scn._maybe_offer_2x(50, scn.get_global_rect().get_center())
	ok(scn._2x_offer != null and is_instance_valid(scn._2x_offer), "a quest coin reward surfaces the 2× doubler on the board")
	# The card must SPELL OUT the doubling (legibility, not a bare "+50"): the ORIGINAL amount and the
	# DOUBLED total both appear, so the player sees 50 → 100, not one ambiguous number.
	var card_labels := _label_texts(scn._2x_offer)
	ok("50" in card_labels, "the 2× card shows the original amount (50)")
	ok("100" in card_labels, "the 2× card shows the DOUBLED total (100)")
	var coins_b := Save.coins()
	scn._accept_2x_offer(50)
	ok(Save.coins() == coins_b + 50, "accepting the 2× credits a SECOND N coins (the doubled half)")
	ok(scn._2x_offer == null, "the card dismisses after accept")
	scn._maybe_offer_2x(0, scn.get_global_rect().get_center())
	ok(scn._2x_offer == null, "a zero-coin reward never offers the doubler")
	scn.queue_free()

# ── T45 · the INTEGRATION wiring (drives the real Map scene) ──────────────────────────────
# The three monetization engines (2×-collect ad, piggy vault, daily-login calendar) merged
# tested but UNREACHABLE; this proves their entry points are now live:
#   1. a hub auto-collect of N coins surfaces an opt-in 2× DOUBLER that credits exactly a
#      second N and consumes the arm (and does NOT appear when the ad isn't offerable),
#   2. the piggy-bank button lives in the map chrome, opens the jar, and lights its pip when
#      the vault is claimable,
#   3. the daily-login calendar auto-pops on a fresh (unclaimed) day past the FTUE, and stays
#      shut when already claimed today.
func _test_t45_wiring() -> void:
	var hub := G.hub_map()
	var hub_id := String(G.MAPS[hub].spots[0].id)   # a real hub spot to restore as a yield building

	# (The 2× DOUBLER sub-tests (1a/1b) were retired with the hub-yield auto-collect they hung off —
	# the §8 home-hub loop is gone (population sub-game now). FOLLOW-UP: re-point the rewarded "2×"
	# ad from "double a yield collect" to "double a welcome" and restore coverage. See grove_spec §10.)

	# 2. THE PIGGY-VAULT CHROME ENTRY. The map chrome carries a piggy button that opens the jar;
	# its ready-pip reflects Vault.claimable(). Drive _open_vault() → a parchment overlay appears.
	fresh("t45_vault")
	var hv = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hv)
	if hv.content == null:
		hv._ready()
	# a sub-threshold jar → the pip is dark; fill it past the claim min → the pip lights.
	hv._refresh_piggy_pip()
	ok(hv._piggy_pip != null and not hv._piggy_pip.visible, "the piggy ready-pip is dark while the jar is below the claim threshold")
	Vault.skim(Vault.claim_min() * Vault.skim_den() * 4)   # well past claimable
	hv._refresh_piggy_pip()
	ok(Vault.claimable() and hv._piggy_pip.visible, "the piggy ready-pip LIGHTS once the jar is claimable")
	var ov_before: int = hv.get_child_count()
	hv._open_vault()
	ok(hv.get_child_count() == ov_before + 1, "tapping the piggy button opens a surface overlay")
	var vov: Control = hv.get_child(hv.get_child_count() - 1)
	ok(vov.find_children("*", "PanelContainer", true, false).size() >= 1, "the vault opens as a framed parchment jar card (diegetic, §13)")
	ok(_press_label(vov, "Claim"), "the opened vault shows a Claim button (the jar surface, reachable from the hub)")
	hv.queue_free()

	# 3. THE DAILY-LOGIN AUTO-POPUP. Past the FTUE (a spot owned) and unclaimed today, the day's
	# first hub open auto-shows the calendar ONCE; already-claimed → it stays shut.
	Feat.FLAGS["daily_login_popup"] = true            # restore the flag the 2× section turned off
	fresh("t45_login_fresh")
	var gl := Save.grove()
	gl["unlocks"] = {hub_id: true}                    # past the cold FTUE (a rewarding beat happened)
	Save.grove_write()
	ok(not Login.claimed_today(), "today is unclaimed (the day's first open)")
	var hl = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hl)
	if hl.content == null:
		hl._ready()
	await create_timer(0.2).timeout                   # the popup is deferred two frames; the timer spans them
	var login_up := _find_calendar_overlay(hl)
	ok(login_up != null, "the daily-login calendar AUTO-POPS on the day's first hub open (past the FTUE)")
	ok(_press_label(login_up, "Claim"), "the auto-popped calendar shows a Claim button")
	hl.queue_free()

	# 3b. ALREADY CLAIMED today → no auto-popup (it fired its once; never nags).
	fresh("t45_login_claimed")
	var gl2 := Save.grove()
	gl2["unlocks"] = {hub_id: true}
	Save.grove_write()
	ok(Login.claim_today(), "claim today's rung up front")
	ok(Login.claimed_today(), "today now reads claimed")
	var hl2 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hl2)
	if hl2.content == null:
		hl2._ready()
	await create_timer(0.2).timeout
	ok(_find_calendar_overlay(hl2) == null, "an already-claimed day shows NO calendar popup (fires once, never nags)")
	hl2.queue_free()

	# 3c. the cold FTUE session (no spots owned) is SKIPPED — §18 "after a reward, not a cold open".
	fresh("t45_login_ftue")
	var hf = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hf)
	if hf.content == null:
		hf._ready()
	await create_timer(0.2).timeout
	ok(_find_calendar_overlay(hf) == null, "the cold first FTUE session (no spots owned) skips the calendar (§18)")
	hf.queue_free()

# Find a live login-calendar overlay on `host`: the LoginUI roots a full-rect Control whose
# subtree carries the day grid and today's green "Claim" CTA (ui/login.gd). Returns it or null.
func _find_calendar_overlay(host: Control) -> Control:
	for c in host.get_children():
		if not (c is Control):
			continue
		for b in (c as Control).find_children("*", "Button", true, false):
			if String((b as Button).text).findn("Claim") != -1:
				return c as Control
	return null
# T44: press the first Button whose text contains `frag` inside `overlay`. Returns whether
# one was found+pressed (so a test asserts the control exists AND fires its action).
func _press_label(overlay: Control, frag: String) -> bool:
	for b in overlay.find_children("*", "Button", true, false):
		if String((b as Button).text).findn(frag) != -1:
			(b as Button).pressed.emit()
			return true
	return false

# UI redesign: true if `n` or any descendant is of the given built-in class name.
func _tree_has(n: Node, klass: String) -> bool:
	if n.is_class(klass):
		return true
	for c in n.get_children():
		if _tree_has(c, klass):
			return true
	return false

