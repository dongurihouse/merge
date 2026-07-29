extends RefCounted
## The per-ELEMENT adapters for the mock-compare rig (games/grove/tools/mock_compare_shot.gd; the method
## is docs/design/verifying-against-a-mock.md). One adapter per kind of thing that can be stood up on a
## flat field on its own, each built through the SAME calls the live screen makes — so what lands on the
## sheet is the shipping element, not a re-implementation of it.
##
## AN ADAPTER OWES THE RIG THREE THINGS, and the third is the one that is easy to get silently wrong:
##
##  1. BUILD THROUGH THE SHIPPING PATH. `Kit.action_button(…)` / `Kit.gold_currency_pill(…)` with the
##     opts the screen itself passes. A hand-rolled stand-in measures the stand-in.
##  2. TAKE ITS SIZE FROM THE MOCK. The face width is handed in; the element is built AT that width.
##     Never resample afterwards — a rescaled capture has a resampler's blur in exactly the pixels a
##     shadow lives in.
##  3. SCALE **EVERY** METRIC, not just the ones one knob happens to own. `nav` derives its whole
##     geometry — corner, glyph, caption, halo reach — from `slot_w`, so handing it the mock's width
##     scales the tab coherently and there is nothing else to do. `wallet` does NOT: its
##     `overall_scale` knob scales the layout numbers but the shared cut-paper EDGE knobs (corner,
##     deckle_amp, rim_width, shadow_reach, halo_reach, bevel_px, edge_feather) are absolute px and do
##     not follow it. Left alone, our pill at the mock's 0.86x would carry a 1.16x-too-large shadow
##     reach against a face that had shrunk — and the sheet would look like a shadow-tuning defect
##     instead of a rig bug. `scale_cp()` below is what stops that; a new adapter that skips it is
##     comparing two different geometries.
##
## Adding an element: write `_build_<name>`, add it to `NAMES`, and add a region to
## games/grove/tools/mock_targets.json that names it. Everything that needs a human to LOOK at the
## mock (rects, clean ground, field patches) belongs in that JSON, never here.
##
## WHAT CANNOT BE ADAPTED. This rig only works for an element that can be stood up ALONE on a flat
## field. Anything whose look depends on what is behind it or beside it — the board's own tiles (they
## sit on the board frame's paper, not on sky), the giver cards (their fill is a per-giver tint pulled
## from live state), a scene backdrop — cannot be isolated without inventing the very context under
## test. For those, say so and measure something else; do not fake a field.

const Game = preload("res://engine/scripts/core/game.gd")
const NavBar = preload("res://engine/scripts/ui/nav_bar.gd")

## Every element name a region may name. An unknown one REFUSES the run rather than rendering a blank.
const NAMES := ["nav", "wallet"]

## The cut-paper knobs that are LENGTHS in px, and so must be rescaled with the face (see the header).
## Knobs that are fractions, percentages, counts or colours are deliberately absent.
const CP_LENGTHS := ["corner", "deckle_amp", "rim_width", "shadow_reach", "halo_reach", "bevel_px",
	"edge_feather"]

## Cut-paper knobs whose value is a Vector2 (see `_apply_pairs`).
const VECTOR2_KNOBS := ["halo_offset"]

## Knobs `cut_paper.gd:configure` honours that are NOT in Kit.CUT_PAPER_KNOBS, so a config-derived cp
## dict never carries them and membership alone would reject them. Each is a real panel property.
const EXTRA_CP := ["halo_falloff", "halo_offset"]
## The same, for an element's top-level opts: keys its builder reads with `.get(key, default)` instead
## of receiving them from its opts-from-config pass.
const EXTRA_OPT := ["deckle", "count", "plus_base", "plus_action", "caption", "active", "glyph_shadow",
	"bleed_bottom", "tints"]

## Captions for the nav roles the row ships (games/grove/strings.json map.nav.*); anything else is
## titled from its own role name.
const NAV_CAPTION := {"play": "Board", "map": "Map", "home": "Home", "residents": "Residents",
	"mail": "Mail", "daily": "Daily", "vault": "Vault", "bag": "Bag", "almanac": "Almanac"}


## Build ONE of our elements at the mock's own face width.
##   element  the adapter name (see NAMES)
##   args     the region's `args` block from mock_targets.json (role / icon+count / …)
##   face_w   the face width measured off the mock, in the mock's own pixels
##   mods     the cell spec's `:key=value` modifiers (see mock_compare_shot.gd's header)
## Returns {node, drawn_w, face_w, face_h, face_dx} — `drawn_w` is the full drawn width (an active nav
## tab's rim lives outside its fill), `face_dx` where the FACE starts inside it. {} on failure, after
## push_error.
static func build(element: String, args: Dictionary, face_w: float, mods: Dictionary) -> Dictionary:
	match element:
		"nav": return _build_nav(args, face_w, mods)
		"wallet": return _build_wallet(args, face_w, mods)
	push_error("mock_elements: no adapter named '%s' (have: %s)" % [element, ", ".join(NAMES)])
	return {}


## Does this element accept a forced face colour? `fill=` is the rig's way of removing the fill as a
## variable, and an adapter that cannot honour it must say so rather than quietly ignoring it.
static func takes_fill(element: String) -> bool:
	return element in ["nav", "wallet"]


# --- shared -------------------------------------------------------------------------------

## Multiply every cut-paper LENGTH knob by `k`. See the header: this is not a nicety, it is what makes
## the element's edge the same geometry at the mock's scale as it is at the shipping scale.
static func scale_cp(cp: Dictionary, k: float) -> Dictionary:
	if is_equal_approx(k, 1.0):
		return cp
	for key in CP_LENGTHS:
		if cp.has(key):
			cp[key] = float(cp[key]) * k
	return cp


## Apply the generic `:cp=` / `:opt=` / `:fill=` modifiers. This is how an alternative tuning renders
## WITHOUT editing a constant, so before / after / mock all come out of ONE launch — the moment a
## tuning needs a rebuild to be seen, before and after stop being comparable (different build, and in
## practice a different day's idea of what the baseline was).
##
## A value is `N` (a number), `Nw` (that fraction of the face width — how every reach in this project
## is actually specified), `#RRGGBB`, `true` / `false`, or `off` (0).
##
## An UNKNOWN knob name is REFUSED, not ignored. cut_paper.gd's `configure` (and every opts consumer in
## the kit) reads with `.get(key, default)`, so a misspelt knob changes nothing at all: the cell renders
## the BASELINE, is labelled with the tuning that was asked for, and is then compared against the mock
## as if it were that tuning. Measured — a `_` that a label rule had turned into a space cost exactly
## that, and the sheet looked entirely reasonable.
static func patch(o: Dictionary, cp: Dictionary, mods: Dictionary, face_w: float) -> Array:
	var errs: Array = []
	errs.append_array(_apply_pairs(cp, String(mods.get("cp", "")), face_w, EXTRA_CP, "cp"))
	errs.append_array(_apply_pairs(o, String(mods.get("opt", "")), face_w, EXTRA_OPT, "opt"))
	if mods.has("fill"):
		o["fill"] = Color(String(mods["fill"]))
	return errs


static func _apply_pairs(target: Dictionary, spec: String, face_w: float, extra: Array,
		what: String) -> Array:
	var errs: Array = []
	if spec == "":
		return errs
	for pair in spec.split(",", false):
		var eq := String(pair).find("=")
		if eq < 0:
			errs.append("REFUSED: `%s=` takes KEY=VALUE pairs; '%s' is not one." % [what, pair])
			continue
		var key := String(pair).substr(0, eq)
		var raw := String(pair).substr(eq + 1)
		if not target.has(key) and not (key in extra):
			var seen := {}
			for k in target.keys():
				seen[k] = true
			for k in extra:
				seen[k] = true
			var known: Array = seen.keys()
			known.sort()
			errs.append("REFUSED: '%s' is not a `%s` knob, so setting it would change nothing and the" \
				% [key, what])
			errs.append("cell would render the BASELINE under the tuning's own label.")
			errs.append("  known: %s" % ", ".join(PackedStringArray(known)))
			continue
		var val: Variant = _value(raw, face_w)
		# A Vector2 knob takes ONE number here and slides both ways, which is what "the light is up-left"
		# means. Keyed by NAME, not by the current value's type: a cp dict built from the config's knob
		# list does not carry the knob at all when it is off, so there is nothing to infer the type from
		# — and a float silently written into halo_offset makes cut_paper.gd fail at draw time.
		target[key] = Vector2(float(val), float(val)) if key in VECTOR2_KNOBS and val is float else val
	return errs


static func _value(raw: String, face_w: float) -> Variant:
	if raw == "off":
		return 0.0
	if raw == "true" or raw == "false":
		return raw == "true"
	if raw.begins_with("#"):
		return Color(raw)
	if raw.ends_with("w"):
		return face_w * float(raw.trim_suffix("w"))
	return float(raw)


## Print any refusals `patch` collected. False means the caller must give up on this cell.
static func _report(errs: Array) -> bool:
	for e in errs:
		print(e)
	return errs.is_empty()


static func _kit() -> GDScript:
	var Kit: GDScript = Game.kit_script()
	if Kit == null:
		push_error("mock_elements: no UI kit for this game")
	return Kit


# --- nav tab ------------------------------------------------------------------------------

## ONE nav tab, built through the same two calls the live row makes (NavBar.tab_opts + NavBar.tab_cp
## merged over Kit.action_button_opts_from_config). Every nav metric is a fraction of the slot width,
## so handing it the mock's own tab width scales corner, glyph, caption and shadow reach together —
## no scale_cp() needed here, and that is a property of nav_bar.gd, not a general one.
##
## Mods: `:active` the raised current tab · `:cap=TEXT` · `:glyph=off | DY,GROW,A/DY,GROW,A/…` the
## ICON's own shadow stack (`/` separates layers because a `;` would end the shell command).
static func _build_nav(args: Dictionary, face_w: float, mods: Dictionary) -> Dictionary:
	var Kit := _kit()
	if Kit == null:
		return {}
	var role := String(args.get("role", "home"))
	var active := mods.has("active")
	var box: Vector2 = NavBar.active_size(face_w) if active else NavBar.tile_size(face_w)
	var drawn_w: float = NavBar.drawn_w(face_w, active)

	var o: Dictionary = Kit.action_button_opts_from_config(Game.kit_config())
	o.merge(NavBar.tab_opts(face_w), true)
	o["name"] = "NavTab_" + role
	o["caption"] = String(mods.get("cap", NAV_CAPTION.get(role, role.capitalize())))
	o["active"] = active
	o["fill"] = NavBar.chalk(Kit.action_role_fill(role, o.get("tints", {})))
	# the paper runs one corner radius past the bottom edge, so the bottom corners round OFF the sheet
	# and only the top two show — the bled tab bar. (`Look.safe_bottom` is 0 on a desktop capture.)
	var bleed := float(o["corner"])
	o["bleed_bottom"] = bleed
	var cp: Dictionary = (o.get("cp", {}) as Dictionary).duplicate()
	cp.merge(NavBar.tab_cp(face_w, box.y, box.y + bleed, active), true)
	if not _report(patch(o, cp, mods, face_w)):
		return {}
	o["cp"] = cp
	if mods.has("glyph"):
		o["glyph_shadow"] = _glyph_stack(String(mods["glyph"]))

	var b: Button = Kit.action_button(role, box, Callable(), o)
	b.size = box
	return {"node": b, "drawn_w": drawn_w, "face_w": box.x, "face_h": box.y,
		"face_dx": (drawn_w - box.x) * 0.5}


## `off` → no icon shadow; else `DY,GROW,A/DY,GROW,A/…` → that literal stack. Literal rather than a
## named preset on purpose: a stack a past commit shipped is then a command-line argument, so the rig
## can render a retired tuning without checking the tree out at that commit.
static func _glyph_stack(s: String) -> Array:
	if s == "off":
		return []
	var out: Array = []
	for layer in s.split("/", false):
		var f := String(layer).split(",")
		if f.size() >= 3:
			out.append({"dy": float(f[0]), "grow": float(f[1]), "a": float(f[2])})
	return out


# --- wallet pill --------------------------------------------------------------------------

## ONE HUD wallet pill, built through Kit.gold_currency_pill with the HUD's own opts.
##
## Its width comes from the config's `pill_w` under `overall_scale`, so the width is forced by solving
## that knob for the mock's face width and rebuilding — the component's OWN scale knob rather than a
## list of multiplications here. The cut-paper edge knobs then still have to be scaled by hand: see
## the header, they do not follow overall_scale.
##
## Mods: `:count=N` · `:icon=ID` (both default to the region's own args, i.e. the number the mock
## actually draws) · plus the shared `:cp=` / `:opt=` / `:fill=`.
static func _build_wallet(args: Dictionary, face_w: float, mods: Dictionary) -> Dictionary:
	var Kit := _kit()
	if Kit == null:
		return {}
	var icon := String(mods.get("icon", args.get("icon", "water")))
	var count := int(mods.get("count", args.get("count", 0)))

	var cfg: Dictionary = Game.kit_config()
	var base: Dictionary = Kit.gold_currency_pill_opts_from_config(cfg)
	var natural_w := maxf(1.0, float(base.get("pill_w", 292.0)))
	var k := face_w / natural_w
	if not is_equal_approx(k, 1.0):
		# re-derive at the scale that lands pill_w on the mock's face width. duplicate(true) so the
		# kit's SHARED config cache is never mutated (Game.kit_config's contract).
		var scaled: Dictionary = cfg.duplicate(true)
		var block: Dictionary = scaled.get("gold_currency_pill", {})
		block["overall_scale"] = float(block.get("overall_scale", 100.0)) * k
		scaled["gold_currency_pill"] = block
		base = Kit.gold_currency_pill_opts_from_config(scaled)
	var o: Dictionary = base.duplicate(true)
	o["icon"] = icon
	o["show_plus"] = String(mods.get("plus", "1")) != "0"
	var cp: Dictionary = scale_cp((o.get("cp", {}) as Dictionary).duplicate(), k)
	if not _report(patch(o, cp, mods, face_w)):
		return {}
	o["cp"] = cp

	var pill: Control = Kit.gold_currency_pill(o, {icon: count})
	var w := float(o.get("pill_w", face_w))
	var h := maxf(float(o.get("pill_h", 100.0)), pill.custom_minimum_size.y)
	pill.size = Vector2(w, h)
	return {"node": pill, "drawn_w": w, "face_w": w, "face_h": h, "face_dx": 0.0}
