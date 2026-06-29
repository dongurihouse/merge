# Map-card Expeditions and Home-map Residents - Design

Date: 2026-06-28
Branch: codex/map-card-expeditions

## Goal

Move Expedition out of the side rail and into each eligible map card, make expedition rewards feel local to the map that starts the run, and make resident placement legible: every resident line belongs to one home map, rewards enter the shared hand, and only that resident's home map accepts placement.

## Decisions

- Expedition entry lives inside each map card, not the live-ops side rail.
- The Expedition button is shown only on map cards where residents are unlocked (`G.can_populate(z, unlocks, gates)`).
- The workbench's `map_card` item tunes the new button's position and size.
- Expedition rewards still use the shared hand. Nothing auto-places.
- Each resident kind has one home map, derived from `G.resident_lines(z)`.
- Placement is restricted to the resident's home map.
- Tap selection gives a calm placement preview. Dragging makes valid and invalid map-card states stronger.
- The source map's resident line has 3x reward weight; every other unlocked resident line has 1x weight.
- All resident rails always show the full 8-cell capacity. Cells above the current unlocked capacity are visible but greyed/locked.

## Current State

`engine/scripts/scenes/map.gd` currently builds a side-rail Expedition tile in `_build_liveops_rail()`, stores it in `_residents_btn`, and opens `_open_expedition()` without a map argument. `_open_expedition()` starts the run through `Explore.begin_run(equip)` and then loads `ExploreRush.tscn`.

Map cards already render resident habitat state through `_habitat_card()` and `_add_habitat_strip()`. The rail uses a stable 2-column by 4-row layout, but it fills to `display_cap = maxi(cap, 8)`, which effectively shows 8 cells without differentiating currently locked capacity cells.

`engine/scripts/core/content.gd` already computes the live map capacity with `resident_capacity(z, unlocks)`: one slot after the first restored spot, ramping to `RESIDENT_SLOTS_MAX` when all spots are restored.

`engine/scripts/core/habitat.gd` owns hand, placed residents, placement, moving, production, and reward collection. `Habitat.place(map_id, index, now)` currently allows any hand resident to be placed on any non-full map. `Habitat.grant_chest(count)` rolls uniformly from the global pool of resident kinds.

`engine/scripts/ui/explore_reward.gd` grants the run reward through `Habitat.grant_chest(Explore.trade_count(Explore.score()))`, so the reward code currently has no idea which map launched the expedition.

`games/grove/tools/ui_workbench_kit.gd` and `games/grove/tools/ui_workbench_view.gd` already make the map-card resident rail and reward shelf tunable under the `map_card` workbench item.

## Data and Model

Add a pure resident-home lookup in the content layer:

- `G.resident_home_map(kind: String) -> int`
- `G.resident_home_map_id(kind: String) -> String`

The lookup scans `G.MAPS` and `G.resident_lines(z)` and returns the map that offers the resident kind. Unknown kinds return `-1` or `""`.

Update habitat placement so the model enforces the UI rule:

- `Habitat.can_place_on(map_id: String, inst: Dictionary) -> bool`
- `Habitat.place(map_id: String, index: int, now := -1.0) -> bool` checks `can_place_on()` before moving the spirit.
- `Habitat.place_merge(map_id, h_index, p_index, now)` also checks that the hand spirit belongs to `map_id` before merging into a placed resident.
- `Habitat.move(from_id, index, to_id, now)` refuses moves to a non-home map. This keeps old saves safe if they already contain misplaced residents, but prevents new wrong-map placement.

Reward rolling gets a source-aware API:

- `Habitat.resident_reward_pool(source_map_id := "") -> Array[Dictionary]`, returning entries like `{kind, map_id, weight}`.
- `Habitat.roll_reward_kind(source_map_id: String, rng: RandomNumberGenerator) -> String`.
- `Habitat.grant_chest(count: int, source_map_id := "") -> Array`.

When `source_map_id` is present and unlocked, its resident kinds get weight `3`; all other unlocked resident kinds get weight `1`. The pool still includes every unlocked resident line. If the source map is absent or not in the unlocked pool, all unlocked resident lines fall back to weight `1`.

## Explore Run Source

Extend the transient Explore run state:

- `Explore.begin_run(equip: Dictionary, source_map_id := "")`
- `Explore.source_map_id() -> String`

The map card calls `_open_expedition(z)`, and the Set off button calls `Explore.begin_run(equip.v, String(G.MAPS[z].id))`. Existing direct-open or test paths can omit the source map and retain global behavior.

`ExploreReward.open()` passes `Explore.source_map_id()` into `Habitat.grant_chest()`. The reward reveal still grants up front and displays the same slot-reel UI. Only kind weighting changes.

## Map-card Expedition Button

Remove the Expedition entry from `_build_liveops_rail()`. The rail remains Settings, Daily, Vault, and guarded Inbox.

Each eligible habitat map card gets an Expedition button inside the card. The default placement sits in the left-lane lower area near the reward shelf without covering the Collect button, resident rail, or title plate. The button uses the shared `Kit.home_button` rect-badge style with the expedition icon from `home_chrome.gd`.

The card button is a real `Button` with `MOUSE_FILTER_STOP`, like the Collect button, so tapping it opens loadout instead of navigating into the map. Other card content stays mouse-ignored and continues to use the single input surface.

Add workbench settings under `map_card`:

- `expedition_button_px`
- `expedition_button_x`
- `expedition_button_y`
- `expedition_button_icon_scale`

`Kit.map_card_opts_from_config()` resolves those values. The workbench preview shows the expedition button when `open` and `done` are both true, and the sidebar exposes the sliders in a new "Expedition button" section. The live map reads the same opts.

## Placement Hints

The map picker already tracks `_sel_orb`, `_drag`, `_hand_orbs`, and `_placed_orbs`. Use that state to drive card-level placement hints.

When a hand resident is selected by tap:

- Determine its home map with `G.resident_home_map(kind)`.
- The home map card receives a gentle valid hint: a warm border/glow and normal brightness.
- Other populatable map cards are slightly dimmed.
- Locked maps stay in their existing locked style.

When dragging a hand resident:

- The home map card gets a stronger valid drop-target hint.
- Non-home populatable maps dim harder.
- Non-home resident rails/cells ignore the drop and give a soft invalid response if released there.

If a resident is selected or dragged and its home map has no currently unlocked empty cells, the home card still highlights as the correct map, but its available-cell state makes clear that the current capacity is full.

## Resident Rail Capacity

Every habitat card renders exactly 8 resident cells:

- Filled cells for placed residents.
- Empty normal cells from `placed.size()` up to current `Habitat.cap(map_id)`.
- Greyed locked cells from current capacity up to `G.RESIDENT_SLOTS_MAX`.

Greyed cells are visual only. They are not valid drop targets. They use the same square slot-cell silhouette at lower saturation/alpha with a small lock or shaded overlay, so players understand the map can eventually hold more residents.

When dragging a resident that belongs on the card, only normal empty cells are valid placement targets. Filled matching cells remain valid merge targets. Greyed cells stay invalid even on the home map.

## Tests

Add or update tests before production code:

- Content lookup: each resident kind resolves to its expected home map id.
- Habitat placement: a resident can be placed on its home map and cannot be placed on another map.
- Habitat move/merge: move and place-merge refuse non-home map destinations.
- Reward pool: with five unlocked maps and source `farmhouse`, the farmhouse entry has weight `3` and other entries have weight `1`; generated grants still include all unlocked lines over deterministic RNG samples.
- Explore run state: `Explore.begin_run(equip, source_map_id)` stores the source and existing `begin_run(equip)` callers still work.
- Reward overlay: `ExploreReward.open()` calls source-aware grant through the run source.
- Map UI: side-rail Expedition is absent; eligible map cards expose an Expedition button that calls `_open_expedition(z)`.
- Workbench: `map_card` opts/defaults/settings include the expedition button knobs, and the preview renders the button.
- Resident rail: an incomplete map card renders 8 cells, with cells above current capacity marked locked/greyed.
- Placement hints: selecting a hand resident marks only its home map as valid, and dragging strengthens that state.

Run the focused Grove suites for changed behavior first, then `make test-fast` and `make test` before final handoff. The initial fresh-worktree `make test-fast` baseline on 2026-06-28 failed before this spec changed code, with asset/bake/null-texture failures in `kit_bake_tests`, `tutorial_image_tests`, `vase_water_effect_tests`, `fx_juice_tests`, and a `level_badge_tests` timeout. Treat those as baseline issues unless they are fixed during implementation.

## Out of Scope

- New resident art or new resident lines.
- Rarity.
- A resident almanac or collection screen.
- Auto-placement of rewards.
- Changing the Rush board rules, score rate, or reel reveal pacing.
- Capacity upgrades beyond the existing restoration-based capacity ramp.
