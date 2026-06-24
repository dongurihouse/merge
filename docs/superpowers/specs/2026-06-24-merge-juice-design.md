# Merge impact + Tier 2 juice — design

Date: 2026-06-24
Branch: `juice-merge-impact`
Status: approved (brainstorm), pending implementation plan

## Goal

The merge is the most-repeated action in the game, and today it is the flattest
thing in it: `_after_merge` does a glide-in → uniform `FX.pop` → particle burst →
sound. That is *acknowledgment*, not *impact*. Give the merge real weight (the
cozy-but-satisfying "C" direction the owner picked over the punchier "D"), plus a
small set of grounded Tier 2 additions, and consolidate the duplicated shake helper.

Direction chosen from an animated 4-way comparison: **C — Satisfying**. Cozy weight
(squash & stretch + accelerate-into-impact) PLUS a ~50ms hitstop "thunk" + a soft
white flash + a small settle nudge. **No** full screen shake on routine merges
(that was the rejected "D"). A *gentle* shake is reserved only for rare big moments.

## Non-goals

- No global tone change — the game stays cozy. Shake is reserved, never routine.
- No new art. Reuse existing burst sprites / dot fallback.
- The lucky coin drop is unchanged: it already arcs onto the board as a pickup
  (`_drop_coin_near`), it is not a wallet grant — "arc the coin" was dropped after
  reading the code.
- Spawn is not tier-differentiated: generators only ever produce base-tier fuel,
  so per-tier spawn juice is moot. (The merge burst already scales by tier.)

## Components

All animation values live in `tuning.gd` class `FX` (existing convention). Every new
behaviour ships behind a flag in `features.gd` (rule N4) and is calm-mode aware.

### 1. New shared FX statics — `engine/scripts/ui/fx.gd`

- **`hitstop(secs)`** — global micro-freeze.
  - Sets `Engine.time_scale ≈ 0` (HITSTOP_SCALE) and restores `1.0` via a real-time
    `SceneTreeTimer` created with `ignore_time_scale = true` (and `process_always`),
    so it ALWAYS recovers regardless of the freeze.
  - Tweens obey `time_scale`, so the produced tile's `squash_pop` tween — started at
    impact — holds its compressed pose during the freeze and plays out on release.
    No explicit "wait then animate" sequencing needed.
  - Audio ignores `time_scale`; the merge sound punches through the freeze.
  - **Hard guards (no-op if any true):** `DisplayServer.get_name() == "headless"`
    (protects the deterministic test clock — see Risks), calm mode, flag
    `merge_hitstop` off.
  - **Re-entrancy guard:** a static "active" token; a merge during an existing freeze
    does not stack another freeze (avoids stutter during fast play / combos).
  - Gating split out as a pure predicate `hitstop_enabled()` for unit testing.
- **`squash_pop(node)`** — squash & stretch on the merge result.
  - Profile (the "soft" C curve): `(1.16,0.84) → (0.92,1.12) → (1.03,0.98) → (1,1)`
    with tuned per-leg durations; center pivot via existing `_center_pivot`.
  - Calm mode falls back to the existing uniform `pop()`.
  - Existing `pop()` is unchanged and still used for taps/confirms.
- **`flash(host, gpos, size)`** — brief additive-white overlay over the merged tile.
  - A white rounded rect (additive blend) at the tile rect, alpha `FLASH_PEAK (0.55) → 0`
    over `FLASH_T (~0.16s)`, then frees itself. Holds bright during a freeze, fades on
    release. No-op under calm.
- **`shake(node, amp)`** — decaying positional shake.
  - **Promoted from the private `_shake` in `engine/scripts/ui/login_mystery.gd`**
    into the shared vocabulary. `login_mystery` is updated to call `FX.shake`, deleting
    its private copy (consolidation). Calm mode heavily reduces or skips.
- **`gen_charge(node)`** — generator pop anticipation.
  - Quick compress→overshoot→settle squash on the generator as it spits a tile
    (e.g. `(0.9,1.1) → (1.08,0.92) → (1,1)`), tuned subtle. No-op under calm.

### 2. Wire into the merge — `engine/scripts/scenes/board.gd`

- **`_commit_merge` (~2108):** change the absorbed tile's slide ease from
  `TRANS_QUAD/EASE_OUT` (floaty) to `EASE_IN` — it accelerates *into* the impact.
- **`_after_merge` (~2116):** replace `FX.pop(n)` with the impact sequence:
  1. set produced tile to the squash-start pose, start `squash_pop(n)`
  2. `flash` over the tile rect
  3. `hitstop(secs)` — duration scales slightly by tier (HITSTOP_MERGE + tier bonus)
  4. keep the existing tier-scaled `burst` and pitch-scaled audio
  5. combo + escalation hooks (below)
  - Behind flag `merge_impact` (squash + flash + anticipation ease); the freeze is the
    separate `merge_hitstop` flag.

### 3. Big-moment escalation — flag `big_moment_shake`

The gentle reserved shake (soft end of "D"), never on routine merges:
- `_after_merge`: when `tier >= 4` (the existing STRAW threshold), add a gentle
  `shake(board_area)` + a touch more hitstop + slightly larger burst.
- `engine/scripts/scenes/map.gd`: add the same gentle `shake` to level-up (~1025)
  and map-restore (~1057, alongside the existing `shatter_veil`).

### 4. Generator anticipation — flag `gen_anticipation`

- `_pop_seed` (~1977): call `gen_charge` on the generator node when it pops a tile.

### 5. Cozy combo — flag `merge_combo`

- **Pure timing fn** `BoardLogic.combo_step(prev_count, dt, window) -> int` in
  `engine/scripts/core/board_logic.gd` (unit-testable without the scene): returns
  `prev_count + 1` if `dt <= window`, else `1`.
- `board.gd` holds last-merge time + count; reset after `COMBO_WINDOW (~2.5s)` idle.
- At milestones (3 / 5 / 8): a small encouraging-word floater via `FX.floating_text`
  (cozy strings, e.g. "Nice!" / "Lovely!" / "Wonderful!" — added to grove
  `strings.json`, NEVER "COMBO ×5"), a slight audio pitch bump, and a couple extra
  burst particles. **No shake** — stays cozy. Calm mode keeps the worded floater
  (text only), drops the extras.

### 6. Flags — `engine/scripts/core/features.gd`

Add to `FLAGS`, all default `true`:
`merge_impact`, `merge_hitstop`, `big_moment_shake`, `gen_anticipation`, `merge_combo`.

### 7. Tuning constants — `engine/scripts/core/tuning.gd` class `FX`

New constants (values are starting points, tuned in-engine):
- Hitstop: `HITSTOP_SCALE (0.0)`, `HITSTOP_MERGE (~0.05)`, `HITSTOP_TIER_BONUS`,
  `HITSTOP_BIG (~0.08)`.
- Squash: keyframe scales + per-leg durations (`SQUASH_*`).
- Flash: `FLASH_PEAK (0.55)`, `FLASH_T (0.16)`.
- Shake: `SHAKE_AMP`, `SHAKE_BIG_AMP`, decay/oscillation count, duration.
- Gen charge: `GEN_CHARGE_*` scales + durations.
- Combo: `COMBO_WINDOW (~2.5)`, `COMBO_MILESTONES ([3,5,8])`, `COMBO_PITCH_STEP`,
  `COMBO_BURST_BONUS`, `ESCALATE_TIER (4)`.

## Data flow

`drag-drop → _commit_merge (slide, EASE_IN) → tween callback → _after_merge`:
build produced tile → `squash_pop` + `flash` + `hitstop` (held compressed pose during
freeze) → `burst` + audio → `combo_step` (milestone floater/pitch/extra burst) →
escalation shake if `tier >= ESCALATE_TIER`. Generator tap → `_pop_seed → gen_charge`.

## Risks / decisions

- **Headless test clock (load-bearing):** the grove test base pins
  `Engine.time_scale = 1.0` and warns that disturbing the headless clock starves
  frame-dependent asserts (bramble-clear, merge→log). `hitstop` mutates global
  `time_scale`, so it is **hard-guarded off in headless** — it is a purely felt
  visual effect with no logic consequence, so skipping it headless is correct and
  keeps every suite green. The *gating predicate* is still unit-tested.
- **Re-entrancy / fast play:** the active-token guard prevents stacked freezes from
  feeling stuttery during rapid merges and combos.
- **Combo tone:** worded, gentle, milestone-gated — chosen to fit the cozy direction
  (C), not arcade.

## Testing

- Unit: `hitstop_enabled()` is false under headless / calm / flag-off; `squash_pop`,
  `shake`, `gen_charge` each produce a tween / set pivot; `combo_step` window + reset.
- Place tests in existing active suites (`calm_tests`, `floater_tests`, a grove slice)
  — never a disabled suite.
- `make test-fast` after each change; full `make test` before handoff.

## Verification (not eyeballing)

Capture a real-renderer before/after of a merge via the quiet minimized-window
`override.cfg` pattern (CLAUDE.md), as a short frame sequence / composite around the
impact, and deliver it to the owner to judge the feel. Do not assert "feels good" from
a thumbnail.
