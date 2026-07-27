extends "res://engine/tests/test_base.gd"
## Headless guard for the PALETTE single-source-of-truth invariant.
##   godot --headless --path . -s res://engine/tests/palette_ssot_tests.gd
##
## games/<name>/grove_palette.gd declares itself the one place the game's colours are
## written down; every other script is supposed to read them as Game.PALETTE (Pal.INK,
## Pal.CREAM, …). The rule was documented but never enforced, so ~39 re-typed hex
## literals accumulated across engine/ and games/ — the same value spelled twice in the
## SAME file in two cases (giver_stand.gd aliased CREAM on one line and hardcoded
## "#F6EBDD" eleven lines later). They were swept onto the palette constants and this
## scan now FAILS on a new one.
##
## What is scanned: every .gd under engine/ and games/, for a 6-digit hex STRING LITERAL —
## `Color("#RRGGBB")`, `"#RRGGBB"`, or the bare `"RRGGBB"` form — whose hex equals one of the
## palette's ROLE values. Nothing else — the tree carries ~200 Color("#…") literals and the
## large majority are genuine one-off colours (the measured mock tones, the warm-gold
## unlockable rim, the purple/kraft paper roles …); those are none of this guard's business.
## Comment text doesn't count, matching the comment-stripping the layering guard's scans
## already do.
##
## The bare form is scanned because it is the same duplication wearing a different coat, and
## it hid five sites for months: `const PROGRESS_FILL_HEX := "5F9B6D"` carried the comment
## `# Pal.LEAF` on its own line, and two `Color.from_string("#" + cfg.get(k, "3F6D7D"), Pal.BARK)`
## calls spelled the colour TWICE on one line — a re-typed hex default beside the Pal fallback
## that already holds it. A value equal to a role is the whole match condition, so an asset id,
## a hash or a uid fragment cannot trip it unless it happens to BE a palette colour.
##
## Fixing an offender: read the colour off the palette instead — `const Pal = Game.PALETTE`
## then `Pal.<ROLE>`, or a semantic alias (Pal.SURFACE / Pal.LOCKED / Pal.GOLD /
## Pal.SCREEN_BG / Pal.CELL_EMPTY) where that reads truer at the call site. An alpha
## variant is Color(Pal.BARK, 0.35), not a re-typed "#3F6D7D". Where a STRING is genuinely
## needed (a config default that round-trips as hex text), write `Pal.<ROLE>.to_html(false)`.

const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

const SCAN_ROOTS := ["res://engine/", "res://games/"]

## The palette's ROLE constants — the names whose VALUES define a duplicate. Aliases
## (SURFACE, LOCKED, GOLD, SCREEN_BG, CELL_EMPTY, BG, PLANK, …) resolve to these same
## values, so listing the roles once covers every alias too.
const ROLE_NAMES := ["CREAM", "STRAW", "INK", "BARK", "SKY", "MEADOW", "LEAF", "CLAY", "BRAMBLE_BG"]

## Sites deliberately left as literals. One line of reason each — an entry here is a
## decision, not a backlog item. Keyed "res://path.gd:LINE".
const ALLOWLIST := {
	"res://games/grove/tests/grove_explore_tests.gd@INK":
		"pins the Rush hint's ink text colour independently — reading it from Pal would make the assertion restate itself and stop catching a palette-role swap",
	"res://games/grove/tests/grove_ui_workbench_tests.gd@STRAW":
		"pins that a workbench-saved fill_color override round-trips to that exact hex; the value being STRAW is incidental to what the test proves",
}

## The palette script itself — the one file that IS allowed to write the hex down.
func _owner_path() -> String:
	var script: GDScript = Pal
	return script.resource_path

# The walk and the slurp are test_base.gd's gd_files(dir, deep) / read_text(path) — one
# coverage function for every guard.

## hex (uppercase, no "#") -> role name, for every role the active palette declares.
func _role_by_hex() -> Dictionary:
	var script: GDScript = Pal
	var consts: Dictionary = script.get_script_constant_map()
	var by_hex := {}
	for name in ROLE_NAMES:
		var c: Color = consts.get(name, Color.BLACK)
		by_hex[c.to_html(false).to_upper()] = name
	return by_hex

func _initialize() -> void:
	print("== Palette single-source-of-truth guard ==")
	var by_hex := _role_by_hex()
	ok(by_hex.size() == ROLE_NAMES.size(), \
		"the active palette declares %d distinct role values (%d names)" % [by_hex.size(), ROLE_NAMES.size()])

	var owner := _owner_path()
	var files := PackedStringArray()
	for root in SCAN_ROOTS:
		files.append_array(gd_files(root))
	ok(files.size() >= 100, "scan reaches the tree (%d .gd files under %s)" % [files.size(), ", ".join(SCAN_ROOTS)])

	# The guard can only be trusted if it can SEE the owner's own literals — if this
	# drops to 0 the matcher is broken, not the tree clean.
	var owner_hits := _scan(owner, by_hex).size()
	ok(owner_hits == ROLE_NAMES.size(), \
		"known-positive: the palette file itself yields %d role literals (expected %d)" % [owner_hits, ROLE_NAMES.size()])

	var offenders := PackedStringArray()
	var allowed := 0
	for p in files:
		if p == owner:
			continue
		for hit in _scan(p, by_hex):
			var key: String = "%s@%s" % [p, hit.role]
			if ALLOWLIST.has(key):
				allowed += 1
				continue
			offenders.append("%s:%d  %s == Pal.%s" % [p, hit.line, hit.text, hit.role])
	if not offenders.is_empty():
		print("  ----------------------------------------------------------------")
		print("  re-typed palette colours: %d" % offenders.size())
		for o in offenders:
			print("    ", o)
		print("  read the colour off the palette instead (const Pal = Game.PALETTE; Pal.<ROLE>),")
		print("  or add the site to ALLOWLIST in this file with the reason it must stay a literal.")
		print("  ----------------------------------------------------------------")
	ok(offenders.is_empty(), \
		"no script outside %s re-types a palette role's hex (%d offender(s), %d allowlisted)" % \
		[owner.get_file(), offenders.size(), allowed])

	# Every allowlist entry must still point at a real literal — a stale exemption is a
	# hole that silently re-opens. Keyed by file@ROLE, NOT file:line — a line-keyed allowlist
	# goes stale whenever anything ABOVE it shifts (a concurrent merge did exactly that), and a
	# guard that cries wolf on unrelated edits is a guard someone eventually switches off.
	var stale := PackedStringArray()
	for key in ALLOWLIST:
		var parts: PackedStringArray = String(key).rsplit("@", true, 1)
		var path: String = parts[0]
		var role: String = parts[1]
		var live := false
		for hit in _scan(path, by_hex):
			if String(hit.role) == role:
				live = true
				break
		if not live:
			stale.append(key)
	ok(stale.is_empty(), "every ALLOWLIST entry still points at a palette-role literal%s" % \
		("" if stale.is_empty() else " — stale: " + ", ".join(stale)))
	finish()

## Every palette-role hex literal in `path`, as {line, hex, role, text}. One regex covers
## all three spellings — the optional `#` makes `Color("#F6EBDD")`, a standalone `"#F6EBDD"`
## and a bare `"F6EBDD"` the same match — and the role-value test is what keeps it from
## reporting hex-shaped strings that are not colours. Comment text is stripped first; a `#`
## inside the quoted hex is not a comment start, so the split happens on the first `#` that
## is NOT preceded by a quote.
func _scan(path: String, by_hex: Dictionary) -> Array:
	var out: Array = []
	var text := read_text(path)
	if text == "":
		return out
	var re := RegEx.create_from_string("\"#?([0-9A-Fa-f]{6})\"")
	var line_no := 0
	for raw_line in text.split("\n"):
		line_no += 1
		var line := _strip_comment(raw_line)
		for m in re.search_all(line):
			var hex := m.get_string(1).to_upper()
			if by_hex.has(hex):
				out.append({"line": line_no, "hex": hex, "role": by_hex[hex], "text": m.get_string(0)})
	return out

## Drop a trailing `# comment`, keeping `Color("#RRGGBB")` intact (the `#` there is
## inside a string literal, always immediately after a double quote).
func _strip_comment(line: String) -> String:
	var i := 0
	while i < line.length():
		if line[i] == "#" and (i == 0 or line[i - 1] != "\""):
			return line.substr(0, i)
		i += 1
	return line
