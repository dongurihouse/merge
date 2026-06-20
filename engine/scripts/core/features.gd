extends RefCounted
## FEATURE FLAGS — the registry index lives in docs/FEATURES.md (Lives-in + Eval per flag).
## Flipping a bool HERE disables the feature — code-level only by owner's word
## (player-facing settings like music/sfx/calm stay in Settings).
##
## `static var` (not const) so tests can flip flags (N3's flip smokes) — runtime
## code treats it as read-only. Missing id → push_warning + TRUE, so a typo can
## never silently kill a feature.
##
## Rule N4: every NEW ambient/juice/assist/ftue feature ships behind a flag
## here, and its WORK_DONE entry names the flag so triage can index it.

static var FLAGS := {
	# assist
	"idle_hint": true,            # idle ~7s → a mergeable pair wiggles
	"discovery_ladder": true,     # tap item → upgrade-path card ("?" tiers)
	"quest_ready_check": true,    # green ✓ badge when an ask is payable
	"sell_hints": true,           # W3: stall brightens + "+N🪙" tag while dragging; 1st max-tier floater
	# juice
	"breathe_cta": true,          # the ONE suggested next action breathes
	"press_juice": true,          # buttons squash in / overshoot out
	"wallet_tick": true,          # wallet numbers count toward new values
	"fly_to_wallet": true,        # grants arc an icon to the wallet
	"scatter_in": true,           # staggered pop-in for card groups
	"floaters": true,             # drift-up feedback text
	"celebrate_bursts": true,     # particle bursts on merges/buys/restores
	"spirit_tap_hop": true,       # tapping a map spirit hops it
	"porter_collect": true,       # Y3: a porter spirit drifts in to clear the sell basket (off → chips just fade)
	"spirit_treats": true,        # Z3: a 10🪙 acorn treat at the stall — a wandering spirit nibbles it (recurring sink)
	"giver_bob": true,            # AB: frameless fence givers idle-bob over the rail
	"gen_preview": true,          # V: locked generators show a greyed "after N spots" silhouette
	# ambient
	"winback_rain_beat": true,    # >=48h away → full water + the rainy minute
	"ambient_characters": true,   # characters wander the scenes
	"ambient_weather": true,      # breeze/rain/snow schedule
	# feature
	"game_center": false,         # iOS Game Center sign-in for a pseudonymous player id (OFF until the GodotApplePlugins plugin is in the iOS export — see docs/design/apple-services-setup.md)
	"mail_sync": false,           # server-driven mail: pull the remote operator feed on map open (OFF until core/inbox_sync.gd::FEED_URL points at a real endpoint)
	"item_backing": true,         # AF3: ON — re-purposed as a soft warm contact shadow under each piece
	"drag_swap": true,            # drop an item on another occupied cell → swap (P)
	# ftue
	"ftue_free_pops": false,      # retired: water now costs from the first pop (no 10-pop free intro)
	"ftue_staged_chrome": true,   # merchant ch1+, bag ch2+ (the water meter is always shown now)
	"ftue_feature_spotlight": true,  # T28: a feature's FIRST appearance → spotlight + pulse + a mimed tap/drag guide (§14)
	"daily_login_popup": true,    # T45: the day's first hub open auto-shows the login calendar once (§18 — after a rewarding moment, skips the cold first FTUE session)
}

static func on(id: String) -> bool:
	if not FLAGS.has(id):
		push_warning("Features.on(\"%s\"): unknown flag — defaulting ON" % id)
		return true
	return bool(FLAGS[id])
