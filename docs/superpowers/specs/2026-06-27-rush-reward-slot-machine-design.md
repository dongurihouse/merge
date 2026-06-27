# Rush reward → slot-machine reveal (design)

**Date:** 2026-06-27 · **Area:** ux-feel + mechanics (Explore · Trade screen)

## Problem

The Trade screen (`engine/scripts/scenes/explore_trade.gd`, shown after a Rush run) offers three
boxes — Acorn pouch (1 spirit / 250 pts), Grove chest (4 / 800), Spirit vault (8 / 2000). They
differ **only in scale**, and per-spirit cost is nearly flat (250 / 200 / 250), so the "choice"
collapses to a formula: buy the biggest box you can afford, repeat, dump the remainder. It is a
multiple-choice question with one correct answer.

Deeper cause (confirmed with the owner): spirits are currently **undifferentiated** — any spirit is
about as good as any other, more is always strictly better — so no spend UI on top can create a real
decision. Rather than manufacture artificial demand, the owner's call is to **remove the fake choice
entirely**: convert score straight to spirits, and replace the box-picking with a satisfying
slot-machine reveal — one spinning reel per earned spirit.

## The decision

Convert the run's score directly into spirits at a fixed rate, then reveal them as slot reels.
There is **no player choice** on this screen; its job is the payout *feel*, not a decision.

- **Conversion:** `n = max(1, floor(score / RATE))` with `RATE = 200` (the old Grove-chest per-spirit
  rate, i.e. every run now gets the best value automatically). The remainder is **discarded** — no
  bonus reel, no carry-over. The `max(1, …)` floor means a run always pays out **at least one** spirit.
- **What each spirit is:** unchanged. Kind is rolled uniformly from the unlocked pool; tier off the
  generator curve (`TIER_ODDS` = 65/25/9/1). This is purely a *presentation* change over the rewards
  `Habitat.grant_chest(n)` already produces — same RNG, pool, and hand-add path.
- **Reveal:** `n` slot reels, one per spirit. All reels start whirring together and **land one at a
  time, left → right** (a slow cascade). Each reel scrolls spirit faces, eases to a stop on its
  spirit, and settles with a bounce. High-tier landings **shine**.
- **The single control is `Done`** (dual-purpose — see below). The reveal **auto-starts** when the
  screen opens; there is no Spin button.

## Reuse: the slot-reveal already exists

`engine/scripts/ui/login_mystery.gd` (the daily mystery-gift reveal, §T54) already implements exactly
this spin: reels that start together and land left→right with a stagger, a weighty bounce + flash +
escalating chime per land, a premium **shine** (glow + sparkle) on the valuable reels, a dialog shake
on the richest, and an `instant` headless path that skips the animation. We reuse that machinery
rather than reinvent reels.

The mystery reveal's reel content is a *currency reward* (`coins`/`gems`/`water`), and it has a **pick
phase** (player chooses N of the shown rewards). The rush reward differs on exactly two axes: tiles
are **spirits** (kind + tier), and there is **no pick** (direct conversion). Everything else — band
build, spin tweens, land juice, shine — is identical.

**Recommended structure — extract a shared reel helper.** Pull the generic reel mechanic out of
`login_mystery.gd` into a new `engine/scripts/ui/slot_reel.gd`:

- `build_reel(pool, target, cw, ch, index, make_tile: Callable) -> Control` — band + clipped window,
  landed on `target`; `make_tile.call(symbol, w, h)` renders one tile (currency row *or* spirit).
- `spin_reels(host, reels, dialog, on_all_landed, cfg) -> Dictionary` — the start-together / land-
  staggered tweens + per-reel `land` juice; `cfg` carries the pacing constants and a
  `shine_pred: Callable` (symbol → bool) plus the `top_index` to shine hardest. Returns a handle
  exposing `finish_now()` (kill tweens, snap every band to its target, apply shines, one summary
  chime — for the Done-skip).

`login_mystery.gd` then calls `slot_reel` passing its `_reward_amounts` builder + `is_premium`
predicate, and keeps its pick phase locally. `explore_trade.gd` calls `slot_reel` passing a
spirit-tile builder (reusing the existing `_spirit_widget` art path) + a `tier >= 3` predicate, and
has no pick. This matches the codebase's "single source" convention and keeps both reveals in step.

**Owner's call (2026-06-27): take the shared extraction**, refactoring `login_mystery.gd` to delegate
to `slot_reel.gd` as needed. The adapt-in-place duplicate (port `_spin_reels` / `_land_reel` / `shine`
into `explore_trade.gd`, leave the mystery reveal untouched) is the fallback only if the extraction
destabilises the mystery tests.

## Tier shine (the "rare" moment)

The mystery reveal shines `gems > 0`; the spirit analog is **tier**. A reel whose spirit lands at
**tier ≥ 3** shines; the **highest-tier landed reel** shines hardest and kicks the dialog shake — the
~1% tier-4 pull is the jackpot beat. Reuse `login_mystery.shine` / `_flash` / `FX.shake` unchanged.

## Done — dual-purpose

A single `Done` button (the existing cream pill), behaviour depends on reveal state:

- **While reels are still landing** → *finish now*: kill the running tweens, snap every band to its
  target spirit, apply the tier shines, show the final tally, set `finished = true`. **The window
  stays open** so the player can see everything they got.
- **After all reels have landed** → *close*: the existing `_on_done()` → `SceneWarm.go(Map.tscn)`.

The spirits are added to the hand up front by `grant_chest` (before the animation), so a skip never
loses a reward — finishing is purely visual.

## Screen flow & layout

Unchanged shell: still its own screen after Rush (`explore_rush.gd` → `ExploreTrade.tscn`), still the
shared framed dialog (`Kit.dialog_frame`) with the run-score chip at top. Inside the frame:

- **Remove** the three box cards (`_box_card` / `_box_icon`), the "Spend your score on boxes…" note,
  and the separate "Revealed" grid. The reels *are* the reveal and stay on screen after landing.
- **Add** a centred caption (reusing the mystery caption pattern: a "revealing…" line that becomes
  `+N spirits to your hand` on finish) over a centred **reel row** that **wraps to a grid** when `n`
  is large (mirror the old Revealed grid: ~5 columns).
- Banner text: the "Trade" framing (spend score) no longer fits. Rename to **"Rewards"**.

## Edge cases

- **Weak run** (score < `RATE`): `max(1, …)` still grants **one** spirit — the screen always pays out
  at least one reel. No "not enough score" empty state.
- **Empty unlocked pool** (`grant_chest` returns `[]` — nothing to roll): the one edge that can still
  yield zero reels. Show a gentle empty caption; `Done` closes. Unlikely after the first map.
- **Large `n`** (a high-scoring run, e.g. 4000 → 20 spirits): reels wrap into the grid, and the spin
  **caps total reveal time** — compress the per-reel stagger so the whole cascade stays bounded
  (target ≤ ~3.5 s) instead of `n × stagger`. `Done`-skip is always available as the escape hatch.

## Tunable feel constants (owner eyeball)

Carried at the top of the reveal, same spirit as `login_mystery`'s "owner feel dial". Defaults set
**slower** than the mystery reveal per the owner's note:

- `REEL_SPIN ≈ 1.2 s` (reel 0 spin time; was 1.0)
- `REEL_STAGGER ≈ 0.55 s` (gap between successive stops; was 0.45)
- `REEL_ANTICIPATE ≈ 0.5 s` (last reel hangs longer)
- Large-`n` stagger compression so total ≤ ~3.5 s.

Final pacing is an owner eyeball via the workbench Play button (low-reliability — can't be asserted
headless).

## What gets removed / changed

- `explore_trade.gd`: drop `_on_buy`, `_box_card`, `_box_icon`, the box loop, the `_revealed` grid;
  add the reel build + auto-spin + dual `Done`. Reuse `_spirit_widget`.
- `explore.gd`: `BOXES` and `buy_box()` become unused once the boxes are gone. Add `RATE`
  (e.g. `const TRADE_RATE := 200`). Remove `BOXES` / `buy_box` if nothing else references them after
  the test rewrite (they are only used by the trade screen + its tests today).
- Rush box icon assets (`assets/ui/rush/rush_box_*.png`) become unreferenced — leave on disk, just
  unused (asset cleanup is out of scope).

## Testing

The animation can't be observed headless (no real renderer), so logic is tested through an **instant
/ headless path** mirroring `login_mystery`'s `instant:true` — convert + grant without spinning.

- Rewrite `grove_explore_tests.gd`:
  - `_test_run_state`: drop `buy_box`; assert `floor(score / RATE)` conversion math and remainder
    discard (e.g. 852 → 4, 199 → 0, 400 → 2).
  - `_test_screens` seam: the Trade screen, given a run score, grants `floor(score/RATE)` spirits to
    the hand, each a pool kind at tier 1–4 (replaces the `_on_buy(BOXES[i])` assertions).
  - Replace `_test_trade_box_icons` (box-icon test, now meaningless) with a reel-build test: `n`
    reels built for a score, each carrying a pool-kind spirit; the unarted-spirit reel still shows
    placeholder face details (keep the `_spirit_widget` placeholder assertion).
  - `_test_trade_reward_dialog_layout`: keep — still uses the shared `TradeDialog` frame.
- If the shared `slot_reel.gd` extraction is taken, keep `login_tests.gd` green (the mystery reveal
  must behave identically after delegating to the shared helper).
- `make test-grove` for the slice; `make test` before handoff.

## Resolved decisions (owner, 2026-06-27)

1. **Weak run** — guarantee a **minimum of 1** spirit: `n = max(1, floor(score / RATE))`. No
   zero-spirit empty state (except the empty-pool edge).
2. **Code reuse** — **shared extraction**: refactor `login_mystery.gd` into a shared `slot_reel.gd`,
   reusing as much as possible. Adapt-in-place is the fallback only on test instability.
3. **Banner** — "Rewards" (default; trivially changed if the owner prefers "Trade" / "Spoils").
