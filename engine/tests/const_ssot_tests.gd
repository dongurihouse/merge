extends "res://engine/tests/test_base.gd"
## Headless guard for eight constants that were each written down in more than one place.
##   godot --headless --path . -s res://engine/tests/const_ssot_tests.gd
##
## Every value below now has ONE owner. Where the duplicate could be deleted it was; where a
## deliberate copy remains (a purity constraint that is worth more than the copy costs), this
## suite is the mechanism that keeps the copy honest. A comment saying "keep these in step" is
## not a mechanism — it is a promise, and promises drift.
##
##  1. THE DESIGN CANVAS (project.godot display/window/size, owned by core/design.gd).
##     ~22 sites had re-typed 1080/1920. The worst was the UI workbench's PHONE_W/PHONE_H —
##     the tool you VERIFY layouts in would have validated against the old canvas after a
##     change, so the check would agree with itself and lie. Scan below.
##  2. THE BAG SLOT BAND (6..18). Save clamped the persisted count to a re-typed band while
##     board_logic clamped to the game's. Raising the cap in grove_data alone would have let
##     the UI offer slot 19 while set_bag_slots clamped it straight back — the player pays
##     💎 and loses the slot. Save now READS the game's band; this asserts they agree.
##  3. THE RESIDENT LADDER LENGTH (12). resident_bucket.gd is a pure leaf that preloads
##     nothing, so its copy stays deliberately; asserted here instead.
##  4. THE MARKETING VERSION (export_presets.cfg). build_info.gd's fallback was a stale
##     re-typed literal that rendered the WRONG version in the player-facing Settings dialog
##     on every unstamped build. It parses the presets file now; this asserts the agreement.
##     (tools/test_stamp_build_info.sh guards the stamp script's half, via `make test-config`.)
##  5. THE BOARD GATE GRID (MIN_LEVEL, 9x7). The const said corners open at L22 while
##     economy_tuning.json said L16, and the JSON won at runtime — so the grid the owner would
##     have re-tuned was not the grid anyone plays. The const is the SEED (content.gd:24) and the
##     absent-file fallback, so it cannot be deleted; it is re-synced and asserted instead.
##  6. THE PINNACLE TIER (8). tuning.gd spelled it twice, 18 lines apart, and neither copy is
##     PREMIUM_TIER. Moving the pinnacle would have left the reserved big-moment cues — shake, HOT
##     burst, heavy haptic — firing on an ordinary merge, with no test failing. One copy DELETED;
##     tuning.gd preloads nothing on purpose, so the other stays and is asserted (as in 3).
##  7. THE BUNDLE ID (export_presets.cfg). update_check.gd's copy is what the shipped app puts in
##     itunes.apple.com/lookup?bundleId=. A rebrand would have left the update prompt polling the
##     OLD id forever and never firing again — silently, since the check never surfaces an error.
##     It cannot read the preset the way 4 does (that file is not packed); asserted instead.
##  8. THE APP DISPLAY NAME. export_presets.cfg restated project.godot's config/name. Renaming the
##     game would have left the iOS home-screen label stale until someone read an export. Godot's
##     iOS exporter falls back to config/name when application/name is blank (verified by export),
##     so the copy is DELETED — this asserts the preset stays blank, i.e. still inheriting.

const Design = preload("res://engine/scripts/core/design.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const G = Game.DATA
const RB = preload("res://engine/scripts/core/resident_bucket.gd")
const BUILD_INFO_PATH := "res://engine/scripts/core/build_info.gd"
const BuildInfo = preload(BUILD_INFO_PATH)
const Content = preload("res://engine/scripts/core/content.gd")
const UpdateCheck = preload("res://engine/scripts/core/update_check.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").FX

const BUNDLE_KEY := "application/bundle_identifier"
const IOS_NAME_KEY := "application/name"
const PROJECT_NAME_KEY := "application/config/name"

const SCAN_ROOTS := ["res://engine/", "res://games/"]

## The design canvas' two numbers. Anything else spelling them in CODE (not a comment, not a
## string) is a re-typed canvas — read Design.size() instead.
const CANVAS_LITERALS := ["1080", "1920"]

## The ONE file allowed to name the canvas numbers: it is where they are read from ProjectSettings.
const CANVAS_OWNER := "res://engine/scripts/core/design.gd"

## Sites deliberately left as literals. One line of reason each — an entry here is a decision,
## not a backlog item. Keyed "res://path.gd@LITERAL" (NOT by line: a line-keyed exemption goes
## stale whenever anything above it shifts, and a guard that cries wolf gets switched off).
const CANVAS_ALLOWLIST := {
	"res://games/grove/tests/grove_explore_tests.gd@1080":
		"a deliberate viewport RESIZE MATRIX — it sizes the root to 1080x1920 and then to 1600x1920 to prove the rush board re-centres; the assertion constants (540, 1082) are hand-derived from that specific width, so reading it from Design would make the assertions restate themselves and stop catching a real re-centre regression",
	"res://games/grove/tests/grove_explore_tests.gd@1920":
		"same resize matrix — 1920 is the height held FIXED across both rows, which is the point of the case",
	"res://games/grove/tests/grove_scene_workbench_tests.gd@1080":
		"not the canvas: a placement's y coordinate in a fixture scene (a gate at y=1080) and the assertion that reads it back — the value coinciding with the canvas width is an accident",
}

func _initialize() -> void:
	print("== Constant single-source-of-truth guard ==")
	_check_design_canvas()
	_check_bag_band()
	_check_resident_ladder()
	_check_marketing_version()
	_check_board_gate_grid()
	_check_pinnacle_tier()
	_check_bundle_id()
	_check_app_display_name()
	finish()

# --- 1. the design canvas -----------------------------------------------------------------

func _check_design_canvas() -> void:
	var design := Design.size()
	ok(design.x > 0.0 and design.y > 0.0, "Design.size() resolves the project viewport (%.0fx%.0f)" % [design.x, design.y])
	ok(int(design.x) == int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) \
		and int(design.y) == int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)), \
		"Design.size() IS project.godot's display/window/size (not a re-typed copy)")

	var files := PackedStringArray()
	for root in SCAN_ROOTS:
		files.append_array(_gd_files_deep(root))
	ok(files.size() >= 100, "scan reaches the tree (%d .gd files under %s)" % [files.size(), ", ".join(SCAN_ROOTS)])

	# KNOWN-POSITIVE: the owner writes both numbers down (as ProjectSettings defaults). If this
	# ever drops to 0 the matcher is broken, not the tree clean — a scanner that reports nothing
	# is a bug until it has been shown finding something.
	var owner_hits := _scan_canvas(CANVAS_OWNER)
	ok(owner_hits.size() == 2, "known-positive: the owner itself yields %d canvas literals (expected 2)" % owner_hits.size())

	var offenders := PackedStringArray()
	var allowed := 0
	for p in files:
		if p == CANVAS_OWNER:
			continue
		for hit in _scan_canvas(p):
			if CANVAS_ALLOWLIST.has("%s@%s" % [p, hit.literal]):
				allowed += 1
				continue
			offenders.append("%s:%d  %s" % [p, hit.line, hit.text.strip_edges()])
	if not offenders.is_empty():
		print("  ----------------------------------------------------------------")
		print("  re-typed design-canvas numbers: %d" % offenders.size())
		for o in offenders:
			print("    ", o)
		print("  read the canvas off its owner instead — const Design = preload(\"%s\")" % CANVAS_OWNER)
		print("  then Design.size() (memoised, so a call is cheap). If the number genuinely is NOT")
		print("  the canvas, add the site to CANVAS_ALLOWLIST in this file with the reason.")
		print("  ----------------------------------------------------------------")
	ok(offenders.is_empty(), \
		"no script outside design.gd re-types the design canvas (%d offender(s), %d allowlisted)" % \
		[offenders.size(), allowed])

	# A stale exemption is a hole that silently re-opens.
	var stale := PackedStringArray()
	for key in CANVAS_ALLOWLIST:
		var parts: PackedStringArray = String(key).rsplit("@", true, 1)
		var live := false
		for hit in _scan_canvas(parts[0]):
			if String(hit.literal) == parts[1]:
				live = true
				break
		if not live:
			stale.append(key)
	ok(stale.is_empty(), "every CANVAS_ALLOWLIST entry still points at a real literal%s" % \
		("" if stale.is_empty() else " — stale: " + ", ".join(stale)))

# --- 2. the bag slot band -----------------------------------------------------------------

func _check_bag_band() -> void:
	ok(Save.BAG_MIN_SLOTS == G.BAG_START_SLOTS, \
		"the bag's slot FLOOR has one owner (Save.BAG_MIN_SLOTS %d == G.BAG_START_SLOTS %d)" % \
		[Save.BAG_MIN_SLOTS, G.BAG_START_SLOTS])
	ok(Save.BAG_MAX_SLOTS == G.BAG_MAX_SLOTS, \
		"the bag's slot CAP has one owner (Save.BAG_MAX_SLOTS %d == G.BAG_MAX_SLOTS %d)" % \
		[Save.BAG_MAX_SLOTS, G.BAG_MAX_SLOTS])
	# The price schedule is the third half of the same band: one 💎 price per PURCHASABLE slot.
	# A cap raised without a price appended offers a slot nothing can charge for.
	var prices: Array = G.BAG_SLOT_PRICES
	ok(prices.size() == G.BAG_MAX_SLOTS - G.BAG_START_SLOTS, \
		"one 💎 price per purchasable slot (%d prices for slots %d..%d)" % \
		[prices.size(), G.BAG_START_SLOTS + 1, G.BAG_MAX_SLOTS])

# --- 3. the resident ladder length --------------------------------------------------------

func _check_resident_ladder() -> void:
	ok(RB.MAX_TIER == G.RESIDENT_MAX_TIER, \
		"the resident ladder length agrees across the pure module and the game data (RB.MAX_TIER %d == G.RESIDENT_MAX_TIER %d)" % \
		[RB.MAX_TIER, G.RESIDENT_MAX_TIER])

# --- 4. the marketing version -------------------------------------------------------------

func _check_marketing_version() -> void:
	var preset := BuildInfo.preset_value(BuildInfo.MARKETING_KEY)
	ok(preset != "" and "." in preset, \
		"export_presets.cfg's %s parses to a version (%s)" % [BuildInfo.MARKETING_KEY, preset])
	ok(BuildInfo.preset_value(BuildInfo.BUILD_KEY) != "", \
		"export_presets.cfg's %s parses to a value" % BuildInfo.BUILD_KEY)
	# No stamp is present on a clean checkout (engine/generated/ is gitignored), and one IS
	# present after a release export — so assert the property that holds either way: the text
	# is never the old hardcoded literal, and unstamped it equals the preset.
	var text := BuildInfo.version_text()
	ok(text != "", "BuildInfo.version_text() is never blank (%s)" % text)
	var stamped := FileAccess.file_exists(BuildInfo.GENERATED_PATH)
	if stamped:
		ok(true, "a stamp is present (%s) — the presets fallback is not the live path here" % BuildInfo.GENERATED_PATH)
	else:
		ok(text == preset, \
			"unstamped, the player-facing version IS the shipping preset (%s == %s)" % [text, preset])
	# The runtime must not re-type a version literal — that is exactly what shipped a stale
	# "Version 1.1.9" into the Settings dialog long after the preset moved on.
	var src := _read(BUILD_INFO_PATH)
	var re := RegEx.create_from_string("const\\s+(MARKETING_VERSION|BUILD_NUMBER)\\s*:?=\\s*\"[0-9]")
	ok(src != "" and re.search(src) == null, \
		"build_info.gd names no version literal of its own — it reads export_presets.cfg")

# --- 5. the board gate grid ---------------------------------------------------------------

## Content.MIN_LEVEL is seeded from the game data const and then OVERWRITTEN by the active game's
## economy_tuning.json at class load (content.gd _static_init -> apply_tuning). The const is the
## absent-file fallback, so it must SPELL the shipped grid — otherwise deleting the JSON silently
## re-paces the first hour of the game, and the grid the owner reads is not the grid anyone plays.
## Out of reach: docs/economy_tuning.html's GRID0, the tool that GENERATES the JSON. Nothing here can
## see it, so a pairing of the const and the JSON still leaves the tool free to re-introduce the
## drift — that copy is held by a comment on GRID0 itself, which is weaker on purpose and worth
## knowing about.
func _check_board_gate_grid() -> void:
	var path: String = Content.TUNING_PATH % Game.active()
	ok(FileAccess.file_exists(path), "the active game ships a tuning file (%s)" % path)

	# KNOWN-POSITIVE: the equality below is VACUOUS when the JSON does not apply the key — an absent,
	# malformed or mis-shaped grid leaves Content.MIN_LEVEL as the const's own seed, and the two agree
	# for the wrong reason. apply_tuning names the keys it actually took, so this proves the check is
	# looking at a live override and not at itself.
	var applied := Content.apply_tuning(path)
	ok(applied.has("min_level"), \
		"known-positive: %s really applies min_level (applied: %s)" % [path, ", ".join(applied)])

	ok(Content.MIN_LEVEL == G.MIN_LEVEL, \
		"the board gate grid has one shape: the JSON override IS the game-data fallback (corners L%s == L%s)" % \
		[Content.MIN_LEVEL[0][0], G.MIN_LEVEL[0][0]])

	# The shape the engine requires. _coerce_grid drops a mis-shaped grid (loudly, now); this catches
	# the same mistake in the committed file before a player's board silently falls back.
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var grid: Variant = (parsed as Dictionary).get("min_level", null) if parsed is Dictionary else null
	var rows: int = (grid as Array).size() if grid is Array else -1
	var bad := PackedStringArray()
	if grid is Array:
		for i in (grid as Array).size():
			var row: Variant = (grid as Array)[i]
			if not (row is Array) or (row as Array).size() != int(G.COLS):
				bad.append("row %d" % i)
	ok(rows == int(G.ROWS) and bad.is_empty(), \
		"%s's min_level is %d x %s (expected %d x %d)%s" % \
		[path, rows, "%d" % int(G.COLS) if bad.is_empty() else "ragged", int(G.ROWS), int(G.COLS), \
		"" if bad.is_empty() else " — wrong width: " + ", ".join(bad)])

# --- 6. the pinnacle tier -------------------------------------------------------------------

## ESCALATE_TIER gates the RESERVED big-moment vocabulary (shake, HOT burst, heavy haptic —
## feel.gd, merge_fx.gd). It is the game's PREMIUM_TIER, restated as a literal because tuning.gd
## preloads nothing on purpose: it declares itself the ENGINE's game-independent defaults, and
## reading Game.DATA there would make the engine's tuning leaf game-dependent — the same trade
## resident_bucket.gd refused in 3. So it stays a copy, and this is the mechanism.
func _check_pinnacle_tier() -> void:
	ok(Tune.ESCALATE_TIER == G.PREMIUM_TIER, \
		"the reserved big-moment cues fire at the PINNACLE tier (Tune.FX.ESCALATE_TIER %d == G.PREMIUM_TIER %d)" % \
		[Tune.ESCALATE_TIER, G.PREMIUM_TIER])

# --- 7. the bundle id -----------------------------------------------------------------------

## export_presets.cfg owns it; update_check.gd copies it because that file is an EDITOR artifact and
## is not packed into the export (only resource types survive the all_resources filter), while
## update_check.check() runs only on iOS — i.e. only from the shipped build, where a parse would
## resolve to "". 4's fallback is safe because a release also stamps engine/generated/build_info.gd,
## which does ship; there is no such stamp here. tools/asc_lib.sh holds a third copy that fails
## LOUDLY (a wrong id aborts the upload), so it is self-announcing and left alone.
func _check_bundle_id() -> void:
	var preset := BuildInfo.preset_value(BUNDLE_KEY)
	ok(preset != "" and "." in preset, \
		"export_presets.cfg's %s parses to a bundle id (%s)" % [BUNDLE_KEY, preset])
	ok(UpdateCheck.BUNDLE_ID == preset, \
		"the App Store lookup polls the SHIPPING bundle id (update_check %s == preset %s)" % \
		[UpdateCheck.BUNDLE_ID, preset])

# --- 8. the app display name ----------------------------------------------------------------

## project.godot's config/name is the one owner. Godot's iOS exporter falls back to it when the
## preset's application/name is blank — verified by exporting with a renamed config/name and reading
## INFOPLIST_KEY_CFBundleDisplayName back out of the generated Xcode project — so the preset's copy
## was deleted rather than asserted. This holds the deletion: refill application/name and the
## home-screen label stops tracking the game's name, which is only visible at export time.
func _check_app_display_name() -> void:
	var project_name := String(ProjectSettings.get_setting(PROJECT_NAME_KEY, ""))
	ok(project_name != "", "project.godot names the app (%s == %s)" % [PROJECT_NAME_KEY, project_name])
	ok(BuildInfo.preset_value(IOS_NAME_KEY) == "", \
		"export_presets.cfg's %s stays BLANK so the iOS label inherits %s (\"%s\")" % \
		[IOS_NAME_KEY, PROJECT_NAME_KEY, BuildInfo.preset_value(IOS_NAME_KEY)])

# --- scanning ------------------------------------------------------------------------------

func _gd_files_deep(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + f)
	for sub in d.get_directories():
		out.append_array(_gd_files_deep(dir + sub + "/"))
	return out

func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t

## Every canvas literal in `path` that survives comment + string stripping, as {line, literal, text}.
## The lookaround excludes identifiers (cx1080), longer numbers (21080, 10800) and decimal tails
## (0.1080) while still catching 1080.0 — the float spelling most call sites used.
func _scan_canvas(path: String) -> Array:
	var out: Array = []
	var text := _read(path)
	if text == "":
		return out
	var re := RegEx.create_from_string("(?<![0-9._A-Za-z])(%s)(?![0-9_A-Za-z])" % "|".join(CANVAS_LITERALS))
	var line_no := 0
	var in_doc := false
	for raw_line in text.split("\n"):
		line_no += 1
		var stripped := _strip_comments_and_strings(raw_line, in_doc)
		in_doc = bool(stripped.in_doc)
		for m in re.search_all(String(stripped.code)):
			out.append({"line": line_no, "literal": m.get_string(1), "text": raw_line})
	return out

## Drop `# comments` and blank the CONTENTS of string literals, so neither can look like code.
## Triple-quoted blocks are tracked across lines (`in_doc`); a `"""` toggles the state.
func _strip_comments_and_strings(line: String, in_doc: bool) -> Dictionary:
	var out := ""
	var quote := ""
	var i := 0
	while i < line.length():
		if in_doc:
			if line.substr(i, 3) == "\"\"\"":
				in_doc = false
				i += 3
				continue
			i += 1
			continue
		if quote != "":
			if line[i] == "\\":
				i += 2
				continue
			if line[i] == quote:
				quote = ""
			i += 1
			continue
		if line.substr(i, 3) == "\"\"\"":
			in_doc = true
			i += 3
			continue
		var c := line[i]
		if c == "\"" or c == "'":
			quote = c
			i += 1
			continue
		if c == "#":
			break
		out += c
		i += 1
	return {"code": out, "in_doc": in_doc}
