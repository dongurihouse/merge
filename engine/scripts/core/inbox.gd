extends RefCounted
## THE MAILBOX — the LiveOps inbox (HUD chrome backlog · the one net-new LiveOps system).
## A small store-backed mailbox for OPERATOR messages: gifts, compensation, and news. Each
## message can carry a claimable reward (coins / 💎 / water); the HUD's Inbox button wears an
## unread badge driven by unread_count() and lights when there's something to grab.
##
## PURE engine (core/ layer — no ui/, no scenes/): the message list + the claim/grant live
## here; the list persists in the grove blob under "inbox" (a sibling of vault/daily), lazy-
## init to [] and DEFAULTED on old saves by the deep-merge-over-defaults path (no migration).
## The diegetic parchment surface is ui/inbox.gd. Mirrors core/login.gd + core/vault.gd: the
## reward dict + its grant (Save.add_coins / add_diamonds / capped grove water) match the
## login ladder's _grant exactly, so the two faucets pay the same way and obey the same
## §4/§10 discipline (coins/premium freely; water capped at WATER_CAP, never self-sustaining).
##
## A message is a small Dictionary:
##   {id, title, body, icon, reward:{coins,gems,water}, claimed:bool, read:bool, ts:float}
## Newest first is fine; add() prepends so a fresh gift sits at the top of the list.

const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const D = Game.DATA                                  # the active game's data (WATER_CAP)

# The mailbox is a small, capped to-do list — NOT a growing archive. It holds at most MAIL_CAP
# messages; the server-driven sync only pulls enough to top it up to the cap (remaining_slots), and
# "dealt-with" mail (claimed gifts / read notes) is pruned so room frees up over time. One config knob.
const MAIL_CAP := 10

# --- the stored list ----------------------------------------------------------------

## The persisted message list (a live ref in the grove blob). Lazy-inits to [] and SEEDS a
## couple of friendly starter messages exactly once (guarded on a flag), so a new inbox isn't
## empty but a returning save is never re-seeded.
static func messages() -> Array:
	var g := Save.grove()
	if not g.has("inbox"):
		g["inbox"] = []
	if not bool(g.get("inbox_seeded", false)):
		g["inbox_seeded"] = true
		g["inbox_icons_v2"] = true        # a fresh seed already carries the plated mail-kit icons
		_seed(g["inbox"])
		Save.grove_write()
	elif not bool(g.get("inbox_icons_v2", false)):
		g["inbox_icons_v2"] = true        # one-time: lift an already-seeded inbox onto the plated icons
		_migrate_seed_icons(g["inbox"])
		Save.grove_write()
	return g["inbox"]

# Seed the welcome note + a small starter gift (newest first → the gift sits on top). Called
# ONCE ever, guarded by the inbox_seeded flag in the blob.
static func _seed(list: Array) -> void:
	_append(list, {
		"id": "welcome",
		"title": "Welcome to the grove",
		"body": "We're so glad you're here. Tend it gently — the grove grows with you.",
		"icon": "leaf",
		"reward": {},
	})
	_append(list, {
		"id": "starter_gift",
		"title": "A little something",
		"body": "A handful of coins to get you started. Enjoy!",
		"icon": "gift",
		"reward": {"coins": 100},
	})

# One-time icon migration (inbox_icons_v2): an inbox seeded before the plated mail-kit icons existed
# still carries the old glyph ids (star / coin) — lift the two known starter messages onto the new
# plated sprites in place. Targeted by id + old value so it never clobbers a deliberately-set icon.
static func _migrate_seed_icons(list: Array) -> void:
	for m in list:
		var id := String(m.get("id", ""))
		if id == "welcome" and String(m.get("icon", "")) == "star":
			m["icon"] = "leaf"
		elif id == "starter_gift" and String(m.get("icon", "")) == "coin":
			m["icon"] = "gift"

# --- reads --------------------------------------------------------------------------

## Unread attention count: a message counts if it is unread OR still has an unclaimed reward
## (so a read-but-unclaimed gift keeps the badge lit until it's grabbed). Drives the HUD badge.
static func unread_count() -> int:
	var n := 0
	for m in messages():
		if not bool(m.get("read", false)) or _is_unclaimed_gift(m):
			n += 1
	return n

## Whether ANY message carries a non-empty reward that hasn't been claimed yet (the "you have
## a gift" read — lights the button even after the list has been opened/read).
static func has_unclaimed() -> bool:
	for m in messages():
		if _is_unclaimed_gift(m):
			return true
	return false

# A message has a claimable gift when it carries a positive reward and isn't claimed yet.
static func _is_unclaimed_gift(m: Dictionary) -> bool:
	return not bool(m.get("claimed", false)) and _reward_total(m.get("reward", {})) > 0

static func _reward_total(rew: Dictionary) -> int:
	return int(rew.get("coins", 0)) + int(rew.get("gems", 0)) + int(rew.get("water", 0))

# --- server-sync state: the cap + the cursor ----------------------------------------

## How many MORE messages the box can hold right now (MAIL_CAP minus the current count, clamped at 0).
## The sync asks for exactly this many; when it's 0 the box is full and we don't fetch at all.
static func remaining_slots() -> int:
	return maxi(0, MAIL_CAP - messages().size())

## The high-watermark of server mail already folded in ("last mail gotten"). 0 on a fresh save, so the
## first fetch asks for everything since 0. apply_feed advances it; the request sends it as `since`.
static func cursor() -> int:
	return int(Save.grove().get("inbox_cursor", 0))

static func set_cursor(seq: int) -> void:
	var g := Save.grove()
	if int(g.get("inbox_cursor", 0)) != seq:
		g["inbox_cursor"] = seq
		Save.grove_write()

## Clear "dealt-with" mail so the capped box frees room over time: drop claimed gifts and read plain
## notes, KEEP every unclaimed gift and unread message. Persists; returns the removed count. Run before
## a fetch (so remaining_slots reflects the live load) and when the mailbox opens.
static func prune() -> int:
	var list := messages()
	var keep: Array = []
	for m in list:
		if not _resolved(m):
			keep.append(m)
	var removed := list.size() - keep.size()
	if removed > 0:
		list.clear()
		list.append_array(keep)
		Save.grove_write()
	return removed

# "dealt with": a gift the player has claimed, or a plain note (no reward) they have read. Unclaimed
# gifts and unread messages are never pruned — the player hasn't acted on them yet.
static func _resolved(m: Dictionary) -> bool:
	if _reward_total(m.get("reward", {})) > 0:
		return bool(m.get("claimed", false))
	return bool(m.get("read", false))

# --- mutations ----------------------------------------------------------------------

## Append a message (newest first), filling defaults for missing keys and assigning an id/ts
## when absent. Persists. The reward dict is normalised to {coins,gems,water} so the UI + the
## claim can read it without guards.
static func add(msg: Dictionary) -> void:
	_append(messages(), msg)
	Save.grove_write()

# Prepend a normalised message onto `list` (no persist — callers flush). Shared by add() + _seed.
static func _append(list: Array, msg: Dictionary) -> void:
	var rew_in: Dictionary = msg.get("reward", {})
	list.push_front({
		"id": String(msg.get("id", _gen_id())),
		"title": String(msg.get("title", "")),
		"body": String(msg.get("body", "")),
		"icon": String(msg.get("icon", "star")),
		"reward": {
			"coins": int(rew_in.get("coins", 0)),
			"gems": int(rew_in.get("gems", 0)),
			"water": int(rew_in.get("water", 0)),
		},
		"claimed": bool(msg.get("claimed", false)),
		"read": bool(msg.get("read", false)),
		"ts": float(msg.get("ts", Time.get_unix_time_from_system())),
	})

# A stable-enough id when a message doesn't bring its own (timestamp + a small counter so two
# adds in the same second don't collide).
static var _seq := 0
static func _gen_id() -> String:
	_seq += 1
	return "m_%d_%d" % [int(Time.get_unix_time_from_system()), _seq]

## Mark every message read (opening the mailbox does this). Persists. Does NOT touch claimed —
## an unclaimed gift keeps the badge lit via has_unclaimed even after the list is read.
static func mark_all_read() -> void:
	var changed := false
	for m in messages():
		if not bool(m.get("read", false)):
			m["read"] = true
			changed = true
	if changed:
		Save.grove_write()

## Grant a message's reward, mark it claimed, persist, and return the granted reward dict. A
## no-op (returns {}) if the id isn't found or it's already claimed. Mirrors login.gd's _grant:
## coins/gems go to the wallet; water tops up the capped grove can. Grant + flag persist together.
static func claim(id: String) -> Dictionary:
	for m in messages():
		if String(m.get("id", "")) != id:
			continue
		if bool(m.get("claimed", false)):
			return {}
		var rew: Dictionary = m.get("reward", {})
		_grant(rew)
		m["claimed"] = true
		Save.grove_write()
		return rew
	return {}

# Pay out a reward dict. Coins/gems go straight to the wallet (each persists); water tops up the
# grove can, CAPPED at WATER_CAP (a modest top-up, never self-sustaining — the §4/§10 invariant
# the login ladder obeys). Returns nothing; the final grove_write flushes the water grant.
static func _grant(rew: Dictionary) -> void:
	if int(rew.get("coins", 0)) > 0:
		Save.add_coins(int(rew.coins))           # persists
	if int(rew.get("gems", 0)) > 0:
		Save.add_diamonds(int(rew.gems))         # persists
	if int(rew.get("water", 0)) > 0:
		var g := Save.grove()
		g["water"] = mini(int(D.WATER_CAP), int(g.get("water", 0)) + int(rew.water))
		Save.grove_write()
