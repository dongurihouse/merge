extends SceneTree
## Headless tests for the server-driven mail SYNC contract (core/inbox_sync.gd::apply_feed) — pure
## logic, no network. Proves the feed→inbox fold: dedup by id, time windows, malformed-input safety.
##   godot --headless -s res://engine/tests/inbox_sync_tests.gd

const Save = preload("res://engine/scripts/core/save.gd")
const Inbox = preload("res://engine/scripts/core/inbox.gd")
const Sync = preload("res://engine/scripts/core/inbox_sync.gd")

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
	var dir := "user://tu_inboxsync_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func _has(id: String) -> bool:
	for m in Inbox.messages():
		if String(m.get("id", "")) == id:
			return true
	return false

func _msg(id: String) -> Dictionary:
	for m in Inbox.messages():
		if String(m.get("id", "")) == id:
			return m
	return {}

const NOW := 1_700_000_000.0

func _initialize() -> void:
	print("== Inbox sync tests ==")

	# 1. FOLD: a valid feed adds its new messages to the inbox and returns the count.
	fresh("fold")
	var n := Sync.apply_feed('{"version":1,"messages":[' +
		'{"id":"news_a","title":"Hi","body":"there","icon":"news"},' +
		'{"id":"gift_a","title":"Gift","body":"coins","icon":"gift","reward":{"coins":100}}]}', NOW)
	ok(n == 2, "a valid feed folds in its 2 new messages (returns the count)")
	ok(_has("news_a") and _has("gift_a"), "both feed messages land in the inbox")
	ok(int(_msg("gift_a").get("reward", {}).get("coins", 0)) == 100, "the reward passes through to the stored message")

	# 2. DEDUP: re-applying the SAME feed adds nothing (folded ids are remembered).
	var n2 := Sync.apply_feed('{"messages":[{"id":"news_a","title":"Hi","body":"there"}]}', NOW)
	ok(n2 == 0, "re-applying an already-folded id is a no-op")
	ok(bool(Save.grove().get("inbox_remote_seen", {}).has("news_a")), "folded ids persist in inbox_remote_seen")

	# 3. MALFORMED: bad JSON / wrong shape / missing id never crash and fold nothing.
	fresh("malformed")
	ok(Sync.apply_feed("not json {{{", NOW) == 0, "garbage JSON folds nothing")
	ok(Sync.apply_feed('{"messages":"oops"}', NOW) == 0, "a non-array messages field folds nothing")
	ok(Sync.apply_feed('{"messages":[{"title":"no id here"}]}', NOW) == 0, "a message without an id is skipped")

	# 4. ALREADY PRESENT: a feed id that already exists in the inbox (e.g. the local seed) is not re-added.
	fresh("present")
	Inbox.add({"id": "starter_gift", "title": "x", "body": "y", "reward": {"coins": 5}})
	var n4 := Sync.apply_feed('{"messages":[{"id":"starter_gift","title":"dup","body":"z","reward":{"coins":999}}]}', NOW)
	ok(n4 == 0, "a feed id already present in the inbox is not re-added")

	# 5. EXPIRED: a message past its end window is skipped AND marked seen (won't fold on a later sync).
	fresh("expired")
	var n5 := Sync.apply_feed('{"messages":[{"id":"old","title":"x","body":"y","end":%d}]}' % int(NOW - 100), NOW)
	ok(n5 == 0 and not _has("old"), "an expired message is not folded")
	ok(bool(Save.grove().get("inbox_remote_seen", {}).has("old")), "an expired message is marked seen so it never folds later")

	# 6. NOT-YET-LIVE: a message before its start window is skipped but NOT marked seen, so it folds
	#    once it goes live on a later sync.
	fresh("future")
	var n6 := Sync.apply_feed('{"messages":[{"id":"soon","title":"x","body":"y","start":%d}]}' % int(NOW + 1000), NOW)
	ok(n6 == 0 and not _has("soon"), "a not-yet-live message is not folded")
	ok(not bool(Save.grove().get("inbox_remote_seen", {}).has("soon")), "a not-yet-live message is NOT marked seen")
	var n6b := Sync.apply_feed('{"messages":[{"id":"soon","title":"x","body":"y","start":%d}]}' % int(NOW + 1000), NOW + 2000)
	ok(n6b == 1 and _has("soon"), "the message folds in once its start window opens")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
