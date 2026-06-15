extends RefCounted
## FEATURE FLAGS (order N; the index lives in FEATURES.md, triage-owned).
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
	"spot_ghost": true,           # §8: unowned restoration spots ghost-preview the buildable (low-alpha, behind the price-pin)
	# ambient
	"winback_rain_beat": true,    # >=48h away → full water + the rainy minute
	"ambient_characters": true,   # characters wander the scenes
	"ambient_weather": true,      # breeze/rain/snow schedule
	# feature
	"customize_variants": true,   # owned spots offer coin/gem looks
	"item_backing": true,         # AF3: ON — re-purposed as a soft warm contact shadow under each piece
	"drag_swap": true,            # drop an item on another occupied cell → swap (P)
	# ftue
	"ftue_free_pops": true,       # first 10 pops cost no water
	"ftue_staged_chrome": true,   # merchant ch1+, bag ch2+, water chip after intro
}

static func on(id: String) -> bool:
	if not FLAGS.has(id):
		push_warning("Features.on(\"%s\"): unknown flag — defaulting ON" % id)
		return true
	return bool(FLAGS[id])
