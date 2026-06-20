extends SceneTree
## Headless tests for the daily-login calendar UI (ui/login.gd) — focuses on the claim-feedback
## regression: a day's reward celebration must render ABOVE the z=100 modal, not behind its veil.
##   godot --headless -s res://engine/tests/login_tests.gd

const Save = preload("res://engine/scripts/core/save.gd")
const Login = preload("res://engine/scripts/core/login.gd")
const LoginUI = preload("res://engine/scripts/ui/login.gd")
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

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
