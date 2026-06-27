# Unified feel verbs — merge / land / launch / move — design

Date: 2026-06-27
Branch: `feel-verbs` (proposed)
Status: pending user review of spec

## Goal

The same four physical events happen all over the game — two things **merge**, an
item **lands** on a cell, an item is **launched**, an item **moves** between cells —
but every scene hand-assembles its own juice for them, so they feel like different
games. The board merge is rich; the Rush merge plays a UI `button_tap` and only
flashes at tier ≥ 4; the spirit merge on the map is a bare poof. Rush landings are
silent; board landings grow in. The fling has no emitter recoil; every travel tween
is hand-rolled with drifting durations.

Give the whole game **one juice vocabulary**: four shared verbs that every scene
calls, each composed from the existing `fx.gd` primitives, each scaled by an
**intensity (0–1)** so a surface can share the *vocabulary* while dialing the
*strength* (a map spirit-merge must not freeze the screen like a tier-8 board merge).

## Non-goals

- **No new art.** Reuse existing burst sprites / dot fallback and existing sounds.
- **No new workbench surface this pass.** Verbs read constants from `tuning.gd`;
  the existing RushFx toggles stay. Exposing `intensity` in the workbench is a later,
  separate step if wanted (grow tools incrementally).
- **No tone change.** The game stays cozy. Screen shake stays reserved for rare big
  moments, never routine — carried over from the 2026-06-24 merge-juice direction.
- **The generator's grow-in stays generator-specific.** Spawning a fuel tile that
  scales `0.3 → 1.0` as it flies out of the generator is the generator's own spawn
  signature. It is NOT folded into the `land` verb (owner's call).
- Not changing merge/land/launch game *logic* (tier math, scoring, gravity) — this is
  purely the felt layer over those existing events.

## Architecture

New module **`engine/scripts/ui/feel.gd`** — a `RefCounted` static library holding the
four verbs. Each verb is a *composition* of the primitives that already live in
`engine/scripts/ui/fx.gd` (`squash_pop`, `flash`, `hitstop`, `burst`, `shake`,
`gen_charge`, plus `Audio.play`). The split is load-bearing:

- **`fx.gd` stays the primitive library** — one verb-free effect each.
- **`feel.gd` is the grammar** — the four compositions every scene calls instead of
  reassembling primitives inline.

Every verb:
- takes an `intensity: float` (0–1) that scales the felt strength of each component,
- respects `FX.calm()` (motion accessibility) exactly as the primitives already do —
  flash/shake/hitstop already no-op under calm, so the verbs inherit that,
- is hard-off in headless for the global-freeze part (`FX.hitstop` already gates on
  `DisplayServer.get_name() != "headless"`), so deterministic test clocks are safe.

All animation/tuning values live in `tuning.gd` class `FX` (existing convention).

### Per-surface intensity

| Surface | merge | land | launch |
|---|---|---|---|
| Board | 1.0 | 0.8 | 1.0 |
| Rush  | 1.0 (pace-aware thunk) | 0.8 | 0.9 |
| Spirit / map | 0.4 (gentle — no screen freeze) | 0.5 | — (map has no launch) |

## The four verbs

### 1. `feel.merge(host, node, center, tier, combo, intensity, hitstop_gate := 0)`

Composes, in order:

- **squash** — `FX.squash_pop(node)` (the 4-key `SQUASH_K` impact pose). Always.
- **flash** — `FX.flash(host, center, size, FLASH_PEAK * intensity * tier_ramp)` on
  **every** merge. `tier_ramp` lerps soft → full from tier 1 → ≥ 4, so ordinary
  merges get a subtle bloom and big ones the full pop. (`FX.flash` self-gates on the
  `merge_impact` feature + calm.)
- **hitstop** — a tier+combo-scaled micro-freeze × intensity, with a per-call
  `hitstop_combo_gate`: below the gate, hitstop is **zero**.
  - `secs = clampf(HITSTOP_MERGE + HITSTOP_TIER_BONUS*(tier-1) + combo_bonus, 0, HITSTOP_MAX) * intensity`
  - Board uses gate `0` → fires every merge, tier-scaled — **preserves today's board feel exactly**.
  - Rush uses gate `2` → an isolated low-combo merge gets **no** freeze (stays snappy
    in the fast mode); a building streak lands a mounting thunk, capped low. The
    existing `FX.hitstop` re-entrancy guard already stops rapid merges stacking.
- **burst** — `FX.burst(host, center, color, count)`.
  - `color`: tier < 4 → `LEAF` green; tier 4–7 → `STRAW` gold (auto-swaps the particle
    texture to pollen); tier ≥ 8 → `HOT`. ("bigger feels bigger.")
  - `count`: the board's existing curve `10 + tier*3` + combo bonus + big-moment bonus,
    scaled by intensity (`FX.amount_for` already trims under calm). Canonical across
    surfaces — Rush adopts this curve (a slight change from its old
    `20 + (tier-3)*4`, acceptable as part of unifying).
- **shake** — `FX.shake(host)` only at the reserved big-moment tier (`ESCALATE_TIER`,
  8), as today.
- **sound** — `Audio.play("merge_success" if tier >= 4 else "merge_soft", -1.0, pitch)`,
  `pitch = clampf(0.95 + 0.03*tier, 0.9, 1.3)` plus the combo pitch step. The real,
  pitched merge sound.

Per-surface result:
- **Board** ([board.gd:2531 `_after_merge`](../../../engine/scripts/scenes/board.gd)) —
  refactor the hand-built stack into one `feel.merge(..., intensity=1.0, gate=0)` call.
  Behavior preserved; the combo-milestone callout, coin/special drops stay in
  `_after_merge` around the call (they are board-specific, not part of the verb).
- **Rush** ([explore_rush.gd:560 `_merge`](../../../engine/scripts/scenes/explore_rush.gd)) —
  **new feel:** gains the pitched merge sound (drops `button_tap`), flash + combo-gated
  thunk on every merge, tier-escalating gold/hot burst. The Rush-specific extras (score
  tick, score/mult cell pop, combo heat, "BUILD!" callout) stay in `_merge` around the call.
- **Spirit** ([map.gd:1897 `_merge_fx`](../../../engine/scripts/scenes/map.gd)) —
  **new feel:** `feel.merge(..., intensity=0.4)` over today's bare `tidy_poof` +
  "Merged!" text. Called with `hitstop_gate` above any possible combo (e.g. a large
  sentinel) so the freeze is **never** triggered — at 0.4 it is squash + a soft bloom
  + a small burst, no screen freeze. The "Merged!" text stays.

### 2. `feel.land(host, node, center, intensity)`

The arrival of a tile that **traveled then touched down** — it is the impact the
fast end of `feel.move` lands into:

- **squash** — the 2-key land squash `LAND_SQUASH_K` (`1.14/0.86 → 1.0`, the value Rush
  already uses), strength × intensity.
- **small flash** — a brief, soft white `FX.flash` at the touch-down point, peak
  `FLASH_PEAK * LAND_FLASH_FACTOR * intensity` over `LAND_FLASH_T` (much softer and
  shorter than a merge flash) — the visual "tap" that catches the arriving tile.
- **sound** — one canonical soft touch sound at a consistent level (proposed
  `tidy_poof` at -4.0 dB, slight pitch). One id everywhere.
- **micro-puff** — optional small `FX.burst` (a few neutral particles) × intensity.

Applies to:
- **Rush** fall / settle / fling-land ([explore_rush.gd:517](../../../engine/scripts/scenes/explore_rush.gd),
  `:657`, `:674`) — keeps the squash it already has; **gains** the unified touch sound
  (today silent).
- **Board drops** — coin ([board.gd:2656](../../../engine/scripts/scenes/board.gd)) and
  special ([board.gd:2704](../../../engine/scripts/scenes/board.gd)) — **gain** a land
  squash + the same touch sound at the *end* of their existing grow-in flight.
- **Excluded: generator spawn** — keeps its grow-in (`0.3 → 1.0`) as its spawn
  signature, per non-goals. It does not get a separate land squash.

### 3. `feel.launch(emitter, projectile, intensity)`

An item being emitted / thrown:

- **emitter recoil** — generalize `FX.gen_charge`'s crouch → spring → settle so any
  emitter node can recoil (× intensity).
- **toss sound** — one canonical light toss sound (proposed `item_drop`), consistent
  level/pitch.
- **muzzle puff** — optional small `FX.burst` at the emit point × intensity.

Applies to:
- **Generator** ([board.gd:2385 `_pop_seed`](../../../engine/scripts/scenes/board.gd)) —
  already recoils via `gen_charge`; adopts the shared toss sound. **Keeps grow-in** on
  the projectile.
- **Rush fling** ([explore_rush.gd:604 `_fling`](../../../engine/scripts/scenes/explore_rush.gd)) —
  **gains** emitter recoil + muzzle puff; keeps its arc + ±22° spin; uses the shared
  toss sound (drops its own `button_tap`).

### 4. `feel.move(node, from, to, kind, dur)`

Travel between positions, built to **sell the arrival**. `kind ∈ {slide, arc, fall}`,
replacing the per-site hand-rolled tweens. Components:

- **variable speed — accelerate into the destination.** All move kinds use an ease
  that leaves slowly and is **fastest as it reaches the target** (`TRANS_QUAD`/
  `TRANS_CUBIC` `EASE_IN`; the arc's down-leg already does this). The late
  acceleration is what gives the chained `feel.land` its punch — the tile arrives
  *fast*, then the land squash + small flash catch it. This makes accelerate-into-
  impact the canonical move easing (board merge slide already does it under
  `merge_impact`; now every move does).
- **cast shadow** — a soft dark blob following under the node (a darkened, blurred
  duplicate of the node's own sprite — no new art), offset by a fixed light
  direction. For `arc`, the shadow hugs the ground line and its size/alpha shrink as
  the node rises and snap back as it lands, reading the height of the hop. For
  `slide`/`fall`, a subtle constant-offset shadow. Frees itself once the move settles.
- **motion trail (cheap "blur")** — a short fading afterimage: `MOVE_TRAIL_N` ghost
  copies of the node sprite dropped along the path at decreasing alpha, each
  self-freeing over `MOVE_TRAIL_T`. Reads as motion blur with no shader and no new
  art; density scales with travel speed, so a fast fling smears and a gentle settle
  barely does. (A true shader-based smear is parked — see out of scope.)
- **motion-lean** — a slight tilt (`MOVE_LEAN_DEG`) into the direction of travel,
  righting on arrival.

`slide` = board merge slide ([board.gd:2522](../../../engine/scripts/scenes/board.gd));
`arc` = rush fling ([explore_rush.gd:674 `_fly_to`](../../../engine/scripts/scenes/explore_rush.gd)),
keeping its ±22° spin; `fall` = rush settle/spawn fall
([explore_rush.gd:714 `_fall_to`](../../../engine/scripts/scenes/explore_rush.gd)).
Returns the tween so callers chain `feel.land` on completion — the fast arrival + land
squash/flash are one continuous impact.

## Additional screen juice — bundles A, B, D

Picked on top of the four verbs. (Bundle C — premium shine sweep + idle board
breathing — was considered and parked.) Each hooks into a verb or the drag loop; all
are calm-aware and headless-safe.

### A. Tactile interaction

**A1. Haptics** *(new — none in the codebase; this is a Mobile/iOS export,
`emulate_touch_from_mouse`, `renderer=mobile`).*
A `feel.haptic(weight)` helper wrapping `Input.vibrate_handheld(ms)`,
`weight ∈ {tick, soft, firm, heavy}`: pickup → tick, land → soft, merge → soft…heavy
scaled by tier, combo milestone → a double pulse. The four verbs fire the matching
weight as their final step. Gated by a new `haptics` user setting (default on) and the
OS reduce-haptics flag; independent of `calm()` (motion-only). A per-frame throttle
(`HAPTIC_THROTTLE_MS`) stops a multi-tile Rush settle from machine-gunning the motor.
Richer iOS impact-generator haptics (light/medium/heavy via a plugin) are parked.

**A2. Merge-target telegraph** *(new — today there is no pre-drop feedback; board-only,
Rush has no drag).* While a dragged tile hovers a cell where
`board.can_merge(from, target)` is true: the target `FX.breathe`s + shows a soft glow
ring, and the held tile and target **lean toward each other** (a small position/scale
magnetism). Moving off clears it; releasing on a valid target flows into `feel.merge`.
Reuses the `breathe` + `DRAG_HILITE` pattern already used for the Bag button
([board.gd:1022](../../../engine/scripts/scenes/board.gd)).

**A3. Drag lean/lag** *(new — lift + two-state shadow exist at
[board.gd:2245](../../../engine/scripts/scenes/board.gd) /
[piece_view.gd:79](../../../engine/scripts/ui/piece_view.gd), no lean).* The held tile
tilts into pointer velocity (`DRAG_LEAN_DEG`, clamped) and trails slightly, righting
when the pointer stills. Board-only, in the drag-follow code.

### B. Impact propagation (a step inside `merge` + `land`)

**B1. Neighbor ripple** *(new).* `feel.ripple(neighbors, impact_center, intensity)` —
the up-to-4 orthogonal neighbor tiles get a quick directional squash *away* from the
impact, staggered a few ms, settling back. Called by `feel.merge` and `feel.land` on
both boards; the caller supplies the neighbor nodes (it owns the grid). Skipped under calm.

**B2. Board punch-zoom** *(new — today big merges only `FX.shake`).*
`feel.board_punch(board, intensity)` scales the whole board container
`1.0 → 1.0 + PUNCH×intensity → 1.0` with a quick back-ease — the cozy escalation on
`tier ≥ ESCALATE_TIER`, complementing (and at mid-tier replacing) the reserved shake.
Both boards, skipped under calm.

### D. Combo & world reaction

**D1. Musical merge ladder** *(enhance — today pitch climbs continuously with combo +
`Audio.jitter_pitch`).* In `feel.merge`'s sound step, snap the combo climb to
**pentatonic** steps: `pitch = base * 2^(PENTA[degree]/12)`, `degree` walking the scale
by consecutive-merge count and resetting when the combo window (`COMBO_WINDOW`) lapses.
Keeps the existing jitter. A chain now sounds like a rising melody, not higher beeps.

**D2. Combo screen bloom** *(new).* A soft warm vignette/edge-glow overlay (a
`CanvasLayer` the scene owns) whose strength tracks the live combo — each merge swells
it toward `COMBO_BLOOM_MAX`, easing back to rest when the combo window expires.
`feel.merge` pokes the overlay with the current combo; the scene drives the decay. Both
boards. Allowed under calm at reduced strength (a soft glow, not motion).

**D3. Reactive ambient motes** *(enhance — `ambient.gd` already runs pollen/weather).*
On a merge, push an outward puff impulse to the ambient layer at the merge center so
the floating motes scatter from the impact. Graceful no-op when no ambient layer is
present (Rush, or weather off).

## New / changed tuning constants (`tuning.gd` class `FX`)

- `LAND_SQUASH_K`, `LAND_SQUASH_T` — the 2-key land squash (extract Rush's current values).
- `LAND_FLASH_FACTOR`, `LAND_FLASH_T` — the small land flash (a fraction of `FLASH_PEAK`,
  shorter than a merge flash).
- `LAND_TOUCH_DB`, `LAND_PUFF_N` — touch sound level + micro-puff count.
- `LAUNCH_TOSS_DB`, `LAUNCH_PUFF_N` — toss sound level + muzzle-puff count.
- `MERGE_FLASH_TIER_RAMP` (tier→peak factor), `MERGE_HITSTOP_COMBO_BONUS`,
  `MERGE_BURST_HOT_TIER` (8).
- `MOVE_SLIDE_T`, `MOVE_ARC_T_UP`, `MOVE_ARC_T_DOWN`, `MOVE_FALL_T_MIN/MAX` —
  extracted from the current per-site literals so they stop drifting.
- `MOVE_LEAN_DEG` — motion-lean tilt.
- `MOVE_SHADOW_ALPHA`, `MOVE_SHADOW_OFFSET`, `MOVE_SHADOW_SCALE` — cast-shadow look.
- `MOVE_TRAIL_N`, `MOVE_TRAIL_T`, `MOVE_TRAIL_SPEED_REF` — afterimage count, fade,
  speed at which the trail reaches full density.
- `HAPTIC_MS` (tick/soft/firm/heavy → ms), `HAPTIC_THROTTLE_MS` — haptic weights + throttle.
- `DRAG_LEAN_DEG`, `DRAG_LEAN_LAG` — drag tilt + trail amount.
- `TELEGRAPH_GLOW`, `TELEGRAPH_MAGNET` — target glow strength + lean-together amount.
- `RIPPLE_SQUASH`, `RIPPLE_STAGGER_MS` — neighbor nudge strength + per-neighbor delay.
- `PUNCH`, `PUNCH_T` — board punch-zoom scale delta + duration.
- `PENTA` — pentatonic semitone pattern for the merge ladder.
- `COMBO_BLOOM_MAX`, `COMBO_BLOOM_RISE`, `COMBO_BLOOM_DECAY` — screen-bloom strength + easing.
- `MOTE_PUFF_IMPULSE` — outward push given to ambient motes on a merge.

Existing reused: `SQUASH_K/T`, `FLASH_PEAK/T`, `HITSTOP_*`, `BURST_*`, `SHAKE_*`,
`GEN_CHARGE_K/T`, `ESCALATE_TIER`, `COMBO_MILESTONES`.

## Accessibility & headless

- Verbs inherit primitive gating: `flash`/`shake`/`hitstop` already no-op under
  `calm()`; `burst` trims via `amount_for`; `hitstop` is hard-off in headless.
- Sound always punches through (audio ignores `time_scale`), so a merge still *sounds*
  even during the freeze.
- Bundle additions: ripple, board-punch, drag-lean, telegraph-magnet, and ambient
  motes all skip under `calm()`. Combo bloom runs under calm at reduced strength (soft
  glow, not motion). Haptics gate on the `haptics` user setting + OS reduce flag
  (not on `calm()`), and no-op in headless / on platforms without a vibrator.

## RushFx interaction

`rush_fx.gd` thins out, not deleted:
- `merge_burst`, the tier ≥ 4 flash/hitstop, and the merge `cell_pop` calls route
  through `feel.merge`.
- The rush-specific extras stay as RushFx toggles: `score_tick`, `score_pulse`,
  `mult_pop`, `combo_heat`, `timer_low`, `treefall_crack`.
- `treefall_crack` already composes burst + shake + hitstop + sound — leave it as the
  one bespoke Rush impact (it is a different event from a merge/land).

## Testing

- **`engine/tests/feel_tests.gd`** (new suite, added to `run_suites.py`): for each
  verb assert it (a) fires its expected primitives at a given intensity, (b) scales
  with intensity (e.g. intensity 0 → no flash/hitstop/burst), (c) no-ops the freeze
  under calm and under headless. Headless can verify the *wanted* flags
  (`FX.hitstop_wanted()`) and the non-freeze components (squash tween created, sound
  requested); the actual `time_scale` freeze is headless-off by design.
- **Update `engine/tests/rush_fx_tests.gd`** for the rerouting (merge burst/flash/
  hitstop now via `feel.merge`).
- **Bundle coverage in `feel_tests.gd`:** haptic weight→ms mapping + throttle (assert a
  vibrate is requested with the mapped ms and suppressed when the setting is off / when
  throttled); ripple nudges the given neighbors and no-ops under calm; board-punch
  creates the scale tween; the musical ladder snaps pitch to pentatonic degrees and
  resets after the combo window; combo bloom strength rises per merge and decays on
  window expiry.
- **Board UI tests** for the input-driven pieces: target telegraph shows the glow/breathe
  only when `can_merge` is true and clears on move-off; drag-lean applies a clamped tilt.
- Run `make test-fast` after each change; `make test` before handoff.

## Risks / mitigations

- **Board regression** — the board merge is the most-played action. Mitigation: board
  calls `feel.merge` at intensity 1.0, gate 0, with the same curves it uses today, so
  the refactor is behavior-preserving; verify side-by-side.
- **Rush pace** — a per-merge freeze would stutter the fast mode. Mitigation: combo
  gate (no freeze below combo 2) + low cap + the existing re-entrancy guard.
- **Sound choices** — `tidy_poof` (land) and `item_drop` (launch) are *proposed*
  canonical ids; audio was not the owner's priority gap, so these are easy to retune
  and are isolated to one constant each.
- **Move-fx churn** — shadow + trail spawn transient nodes per move, and Rush settles
  many tiles at once. Mitigation: short self-freeing lifetimes, trail density capped
  by `MOVE_TRAIL_N` and scaled down at low speed (a gentle settle barely trails), and
  shadow/trail skipped under `calm()` and in headless. Verify Rush settle frame cost
  with a full board.
- **Haptic spam** — bulk Rush settles could fire many vibrations. Mitigation:
  `HAPTIC_THROTTLE_MS` per-frame gate + only the *merge*/*pickup* verbs haptic, not
  every settled tile.
- **Telegraph false signal** — the glow must mean "this will merge." Mitigation: drive
  it strictly off `can_merge(from, target)` and clear instantly on move-off.
- **Bloom overlay leak** — the combo-bloom `CanvasLayer` must free with its scene and
  never persist across screens. Mitigation: scene-owned, bound to scene lifetime.
- **Ladder reset** — a stale pentatonic `degree` would start a new chain mid-scale.
  Mitigation: reset `degree` whenever the combo window lapses, tied to the same
  `COMBO_WINDOW` the combo system already uses.

## Out of scope (parked)

- Exposing `intensity` and the verb knobs in the workbench.
- A true shader-based motion blur on `move` (the afterimage trail stands in for it).
- A `move` motion-lean beyond a slight constant tilt.
- **Bundle C** — premium high-tier shine sweep + idle board-piece breathing (considered, parked).
- iOS rich-haptic plugin (`UIImpactFeedbackGenerator` light/medium/heavy); the baseline
  uses `Input.vibrate_handheld` durations.
- Resident silent auto-merge ([map.gd:2101](../../../engine/scripts/scenes/map.gd)) —
  stays silent (it is a bookkeeping merge, not a player action).
