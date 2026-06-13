# FEATURE INDEX — every feature & small thing, for later evaluate/improve/remove
(owner 2026-06-11 · written by TRIAGE only, like BUILD_QUEUE.md · eng reports
new features via WORK_DONE and triage indexes them here)

Each row: the code flag (in `scripts/features.gd`, order N), where it lives,
and an **Eval** column the owner fills during playtests (keep / improve / cut).
Categories: `ambient` `juice` `assist` `ftue` — these get bool flags.
`tuning` rows are numeric dials (no bool; the dial is named); `core` rows are
indexed for visibility but NOT flaggable (removing them is a design change).

## Live

| flag / dial | cat | what | where | Eval |
|---|---|---|---|---|
| `idle_hint` | assist | after ~4.5s idle (W1, was 7), a mergeable pair ROCKS gently (±6°, 3 slow cycles); renudges ~4s | grove.gd `_process`/`_hint_pair` | |
| `breathe_cta` | juice | the ONE suggested next action breathes (gate, cheapest pin, ready card) | FX.breathe_once call sites | |
| `press_juice` | juice | every button squashes 0.96 in, overshoots out | Look.add_press_juice | |
| `wallet_tick` | juice | wallet numbers count toward new values | hud.gd `_set_or_tick` / FX.tick | |
| `fly_to_wallet` | juice | grants arc an icon to the wallet chip | FX (G2 shop, deliveries) | |
| `scatter_in` | juice | staggered pop-in for card/section groups | FX.scatter_in (shop, fence) | |
| `floaters` | juice | outlined drift-up feedback text ("+2★", "Cleared!") | FX.floating_text | |
| `celebrate_bursts` | juice | particle bursts on merges/buys/zone-restored | FX.burst / celebrate_at | |
| `winback_rain_beat` | ambient | "It rained while you were away" full-water beat | grove.gd `_load_state` | |
| `discovery_ladder` | assist | tap item → upgrade path card, unseen tiers "?" | grove.gd `_open_ladder` + grove.seen | |
| `quest_ready_check` | assist | green ✓ badge + brighten when an ask is payable | grove.gd `_refresh_giver_lights` | |
| `sell_hints` | assist | W3: while dragging, the stall brightens + a live "+N🪙" tag at the merchant's shoulder; first max-tier item floats a one-time "sell at the stall" hint | grove.gd `_show_sell_affordance`/`_note_item_landed` | |
| `customize_variants` | feature | owned spots offer coin/gem looks (inline strip) | home.gd `_apply_variant` + G.spot_variants | |
| `ftue_free_pops` | ftue | first 10 pops cost no water; meter appears after | grove.gd `_pop_seed`/`_ftue_pops_done` | |
| `ftue_staged_chrome` | ftue | merchant from ch1, bag from ch2, water chip after intro pops | grove.gd | |
| `ambient_spirits` | ambient | spirit folk wander; count = 1 + restored zones (cap 5) | ambient.gd (L; flag retrofitted by N, 8ddc1ab) | |
| `ambient_weather` | ambient | clear/breeze/rain/snow hourly schedule + win-back rain minute, calm-wins | ambient.gd (L; flag via N) | |
| `spirit_tap_hop` | juice | tapping a map spirit makes it hop | ambient.gd (L; flag via N) | |
| `porter_collect` | juice | Y3: a porter spirit drifts in to clear the sell basket (off → the chips just fade on the same timer) | grove.gd `_porter_collect`/`_play_porter` | |
| `wayside_decor` | feature | Z2: coin-priced cosmetic plots scattered on the map (the structural coin SINK; 4 per restored zone, 40–150🪙) | home.gd `_make_wayside`/`buy_wayside` | |
| `spirit_treats` | feature | Z3: a 10🪙 acorn treat at the merchant stall — a wandering spirit scurries over + hops (the recurring coin sink) | grove.gd `_buy_treat` | |
| `drag_swap` | feature | drop on an occupied cell SWAPS the two items (merge keeps precedence) | grove.gd drop chain + grove_board.swap (P, 63ca797) | |
| `item_backing` | juice | dark warm-earth ellipse under every occupied cell (board contrast) — **order AC2 flips the default OFF (light tray v3 carries the contrast); owner re-picks from the AC2 crops** | grove.gd `_make_piece` (U, 907fe30) | |
| `interior_view` | core | zone interiors (closed chest → full-screen room) — **NOT flagged: Director disposition on eng#37's flag — load-bearing navigation (T/Q build on it; off = soft-lock on spot buying)** | home.gd `_open_interior` (K) | — |
| `bramble_line_gates` | core | edge brambles demand late-line tiers (endgame arc) | grove_content.bramble_gate | — |
| `gate_pause` | core | givers pause when the frontier spot is affordable — **order AA DELETES this (soft star gate); row moves to Removed when AA ships** | grove.gd `_gate_ready`/`_active_quest_idx` | — |
| `spot_level_gates` | core | items unlock by player level (rank-derived, strand-proof) | G.spot_level_req | — |
| `ASK_WEIGHT 0.6` | tuning | pops lean toward asked lines | grove_content.gd | |
| `COIN_DROP_RATE 0.10` | tuning | merges sometimes shake a coin loose | grove_content.gd | |
| `IDLE_HINT_SECS 7` | tuning | idle hint delay | grove.gd | |
| `TIER_ODDS [.65 .25 .09 .01]` | tuning | pop tier distribution | grove_content.gd | |

## Pending (flag reserved; lands with its order)

| flag | cat | what | order |
|---|---|---|---|
| `gen_preview` | assist | greyed silhouette + "after N more spots" chip on future generator cells | V |
| `giver_bob` | juice | frameless fence givers idle-bob gently (±3px, ~3s) | AB |
| `porter_collect` | ambient | porter spirit collects the sell basket every ~3 min (buy-back expiry) | Y |
| `spirit_treats` | juice | 10🪙 acorn treat → a spirit scurries over, nibbles, happy hop | Z |

## Removed / retired (history, so we don't re-litigate)

- on-map open-state scatter (F) → superseded by interiors (K, §0c #10)
- zone chest "lid opens in place" list (§0c #8) → superseded by K
- scattered price pins around buildings (§0c #9 open state) → superseded by K
- centered customize modal → inline swatch strip (F2)
- emoji glyph UI → sprite icon kit (G-UI)
