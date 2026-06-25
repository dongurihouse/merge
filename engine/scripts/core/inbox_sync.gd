extends RefCounted
## MAIL SYNC — tops up the local mailbox (core/inbox.gd) from a remote operator feed (a STATIC file).
##
## The mailbox is a small CAPPED to-do list (Inbox.MAIL_CAP). Each sync: prune dealt-with mail → GET the
## whole feed → fold in any message we have NOT folded before, up to what FITS (remaining_slots). A full
## box never hits the network. The NETWORK shell (sync(), an HTTPRequest) is thin; the FEED→inbox logic
## is the PURE apply_feed() below, unit-tested with no server. sync() NEVER blocks play or shows the
## player an error — a dead network is a no-op.
##
## STATIC FEED, CLIENT-SIDE IDEMPOTENCY: the feed is a plain static file (no query handling), so the
## client pulls the FULL list every time and dedups itself. Inbox.seen() is a permanent per-id ledger of
## everything ever folded — it survives prune, so a claimed-and-pruned gift the file still lists is never
## re-delivered (no double-claim). `seq` is kept only to order the array; the client does not filter on it.
##
## CONTRACT
##   Request:  GET <FEED_URL>                              # whole file, no query params
##             header  X-Player-Id: <id>                   # only when an identity exists (else broadcast)
##   Response: { "messages": [
##                 { "seq": 141,                           # ordering hint only — author the array ascending
##                   "id": "news_...",                     # REQUIRED, stable, NEVER reused — the dedup key
##                   "title": "...", "body": "...",
##                   "icon": "gift",                       # inbox icon id (gift/leaf/news/gem/coin/star)
##                   "reward": {"coins":100,"gems":0,"water":0} },  # optional — absent = a plain note
##                 ...
##               ] }
##   The file lists every currently-live message; removing one stops NEW players from getting it (players
##   who already took it keep their copy). Scheduling/targeting are not supported by a static file — a
##   future Worker could add `?since=` windows + per-player targeting, and the seen-ledger keeps the
##   client correct either way.

const Inbox = preload("res://engine/scripts/core/inbox.gd")

# The live operator feed (a static JSON file on the dongurihouse.net CDN — see dh/www/docs/liveops.md).
const FEED_URL := "https://dongurihouse.net/donguri-merge/mail.json"
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
	var err := req.request(url, headers)           # GET the whole static feed; the client dedups by id
	if err != OK:                                  # couldn't even start (bad url / no TLS) — silent no-op
		if is_instance_valid(req):
			req.queue_free()
		if on_done.is_valid():
			on_done.call(0)

# PURE: fold a feed reply into the capped mailbox. Adds each message we have NOT folded before (by id,
# tracked permanently in Inbox.seen()), in array order, up to the box's remaining slots. A message with
# no room is left untaken and unmarked, so it comes back on the next fetch. Returns the count added.
# Never crashes on bad input.
static func apply_feed(text: String) -> int:
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		return 0
	var msgs: Variant = (data as Dictionary).get("messages", [])
	if not (msgs is Array):
		return 0
	var present := {}                              # also skip anything already sitting in the live box
	for m in Inbox.messages():
		present[String(m.get("id", ""))] = true
	var seen := Inbox.seen()                       # permanent ledger: ids ever folded (survives prune)
	var remaining := Inbox.remaining_slots()
	var folded: Array = []
	for raw in (msgs as Array):
		if remaining <= 0:
			break                                  # box full — leave the rest unmarked (refetched next time)
		if not (raw is Dictionary):
			continue
		var msg: Dictionary = raw
		var id := String(msg.get("id", ""))
		if id == "" or present.has(id) or seen.has(id):
			continue                               # no id, already in box, or already folded once — skip
		Inbox.add({
			"id": id,
			"title": String(msg.get("title", "")),
			"body": String(msg.get("body", "")),
			"icon": String(msg.get("icon", "gift")),
			"reward": msg.get("reward", {}),
		})
		present[id] = true
		folded.append(id)
		remaining -= 1
	Inbox.mark_seen(folded)                         # one write; the per-message Inbox.add()s persisted the box
	return folded.size()

# The pseudonymous player id for targeted mail, or "" when there is no identity yet (→ broadcast).
# Guarded-loaded so this file never hard-depends on the identity provider (and the iOS-only Game Center
# wiring it will eventually use). Empty everywhere until that lands.
static func _player_id() -> String:
	if ResourceLoader.exists(IDENTITY_PATH):
		var Id: Variant = load(IDENTITY_PATH)
		if Id != null and Id.has_method("player_id"):
			return String(Id.player_id())
	return ""
