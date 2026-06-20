extends RefCounted
## SERVER-DRIVEN MAIL SYNC — pulls a remote operator-message feed (a JSON config fetched over an
## HTTPS GET) and folds any NEW messages into the local mailbox (core/inbox.gd), deduped by id.
##
## The split is deliberate: the NETWORK shell (sync(), an HTTPRequest) is thin and untestable headless;
## the FEED→inbox logic is the PURE apply_feed() below, so the wire contract is unit-tested with no
## server. sync() NEVER blocks play or shows the player an error — a dead network is a silent no-op.
##
## CONTRACT  (request = a plain GET, no body/auth in v1; response = the whole feed as JSON):
##   {
##     "version": 3,                       # optional, monotonic — lets the client skip a folded feed
##     "messages": [
##       { "id": "news_2026_06_20",        # REQUIRED, stable, unique — drives client dedup
##         "title": "...", "body": "...",  # shown text
##         "icon": "gift",                 # one of the inbox icon ids (gift/leaf/news/gem/coin/star)
##         "reward": {"coins":100,"gems":0,"water":0},   # optional — absent = a plain note
##         "start": 1718841600, "end": 1719446400 }      # optional unix secs (0/absent = unbounded)
##     ]
##   }
## A message is folded once, when it is first seen WITHIN [start,end]; ids already folded (or already
## present in the inbox) are skipped. The folded-id set persists in the save (grove "inbox_remote_seen").

const Inbox = preload("res://engine/scripts/core/inbox.gd")
const Save = preload("res://engine/scripts/core/save.gd")

# TODO(server): point at the real endpoint once the backend is running. A plain HTTPS GET returning
# the feed above — a static file on a CDN/bucket, or a dynamic Worker; the client contract is identical.
const FEED_URL := "https://example.invalid/tidyup/mail/feed.json"
const SYNC_TIMEOUT := 8.0

# Fetch the feed and fold new messages in. `host` parents the transient HTTPRequest node. `on_done(added)`
# fires when finished (added = 0 on ANY failure — sync never blocks play or surfaces a player error).
static func sync(host: Node, on_done: Callable = Callable(), url: String = FEED_URL) -> void:
	var req := HTTPRequest.new()
	req.timeout = SYNC_TIMEOUT
	host.add_child(req)
	req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		var added := 0
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			added = apply_feed(body.get_string_from_utf8(), Time.get_unix_time_from_system())
		if is_instance_valid(req):
			req.queue_free()
		if on_done.is_valid():
			on_done.call(added))
	var err := req.request(url)
	if err != OK:                                 # couldn't even start (bad url / no TLS) — silent no-op
		if is_instance_valid(req):
			req.queue_free()
		if on_done.is_valid():
			on_done.call(0)

# PURE: parse a feed JSON string and fold new, in-window messages into the inbox. Returns the count
# added. Skips (never crashes): bad JSON, a non-array `messages`, a message with no id, ids already
# folded or already in the inbox, and messages outside their [start,end] window. Expired-before-seen
# ids are marked seen (so they never fold later); not-yet-live ids are left unseen (fold once live).
static func apply_feed(text: String, now: float) -> int:
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		return 0
	var msgs: Variant = (data as Dictionary).get("messages", [])
	if not (msgs is Array):
		return 0
	var g := Save.grove()
	var seen: Dictionary = g.get("inbox_remote_seen", {})
	# also dedup against ids already in the inbox (covers a save predating the seen-set, and the local seed)
	var present := {}
	for m in Inbox.messages():
		present[String(m.get("id", ""))] = true
	var added := 0
	for raw in (msgs as Array):
		if not (raw is Dictionary):
			continue
		var msg: Dictionary = raw
		var id := String(msg.get("id", ""))
		if id == "" or seen.has(id) or present.has(id):
			continue
		var start := float(msg.get("start", 0))
		var end := float(msg.get("end", 0))
		if start > 0.0 and now < start:
			continue                              # not live yet — re-evaluate on a later sync (leave unseen)
		if end > 0.0 and now > end:
			seen[id] = true                       # expired before we ever showed it — burn the id, never fold
			continue
		Inbox.add({
			"id": id,
			"title": String(msg.get("title", "")),
			"body": String(msg.get("body", "")),
			"icon": String(msg.get("icon", "gift")),
			"reward": msg.get("reward", {}),
		})
		seen[id] = true
		added += 1
	g["inbox_remote_seen"] = seen
	Save.grove_write()
	return added
