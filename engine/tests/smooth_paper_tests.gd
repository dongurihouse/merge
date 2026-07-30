extends "res://engine/tests/test_base.gd"
## THE GUARD ON ONE PAPER MATERIAL: every cut-paper surface in the game draws a SMOOTH, antialiased cut
## edge, and no surface may quietly go back to the torn deckle it used to wear.
##   godot --headless --path . -s res://engine/tests/smooth_paper_tests.gd
##
## WHY A SUITE AND NOT A PROMISE. The torn edge was switched on in eleven separate places — a knob schema,
## seven per-component default dicts, three hand-written opts literals and seven saved config values — and
## nothing tied them together. Reverting one of them is a one-word edit that renders as "that dialog looks
## slightly different", passes every other suite, and would land. Worse, the two halves of a smooth edge
## are SEPARABLE: `draw_colored_polygon` computes no coverage, so zeroing `deckle_amp` without asking for
## `edge_feather` draws a hard binary STAIRCASE up every corner arc — and that failure is invisible at 1x
## and invisible to a test that only checks the tear is gone. Both halves are checked here, always together.
##
## FOUR LAYERS, deliberately, because each catches a different way a tear comes back:
##   1. THE SCHEMA — Kit.CUT_PAPER_KNOBS. This is the generator: a component that says nothing about its
##      edge gets whatever is here, so this is where "new surfaces are smooth by default" is actually true
##      or not. Also pins the feather to the panel's own measured constant rather than a re-typed number.
##   2. THE OVERRIDE DICTS — every `*_CP_DEFAULTS` const on the Kit, found by REFLECTION rather than named,
##      so a component added tomorrow is covered without anyone remembering to add it here.
##   3. THE SAVED CONFIG — games/grove/ui_kit_settings.json, the values that actually ship. The workbench
##      writes this file wholesale, so a tuning session is exactly how a tear gets saved back in.
##   4. THE HAND-WRITTEN LITERALS — a source scan. Three cut-paper opts dicts are built by hand (the map
##      card shell's Kit-less fallback, the toggle switch's, the slot cell's inner well) and by definition
##      inherit nothing from layers 1-3, which is precisely why they were the ones left torn twice.
## …and then 5: the surfaces are BUILT and read back, because a knob dict is not a render.

const Kit = preload("res://games/grove/ui_kit.gd")
const CutPaper = preload("res://engine/scripts/ui/cut_paper.gd")

## The two knobs that ARE the edge treatment. Everything below asserts on this pair together.
const AMP := "deckle_amp"
const FEATHER := "edge_feather"

## Shipping source roots the literal scan walks. Tests are excluded on purpose — a suite is allowed to
## build a torn panel to prove the machinery still works (action_button_tests does exactly that).
const SCAN_ROOTS := ["res://engine/scripts/", "res://games/grove/"]
const SCAN_SKIP := ["res://games/grove/tests/", "res://games/grove/assets/"]

## A hand-written cut-paper opts literal is allowed to spell a NON-ZERO tear only if it is listed here,
## with the reason. Empty is the correct state; an entry is a decision someone made and can be reviewed.
const TORN_BY_DESIGN := {}

func _initialize() -> void:
	print("== One smooth paper material ==")
	_check_schema()
	_check_override_dicts()
	_check_saved_config()
	_check_source_literals()
	_check_built_surfaces()
	finish()

# --- 1. the schema: what a component gets when it says nothing --------------------------------------

func _knob(key: String) -> Dictionary:
	for k in Kit.CUT_PAPER_KNOBS:
		if String(k["key"]) == key:
			return k
	return {}

func _check_schema() -> void:
	var amp := _knob(AMP)
	var feather := _knob(FEATHER)
	ok(not amp.is_empty() and not feather.is_empty(), "the shared knob set still defines both halves of the edge")
	if amp.is_empty() or feather.is_empty():
		return
	ok(is_equal_approx(float(amp["default"]), 0.0),
		"the SCHEMA's tear defaults to nothing — a new surface is smooth without asking (%.2f)" % float(amp["default"]))
	ok(float(feather["default"]) > 0.0,
		"…and its antialias band defaults ON, or that smooth arc rasterizes as a staircase (%.2f)"
			% float(feather["default"]))
	# ONE number, in ONE place. The measurement lives on the panel; the schema and the paper-button
	# material both point at it. A literal re-typed here is how two surfaces end up 0.5px apart.
	ok(is_equal_approx(float(feather["default"]), CutPaper.SMOOTH_FEATHER_PX),
		"…at the panel's own measured width, not a number re-typed in the schema (%.2f vs %.2f)"
			% [float(feather["default"]), CutPaper.SMOOTH_FEATHER_PX])
	var Paper := load("res://engine/scripts/ui/paper_button.gd")
	ok(is_equal_approx(Paper.EDGE_FEATHER_PX, CutPaper.SMOOTH_FEATHER_PX),
		"…and the paper-button material points at the same one (%.2f)" % Paper.EDGE_FEATHER_PX)
	# the FEATHER MUST BE REACHABLE at the schema's default: the slider's own range has to contain it, or
	# the workbench clamps the value the game renders and a Save writes the clamped one back.
	ok(float(feather["default"]) >= float(feather["min"]) and float(feather["default"]) <= float(feather["max"]),
		"…and it sits inside the workbench slider's own range (%.2f in [%.0f, %.0f])"
			% [float(feather["default"]), float(feather["min"]), float(feather["max"])])
	# the panel's OWN exports are the last-resort default — anything that builds a CutPaperPanel and never
	# calls `configure` (the scale-proof shot rig) renders off these.
	var bare: Control = CutPaper.new()
	ok(is_equal_approx(bare.deckle_amp, 0.0) and bare.edge_feather > 0.0,
		"an unconfigured panel is smooth + antialiased straight out of its own exports (%.2f / %.2f)"
			% [bare.deckle_amp, bare.edge_feather])
	bare.free()
	_check_arc_flatness()

## THE CORNER MUST BE A CURVE, NOT A POLYGON. Antialiasing a silhouette does nothing about how coarsely
## that silhouette was sampled, and the tear was hiding both: at the old step rule a 36px toggle knob came
## out a twelve-sided polygon with 0.61px facets, which the 2px feather softened without hiding. Asserted
## on the SAGITTA the step count actually produces — the depth of the flat a player can see — in literal
## px, at every radius the game ships, and never against the constant that produces it.
func _check_arc_flatness() -> void:
	var worst := 0.0
	var worst_r := 0.0
	# the radii shipping today: a switch knob (18), a settings row (16/20), a dialog (22), a mail card (32),
	# a wallet pill (35), an action button (41), the board frame (46) — plus the extremes of the slider.
	for r in [4.0, 8.0, 10.0, 16.0, 18.0, 20.0, 22.0, 32.0, 35.0, 41.0, 46.0, 60.0]:
		var k: int = CutPaper.arc_steps(r)
		var sag: float = r * (1.0 - cos(PI * 0.25 / float(k)))     # the mid-chord shortfall, in px
		if sag > worst:
			worst = sag
			worst_r = r
	ok(worst < 0.2, "no corner arc reads flatter than a fifth of a pixel (worst %.3fpx at r=%.0f)" % [worst, worst_r])
	# …and the sampling really is what changed, not just the algebra: a 36px disc must come out with enough
	# points to BE a disc. 12 was the old count and read as a dodecagon; anything near it fails.
	var knob: Control = CutPaper.new()
	knob.size = Vector2(36, 36)
	knob.corner = 18.0
	var pts: PackedVector2Array = knob._deckle_polygon(knob.size, knob.corner)
	ok(pts.size() >= 24, "a 36px round knob is sampled as a disc, not a dodecagon (%d points)" % pts.size())
	# every sampled point sits ON the circle — a density change must not move the silhouette.
	var c := Vector2(18, 18)
	var off := 0.0
	for p in pts:
		off = maxf(off, absf(p.distance_to(c) - 18.0))
	ok(off < 0.01, "…and every point still lies on the same circle, so the silhouette did not move (%.4fpx)" % off)
	knob.free()

# --- 2. every per-component override dict, found by reflection ---------------------------------------

## Every `*_CP_DEFAULTS` const the Kit carries. Reflection, not a list: the whole point is that a
## component added after this suite was written cannot slip past it. (`get_script_constant_map` is an
## instance method on Script, so the map comes off the loaded script resource, not the class name.)
func _cp_default_consts() -> Dictionary:
	var kit_script: Script = load("res://games/grove/ui_kit.gd")
	var consts: Dictionary = kit_script.get_script_constant_map()
	var out := {}
	for name in consts:
		if String(name).ends_with("_CP_DEFAULTS") and consts[name] is Dictionary:
			out[String(name)] = consts[name]
	return out

func _check_override_dicts() -> void:
	var found := _cp_default_consts()
	# a reflection-based check that found nothing is a broken check, not a clean bill of health.
	ok(found.size() >= 5, "found %d shared *_CP_DEFAULTS dicts to check (a scan finding none is a bug)" % found.size())
	for name in found:
		var d: Dictionary = found[name]
		# The correct spelling is ABSENCE: the schema owns the smooth default, so a component that names
		# the knob at all is overriding a decision it should be inheriting. Zero is tolerated (it says the
		# same thing); anything else is a tear, and a tear here needs its own feather too.
		var amp := float(d.get(AMP, 0.0))
		ok(is_equal_approx(amp, 0.0), "%s inherits the smooth edge — no tear of its own (%.2f)" % [name, amp])
		ok(not d.has(FEATHER) or float(d[FEATHER]) > 0.0,
			"%s does not switch the antialias band OFF" % name)

# --- 3. the saved config: the values that actually ship ---------------------------------------------

## Every tear-ish key a config block can carry. `inner_amp` is the slot cell's green well, whose opts are
## a hand-built literal rather than the shared knob set, so it has its own name for the same knob.
const SAVED_AMP_KEYS := ["deckle_amp", "inner_amp"]

func _check_saved_config() -> void:
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	ok(not cfg.is_empty(), "the saved kit config parses (%d blocks)" % cfg.size())
	var checked := 0
	for block in cfg:
		if not (cfg[block] is Dictionary):
			continue
		var d: Dictionary = cfg[block]
		for key in SAVED_AMP_KEYS:
			if not d.has(key):
				continue
			checked += 1
			ok(is_equal_approx(float(d[key]), 0.0),
				"saved %s.%s is a smooth cut (%.2f) — a workbench Save is how a tear comes back"
					% [block, key, float(d[key])])
		# a block that saved the feather must not have saved it OFF: the schema's default only applies to
		# a key the block never wrote, and the workbench writes every knob it has a slider for.
		if d.has(FEATHER):
			ok(float(d[FEATHER]) > 0.0,
				"saved %s.%s keeps the antialias band (%.2f)" % [block, FEATHER, float(d[FEATHER])])
	ok(checked > 0, "the saved config really does carry edge amplitudes to check (%d found)" % checked)

# --- 4. the hand-written literals in shipping source ------------------------------------------------

## Walk the shipping .gd tree for a cut-paper opts literal that spells a NON-ZERO tear — `"deckle_amp": 4`
## or `"inner_amp": 3` — or that pins the feather to zero. These dicts inherit nothing from the schema, so
## the only mechanism that can cover them is reading the source.
func _check_source_literals() -> void:
	var files := _gd_files()
	ok(files.size() > 50, "the literal scan found %d shipping scripts to read (a scan finding none is a bug)" % files.size())
	var torn: Array = []
	var unfeathered: Array = []
	for path in files:
		var txt := FileAccess.get_file_as_string(path)
		if txt == "":
			continue
		var lines := txt.split("\n")
		for i in lines.size():
			var line: String = lines[i]
			if line.strip_edges().begins_with("#"):
				continue                      # a comment quoting the old value is not a live default
			for key in SAVED_AMP_KEYS:
				var v := _literal_after(line, key)
				if v > 0.0:
					torn.append("%s:%d %s = %.1f" % [path, i + 1, key, v])
			if _mentions_zero_feather(line):
				unfeathered.append("%s:%d" % [path, i + 1])
	for hit in torn:
		if not TORN_BY_DESIGN.has(hit.split(" ")[0]):
			ok(false, "a shipping literal still spells a TORN edge — %s" % hit)
	ok(torn.is_empty() or TORN_BY_DESIGN.size() > 0,
		"no shipping cut-paper literal reintroduces the deckle (%d hits)" % torn.size())
	ok(unfeathered.is_empty(),
		"no shipping literal switches the antialias band off%s"
			% ("" if unfeathered.is_empty() else " — " + ", ".join(unfeathered)))
	# KNOWN POSITIVE. A scanner that has never fired is not a scanner; prove both matchers on text that
	# must match, so a broken regex cannot read as a clean tree.
	ok(_literal_after('	"deckle_amp": 4.0,', AMP) > 0.0, "…and the tear matcher finds a known positive")
	ok(_literal_after('		"inner_amp": float(opts.get("inner_amp", 3.0)),', "inner_amp") > 0.0,
		"…including one written as a get() fallback, which is how the well's tear was spelled")
	ok(is_equal_approx(_literal_after('	"deckle_amp": 0.0,', AMP), 0.0), "…and does not fire on a zeroed one")
	ok(_mentions_zero_feather('		"edge_feather": 0.0,'), "…and the feather matcher finds a known positive")
	ok(not _mentions_zero_feather('		"edge_feather": Paper.EDGE_FEATHER_PX,'), "…and not on the shared constant")

## The LARGEST number a source line assigns to `key`, or -1 when the line assigns it no literal at all.
## Two spellings occur in this codebase and both are live defaults: a plain dict entry (`"deckle_amp": 4`)
## and a get()-with-fallback (`float(opts.get("inner_amp", 4.0))`), where the fallback IS the value that
## ships when nothing overrode it. EVERY occurrence of the key on the line is tried, because the second
## spelling names the key twice — once as the dict key, once inside the `get` — and only the second one is
## followed by the number. Anything else (a variable, another key's value) reads as "not a literal" and is
## left to layer 5, which sees the built panel.
func _literal_after(line: String, key: String) -> float:
	var quoted := '"%s"' % key
	var num := RegEx.create_from_string("^\\s*[:,]\\s*(-?[0-9]+(?:\\.[0-9]+)?)")
	var best := -1.0
	var at := line.find(quoted)
	while at >= 0:
		var m := num.search(line.substr(at + quoted.length()))
		if m != null:
			best = maxf(best, float(m.get_string(1)))
		at = line.find(quoted, at + 1)
	return best

## Does this line pin `edge_feather` to a literal zero? That is the half of the treatment whose absence
## does not look like a bug in a diff — it looks like a knob nobody set.
func _mentions_zero_feather(line: String) -> bool:
	var v := _literal_after(line, FEATHER)
	return v >= 0.0 and is_equal_approx(v, 0.0)

func _gd_files() -> Array:
	var out: Array = []
	var stack: Array = SCAN_ROOTS.duplicate()
	while not stack.is_empty():
		var d: String = stack.pop_back()
		var skip := false
		for s in SCAN_SKIP:
			if d.begins_with(s):
				skip = true
		if skip:
			continue
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		for sub in dir.get_directories():
			stack.append(d + sub + "/")
		for f in dir.get_files():
			if f.ends_with(".gd"):
				out.append(d + f)
	return out

# --- 5. the surfaces, BUILT ------------------------------------------------------------------------

## Read the edge off a real CutPaperPanel rather than off the dict handed to it: `configure` is where an
## opts key becomes panel state, and a knob the applier forgets to consume looks perfect in layers 1-4.
func _assert_smooth(panel: Control, label: String) -> void:
	if panel == null:
		ok(false, "%s builds a cut-paper surface to check" % label)
		return
	ok(is_equal_approx(float(panel.get(AMP)), 0.0) and float(panel.get(FEATHER)) > 0.0,
		"%s — smooth cut, antialiased (amp %.2f, feather %.2fpx)"
			% [label, float(panel.get(AMP)), float(panel.get(FEATHER))])

## Every CutPaperPanel under `node`, whatever built it. A surface reached this way was not named by this
## suite, so a new sub-panel inside a checked component is covered for free.
func _panels(node: Node) -> Array:
	var out: Array = []
	var script := load(Kit.CUT_PAPER)
	for c in node.find_children("*", "Control", true, false):
		if c.get_script() == script:
			out.append(c)
	if node is Control and (node as Control).get_script() == script:
		out.append(node)
	return out

func _check_built_surfaces() -> void:
	var root := get_root()
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	# each entry is a REAL builder call, made the way the game makes it (from the saved config), so what is
	# checked is the shipping path and not a fixture. The daily card is built through `daily_opts_from_config`
	# on purpose: that reader seeds `cp` from the FRAME block, so a card built any other way would be
	# checking a knob dict the game never uses.
	var daily_opts: Dictionary = Kit.daily_opts_from_config(cfg)
	daily_opts["cut_paper"] = true      # what `daily_grid` sets: the calendar draws the CODE-DRAWN face
	# (the SHOP grid is the other daily_card caller and leaves this off — its cells are a nine-patch)
	var built := {
		"the dialog frame": Kit.dialog_frame(Label.new(), 800.0, Kit.dialog_opts_from_config(cfg)),
		"a mail / reward card": Kit.mail_card({"title": "Acorns", "body": "a note", "icon": "gem"},
			24, 20, Kit.mail_card_opts_from_config(cfg)),
		"a settings toggle row": Kit.toggle_card({"title": "Sounds", "value": true},
			Kit.toggle_card_opts_from_config(cfg)),
		"a wallet pill": Kit.gold_currency_pill(Kit.gold_currency_pill_opts_from_config(cfg)),
		"a slot cell": Kit.torn_cell(Kit.torn_cell_opts_from_config(cfg)),
		"a daily card (cream)": Kit.daily_card({"state": "future", "day": 2, "label": "Day 2",
			"reward": {"coins": 100}}, daily_opts),
		"a daily card (today, two layers)": Kit.daily_card({"state": "today", "day": 1, "label": "Day 1",
			"reward": {"coins": 50}}, daily_opts),
		"a daily card face on its own fallback cp": Kit.daily_card_face(Vector2(160, 180), "cream"),
	}
	for label in built:
		var node: Node = built[label]
		if node == null:
			ok(false, "%s builds" % label)
			continue
		root.add_child(node)
		var found := _panels(node)
		ok(not found.is_empty(), "%s draws at least one cut-paper sheet (%d)" % [label, found.size()])
		var n := 0
		for p in found:
			n += 1
			_assert_smooth(p, "%s sheet %d/%d" % [label, n, found.size()])
	# THE TOGGLE SWITCH is built by the engine skin, not the Kit, and its opts dict is the hand-written
	# fallback layer 4 scans for — so build it BOTH ways: through the config the game passes, and with the
	# empty dict that selects the literal.
	var Look := load("res://engine/scripts/ui/skin.gd")
	var cp: Dictionary = Kit.toggle_card_opts_from_config(cfg).get("cp", {})
	for pair in [["from the saved config", cp], ["on its own fallback literal", {}]]:
		var sw: Button = Look.toggle_switch(true, func(_v: bool) -> void: pass, 44.0, pair[1])
		root.add_child(sw)
		var parts := _panels(sw)
		ok(parts.size() >= 2, "the toggle switch %s draws its track and its knob (%d)" % [pair[0], parts.size()])
		for p in parts:
			_assert_smooth(p, "the toggle switch %s — %s" % [pair[0], p.name])
