extends "res://games/grove/tests/grove_test_base.gd"
## grove · ui workbench — a LIVE (unsaved) cut-paper edge edit must preview on EVERY shared button at
## once, not only the one tile that is fed the live params directly. The mail/shop cards, the reward
## chips, and the borderless paper-role buttons all build their edge from Kit.load_config(CONFIG_PATH)
## (no explicit `cp` passed), so before the fix an edge change only reached them after Save. _apply_edit
## now syncs the live params into Kit's config cache, so the whole button family reflects the edit now.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const UIWorkbenchView = preload("res://games/grove/tools/ui_workbench_view.gd")

func _initialize() -> void:
	begin("grove · ui workbench")
	_live_cutpaper_edit_reaches_shared_buttons()
	_live_corner_edit_reaches_shared_buttons()
	_live_rim_color_edit_reaches_shared_buttons()
	_white_role_builds_with_white_tile()
	await _mail_claim_corner_follows_button_group()
	finish()

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
