extends "res://engine/tests/test_base.gd"
## Headless tests for the App Store update-check contract (core/update_check.gd) + the dismissed-version
## ledger it leans on (core/save.gd). Pure logic + local persistence, NO network.
##   godot --headless -s res://engine/tests/update_check_tests.gd

const Save = preload("res://engine/scripts/core/save.gd")
const UpdateCheck = preload("res://engine/scripts/core/update_check.gd")

# This suite's own user:// save-dir tree — kept distinct so the parallel
# runner can never let two suites clobber each other's saves.
func save_prefix() -> String:
	return "tu_updatecheck_"

# a lookup reply listing one app at `version` with a store url.
func _lookup(version: String, url: String = "https://apps.apple.com/app/id123") -> String:
	return '{"resultCount":1,"results":[{"version":"%s","trackViewUrl":"%s"}]}' % [version, url]

func _initialize() -> void:
	print("== Update check tests ==")

	# --- version_gt: dotted-numeric compare, left to right (NEWER-than, not lexical) ---
	ok(UpdateCheck.version_gt("1.2.0", "1.1.9"), "1.2.0 is newer than 1.1.9")
	ok(UpdateCheck.version_gt("1.10", "1.9"), "1.10 is newer than 1.9 (numeric, not string compare)")
	ok(not UpdateCheck.version_gt("1.2.0", "1.2.0"), "an equal version is not newer")
	ok(not UpdateCheck.version_gt("1.1.9", "1.2.0"), "an older version is not newer")
	ok(not UpdateCheck.version_gt("1.2", "1.2.0"), "1.2 equals 1.2.0 (missing components are zero) — not newer")
	ok(UpdateCheck.version_gt("1.2.1", "1.2"), "1.2.1 is newer than 1.2 (ragged, nonzero tail)")
	ok(not UpdateCheck.version_gt("garbage", "1.0.0"), "junk version compares as zero and never crashes")

	# --- evaluate: {prompt, version, url} from a lookup reply + installed + dismissed ---
	var d1: Dictionary = UpdateCheck.evaluate(_lookup("1.2.0"), "1.1.9", "")
	ok(d1.get("prompt", false), "a newer store version prompts")
	ok(String(d1.get("version", "")) == "1.2.0", "evaluate surfaces the store version")
	ok(String(d1.get("url", "")) == "https://apps.apple.com/app/id123", "evaluate surfaces the store url")

	ok(not UpdateCheck.evaluate(_lookup("1.1.9"), "1.1.9", "").get("prompt", false),
		"an equal store version does not prompt")
	ok(not UpdateCheck.evaluate(_lookup("1.0.0"), "1.1.9", "").get("prompt", false),
		"an older store version does not prompt")
	ok(not UpdateCheck.evaluate(_lookup("1.2.0"), "1.1.9", "1.2.0").get("prompt", false),
		"a store version the player already dismissed does not prompt")
	ok(UpdateCheck.evaluate(_lookup("1.3.0"), "1.1.9", "1.2.0").get("prompt", false),
		"a version newer than the dismissed one prompts again")

	ok(not UpdateCheck.evaluate("not json {{{", "1.1.9", "").get("prompt", false),
		"garbage JSON never prompts (and never crashes)")
	ok(not UpdateCheck.evaluate('{"resultCount":0,"results":[]}', "1.1.9", "").get("prompt", false),
		"an empty results list does not prompt")
	ok(not UpdateCheck.evaluate('{"results":[{"trackViewUrl":"x"}]}', "1.1.9", "").get("prompt", false),
		"a result missing its version does not prompt")

	# --- Save: the dismissed-version ledger (deep-merged over defaults → fresh save reads unset) ---
	fresh("dismiss")
	ok(Save.update_dismissed() == "", "a fresh save has no dismissed version")
	Save.mark_update_dismissed("1.2.0")
	ok(Save.update_dismissed() == "1.2.0", "marking a version persists it")
	Save.mark_update_dismissed("1.2.0")
	ok(Save.update_dismissed() == "1.2.0", "re-marking the same version is idempotent")
	Save.mark_update_dismissed("1.3.0")
	ok(Save.update_dismissed() == "1.3.0", "marking a newer version overwrites the dismissed one")

	finish()
