extends SceneTree
## Headless tests for the LiveOps Inbox (core/inbox.gd) — the mailbox + claimable gifts.
##   godot --headless -s res://engine/tests/inbox_tests.gd

const Save = preload("res://engine/scripts/core/save.gd")
const Inbox = preload("res://engine/scripts/core/inbox.gd")
const InboxUI = preload("res://engine/scripts/ui/inbox.gd")
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

# Point Save at a clean temp dir (never touches the real save).
func fresh(name: String) -> void:
	var dir := "user://tu_inbox_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

# --- tree-walk helpers for the UI feedback test --------------------------------
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
	print("== Inbox tests ==")

	# 1. SEED-ONCE: a fresh inbox carries the starter messages; touching it again does NOT
	#    re-seed (the count is stable), and a reload keeps the seed without re-running it.
	fresh("seed")
	var seeded := Inbox.messages().size()
	ok(seeded >= 2, "a fresh inbox seeds a couple of starter messages")
	ok(Inbox.messages().size() == seeded, "a second read does not re-seed")
	Save._loaded = false                          # force a reload from disk
	ok(Inbox.messages().size() == seeded, "the seed persists across a reload (no re-seed)")
	ok(bool(Save.grove().get("inbox_seeded", false)), "the seed-once guard flag is set")

	# 2. ADD fills defaults + assigns id/ts, and prepends (newest first).
	fresh("add")
	var before := Inbox.messages().size()
	Inbox.add({"title": "Hi", "body": "there"})
	var lst := Inbox.messages()
	ok(lst.size() == before + 1, "add appends one message")
	var top: Dictionary = lst[0]
	ok(String(top.get("title", "")) == "Hi", "add prepends the new message (newest first)")
	ok(String(top.get("id", "")) != "", "add assigns an id when absent")
	ok(top.has("ts") and top.has("reward") and top.has("claimed") and top.has("read"), \
		"add fills the default keys (reward/claimed/read/ts)")
	ok(int(top["reward"].get("coins", 0)) == 0, "a missing reward normalises to a zero dict")

	# 3. UNREAD_COUNT: counts unread OR unclaimed-gift messages.
	fresh("unread")
	# the seed has a welcome (no reward, unread) + a gift (reward, unread) → both count
	var u0 := Inbox.unread_count()
	ok(u0 >= 2, "fresh seed messages all count as unread")
	Inbox.mark_all_read()
	# after reading: the no-reward welcome drops out, but the unclaimed GIFT still counts
	var u1 := Inbox.unread_count()
	ok(u1 >= 1 and u1 < u0, "mark_all_read clears plain reads but keeps the unclaimed gift counted")

	# 4. HAS_UNCLAIMED: true while a positive reward sits unclaimed, false once grabbed.
	fresh("has_unclaimed")
	ok(Inbox.has_unclaimed(), "the seeded starter gift makes has_unclaimed true")

	# 5. CLAIM grants the reward (coins) and is idempotent (a second claim grants nothing).
	fresh("claim")
	Inbox.add({"id": "gift_a", "title": "Gift", "body": "coins", "reward": {"coins": 50}})
	var c0 := Save.coins()
	var got := Inbox.claim("gift_a")
	ok(int(got.get("coins", 0)) == 50, "claim returns the granted reward dict")
	ok(Save.coins() == c0 + 50, "claim grants the coins to the wallet")
	var c1 := Save.coins()
	var again := Inbox.claim("gift_a")
	ok(again.is_empty() and Save.coins() == c1, "a second claim is a no-op (idempotent, grants nothing)")
	ok(Inbox.claim("nope").is_empty(), "claiming an unknown id is a safe no-op")

	# 5b. CLAIM grants gems + water too (water tops up the capped grove can).
	fresh("claim_multi")
	Inbox.add({"id": "gift_b", "title": "Bundle", "body": "all three", "reward": {"coins": 10, "gems": 3, "water": 5}})
	var d0 := Save.diamonds()
	var w0 := int(Save.grove().get("water", 0))
	var g := Inbox.claim("gift_b")
	ok(int(g.get("gems", 0)) == 3 and Save.diamonds() == d0 + 3, "claim grants gems to the wallet")
	ok(int(Save.grove().get("water", 0)) == w0 + 5, "claim tops up the grove water")

	# 6. PERSISTENCE: a claimed flag + an added message survive a reload.
	fresh("persist")
	Inbox.add({"id": "keep", "title": "Keep me", "body": "x", "reward": {"coins": 20}})
	Inbox.claim("keep")
	Save._loaded = false                          # force a reload from disk
	var found := false
	for m in Inbox.messages():
		if String(m.get("id", "")) == "keep":
			found = true
			ok(bool(m.get("claimed", false)), "the claimed flag persists across a reload")
	ok(found, "an added message persists across a reload")
	ok(not Inbox.claim("keep").has("coins") or Inbox.claim("keep").is_empty(), \
		"a claimed message stays claimed after reload (no re-grant)")

	# 7. ICON MIGRATION (inbox_icons_v2): an already-seeded inbox on the OLD glyph icons (star /
	#    coin) is lifted onto the plated mail-kit icons (leaf / gift) exactly once, and never reverts.
	fresh("icon_migrate")
	var gm := Save.grove()
	gm["inbox"] = [
		{"id": "starter_gift", "title": "A little something", "body": "x", "icon": "coin",
			"reward": {"coins": 100}, "claimed": false, "read": false, "ts": 0.0},
		{"id": "welcome", "title": "Welcome", "body": "y", "icon": "star",
			"reward": {}, "claimed": false, "read": false, "ts": 0.0},
	]
	gm["inbox_seeded"] = true                      # already seeded (old icons) → migrate, never re-seed
	Save.grove_write()
	var icons := {}
	for m in Inbox.messages():
		icons[String(m.get("id", ""))] = String(m.get("icon", ""))
	ok(icons.get("welcome", "") == "leaf", "migration lifts the welcome icon star -> leaf")
	ok(icons.get("starter_gift", "") == "gift", "migration lifts the starter gift icon coin -> gift")
	ok(bool(Save.grove().get("inbox_icons_v2", false)), "the migration guard flag is set")
	# idempotent: with the flag set, a later deliberate icon change is NOT reverted on the next read.
	for m in Save.grove()["inbox"]:
		if String(m.get("id", "")) == "welcome":
			m["icon"] = "news"
	var after := ""
	for m in Inbox.messages():
		if String(m.get("id", "")) == "welcome":
			after = String(m.get("icon", ""))
	ok(after == "news", "migration runs once — a later icon change is not reverted")

	# 8. CLAIM FEEDBACK (UI): claiming a gift plays its reward celebration ABOVE the modal — the
	#    floating-reward node must live inside the z=100 mailbox overlay, not behind it. Regression:
	#    the celebration was attached to the map host at z=60, hidden under the veil, so a real claim
	#    granted the coins but looked like a dead button.
	fresh("uifx")
	Features.FLAGS["celebrate_bursts"] = true
	Features.FLAGS["floaters"] = true
	Inbox.messages()                               # seed welcome + starter_gift (100 coins)
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	await process_frame
	InboxUI.open(host)
	for _i in 4:
		await process_frame
	var overlay: Control = null
	for c in host.get_children():
		if c is Control and (c as Control).z_index == 100:
			overlay = c
	ok(overlay != null, "opening the mailbox adds a z=100 modal overlay")
	var claim := _find_claim(host)
	ok(claim != null, "the unclaimed 100-coin gift renders a Claim button")
	if claim != null:
		claim.pressed.emit()
	for _i in 4:
		await process_frame
	var floater := _find_floater(host)
	ok(floater != null, "claiming plays a floating reward celebration")
	ok(floater != null and overlay != null and _is_descendant(floater, overlay),
		"the claim celebration renders inside the z=100 overlay (above the veil), not behind it")
	host.queue_free()
	await process_frame

	# 9. CLAIM REFRESH (UI): Save has no change signal — the HUD wallet is pull-based — so a claim must
	#    fire the host's refresh hook to re-read the currency bar. Regression: the inbox ignored any
	#    refresh callback, so granted coins never showed on the bar until an unrelated HUD rebuild.
	fresh("uirefresh")
	Inbox.messages()                               # seed welcome + starter_gift (100 coins)
	var rhost := Control.new()
	rhost.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(rhost)
	await process_frame
	var refreshed := [0]
	InboxUI.open(rhost, {"refresh": func() -> void: refreshed[0] += 1})
	for _i in 4:
		await process_frame
	var rclaim := _find_claim(rhost)
	ok(rclaim != null, "the gift renders a Claim button (refresh test)")
	if rclaim != null:
		rclaim.pressed.emit()
	for _i in 4:
		await process_frame
	ok(refreshed[0] > 0, "claiming fires the host refresh hook so the currency bar re-reads the wallet")
	rhost.queue_free()
	await process_frame

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
