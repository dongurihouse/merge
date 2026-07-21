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
	finish()

## The deckle amplitude the shared CutPaperPanel was configured with (-1 if the button has no deckle
## surface). This is the edge knob the workbench "Deckle Amp" slider drives.
func _deckle_amp_of(btn: Button) -> float:
	for c in btn.get_children():
		if String(c.name) == "ButtonDeckleSurface":
			return float((c as Control).deckle_amp)
	return -1.0

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
