extends SceneTree
## Isolated contract tests for Meadow Sky palette roles and atlas routing.
## This suite deliberately avoids constructing Board/Map/UI scenes so it remains useful while
## grove_ui_tests has unrelated storefront/layout failures.

const Pal = preload("res://games/grove/grove_palette.gd")
const MAPPING_PATH := "res://games/grove/assets/ui/meadow_v2/canonical_mapping.json"
const MANIFEST_PATH := "res://games/grove/assets/ui/meadow_v2/manifest.json"
const SUITE_PATH := "games/grove/tests/grove_palette_routing_tests"
const FIXED_CONSUMERS := {
	"map/left_card_frame_large.png": {"min_aspect": 1.1, "contract": "landscape map frame"},
	"map/left_locked_preview.png": {"min_aspect": 1.1, "contract": "landscape map preview"},
}
const MEADOW_FOREGROUND_CONSUMERS := [
	"shared/disc_round.png",
	"shared/badge_rect.png",
	"shared/play_disc.png",
	"kit/level_frame.png",
	"rush/exit_x.png",
]

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _assert_color(name: String, actual: Color, expected_hex: String) -> void:
	ok(actual == Color(expected_hex), "%s is fixed Meadow Sky %s (got %s)" % [name, expected_hex, actual.to_html(false)])

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		ok(false, "%s opens" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	ok(parsed is Dictionary, "%s parses as a JSON object" % path)
	return parsed as Dictionary if parsed is Dictionary else {}

func _assert_route(source_name: String, canonical_rel: String) -> void:
	var source := "res://games/grove/assets/ui/meadow_v2/%s" % source_name
	var canonical := "res://games/grove/assets/ui/%s" % canonical_rel
	ok(FileAccess.file_exists(canonical), "%s canonical resource exists" % canonical_rel)
	if FileAccess.file_exists(canonical):
		ok(FileAccess.get_sha256(canonical) == FileAccess.get_sha256(source),
			"%s routes meadow_v2/%s without divergence" % [canonical_rel, source_name])
		ok(ResourceLoader.exists(canonical), "%s is imported as a Godot resource" % canonical_rel)

func _active_grove_suite_line() -> String:
	var f := FileAccess.open("res://Makefile", FileAccess.READ)
	if f == null:
		return ""
	for line in f.get_as_text().split("\n"):
		if line.begins_with("GROVE_TESTS  :="):
			return line
	return ""

func _initialize() -> void:
	print("== Grove Meadow Sky palette/routing tests ==")

	var palette_roles := {
		"CREAM": [Pal.CREAM, "F6EBDD"], "STRAW": [Pal.STRAW, "D6A94C"],
		"INK": [Pal.INK, "243B4B"], "BARK": [Pal.BARK, "3F6D7D"],
		"SKY": [Pal.SKY, "6FA9C0"], "MEADOW": [Pal.MEADOW, "A8D3B9"],
		"LEAF": [Pal.LEAF, "5F9B6D"], "CLAY": [Pal.CLAY, "D87865"],
		"GROUND": [Pal.GROUND, "F6EBDD"], "GROUND_EDGE": [Pal.GROUND_EDGE, "3F6D7D"],
		"BRAMBLE_BG": [Pal.BRAMBLE_BG, "8296AF"], "BRAMBLE_EDGE": [Pal.BRAMBLE_EDGE, "3F6D7D"],
		"BG": [Pal.BG, "6FA9C0"], "BG_DEEP": [Pal.BG_DEEP, "3F6D7D"],
		"TEXT": [Pal.TEXT, "F6EBDD"], "TEXT_MUTED": [Pal.TEXT_MUTED, "8296AF"],
		"GOLD": [Pal.GOLD, "D6A94C"], "COIN_EDGE": [Pal.COIN_EDGE, "3F6D7D"],
		"PLANK": [Pal.PLANK, "3F6D7D"], "PLANK_EDGE": [Pal.PLANK_EDGE, "243B4B"],
		"PILL": [Pal.PILL, "F6EBDD"], "PILL_EDGE": [Pal.PILL_EDGE, "3F6D7D"],
		"BTN_PRIMARY": [Pal.BTN_PRIMARY, "5F9B6D"], "BTN_PRIMARY_EDGE": [Pal.BTN_PRIMARY_EDGE, "3F6D7D"],
		"SCREEN_BG": [Pal.SCREEN_BG, "6FA9C0"], "SURFACE": [Pal.SURFACE, "F6EBDD"],
		"SURFACE_FRAME": [Pal.SURFACE_FRAME, "3F6D7D"], "CELL_EMPTY": [Pal.CELL_EMPTY, "A8D3B9"],
		"LOCKED": [Pal.LOCKED, "8296AF"], "LOCKED_GLYPH": [Pal.LOCKED_GLYPH, "3F6D7D"],
		"NEAR_UNLOCK": [Pal.NEAR_UNLOCK, "6FA9C0"], "NEAR_HINT": [Pal.NEAR_HINT, "5F9B6D"],
		"CARD_PEDESTAL": [Pal.CARD_PEDESTAL, "F6EBDD"], "INK_MUTED": [Pal.INK_MUTED, "3F6D7D"],
		"ACCENT_CTA": [Pal.ACCENT_CTA, "5F9B6D"], "ACCENT_REWARD": [Pal.ACCENT_REWARD, "D6A94C"],
		"ACCENT_ALERT": [Pal.ACCENT_ALERT, "D87865"], "ACCENT_INFO": [Pal.ACCENT_INFO, "6FA9C0"],
	}
	for role in palette_roles:
		_assert_color(role, palette_roles[role][0], palette_roles[role][1])
	ok(not Pal.NEAR_UNLOCK.is_equal_approx(Pal.CELL_EMPTY),
		"near-unlock frontier is visually distinct from an empty meadow cell")

	var mapping := _load_json(MAPPING_PATH)
	var manifest := _load_json(MANIFEST_PATH)
	var routes: Dictionary = mapping.get("source_to_canonical", {})
	var consumer_contracts: Dictionary = mapping.get("consumer_contracts", {})
	ok(not routes.is_empty(), "canonical mapping contains routes")
	ok(not consumer_contracts.is_empty(), "canonical mapping declares target consumer contracts")

	var source_policies := {}
	for asset in manifest.get("assets", []):
		if asset is Dictionary:
			source_policies[String(asset.get("path", ""))] = String(asset.get("policy", ""))
	var mapped_targets := {}
	for source_name in routes:
		ok(source_policies.has(source_name), "%s is declared in the Meadow atlas manifest" % source_name)
		var source_policy := String(source_policies.get(source_name, ""))
		for canonical_rel in routes[source_name]:
			canonical_rel = String(canonical_rel)
			mapped_targets[canonical_rel] = source_name
			_assert_route(source_name, canonical_rel)
			var accepted := false
			var matched_contract := false
			for pattern in consumer_contracts:
				if canonical_rel.match(String(pattern)):
					matched_contract = true
					accepted = source_policy in consumer_contracts[pattern]
					if accepted:
						break
			ok(matched_contract, "%s has a declared consumer contract" % canonical_rel)
			ok(accepted, "%s accepts Meadow source policy %s" % [canonical_rel, source_policy])

	for canonical_rel in FIXED_CONSUMERS:
		var fixed: Dictionary = FIXED_CONSUMERS[canonical_rel]
		ok(not mapped_targets.has(canonical_rel), "%s remains legacy-only (%s)" % [canonical_rel, fixed.contract])
		var path := "res://games/grove/assets/ui/%s" % canonical_rel
		var tex := load(path) as Texture2D
		ok(tex != null, "%s legacy consumer texture loads" % canonical_rel)
		if tex != null:
			var aspect := float(tex.get_width()) / maxf(1.0, float(tex.get_height()))
			ok(aspect >= float(fixed.min_aspect), "%s preserves %s aspect (%.2f)" % [canonical_rel, fixed.contract, aspect])

	for canonical_rel in MEADOW_FOREGROUND_CONSUMERS:
		ok(mapped_targets.has(canonical_rel), "%s is replaced by a declared Meadow v2 route" % canonical_rel)
	var export_text := FileAccess.get_file_as_string("res://export_presets.cfg")
	ok(export_text.contains("games/grove/assets/_review/**"),
		"export preset excludes generated Meadow QC review artifacts")
	ok(not DirAccess.dir_exists_absolute("res://games/grove/assets/ui/meadow_v2/qc"),
		"production Meadow resource tree contains no QC montage directory")

	ok(_active_grove_suite_line().contains(SUITE_PATH),
		"palette/routing contract is part of active GROVE_TESTS")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
