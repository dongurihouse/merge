# FTUE — hand hints for the first merge and the first generator tap — design

Date: 2026-07-23
Branch: `ftue-hand-hint`
Status: approved, ready for an implementation plan.

## Goal

Two one-time hand-gesture teaches on the board, shown in this order to a brand-new player:

1. **FTUE1 — merge.** A hand icon repeatedly drags one item onto its match until the player performs
   their first merge.
2. **FTUE2 — generator tap.** A hand icon sits on the generator and bobs down/up to mime a tap, until
   the player taps the generator for the first time.

This **supersedes** `docs/superpowers/specs/2026-06-23-ftue-hand-gesture-spotlight-design.md`, which
paired *merge* with a *bag* teach and specified a hard-edged spotlight (bright cutouts, pulsing rings,
captions). The bag teach is **out of scope** here and stays parked in `docs/BACKLOG.md`. The
presentation is lighter: a soft dim and a hand, nothing else.

## Decisions (confirmed with the user)

- **Presentation: hand + soft dim.** No pulsing ring, no caption text, no translatable string.
- **Order: merge first, generator tap second.** The fresh board always seeds a mergeable pair
  (`grove_data.gd:STARTER_ITEMS` places six tier-1 `101` items), so the merge teach is always possible
  on the first frame. If no mergeable pair exists for some unforeseen reason, the merge hint simply
  does not present that rebuild and is re-checked on the next one.
- **Persistence: loops until the action is done.** The hand never self-dismisses and is never dismissed
  by an unrelated tap. It ends only when the taught action is actually performed.
- **Art: generated, then taken through the intake pipeline** to `ui/kit/hand.png`, with a code-drawn
  fallback so the triggers are verifiable before the art lands.
- **Skip-if-already-done:** if the player taps the generator while the *merge* hint is still up,
  `gen_tap` is marked seen and never presents. Teaching a verb the player just performed is noise.
- **Idle-hint coordination:** the existing idle hint is suppressed while a hand hint is live, and its
  merge rock is suppressed until the merge teach is seen, so the hand is the first merge teach.

## The overlay — `engine/scripts/ui/hand_hint.gd`

A reusable presentation node in the `ui/` layer (imports `core` + `ui` only, never `scenes/`).

**API**

```gdscript
static func present(host: Control, gesture: String, source_rect: Rect2, target_rect: Rect2) -> Control
func retarget(source_rect: Rect2, target_rect: Rect2) -> void
func dismiss() -> void
```

- `gesture` is `"drag"` or `"tap"`. `drag` uses both rects; `tap` uses `target_rect` only.
- `present` returns `null` and does nothing when the `ftue_hand_hint` flag is off.
- Rects are in the host's global coordinate space.

**Soft dim, fully non-blocking**

- A full-screen veil at low alpha (~0.35 black) covering everything *except* the involved rects: two
  cutouts for a drag (source + target), one for a tap (target).
- Built by **rectangle subtraction** — screen minus each cutout rect — drawn as plain `ColorRect`
  bands. No shader. Generalizes to N cutouts.
- **Every node in the overlay sets `mouse_filter = IGNORE`.** The player performs the real gesture
  straight through the veil; the overlay is decoration, never a modal.

**The hand**

- A `TextureRect` loading `ui/kit/hand.png` through the kit loader, drawn above the veil. A small
  code-drawn hand (`_HandDraw`) is the fallback when the texture is missing.
- *drag:* presses at the source rect's centre (small scale dip), glides source → target along a
  straight path over ~0.9s, releases (scale back), pauses ~0.4s, loops.
- *tap:* rests on the target rect's centre and bobs down/up over a ~0.35s cycle with a small scale
  dip on the down beat, loops.
- The loop runs forever until `dismiss()`.

**Retargeting.** `retarget()` updates the cutouts and the animation path in place, so the hint follows
the board across a rebuild without restarting its loop.

## The state — seen-once, flagged

- **Flag:** `ftue_hand_hint` in `engine/scripts/core/features.gd`, default **ON** (rule N4: every new
  FTUE feature ships behind a flag).
- **Save:** an `ftue_seen` dictionary in the save blob, keyed by hint id (`"merge"`, `"gen_tap"`),
  deep-merged over defaults — no migration needed; absent keys read as unseen.
- **Core API** in `engine/scripts/core/save.gd`: `ftue_seen(id) -> bool` and `mark_ftue_seen(id)`
  (idempotent).

## The triggers — `engine/scripts/scenes/board.gd`

A single `_hand_hint` member holds the live overlay (at most one at a time) and `_hand_hint_id` its id.
`_maybe_hand_hint()` is called at the end of `_rebuild_all`, after layout, resolving rects on the next
frame (`await get_tree().process_frame`).

**Eligibility, checked in order:**

1. **`merge`** — unseen, and `BoardLogic.find_mergeable_pair(board)` returns a pair. Source is
   `piece_nodes[cell_a]`, target `piece_nodes[cell_b]`; present a `drag`.
2. **`gen_tap`** — `merge` already seen, `gen_tap` unseen, and a tappable anchor generator exists in
   `gen_nodes`. Target is that generator's node rect; present a `tap`.

If the currently live hint is still the eligible one, `retarget()` is called instead of re-presenting.

**Completion:**

- A merge resolving on the board marks `merge` seen and dismisses the hint, then re-runs
  `_maybe_hand_hint()` so `gen_tap` follows immediately.
- A tap-pop of a generator (the still-tap branch of `_release_gen` reaching `_pop_seed`) marks
  `gen_tap` seen and dismisses the hint. This fires even while the *merge* hint is live, implementing
  the skip-if-already-done rule.

**Idle-hint coordination** in `_hint_pair`: return early while `_hand_hint != null`, and while
`merge` is still unseen.

## Verification

- **Headless** (`engine/tests/hand_hint_tests.gd`, wired into the active `ENGINE_TESTS`):
  - flag off → `present` returns null and nothing is added to the host;
  - `ftue_seen` / `mark_ftue_seen` gate and persist, and marking twice is idempotent;
  - order: on a fresh board `merge` is eligible and `gen_tap` is not; after marking `merge` seen,
    `gen_tap` becomes eligible;
  - skip-if-already-done: marking `gen_tap` seen while `merge` is unseen leaves `gen_tap` ineligible
    forever;
  - the drag overlay builds two cutouts and the tap overlay one, and every child has
    `mouse_filter == IGNORE`;
  - rect resolution against a real built board tree (measure the node tree, do not eyeball).
- **Visual:** capture the board with each hint through the quiet-godot shot path and look at the
  results before calling this done — confirm the dim level, the two-cutout drag framing, and the hand
  sitting where it should.
- `make test` green before merging.

## Art asset

Per `docs/design/art-style-guide.md`:

1. Generate a clean pointing-hand cursor (transparent background, generous padding, palette-consistent)
   and drop the raw PNG in `games/grove/assets/_new/`.
2. Author `hand.plan.json` — `category: icon`, `params.size: 512`, output `ui/kit/hand.png`, archive
   under `_originals/ui/`.
3. `make intake`, then verify the alpha over a contrasting background; re-roll if it has halos.

The overlay ships with the code-drawn fallback regardless, so implementation is not blocked on the art.
