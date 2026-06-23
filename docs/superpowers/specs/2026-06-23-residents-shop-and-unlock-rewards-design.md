# Residents shop + map-unlock reward dialog — design

Date: 2026-06-23
Branch: `worktree-residents-shop`

## Goal

When a map is fully unlocked (all spots restored **and** its gate delivered — the existing
`G.can_populate(z)` / `map_complete` gate), the player should:

1. See a **one-time celebratory dialog** granting rewards (coins, diamonds, and one free spirit),
   with rewards scaling up on later maps.
2. Get a new square **Residents** button next to the Map button in the bottom nav.
3. Open a **shop-style Residents dialog** from that button (replacing today's always-on bottom
   "Welcome a spirit" panel) where each cell is a summonable resident with its icon and cost.

All dialogs reuse the existing Kit dialog framework (`dialog_frame` / `info_dialog` / `shop_dialog`)
and the existing banner chrome. No new art is authored.

## Decisions (confirmed with user)

- The always-on bottom welcome panel is **removed**; residents are summoned only via the new button → shop dialog.
- Reward scaling is **escalating**: `coins = 120 + 80*z`, `gems = 2 + z`, plus one free spirit per map.
- The free spirit is the **map's signature spirit** (`RESIDENT_SIGNATURE[map_id][0]`, the non-premium one).
- The unlock dialog is a **single-Collect reveal** (no per-row claim buttons).

### Reward table (derived from the formulas)

| z | map id    | display name | coins | 💎 | free spirit            |
|---|-----------|--------------|------:|---:|------------------------|
| 0 | farmhouse | The Farm     |   120 |  2 | hen (Hen-kin)          |
| 1 | barn      | The Orchard  |   200 |  3 | bee (Bee-kin)          |
| 2 | pond      | The Garden   |   280 |  4 | butterfly (Butterfly-kin) |
| 3 | orchard   | The Mill     |   360 |  5 | fieldmouse (Field-mouse) |
| 4 | meadow    | The Meadow   |   440 |  6 | hedgehog (Hedgehog-kin) |

## Current state (what exists today)

- `games/grove/grove_data.gd`
  - `RESIDENT_CORE`, `RESIDENT_SIGNATURE`, `RESIDENT_BASE_COST = 40`, `RESIDENT_PREMIUM_COST = 3`,
    `resident_lines(map_id)`.
  - `MAP_TASK_REWARD := {"coins": 120, "gems": 2}` — a single flat reward used today.
- `engine/scripts/core/content.gd`
  - `resident_cost(type_def)`, `welcome_resident(z, type_id)` (spend → add T1 → `resolve_resident_merges`),
    `resolve_resident_merges(z)`, `can_populate(z, unlocks, gates)` → `map_complete(...)`.
- `engine/scripts/core/save.gd`
  - `add_coins(n)`, `add_diamonds(n)`, `spend(n, reason)`, `spend_diamonds(n)`,
    `resident_counts(map_id, type_id)`, `set_resident_counts(...)`, `grove()`, `grove_write()`.
  - One-time per-map flag pattern: `grove()["task_reward"][map_id] = true`.
- `engine/scripts/scenes/map.gd`
  - `_build_map(...)`: at the `G.can_populate(z, ...)` check it builds the population layer and calls
    `_add_welcome_panel(z)`; separately calls `_grant_map_task_reward(z)` when `map_spots_done(z)`.
  - `_grant_map_task_reward(z)`: gated by `task_reward[map_id]`; grants flat `MAP_TASK_REWARD`; plays
    `_task_reward_fx` (floating coins/gems + text). Also called near line 649 (post-restore path).
  - `_add_welcome_panel` / `_welcome_row` / `_on_welcome_tap` + `resident_hits`: the always-on bottom panel.
  - `_build_chrome()`: builds the bottom nav `[Map, Play]` via `NavBar.build`; `_make_map_button()` builds
    a rounded-rect badge (`shape:"rect"`) via `Kit.home_button`. `FX.breathe_once(nav.buttons[1])` breathes Play.
- `engine/scripts/ui/ambient.gd`: `build_population_layer(bounds, members)` renders the roster.
- Kit (`games/grove/tools/ui_workbench_kit.gd`)
  - `dialog_frame(content, width, opts)` — parchment frame + banner + ✕ + scroll.
  - `info_dialog(spec, width, opts)` — title + itemized rows (`{icon,label,amount,note}`) + footer + close button.
  - `shop_dialog(sections, width, opts)` — `{caption, cards:[…]}` sections; each card built by `daily_card`.
  - `daily_card(card, opts)` renders a card; **a `node` key injects a pre-built Control as the hero**
    (line ~2064), bypassing the id→`ui/shared|currency` icon resolver. Card keys used: `node`, `label`,
    `price`, `price_icon` ("coin"/"gem"), `affordable`, `on_buy`.
  - `make_icon(id, px)` for currency icons (`coin`, `gem`); resolver only checks `ui/shared` + `ui/currency`.

## Design

### 1. Reward data — `grove_data.gd`

Add a single source of truth for the per-map unlock reward:

```gdscript
# The one-time gift for fully unlocking a map (all spots restored + gate delivered). Escalates with the
# map index z: more coins/diamonds on later maps, plus one free signature spirit. The z=0 values
# (120 coins / 2 gems) equal the old flat MAP_TASK_REWARD, so the first map's payout is unchanged.
static func map_unlock_reward(z: int) -> Dictionary:
    var sig: Array = RESIDENT_SIGNATURE.get(String(MAPS[z].id), [])
    var spirit: String = String(sig[0].id) if sig.size() > 0 else ""   # the map's non-premium signature critter
    return {"coins": 120 + 80 * z, "gems": 2 + z, "spirit": spirit}
```

- `MAP_TASK_REWARD` is removed (its only consumer was `_grant_map_task_reward`).
- Mirror as a thin `content.gd` passthrough (`G.map_unlock_reward(z)`) following the existing `D.`-aliasing
  pattern, so scene + tests call it through `G` like the other content helpers.

### 2. Free-spirit grant — `content.gd`

Extract the spend-free core of `welcome_resident` so the reward can grant a spirit without charging:

```gdscript
# Add one tier-1 instance of a resident to map z's roster and cascade two-of-a-kind merges. The shared
# core of welcome_resident (paid) and the unlock gift (free). Returns the merge events for FX.
static func grant_resident(z: int, type_id: String) -> Array:
    var map_id := String(MAPS[z].id)
    var counts: Array = Save.resident_counts(map_id, type_id).duplicate()
    counts[0] = int(counts[0]) + 1
    Save.set_resident_counts(map_id, type_id, counts)
    return resolve_resident_merges(z)
```

`welcome_resident` is refactored to: validate type → `resident_cost` → spend (coins/diamonds) → on success
`grant_resident(z, type_id)`. Behaviour is unchanged for the paid path; the gift path calls `grant_resident`
directly. The type must exist in `resident_lines(z)` — the unlock gift's spirit always does (it is that map's
signature), but `grant_resident` is a no-op-safe add regardless.

### 3. One-time unlock dialog — `map.gd`

Rename/evolve `_grant_map_task_reward(z)` → `_maybe_show_unlock_reward(z)`:

- Keep the existing one-time gate: `grove()["task_reward"][map_id]`. If already set, return.
  (See "Migration / one-time semantics" below.)
- Compute `rew := G.map_unlock_reward(z)`.
- **Grant immediately** (robust to interruption), then set the flag and persist:
  `Save.add_coins(rew.coins)`, `Save.add_diamonds(rew.gems)`, `G.grant_resident(z, rew.spirit)`.
- Build a celebratory dialog over a veil overlay (same overlay+veil pattern as `shop.gd`/inbox):
  use `Kit.info_dialog` with three rows, each carrying an icon + label + amount:
  - coins row: icon `coin`, amount `rew.coins`
  - diamonds row: icon `gem`, amount `rew.gems`
  - spirit row: a `node`/icon for `spirit_<id>.png`, amount `+1`, label = spirit name
    (info_dialog rows are id-based; if the spirit art will not resolve through `make_icon`, render the
    spirit row via a small custom row or pass a pre-built icon node — same `node` escape hatch as shop cards).
  - banner text: `map.unlock.title`; close/primary button label: `map.unlock.collect` ("Collect ✿").
- On the Collect/close press: play the existing reward FX (`_task_reward_fx(coins, gems)` — celebrate_reward
  + floating text + `level_complete` sound), then dismiss the overlay and `_update_hud()`.
- **Trigger point**: call `_maybe_show_unlock_reward(z)` from `_build_map` where `G.can_populate(z, …)` is
  already checked (so the dialog, the free spirit, and the Residents button all appear together on the
  fully-unlocked map). Remove the old `map_spots_done`-keyed call sites (lines ~341 and ~649). Guard against
  showing during non-interactive/headless rebuilds the same way `_task_reward_fx` already guards
  (`is_inside_tree`, deferred).

### 4. Residents button — `map.gd` `_build_chrome()`

- Nav becomes `[Map, Residents, Play]`. Add a spec built like `_make_map_button`: a rounded-rect badge
  (`shape:"rect"`) carrying a `residents` icon (glyph fallback if `icon_residents.png` is absent) and the
  label `map.nav.residents` ("Residents"); action = `_open_residents_shop(_map_idx)`.
- Store the button (`_residents_btn`) and toggle `.visible` from a `_refresh_residents_btn()` called on map
  open / build: visible only when `G.can_populate(_map_idx, unlocks, gates)`. A hidden control collapses out
  of the HBox, so an incomplete map shows just `[Map, Play]`.
- Update `FX.breathe_once(nav.buttons[…])` to target the Play button by identity (not hard index 1), since
  Play is now index 2.

### 5. Residents shop dialog — `map.gd`

Add `_open_residents_shop(z)` (replaces `_add_welcome_panel`/`_welcome_row`/`_on_welcome_tap` and the
`resident_hits` machinery, which are all removed):

- Build over a veil overlay (tap-veil dismiss), banner `map.welcome.title` ("Welcome a spirit ✿").
- One `Kit.shop_dialog` section; one card per `G.resident_lines(z)` entry:
  - `node`: a `TextureRect` of `res://games/grove/assets/characters/spirit_<id>.png` (the hero icon).
  - `label`: localized resident name.
  - `price`: `str(G.resident_cost(td).cost)`; `price_icon`: `"gem"` if premium else `"coin"`.
  - `affordable`: compare cost vs `Save.coins()` / `Save.diamonds()` (dims the buy CTA when unaffordable).
  - `on_buy`: `G.welcome_resident(z, id)`; on success rebuild the population layer + play the same
    success/merge FX and floating text the panel plays today (`map.welcome.new_friend` /
    `map.welcome.two_became_one`); on failure play `invalid_soft` + `map.welcome.not_enough`.
- After a buy, refresh the open shop cards' affordability (rebuild the dialog contents or re-open) so the
  prices dim/undim as the wallet changes.

### 6. Strings — `games/grove/strings.json`

Add: `map.nav.residents` ("Residents"), `map.unlock.title` ("A place restored ✿"),
`map.unlock.collect` ("Collect ✿"), and reward-row labels
(`map.unlock.coins`, `map.unlock.diamonds`, `map.unlock.spirit`). Reuse existing `map.welcome.*` strings
for the shop.

## Migration / one-time semantics

The unlock dialog reuses the existing `task_reward[map_id]` one-time flag. Maps a player already completed
before this change already have the flag set, so **they will not retro-show the dialog or grant the new
free spirit** — they already received the old completion reward. Only maps completed after the update show
the new dialog. This avoids double-granting currency on load. (To preview on already-complete maps during
development, reset the save.) If retro-granting on already-complete maps is desired, switch to a new flag
key (e.g. `unlock_reward_seen`) instead — flagged here as the one open tradeoff.

## Testing

New coverage goes into the **active** `games/grove/tests/grove_shop_ads_tests.gd` (the economy/shop-flavored
active suite — the `grove_economy_tests`/`grove_ui_tests` suites are parked/disabled in the Makefile and
would not run). Cover with logic-level assertions (no window):

- `map_unlock_reward(z)` scales: coins `120 + 80*z`, gems `2 + z`, and `spirit` equals the map's signature[0]
  for each shipping map.
- `grant_resident(z, id)` adds a T1 to the roster and cascades merges; `welcome_resident` still spends then
  grants (paid path unchanged: insufficient funds → no grant).
- The unlock reward is granted exactly once per map (second call after the flag is set is a no-op): coins,
  diamonds, and the free spirit all land in the player's balances/roster on first unlock only.
- Residents button visibility tracks `G.can_populate(z)` (helper-level: visible iff map complete).
- Residents shop card data: one card per `resident_lines(z)`, correct `price`/`price_icon` per
  premium flag, `affordable` reflects the wallet.

Run `make test-fast` after every change; `make test` (engine + active grove suites) before handing off.

## Out of scope (YAGNI)

- No new art authoring (the `residents` nav icon falls back to a glyph if no png exists; spirit art reuses
  the existing `characters/spirit_<id>.png`).
- No change to resident pricing, the merge ladder, or `RESIDENT_*` constants.
- No reward for incomplete maps; no retro-grant for pre-update completed maps (see Migration).
- No re-enabling of the parked `grove_economy_tests`/`grove_ui_tests` suites.
