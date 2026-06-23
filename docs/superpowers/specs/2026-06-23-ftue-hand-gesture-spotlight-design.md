# FTUE — one reusable hand-gesture spotlight — design

Date: 2026-06-23
Branch: `ftue-spotlight-removal`
Status: **SPEC ONLY — implementation parked** (`docs/BACKLOG.md`). The previous feature-spotlight
code was **removed** in this branch so the redesign starts from a clean slate (see *Removed code*).

## Goal

One reusable FTUE overlay used at every tutorial site: a **hand icon that mimes the gesture over a
dimmed page**, plus an explicit per-site trigger. Replaces the old per-feature spotlights (merchant /
bag / shop), which were all dormant and have now been stripped.

The mechanism is unchanged in spirit — a **seen-once gate** so each feature is announced exactly once,
ever, driven by a small **registry** of `{id, gesture, label}` rows — but the **presentation** is
redesigned around a hand-cursor that travels the gesture, and the **sites** are re-chosen to match the
current UI.

## Decisions (confirmed with user)

- **Two live sites, both `drag`:**
  - **merge** — taught the *very first time on the board*: drag one piece onto its match.
  - **bag** — taught the *first time the board is full*: drag a board piece into the bag well to free space.
- **Merchant and shop sites are dropped.**
  - The merchant "drag → sell well" gesture is **obsolete**: selling moved to the info-bar trashcan
    (tap a piece → tap the delete icon); `board.gd:merchant_btn` is never assigned. The user's call:
    *"we now have an info bar with delete icon, that's good enough."*
  - The shop "tap → store" site is **cut**: the store opens from the top HUD gem-`+` pill, and the
    info-bar delete icon covers the teach. (This also removes the daily-login-popup collision concern —
    there is no shop spotlight to coordinate with anymore.)
- **The hand is a real art asset** (not the code-drawn placeholder): authored as a pointing-hand cursor
  and brought in through the asset-intake pipeline (`ui/kit/hand.png`), with the code-drawn fallback
  retained per §13 "ships twice".
- **Merge is now spotlit.** This reverses the prior rule (`merge_spec §14`: "the idle hint teaches the
  merge verb, not a spotlight"). The first-time spotlight is the merge teach; the idle hint becomes the
  ongoing re-nudge *after* the spotlight has been seen.
- **Implementation is parked** in the backlog; this branch only writes the spec and removes the old code.

## The reusable overlay

Rewrite `engine/scripts/ui/spotlight_overlay.gd` (presentation only; `ui/` layer — imports `core` + `ui`
only, never `scenes/`).

- **API:** `present(host, source, target, gesture, label, on_done) -> Control`.
  - `gesture` is `"drag"` or `"tap"`.
  - `drag` uses both `source` and `target` Controls; `tap` uses only `target` (`source` ignored / null).
  - No-op when the `ftue_feature_spotlight` flag is off (fires `on_done` and returns null).
- **Dim-except-cutouts veil.** The whole page dims except the bright cutout(s): **two** for a drag
  (source + target), **one** for a tap (target). Build by **rectangle-subtraction** of the screen minus
  each cutout rect — generalizes today's single-rect four-band veil to N rects, no shader, matching the
  existing hard-edge look. A pulsing cream ring + straw halo traces each cutout (reuse the `_RingDraw`
  primitive + `FX.breathe`).
- **The hand.** A `TextureRect` loading `ui/kit/hand.png` (via the kit loader, e.g. `Look.kit`); the
  existing code-drawn `_HandDraw` is the fallback when the texture is missing.
  - *drag:* hand presses at the **source** rect, glides **source → target** along the real path,
    releases, **loops**.
  - *tap:* hand taps the **target** in place, **loops** (kept for future tap sites).
- **Caption** (wordless one-liner from the registry, wrapped in `tr()`) sits under the hand.
- **Dismiss** on any tap/press → fade out, free, call `on_done`.

Targets that resolve to null/invalid → a centred fallback rect (still teaches the gesture).

## The hand art asset

The game's art is LLM-generated and lands in `games/grove/assets/_new/` for the intake pipeline
(`docs/design/asset-intake.md`). For this asset:

1. Author a clean pointing-hand cursor (transparent background, generous padding), drop the raw PNG in
   `games/grove/assets/_new/`.
2. Write `hand.plan.json` — `category: icon`, `params.size: 512`, output `ui/kit/hand.png`, archive under
   `_originals/ui/`.
3. `make intake` (writes the output, archives the raw, reimports), then `make bake-textures` if the
   overlay's draw path is covered by a baked dialog.
4. Verify the alpha over a contrasting background; re-roll the raw if it has halos.

*(No image-generation tool is connected in-session; if the asset is authored as vector→PNG rather than an
LLM render, the wiring is identical — the overlay just loads `ui/kit/hand.png`.)*

## The registry (data source)

Re-add a `core/spotlight.gd` mechanism (game-agnostic: `should_spotlight` / `mark_spotlit` /
`gesture_for` / `label_for` / `feature_order`, reading `G.SPOTLIGHTS`) and a per-game registry. The
grove rows:

```gdscript
const SPOTLIGHTS := [
    {"id": "merge", "gesture": "drag", "label": "Drag two alike together to merge"},
    {"id": "bag",   "gesture": "drag", "label": "Drag a piece here to tuck it away"},
]
```

Declaration order is the staged teach order (`feature_order()`): **merge before bag**. A future site is
one registry row + one call. Labels are provisional and ship translatable.

Seen-state persists in the save blob (re-add `Save.spotlights_seen` / `spotlight_seen` /
`mark_spotlight_seen`, keyed by feature id, deep-merged over defaults — no migration). The
`ftue_feature_spotlight` flag (default ON) gates the whole mechanism.

## The triggers (`board.gd`)

Re-wire `_maybe_spotlight_chrome()` (called from `_rebuild_all`, after layout). One overlay at a time via
a `_spotlight_active` latch; `_on_spotlight_done` releases it and re-checks so a second eligible site can
follow. Resolve target rects on the next frame (`await get_tree().process_frame`).

- **merge** — eligible iff `Spotlight.should_spotlight("merge")` **and** a mergeable pair exists.
  - Pair: `BoardLogic.find_mergeable_pair(board)` → `[cell_a, cell_b]` (or `[]`).
  - Present a **drag** from `piece_nodes[cell_a]` (source) → `piece_nodes[cell_b]` (target). "Very first
    time on the board" = the first frame a mergeable pair is present; the seen-once gate fires it once.
- **bag** — eligible iff `Spotlight.should_spotlight("bag")` **and** the board is full **and** the bag
  has room **and** a stashable piece exists.
  - Board full: `board.empty_ground_cells().is_empty()` (the §6 generator-dim predicate).
  - Bag room: `bag.size() < _bag_capacity()`.
  - Stashable piece: a board cell holding a non-coin, non-generator item (pick the first as the source).
  - Present a **drag** from that piece (source) → `bag_btn` (target).
- **Priority:** merge before bag (matches `feature_order()`).

### Idle-hint coordination

The idle hint (`board.gd:_hint_pair`, gated on `Features.on("idle_hint")`) rocks a mergeable pair after
~4.5 s idle — it currently teaches the merge verb. Coordinate so the spotlight is the **first** merge
teach:

- Suppress `_hint_pair` while `_spotlight_active` (don't rock pieces under a live overlay), **and**
- Suppress the merge rock while `Spotlight.should_spotlight("merge")` is still true (merge not yet
  taught). Once the merge spotlight is seen, the idle hint resumes as the ongoing re-nudge.

## Mechanism touch-ups when re-implementing

- `core/spotlight.gd` comments: merge **is** spotlit now (drop the "idle hint teaches merge" framing).
- `engine/tests/spotlight_tests.gd`: target the new registry — `gesture_for("merge") == "drag"`,
  `gesture_for("bag") == "drag"`, `order.has("merge")`, merge before bag, unknown → tap fallback, plus
  the gate / persist / idempotent tests. **Re-enable this fast pure-logic suite in the active
  `ENGINE_TESTS`** (it was parked in `ENGINE_TESTS_DISABLED`).
- `docs/design/merge_spec.md §14`: note that merge gets a first-appearance spotlight and the idle hint is
  the post-teach re-nudge.

## Verification

- Headless: `make test-fast` + the re-enabled `spotlight_tests` suite green.
- Visual (don't eyeball from memory): capture the board with each overlay (merge + bag) via the
  quiet-godot shot path and deliver the screenshots — confirm the two-cutout dimming, the per-cutout
  ring, and the hand traveling source → target.

## Removed code (the clean-slate starting point)

This branch stripped the dormant feature-spotlight subsystem. A re-implementer rebuilds against this
spec. What was removed:

- **Deleted files:** `engine/scripts/core/spotlight.gd`, `engine/scripts/ui/spotlight_overlay.gd`,
  `engine/tests/spotlight_tests.gd` (+ their `.uid`).
- **Registry:** `games/grove/grove_data.gd:SPOTLIGHTS` and `engine/scripts/core/content.gd`
  `const SPOTLIGHTS = D.SPOTLIGHTS`.
- **Flag:** `ftue_feature_spotlight` in `engine/scripts/core/features.gd`.
- **Save API:** `spotlights_seen` / `spotlight_seen` / `mark_spotlight_seen` in
  `engine/scripts/core/save.gd` (the persisted `spotlights_seen` key is harmless on old saves).
- **`board.gd` wiring:** the `Spotlight` / `SpotlightOverlay` preloads, the `shop_btn` and
  `_spotlight_active` members, the `_maybe_spotlight_chrome()` call, and the four functions
  `_maybe_spotlight_chrome` / `_spotlight_chrome_deferred` / `_show_spotlight` / `_on_spotlight_done`.
- **Shot tools / tests:** the `Save.mark_spotlight_seen("shop")` guards in `games/grove/tools/map_shot.gd`,
  `residents_shot.gd`, `inbox_shot.gd`, and `games/grove/tests/grove_test_base.gd`; the dangling shop-
  spotlight comments in `engine/scripts/scenes/map.gd`; and `engine/tests/spotlight_tests` from the
  `Makefile`'s `ENGINE_TESTS_DISABLED` list.

**Left intact** (separate, *active* onboarding features — not the spotlight): `ftue_free_pops` and
`ftue_staged_chrome`.
