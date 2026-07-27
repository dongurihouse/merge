extends RefCounted
## The reward-flight ACTION TABLE — the seven game moments that route through the shared
## Coin Flow component (FX.reward_arrival), and how each one stages itself in the workbench.
##
## Lives in its own file so the FX workbench's sidebar (fx_gallery_view.gd) and its embedded
## preview (fx_workbench_view.gd) read the SAME table without the sidebar reaching into a
## view class for it. `id` must match an entry in FX.REWARD_FX_IDS — that is the id the
## per-action gate (FX.reward_fx_enabled) is keyed on.
##
## Fields: id · label (sidebar text) · screen/context (which preview backdrop) · icon (the
## flying glyph) · target (which wallet chip it lands in) · source_kind (what the preview
## draws as the origin) · targets (which wallet chips the preview shows) · footer (caption).

const DEFS := [
	{"id": "coin_pickup", "label": "Coin pickup", "screen": "Board", "context": "board", "icon": "coin", "target": "coin", "source_kind": "coin_piece", "targets": ["coin"], "footer": "Coin pickup routes to wallet"},
	{"id": "board_refill", "label": "Board refill", "screen": "Board", "context": "board", "icon": "water", "target": "water", "source_kind": "button", "source_label": "Refill", "targets": ["water"], "footer": "Refill button sends water to the HUD"},
	{"id": "stash_to_bag", "label": "Stash to bag", "screen": "Board", "context": "board", "icon": "bag", "target": "bag", "source_kind": "item_piece", "targets": ["bag"], "footer": "Dragged item stores into the bag"},
	{"id": "quest_payout", "label": "Quest payout", "screen": "Board", "context": "board", "icon": "coin", "target": "coin", "source_kind": "quest", "targets": ["coin"], "footer": "Quest coin reward flies from the giver chip"},
	{"id": "accept_2x", "label": "2x reward accept", "screen": "Board", "context": "board", "icon": "coin", "target": "coin", "source_kind": "offer", "targets": ["coin"], "footer": "Bonus accept pays a second coin grant"},
	{"id": "map_task_reward", "label": "Map task reward", "screen": "Map", "context": "map", "icon": "coin", "target": "coin", "source_kind": "map_card", "targets": ["gem", "coin"], "footer": "Restored place pays gems and coins"},
	{"id": "sale_payout", "label": "Sale payout", "screen": "Home", "context": "home", "icon": "coin", "target": "coin", "source_kind": "sale_item", "targets": ["coin"], "footer": "Sold item payout routes to the wallet"},
]

## The def for `id`, falling back to the first entry so a stale selection still renders.
static func def(id: String) -> Dictionary:
	for entry in DEFS:
		var d: Dictionary = entry
		if String(d.get("id", "")) == id:
			return d
	return DEFS[0]
