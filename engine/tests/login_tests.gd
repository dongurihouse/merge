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
	ok(bool(done_fired.v), "the reveal fires on_done (rebuilds the calendar)")
	host3.queue_free()
	await process_frame

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
