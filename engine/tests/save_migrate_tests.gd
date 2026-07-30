extends "res://engine/tests/test_base.gd"
## Headless tests for core/save_migrate.gd (load-time save hygiene + the above-level content purge)
## and for the DISCOVERY LOG half of core/quests.gd (mark_seen / lowest_seen_code / ladder_header)
## plus content.gd's gen_made_line (the generator → its line rule the board's ⓘ opens). Both clusters
## lived inside engine/scripts/scenes/board.gd until 2026-07-26, where they were reachable only by
## booting a whole Control — and they are the code most likely to silently eat a player's save.
## board.gd now keeps thin wrappers (`_purge_above_level_content`, `_mark_seen`, `_gen_line`,
## `_ladder_entries`) that only supply the scene's run-state / the Save read.
##   godot --headless --path . -s res://engine/tests/save_migrate_tests.gd
##
## Content-derived, not content-hardcoded: every line / code / level below is looked up off the live
## roster at runtime, so a pacing re-tune moves the fixtures instead of turning the suite red.

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const SaveMigrate = preload("res://engine/scripts/core/save_migrate.gd")
const Quests = preload("res://engine/scripts/core/quests.gd")

func save_prefix() -> String:
	return "tsm_"

# A code no roster line can ever claim — is_valid_item_code's LINES.has() arm rejects it.
const UNKNOWN_CODE := 999 * 100 + 1

# The lowest level at which NO base line is gated out, and a level at which at least one IS.
# Derived so the purge fixtures follow the cadence rather than pinning a number to it.
func _gated_line_at(level: int) -> int:
	for l in G.ZONE_BASE_LINES:
		if G.line_gated_out(int(l), level):
			return int(l)
	return 0

func _open_line_at(level: int) -> int:
	for l in G.ZONE_BASE_LINES:
		if not G.line_gated_out(int(l), level):
			return int(l)
	return 0

func _initialize() -> void:
	print("== save_migrate + discovery log ==")
	fresh("save_migrate")
	_test_sanitize_item_bag()
	_test_quest_items_are_known()
	_test_sanitize_quests()
	_test_sanitize_seen()
	_test_quest_line_gated_out()
	_test_purge()
	_test_discovery_log()
	_test_ladder_header()
	finish()

# --- sanitizers ---------------------------------------------------------------------------------

func _test_sanitize_item_bag() -> void:
	var good := int(G.ZONE_BASE_LINES[0]) * 100 + 1
	ok(G.is_valid_item_code(good), "fixture: line %d t1 is a valid item code" % int(G.ZONE_BASE_LINES[0]))
	ok(not G.is_valid_item_code(UNKNOWN_CODE), "fixture: %d is NOT a valid item code" % UNKNOWN_CODE)

	var clean := SaveMigrate.sanitize_item_bag([good, good])
	ok(clean["items"] == [good, good], "a bag of valid codes survives verbatim")
	ok(not bool(clean["changed"]), "an already-clean bag reports changed=false — no needless re-persist")

	var dirty := SaveMigrate.sanitize_item_bag([good, UNKNOWN_CODE, 0, -5, good])
	ok(dirty["items"] == [good, good], "unknown codes, 0 and negatives are dropped; ORDER of the survivors holds")
	ok(bool(dirty["changed"]), "a dropped code reports changed=true → the caller re-persists")

	var empty := SaveMigrate.sanitize_item_bag([])
	ok(empty["items"].is_empty() and not bool(empty["changed"]), "an empty bag is clean, not 'changed'")

	# Godot's JSON reload hands ints back as floats — the int() cast must absorb that.
	var floaty := SaveMigrate.sanitize_item_bag([float(good)])
	ok(floaty["items"] == [good] and not bool(floaty["changed"]), "a float-typed saved code (JSON round-trip) is kept, not purged")

# --- quest ask validation -----------------------------------------------------------------------

func _test_quest_items_are_known() -> void:
	var line := int(G.ZONE_BASE_LINES[0])
	ok(SaveMigrate.quest_items_are_known({"line": line, "tier": 1}), "single-ask shape: a rostered {line,tier} is known")
	ok(not SaveMigrate.quest_items_are_known({"line": 999, "tier": 1}), "single-ask shape: an unrostered line is NOT known")
	ok(SaveMigrate.quest_items_are_known({"asks": [{"line": line, "tier": 1}, {"line": line, "tier": 2}]}),
		"asks[] shape: every rostered entry is known")
	ok(not SaveMigrate.quest_items_are_known({"asks": [{"line": line, "tier": 1}, {"line": 999, "tier": 1}]}),
		"asks[] shape: ONE unrostered entry condemns the whole quest")
	ok(SaveMigrate.quest_items_are_known({"asks": ["junk", 7]}),
		"asks[] shape: non-dictionary entries are SKIPPED, not treated as unknown (the shipped guard)")
	ok(SaveMigrate.quest_items_are_known({"gate": true}),
		"a quest with neither `line` nor `asks` (gate / grant stands) is known by default")
	# `line` wins over `asks` when a quest somehow carries both — the shipped early return.
	ok(not SaveMigrate.quest_items_are_known({"line": 999, "tier": 1, "asks": [{"line": line, "tier": 1}]}),
		"`line` short-circuits `asks` when both are present")

func _test_sanitize_quests() -> void:
	var line := int(G.ZONE_BASE_LINES[0])
	var good := {"line": line, "tier": 1, "reward": {"coins": 3}}
	var clean := SaveMigrate.sanitize_quests([good])
	ok(clean["quests"].size() == 1 and not bool(clean["changed"]), "a clean fence survives unchanged")
	ok(clean["quests"][0] == good, "the surviving quest dictionary is the SAME entry, not a rebuilt copy")

	var dirty := SaveMigrate.sanitize_quests([good, "not a dict", {"line": 999, "tier": 1}, good])
	ok(dirty["quests"].size() == 2, "a non-dictionary entry and an unrostered ask are both dropped")
	ok(bool(dirty["changed"]), "either kind of drop reports changed=true")
	ok(SaveMigrate.sanitize_quests([]).get("quests").is_empty(), "an empty fence sanitizes to an empty fence")

# --- the discovery set --------------------------------------------------------------------------

func _test_sanitize_seen() -> void:
	var good := int(G.ZONE_BASE_LINES[0]) * 100 + 1
	var no_key := {}
	ok(not SaveMigrate.sanitize_seen(no_key), "a save with no `seen` key is not dirty")
	ok(not no_key.has("seen"), "...and sanitize does NOT create the key (no spurious re-persist)")

	var wrong_type := {"seen": [1, 2, 3]}
	ok(SaveMigrate.sanitize_seen(wrong_type), "a non-dictionary `seen` is dirty")
	ok(wrong_type["seen"] is Dictionary and (wrong_type["seen"] as Dictionary).is_empty(),
		"...and is RESET to an empty dictionary in place")

	var clean := {"seen": {str(good): true}}
	ok(not SaveMigrate.sanitize_seen(clean), "an all-valid seen set is not dirty")
	ok(clean["seen"].has(str(good)), "...and is left untouched")

	var retired_popup_key := "rush" + "_intro_seen"
	var retired_popup := {"seen": {str(good): true}, retired_popup_key: 1}
	ok(SaveMigrate.sanitize_seen(retired_popup), "the retired Rush popup key makes an old grove save dirty")
	ok(not retired_popup.has(retired_popup_key), "...and the retired Rush popup key is erased in place")
	ok(not SaveMigrate.sanitize_seen(retired_popup), "the Rush popup key removal is idempotent")

	var dirty := {"seen": {str(good): true, "banana": true, str(UNKNOWN_CODE): true}}
	ok(SaveMigrate.sanitize_seen(dirty), "a non-integer key or a retired code makes the seen set dirty")
	var out: Dictionary = dirty["seen"]
	ok(out.size() == 1 and out.has(str(good)), "only the still-valid code survives")
	ok(not SaveMigrate.sanitize_seen(dirty), "sanitize_seen is IDEMPOTENT — a second pass is clean")

# --- the above-level purge ----------------------------------------------------------------------

func _test_quest_line_gated_out() -> void:
	var gated := _gated_line_at(1)
	ok(gated > 0, "fixture: at least one base line is gated out at L1 (found line %d)" % gated)
	var open_line := _open_line_at(1)
	ok(open_line > 0, "fixture: at least one base line is available at L1 (found line %d)" % open_line)

	ok(SaveMigrate.quest_line_gated_out({"line": gated, "tier": 1}, 1), "single-ask shape: a too-advanced line is gated out")
	ok(not SaveMigrate.quest_line_gated_out({"line": open_line, "tier": 1}, 1), "single-ask shape: an in-cadence line is not")
	ok(SaveMigrate.quest_line_gated_out({"asks": [{"line": open_line, "tier": 1}, {"line": gated, "tier": 1}]}, 1),
		"asks[] shape: ONE too-advanced entry gates the whole quest out")
	ok(not SaveMigrate.quest_line_gated_out({"asks": ["junk"]}, 1), "asks[] shape: a non-dictionary entry never gates")
	ok(not SaveMigrate.quest_line_gated_out({"line": G.COIN_LINE, "tier": 1}, 1),
		"coins are content-neutral (zone_of_line == -1) and are NEVER gated out")

func _test_purge() -> void:
	var gated := _gated_line_at(1)
	var open_line := _open_line_at(1)
	var gated_code := gated * 100 + 1
	var open_code := open_line * 100 + 1

	# --- a save already consistent with the cadence is untouched ---
	var clean_board := BoardModel.new()
	var clean_bag: Array = [open_code]
	var clean_quests: Array = [{"line": open_line, "tier": 1}]
	var clean := SaveMigrate.purge_above_level_content(clean_board, clean_bag, clean_quests, 1)
	ok(not bool(clean["changed"]), "an in-cadence save purges NOTHING — changed=false, so no re-persist")
	ok(clean["bag"] == clean_bag and clean["quests"] == clean_quests, "...and the bag + fence come back intact")

	# --- board pieces ---
	var b := BoardModel.new()
	var open_cell: Vector2i = b.empty_ground_cells()[0]
	var keep_cell: Vector2i = b.empty_ground_cells()[1]
	b.place(open_cell, gated_code)
	b.place(keep_cell, open_code)
	var r := SaveMigrate.purge_above_level_content(b, [], [], 1)
	ok(bool(r["changed"]), "a too-advanced board piece makes the purge report changed")
	ok(b.item_at(open_cell) == 0, "the too-advanced piece is taken off the board")
	ok(b.item_at(keep_cell) == open_code, "the in-cadence piece stays")

	# --- live generators: gated out, but accumulators exempt ---
	var gb := BoardModel.new()
	gb.gens.clear()
	var gcell: Vector2i = gb.empty_ground_cells()[0]
	var acell: Vector2i = gb.empty_ground_cells()[1]
	var gated_gid := G.gen_for_line(gated)
	ok(gated_gid != "", "fixture: the gated line has a generator id (%s)" % gated_gid)
	gb.place_gen(gated_gid, gcell)
	var acc_kinds: Array = G.ACCUMULATORS.keys()
	ok(not acc_kinds.is_empty(), "fixture: the roster has at least one accumulator kind")
	var acc_id := String((G.ACCUMULATORS[acc_kinds[0]] as Dictionary).get("id", ""))
	gb.place_gen(acc_id, acell)
	var gr := SaveMigrate.purge_above_level_content(gb, [], [], 1)
	ok(bool(gr["changed"]), "a too-advanced live generator makes the purge report changed")
	ok(not gb.gens.has(gcell), "the too-advanced generator is removed from the board")
	ok(gb.gens.has(acell) and String(gb.gens[acell]) == acc_id,
		"an ACCUMULATOR generator is exempt — it banks currency, not a gated line")

	# --- the anchor generator is never gated out (zone 0 unlocks at L1) ---
	var ab := BoardModel.new()
	ab.gens.clear()
	var anchor := G.anchor_gen()
	ok(anchor != "", "fixture: the roster has an anchor generator (%s)" % anchor)
	var anchor_cell: Vector2i = ab.empty_ground_cells()[0]
	ab.place_gen(anchor, anchor_cell)
	var ar := SaveMigrate.purge_above_level_content(ab, [], [], 1)
	ok(not bool(ar["changed"]) and ab.gens.has(anchor_cell), "the gen_1 ANCHOR survives the purge at L1")

	# --- the stored-generator bag: ids and boosts stay in lockstep ---
	var sb := BoardModel.new()
	sb.gens.clear()
	var open_gid := G.gen_for_line(open_line)
	sb.bag_add(gated_gid, 2)         # dropped
	sb.bag_add(open_gid, 7)          # kept — and its boost must ride along
	sb.bag_add(acc_id, 1)            # kept (accumulator)
	var sr := SaveMigrate.purge_above_level_content(sb, [], [], 1)
	ok(bool(sr["changed"]), "a too-advanced STORED generator makes the purge report changed")
	ok(sb.gen_bag == [open_gid, acc_id], "the gated stored generator is dropped from gen_bag")
	ok(sb.gen_bag_boost == [7, 1], "gen_bag_boost stays in LOCKSTEP with the surviving ids")

	# --- the item bag and the live fence ---
	var fb := BoardModel.new()
	var fr := SaveMigrate.purge_above_level_content(fb, [open_code, gated_code, open_code],
		[{"line": open_line, "tier": 1}, {"line": gated, "tier": 1}, "not a dict"], 1)
	ok(bool(fr["changed"]), "a too-advanced stashed item / quest makes the purge report changed")
	ok(fr["bag"] == [open_code, open_code], "the too-advanced stashed item is dropped, order held")
	ok(fr["quests"].size() == 2, "the too-advanced quest is dropped; a non-dictionary entry is left for the sanitizer")
	ok((fr["quests"][0] as Dictionary).get("line") == open_line, "the in-cadence quest survives")

	# --- idempotency: the shipped contract (it runs on EVERY load, with no one-time flag) ---
	var again := SaveMigrate.purge_above_level_content(fb, fr["bag"], fr["quests"], 1)
	ok(not bool(again["changed"]), "the purge is IDEMPOTENT — a second pass removes nothing")

	# --- a high level gates nothing out ---
	var hb := BoardModel.new()
	var hcell: Vector2i = hb.empty_ground_cells()[0]
	hb.place(hcell, gated_code)
	var hr := SaveMigrate.purge_above_level_content(hb, [gated_code], [{"line": gated, "tier": 1}], 9999)
	ok(not bool(hr["changed"]), "at a level past the whole cadence the purge is a no-op")
	ok(hb.item_at(hcell) == gated_code and hr["bag"] == [gated_code], "...and nothing is taken")

# --- the discovery log (core/quests.gd) ----------------------------------------------------------

func _test_discovery_log() -> void:
	var line := int(G.ZONE_BASE_LINES[0])
	var t1 := line * 100 + 1
	var t3 := line * 100 + 3

	var g := {}
	Quests.mark_seen(g, t3)
	ok(g.has("seen") and (g["seen"] as Dictionary).has(str(t3)), "mark_seen creates `seen` and keys by the STRING code")
	Quests.mark_seen(g, 0)
	Quests.mark_seen(g, -7)
	ok((g["seen"] as Dictionary).size() == 1, "mark_seen ignores 0 and negative codes")
	Quests.mark_seen(g, G.COIN_LINE * 100 + 1)
	ok((g["seen"] as Dictionary).size() == 1, "mark_seen never logs a COIN — coins are not a discovery")

	var seen: Dictionary = g["seen"]
	ok(Quests.lowest_seen_code(line, seen) == t3, "lowest_seen_code returns the lowest DISCOVERED tier")
	Quests.mark_seen(g, t1)
	ok(Quests.lowest_seen_code(line, seen) == t1, "...and drops to t1 once t1 is seen")
	ok(Quests.lowest_seen_code(999, seen) == 0, "a wholly unseen line reads 0")

	# G.gen_made_line — "what line does this generator make?", the rule behind the board's ⓘ (a tap
	# opens THAT line's tier ladder, and 0 means there is no ladder, so the button stays hidden).

	# An ACCUMULATOR banks currency, so it makes no item line at all.
	var acc_kinds: Array = G.ACCUMULATORS.keys()
	var acc_id := String((G.ACCUMULATORS[acc_kinds[0]] as Dictionary).get("id", ""))
	ok(G.gen_made_line(acc_id) == 0, "an ACCUMULATOR generator makes no line (no ⓘ ladder)")

	# A TREAT generator makes ONLY its own treasure line — which is NOT in the main roster, so the
	# roster lookup alone would read 0 and wrongly hide its ladder.
	if not G.TREAT_LINES.is_empty():
		var tline := int(G.TREAT_LINES[0])
		ok(G.gen_made_line(G.treat_gen_id(tline)) == tline,
			"a TREAT generator makes exactly its own treasure line")

	# A NORMAL generator makes its one rostered base line (one line per generator since the redesign).
	var gid := G.gen_for_line(line)
	ok(G.gen_made_line(gid) == line, "a normal generator makes its own rostered base line")
	var made := {}
	for gen in G.GENERATORS:
		var g_id := String(gen.get("id", ""))
		var g_line := G.gen_made_line(g_id)
		ok(g_line > 0 and G.LINES.has(g_line), "%s makes a real line (%d)" % [g_id, g_line])
		ok(not made.has(g_line), "no two generators claim the same line (%d)" % g_line)
		made[g_line] = true
		ok(G.gen_for_line(g_line) == g_id, "...and the line maps back to it (gen_for_line round-trip)")

	# An unknown id makes nothing rather than crashing (a stale save's pruned generator id).
	ok(G.gen_made_line("gen_does_not_exist") == 0, "an UNKNOWN generator id makes no line")

func _test_ladder_header() -> void:
	var base_line := int(G.ZONE_BASE_LINES[0])
	var h := Quests.ladder_header(base_line)
	ok(String(h["kind"]) == "generator", "a BASE line's ladder header names its generator")
	ok(String(h["gid"]) == G.gen_for_line(base_line), "...with that generator's id")
	ok(String(h["name"]) == Quests.ladder_line_name(base_line), "...and the line's display name")

	var suffixed := Quests.ladder_header(base_line, "  retired  ")
	ok(String(suffixed["name"]) == "%s · retired" % Quests.ladder_line_name(base_line),
		"a status suffix is trimmed and appended with the · separator")
	ok(String(Quests.ladder_header(base_line, "   ")["name"]) == Quests.ladder_line_name(base_line),
		"a whitespace-only suffix adds nothing")

	# A crafted special line reads as a two-ingredient recipe.
	var special := 0
	for l in G.LINES.keys():
		if G.recipe_lines(int(l)).size() == 2:
			special = int(l)
			break
	if special > 0:
		var sh := Quests.ladder_header(special)
		ok(String(sh["kind"]) == "recipe" and (sh["lines"] as Array).size() == 2,
			"a CRAFTED line's header is its two-ingredient recipe (line %d)" % special)

	# An unrostered line has neither a generator nor a recipe → the plain title fallback.
	ok(String(Quests.ladder_header(999)["kind"]) == "title", "an unrostered line falls back to the plain title")
	ok(Quests.ladder_line_name(999) == "line 999", "ladder_line_name falls back to 'line N' for an unrostered line")
	ok(Quests.ladder_line_name(base_line) != "", "a rostered line has a display name")
