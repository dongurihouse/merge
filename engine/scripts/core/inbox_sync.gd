extends RefCounted
## SERVER-DRIVEN MAIL SYNC — tops up the local mailbox (core/inbox.gd) from a remote operator feed.
##
## The mailbox is a small CAPPED to-do list (Inbox.MAIL_CAP). Each sync: prune dealt-with mail → ask
## the server for only what's NEW (since the cursor) and only as many as will FIT (remaining_slots) →
## fold the reply in, advancing the cursor. A full box never hits the network. The NETWORK shell
## (sync(), an HTTPRequest) is thin; the FEED→inbox logic is the PURE apply_feed() below, unit-tested
## with no server. sync() NEVER blocks play or shows the player an error — a dead network is a no-op.
##
## CONTRACT
##   Request:  GET <FEED_URL>?since=<cursor>&limit=<n>     # cursor = last seq folded (0 on a fresh save)
##             header  X-Player-Id: <id>                   # only when an identity exists (else broadcast)
##   Response: { "messages": [
##                 { "seq": 141,                           # REQUIRED, server-monotonic — drives the cursor
##                   "id": "news_...",                     # REQUIRED, stable — dedup safety net
##                   "title": "...", "body": "...",
##                   "icon": "gift",                       # inbox icon id (gift/leaf/news/gem/coin/star)
##                   "reward": {"coins":100,"gems":0,"water":0} },  # optional — absent = a plain note
##                 ...
##               ] }
##   The server returns ONLY currently-live messages with seq > since, ASCENDING, at most `limit` of
##   them. Scheduling/expiry (start/end windows) and targeting live SERVER-SIDE — the client just folds
##   what it's handed, dedups by id, caps at the box size, and advances the cursor to the last seq it took.

const Inbox = preload("res://engine/scripts/core/inbox.gd")

# TODO(server): point at the real endpoint once the backend is running. A plain HTTPS GET returning the
# feed above — a static file on a CDN/bucket, or a dynamic Worker; the client contract is identical.
const FEED_URL := "https://example.invalid/acornforest/mail/feed.json"
const IDENTITY_PATH := "res://engine/scripts/core/identity.gd"
const SYNC_TIMEOUT := 8.0

# Top the mailbox up from the feed. `host` parents the transient HTTPRequest. `on_done(added)` fires when
# finished (added = 0 on ANY failure / full box — sync never blocks play or surfaces a player error).
static func sync(host: Node, on_done: Callable = Callable(), url: String = FEED_URL) -> void:
	Inbox.prune()                                  # free slots from dealt-with mail before sizing the ask
	var remaining := Inbox.remaining_slots()
	if remaining <= 0:                             # box full — don't even hit the network ("clear old ones first")
		if on_done.is_valid():
			on_done.call(0)
		return
	var full_url := "%s?since=%d&limit=%d" % [url, Inbox.cursor(), remaining]
	var req := HTTPRequest.new()
	req.timeout = SYNC_TIMEOUT
	host.add_child(req)
	req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		var added := 0
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			added = apply_feed(body.get_string_from_utf8())
		if is_instance_valid(req):
			req.queue_free()
		if on_done.is_valid():
			on_done.call(added))
	var headers := PackedStringArray()
	var pid := _player_id()
	if pid != "":
		headers.push_back("X-Player-Id: " + pid)   # present only when an identity exists → targeted; else broadcast
	var err := req.request(full_url, headers)
	if err != OK:                                  # couldn't even start (bad url / no TLS) — silent no-op
		if is_instance_valid(req):
			req.queue_free()
		if on_done.is_valid():
			on_done.call(0)

# PURE: fold a feed reply into the capped mailbox. Adds new (by id), in seq order, up to the box's
# remaining slots, and advances the cursor to the last seq it CONSUMED — never past a message it had no
# room for (those come back on the next fetch). Returns the count added. Never crashes on bad input.
static func apply_feed(text: String) -> int:
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		return 0
	var msgs: Variant = (data as Dictionary).get("messages", [])
	if not (msgs is Array):
		return 0
	var present := {}                              # dedup by id, bounded by the cap (≤ MAIL_CAP entries)
	for m in Inbox.messages():
		present[String(m.get("id", ""))] = true
	var remaining := Inbox.remaining_slots()
	var cursor := Inbox.cursor()
	var added := 0
	for raw in (msgs as Array):
		if remaining <= 0:
			break                                  # box full — leave the rest (cursor NOT advanced past them)
		if not (raw is Dictionary):
			continue
		var msg: Dictionary = raw
		var id := String(msg.get("id", ""))
		var seq := int(msg.get("seq", 0))
		if id != "" and not present.has(id):
			Inbox.add({
				"id": id,
				"title": String(msg.get("title", "")),
				"body": String(msg.get("body", "")),
				"icon": String(msg.get("icon", "gift")),
				"reward": msg.get("reward", {}),
			})
			present[id] = true
			added += 1
			remaining -= 1
		if seq > cursor:
			cursor = seq                           # consumed (folded OR a permanent dup/no-id skip) — advance past it
	Inbox.set_cursor(cursor)
	return added

# The pseudonymous player id for targeted mail, or "" when there is no identity yet (→ broadcast).
# Guarded-loaded so this file never hard-depends on the identity provider (and the iOS-only Game Center
# wiring it will eventually use). Empty everywhere until that lands.
static func _player_id() -> String:
	if ResourceLoader.exists(IDENTITY_PATH):
		var Id: Variant = load(IDENTITY_PATH)
		if Id != null and Id.has_method("player_id"):
			return String(Id.player_id())
	return ""
