extends SceneTree
## Headless tests for the server-driven mail SYNC contract (core/inbox_sync.gd::apply_feed) + the
## capped-mailbox helpers it leans on (core/inbox.gd seen/remaining_slots/prune). Pure logic, no
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

	# fresh box = the 2 seeded starters (welcome + starter_gift), empty seen-ledger, room for CAP-2 more.
	fresh("base")
	ok(Inbox.seen().is_empty(), "a fresh save has an empty seen-ledger (nothing folded yet)")
	ok(Inbox.remaining_slots() == Inbox.MAIL_CAP - 2, "remaining_slots = cap minus the 2 seeded messages")

	# 1. FOLD: a feed folds its messages in, returns the count, and records each id in the seen-ledger.
	var n := Sync.apply_feed(_feed(5, 3))                    # ids g5,g6,g7
	ok(n == 3 and _has("g5") and _has("g7"), "a feed folds its new messages into the box")
	ok(Inbox.seen().has("g5") and Inbox.seen().has("g7"), "folded ids are recorded in the seen-ledger")

	# 2. RE-APPLY: folding the same feed again adds nothing (the ids are already in the box AND seen).
	var n2 := Sync.apply_feed(_feed(5, 3))
	ok(n2 == 0, "re-applying a folded feed is a no-op")

	# 3. NO RE-DELIVERY across prune: the whole point of the seen-ledger. Fold a gift, claim it, prune it
	#    out of the box, then re-ingest a feed that STILL lists it — it must NOT come back (no double-claim).
	fresh("seen")
	Sync.apply_feed('{"messages":[{"seq":1,"id":"gift1","title":"g","body":"b","reward":{"coins":50}}]}')
	ok(_has("gift1"), "the gift folds in on first sync")
	Inbox.claim("gift1")                                     # claimed → now "dealt with"
	ok(Inbox.prune() >= 1 and not _has("gift1"), "claiming then pruning removes the gift from the box")
	var redelivered := Sync.apply_feed('{"messages":[{"seq":1,"id":"gift1","title":"g","body":"b","reward":{"coins":50}}]}')
	ok(redelivered == 0 and not _has("gift1"), "a pruned-but-claimed gift the feed still lists is NOT re-delivered")

	# 4. CAP + overflow: a feed bigger than the box only folds up to remaining_slots; the overflow stays
	#    UNMARKED, so once slots free it folds in on a later sync.
	fresh("cap")
	var big := Sync.apply_feed(_feed(1, 50))                 # ids g1..g50, but only CAP-2 slots free
	ok(big == Inbox.MAIL_CAP - 2, "a feed only folds up to the remaining slots")
	ok(Inbox.messages().size() == Inbox.MAIL_CAP, "the box fills exactly to the cap")
	for m in Inbox.messages():
		m["read"] = true                                    # mark everything read so prune can clear the plain notes
	Inbox.prune()                                           # frees the read notes (keeps the unclaimed starter gift)
	var more := Sync.apply_feed(_feed(1, 50))                # same file → the unseen overflow (g9+) now folds in
	ok(more > 0 and _has("g%d" % Inbox.MAIL_CAP), "overflow left unmarked is folded on a later sync")

	# 5. MALFORMED: never crashes, folds nothing, ledger untouched.
	fresh("malformed")
	ok(Sync.apply_feed("not json {{{") == 0, "garbage JSON folds nothing")
	ok(Sync.apply_feed('{"messages":"oops"}') == 0, "a non-array messages field folds nothing")
	ok(Inbox.seen().is_empty(), "malformed input leaves the seen-ledger empty")

	# 6. NO-ID: a message with no id can't be deduped, so it's never folded (and never marked seen).
	fresh("noid")
	var n5 := Sync.apply_feed('{"messages":[{"seq":9,"title":"no id"}]}')
	ok(n5 == 0 and not _has("") and Inbox.seen().is_empty(), "a message with no id is skipped and not recorded")

	# 7. FULL BOX: when nothing fits, apply_feed folds nothing.
	fresh("full")
	Sync.apply_feed(_feed(1, 50))                            # fill to cap
	var n6 := Sync.apply_feed(_feed(100, 5))
	ok(n6 == 0, "a full box folds nothing")

	# 8. PRUNE: dealt-with mail (claimed gifts / read notes) clears; unclaimed gifts + unread stay.
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
