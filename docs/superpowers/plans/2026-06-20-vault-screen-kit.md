# Vault (piggy bank) screen on the shared kit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the in-game Vault (piggy bank) face on the shared workbench kit + saved config, add a reusable "border" option to the shared frame (parchment / vault twig), and slice the twig border + jar + plate from `vault_asset.png`.

**Architecture:** The shared `dialog_frame` gains a `border` opt resolved from a `FRAME_BORDERS` registry (default parchment → existing dialogs byte-identical). A new `vault_dialog` + `vault_opts_from_config` build the vault face (gem read + jar-on-plate + reused green CTA) inside that frame. The game `ui/vault.gd` is rebuilt to construct its face from the kit (preserving the vault math + IAP `_confirm_crack`), and a workbench "Vault" item makes it tunable.

**Tech Stack:** Godot 4.6 GDScript; headless SceneTree tests; the asset-intake pipeline (`make intake`, `slice_islands.gd`).

**Spec:** [`../specs/2026-06-20-vault-screen-kit-design.md`](../specs/2026-06-20-vault-screen-kit-design.md). Backlog (preserved systems): [`../../BACKLOG.md`](../../BACKLOG.md) "Vault (piggy bank) — preserved systems".

**Conventions:** Run `make test-fast` after each engine change. Run the vault kit guard directly:
`godot --headless --path . -s res://engine/tests/vault_kit_tests.gd`. Never open a visible window.

---

### Task 1: Slice the twig border + jar + plate from `vault_asset.png`

**Files:**
- Create: `games/grove/assets/_new/vault_asset.png` (copy of the original, the intake source)
- Create: `games/grove/assets/_new/vault.plan.json`
- Output (by intake): `games/grove/assets/ui/kit/vault_panel.png`, `ui/kit/vault_jar.png`, `ui/kit/vault_plate.png`

- [ ] **Step 1: Stage the raw into `_new/`**

```bash
cp games/grove/assets/_originals/ui/vault_asset.png games/grove/assets/_new/vault_asset.png
```

- [ ] **Step 2: Peek the islands to map index → piece**

Run: `godot --headless --path . -s res://games/tools/slice_islands.gd -- games/grove/assets/_new/vault_asset.png --key '#03CBFE' --tol 0.22 --min-area 3000 --peek /tmp/vault_peek`
Expected: prints `n -> x,y wxh (px=count)` rows. Open `/tmp/vault_peek/cell_<n>.png` and note which index is the **twig-border parchment frame**, the **jar**, and the **oval base plate** (ignore the banner / green button / ✕ / icons — reused from the existing kit).

- [ ] **Step 3: Write `vault.plan.json`** (fill the three island indices from Step 2)

```json
{
  "source": "_new/vault_asset.png",
  "category": "sheet",
  "inner": "sheet",
  "params": { "key": "#03CBFE", "tol": 0.22, "min_area": 3000, "pad": 4 },
  "outputs": [
    { "island": 0, "name": "vault_panel", "path": "ui/kit/vault_panel.png" },
    { "island": 6, "name": "vault_jar",   "path": "ui/kit/vault_jar.png" },
    { "island": 10, "name": "vault_plate", "path": "ui/kit/vault_plate.png" }
  ],
  "archive": "_originals/ui/vault_asset.png"
}
```

- [ ] **Step 4: Apply the intake**

Run: `make intake PLAN=games/grove/assets/_new/vault.plan.json`
Expected: writes the three PNGs under `games/grove/assets/ui/kit/`, archives the raw, prints per-output sizes.

- [ ] **Step 5: Verify the three sprites loaded cleanly**

Run: `godot --headless --path . --quit-after 2 2>&1 | grep -iE "vault_(panel|jar|plate)|error" || echo "imported clean"`
Then confirm files exist: `ls games/grove/assets/ui/kit/vault_panel.png games/grove/assets/ui/kit/vault_jar.png games/grove/assets/ui/kit/vault_plate.png`
Expected: all three exist; no import errors. Open each in the Read tool to confirm the border is the twig frame, the jar is the gem jar, and the plate is the oval base.

- [ ] **Step 6: Commit**

```bash
git add games/grove/assets/_new/vault.plan.json games/grove/assets/_new/_processed/ games/grove/assets/ui/kit/vault_panel.png* games/grove/assets/ui/kit/vault_jar.png* games/grove/assets/ui/kit/vault_plate.png* games/grove/assets/_originals/ui/vault_asset.png
git commit -m "Vault intake: slice twig border + jar + base plate from vault_asset.png"
```

---

### Task 2: Shared frame — the reusable `border` option

**Files:**
- Modify: `games/grove/tools/ui_workbench_kit.gd` (add `FRAME_BORDERS` + `frame_border()` before `dialog_frame`; resolve `border` inside `dialog_frame`)
- Test: `engine/tests/vault_kit_tests.gd` (new — created here, extended in Task 3)

- [ ] **Step 1: Write the failing test** — create `engine/tests/vault_kit_tests.gd`

```gdscript
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

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
```

- [ ] **Step 2: Run it — verify it fails**

Run: `godot --headless --path . -s res://engine/tests/vault_kit_tests.gd`
Expected: FAIL — `FRAME_BORDERS` / `frame_border` not defined on the kit.

- [ ] **Step 3: Add the registry** — in `ui_workbench_kit.gd`, immediately above `static func dialog_frame` (~line 1033):

```gdscript
## The shared frame's selectable BORDER art — a reusable registry so a dialog (or the Frame item's
## Border picker) dresses the SAME frame mechanics in a different border. Each entry carries the
## nine-patch art + its natural slice + content padding. dialog_frame resolves the chosen name into
## panel_art / slice / pad DEFAULTS; explicit panel_art / card_slice_* / panel_pad_* opts still win,
## so every existing caller (mail/daily/shop/settings on parchment; tiers on its own art) is unchanged.
const FRAME_BORDERS := {
	"parchment":  {"art": "kit/panel_parchment_v2.png", "slice": 48.0, "pad_x": 26.0, "pad_y": 24.0},
	"vault twig": {"art": "kit/vault_panel.png",        "slice": 64.0, "pad_x": 40.0, "pad_y": 34.0},
}

## Resolve a border NAME to its {art, slice, pad_x, pad_y} record (unknown → parchment, so a stale
## saved value never blanks the frame).
static func frame_border(name: String) -> Dictionary:
	return FRAME_BORDERS.get(name, FRAME_BORDERS["parchment"])
```

- [ ] **Step 4: Resolve `border` inside `dialog_frame`** — replace the slice + chrome-art default reads. Change lines `var sl_l … sl_b` (~1043-1046) and `var panel_art … panel_pad_y` (~1060-1062) so the border supplies defaults. Insert a `border` lookup at the TOP of the opts reads (right after `var on_close`/`banner_text`, before `var panel_art`), then point the slice + pad + art defaults at it:

```gdscript
	# the BORDER option supplies panel_art / slice / pad DEFAULTS (explicit opts still override).
	var border: Dictionary = frame_border(String(opts.get("border", "parchment")))
	var sl_l: float = float(opts.get("card_slice_l", border["slice"]))
	var sl_t: float = float(opts.get("card_slice_t", border["slice"]))
	var sl_r: float = float(opts.get("card_slice_r", border["slice"]))
	var sl_b: float = float(opts.get("card_slice_b", border["slice"]))
	...
	var panel_art: String = String(opts.get("panel_art", border["art"]))
	var panel_pad_x: float = float(opts.get("panel_pad_x", border["pad_x"]))
	var panel_pad_y: float = float(opts.get("panel_pad_y", border["pad_y"]))
```

(Delete the now-duplicated old `sl_l..sl_b` / `panel_art` / `panel_pad_*` declarations — each name must be declared once. Keep `card_h_stretch`/`card_v_stretch`/`banner_art`/`close_art` as they are.)

- [ ] **Step 5: Extend the test with the frame regression guard** — add before the final print in `vault_kit_tests.gd`:

```gdscript
	# --- dialog_frame default border = parchment; "vault twig" swaps the art -------
	var c1 := Control.new()
	var par := Kit.dialog_frame(c1, 540.0, {"card_art": true, "banner_text": "X"})
	var par_panel := _panel_tex_path(par)
	ok(par_panel.ends_with("panel_parchment_v2.png"), "default border keeps the parchment panel (regression)")
	var c2 := Control.new()
	var twig := Kit.dialog_frame(c2, 540.0, {"card_art": true, "border": "vault twig", "banner_text": "X"})
	ok(_panel_tex_path(twig).ends_with("vault_panel.png"), "border 'vault twig' swaps the panel to the twig art")
```

And add this helper above `_initialize`:

```gdscript
## The panel StyleBoxTexture's texture path on a built dialog's card (the first PanelContainer that has a
## StyleBoxTexture "panel" override) — so the test can assert which border art the frame is wearing.
func _panel_tex_path(dialog: Node) -> String:
	for p in dialog.find_children("", "PanelContainer", true, false):
		var sb := (p as PanelContainer).get_theme_stylebox("panel")
		if sb is StyleBoxTexture and (sb as StyleBoxTexture).texture != null:
			return (sb as StyleBoxTexture).texture.resource_path
	return ""
```

- [ ] **Step 6: Run the guard — verify it passes**

Run: `godot --headless --path . -s res://engine/tests/vault_kit_tests.gd`
Expected: PASS for the border registry + frame regression rows.

- [ ] **Step 7: Regression — other dialogs still build on parchment**

Run: `make test-grove` (grove_ui suite exercises the dialogs) — Expected: no new failures.

- [ ] **Step 8: Commit**

```bash
git add games/grove/tools/ui_workbench_kit.gd engine/tests/vault_kit_tests.gd
git commit -m "Frame: add reusable border option (parchment / vault twig) to dialog_frame"
```

---

### Task 3: `vault_dialog` + `vault_opts_from_config` in the kit

**Files:**
- Modify: `games/grove/tools/ui_workbench_kit.gd` (add `vault_dialog`, `_vault_jar`, `vault_opts_from_config`; a `DEMO_VAULT` const)
- Test: `engine/tests/vault_kit_tests.gd`

- [ ] **Step 1: Write the failing test** — add before the final print in `vault_kit_tests.gd`:

```gdscript
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
	var green := null                                  # the green price CTA = a Button reading the price
	for b in vd.find_children("", "Button", true, false):
		if (b as Button).text == "$4.99":
			green = b
	ok(green != null, "vault_dialog shows the green price CTA ($4.99)")
	if green != null:
		(green as Button).pressed.emit()
	ok(fired[0] == true, "pressing the CTA fires state.on_claim")

	# claimable=false dims the CTA + shows the keep-playing hint
	var dim := Kit.vault_dialog({"balance": 10, "cap": 500, "price": "$4.99", "claimable": false, "claim_min": 100},
		460.0, {"border": "vault twig"})
	var dim_cta := null
	for b in dim.find_children("", "Button", true, false):
		if (b as Button).text == "$4.99":
			dim_cta = b
	ok(dim_cta != null and (dim_cta as Button).modulate.a < 1.0, "not-claimable dims the CTA")

	# --- vault_opts_from_config: forces the twig border + reads its block ----------
	var vo := Kit.vault_opts_from_config({})
	ok(String(vo.get("border", "")) == "vault twig", "vault_opts forces the twig border")
	ok(vo.has("banner_font") and vo.has("close_size"), "vault_opts inherits the shared frame chrome")
	var vo2 := Kit.vault_opts_from_config({"vault": {"jar_px": 240, "panel_pad_x": 50}})
	ok(float(vo2.get("jar_px", 0)) == 240.0 and float(vo2.get("panel_pad_x", 0)) == 50.0,
		"vault_opts reads saved overrides (jar_px · panel_pad_x)")
```

- [ ] **Step 2: Run it — verify it fails**

Run: `godot --headless --path . -s res://engine/tests/vault_kit_tests.gd`
Expected: FAIL — `vault_dialog` / `vault_opts_from_config` not defined.

- [ ] **Step 3: Add `DEMO_VAULT`** near the other `DEMO_*` consts (~line 92):

```gdscript
# Demo vault state for the workbench preview — same shape the game builds from core/vault.gd.
const DEMO_VAULT := {"balance": 320, "cap": 500, "price": "$4.99", "claimable": true, "claim_min": 100}
```

- [ ] **Step 4: Add `vault_dialog` + `_vault_jar`** — after `settings_dialog` (~line 1176):

```gdscript
## The VAULT (piggy-bank) dialog — the shared frame dressed in the twig border, wrapping the jar hero +
## a gem-balance read + the reused green price CTA. Game-state-agnostic (like settings_dialog): `state`
## carries the numbers + the claim callback, so BOTH the workbench preview and the game (ui/vault.gd)
## build the SAME face. state: { balance:int, cap:int, price:String, claimable:bool, claim_min:int,
## on_claim:Callable }.
static func vault_dialog(state: Dictionary, width: float = 460.0, opts: Dictionary = {}) -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(opts.get("row_gap", 12)))
	content.alignment = BoxContainer.ALIGNMENT_CENTER

	# the gem-balance read (icon + number) — the reference's "gem 320"
	var bal := HBoxContainer.new()
	bal.alignment = BoxContainer.ALIGNMENT_CENTER
	bal.add_theme_constant_override("separation", 8)
	bal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bal.add_child(make_icon("gem", float(opts.get("balance_icon", 34))))
	var bnum := Label.new()
	bnum.text = str(int(state.get("balance", 0)))
	bnum.add_theme_font_size_override("font_size", int(opts.get("balance_font", 34)))
	bnum.add_theme_color_override("font_color", Pal.INK)
	bnum.add_theme_constant_override("outline_size", 0)
	bnum.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bnum.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bal.add_child(bnum)
	content.add_child(bal)

	# the jar on its plate (sliced art when present, else a code-drawn vessel with the same metrics)
	content.add_child(_vault_jar(int(state.get("balance", 0)), int(state.get("cap", 1)),
		float(opts.get("jar_px", 200)), float(opts.get("plate_px", 220))))

	# the pitch line — the longer you play, the better the deal
	var pitch := Label.new()
	pitch.text = String(opts.get("pitch", "Premium you've earned, saved up — claim it all."))
	pitch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pitch.add_theme_font_size_override("font_size", int(opts.get("pitch_font", 16)))
	pitch.add_theme_color_override("font_color", Color(Pal.BARK, 0.95))
	pitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(pitch)

	# the green price CTA — the SHARED pill_button (reused), claimable-gated (dim + a hint below)
	var claimable: bool = bool(state.get("claimable", true))
	var cta := pill_button(String(state.get("price", "")), {"bg": "green", "icon": "gem",
		"font": int(opts.get("cta_font", 24)), "enabled": true, "shadow": true, "corner": 22.0})
	cta.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cta.modulate = Color(1, 1, 1, 1.0 if claimable else 0.55)
	var on_claim: Callable = state.get("on_claim", Callable())
	if on_claim.is_valid():
		cta.pressed.connect(func() -> void: on_claim.call())
	content.add_child(cta)
	if not claimable:
		var hint := HBoxContainer.new()
		hint.alignment = BoxContainer.ALIGNMENT_CENTER
		hint.add_theme_constant_override("separation", 4)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hl := Label.new()
		hl.text = String(opts.get("hint_text", "Keep playing — it fills at"))
		hl.add_theme_font_size_override("font_size", 15)
		hl.add_theme_color_override("font_color", Color(Pal.BARK, 0.8))
		hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.add_child(hl)
		hint.add_child(make_icon("gem", 16))
		var hn := Label.new()
		hn.text = str(int(state.get("claim_min", 0)))
		hn.add_theme_font_size_override("font_size", 15)
		hn.add_theme_color_override("font_color", Color(Pal.BARK, 0.8))
		hn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.add_child(hn)
		content.add_child(hint)

	return dialog_frame(content, width, opts)

## The jar hero seated on its base plate: vault_plate.png behind + vault_jar.png over (cleaned), when
## present; else a code-drawn vessel with a GOLD fill rising to balance/cap — the fallback lifted from
## the old ui/vault.gd `_make_jar`, so the read survives until the art lands (the kit invariant).
static func _vault_jar(balance: int, cap: int, jar_px: float, plate_px: float) -> Control:
	var box := Control.new()
	var box_w: float = maxf(jar_px, plate_px)
	box.custom_minimum_size = Vector2(box_w, jar_px * 1.16)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate_tex := clean_tex_path(Look.kit("kit/vault_plate.png"), 256)
	if plate_tex != null:
		var pl := TextureRect.new()
		pl.texture = plate_tex
		pl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var ph: float = plate_px * 0.42
		pl.custom_minimum_size = Vector2(plate_px, ph)
		pl.size = pl.custom_minimum_size
		pl.position = Vector2((box_w - plate_px) / 2.0, box.custom_minimum_size.y - ph)
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(pl)
	var jar_tex := clean_tex_path(Look.kit("kit/vault_jar.png"), 384)
	if jar_tex != null:
		var jr := TextureRect.new()
		jr.texture = jar_tex
		jr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		jr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		jr.custom_minimum_size = Vector2(jar_px, jar_px)
		jr.size = jr.custom_minimum_size
		jr.position = Vector2((box_w - jar_px) / 2.0, 0)
		jr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(jr)
		return box
	# --- code-drawn fallback (no jar art) — vessel + gold fill, adapted from the old _make_jar -------
	var frac := clampf(float(balance) / float(maxi(1, cap)), 0.0, 1.0)
	var jx := (box_w - jar_px) / 2.0
	var body := Panel.new()
	body.position = Vector2(jx, 0); body.size = Vector2(jar_px, jar_px)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(Pal.CREAM, 0.65)
	bs.set_corner_radius_all(int(jar_px * 0.28))
	bs.set_border_width_all(5); bs.border_color = Pal.BARK
	body.add_theme_stylebox_override("panel", bs)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(body)
	var inset := 8.0
	var fill := Panel.new()
	var fh: float = maxf(6.0, (jar_px - inset * 2.0) * frac)
	fill.position = Vector2(jx + inset, jar_px - inset - fh)
	fill.size = Vector2(jar_px - inset * 2.0, fh)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(Pal.GOLD, 0.92) if frac > 0.0 else Color(Pal.GOLD, 0.0)
	fs.set_corner_radius_all(int(jar_px * 0.22))
	fill.add_theme_stylebox_override("panel", fs)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(fill)
	return box
```

(Note: `Pal.GOLD` is used by the existing `ui/vault.gd`; it exists in the palette. `make_icon` / `clean_tex_path` / `Look.kit` / `pill_button` / `dialog_frame` are all defined earlier in this file.)

- [ ] **Step 5: Add `vault_opts_from_config`** — after `settings_opts_from_config` (~line 1938):

```gdscript
## The full VAULT-dialog opts: the SHARED frame (banner / close styling inherited from the Frame item)
## + the new TWIG border forced on + the vault's own tuned slice / pad / jar size from its config block.
## Used by BOTH the workbench preview and the game (engine/scripts/ui/vault.gd) — one builder, no
## duplicated face.
static func vault_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)
	var v: Dictionary = cfg.get("vault", {})
	o["border"] = "vault twig"                            # the new frame option (forced for the vault)
	var sl: float = float(v.get("card_slice", 64))
	o["card_slice_l"] = sl; o["card_slice_t"] = sl; o["card_slice_r"] = sl; o["card_slice_b"] = sl
	o["panel_pad_x"] = float(v.get("panel_pad_x", 40))
	o["panel_pad_y"] = float(v.get("panel_pad_y", 34))
	o["card_art"] = true
	o["banner_icon_id"] = "piggy"                         # reuse the existing icon_piggy sprite
	o["jar_px"] = float(v.get("jar_px", 200))
	o["plate_px"] = float(v.get("plate_px", 220))
	o["balance_font"] = int(v.get("balance_font", 34))
	o["row_gap"] = float(v.get("row_gap", 12))
	return o
```

- [ ] **Step 6: Run the guard — verify it passes**

Run: `godot --headless --path . -s res://engine/tests/vault_kit_tests.gd`
Expected: PASS all rows (border + vault_dialog + opts).

- [ ] **Step 7: Commit**

```bash
git add games/grove/tools/ui_workbench_kit.gd engine/tests/vault_kit_tests.gd
git commit -m "Kit: add vault_dialog + vault_opts_from_config (jar-on-plate + reused green CTA)"
```

---

### Task 4: Workbench — the Vault item + the Frame Border dropdown

**Files:**
- Modify: `games/grove/tools/ui_workbench_view.gd` (IDS, COLUMNS, CAPTIONS, TEST_KEYS, `_params`; preview branch; sidebar dispatch + `_vault_sidebar`; the Frame Border dropdown)

- [ ] **Step 1: Register the item** — add `"vault"` to `IDS` (line 19) and to the dialogs column in `COLUMNS` (line 26, e.g. after `["settings"]`):

```gdscript
const IDS := [..., "settings", "vault"]
...
	[["dialog"], ["daily"], ["shop"], ["tiers"], ["currency_pill"], ["settings"], ["vault"]],
```

Add to `CAPTIONS`: `"vault": "Vault — piggy bank (twig border)",`
Add to `TEST_KEYS`: `"vault": ["balance", "claimable"],`

- [ ] **Step 2: Add `_params["vault"]`** (near the other dialog params):

```gdscript
	# the VAULT dialog — the shared frame in the NEW twig border + the jar hero. width_pct + the twig
	# slice/pad + the jar/plate sizes are saved; balance/claimable just preview the read. The banner / ✕
	# styling is inherited from the Frame item (like the other dialogs).
	"vault": {"width_pct": 80, "card_slice": 64, "panel_pad_x": 40, "panel_pad_y": 34,
		"jar_px": 200, "plate_px": 220, "balance_font": 34, "row_gap": 12,
		"balance": 320, "claimable": true},
```

- [ ] **Step 3: Add the preview branch** — in the build `match _selected` (after the `"settings"` branch, ~line 361):

```gdscript
		"vault":
			# the SHARED frame in the NEW twig border + the jar hero (the SAME builder ui/vault.gd uses)
			var vopts := Kit.vault_opts_from_config(_params)
			vopts["banner_text"] = "Vault"
			var p_st := Kit.DEMO_VAULT.duplicate()
			p_st["balance"] = int(p.balance)
			p_st["claimable"] = bool(p.claimable)
			return Kit.vault_dialog(p_st, _dlg_px("vault"), vopts)
```

- [ ] **Step 4: Add the sidebar branch + function** — in the sidebar `match _selected` (after `"settings"`), add `"vault": _vault_sidebar()`, then define `_vault_sidebar` next to `_frame_sidebar`:

```gdscript
func _vault_sidebar() -> void:
	_group_header("Saved to config", true)
	_section_header("Layout")
	_sidebar_body.add_child(_slider_row(["width_pct", 40, 100]))   # % of the screen width (responsive)
	_sidebar_body.add_child(_slider_row(["jar_px", 120, 320]))
	_sidebar_body.add_child(_slider_row(["plate_px", 120, 340]))
	_sidebar_body.add_child(_slider_row(["balance_font", 18, 56]))
	_sidebar_body.add_child(_slider_row(["row_gap", 4, 40]))
	_section_header("Border (twig panel)")
	_sidebar_body.add_child(_slider_row(["card_slice", 0, 160]))
	_sidebar_body.add_child(_slider_row(["panel_pad_x", 0, 140]))
	_sidebar_body.add_child(_slider_row(["panel_pad_y", 0, 140]))
	_group_header("Test only — not saved", false)
	_sidebar_body.add_child(_slider_row(["balance", 0, 999]))      # the previewed gem read
	_sidebar_body.add_child(_toggle_row("Claimable", "claimable"))  # toggles the CTA dim + hint
```

- [ ] **Step 5: Add the Frame Border dropdown** — in `_frame_sidebar()` Card section (after the `width` slider, ~line 889), and seed the default in `_params["frame"]`:

```gdscript
	_sidebar_body.add_child(_option_row("Border", "border", Kit.FRAME_BORDERS.keys()))
```
and add `"border": "parchment",` to the `"frame"` `_params` block (so the shared frame defaults to parchment — other dialogs unchanged).

Then make the Frame preview honor it — in the `"frame"` build branch (~line 297) set the border from the param:

```gdscript
				fo["border"] = String(_params["frame"]["border"])
```

- [ ] **Step 6: Verify the workbench loads + the item builds**

Run: `godot --headless --path . -s res://games/grove/tools/ui_workbench.gd --quit-after 3 2>&1 | grep -iE "error|vault" || echo "workbench builds clean"`
(If the tool has no headless self-test entry, instead run `make workbench` briefly is NOT allowed — it opens a window. Rely on the parse check:) `godot --headless --check-only res://games/grove/tools/ui_workbench_view.gd 2>&1 | grep -i error || echo "parses clean"`
Expected: no parse/build errors; the `vault` branch + `_vault_sidebar` resolve.

- [ ] **Step 7: Commit**

```bash
git add games/grove/tools/ui_workbench_view.gd
git commit -m "Workbench: add the Vault item + a Border picker on the shared Frame item"
```

---

### Task 5: Rebuild the in-game `ui/vault.gd` on the kit

**Files:**
- Modify: `engine/scripts/ui/vault.gd` (rebuild `open()` on the kit; keep `_confirm_crack` + IAP; drop `_make_jar`)

- [ ] **Step 1: Rewrite `open()`** — replace the hand-drawn body. Keep the file's header doc (update the "this is only its face" note to say the face is built from the kit), keep the `Vault` / `Store` / IAP consts and `_confirm_crack` verbatim. New `open()`:

```gdscript
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
const WIDTH_PCT_DEF := 80.0

static func open(host: Control, opts: Dictionary = {}) -> void:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("Vault: ui kit missing at %s" % KIT_PATH)
		return
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	host.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(INK, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var vw: float = host.get_viewport_rect().size.x
	var pct: float = float((cfg.get("vault", {}) as Dictionary).get("width_pct", WIDTH_PCT_DEF))
	var width: float = vw * clampf(pct, 30.0, 100.0) / 100.0

	# the vault MATH stays in core/vault.gd; the kit face reads it via this state dict (game-state-agnostic).
	var state := {
		"balance": Vault.balance(),
		"cap": Vault.cap(),
		"price": Vault.price_usd(),
		"claimable": Vault.claimable(),
		"claim_min": Vault.claim_min(),
		"on_claim": func() -> void:
			if not Vault.claimable():
				Audio.play("invalid_soft", -6.0)
				return
			_confirm_crack(host, overlay, opts),
	}
	var vopts: Dictionary = Kit.vault_opts_from_config(cfg)
	vopts["banner_text"] = host.tr("Vault")
	vopts["pitch"] = host.tr("Premium you've earned, saved up — claim it all for %s.") % Vault.price_usd()
	vopts["hint_text"] = host.tr("Keep playing — it fills at")
	vopts["on_close"] = func() -> void:
		if is_instance_valid(overlay): overlay.queue_free()
	var dialog: Control = Kit.vault_dialog(state, width, vopts)
	cc.add_child(dialog)
	FX.pop_in(dialog)
```

Delete `_make_jar` and its sizing consts (`CARD_MAX_W`, `CARD_VW_FRAC`, `JAR_W`, `JAR_H`) — the kit owns the jar now. Keep `_confirm_crack` unchanged.

- [ ] **Step 2: Verify the kit guard + map open path still hold**

Run: `godot --headless --path . -s res://engine/tests/vault_kit_tests.gd` — Expected: PASS.
Run: `godot --headless --check-only res://engine/scripts/ui/vault.gd 2>&1 | grep -i error || echo "parses clean"` — Expected: clean.

- [ ] **Step 3: Smoke — the map opens the vault without error** (quiet; no visible window)

Run: `make test-fast` — Expected: engine suites green (store_tests / save_tests cover the math + IAP path).

- [ ] **Step 4: Commit**

```bash
git add engine/scripts/ui/vault.gd
git commit -m "Vault: rebuild ui/vault.gd face on the shared kit (math + IAP crack preserved)"
```

---

### Task 6: Wire the guard into the suite runner + full sweep

**Files:**
- Modify: `Makefile` (add `vault_kit_tests` to `ENGINE_TESTS_DISABLED`, beside `settings_kit_tests`)

- [ ] **Step 1: Register the suite** — append `engine/tests/vault_kit_tests` to the `ENGINE_TESTS_DISABLED` line (the UI suites are parked during churn — same home as `settings_kit_tests`; run it directly during dev):

```make
ENGINE_TESTS_DISABLED := ... engine/tests/settings_kit_tests engine/tests/vault_kit_tests
```

- [ ] **Step 2: Run the guard via its path one more time**

Run: `godot --headless --path . -s res://engine/tests/vault_kit_tests.gd`
Expected: `== N passed, 0 failed ==`.

- [ ] **Step 3: Full sweep before handoff**

Run: `make test`
Expected: every active suite green (engine + grove); per-suite timing table, no FAIL/crash.

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "Tests: register vault_kit_tests (parked UI suite set)"
```

---

## Self-review notes

- **Spec coverage:** §1 intake → Task 1; §2 frame border → Task 2; §3 vault_dialog/opts → Task 3; §4 workbench item → Task 4; §5 game rebuild → Task 5; §6 tests → Tasks 2/3/6. All covered.
- **Type consistency:** `vault_dialog(state, width, opts)` / `vault_opts_from_config(cfg)` / `frame_border(name)` / `FRAME_BORDERS` / `_vault_jar(balance, cap, jar_px, plate_px)` / `DEMO_VAULT` — names match across tasks and tests.
- **Risk — twig slice/pad:** values (slice 64, pad 40/34) are starting points; the Vault item's sliders + the Frame Border preview let them be tuned against the real sprite before locking into config. If the nine-patch corners pinch, raise `card_slice`; verify at a couple of widths.
- **Risk — jar fill read:** the static jar art is the vessel; the explicit gem-balance number is the authoritative read. The code-drawn fallback keeps the gold-fill read until/unless the art replaces it.
- **Open verify-by-human:** the actual visual (twig border + jar-on-plate composition) needs a quiet capture review once built — not eyeballed from a thumbnail.
