extends "res://games/grove/tests/grove_test_base.gd"
## grove · ui workbench — a LIVE (unsaved) cut-paper edge edit must preview on EVERY shared button at
## once, not only the one tile that is fed the live params directly. The mail/shop cards, the reward
## chips, and the borderless paper-role buttons all build their edge from Kit.load_config(CONFIG_PATH)
## (no explicit `cp` passed), so before the fix an edge change only reached them after Save. _apply_edit
## now syncs the live params into Kit's config cache, so the whole button family reflects the edit now.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const UIWorkbenchView = preload("res://games/grove/tools/ui_workbench_view.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const GiverStand = preload("res://engine/scripts/ui/giver_stand.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")

func _initialize() -> void:
	begin("grove · ui workbench")
	_live_cutpaper_edit_reaches_shared_buttons()
	_live_corner_edit_reaches_shared_buttons()
	_live_rim_color_edit_reaches_shared_buttons()
	_white_role_builds_with_white_tile()
	_shared_frame_uses_soft_cream_tile()
	_daily_card_face_tones()
	_daily_card_uses_face_only_for_daily()
	_mail_claim_all_footer_is_transparent()
	await _mail_claim_corner_follows_button_group()
	_slot_cell_gallery_uses_game_cells()
	_slot_content_shadow_can_be_tuned()
	_quest_check_scale_flows_to_giver_card()
	finish()

## The shared daily card FACE (Kit.daily_card_face) — the code-drawn cut-paper card BOTH the workbench daily
## grid and the real login dialog draw: cream days, a gold-under-cream DOUBLE layer for today, a single gold
## layer for day 7.
func _daily_card_face_tones() -> void:
	var cream := Kit.daily_card_face(Vector2(120, 170), "cream")
	var cl := _cp_layers(cream)
	ok(cl.size() == 1 and (cl[0].paper_color as Color).is_equal_approx(Kit.DAILY_CREAM_FILL),
		"a cream day is ONE cut-paper layer, cream fill")
	cream.free()

	var gold := Kit.daily_card_face(Vector2(120, 170), "gold")
	var gl := _cp_layers(gold)
	ok(gl.size() == 1 and (gl[0].paper_color as Color).is_equal_approx(Kit.DAILY_GOLD_FILL),
		"day 7 is ONE cut-paper layer, gold fill")
	gold.free()

	var today := Kit.daily_card_face(Vector2(120, 170), "today")
	var tl := _cp_layers(today)   # gold BELOW (index 0), cream ON TOP (index 1)
	var double := tl.size() == 2
	ok(double, "today is a DOUBLE layer (gold under cream)")
	ok(double and (tl[0].paper_color as Color).is_equal_approx(Kit.DAILY_GOLD_FILL),
		"today's under-layer is gold")
	ok(double and (tl[1].paper_color as Color).is_equal_approx(Kit.DAILY_CREAM_FILL),
		"today's top layer is cream")
	ok(double and bool(tl[0].draw_shadow) and not bool(tl[1].draw_shadow),
		"the gold under-layer casts the shadow; the cream top layer does not (no double shadow)")
	today.size = Vector2(120, 170)
	var gold_rect: Rect2 = (tl[0] as Control).get_rect()
	var cream_rect: Rect2 = (tl[1] as Control).get_rect()
	ok(double and gold_rect.get_center().distance_to(cream_rect.get_center()) <= 0.5,
		"today's gold under-layer is centered behind the cream layer")
	today.free()

## The cut-paper face drives the DAILY grid, but the SHOP grid (the other daily_card caller) is unchanged —
## it keeps its nine-patch card and draws no cut-paper face.
func _daily_card_uses_face_only_for_daily() -> void:
	Kit.clear_config_cache()
	var card := Kit.daily_card({"state": "today", "reward": {"coins": 100}, "day": 2, "label": "Day 2"},
		{"cell_w": 120.0, "cell_h": 170.0, "cut_paper": true})
	ok(_find_named(card, "DailyCardFace") != null,
		"a daily card (cut_paper on) renders the shared cut-paper face")
	var shop := Kit.daily_card({"icon": "coin", "count": 5, "price": "$1"},
		{"cell_w": 120.0, "cell_h": 170.0})
	ok(_find_named(shop, "DailyCardFace") == null,
		"a shop card (cut_paper off) draws NO cut-paper face — unchanged")
	card.free()
	shop.free()
	Kit.clear_config_cache()

## The CutPaperPanel layers of a daily face, in child order.
func _cp_layers(face: Control) -> Array:
	var out: Array = []
	for c in face.get_children():
		if c is Control and "paper_color" in c:
			out.append(c)
	return out

func _find_named(n: Node, nm: String) -> Node:
	if String(n.name) == nm:
		return n
	for c in n.get_children():
		var r := _find_named(c, nm)
		if r != null:
			return r
	return null

func _has_named(n: Node, nm: String) -> bool:
	return _find_named(n, nm) != null

func _slot_cell_gallery_uses_game_cells() -> void:
	Kit.clear_config_cache()
	var view := UIWorkbenchView.new()
	var gallery := view._slot_cell_gallery(view._params["bag_card"])
	ok(_has_named(gallery, "TornCellOuter"),
		"Slot-cell workbench gallery uses the same torn-cell component as the game")
	ok(not _has_named(gallery, "SlotCellBackground"),
		"Slot-cell workbench gallery no longer previews the retired flat well background")
	ok(_has_named(gallery, "SlotContentShadow"),
		"Slot-cell filled previews render with the shared content shadow")
	gallery.free()
	view.free()
	Kit.clear_config_cache()

func _slot_content_shadow_can_be_tuned() -> void:
	var opts := Kit.shared_torn_slot_opts_from_config({"bag_card": {"content_shadow": false}, "torn_cell": {}})
	opts["cell_w"] = 120.0
	opts["cell_h"] = 120.0
	var cell := Kit.slot_cell({"state": "filled", "make_content": func(px: float) -> Control:
		return PieceView.make_piece(102, px, 0.0)}, opts)
	ok(not _has_named(cell, "ContactShadow"),
		"Slot-cell content shadow can be disabled from the Slot cell workbench setting")
	cell.free()

	var cfg := {
		"shadow": {"offset_x": 4.0, "offset_y": 9.0, "blur": 11.0, "spread": -3.0, "alpha": 42.0},
		"bag_card": {"content_shadow": true},
		"torn_cell": {},
	}
	var shared_opts := Kit.shared_torn_slot_opts_from_config(cfg)
	shared_opts["cell_w"] = 120.0
	shared_opts["cell_h"] = 120.0
	var shared_cell := Kit.slot_cell({"state": "filled", "make_content": func(px: float) -> Control:
		return PieceView.make_piece(102, px, 0.0)}, shared_opts)
	var content_shadow := _find_named(shared_cell, "SlotContentShadow") as Panel
	var style := content_shadow.get_theme_stylebox("panel") as StyleBoxFlat if content_shadow != null else null
	ok(content_shadow != null and style != null and absf(style.shadow_color.a - float(Look.shadow_params(cfg).alpha)) <= 0.01,
		"Slot-cell content shadow uses the standard shared Shadow settings")
	ok(not _has_named(shared_cell, "ContactShadow"),
		"Slot-cell content shadow replaces the piece-specific ContactShadow")
	shared_cell.free()

func _quest_check_scale_flows_to_giver_card() -> void:
	var lay := Kit.giver_lay_from_config({"quest_card": {"item_size": 60, "check_scale": 120}})
	var demo_q := {"line": 1, "tier": 3, "reward": {"stars": 25}}
	var noop2 := func(_a: Variant, _b: Variant) -> void: pass
	var made := GiverStand.make(1, demo_q, {
		"ask_tap": noop2, "stand_tap": noop2,
		"wire_tap": func(_node: Control, _action: Callable) -> void: pass,
		"stand_w": 480.0, "fence_h": 410.0, "lay": lay,
	})
	var met: Control = (made.item as Dictionary).get("met")
	var expected := 410.0 * float(lay.card_h) * float(lay.item_h) * 1.20
	ok(met != null and absf(met.size.x - expected) <= 1.0,
		"Quest-card check mark size follows the saved check_scale knob")
	(made.chip as Control).free()

func _mail_claim_all_footer_is_transparent() -> void:
	var dialog := Kit.mail_dialog(
		[{"icon": "gift", "title": "A little something", "body": "Enjoy!", "reward": {"coins": 100}}],
		560.0,
		{"claim_all_text": "Claim All", "on_claim_all": func() -> void: pass})
	var footer := _find_named(dialog, "DialogFooterBand") as PanelContainer
	var sb := footer.get_theme_stylebox("panel") as StyleBoxFlat if footer != null else null
	ok(sb != null and sb.bg_color.a <= 0.01,
		"mail Claim All footer does not draw a white/cream background band")
	var claim_all := _find_button_by_text(dialog, "Claim All")
	ok(claim_all != null and claim_all.icon == null,
		"mail Claim All has no leading mail icon")
	dialog.free()

## The mail Claim button is the shared button's green variant — its cut-paper corner must FOLLOW the
## shared Button corner knob, not a dead hardcoded pin. Regression for: card_claim_corner (never set by
## anything) forced the claim corner to 20, so a Button-group Corner edit never reached the mail Claim.
func _mail_claim_corner_follows_button_group() -> void:
	Kit.clear_config_cache()
	var view := UIWorkbenchView.new()
	get_root().add_child(view)          # in-tree so the gallery/dialog builds
	await process_frame   # let the @tool _build() populate _sections
	view._selected = "button"
	view._params["button"]["deckle"] = true
	view._params["button"]["corner"] = 41.0   # distinctive shared corner
	view._apply_edit()
	view._rebuild_element("dialog")     # the Mail dialog preview (a Button dependent)
	await process_frame
	var dlg: Node = view._sections.get("dialog")
	var claim: Button = _find_button_by_text(dlg, "Claim") if dlg != null else null
	var d: Control = _deckle_of(claim) if claim != null else null
	ok(d != null and is_equal_approx(float(d.corner), 41.0),
		"the mail Claim corner follows the shared Button corner (41, not the old hardcoded 20)")
	view.free()
	Kit.clear_config_cache()

func _find_button_by_text(n: Node, text: String) -> Button:
	if n is Button and String((n as Button).text) == text:
		return n as Button
	for c in n.get_children():
		var r := _find_button_by_text(c, text)
		if r != null:
			return r
	return null

## The shared CutPaperPanel behind a deckled button (null if the button has no deckle surface).
func _deckle_of(btn: Button) -> Control:
	for c in btn.get_children():
		if String(c.name) == "ButtonDeckleSurface":
			return c as Control
	return null

## The deckle amplitude the shared CutPaperPanel was configured with (-1 if no deckle surface).
func _deckle_amp_of(btn: Button) -> float:
	var d := _deckle_of(btn)
	return float(d.deckle_amp) if d != null else -1.0

func _live_cutpaper_edit_reaches_shared_buttons() -> void:
	Kit.clear_config_cache()   # start from the saved-on-disk config (button deckle_amp == 5)
	var view := UIWorkbenchView.new()   # _init() populates _params from the built-in defaults
	view._selected = "button"
	# a distinctive amplitude that can't be mistaken for the saved default (5) or the schema fallback
	view._params["button"]["deckle"] = true
	view._params["button"]["deckle_amp"] = 17.0
	view._apply_edit()                  # the live-edit path: must publish _params so shared readers see it

	# a borderless CREAM paper button with NO explicit `cp` — the exact construction the mail reward chip,
	# the shop cards, and the paper-role buttons use; it resolves its edge from Kit.load_config.
	var b := Kit.pill_button("Claim", {"bg": "cream", "paper": "cream", "border": 0.0})
	ok(is_equal_approx(_deckle_amp_of(b), 17.0),
		"a live cut-paper edit previews on a shared cream button (deckle amp 17, not the saved 5)")

	# the mail Claim / Claim-All footer build their edge via button_opts_from_config(load_config(...)) —
	# same cache, so the green Claim reflects the live edit too.
	var claim_cp: Dictionary = Kit.button_opts_from_config(Kit.load_config(Kit.CONFIG_PATH)).get("cp", {})
	ok(is_equal_approx(float(claim_cp.get("deckle_amp", -1.0)), 17.0),
		"the mail Claim path (button_opts_from_config) reads the live edge too (deckle amp 17)")

	b.free()
	view.free()
	Kit.clear_config_cache()   # don't leak the preview config into sibling suites

## Corner is part of the SHARED edge set now: a live Corner edit must reach a no-`cp` shared button, not
## only the live green tile (before the fix `corner` was test-only and defaulted to a hardcoded 16).
func _live_corner_edit_reaches_shared_buttons() -> void:
	Kit.clear_config_cache()
	var view := UIWorkbenchView.new()
	view._selected = "button"
	view._params["button"]["deckle"] = true
	view._params["button"]["corner"] = 41.0   # distinctive, not the saved default (16)
	view._apply_edit()
	var b := Kit.pill_button("Buy", {"bg": "cream", "paper": "cream", "border": 0.0})
	var d := _deckle_of(b)
	ok(d != null and is_equal_approx(float(d.corner), 41.0),
		"a live Corner edit previews on a shared cream button (corner 41, not the hardcoded 16)")
	b.free()
	view.free()
	Kit.clear_config_cache()

## The new Rim color picker (shared cut-paper knob) must reach the CutPaperPanel.rim_color of a shared
## button — a button that computes no rim of its own.
func _live_rim_color_edit_reaches_shared_buttons() -> void:
	Kit.clear_config_cache()
	var view := UIWorkbenchView.new()
	view._selected = "button"
	view._params["button"]["deckle"] = true
	view._params["button"]["rim_color"] = "FF0000"   # unmistakable red rim
	view._apply_edit()
	var b := Kit.pill_button("Buy", {"bg": "cream", "paper": "cream", "border": 0.0})
	var d := _deckle_of(b)
	ok(d != null and (d.rim_color as Color).is_equal_approx(Color("#FF0000")),
		"a live Rim color edit previews on a shared cream button (rim goes red)")
	b.free()
	view.free()
	Kit.clear_config_cache()

## The new white paper role builds a deckle surface fed the WHITE fibre tile (not the shared cream tile),
## so a white fill reads white instead of cream.
func _white_role_builds_with_white_tile() -> void:
	Kit.clear_config_cache()
	var white_tile := load(Kit.CUT_PAPER_TILE_WHITE)
	ok(ResourceLoader.exists(Kit.CUT_PAPER_TILE_WHITE) and white_tile != null,
		"the white paper tile asset exists and loads")
	var b := Kit.pill_button("White", {"bg": "cream", "paper": "white", "border": 0.0})
	var d := _deckle_of(b)
	ok(d != null and (d.paper_tex as Texture2D) == white_tile,
		"the white role's deckle surface uses the white fibre tile, not the cream one")
	ok(d != null and (d.paper_color as Color).r > 0.95 and (d.paper_color as Color).g > 0.95 and (d.paper_color as Color).b > 0.95,
		"the white role fills near-white")
	b.free()
	Kit.clear_config_cache()

## The shared dialog frame's deckled sheet uses a soft cream fibre between white and the old yellow cream.
func _shared_frame_uses_soft_cream_tile() -> void:
	Kit.clear_config_cache()
	var soft_path := Kit.CUT_PAPER_TILE_SOFT_CREAM
	var soft_tile: Texture2D = load(soft_path) as Texture2D if ResourceLoader.exists(soft_path) else null
	ok(Kit.cut_paper_tile() == soft_tile,
		"the shared cut-paper tile helper resolves to the soft cream frame background")
	var body := Label.new()
	body.text = "Body"
	var opts := Kit.dialog_opts_from_config({"frame": {"deckle": true}})
	var dialog := Kit.dialog_frame(body, 420.0, opts)
	var sheet := _find_named(dialog, "CutPaperSheet")
	ok(soft_tile != null, "the soft cream frame paper tile exists")
	ok(sheet != null and (sheet.paper_tex as Texture2D) == soft_tile,
		"the shared frame deckle uses the soft cream paper tile")
	var fill: Color = sheet.paper_color if sheet != null else Color.BLACK
	ok(fill.r > 0.96 and fill.g > 0.93 and fill.b > 0.90 and fill != Color("#FBFBFB"),
		"the shared frame fill is between white and the old yellow cream")
	dialog.free()
	Kit.clear_config_cache()
