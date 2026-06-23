# Mystery reward reveal — slot-machine reels + player picks N (design)

**Date:** 2026-06-23 · **Task:** T54 (follow-up of T53) · **Area:** ux-feel + mechanics
**Owner-approved direction (2026-06-23):** "each of the 5 should spin like a real slot machine, one
by one; the good ones shine; at the end the player picks 2, and it must be clear that 2 is allowed.
Design and implement it properly — no lazy shortcut."

## Goal

Replace the current mystery-day reveal (a highlight cursor that sweeps the prize row and auto-lands
on random winners) with a **slot-machine reveal the player acts on**:

1. The `show` reward cards spin as **vertical slot reels**, landing **one at a time, left → right**.
2. As each reel lands, **valuable rewards shine** (gem rewards glow + sparkle; the single richest
   shines hardest).
3. Then the player **picks `win` of the `show`** — with an unmistakable "Pick N" prompt, a live
   counter, and a Claim button gated until exactly N are chosen.

Generalised from the existing per-slot data: **day 4** = 3 reels, **pick 1**; **day 7** = 5 reels,
**pick 2**. (`show`/`win` already live in `games/grove/login_rewards.json` per slot.)

## Why the mechanic changes (and the one consequence to own)

Today `roll_mystery` pre-picks `win` *random* winners and the spin lands on them. The new flow hands
the choice to the **player**, so they will rationally take the **top `win` by value** → the reward's
**expected value rises** vs. random. This is intended (agency = feel-good), but the pool numbers must
be balanced for "**top-N picked**," not "random-N." That tuning is already parked under
`docs/BACKLOG.md` → Tuning ("Mystery reward pools"); this spec adds the note there, it does **not**
re-balance numbers (placeholder pools stay).

## The three phases (interactive path)

### Phase 1 — reel spin, one at a time
- Each of the `show` cards becomes a **reel**: a card-sized clipped window over a vertical **band** of
  reward tiles. To spin, the band scrolls upward through pool symbols (fast), then **eases to a stop**
  (`ease_out`) aligned on the reel's **target reward** (the i-th drawn option). The scroll cycles the
  **full pool** symbols (repeated) so it reads as "could be anything," then snaps to the target.
- **All reels start spinning together; they LAND sequentially** (reel 0 first, then 1, …) — the classic
  left-to-right slot stop. A tick/snap SFX + a small land-pop per reel.
- **Timing (tunable defaults):** per-reel spin ≈ 0.9 s, land **stagger ≈ 0.32 s**, ease curve `ease_out`
  (cubic). 5 reels finish ≈ 1.0 s (reel 0) → ≈ 2.3 s (reel 4); 3 reels ≈ 1.0 → 1.7 s. Caption:
  `mystery.spinning` ("Spinning…"). These are constants at the top of `_spin` so the workbench Play
  button + the owner can re-pace; final feel is an owner eyeball (low-reliability).

### Phase 2 — the good ones shine
- The moment a reel lands, classify its reward: **premium** = `gems > 0`. Premium rewards get a
  **gold shine** (a glow ring + a sparkle FX); the **single highest-value** landed reward (value =
  `gems*100 + coins + water*10`, mirroring `Login.day_value` weights) gets the **strongest** "jackpot"
  shine. Non-premium cards stay plain. Shine is **enticement only** — it never restricts the pick.

### Phase 3 — pick N
- Caption switches to **`mystery.pick`** rendered as "**Pick 2**" (the count from `win`), with a live
  **counter** "`0 / 2`" (`mystery.pick_counter`, format `%d / %d`).
- Every card becomes **tappable**. Tap to select → the card **lifts** (small `-y` offset) + a **check
  badge** appears + the counter increments. Tap a selected card to **deselect**. Selection is capped at
  `win` (tapping a 3rd when 2 are chosen does nothing, or — chosen below — is rejected with a tiny nudge).
- A **Claim button** sits below the row: **disabled** until exactly `win` are chosen; label reads
  **"Pick 1 more"** / **"Pick 2"** style while short (`mystery.claim_more`, format `%d`) and **"Claim"**
  (`mystery.claim`) when ready.
- **Claim** → grant the picked rewards via `Login.claim_mystery(picked)`, the unpicked cards **dim
  away**, the won cards **celebrate** (`mystery.won` "You won!" + the existing `_celebrate` floaters),
  then **auto-dismiss** and rebuild the calendar (`on_done`).

### Selection rules (decided)
- Free choice: the player may pick **any** `win` of the `show` (shine guides, doesn't gate).
- **Deselect allowed** before Claim; **explicit Claim** (no auto-grant on the Nth tap) — this is what
  makes "you choose N" unmistakable, which the owner asked for.
- Selecting beyond `win` is **blocked** (the over-cap tap is ignored + a brief shake on the counter),
  so the player is never confused about the limit.

## Engine (core/login.gd) — minimal change

The reveal math is already right; the only shift is **semantics**, not new RNG:
- `roll_mystery(day)` is **unchanged**: still draws `show` **distinct** options + a `winners` set.
- `winners` is **repurposed** as the **default / fallback pick** used only by the **non-interactive
  paths**: the headless `claim_today()` on a mystery day and `LoginMystery.open({instant:true})` (the
  test path). The **interactive UI ignores `roll.winners`** and passes the **player's** picks to
  `claim_mystery`.
- `claim_mystery(picked: Array)` is **unchanged** — grants whatever set it's handed, bumps the streak
  once, refuses a second claim.

No data-schema change. (`won_rewards(roll)` keeps serving the instant/headless default.)

## UI (engine/scripts/ui/login_mystery.gd) — the real work

Refactor the reveal into clear units (each independently testable):
- `build_reveal(options, winners, width, opts)` — **kept** as the shared face builder (T53), but the
  inner cards become **reel-capable**: each card exposes its **reel band** + a `land_on(target)` hook.
  Returns `{dialog, reels, caption, claim_button}`.
- `_reel(reward_options, target_reward, cw, ch)` — builds one reel (clipped window + scrolling band of
  pool symbols ending on the target). Reuses the T53 `_reveal_card` look for each tile (parchment cell +
  icon+amount), so a landed reel is visually identical to today's card.
- `_spin(reels, targets, on_all_landed)` — drives the staggered land (one chained tween), shines premium
  reels on land, then calls `on_all_landed`.
- `_enter_pick(reels, win, caption, claim, on_claim)` — wires the pick phase: per-reel tap-select/deselect
  (capped at `win`), the counter + Claim label updates, Claim → `on_claim(picked_rewards)`.
- `open()` orchestrates: build → if `instant` grant `roll.winners` immediately (unchanged test path);
  else `_spin` → `_enter_pick` → on Claim `Login.claim_mystery(picked)` → `_finish`/celebrate/dismiss.

The reel band, shine, and pick interaction are **engine-side** (work in the real game) and reuse the
shared kit for the card look.

## Strings (games/grove/strings.json → `mystery`)

Add: `pick` = "Pick %d", `pick_counter` = "%d / %d", `claim` = "Claim", `claim_more` = "Pick %d more".
(Keep `spinning`, `won`, `banner_single`, `banner_plural`.) All via `Strings.t(...)` so `strings_tests`
validates them.

## Workbench (games/grove/tools/ui_workbench*) — make it watchable

- The static `mystery` preview states become: **"spin"** (mid-spin: some reels landed, some scrolling),
  **"revealed"** (all landed, premium shining), **"pick"** (pick phase, some selected + the Claim
  button). Replaces the T53 "shown"/"won".
- **"▶ Play spin"** button in the Mystery sidebar: rebuilds the mystery element and runs the **real**
  `_spin` (and optionally walks into the pick phase) on the live preview, so the animation + pacing are
  watchable/tunable in `make workbench` and capturable with `make shot-workbench EL=mystery`.

## Testing

- **`engine/tests/login_tests.gd`** (run direct; still in `ENGINE_TESTS_DISABLED`): keep the existing
  instant-grant + reveal-amount checks; **add** — (a) the reveal builds `show` reels each carrying a
  landed reward amount; (b) after spin, the pick phase exposes one tappable card per reel + a Claim
  disabled until `win` selected; (c) selecting `win` cards enables Claim and `claim` grants **exactly the
  selected** rewards + bumps the streak by one; (d) deselect works + over-cap is blocked.
- **`engine/tests/save_tests.gd`** (active): unchanged mystery math (roll counts, distinct, faucet,
  claim grants exactly the passed set) — confirms the engine semantics didn't regress.
- **`games/grove/tests/grove_workbench_tests.gd`** (active): the mystery component still registers +
  renders each preview state; the Play-spin control exists; deterministic preview.
- **Pacing** is perceptual (low-reliability): verified by the workbench Play-spin + a live capture
  (frame strip / GIF), durations measured, final feel handed to the owner — never an eyeball-only claim.

## Files

`engine/scripts/ui/login_mystery.gd` (reels + shine + pick — the bulk) · `games/grove/strings.json`
(+4 keys) · `games/grove/tools/ui_workbench_view.gd` (preview states + Play-spin) ·
`games/grove/tools/ui_workbench_kit.gd` (only if a shared reel helper is warranted) ·
`engine/tests/login_tests.gd` + `games/grove/tests/grove_workbench_tests.gd` (coverage) ·
`docs/BACKLOG.md` (Tuning note: balance pools for top-N-picked). `core/login.gd` **unchanged** (the
`winners` semantics note goes in its doc comment only).

## Edge cases

- `instant`/headless path unchanged (auto-grants `roll.winners`) — keeps tests + the debug fast-forward
  working without a player.
- `win == show` (pick all) — handled (Claim enables when all selected). Not in current data.
- Empty/short pool or non-mystery slot → no reels, no crash (existing guards).
- Over-cap selection blocked; Claim never fires with ≠ `win` picked.
- Reduced-motion is out of scope (no such setting exists); the `instant` flag is the only skip.

## Out of scope / parked

- Mystery-pool **number** tuning (BACKLOG → Tuning; this ships on placeholder pools).
- Re-enabling `login_tests` in the Makefile (BACKLOG → Testing).
- A literal "chest lid opens" pre-animation (the reels are the reveal; revisit only if the owner wants
  a box-open beat on top).
