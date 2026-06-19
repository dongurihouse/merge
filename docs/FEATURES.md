# Feature-Flag Registry (the §11 index)

The index of **everything we add** behind a code-level flag — so when something breaks we can
flip features off one at a time and find the culprit (`merge_spec` §11). Every player-facing
*assist / juice / ambient / feature / ftue* behavior ships behind a `static var` bool in
`engine/scripts/core/features.gd` (the `FLAGS` dict). To disable one, **flip its bool there** —
that is the only switch; an **unknown id → `true` + a `push_warning`** so a typo can never
silently kill a feature, and **all flags default ON**.

This file is the registry that §11 calls for: per flag, **Lives-in** (the code site that reads
it) and an **Eval** (the owner's *keep / improve / cut* verdict). It is kept in sync with
`features.gd` — adding a flag there means adding a row here (rule N4).

- **Player-facing toggles** (music / sfx / calm-mode) are **not** here — they live in Settings.
  This registry is code-level only.
- **Tuning dials** (`TIER_ODDS`, `ASK_WEIGHT`, `COIN_DROP_RATE`, `POP_COST`, idle timings) are
  numeric values, not bools — not flags, not indexed here.
- **Eval is an owner verdict.** Every row below is `keep — default ON, owner review pending`:
  truthful, since all 24 ship ON and none has had a keep/improve/cut pass yet. These need an
  owner sweep (see the note at the bottom).

Paths in **Lives-in** are relative to the repo root; `file.gd:func()` is the reading function.

---

## assist

| Flag | What it does | Lives-in | Eval |
|---|---|---|---|
| `idle_hint` | idle ~7s → a mergeable pair wiggles | `engine/scripts/scenes/board.gd` `_process()` (L302), `_hint_pair()` (L312) | keep — default ON, owner review pending |
| `discovery_ladder` | tap item → upgrade-path card ("?" tiers) | `engine/scripts/scenes/board.gd` `_open_ladder()` (L2190) | keep — default ON, owner review pending |
| `quest_ready_check` | green ✓ badge when an ask is payable | `engine/scripts/scenes/board.gd` `_refresh_giver_lights()` (L1084) | keep — default ON, owner review pending |
| `sell_hints` | W3: stall brightens + "+N🪙" tag while dragging; 1st max-tier floater | `engine/scripts/scenes/board.gd` `_show_sell_affordance()` (L1047), `_note_item_landed()` (L1064) | keep — default ON, owner review pending |

## juice

| Flag | What it does | Lives-in | Eval |
|---|---|---|---|
| `breathe_cta` | the ONE suggested next action breathes | `engine/scripts/ui/fx.gd` `breathe_once()` (L101) | keep — default ON, owner review pending |
| `press_juice` | buttons squash in / overshoot out | `engine/scripts/ui/skin.gd` `add_press_juice()` (L217) | keep — default ON, owner review pending |
| `wallet_tick` | wallet numbers count toward new values | `engine/scripts/ui/fx.gd` `tick()` (L137) | keep — default ON, owner review pending |
| `fly_to_wallet` | grants arc an icon to the wallet | `engine/scripts/ui/fx.gd` `fly_to_wallet()` (L155); `engine/scripts/scenes/board.gd` `_grant_sale()` (L2070) | keep — default ON, owner review pending |
| `scatter_in` | staggered pop-in for card groups | `engine/scripts/ui/fx.gd` `scatter_in()` (L123) | keep — default ON, owner review pending |
| `floaters` | drift-up feedback text | `engine/scripts/ui/fx.gd` `floating_text()` (L68) | keep — default ON, owner review pending |
| `celebrate_bursts` | particle bursts on merges/buys/restores | `engine/scripts/ui/fx.gd` `celebrate_at()` (L94), `burst()` (L198) | keep — default ON, owner review pending |
| `spirit_tap_hop` | tapping a map spirit hops it | `engine/scripts/scenes/map.gd` `_map_tap()` (L647) | keep — default ON, owner review pending |
| `porter_collect` | Y3: a porter spirit drifts in to clear the sell basket (off → chips just fade) | `engine/scripts/scenes/board.gd` `_porter_collect()` (L2147) | keep — default ON, owner review pending |
| `spirit_treats` | Z3: a 10🪙 acorn treat at the stall — a wandering spirit nibbles it (recurring sink) | `engine/scripts/scenes/board.gd` `_make_merchant_stand()` (L981), `_buy_treat()` (L1023) | keep — default ON, owner review pending |
| `giver_bob` | AB: frameless fence givers idle-bob over the rail | `engine/scripts/scenes/board.gd` `_giver_bob()` (L853) | keep — default ON, owner review pending |
| `gen_preview` | V: locked generators show a greyed "after N spots" silhouette | `engine/scripts/scenes/board.gd` `gen_preview_cells` field (L66); read-site PARKED (T17) — preview disabled under per-zone generators, the flag is held (L1148) | keep — default ON, owner review pending |

## ambient

| Flag | What it does | Lives-in | Eval |
|---|---|---|---|
| `winback_rain_beat` | >=48h away → full water + the rainy minute | `engine/scripts/ui/ambient.gd` `check_winback()` (L121), `winback_active()` (L130) | keep — default ON, owner review pending |
| `ambient_characters` | characters wander the scenes | `engine/scripts/ui/ambient.gd` `build_layer()` (L38) | keep — default ON, owner review pending |
| `ambient_weather` | breeze/rain/snow schedule | `engine/scripts/ui/ambient.gd` `build_weather()` (L159) | keep — default ON, owner review pending |

## feature

| Flag | What it does | Lives-in | Eval |
|---|---|---|---|
| `item_backing` | AF3: ON — re-purposed as a soft warm contact shadow under each piece | `engine/scripts/scenes/board.gd` `_make_piece()` (L1219) | keep — default ON, owner review pending |
| `drag_swap` | drop an item on another occupied cell → swap (P) | `engine/scripts/scenes/board.gd` `_on_release()` (L1554) | keep — default ON, owner review pending |

## ftue

| Flag | What it does | Lives-in | Eval |
|---|---|---|---|
| `ftue_free_pops` | first 10 pops cost no water | `engine/scripts/scenes/board.gd` `_ftue_pops_done()` (L545) | keep — default ON, owner review pending |
| `ftue_staged_chrome` | merchant ch1+, bag ch2+, water chip after intro | `engine/scripts/scenes/board.gd` `_ready()` (L229), `_update_water_hud()` (L554), `_rebuild_givers()` (L622) | keep — default ON, owner review pending |

---

## Core — indexed, not flaggable

A handful of behaviors are core: **indexed here but not behind a flag**. Removing one is a
**design change, not a toggle** — there is no bool to flip.

| Behavior | What it is | Lives-in |
|---|---|---|
| `gate_pause` | §7 soft gate — active giver-stand count metered to the NEXT unlock (fence empties when the next unlock is affordable → wordless "go restore") | `engine/scripts/core/content.gd` `active_giver_count()` region (L298); sizing const `STARS_PER_QUEST_EST` in `games/grove/grove_data.gd` (L127) |
| `spot_level_gates` | §4 per-cell `min_level` gating — a sealed cell unseals when the player's Level reaches its `cell_min_level`, opened by an adjacent merge | `engine/scripts/core/content.gd` `cell_min_level()` (L208); `engine/scripts/core/board_model.gd` `openable_brambles()` (L157); table `MIN_LEVEL` in `games/grove/grove_data.gd` (L95) |
| `daily_login_popup` | §18 — the daily login calendar auto-pops on the day's first hub open (gated past the cold FTUE; never on first launch) | `engine/scripts/scenes/map.gd` `_maybe_login_popup_deferred()` (T45, on branch `t45-integration` pending merge) |

---

_Owner action pending: the **Eval** column is stubbed `keep — default ON` for all 24 flags. None
has had a keep / improve / cut review — that verdict is the owner's call and needs a sweep._
