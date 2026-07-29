extends "res://engine/tests/test_base.gd"
## Shared base for the split grove suites: preloaded refs, assert helpers, the
## resident sub-tests, and begin()/finish() (header + Engine.time_scale + summary).
## NOT a runnable suite (no _tests suffix) — grove_*_tests.gd extend this.
## The counters, ok(), fresh() and the printed footer live one layer down in
## engine/tests/test_base.gd, shared with every engine suite.

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Strings = preload("res://engine/scripts/core/strings.gd")   # localized copy (board.refill.*)
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
const Claims = preload("res://engine/scripts/core/claims.gd")
const Feat = preload("res://engine/scripts/core/features.gd")
const Data = preload("res://games/active.gd").DATA

# Left at 1.0 deliberately. Fast-forwarding the headless clock breaks ~4 frame-dependent
# asserts (bramble-clear, merge->log) that settle over a fixed number of FRAMES flushed
# during the wait; a higher time_scale starves those frames. The split + parallel runner
# are the real speed-up. Raise ONLY if you re-verify the counts still hold.
const TIME_SCALE := 1.0

# --- the three engine scene hosts ----------------------------------------------
# test_base.mount() bound to each scene's path + its "did _ready run?" probe. The probe is a
# property of the SCENE, not of the test: Map builds `content`, Board builds `board`, ExploreRush
# builds its whole subtree. Suites call map_host()/board_host()/rush_host(); grove_shop_tests
# drives both Map and Board from one loop, so the raw probes stay reachable too.
const MAP_SCENE := "res://engine/scenes/Map.tscn"
const BOARD_SCENE := "res://engine/scenes/Board.tscn"
const RUSH_SCENE := "res://engine/scenes/ExploreRush.tscn"

static func map_unready(h) -> bool:
	return h.content == null

static func board_unready(h) -> bool:
	return h.board == null

static func rush_unready(h) -> bool:
	return h.get_child_count() == 0

func map_host() -> Node:
	return mount(MAP_SCENE, map_unready)

func board_host() -> Node:
	return mount(BOARD_SCENE, board_unready)

func rush_host() -> Node:
	return mount(RUSH_SCENE, rush_unready)

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

# `node` renders fully UNCUT: its global rect sits inside every clip_contents ancestor's
# rect (± tol). Guards the dialog bug class where decorative overhangs (a card's ribbon,
# a marked cell's gold ring, a bank card's bar) poke past the shared frame's clip and get
# sliced at the edge. Call after layout has settled (await a frame first).
func assert_unclipped(node: Control, axes: String, tol: float, label: String) -> bool:
	var r := node.get_global_rect()
	var bad := ""
	var anc: Node = node.get_parent()
	while anc != null:
		if anc is Control and (anc as Control).clip_contents:
			var cr := (anc as Control).get_global_rect()
			var checks := []
			if "h" in axes:
				checks += [["left", cr.position.x - r.position.x], ["right", r.end.x - cr.end.x]]
			if "v" in axes:   # NOTE: content scrolled out of a vertical window is a legit "cut" — only
				checks += [["top", cr.position.y - r.position.y], ["bottom", r.end.y - cr.end.y]]   # ask for "v" on non-scrolling clips
			for pair in checks:
				if float(pair[1]) > tol:
					bad += " %s cut %.1f by %s" % [pair[0], pair[1], anc.name]
		anc = anc.get_parent()
	ok(bad == "", "%s — renders unclipped (%s, ±%.1f)%s" % [label, axes, tol, bad])
	return bad == ""

# A FREE-STANDING PAPER BUTTON wears the shared surface treatment (engine/scripts/ui/paper_button.gd) —
# the same material the bottom nav tabs are made of, WITHOUT the geometry that only makes sense for a tab
# anchored to the screen edge. Read off the CutPaperPanel the button actually built, so this covers the
# rendered thing rather than the knob dict that was handed to it.
#
# The knob VALUES themselves are pinned in engine/tests/action_button_tests.gd (the material's own unit
# tests, with their literal px bounds); what this asserts, per button, is that the button IS on it —
# smooth + feathered, casting the scene's directional shadow, a lit hairline, rimless — and that it did
# NOT inherit the tab's flare. A shared module is only worth having if every caller is provably reading it.
func assert_paper_button(btn: Button, label: String) -> void:
	if btn == null:
		ok(false, "%s exists to carry the shared paper-button material" % label)
		return
	var p := btn.find_child("ActionButtonDeckleSurface", true, false) as Control
	if p == null:
		ok(false, "%s wears a code-drawn cut-paper surface" % label)
		return
	ok(is_equal_approx(p.deckle_amp, 0.0) and p.edge_feather > 0.0,
		"%s — smooth antialiased edge, not torn (feather %.2fpx)" % [label, p.edge_feather])
	ok(is_equal_approx(p.rim_width, 0.0), "%s — no rim: its paper edge just ends" % label)
	var off: Vector2 = p.halo_offset
	ok(p.halo_reach > 0.0 and p.halo_falloff > 0.0 and off.x > 0.0 and off.y > 0.0
			and off.length() < p.halo_reach,
		"%s — casts the scene's directional shadow, down-right (%.2fpx in a %.1fpx reach)"
			% [label, off.x, p.halo_reach])
	# a LIT HAIRLINE, in literal px: at every size these buttons ship at (a ~110px almanac chip to a
	# ~160px well) 0.008 W lands between half a pixel and two. A band reaching further reads as volume.
	ok(p.bevel_px >= 0.4 and p.bevel_px <= 2.5 and p.bevel_strength > 0.0,
		"%s — paper thickness is a lit hairline (%.2fpx)" % [label, p.bevel_px])
	ok(is_equal_approx(p.flare, 0.0),
		"%s — does NOT taper: the tab's flare is screen-edge geometry, not material" % label)
	# the glyph's own pool. The kit default drops three copies of the icon straight DOWN at the icon's own
	# size, so there is no lateral shadow at all and the glyph reads as a sticker laid flat. The material's
	# stack GROWS every copy, so the widest shadow copy is measurably wider than the glyph itself — and
	# there are many of them, because a sparse stack bands. Measured on the built nodes, not on the opts.
	var rects: Array = btn.find_children("*", "TextureRect", true, false)
	var glyph_w := 0.0
	var shadow_w: Array = []
	for tr in rects:
		var t: TextureRect = tr
		if t.modulate.a >= 1.0:
			glyph_w = maxf(glyph_w, t.size.x)
		else:
			shadow_w.append(t.size.x)
	shadow_w.sort()
	# the copies must be spaced about a PIXEL apart — that is the whole reason this stack is generated
	# rather than hand-authored, and the count alone does not say it (a small chip legitimately carries
	# fewer copies than a well, because its pool is shorter). Each step grows the copy by twice the
	# per-side spacing, so a ~1px step shows up here as a ~2px width step. Literal bound, per rule 12.
	var worst := 0.0
	for i in range(1, shadow_w.size()):
		worst = maxf(worst, float(shadow_w[i]) - float(shadow_w[i - 1]))
	ok(glyph_w > 0.0 and shadow_w.size() >= 4 and float(shadow_w[-1]) > glyph_w * 1.02 and worst <= 2.6,
		"%s — its glyph sits in a soft POOL, not flat on the paper (%d copies to %.1f vs %.1f, step %.2f)"
			% [label, shadow_w.size(), float(shadow_w[-1]) if shadow_w.size() else 0.0, glyph_w, worst])

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

# ONE HALF of a board gesture: a real InputEventScreenTouch (the device event, not the mouse twin)
# through the board's own input surface, addressed by MODEL CELL — the touch lands at that cell's
# centre. _tap_board sends both halves at once; this one lets a test hold the finger down across
# frames, which is the only way to observe what the board does DURING a live press.
func _board_touch(h, cell: Vector2i, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = pressed
	ev.position = h._cell_pos(cell) + Vector2(h.csz, h.csz) / 2.0
	h._on_board_input(ev)

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

# The cell a weather-hour board powers (Sunbeam/Rain lane center), or (-1,-1) when the hour has none.
func _call_sky_icon_cell(board_scene) -> Vector2i:
	if not board_scene.has_method("_sky_icon_cell"):
		return Vector2i(-1, -1)
	return board_scene.call("_sky_icon_cell")

# …the same cell made TAPPABLE-as-sky: opened if sealed and emptied of its item, so a tap selects the
# weather rather than a tile. Returns the (possibly re-derived) powered cell. Shared by the sky suite and
# the selection-kind sweep in the improvements suite.
func _prepare_weather_focus_cell(board_scene) -> Vector2i:
	var cell := _call_sky_icon_cell(board_scene)
	if cell.x < 0:
		return cell
	if not board_scene.board.is_open(cell):
		board_scene.board.terrain[BoardModel.idx(cell)] = 0
	if not board_scene.board.is_gen(cell):
		board_scene.board.place(cell, 0)
		board_scene._rebuild_all()
		cell = _call_sky_icon_cell(board_scene)
	return cell

# The grove suites' own user:// save-dir tree — kept distinct from the engine suites'
# so the parallel runner can never let two suites clobber each other's saves.
func save_prefix() -> String:
	return "tu_test_grove_"

# Fully unlock cover-up scene `z` in the save (grants its ONE habitat cell — capacity is one cell
# per completed scene). The shared way suites open the resident bucket.
func complete_scene(z: int) -> void:
	var g := Save.grove()
	var unl: Dictionary = g.get("unlocks", {})
	for c in G.clusters(z):
		unl[String((c as Dictionary).id)] = true
	g["unlocks"] = unl
	Save.grove_write()


func begin(title: String) -> void:
	Engine.time_scale = TIME_SCALE
	print("== %s ==" % title)

func finish() -> void:
	# Subtests that instantiate the Map/Board scenes prewarm the OTHER scene off-thread; we never
	# navigate, so flush those loads (else they leak / crash WorkerThreadPool teardown at exit —
	# see scene_warm.gd::drain). Harmless when nothing was prewarmed.
	SceneWarm._clear()
	super()


# ── §1 · the RESIDENTS population sub-game (own fn = its own scope) ────────────────────────
# Replaces the removed §8 home-hub coin-yield keystone. A populated map opens its resident roster:
# welcome (buy) a t1 with coins, and two-of-a-kind AUTO-MERGE one tier up, cascading to
# RESIDENT_MAX_TIER. No roster cap (the endless coin sink). Merge + cost math is content.gd; storage is Save.

# §1 · the per-map UNLOCK reward (scaling coins/gems + a free signature spirit), the free-spirit grant,
# and the one-time claim. Pure-model coverage routed into the ACTIVE shop+ads suite.
func _test_unlock_rewards() -> void:
	fresh("unlock_reward_scale")
	for z in G.MAPS.size():
		var rew: Dictionary = G.map_unlock_reward(z)
		ok(int(rew.coins) == 120 + 80 * z, "map %d unlock grants %d coins (120 + 80*%d)" % [z, 120 + 80 * z, z])
		ok(int(rew.gems) == 2 + z, "map %d unlock grants %d diamonds (2 + %d)" % [z, 2 + z, z])
		var ln: Dictionary = G.RESIDENT_LINES.get(String(G.MAPS[z].id), {})
		var want := String(ln.get("id", ""))
		ok(String(rew.spirit) == want, "map %d unlock's free spirit is its resident line (%s)" % [z, want])

	# grant_resident adds a t1 WITHOUT spending, and still cascades merges.
	fresh("grant_resident_free")
	var z0 := 0
	var mid := String(G.MAPS[z0].id)
	var gid := String(G.resident_lines(z0)[0].id)
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

	# claim_completion_spirit pays the map's signature spirit kind ONCE, at completion. (The separate
	# one-time unlock GIFT — claim_unlock_reward — was retired with the map title plank that was its
	# only trigger; it had been unreachable in play, granting only ever in this test.)
	fresh("claim_completion_spirit_once")
	var cz := 0                                       # the one surviving map (farmhouse; signature "ember")
	ok(G.claim_completion_spirit(cz) == "ember", "the completion claim pays the map's signature spirit kind")
	ok(G.claim_completion_spirit(cz) == "", "the completion spirit pays exactly once")

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

# Every Button.text under `node` (depth-first). Button text is NOT a child Label, so a walk over Labels
# misses it — use this to assert a widget's button/chip labels (e.g. a read-only amount chip) without pressing.
func _button_texts(node: Node) -> Array:
	var out: Array = []
	if node is Button:
		out.append((node as Button).text)
	for c in node.get_children():
		out.append_array(_button_texts(c))
	return out

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

