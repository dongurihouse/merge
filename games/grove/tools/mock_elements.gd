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
##     shadow lives in. And write that size on the node whose rect the ELEMENT's own layout derives from:
##     an ANCHORED child (`tray`'s sheet is anchored full-rect inside its host, and so is the wallet's
##     backer) refuses `size` and keeps the write as OFFSETS, which the next layout pass ADDS to its
##     anchored rect — measured, an 829x146 tray cell drew a 1658x292 sheet across its neighbours.
##  3. SCALE **EVERY** METRIC, not just the ones one knob happens to own. `nav` derives its whole
##     geometry — corner, glyph, caption, halo reach — from `slot_w`, so handing it the mock's width
##     scales the tab coherently and there is nothing else to do. `wallet` does NOT: its
##     `overall_scale` knob scales the layout numbers but the block's own cut-paper EDGE knobs
##     (deckle_freq, shadow_reach, shadow_blur) are absolute px and do not follow it. Left alone, our
##     pill at the mock's 0.86x would carry a 1.16x-too-large shadow reach against a face that had
##     shrunk — and the sheet would look like a shadow-tuning defect instead of a rig bug. `scale_cp()`
##     below is what stops that; a new adapter that skips it is comparing two different geometries.
##     The MIRROR of that bug is scaling a knob that already followed the size: the pill's
##     paper-furniture patch (Paper.FURNITURE_KNOBS) is derived from `pill_h`, so `scale_cp` is told to
##     skip it. Both halves are one question — which knobs already moved.
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
const Paper = preload("res://engine/scripts/ui/paper_button.gd")   # the shared paper-button surface treatment
const EdgeTab = preload("res://engine/scripts/ui/edge_tab.gd")     # …and the screen-edge tab geometry (bleed + flare)
const ActionBar = preload("res://engine/scripts/ui/action_bar.gd") # the board's bottom-row builders (the info tray)
const UnlockBar = preload("res://engine/scripts/ui/unlock_bar.gd") # the board's NEXT UNLOCK strip + its bar
const ShopUI = preload("res://engine/scripts/ui/shop.gd")          # the storefront's offer-card builder
const Design = preload("res://engine/scripts/core/design.gd")      # THE design viewport — never re-type 1080x1920

## Every element name a region may name. An unknown one REFUSES the run rather than rendering a blank.
const NAMES := ["nav", "wallet", "well", "tray", "unlock", "progress", "shop_card"]

## The cut-paper knobs that are LENGTHS in px, and so must be rescaled with the face (see the header).
## Knobs that are fractions, percentages, counts or colours are deliberately absent.
## `halo_offset` is a LENGTH too (a Vector2 one): it is how far the halo's rings slide, in px, and left
## unscaled at the mock's 0.86x it would push the light further off a face that had shrunk — the same
## rule-2 bug the reach knobs carry, just harder to see.
const CP_LENGTHS := ["corner", "deckle_amp", "rim_width", "shadow_reach", "halo_reach", "bevel_px",
	"edge_feather", "halo_offset"]

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
		"well": return _build_well(args, face_w, mods)
		"tray": return _build_tray(args, face_w, mods)
		"unlock": return _build_unlock(args, face_w, mods)
		"progress": return _build_progress(args, face_w, mods)
		"shop_card": return _build_shop_card(args, face_w, mods)
	push_error("mock_elements: no adapter named '%s' (have: %s)" % [element, ", ".join(NAMES)])
	return {}


## Does this element accept a forced face colour? `fill=` is the rig's way of removing the fill as a
## variable, and an adapter that cannot honour it must say so rather than quietly ignoring it.
## `progress` is absent on purpose: a progress bar has no single "face colour". Its two faces are the
## well's floor and the capsule's card, and forcing one of them would remove the wrong variable — the
## thing under test IS the pair. The region hands both in from the mock instead (see `args`).
static func takes_fill(element: String) -> bool:
	return element in ["nav", "wallet", "well", "tray", "unlock", "shop_card"]


# --- shared -------------------------------------------------------------------------------

## Multiply every cut-paper LENGTH knob by `k`. See the header: this is not a nicety, it is what makes
## the element's edge the same geometry at the mock's scale as it is at the shipping scale.
## `skip` names the knobs the element's OWN opts resolver already derived from its scaled size — scaling
## those again is the mirror of the bug this function exists for. The wallet pill's whole paper-furniture
## patch (Paper.FURNITURE_KNOBS) is derived from `pill_h`, which follows `overall_scale`, so it arrives
## correct and must be left alone; only the block's own absolute-px knobs still need the multiply.
static func scale_cp(cp: Dictionary, k: float, skip: Array = []) -> Dictionary:
	if is_equal_approx(k, 1.0):
		return cp
	for key in CP_LENGTHS:
		if not cp.has(key) or key in skip:
			continue
		# a Vector2 length (halo_offset) scales as a vector; everything else is a scalar px value.
		cp[key] = (cp[key] as Vector2) * k if cp[key] is Vector2 else float(cp[key]) * k
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

## ONE nav tab, built through the same two calls the live row makes (NavBar.tab_opts + EdgeTab.tab_cp
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
	cp.merge(EdgeTab.tab_cp(face_w, box.y, box.y + bleed, active), true)
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


# --- free-standing paper WELL ---------------------------------------------------------------

## ONE free-standing paper button — the board's Home / Bag wells, its almanac chip, the place-picker's
## back button — built through the two calls those screens make: Kit.action_button_opts_from_config, then
## the shared material (Paper.apply). No flare, no bleed, no caption: a well is not a tab.
##
## SCALE (rule 3). Unlike `nav`, this element does NOT derive its geometry from one width: the config's
## cut-paper knobs (corner, deckle_amp, rim_width, shadow_reach) are absolute px authored for the size the
## button SHIPS at, so they are rescaled by mock_face_w / native_px before the treatment goes on. The
## treatment's own knobs are already fractions of the face width and are therefore correct at any size —
## which is why they are applied AFTER the rescale and not scaled again.
##
## `args`: role (the kit action role) · face_h (the mock's own face HEIGHT — a well's aspect is the
## board's layout choice, not the material's, so the rig takes the mock's) · native_px (the size this
## button ships at, for the rescale) · tint (a paper role for a role the kit's tint map does not carry) ·
## glyph_rel / icon_scale (overrides, as the shipping caller passes them).
static func _build_well(args: Dictionary, face_w: float, mods: Dictionary) -> Dictionary:
	var Kit := _kit()
	if Kit == null:
		return {}
	var role := String(args.get("role", "bag"))
	var box := Vector2(face_w, float(args.get("face_h", face_w)))
	var cfg: Dictionary = Game.kit_config()
	var native_px := maxf(1.0, float(args.get("native_px",
		float((cfg.get("action_button", {}) as Dictionary).get("px", 158.0)))))

	var o: Dictionary = Kit.action_button_opts_from_config(cfg)
	o["name"] = "Well_" + role
	if args.has("icon_scale"):
		o["icon_scale"] = float(args["icon_scale"])
	if args.has("glyph_rel"):
		o["glyph_rel"] = String(args["glyph_rel"])
	if args.has("tint"):
		var tints: Dictionary = (o.get("tints", {}) as Dictionary).duplicate()
		tints[role] = String(args["tint"])
		o["tints"] = tints
	o["cp"] = scale_cp((o.get("cp", {}) as Dictionary).duplicate(), face_w / native_px)
	Paper.apply(o, box)

	var cp: Dictionary = o["cp"]
	if not _report(patch(o, cp, mods, face_w)):
		return {}
	o["cp"] = cp
	if mods.has("glyph"):
		o["glyph_shadow"] = _glyph_stack(String(mods["glyph"]))

	var b: Button = Kit.action_button(role, box, Callable(), o)
	b.size = box
	return {"node": b, "drawn_w": box.x, "face_w": box.x, "face_h": box.y, "face_dx": 0.0}


# --- the board's bottom INFO TRAY -----------------------------------------------------------

## The board's cream info tray — the MIDDLE sheet of its bottom row — built through the shipping call
## (ActionBar.info_tray), so what stands on the field is the panel the board draws and not a stand-in.
## The mock draws this sheet too, as the info bar above its nav row.
##
## SCALE (rule 3). Everything this sheet's look is made of is derived from the height handed to
## `info_tray`: its corner is `_bar_corner(bar_h)` and its whole material is a fraction of `material_px`,
## which on the shipping screen IS the tray's own visible height (the row's well size). So passing the
## mock's own face height scales the sheet coherently. ONE knob does not follow: `shadow_reach` comes
## from the config in absolute px, so it is scaled here by hand — the same job `scale_cp` does for `well`,
## applied to the built panel because this builder takes no cp dict.
##
## `args`: face_h (the mock's own sheet height) · native_px (the height the tray SHIPS at, for that one
## rescale) · bleed_frac (px of paper past the box, as a fraction of the corner radius — 1.0 is what the
## board ships; the region defaults it to 0).
## Mods: `:bleed=N` px of bled paper, `:fill=#RRGGBB`. `cp=` / `opt=` are REFUSED rather than ignored:
## this element is not built from an opts dict, so a knob written here would change nothing at all and
## the cell would render the BASELINE under the tuning's own label (rule 4).
static func _build_tray(args: Dictionary, face_w: float, mods: Dictionary) -> Dictionary:
	var Kit := _kit()
	if Kit == null:
		return {}
	for bad in ["cp", "opt"]:
		if mods.has(bad):
			print("REFUSED: the 'tray' element is not built from an opts dict, so `%s=` would be" % bad)
			print("silently ignored and the cell would render the BASELINE under the tuning's label.")
			print("  this element's own mods: bleed=N, fill=#RRGGBB")
			return {}
	var face_h := float(args.get("face_h", face_w * 0.18))
	var native_px := maxf(1.0, float(args.get("native_px", 162.0)))
	var bleed := float(mods.get("bleed", float(args.get("bleed_frac", 0.0)) * float(ActionBar.bar_corner_px(face_h))))

	var inner := Control.new()          # the info bar's slot: the sheet is what is under test, not its contents
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tray: Control = ActionBar.info_tray(inner, face_h, {}, bleed, face_h)
	tray.custom_minimum_size = Vector2(face_w, face_h)
	tray.size = Vector2(face_w, face_h)
	# THE SHEET IS TWO LEVELS DOWN, and its rect is not ours to write. `_apply_info_deckle_surface` hangs it
	# off a plain Control (DECKLE_HOST_NODE) precisely so the tray's PanelContainer cannot re-fit it and eat
	# the bleed, and anchors it FULL_RECT inside that host with `offset_bottom = bleed`. Two consequences:
	#   * a NON-recursive lookup on the tray finds nothing, and this adapter then refuses every run;
	#   * `surface.size = …` is REFUSED by Godot ("Nodes with non-equal opposite anchors will have their size
	#     overridden") and is not merely ignored — the write lands in the sheet's OFFSETS, which the next
	#     layout pass adds to the anchored rect. Measured: an 829x146 cell drew a 1658x292 sheet, exactly
	#     double, spilling across its neighbours in the sheet as a cell that looks plausible and is not.
	# So the SIZE is written on the host — the rect those anchors resolve against, and the same rect the
	# PanelContainer fits it to on the shipping screen — and the sheet follows, bleed and all. Its trapezoid
	# is re-solved by the shipping `resized` hook when that layout pass lands, exactly as it is for the
	# board's own expanding tray; re-flaring here (at 0x0) would only write `shape = rect`.
	var host := tray.find_child(ActionBar.DECKLE_HOST_NODE, false, false) as Control
	var surface: Control = null
	if host != null:
		surface = host.find_child(ActionBar.DECKLE_SURFACE_NODE, false, false) as Control
	if surface == null:
		push_error("mock_elements: the info tray built no cut-paper surface under %s" % ActionBar.DECKLE_HOST_NODE)
		return {}
	host.custom_minimum_size = Vector2(face_w, face_h)
	host.size = Vector2(face_w, face_h)
	surface.shadow_reach *= face_h / native_px      # the one absolute length the shipping call does not scale
	if mods.has("fill"):
		surface.paper_color = Color(String(mods["fill"]))
	surface.queue_redraw()
	return {"node": tray, "drawn_w": face_w, "face_w": face_w, "face_h": face_h, "face_dx": 0.0}


# --- wallet pill --------------------------------------------------------------------------

## ONE HUD wallet pill, built through Kit.gold_currency_pill with the HUD's own opts.
##
## Its width comes from the config's `pill_w` under `overall_scale`, so the width is forced by solving
## that knob for the mock's face width and rebuilding — the component's OWN scale knob rather than a
## list of multiplications here. Its paper-furniture knobs (corner, halo, bevel, feather) are derived by
## the resolver from `pill_h`, so those come out already scaled; the block's remaining absolute-px knobs
## (the downward drop shadow) do not follow overall_scale and still need `scale_cp`.
##
## Mods: `:count=N` · `:icon=ID` (both default to the region's own args, i.e. the number the mock
## actually draws) · `:blank` hides the pill's CONTENTS · plus the shared `:cp=` / `:opt=` / `:fill=`.
##
## USE `:blank` FOR ANY SHADOW MEASUREMENT. mock_profile.py finds the element's own edge by walking away
## from a face colour it probes 11px inside that edge, and the pill's amount numeral is now WHITE and
## right-aligned to within a few px of the right edge — so the probe reads the NUMERAL as the face,
## and the edge finder then stops on the numeral's own antialiasing. Measured: the right side came back
## at -0.358 darkening, a shadow that BRIGHTENS, which is the same sign-tell rule 6 names for a
## mismatched silhouette. The sheet still ships through the real builder; only its contents are hidden,
## and the contents cast nothing.
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
	var cp: Dictionary = scale_cp((o.get("cp", {}) as Dictionary).duplicate(), k, Paper.FURNITURE_KNOBS)
	if not _report(patch(o, cp, mods, face_w)):
		return {}
	o["cp"] = cp

	var pill: Control = Kit.gold_currency_pill(o, {icon: count})
	if mods.has("blank"):
		var content := pill.find_child("GoldCurrencyPillContentHost", true, false) as Control
		if content == null:
			print("REFUSED: `blank` found no GoldCurrencyPillContentHost to hide — the cell would")
			print("render the pill's icon and numeral under a label that says it has neither.")
			return {}
		content.visible = false
	var w := float(o.get("pill_w", face_w))
	var h := maxf(float(o.get("pill_h", 100.0)), pill.custom_minimum_size.y)
	pill.size = Vector2(w, h)
	return {"node": pill, "drawn_w": w, "face_w": w, "face_h": h, "face_dx": 0.0}


# --- the board's NEXT UNLOCK strip -----------------------------------------------------------

## The whole band — the shipping engine/scripts/ui/unlock_bar.gd control, built at the mock's own box and
## driven through its own setters, so what stands on the field is the strip the board draws.
##
## SCALE (rule 3). Everything the band's look is made of is derived from its own HEIGHT — the corner, the
## badge, the two type sizes, the bar box, the whole shared material AND its drop-shadow reach are all
## fractions of it (`UnlockBar.surface_cp`) — so handing it the mock's own face height scales it
## coherently and there is nothing left to rescale by hand. That is a property of unlock_bar.gd, not a
## general one: `well` and `tray` both take absolute config px and need `scale_cp`.
##
## `args`: face_h (the mock's own band height) · level (the number under NEXT UNLOCK) · frac (the fill
## the mock happens to draw).
## Mods: `:frac=N` a different fill · `:ready` the affordable/gold state · `:fill=#RRGGBB` · the shared
## `:cp=` (applied to the band's own composed knob set, so an unknown one is REFUSED as everywhere else).
static func _build_unlock(args: Dictionary, face_w: float, mods: Dictionary) -> Dictionary:
	var Kit := _kit()
	if Kit == null:
		return {}
	var face_h := float(args.get("face_h", face_w * 0.127))
	var bar := UnlockBar.new()
	bar.name = "MockUnlockBar"
	bar.size = Vector2(face_w, face_h)
	bar.relayout()      # `resized` does not fire for a band sized by hand outside a container
	bar.set_next_level(int(args.get("level", 3)))
	if mods.has("ready"):
		bar.set_ready(true)
	bar.set_progress(clampf(float(mods.get("frac", args.get("frac", 0.67))), 0.0, 1.0))
	var surface := bar.find_child(UnlockBar.DECKLE_SURFACE_NODE, true, false) as Control
	if surface == null:
		push_error("mock_elements: the unlock strip built no cut-paper surface")
		return {}
	# the band's OWN composed knob set — so a `cp=` mod is checked against exactly the knobs the board
	# ships, and an unknown one is refused rather than rendering the baseline under the tuning's label.
	var cp := UnlockBar.surface_cp(Kit, Game.kit_config(), face_h)
	if not _report(patch({}, cp, mods, face_w)):
		return {}
	var fill: Color = Color(String(mods["fill"])) if mods.has("fill") else surface.paper_color
	surface.configure(cp, fill, null, Kit.cut_paper_tile())
	surface.corner = float(cp["corner"])
	return {"node": bar, "drawn_w": face_w, "face_w": face_w, "face_h": face_h, "face_dx": 0.0}


## JUST THE BAR — the well and its capsule, standing on a flat field of the BAND's cream (which is what
## the mock's own bar lies on: this element is drawn INSET into another sheet, so rule 16 applies and the
## field is that sheet, not the sky).
##
## Built through `UnlockBar.bar_opts`, the same static the strip itself calls, so the rig cannot drift
## from the shipping bar by an opt. `_progress_layout_paper` runs off `resized`, and this bar never enters
## a tree at its final size before the capture, so the layout callable is fired by hand.
##
## `args`: face_h (the mock's own bar height) · frac. Mods: `:frac=N` · `:ready` · the shared `:opt=`.
## `:cp=` is REFUSED: the bar's cut-paper knobs live inside its `paper` sub-dict, so a `cp=` written here
## would land on nothing and the cell would render the BASELINE under the tuning's own label (rule 4).
static func _build_progress(args: Dictionary, face_w: float, mods: Dictionary) -> Dictionary:
	var Kit := _kit()
	if Kit == null:
		return {}
	if mods.has("cp"):
		print("REFUSED: a progress bar's cut-paper knobs are inside its `paper` sub-dict, so `cp=` would")
		print("be silently ignored and the cell would render the BASELINE under the tuning's own label.")
		print("  this element's own mods: frac=N, ready, opt=K=V")
		return {}
	var box := Vector2(face_w, float(args.get("face_h", face_w * 0.09)))
	var o: Dictionary = UnlockBar.bar_opts(Kit, Game.kit_config(), box, mods.has("ready"))
	if not _report(patch(o, {}, mods, face_w)):
		return {}
	var frac := clampf(float(mods.get("frac", args.get("frac", 0.67))), 0.0, 1.0)
	var bar: Control = Kit.progress_bar(frac, o)
	bar.size = box
	Kit.progress_bar_set_frac(bar, frac)     # fires the layout callable: nothing has resized this bar yet
	return {"node": bar, "drawn_w": box.x, "face_w": box.x, "face_h": box.y, "face_dx": 0.0}


# --- the SHOP's offer card ------------------------------------------------------------------

## ONE shop offer card, built through the storefront's own `Shop.build_body` on `Shop.shop_layout` — the
## same pair the live shop and the UI workbench both call — so what stands on the field is the card the
## storefront draws. This is only riggable at all because the card's ground is the dialog's own cream
## SHEET, which the mock paints flat (rule 16: ask what the mock's copy is lying on; measured with the
## rule-9 diagnostic the sheet beside a card reads 3.1-5.2 against a limit of 12).
##
## SCALE (rule 3). The card's cut-paper knobs are absolute px authored for the LAYOUT width the storefront
## gives it, so they are rescaled by the mock's face width over that width (`Shop.grid_inner_w` /
## `Shop.card_layout_w`, the shipping derivations). The dialog's content_scale drops out of that ratio on
## purpose: it scales the sheet and its knob px together, so the proportion the rig must preserve is
## scale-free — and a `cscale` left in would shrink the corner twice.
##
## SIZE FROM THE MOCK (rule 2). A card's ASPECT is the shop grid's layout choice, not the material's
## (ours is 0.26 W on a wide row, the painting's 0.221), so the region hands in the mock's own `face_h`
## and the card is forced to that box after it is built.
##
## `args`: wide (the full-row Free-refill lead) · title (a titled Quick-help card) · face_h · icon ·
## count · price. Mods: `:blank` hides the card's CONTENTS · `:fill=#RRGGBB` · the shared `:cp=`.
## `:opt=` is REFUSED: the card is not built from a top-level opts dict, so a knob written there would
## change nothing and the cell would render the BASELINE under the tuning's own label (rule 4).
##
## USE `:blank` FOR ANY EDGE OR SHADOW MEASUREMENT. mock_profile.py finds the element's own edge by
## walking away from a face colour probed 11px inside it, and a card's art and its white-on-green price
## pill both come within a few px of the sheet's edge — the same trap the wallet pill's numeral set.
static func _build_shop_card(args: Dictionary, face_w: float, mods: Dictionary) -> Dictionary:
	var Kit := _kit()
	if Kit == null:
		return {}
	if mods.has("opt"):
		print("REFUSED: the 'shop_card' element is not built from a top-level opts dict, so `opt=` would")
		print("be silently ignored and the cell would render the BASELINE under the tuning's own label.")
		print("  this element's own mods: blank, fill=#RRGGBB, cp=K=V")
		return {}
	var cfg: Dictionary = Game.kit_config()
	var wide := bool(args.get("wide", false))
	var lay: Dictionary = ShopUI.shop_layout(cfg)
	var gap: float = float(lay.get("grid_gap", ShopUI.GRID_GAP))
	var inner: float = ShopUI.grid_inner_w(Kit, cfg, Design.size().x)
	var native_w: float = maxf(1.0, ShopUI.card_layout_w(inner, gap, wide))
	var box := Vector2(face_w, float(args.get("face_h", face_w * (0.26 if wide else 0.54))))

	var cp: Dictionary = scale_cp((lay.get("cp", {}) as Dictionary).duplicate(), face_w / native_w)
	if not _report(patch({}, cp, mods, face_w)):
		return {}
	lay = lay.duplicate()
	lay["cp"] = cp
	lay["corner"] = float(cp.get("corner", lay.get("corner", ShopUI.CARD_CORNER)))

	var d := {"icon": String(args.get("icon", "shop_can")), "count": int(args.get("count", 100)),
		"price": String(args.get("price", "Free"))}
	if String(args.get("title", "")) != "":
		d["title"] = String(args["title"])
	# A LONE offer takes the WIDE proportions by design (`_offer_grid`: "a lone offer gets the Welcome
	# bundle's full-row proportions"), so a half-width card cannot be built one at a time — it is built as
	# the PAIR the storefront lays out and the first of the two is taken.
	var grid_w := face_w if wide else face_w * 2.0 + gap
	var cards: Array = [d] if wide else [d, d.duplicate()]
	if wide:
		d["wide"] = true
	var body: Control = ShopUI.build_body(Kit, grid_w, [{"caption": "", "cards": cards}], lay)
	var card := body.find_child("ShopOfferCard", true, false) as Control
	if card == null:
		push_error("mock_elements: the storefront built no ShopOfferCard")
		return {}
	var surface := card.find_child(ShopUI.CARD_SURFACE_NODE, false, false) as Control
	if surface == null:
		push_error("mock_elements: the offer card built no cut-paper surface (%s)" % ShopUI.CARD_SURFACE_NODE)
		return {}
	if mods.has("blank"):
		var content := card.find_child("ShopOfferCardBody", false, false) as Control
		if content == null:
			print("REFUSED: `blank` found no ShopOfferCardBody to hide — the cell would render the card's")
			print("art and price pill under a label that says it has neither.")
			return {}
		content.visible = false
	# OUT OF THE GRID, so the box is ours to write: a Container re-fits its children every layout pass and
	# would put the card straight back at the grid's own width (the `tray` note is the same hazard).
	var host := Control.new()
	host.name = "MockShopCardHost"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.custom_minimum_size = box
	host.size = box
	(card.get_parent() as Node).remove_child(card)
	body.queue_free()
	card.custom_minimum_size = box
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(card)
	if mods.has("fill"):
		surface.paper_color = Color(String(mods["fill"]))
		surface.queue_redraw()
	return {"node": host, "drawn_w": box.x, "face_w": box.x, "face_h": box.y, "face_dx": 0.0}
