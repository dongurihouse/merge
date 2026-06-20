extends SceneTree
## Headless tests for the server-driven mail SYNC contract (core/inbox_sync.gd::apply_feed) + the
## capped-mailbox helpers it leans on (core/inbox.gd cursor/remaining_slots/prune). Pure logic, no
## network.  godot --headless -s res://engine/tests/inbox_sync_tests.gd

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

# build a feed JSON of `count` messages starting at seq `from` (ids gN, plain notes).
func _feed(from: int, count: int) -> String:
	var items: Array = []
	for i in count:
		items.append('{"seq":%d,"id":"g%d","title":"t","body":"b"}' % [from + i, from + i])
	return '{"messages":[' + ",".join(items) + ']}'

func _initialize() -> void:
	print("== Inbox sync tests ==")

	# fresh box = the 2 seeded starters (welcome + starter_gift), cursor 0, room for CAP-2 more.
	fresh("base")
	ok(Inbox.cursor() == 0, "a fresh save starts at cursor 0 (fetch everything since 0)")
	ok(Inbox.remaining_slots() == Inbox.MAIL_CAP - 2, "remaining_slots = cap minus the 2 seeded messages")

	# 1. FOLD + CURSOR: a feed folds its messages in, returns the count, and advances the cursor to the
	#    highest seq it took.
	var n := Sync.apply_feed(_feed(5, 3))                    # seq 5,6,7
	ok(n == 3 and _has("g5") and _has("g7"), "a feed folds its new messages into the box")
	ok(Inbox.cursor() == 7, "the cursor advances to the last seq folded")

	# 2. RE-APPLY: folding the same feed again adds nothing and leaves the cursor put (id dedup + seqs
	#    not past the cursor).
	var n2 := Sync.apply_feed(_feed(5, 3))
	ok(n2 == 0 and Inbox.cursor() == 7, "re-applying a folded feed is a no-op")

	# 3. CAP: a feed bigger than the box only folds up to remaining_slots; the cursor stops at the last
	#    one that FIT, so the overflow comes back on the next fetch.
	fresh("cap")
	var big := Sync.apply_feed(_feed(1, 50))                 # seq 1..50, but only CAP-2 slots free
	ok(big == Inbox.MAIL_CAP - 2, "a feed only folds up to the remaining slots")
	ok(Inbox.messages().size() == Inbox.MAIL_CAP, "the box fills exactly to the cap")
	ok(Inbox.cursor() == Inbox.MAIL_CAP - 2, "the cursor stops at the last message that fit (overflow refetched)")

	# 4. MALFORMED: never crashes, folds nothing, cursor untouched.
	fresh("malformed")
	ok(Sync.apply_feed("not json {{{") == 0, "garbage JSON folds nothing")
	ok(Sync.apply_feed('{"messages":"oops"}') == 0, "a non-array messages field folds nothing")
	ok(Inbox.cursor() == 0, "malformed input leaves the cursor at 0")

	# 5. SKIPS still advance the cursor: a message with no id (can't dedup) is not folded but is consumed.
	fresh("noid")
	var n5 := Sync.apply_feed('{"messages":[{"seq":9,"title":"no id"}]}')
	ok(n5 == 0 and not _has("") and Inbox.cursor() == 9, "a message with no id is skipped but the cursor passes it")

	# 6. FULL BOX: when nothing fits, apply_feed folds nothing and leaves the cursor alone.
	fresh("full")
	Sync.apply_feed(_feed(1, 50))                            # fill to cap
	var before := Inbox.cursor()
	var n6 := Sync.apply_feed(_feed(100, 5))
	ok(n6 == 0 and Inbox.cursor() == before, "a full box folds nothing and does not advance the cursor")

	# 7. PRUNE: dealt-with mail (claimed gifts / read notes) clears; unclaimed gifts + unread stay.
	fresh("prune")
	Inbox.add({"id": "gift_keep", "title": "g", "body": "b", "reward": {"coins": 50}})   # unclaimed gift
	Inbox.add({"id": "note_unread", "title": "n", "body": "b"})                          # unread note
	for m in Inbox.messages():
		if String(m.get("id", "")) == "starter_gift":
			m["claimed"] = true                             # a claimed gift → resolved
		if String(m.get("id", "")) == "welcome":
			m["read"] = true                                # a read plain note → resolved
	var removed := Inbox.prune()
	ok(removed == 2, "prune drops the claimed gift and the read note")
	ok(_has("gift_keep") and _has("note_unread"), "prune keeps the unclaimed gift and the unread note")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
