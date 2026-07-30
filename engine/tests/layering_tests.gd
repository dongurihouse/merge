extends "res://engine/tests/test_base.gd"
## Headless guard for the engine layering invariant.
##   godot --headless --path . -s res://engine/tests/layering_tests.gd
## Imports may only flow scenes/ -> ui/ -> core/. This proves the direction holds:
## core/ never reaches up into ui/ or scenes/, and ui/ never reaches into scenes/.
## See docs/design/merge_spec.md §15 (the layering invariant).

const CORE := "res://engine/scripts/core/"
const UI := "res://engine/scripts/ui/"
const SCENES := "res://engine/scripts/scenes/"

# --- engine ↛ games (LIVE GUARD — see _check_engine_never_reaches_into_games) ---
const ENGINE_SCRIPTS := "res://engine/scripts/"
const GAMES := "res://games/"
## LIVE: the sweep landed (the 48 staged violations are gone), so the engine↛games scan
## FAILS the suite instead of just reporting. Flipping this back to `false` would silently
## re-open the door — don't; fix the reference through Game.art/kit/... instead.
const FAIL_ON_GAMES_REFS := true

const Design := preload("res://engine/scripts/core/design.gd")   # the host is the design canvas — read it, never re-type it
const Overlay := preload("res://engine/scripts/ui/overlay.gd")
const Hud := preload("res://engine/scripts/ui/hud.gd")
const TuneFX := preload("res://engine/scripts/core/tuning.gd").FX   # the FX juice dials (FLY_Z / FLOAT_Z)
const HandHint := preload("res://engine/scripts/ui/hand_hint.gd")   # the FTUE teach overlay — must sit under every modal
const Look := preload("res://engine/scripts/ui/skin.gd")            # the medal badge's own tier geometry

# The walk is test_base.gd's gd_files(dir, deep) — one coverage function for every guard.

# True if `path` mentions `needle` anywhere (preload/load both look like a path string).
func _reads(path: String, needle: String) -> bool:
	return read_text(path).find(needle) != -1

func _initialize() -> void:
	print("== Engine layering guard ==")
	var core := gd_files(CORE, false)
	var ui := gd_files(UI, false)
	ok(core.size() >= 1, "core/ has scripts (%d found)" % core.size())
	ok(ui.size() >= 1, "ui/ has scripts (%d found)" % ui.size())
	# core/ is the bottom layer — it must not import ui/ or scenes/.
	for p in core:
		var base := p.get_file()
		ok(not _reads(p, UI), "core/%s does not import ui/" % base)
		ok(not _reads(p, SCENES), "core/%s does not import scenes/" % base)
	# ui/ is the middle layer — it must not import scenes/ (the top).
	for p in ui:
		ok(not _reads(p, SCENES), "ui/%s does not import scenes/" % p.get_file())
	_check_modal_z()
	_check_no_z_above_modal_top()
	_check_engine_never_reaches_into_games()
	_check_shipped_never_names_an_excluded_dir()
	await _check_level_badge_layout()
	finish()

# The modal-overlay z invariant. The game renders on ONE canvas (no CanvasLayers), so "dialogs stay on top
# of the background" is purely z_index: every dialog mounts via Overlay.mount, which MUST stamp a z above
# ALL world/HUD/FX chrome. This is the guard the shop lacked when it forgot its z and slid under the HUD;
# MODAL_TOP_Z stacks one notch higher for a sheet that must sit above an already-open modal.
func _check_modal_z() -> void:
	var host := Control.new()
	var ov: Control = Overlay.mount(host, "ProbeOverlay")
	ok(ov != null and ov.name == "ProbeOverlay", "Overlay.mount returns the named overlay")
	ok(ov != null and ov.z_index == Overlay.MODAL_Z, "Overlay.mount stamps the canonical MODAL_Z")
	ok(host.get_node_or_null("ProbeOverlay") == ov, "Overlay.mount parents the overlay onto its host")
	var chrome_top: int = maxi(Hud.HUD_WALLET_Z, maxi(TuneFX.FLY_Z, TuneFX.FLOAT_Z))
	ok(Overlay.MODAL_Z > chrome_top, \
		"MODAL_Z (%d) sits above the highest HUD/FX chrome (%d) — dialogs cover the world" % [Overlay.MODAL_Z, chrome_top])
	ok(Overlay.MODAL_TOP_Z > Overlay.MODAL_Z, "MODAL_TOP_Z sits above MODAL_Z — a sheet can stack over an open modal")
	# The FTUE hand-hint teach (hand_hint.gd) once hand-rolled z_index = 4000 — the one z in the
	# codebase above the modal band — so every modal opened while a hint was live (How-to-Play, bag,
	# shop, Tiers ladder, level popup, daily-login calendar) rendered UNDER its veil instead of over
	# it. Pin both ends of the invariant so that regression can't come back silently.
	ok(HandHint.HAND_HINT_Z > chrome_top, \
		"HandHint.HAND_HINT_Z (%d) sits above the highest HUD/FX chrome (%d)" % [HandHint.HAND_HINT_Z, chrome_top])
	ok(HandHint.HAND_HINT_Z < Overlay.MODAL_Z, \
		"HandHint.HAND_HINT_Z (%d) sits below Overlay.MODAL_Z (%d) — a modal always covers the FTUE teach" % [HandHint.HAND_HINT_Z, Overlay.MODAL_Z])
	host.free()

# No script anywhere in the engine layers may hand-roll a z_index literal above MODAL_TOP_Z — that
# was exactly the FTUE hand-hint bug (hand_hint.gd's z_index = 4000, the one z above the modal
# band). A named constant derived from/compared against Overlay.MODAL_Z (like HandHint.HAND_HINT_Z
# above) is fine; this scan only flags a bare integer assignment, which is what a future hand-roll
# would look like.
func _check_no_z_above_modal_top() -> void:
	var offenders := PackedStringArray()
	for dir in [CORE, UI, SCENES]:
		for p in gd_files(dir, false):
			var line_no := 0
			for raw_line in read_text(p).split("\n"):
				line_no += 1
				var line: String = raw_line.split("#")[0]   # comments (e.g. "z_index=4000" in prose) don't count
				var idx := line.find("z_index")
				if idx == -1:
					continue
				var eq := line.find("=", idx)
				if eq == -1 or (eq + 1 < line.length() and line[eq + 1] == "="):
					continue   # no assignment here, or it's a `==` comparison
				var rest := line.substr(eq + 1).strip_edges()
				if not rest.is_valid_int():
					continue   # a named constant (Overlay.MODAL_Z, HandHint.HAND_HINT_Z, ...), not a bare literal
				var v := rest.to_int()
				if v > Overlay.MODAL_TOP_Z:
					offenders.append("%s:%d (z_index=%d)" % [p.get_file(), line_no, v])
	ok(offenders.is_empty(), \
		"no script hand-rolls a z_index literal above MODAL_TOP_Z (%d)%s" % \
		[Overlay.MODAL_TOP_Z, ("" if offenders.is_empty() else " — " + ", ".join(offenders))])

# The engine is meant to be GAME-AGNOSTIC: nothing under engine/scripts/ should name a
# res://games/... path. See docs/design/merge_spec.md §15 and docs/design/board_decomposition.md
# (Constraints). The rule was documented but never enforced, so 48 references accumulated —
# mostly `const KIT_PATH := "res://games/grove/ui_kit.gd"` and hardcoded grove asset paths. They
# were swept to the indirection points (Game.art / Skin.kit for art, Game.kit / Game.kit_settings /
# Game.home_chrome for the game-side scripts + settings) and this scan now FAILS on a new one.
#
# Sanctioned exceptions — these are correct by design and are NOT reported:
#  · core/game.gd — the single game-indirection point; preloading res://games/active.gd is its job.
#  · scenes/boot.gd's LAUNCH_PATH const — the splash image is loaded BEFORE the art/audio asset
#    pack is mounted, so it cannot go through the normal indirection. Documented in boot.gd.
#  · a `res://games/%s/` TEMPLATE (core/strings.gd, core/login.gd, core/content.gd) — the "%s" is
#    filled with Game.active(), so the path names no game at all; it IS the game-parametrised
#    indirection, the data-file twin of Game.art(). Only a LITERAL game name is a leak.
# Comment text doesn't count (a path named in prose is not a dependency), matching the
# comment-stripping the z_index scan above already does.
func _check_engine_never_reaches_into_games() -> void:
	var offenders := PackedStringArray()
	for p in gd_files(ENGINE_SCRIPTS):
		if p == CORE + "game.gd":
			continue   # sanctioned: the game-indirection point
		var rel := p.trim_prefix(ENGINE_SCRIPTS)
		var line_no := 0
		for raw_line in read_text(p).split("\n"):
			line_no += 1
			var line: String = raw_line.split("#")[0]
			var idx := line.find(GAMES)
			if idx == -1:
				continue
			if p == SCENES + "boot.gd" and line.strip_edges().begins_with("const LAUNCH_PATH"):
				continue   # sanctioned: splash loads before the asset pack mounts
			if line.substr(idx, GAMES.length() + 3) == GAMES + "%s/":
				continue   # sanctioned: the game-PARAMETRISED template, filled with Game.active()
			# quote-delimited tail of the literal, so the report shows the actual path
			var tail := line.substr(idx)
			var quote := tail.find("\"")
			var matched: String = tail.substr(0, quote) if quote != -1 else tail.strip_edges()
			offenders.append("%s:%d  %s" % [rel, line_no, matched])
	if not offenders.is_empty():
		print("  ----------------------------------------------------------------")
		print("  engine -> games references: %d" % offenders.size())
		for o in offenders:
			print("    ", o)
		print("  route art through Game.art()/Skin.kit(rel); game-side scripts + settings through")
		print("  Game.kit()/Game.kit_settings()/Game.home_chrome() (declared in games/<name>/game.gd)")
		print("  ----------------------------------------------------------------")
	if FAIL_ON_GAMES_REFS:
		ok(offenders.is_empty(), \
			"no script under engine/scripts/ names a res://games/ path (%d offender(s))" % offenders.size())
	else:
		ok(true, "engine/scripts/ -> res://games/ scan ran (staged: %d reported, not failing)" % offenders.size())

# THE SHIPPED PACK MUST BE SELF-CONTAINED. export_presets.cfg drops whole directories from the build
# (`exclude_filter`) — the tests and the dev tools. A shipped script that names a file in one of them is a
# load that cannot resolve on device: silent in the editor, silent in every headless suite, broken only in
# the export. Nothing enforced this until the shop's hit-region overlay moved out of engine/scripts/ui/
# into engine/tools/ (2026-07-30) precisely SO it would stop shipping — the owner's reason for keeping the
# code ("in case we want to change it, or introduce a new shop element") is exactly the day someone
# re-wires it into the runtime by hand. A tool composes it now; see docs/design/shop-hit-regions.md.
#
# The rule is derived from the preset, not typed here, so a new excluded directory is covered the day it
# is added. Only excluded directories that CONTAIN .gd files are scanned for: an excluded asset directory
# (games/grove/assets/**) is a different mechanism — art is mounted at runtime as a separate pack through
# Game.art(), and shipped scripts name those paths legitimately.
const EXPORT_PRESETS := "res://export_presets.cfg"

func _check_shipped_never_names_an_excluded_dir() -> void:
	var excluded := _excluded_dirs()
	ok(not excluded.is_empty(), "export_presets.cfg declares excluded directories (%d)" % excluded.size())
	var code_excluded := PackedStringArray()
	for dir in excluded:
		if gd_files(dir).size() > 0:
			code_excluded.append(dir)
	ok(code_excluded.size() >= 2, \
		"…of which these hold scripts, so nothing shipped may name them: %s" % ", ".join(code_excluded))
	var offenders := PackedStringArray()
	for p in _shipped_gd_files(excluded):
		var line_no := 0
		for raw_line in read_text(p).split("\n"):
			line_no += 1
			var line: String = raw_line.split("#")[0]   # a path named in prose is not a dependency
			for dir in code_excluded:
				if line.find(dir) != -1:
					offenders.append("%s:%d  %s" % [p.trim_prefix("res://"), line_no, dir])
	ok(offenders.is_empty(), \
		"no shipped script names a directory the export excludes (%d offender(s))%s" % \
		[offenders.size(), ("" if offenders.is_empty() else " — " + ", ".join(offenders))])

# The `<dir>/**` entries of the preset's exclude_filter, as res:// directory prefixes.
func _excluded_dirs() -> PackedStringArray:
	var out := PackedStringArray()
	for raw_line in read_text(EXPORT_PRESETS).split("\n"):
		var line := raw_line.strip_edges()
		if not line.begins_with("exclude_filter="):
			continue
		for entry in line.trim_prefix("exclude_filter=").trim_prefix("\"").trim_suffix("\"").split(","):
			var e := String(entry).strip_edges()
			if e.ends_with("/**"):
				out.append("res://" + e.trim_suffix("**"))
		break
	return out

# Every .gd file the export SHIPS: the walk starts at the project root, so a new shipped directory is
# covered without being named here, and skips exactly what the preset already drops.
func _shipped_gd_files(excluded: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for p in gd_files("res://"):
		var shipped := true
		for dir in excluded:
			if p.begins_with(dir):
				shipped = false
				break
		if shipped:
			out.append(p)
	return out

func _check_level_badge_layout() -> void:
	var host := Control.new()
	host.custom_minimum_size = Design.size()
	host.size = Design.size()
	get_root().add_child(host)
	var hud: Dictionary = Hud.build(host, {})
	await process_frame
	await process_frame
	var water_pill := hud.get("water_pill") as Control
	var lv_panel := hud.get("lv_panel") as Control
	var badge := lv_panel.find_child("LevelBadge", true, false) as Control if lv_panel != null else null
	var num := badge.get_node_or_null("lv_num") as Label if badge != null else null
	var water_h := water_pill.get_global_rect().size.y if water_pill != null else 0.0
	var badge_h := badge.get_global_rect().size.y if badge != null else 0.0
	# The badge was stepped up with the top-chrome paper pass (Hud.LEVEL_BADGE_SCALE 1.2 -> 1.35), so it
	# holds against the new pastel pills. engine/tests/hud_paper_tests.gd owns the reason and the bounds;
	# this stays as the layout-side pin that it is still SIZED off the pill and did not float free.
	ok(badge != null and water_h > 0.0 and badge_h >= water_h * 1.32 and badge_h <= water_h * 1.35,
		"level badge is about a third larger than the wallet pill (badge=%.1f pill=%.1f)" % [badge_h, water_h])
	var badge_center := badge.get_global_rect().get_center() if badge != null else Vector2.ZERO
	var num_center := num.get_global_rect().get_center() if num != null else Vector2(INF, INF)
	# The number rides the medal's DISC, which is NOT the badge box's centre — the tails hang below
	# it. Read the disc off the art rect actually on screen (position + circle_cy of the tier the
	# level wears), so this pins the rendered geometry instead of re-running the placement formula.
	var art := badge.get_node_or_null("lv_badge_art") as Control if badge != null else null
	var spec: Dictionary = Look.medal_spec(int(num.text)) if num != null else {}
	var disc_y := art.get_global_rect().position.y \
		+ float(spec.get("circle_cy", 0.5)) * art.get_global_rect().size.y if art != null else INF
	# the Label centres its LINE BOX, which is pushed one px past the disc to land the visible INK on
	# it (Look.MEDAL_NUM_INK_BIAS_PX) — so that px is expected here, not slack in the tolerance.
	var want_y := disc_y + Look.MEDAL_NUM_INK_BIAS_PX
	# Horizontally the Label is deliberately NOT centred on the badge: it is offset so the digits'
	# INK is (this face is tabular, so `1` sits left inside its own advance). The rect therefore
	# carries that offset, and the badge's own centre is the wrong thing to compare it to.
	var want_x := badge_center.x + Look.medal_num_ink_dx(num.text, num.get_theme_font("font"),
		num.get_theme_font_size("font_size")) if num != null else INF
	ok(num != null and absf(num_center.x - want_x) <= 0.5 and absf(num_center.y - want_y) <= 0.5,
		"level badge number rect sits on the medal's DISC (dx from ink centre=%.2f, dy from disc+bias=%.2f, disc is %.1f px off the badge centre)" \
		% [num_center.x - want_x, num_center.y - want_y, disc_y - badge_center.y])
	host.queue_free()
	await process_frame
