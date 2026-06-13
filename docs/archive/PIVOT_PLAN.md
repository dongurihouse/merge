# Reach Zero — Revised Direction & Godot Build Roadmap

## 1. Revised positioning

Reach Zero is a **cosy, can't-lose merge puzzle** where you slide colorful gems together up a 2^n ladder and clear the board to **ZERO** — and "it feels like 2048" is now the point, not a problem. The moat is **not the mechanic**; it is **juice + content + feel + progression**: a familiar verb wrapped in best-in-class screen feel, a steady drip of new toys, and a visible place that grows between sessions. The three chill-audience design rules we build to: **(1) zero learning** — every new thing is the merge verb you already know, taught wordlessly on a can't-fail board; **(2) zero dead frames** — every gesture produces something satisfying, you can never silently fail and never truly lose; **(3) something new almost every session** — a gift, theme, room, or chest within a 60–90s play.

## 2. Core difficulty decision — FORGIVING / near-confluent

**Decision: make the default core forgiving and near-confluent. Retire stranding as a design goal for the main track; keep it only as opt-in "Expert" content.**

- The spec's own analysis hands us the lever: **open boards (≥8 free cells, no/few walls) cannot strand** — they are effectively confluent. We do **not** change the verified `board.gd` mutation rules (`apply_merge`/`apply_reposition` stay exactly as-is). We change **level generation** to live at the open end of the dial: generous free-cell budgets, sparse walls.
- **Stranding becomes a rare edge, and it is always recoverable.** Keep unlimited free `_on_undo`/`_on_restart` (already in `main.gd`). Where a genuine dead-end is detectable, surface an opt-in **"Tidy"** nudge (re-spread pieces), never a fail screen, never an auto-popup.
- **The current L3/L4 "§2.11 strand" puzzle (`levels.gd`, par 6, the wall at index 4) is demoted** out of the default progression into an optional **Expert / "Brain"** side-track and a hidden efficiency crest. The greedy-strands design that the slice was built to validate is the part the pivot supersedes.
- **Justification:** the audience has zero attention tolerance; "the worst case is a free undo, and almost any tap order wins" is the feel contract that delivers chill. The spatial depth was invisible to ~82% of players and defeatable by undo anyway — we stop paying for it and reinvest in juice/content. The thin optional skill layer (efficient-clear crest) keeps the puzzle-hungry minority fed without pressuring casuals.

## 3. Controls — THE decision

**Pick ONE: per-piece TAP-FIRST, drag-accepted, with a "sticky selection / never-discard" commit model. Verdict on 2048's whole-board swipe: REJECT it.**

**Why reject the 2048 swipe (load-bearing):** 2048's directional swipe is inseparable from **gravity + a spawn-every-move** ruleset. Reach Zero is the inverse — no gravity, no spawning, the board only shrinks (`board.gd` has zero gravity/spawn code). A whole-board swipe would force adding gravity, which makes a *perfectly empty* board unreachable and **kills the "reach ZERO" win condition** and the one differentiator we keep. It is a rules rewrite masquerading as a control fix.

**How the chosen scheme works (it is already 90% built in `main.gd`):**
- Tap a piece → it lifts + the board shows **GREEN merge targets** (`board.merge_targets`) and **BLUE reachable cells** (`board.reachable_empties`), plus a new **dim "ghost halo"** on right-match-but-blocked partners.
- Tap a highlighted cell → commit via `_commit` (slide animation). Drag is the **same action**: press selects the source, release on a legal cell commits.

**How "blocked" never silently fails — fix the one defective branch in `_handle_release`/`_tap`.** Today, a drag/tap that resolves to an illegal cell falls through to `selected = NONE` (a dead no-op). Replace with three explicit, mutually-exclusive feedback branches, every one of which produces motion + haptic:
1. **Right family/tier but path blocked** → nudge the source toward the partner and rubber-band back + soft "no" haptic + pulse the ghost halo; **keep selection.**
2. **Non-matching piece tapped** → shake the *target* (`_shake`) + soft haptic; **keep selection.**
3. **Source has zero legal moves** → shake immediately on press-down (call `_shake` in the press branch when `_has_moves` is false), not only on tap.
- **Release on an illegal cell never discards** — it degrades back into the tap flow with highlights still showing. Add a **live legality preview during drag**: the cell under the finger gets a "will-commit" ring if legal, a desaturated (not red-flash) "won't-commit" tint if not, so the gesture self-corrects before lift.

**Rules / level-design implications:** none to the engine — every committed action remains a legal `board.gd` move (drag resolves only to cells in `reachable_empties`/`merge_targets`). The control choice is consistent with the forgiving core: keep per-piece agency, make the *board* forgiving underneath it. One-time wordless coach mark on first play ("Tap a gem, then where to send it"); a board-edge swipe gently deselects rather than doing nothing, so even 2048-reflex players get a response.

## 4. Juice — ranked build order

This is ~90% of the remaining product. Build top-down; **1–4 make the demo finally feel good, 5–8 make it feel expensive.** All hooks already exist in `main.gd`. **Hard rule: per-move = quick + quiet; ZERO = the one big exhale. No screen shake / flash / glow on ordinary merges** (that is the chill-vs-chaos fault line).

1. **Grade the slide + fix the drag.** In `_commit`, scale slide duration by Manhattan distance: `var d = clampf(0.10 + 0.028 * dist, 0.12, 0.24)` (keep `TRANS_QUAD/EASE_OUT`). Add a 60ms "rush-together" before the merge resolves (chain a second `create_tween()` segment). Make finger-drag slide to the farthest legal cell with a small rubber-band snap. **Never a no-op.**
2. **Four core SFX** via a pooled `AudioStreamPlayer` autoload (~6 voices): merge "tink" (dry glassy, `pitch_scale` stepped by run counter), slide-glide (`pitch_scale` rises with distance), showcase "champagne pop", ZERO chime. Fire merge-tink in `_after_move` (merge branch), glide in `_commit`, pop in `_flash`, chime on `is_cleared()`. Direction: **dry/glassy/pentatonic — no boings, no slot-machine clatter.** Independent Music/SFX/Haptics sliders; fully satisfying muted.
3. **Upgrade merge pop → squash + burst.** Replace `_pop`: incoming tile squashes on contact (`scale` ~0.85y/1.12x for 50ms) then result springs to 1.15 overshoot (`TRANS_BACK`); punch the tier `Label` 1.0→1.25→1.0; instance a reusable `MergeBurst.tscn` (`GPUParticles2D`, `one_shot`, ~12 motes, additive, tier hue) at `dst`; add a source-cell vacuum-shimmer on the vacated slot to telegraph the freed lane.
4. **Build the ZERO catharsis screen** (the namesake moment, currently just a status string at `main.gd:317`). On `is_cleared()`: dim board → left-to-right shimmer sweep over the empty grid → "ZERO" serif scale-in + fake bloom → 1–3 stars stamp sequentially with ascending chime + small bursts → pieces/sparkles fly to a Vault icon. Reuse `_flash` as the bridge; sequence with a chained Tween.
5. **Recolor for high-contrast pop.** Replace `_tier_color` with saturated, value-ascending, colorblind-safe hues: **T1 cyan `#3FC9FF`, T2 spring-green `#43E06A`, T3 violet `#B36BFF`, T4 hot-magenta `#FF5FA8`, T5+ warm-gold `#FFC24A`.** Keep the dark velvet bg (`0.09,0.08,0.12`). Add gloss (top-light gradient + inner rim highlight in the StyleBoxFlat) + tier pips. Never two adjacent-hue families on one board.
6. **Pentatonic run system (re-keyed for chill, NOT speed).** Run = consecutive merges within a ~2.5s rolling window; step the tink up C-D-E-G-A-C (cap ~8), scale mote count 12→~28; on lapse, a soft descending two-note "settle" — never a buzzer.
7. **Haptics.** Android: `Input.vibrate_handheld(ms)`. iOS: thin ObjC singleton calling `impactOccurred` (the project already builds via `ReachZero.xcodeproj`). Map selection=light, slide-tick=faint, merge=`.medium` (<16ms from visual contact), showcase=double-pulse, ZERO=three ascending pulses. Global toggle, respect OS setting, **never the sole carrier of a cue.**
8. **Restrained screen punctuation + fake bloom — showcase/ZERO ONLY.** 2–4px board-offset shake, <12% white flash, brief `Engine.time_scale ~0.85` slow in the 0–150ms showcase anticipation, additive radial soft-white sprite. **Explicitly nothing on ordinary merges.**

## 5. Additive content elements — ordered introduction

Each is a new reserved int-code (`family*100+tier` encoding already supports it), maps to an existing `board.gd` mutation, **adds no new verb**, reads as a known noun via juice (no text), debuts on a can't-fail board with a ≤4-word coach mark, **one unknown at a time**, cap ~2–3 concurrent special types per board.

| # | Element | What it does | When |
|---|---|---|---|
| 1 | **Wild Gem** (rainbow joker) | Merges with any adjacent piece; can only help. | W1, ~level 5 (gifted) |
| 2 | **Bomb / Showcase Burst** (booster) | Clears a piece + 4 neighbors to EMPTY; never hurts. | W2–3 |
| 3 | **Crate / lock** (blocker) | Removed by any adjacent merge; always clearable, never a permanent wall. | W3–4 |
| 4 | **×2 multiplier tile** | Doubles Vault credit (Glint) on a merge; pure upside tied to the goal. | W4–5 |
| 5 | **Producer / fountain** (spawner) | Drops fresh low-tier pieces; backbone of no-fail Zen/Endless; **cap rate, pair with bombs**. | W5–6 |
| 6 | **Gentle countdown tile** | Ticks down then bursts into a free reward — **never a loss**. | W6–7 |
| 7 | **Daily / event modifier** | One whole-board fun rule per day via the daily pipeline. | From W2 (parallel rotation) |

**Forgiveness invariants:** every blocker is merge-removable; every countdown expires into something positive. **Drip target: one new toy every 5–8 levels.** All per-element VFX must reuse a **shared modular palette/shader rig** (per-element art is the real cost).

## 6. Progression + return loop

**Meta = "The Atelier"** (the concrete Collection Vault translation): ~8 themed Rooms (Diamond Hall, Couture Wing, Gilded Salon, Midnight Gala…), each with 6–9 Display Stands. Clearing a board sends its showcased pieces flying into the next open stand (reuse the showcase animation as the phase bridge). **Any showcase fills the next stand — no named-variant matching, no theme-locks, no multi-copy "Rush."** Fill a Room → it visibly upgrades (lights on, chandelier drops, velvet→marble) and unlocks the next Room + a board theme. A light, optional **decoration layer** (spend Glint on fountains/rugs/trim) gives binge players a sink and 5-min/day players a reason to peek.

**Progression is RECEIVED, not worked for.** The only required per-session decision is "which pair do I tap"; collection/decoration/streak/daily all advance as a consequence of clearing. **Demote** the 3-star/Clean-Clear mastery chase, par-efficiency leaderboards, ghost replays, variant-seed re-derivation, and early two-currency complexity (introduce Lumen only after the first Room, ~D3–D4).

**Cadence (forgiving, never punishing):** Daily Gift (7-day escalating ramp, 1 free skip/week, streak **dims rather than dies** on a miss); one generous **Daily Board** (~60–90s, no required competition); **Weekly Theme** (board re-skin + one limited Atelier "find," returns in rotation = soft FOMO); 6-week **Season Ribbon** (free track always 1–2 clears from the next node).

**What visibly advances between sessions (4 different clocks):** (1) **Map** — your token one node further up the world ribbon; (2) **Atelier** — a Room visibly fuller / newly lit; (3) **Streak flame** — brighter, next chest previewed; (4) **Season ribbon** — bar advanced, next cosmetic highlighted. Ship a **"next-beat preview"** card on every win/quit showing the single closest carrot ("Diamond Hall: 1 jewel to go") — cheapest high-impact return driver; build it before any leaderboard/social feature.

**Player-facing "how it progresses" blurb:**
> *Slide and merge colorful gems up the ladder; clear the board to reach ZERO. Every treasure you make flies into your own Atelier — a glittering display you grow room by room. Finished rooms light up and unlock new themes, boosters, and dazzling new things to collect. A fresh daily board, weekly events, and seasonal collections always give you something new to chase — and you can never lose, only solve.*

## 7. Revised Godot build roadmap (start now, each step feels on the desktop loop)

Order chosen so the **desktop click-loop feels better after every step**. Steps 0–4 are the "make it finally feel good" sprint.

- **Step 0 — Safety net.** Confirm `godot --headless -s res://tests/run_tests.gd` still passes (9/9) before and after each engine-adjacent change. Engine rules are frozen; do not touch `board.gd` mutations.
- **Step 1 — Controls fix (`_handle_release`/`_tap`).** Replace the silent `selected = NONE` fall-through with the three feedback branches (§3). Add press-down shake when `_has_moves` is false. Add ghost-halo modulate for blocked-but-matching partners in `_refresh_highlights`. **Feel check:** no gesture produces a dead frame.
- **Step 2 — Graded slide + rush-together (`_commit`).** Distance-scaled duration + 60ms close-gap segment + rubber-band drag snap. **Feel check:** slides read as one physical event, short moves snappy, long moves weighty.
- **Step 3 — Audio autoload + 4 SFX.** Pooled `AudioStreamPlayer`; wire tink/glide/pop/chime into `_after_move`/`_commit`/`_flash`/`is_cleared`. **Feel check:** the loop is audibly satisfying with placeholder glassy samples.
- **Step 4 — Merge pop upgrade + MergeBurst particles + vacuum-shimmer.** Replace `_pop`, add `MergeBurst.tscn`. **Feel check:** the most-seen feedback feels crunchy-but-soft.
- **Step 5 — ZERO catharsis screen.** Replace the `main.gd:317` status string with the full sequence. **Feel check:** clearing a board is an event you want to clip.
- **Step 6 — Recolor + gloss + tier pips (`_tier_color`/`_make_piece`).** **Feel check:** pieces pop off the dark bg and stand out.
- **Step 7 — Pentatonic run + restrained showcase punctuation + haptics (Android first).** **Feel check:** a tidy clearing run feels like a wind-chime; hero moments feel premium.
- **Step 8 — Forgiving level gen.** Author the main track at the open end (≥8 free cells, sparse walls); move the L3/L4 strand puzzle to an Expert side-track. Add opt-in "Tidy." **Feel check:** you essentially can't strand yourself.
- **Step 9 — First additive element (Wild Gem) + coach-mark debut.** Then drip elements 2–7 per §5.
- **Step 10 — Atelier meta + next-beat preview + Daily Gift/Board.** Then the decoration layer, Weekly Theme, Season Ribbon.
- **Reallocation note:** the spec's two-engine A*/IDA* solver, stranded-state enumeration, and decision-recency grading are now **~80% unnecessary** under a forgiving core — reverse-construction guarantees solvable boards and a lightweight heuristic (tile count, families, board size, blocker density) replaces the difficulty score. **Redirect that engineering budget to the juice build, the additive-element system, and the modular cosmetic-VFX pipeline** (the true content treadmill, ~50 premium assets/quarter — the real ongoing cost and where the moat now lives).

## 8. Honest risks of the "embrace the clone, win on juice/content" bet

- **Low-differentiation churn.** Remove the spatial mechanic AND under-deliver juice → we become a forgettable 2048-clone that dies. *Mitigation:* juice quality is now **existential, not optional**; gate it on a measurable "satisfying/premium top-2-box >70%" KPI; lead with the ZERO/showcase hero beat as the one genuine differentiator.
- **CPI / discovery.** "Empty the board" is harder to convey thumb-stopping in 6s than a match-3 explosion, and it gets harder with the mechanic de-emphasized. *Mitigation:* build the ZERO "poof" to clip-worthy standard early and **IPM-hard-gate ad creative** on it before scaling spend.
- **Content-treadmill / art budget.** The moat and the whole ongoing cost shift entirely to the cosmetic-VFX + additive-element pipeline. *Mitigation:* build the **parametric/modular shader+palette rig** and procedural daily boards so variety is sub-linear in art cost; budget the tech-artist/VFX headcount as the **primary LiveOps line item**.
- **Sameness vs entrenched incumbents.** We compete on Royal Match / Homescapes turf with smaller budgets, forfeiting mechanical-moat defensibility. *Mitigation:* accept it (per pivot); win on **feel + the legible ZERO fantasy + drip cadence + the async-shareable ZERO clip / Atelier tour** for organic UA, not on out-volume-ing them.
- **"No game" risk from over-forgiveness + monetization softness.** If any tap order wins, the puzzle minority and word-of-mouth driver evaporate; and a no-fail/no-pressure loop suppresses loss- and social-pressure monetization. *Mitigation:* keep the thin optional efficiency crest + Expert track; lean ARPU on **subscription + cosmetic visibility**, and give cosmetics an audience via shareable Atelier tours / ZERO clips. Keep auto-help bounded (auto-route the slide, but the **player still chooses every pair**) so the dopamine stays earned.
