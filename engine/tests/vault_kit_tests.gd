extends SceneTree
## Headless guard for the VAULT kit face + the shared-frame BORDER option. Run:
##   godot --headless --path . -s res://engine/tests/vault_kit_tests.gd
## Proves: FRAME_BORDERS resolves (incl. unknown → parchment); dialog_frame's default border stays
## parchment (mail/daily/shop/settings regression guard) while "vault twig" swaps the panel art; the
## vault_dialog wraps the shared frame around a gem read + jar + green CTA, claimable-gated; and
## vault_opts_from_config forces the twig border + reads its saved block.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

## The panel StyleBoxTexture's texture path on a built dialog's card (the first PanelContainer that has a
## StyleBoxTexture "panel" override) — so the test can assert which border art the frame is wearing.
func _panel_tex_path(dialog: Node) -> String:
	for p in dialog.find_children("", "PanelContainer", true, false):
		var sb := (p as PanelContainer).get_theme_stylebox("panel")
		if sb is StyleBoxTexture and (sb as StyleBoxTexture).texture != null:
			return (sb as StyleBoxTexture).texture.resource_path
	return ""

func _initialize() -> void:
	OS.set_environment("GAME", "grove")
	print("== Vault kit guard ==")

	# --- the border registry ------------------------------------------------------
	ok(Kit.FRAME_BORDERS.has("parchment") and Kit.FRAME_BORDERS.has("vault twig"),
		"FRAME_BORDERS lists parchment + vault twig")
	ok(String(Kit.frame_border("vault twig")["art"]) == "kit/vault_panel.png",
		"frame_border('vault twig') resolves the twig art")
	ok(String(Kit.frame_border("nonsense")["art"]) == String(Kit.FRAME_BORDERS["parchment"]["art"]),
		"frame_border() falls back to parchment for an unknown name")

	# --- dialog_frame default border = parchment; "vault twig" swaps the art -------
	var c1 := Control.new()
	var par := Kit.dialog_frame(c1, 540.0, {"card_art": true, "banner_text": "X"})
	ok(_panel_tex_path(par).ends_with("panel_parchment_v2.png"),
		"default border keeps the parchment panel (regression)")
	var c2 := Control.new()
	var twig := Kit.dialog_frame(c2, 540.0, {"card_art": true, "border": "vault twig", "banner_text": "X"})
	ok(_panel_tex_path(twig).ends_with("vault_panel.png"),
		"border 'vault twig' swaps the panel to the twig art")

	# --- vault_dialog: shared frame + gem read + jar + green CTA, claimable-gated --
	var fired: Array = [false]
	var st := {"balance": 320, "cap": 500, "price": "$4.99", "claimable": true, "claim_min": 100,
		"on_claim": func() -> void: fired[0] = true}
	var vd := Kit.vault_dialog(st, 460.0, {"banner_text": "Vault", "border": "vault twig"})
	ok(vd.find_child("DialogBanner", true, false) != null, "vault_dialog wraps the SHARED frame (banner present)")
	var has_320 := false
	for l in vd.find_children("", "Label", true, false):
		if (l as Label).text == "320":
			has_320 = true
	ok(has_320, "vault_dialog shows the gem balance read (320)")
	var green: Button = null                            # the green price CTA = a Button reading the price
	for b in vd.find_children("", "Button", true, false):
		if (b as Button).text == "$4.99":
			green = b
	ok(green != null, "vault_dialog shows the green price CTA ($4.99)")
	if green != null:
		green.pressed.emit()
	ok(fired[0] == true, "pressing the CTA fires state.on_claim")

	# claimable=false dims the CTA + shows the keep-playing hint
	var dim := Kit.vault_dialog({"balance": 10, "cap": 500, "price": "$4.99", "claimable": false, "claim_min": 100},
		460.0, {"border": "vault twig"})
	var dim_cta: Button = null
	for b in dim.find_children("", "Button", true, false):
		if (b as Button).text == "$4.99":
			dim_cta = b
	ok(dim_cta != null and dim_cta.modulate.a < 1.0, "not-claimable dims the CTA")

	# --- vault_opts_from_config: forces the twig border + reads its block ----------
	var vo := Kit.vault_opts_from_config({})
	ok(String(vo.get("border", "")) == "vault twig", "vault_opts forces the twig border")
	ok(vo.has("banner_font") and vo.has("close_size"), "vault_opts inherits the shared frame chrome")
	var vo2 := Kit.vault_opts_from_config({"vault": {"jar_px": 240, "panel_pad_x": 50}})
	ok(float(vo2.get("jar_px", 0)) == 240.0 and float(vo2.get("panel_pad_x", 0)) == 50.0,
		"vault_opts reads saved overrides (jar_px · panel_pad_x)")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
