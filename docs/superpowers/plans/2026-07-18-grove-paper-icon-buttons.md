# Grove Flat-Paper Currency Pills and Icon Buttons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote the approved flat-paper currency-pill construction into the live HUD and rebuild the common Bag, Home, Map/Back, and side-rail icon buttons from flat paper textures plus code-defined geometry.

**Architecture:** Keep `Kit.gold_currency_pill()` and `Kit.home_button()` as the existing public atoms. Add one internal rounded-paper surface helper to `ui_workbench_kit.gd`; the helper owns code styles, the rounded mask, semantic paper textures, and state tinting. Migrate only consumer option dictionaries for semantic surface roles; preserve all layout and input wiring.

**Tech Stack:** Godot 4.6 GDScript, `StyleBoxFlat`, `TextureRect`, `ShaderMaterial`, existing Grove UI Workbench tests and renderer capture scripts.

## Global Constraints

- Flat paper textures provide material only; silhouette, edge, shadow, and state treatment are code-defined.
- Preserve current sizes, positions, icons, badges, labels, hit targets, callbacks, safe-area behavior, and Workbench sizing controls.
- Text CTAs and the circular Play/Restore control are outside this pass.
- The standalone currency-pill study remains independent.
- Level-badge reconstruction is a follow-up, not part of this plan.

---

### Task 1: Shared rounded-paper surface and live wallet

**Files:**
- Modify: `games/grove/tests/grove_workbench_tests.gd:486-509`
- Modify: `games/grove/tools/ui_workbench_kit.gd:30-90`
- Modify: `games/grove/tools/ui_workbench_kit.gd:1077-1180`

**Interfaces:**
- Consumes: `_meadow_tex(file_name: String) -> Texture2D`, `_meadow_with_shadow(...)`, `Look.add_press_juice(...)`.
- Produces: `_apply_rounded_paper_surface(button: Button, paper_name: String, fill: Color, corner: float, margins: Vector4, inset := 2.0) -> TextureRect` and a child named `PaperSurface`.

- [ ] **Step 1: Replace the live-wallet shell expectation with failing flat-paper assertions**

Update the `gold_currency_pill` section of `grove_workbench_tests.gd` so it requires a `StyleBoxFlat` frame and a `PaperSurface` child:

```gdscript
var gcp_frame := (gcp as Button).get_theme_stylebox("normal") as StyleBoxFlat
var gcp_paper := gcp.find_child("PaperSurface", true, false) as TextureRect
ok(gcp_frame != null
	and gcp_frame.get_corner_radius(CORNER_TOP_LEFT) == 35
	and gcp_frame.get_border_width(SIDE_LEFT) == 1,
	"gold_currency_pill draws its rounded shell and cut edge in code")
ok(gcp_paper != null and gcp_paper.texture != null
	and String(gcp_paper.texture.resource_path).ends_with("ui/meadow_v2/texture_cream.png")
	and gcp_paper.material is ShaderMaterial,
	"gold_currency_pill masks the flat cream paper texture into the code shell")
ok(not _source_contains("res://games/grove/tools/ui_workbench_kit.gd", "meadow_paper_style(\"resource_pill.png\""),
	"live currency pills do not nine-slice the pre-cut resource pill")
```

- [ ] **Step 2: Run the focused test and verify the expected failure**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_workbench_tests
```

Expected: FAIL on the new flat-paper wallet assertions because the live builder still returns `StyleBoxTexture(resource_pill.png)` and has no `PaperSurface` child.

- [ ] **Step 3: Add the rounded-paper mask and state helper**

Add a shared shader constant and helper near the Meadow helpers in `ui_workbench_kit.gd`:

```gdscript
const PAPER_MASK_SHADER := """
shader_type canvas_item;
uniform vec2 control_size = vec2(1.0);
uniform float radius_px = 1.0;
float rounded_box_distance(vec2 point, vec2 half_size, float radius) {
	vec2 q = abs(point) - half_size + vec2(radius);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
}
void fragment() {
	vec4 paper = texture(TEXTURE, UV);
	float d = rounded_box_distance((UV - vec2(0.5)) * control_size, control_size * 0.5, radius_px);
	float mask = 1.0 - smoothstep(-1.0, 1.0, d);
	COLOR = vec4(paper.rgb, paper.a * mask);
}
"""

static func _apply_rounded_paper_surface(
	button: Button, paper_name: String, fill: Color, corner: float,
	margins: Vector4, inset := 2.0
) -> TextureRect:
	var base := StyleBoxFlat.new()
	base.bg_color = fill
	base.border_color = Color("#3F6D7D", 0.35)
	base.set_border_width_all(1)
	base.set_corner_radius_all(int(round(corner)))
	base.anti_aliasing = true
	base.content_margin_left = margins.x
	base.content_margin_top = margins.y
	base.content_margin_right = margins.z
	base.content_margin_bottom = margins.w
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, base)
	var paper := TextureRect.new()
	paper.name = "PaperSurface"
	paper.texture = _meadow_tex(paper_name)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.offset_left = inset; paper.offset_top = inset
	paper.offset_right = -inset; paper.offset_bottom = -inset
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = PAPER_MASK_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("radius_px", maxf(1.0, corner - inset))
	paper.material = material
	button.add_child(paper)
	var sync := func() -> void:
		material.set_shader_parameter("control_size", Vector2(maxf(1.0, paper.size.x), maxf(1.0, paper.size.y)))
	paper.resized.connect(sync)
	paper.ready.connect(sync)
	return paper
```

Add a draw-mode callback to the helper so `paper.self_modulate` is white normally, slightly lightened on hover, `Color(0.90, 0.90, 0.90)` when pressed, and `Color(0.68, 0.68, 0.68)` when disabled.

- [ ] **Step 4: Migrate `gold_currency_pill()` to the helper**

Replace the `resource_pill.png` style construction with:

```gdscript
var corner := pill_h * 0.35
_apply_rounded_paper_surface(
	panel,
	"texture_cream.png",
	Color("#F6EBDD"),
	corner,
	Vector4(pad_left, style_pad_y, pad_x, style_pad_y)
)
```

Keep `row_host`, icon, amount, plus, click action, and optional `_meadow_with_shadow()` wrapper unchanged.

- [ ] **Step 5: Run focused tests and commit the live-wallet slice**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_workbench_tests
git diff --check
```

Expected: the registered focused suite passes; the live wallet uses `texture_cream.png` and retains all existing interaction/layout assertions.

Commit:

```bash
git add games/grove/tests/grove_workbench_tests.gd games/grove/tools/ui_workbench_kit.gd
git commit -m "feat(grove): use flat paper for live currency pills"
```

---

### Task 2: Common square icon-button atom

**Files:**
- Modify: `games/grove/tests/grove_workbench_tests.gd:1450-1530`
- Modify: `games/grove/tools/ui_workbench_kit.gd:1342-1460`

**Interfaces:**
- Consumes: `_apply_rounded_paper_surface(...) -> TextureRect` from Task 1.
- Produces: `home_button(spec, opts)` with `opts.surface_role` values `cream`, `sky`, `green`, or `purple` for `shape: "rect"`.

- [ ] **Step 1: Add failing square-button surface tests**

Add focused assertions:

```gdscript
var rect := Kit.home_button({"icon": "bag", "caption": ""}, {
	"px": 140.0, "shape": "rect", "surface_role": "purple", "shadow": true,
})
var rect_style := rect.get_theme_stylebox("normal") as StyleBoxFlat
var rect_paper := rect.find_child("PaperSurface", true, false) as TextureRect
ok(rect_style != null and rect_style.get_corner_radius(CORNER_TOP_LEFT) == 31,
	"rect home_button draws its rounded-square geometry in code")
ok(rect_paper != null and String(rect_paper.texture.resource_path).ends_with("texture_supporting_purple.png"),
	"rect home_button resolves semantic flat-paper roles")
ok(not _style_tex_path(rect.get_theme_stylebox("normal")).ends_with("shared/badge_rect.png"),
	"rect home_button does not scale a pre-cut badge background")
var play := Kit.home_button({"icon": "board"}, {"px": 188.0, "shape": "disc", "shell": "shared/play_disc.png"})
ok(play.get_theme_stylebox("normal") is StyleBoxTexture,
	"the specialized circular Play shell stays on its authored disc path")
```

- [ ] **Step 2: Run the focused test and verify the expected failure**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_workbench_tests
```

Expected: FAIL because rect buttons still use the full `badge_rect.png` sprite and do not resolve `surface_role`.

- [ ] **Step 3: Route only `shape: "rect"` through the rounded-paper helper**

Define semantic mappings in `ui_workbench_kit.gd`:

```gdscript
const PAPER_SURFACES := {
	"cream": {"texture": "texture_cream.png", "fill": Color("#F6EBDD")},
	"sky": {"texture": "texture_sky.png", "fill": Color("#6FA9C0")},
	"green": {"texture": "texture_action_green.png", "fill": Color("#5F9B6D")},
	"purple": {"texture": "texture_supporting_purple.png", "fill": Color("#8677A3")},
}
```

In `home_button()`, keep the existing `StyleBoxTexture` branch for discs. For rects, resolve `surface_role` (default `cream`) and call:

```gdscript
var corner := int(round(px * 0.22))
var surface: Dictionary = PAPER_SURFACES.get(String(opts.get("surface_role", "cream")), PAPER_SURFACES["cream"])
var surface_fill: Color = surface.get("fill", Color("#F6EBDD"))
_apply_rounded_paper_surface(
	b, String(surface.texture), surface_fill, float(corner), Vector4.ZERO
)
```

Apply `fill_alpha` to the returned paper and base fill. Preserve icon creation, count metadata, badges, captions, sparkle, press juice, and callbacks.

- [ ] **Step 4: Run focused tests and commit the shared atom**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_workbench_tests
git diff --check
```

Expected: PASS, including the existing click, icon, badge, count, and shadow tests.

Commit:

```bash
git add games/grove/tests/grove_workbench_tests.gd games/grove/tools/ui_workbench_kit.gd
git commit -m "feat(grove): draw common icon buttons from flat paper"
```

---

### Task 3: Consumer semantic roles

**Files:**
- Modify: `games/grove/tests/grove_workbench_tests.gd:680-810`
- Modify: `engine/scripts/ui/action_bar.gd:186-200`
- Modify: `engine/scripts/scenes/map.gd:2048-2062`
- Modify: `engine/scripts/scenes/map.gd:2360-2380`
- Modify: `engine/scripts/scenes/map.gd:2490-2520`

**Interfaces:**
- Consumes: `home_button(..., {"shape": "rect", "surface_role": role})` from Task 2.
- Produces: live Bag=`purple`, Home=`green`, Map/Back=`sky`, side rail=`cream`; Play remains a disc.

- [ ] **Step 1: Add failing consumer-role assertions**

Extend the live HUD/map tests to inspect `PaperSurface.texture.resource_path`:

```gdscript
var bag_paper := board_scene.bag_btn.find_child("PaperSurface", true, false) as TextureRect
ok(bag_paper != null and String(bag_paper.texture.resource_path).ends_with("texture_supporting_purple.png"),
	"live board Bag uses the shared purple rounded-square paper surface")
var home_paper := board_scene.home_btn.find_child("PaperSurface", true, false) as TextureRect
ok(home_paper != null and String(home_paper.texture.resource_path).ends_with("texture_action_green.png"),
	"live board Home uses the shared green rounded-square paper surface")
```

For the map scene, assert the Map and Back buttons use `texture_sky.png`, rail buttons use `texture_cream.png`, and `_play_btn` has no `PaperSurface` child.

- [ ] **Step 2: Run focused tests and verify the expected failure**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_workbench_tests
```

Expected: FAIL because consumer option dictionaries do not yet set semantic roles.

- [ ] **Step 3: Apply semantic roles without changing layout or callbacks**

In `ActionBar.home_well()` add:

```gdscript
home_opts["surface_role"] = "purple" if icon_id == "bag" else "green"
```

In `Map._make_map_button()` and `_make_back_button()` add:

```gdscript
opts["surface_role"] = "sky"
```

In `_build_liveops_rail()` add:

```gdscript
_rail_opts["surface_role"] = "cream"
```

Do not add `shape: "rect"` or `surface_role` to `_make_play_button()`.

- [ ] **Step 4: Run integration tests and commit consumer migration**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_workbench_tests
make test-one SUITE=games/grove/tests/grove_board_actions_tests
git diff --check
```

Expected: all focused suites pass with unchanged input and layout behavior.

Commit:

```bash
git add games/grove/tests/grove_workbench_tests.gd engine/scripts/ui/action_bar.gd engine/scripts/scenes/map.gd
git commit -m "feat(grove): apply paper roles to common icon buttons"
```

---

### Task 4: Renderer verification and full regression sweep

**Files:**
- Verify: `games/grove/tools/ui_workbench_view.gd`
- Verify: `games/grove/tools/map_shot.gd`
- Verify: `games/grove/tools/currency_pill_study_shot.gd`

**Interfaces:**
- Consumes: completed live wallet and square-button changes.
- Produces: renderer captures and a merge-ready branch.

- [ ] **Step 1: Capture real-renderer previews**

Run the existing quiet renderer tools:

```bash
engine/tools/quiet_godot.sh --path . -s res://games/grove/tools/currency_pill_study_shot.gd -- /tmp/currency_pill_reference_unchanged.png
engine/tools/quiet_godot.sh --path . -s res://games/grove/tools/map_shot.gd -- /tmp/grove_flat_paper_map.png
```

Expected: the standalone pill reference is unchanged; live map wallet and icon buttons have continuous paper grain, proportional rounded corners, a fine edge, and no baked white strip or stretched badge corners.

- [ ] **Step 2: Run the fast and full suites**

Run:

```bash
make test-fast
make test
git diff --check
```

Expected: all suites pass with zero failures and no whitespace errors.

- [ ] **Step 3: Review branch scope and final diff**

Run:

```bash
git status --short
git diff main...HEAD --stat
git log --oneline main..HEAD
```

Expected: only the approved design/plan docs, shared kit, focused tests, and named consumer files changed.
