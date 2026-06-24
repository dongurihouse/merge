extends SceneTree
## Headless tests for the daily-login calendar UI (ui/login.gd) — focuses on the claim-feedback
## regression: a day's reward celebration must render ABOVE the z=100 modal, not behind its veil.
##   godot --headless -s res://engine/tests/login_tests.gd

const Save = preload("res://engine/scripts/core/save.gd")
const Login = preload("res://engine/scripts/core/login.gd")
const LoginUI = preload("res://engine/scripts/ui/login.gd")
const LoginMystery = preload("res://engine/scripts/ui/login_mystery.gd")
const Features = preload("res://engine/scripts/core/features.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func fresh(name: String) -> void:
	var dir := "user://tu_login_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func _find_claim(n: Node) -> Button:
	if n is Button and (n as Button).text.to_lower().contains("claim"):
		return n
	for c in n.get_children():
		var r := _find_claim(c)
		if r != null:
			return r
	return null

# the floating reward built by FX.floating_reward is the one HBox carrying z_index == FLOAT_Z (60).
func _find_floater(n: Node) -> Control:
	if n is HBoxContainer and (n as Control).z_index == 60:
		return n
	for c in n.get_children():
		var r := _find_floater(c)
		if r != null:
			return r
	return null

func _is_descendant(node: Node, ancestor: Node) -> bool:
	var p := node.get_parent()
	while p != null:
		if p == ancestor:
			return true
		p = p.get_parent()
	return false

func _initialize() -> void:
	print("== Login UI tests ==")

	# CLAIM FEEDBACK: claiming today's daily reward plays its celebration ABOVE the modal — the
	# floating-reward node must live inside the z=100 calendar overlay, not behind it. Regression:
	# the celebration was attached to the map host at z=60, hidden under the veil (mirror of the
	# inbox bug — the inbox UI was built by copying this file).
	fresh("feedback")
	Features.FLAGS["celebrate_bursts"] = true
	Features.FLAGS["floaters"] = true
	ok(not Login.claimed_today(), "a fresh save has today's reward unclaimed")
	ok(not Login.reward_for(Login.today_day()).is_empty(), "today carries a non-empty reward")

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	await process_frame
	LoginUI.open(host)
	for _i in 4:
		await process_frame
	var overlay: Control = null
	for c in host.get_children():
		if c is Control and (c as Control).z_index == 100:
			overlay = c
	ok(overlay != null, "opening the calendar adds a z=100 modal overlay")
	var claim := _find_claim(host)
	ok(claim != null, "today's rung renders a Claim button")
	if claim != null:
		claim.pressed.emit()
	for _i in 4:
		await process_frame
	var floater := _find_floater(host)
	ok(floater != null, "claiming today plays a floating reward celebration")
	ok(floater != null and overlay != null and _is_descendant(floater, overlay),
		"the daily celebration renders inside the z=100 overlay (above the veil), not behind it")
	# claiming auto-dismisses the popup: after the reward-shout delay + fade, the z=100 overlay is gone.
	await create_timer(LoginUI.CLAIM_CLOSE_DELAY + 0.4).timeout
	ok(not is_instance_valid(overlay), "claiming today auto-closes the daily popup")
	host.queue_free()
	await process_frame

	# T46: a MYSTERY day (slot 4/7) wears the "?" chest and its today rung opens the SPIN reveal
	# (not the instant grant). Plant a streak of 3 so today_day() == 4 (a mystery slot).
	fresh("mystery_days_map")
	var gmd := Save.data
	gmd["daily"] = {"day": int(Time.get_unix_time_from_system() / 86400.0), "jobs": 0, "merges": 0, "coins": 0, "claimed": false, "streak": 3}
	Save.save_now()
	Save._loaded = false
	var host2 := Control.new()
	host2.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host2)
	await process_frame
	var rb2 := {"fn": Callable()}
	var days: Array = LoginUI._days(host2, rb2, {})
	var t_entry := {}
	for d in days:
		if int(d.get("day", 0)) == 4:
			t_entry = d
	ok(int(t_entry.get("day", 0)) == 4 and String(t_entry.get("state", "")) == "today", "day 4 is the claimable 'today' rung")
	ok(bool(t_entry.get("mystery", false)), "a mystery day wears the '?' chest")
	ok((t_entry.get("on_claim", Callable()) as Callable).is_valid(), "the mystery 'today' rung wires an on_claim (opens the spin)")
	host2.queue_free()
	await process_frame

	# T46: the spin reveal (instant) grants EXACTLY the rolled winners and fires on_done. Plant a
	# streak of 6 so today_day() == 7 (the 2-winner mystery).
	fresh("mystery_reveal")
	var gmr := Save.data
	gmr["daily"] = {"day": int(Time.get_unix_time_from_system() / 86400.0), "jobs": 0, "merges": 0, "coins": 0, "claimed": false, "streak": 6}
	Save.save_now()
	Save._loaded = false
	ok(Login.today_day() == 7 and Login.is_mystery(7), "the streak reaches the day-7 mystery (2 winners)")
	var host3 := Control.new()
	host3.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host3)
	await process_frame
	var s_pre := Login.streak()
	var done_fired := {"v": false}
	LoginMystery.open(host3, 7, {"instant": true, "on_done": func() -> void: done_fired.v = true})
	await process_frame
	ok(Login.claimed_today(), "the reveal claims the day")
	ok(Login.streak() == s_pre + 1, "the reveal bumps the streak by one")
	ok(bool(done_fired.v), "the reveal fires on_done (closes the calendar)")
	host3.queue_free()
	await process_frame

	# T46: the reveal cards show the reward AMOUNTS (not icon-only) so the prizes are concrete.
	var rc := LoginMystery._reveal_card({"coins": 120, "gems": 1}, 96.0, 100.0)
	get_root().add_child(rc)
	await process_frame
	var amt_texts := _collect_label_texts(rc)
	ok(amt_texts.has("120"), "a reveal card shows the coin amount (120)")
	ok(amt_texts.has("1"), "a reveal card shows the secondary gem amount (1)")
	rc.free()
	await process_frame

	# === T54: slot-machine reels + the player picks N ===
	# build_reveal now yields one tappable REEL per shown option (each carrying its landed reward) plus a
	# Claim button — the reels spin, the player picks, Claim grants the picks.
	var b54 := LoginMystery.build_reveal([{"coins": 200}, {"gems": 2}, {"coins": 300}], [1], 560.0, {})
	var reels: Array = b54.get("reels", [])
	ok(reels.size() == 3, "build_reveal makes one reel per shown option")
	ok(b54.get("claim") is Button, "build_reveal exposes a Claim button")
	ok((reels[0] as Control).get_meta("reward", {}) == {"coins": 200}, "each reel carries its landed reward (meta)")
	get_root().add_child(b54["dialog"]); await process_frame
	ok(_collect_label_texts(b54["dialog"]).has("300"), "a reel shows its concrete reward amount (300)")
	(b54["dialog"] as Control).queue_free(); await process_frame

	# the SHINE classification: a reward with gems is premium; gems outweigh coins for the top-value shine.
	ok(LoginMystery.is_premium({"gems": 1}) and not LoginMystery.is_premium({"coins": 500}), "a gem reward is premium (shines); a coins reward is not")
	ok(LoginMystery.reward_value({"gems": 2}) > LoginMystery.reward_value({"coins": 300}), "gems outweigh coins in reward value (top shine)")

	# the PICK phase: each reel is tappable, Claim is gated until exactly `win` are chosen, over-cap is blocked,
	# deselect works, and Claim hands on_claim EXACTLY the picked rewards.
	var picked := {"v": []}
	var b2 := LoginMystery.build_reveal([{"coins": 200}, {"gems": 2}, {"coins": 100}, {"water": 14}, {"coins": 300}], [], 560.0, {})
	var reels2: Array = b2["reels"]
	var claim2: Button = b2["claim"]
	get_root().add_child(b2["dialog"]); await process_frame
	LoginMystery.enter_pick(reels2, 2, b2["caption"], claim2, func(p: Array) -> void: picked.v = p)
	ok(claim2.disabled, "Claim is disabled before any pick")
	_tap_reel(reels2[2]); await process_frame
	ok(claim2.disabled, "Claim stays disabled with only 1 of 2 picked")
	_tap_reel(reels2[4]); await process_frame
	ok(not claim2.disabled, "Claim enables when exactly 2 are picked")
	_tap_reel(reels2[0]); await process_frame
	ok(_selected_count(reels2) == 2, "selecting a 3rd is blocked at the pick limit (still 2)")
	_tap_reel(reels2[2]); await process_frame
	ok(_selected_count(reels2) == 1 and claim2.disabled, "tapping a picked reel deselects it (Claim disables again)")
	_tap_reel(reels2[2]); await process_frame
	claim2.pressed.emit(); await process_frame
	ok(picked.v.size() == 2 and picked.v.has({"coins": 100}) and picked.v.has({"coins": 300}), "Claim hands on_claim exactly the picked rewards")
	(b2["dialog"] as Control).queue_free(); await process_frame

	# pick → claim_mystery grants the picked set + bumps the streak (the real integration).
	fresh("mystery_pick_grant")
	var gpg := Save.data
	gpg["daily"] = {"day": int(Time.get_unix_time_from_system() / 86400.0), "jobs": 0, "merges": 0, "coins": 0, "claimed": false, "streak": 6}
	Save.save_now(); Save._loaded = false
	var c_pre := Save.coins(); var g_pre := Save.diamonds(); var s_pre2 := Login.streak()
	var b3 := LoginMystery.build_reveal([{"coins": 200}, {"gems": 2}, {"coins": 100}, {"water": 14}, {"coins": 300}], [], 560.0, {})
	var reels3: Array = b3["reels"]; var claim3: Button = b3["claim"]
	get_root().add_child(b3["dialog"]); await process_frame
	LoginMystery.enter_pick(reels3, 2, b3["caption"], claim3, func(p: Array) -> void: Login.claim_mystery(p))
	_tap_reel(reels3[0]); _tap_reel(reels3[1]); await process_frame
	claim3.pressed.emit(); await process_frame
	ok(Save.coins() - c_pre == 200 and Save.diamonds() - g_pre == 2, "claiming grants exactly the picked rewards (200 coin + 2 gem)")
	ok(Login.claimed_today() and Login.streak() == s_pre2 + 1, "the pick-claim marks claimed + bumps the streak")
	(b3["dialog"] as Control).queue_free(); await process_frame

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)

# Press a reel's tap surface (each reel is a Button), simulating a player tap.
func _tap_reel(reel: Variant) -> void:
	if reel is Button:
		(reel as Button).pressed.emit()
		return
	var bs := (reel as Node).find_children("*", "Button", true, false)
	if not bs.is_empty():
		(bs[0] as Button).pressed.emit()

# How many reels are currently selected (the pick phase flags each via a "selected" meta).
func _selected_count(reels: Array) -> int:
	var n := 0
	for r in reels:
		if bool((r as Control).get_meta("selected", false)):
			n += 1
	return n

# Gather every Label's text under a node (for asserting on-card amount text).
func _collect_label_texts(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		out.append_array(_collect_label_texts(c))
	return out
