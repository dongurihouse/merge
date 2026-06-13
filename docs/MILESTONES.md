# Tidy Up — v1 Milestone Plan

> **Status:** For owner approval, generated 2026-06-08 by a 7-agent planning panel
> (3 independent planners → 3 adversarial reviewers → 1 synthesis lead).
> Source of truth for *what* to build: [TIDY_UP_V2_SPEC.md](TIDY_UP_V2_SPEC.md). This is the *order*. (This plan predates v2; the v1 spec it was written against is in [archive/](archive/TIDY_UP_SPEC.md).)
> The merge verb, `board.gd` rules engine, and the already-built board/menu/room/bitmap-font/juice
> are **DONE and FROZEN** — milestones build *around* them, never rebuild them.

---

## 🔄 REVISION — simplified core + progress (2026-06-08)

After a playtest the core changed from adjacency+sliding to **drag-any-to-any merge** (drop a piece on any matching item → merge; see TIDY_UP_SPEC "CORE MECHANIC — REVISED"). This **reshapes the plan below** — read this first; it overrides the original where they differ.

**Dissolved risks:** **R1** (relax-vs-homework) and **R2** (intractable solver) are gone — the simple core isn't a puzzle, and any board with even counts per type clears trivially, so there's no solver/generator/par-difficulty risk. Board-ceiling and free-cell concerns are moot.

**Already DONE since this plan was written:**
- ✅ **M1 — Save foundation** built (TDD, 15 tests) and **merged to `main`**. (The rest of M1's owners — FX, i18n, EconConfig, Settings — are still pending as their own sub-plans.)
- ✅ **Core Rework Phase 1** (branch `core-rework`): drag-any-to-any merge + match-highlights · dynamic cell-sizing (bigger boards fit portrait) · the **Locked Drawer** friction (renders + pops on adjacent merge) · amped tier-scaled juice · a cute rounded **tintable UI font**. Desktop feel-check passed — *bigger + variety + juice reads as satisfying, not mindless.*

**New milestone — "Core & Friction"** (replaces the old sliding board and most of spec §3.C levels):
- **Phase 1 — done** (above).
- **Phase 2 — next:** the other two v1 frictions — **Job Ticket** (per-board goal; *is* the clients/jobs meta object) and **Fill the Shelf** (counted put-away destination; previews the decoration meta). Backlog frictions (Dust Cover, Tangle, Conveyor, Big Toys…) drip in later per district.

**Adjusted milestones:**
- **M2 (R1 playtest)** → reframed to *"is the simple core + friction + juice satisfying?"* — **desktop-validated by the Phase-1 feel-check**; just confirm on device. No longer gates the economy on a puzzle-difficulty question.
- **M6 (levels)** → drastically simpler: hand-author boards with even counts per type (always clearable) + a drip of friction mechanics. **No solver, no solver-par.** The **friction mechanics are the level-design language** — each new one is a district's content.
- **M3 Celebrate · M4 Economy · M5 Room/Reveal · M7 Districts · M8 Quests · M9 Audio · M10 FTUE · M11 Shop** — unchanged in role (all mechanic-agnostic). M5's thin level slice now uses drag-any-to-any + Drawer/Ticket/Shelf.

**Updated build order:** M1 Save ✅ → **Core&Friction Ph1 ✅** → **Core&Friction Ph2 (Ticket+Shelf)** → finish M1 owners (FX/i18n/EconConfig) → M4 Economy + M5 Room/Reveal (the earned-reveal MLP) → M6 content → M7 districts → M8 quests → M9 audio → M10 FTUE → M11 shop.

> The original 11-milestone plan below remains the reference for the *mechanic-agnostic* systems (their goals/exit-criteria still hold); apply the deltas above.

---

# Tidy Up — v1 Milestone Plan (Lead Planner, final for owner approval)

## 1. Overview

The single emotional target of v1 is **"the player reaches their first room reveal feeling *earned*."** Everything is sequenced to reach that as early as is responsible, then layer breadth on a loop that already works. The critical path is: **Foundations & Owners** (the 3 autoloads + static helpers + i18n + Save-with-migration, since the spec's #1 stated failure mode is systems re-deriving shared primitives) → the **R1 relax-vs-homework playtest gate** (run on the *frozen* `board.gd` engine with throwaway boards, **before any economy number is frozen**) → the **Celebrate chain + interrupt invariant** (its own milestone — it is a rework of the binary `animating` flag and ~6 ad-hoc tweens, not a re-home) → the **core earn loop** (payout/coin-fly/count-up/banked wallet, **EconConfig numbers frozen here** now that R1 has reported) → the **room rewrite + art pipeline + first EARNED reveal** (the MLP target, funded by a *thin* level slice on a flat list). Only after the reveal works end-to-end on real coins do we layer **bulk content authoring, the Districts/Jobs map, Quests, Audio, and FTUE/MSB/accessibility**. The reveal **never depends on Quests** (quests narrate the loop; they do not produce it). Audio is wired late and degrades to visual-only, so it never gates the MLP on owner-generated `.wav`/`.ogg` files. The frozen engine/board/menu/room/bitmap-font and the half-built juice (`_burst`/`_flash`/`_pop`/`_shake`/`_add_ring`, merge pop, particles, `_play_zero` ZERO screen, landing rings) are built *around*, never rebuilt.

## 2. Milestone table

| # | Milestone | Goal | Rough size | Depends on |
|---|---|---|---|---|
| **M1** | Foundations & Owners | The single shared-primitive layer (Save→FX→helpers), i18n, stable IDs, EconConfig file (placeholder numbers) — nothing downstream re-derives a primitive. | L | — |
| **M2** | R1 relax-vs-homework playtest **GATE** | Validate larger boards feel relaxing, not homework, on the frozen engine — **before** economy numbers freeze and before bulk authoring. | S | M1 |
| **M3** | Celebrate chain + interrupt invariant | `_play_zero`→`Celebrate.chain_level_clear` as the sole post-clear orchestrator; any tap fast-forwards to end-state in one frame. | L | M1 |
| **M4** | Core earn loop + EconConfig **freeze** | A cleared board pays real Coins that fly to a real, banked wallet; replay flags correct; debug grant/reset menu. **Numbers frozen here** (post-R1). | M | M2, M3 |
| **M5** | Room rewrite + art pipeline + **first EARNED reveal (MLP TARGET)** | Per-slot decor model + the ~17 R6 assets; spend earned coins on 4 slots → the XL Room Complete reveal, on a thin flat level slice. | L | M4 |
| **M6** | Bulk content authoring (~30 levels) | Hand-author the full size/difficulty curve on the R1-validated ceiling, tuned against the frozen economy. | XL | M2, M4 |
| **M7** | Story spine + Jobs/Map nav + client lump | Wrap levels in Districts→Clients→Jobs; the one nav topology; double-door unlock; the directed +150 client lump that auto-funds a slot. | L | M5, M6 |
| **M8** | Quests (event bus + one carrot) | Session micro-chips + merged Daily bundle + story-spine lines + silent milestone counters; one `next_beat()` carrot. | M | M5, M7 |
| **M9** | Audio wiring + remaining core juice | The 3 music beds + ~6 new SFX (graceful-degrade if absent) + the handful of core juice not yet wired. | M | M5, M8 |
| **M10** | FTUE + staged unlocks + MSB + accessibility ship | Beats A–E one verb at a time, `seen_`-flag staged unlocks, MSB cap, Settings/Calm Mode, corruption-recovery flow — the integration/QA close. | L | M7, M8, M9 |
| **M11** | (cuttable) Cosmetic shop + boosters | Flat coin shop + 2 earned boosters + the Tip-Jar ad placement built dark. Explicitly slip-able without touching the MLP. | S | M4, M10 |

## 3. Milestones in detail

### M1 — Foundations & Owners *(L)*
**Goal:** Stand up the single-owner shared-primitive layer so no later system re-derives persistence, FX, or strings. Internal build order is strict: **Save (corruption-tested) → FX (absorbs R8/R9 + colorblind shape redundancy) → Audio static → Celebrate/Quests/Economy/Meta static helpers over them.** No consumer is sequenced before its owner.

**In scope**
- **Save autoload first** (the catastrophic R5 surface): versioned JSON (`schema_version=2`), `DEFAULT_SAVE` deep-merge, atomic `.tmp`→verify→rename + `.bak` + crc, debounced 2s write + forced flush on `APPLICATION_PAUSED`/`WM_CLOSE_REQUEST` + after every reward grant. `migrate_1_to_2`: read old `progress.cfg cleared` int → `stats.boards_cleared`, **seed coins ONCE** (`cleared × 35`) behind the `migrated_v2` guard. `progress.gd` becomes a **read-only shim immediately** (no double-write); repoint `main.gd`/`room.gd` reads.
- **Stable string `id` on every level** in `levels.gd`; `main.gd` keeps the internal index but records persist by `id`; map the 6 existing levels so testers keep records.
- **FX autoload**: persistent `FXLayer` CanvasLayer (128, `PRESET_FULL_RECT`, safe-area aware — R9), the full public API (`go/toast/shake/burst/flash/pop/fly/ticker/haptic`), the ONE canonical haptic table, node-bound looping tweens (R8), particle ceiling, and the **colorblind ring shape-redundancy (green=solid / blue=dashed) owned here from day one** so early board screens never render hue-only rings that must be retrofitted. Re-home the existing `_burst`/`_flash`/`_pop`/`_shake`/`_add_ring` behind this API — do **not** rebuild them.
- **i18n architecture** (owner launch-priority): register translation tables + `locale="en"`; route **all** user-facing strings through `tr()` + placeholder templates; the status line becomes a `tr()` template with placeholders, never glued fragments; locale-aware number formatting helper. Document the per-locale font path (extend the bitmap atlas glyphs vs system-font fallback). English ships; architecture is locale-ready.
- **EconConfig file exists** as the canonical numbers home (pure funcs stubbed with **placeholder** anchors). **No number is frozen here.**
- Settings owner + Calm Mode keys reachable from first launch (accessibility), OR-ed with OS reduce-motion at boot.

**Exit criteria (testable)**
- Boot creates/loads a save and round-trips; the 3 owners (Save/FX/Audio) are the **only** autoloads.
- **Migration gated:** `migrate_1_to_2` round-trips correctly on the existing 6-level `progress.cfg` (coins seeded exactly once; re-running does not double-grant); `progress.gd` is read-only and writes nothing. *This is a hard gate before any later milestone writes a record through Save.*
- Adversarial Save passes fault injection: kill-mid-write, truncated file, old-schema file each degrade gracefully (bak-restore or fresh-start), never "class load failed."
- A string audit shows **zero** hardcoded/concatenated display strings (known offenders: the `"%d moves…"` status line, `room.gd` labels, title/hint). One-paragraph per-locale font path documented.
- The frozen board renders rings with shape redundancy (green solid / blue dashed); existing juice helpers still fire through the FX API.

**Risks/notes:** This is the largest first deliverable; build it in the Save→FX→helpers sub-order so verification checkpoints land incrementally. `EconConfig` exists but is explicitly provisional until R1 (M2) reports.

### M2 — R1 relax-vs-homework playtest **GATE** *(S)*
**Goal:** Retire the highest-strategic-risk unknown cheaply: do larger boards read as relaxing, not homework? **This is exactly where R1 sits — immediately after the owners land, on the *frozen* `board.gd` engine, and BEFORE any economy number is frozen (M4) and before bulk authoring (M6).** It has near-zero new code and zero new art.

**In scope**
- Hand-author throwaway test boards: several **5×6 @ ~50% density** (and a couple of 6×7 "big job" candidates), honoring the ≥ `max(2, round(0.25×pieces))` free-cell floor, hand-typed par. No solver, no generator (R2 — intractable on device).
- Run the playtest (owner + a few testers): measure solve time and the subjective relax-vs-work read. Budget a **feedback loop** — if it reads as homework, re-author and re-test, not one-shot.

**Exit criteria (testable)**
- A recorded **board-ceiling verdict**: 5×6 stays / drops to 5×5 / 6×7 approved; free-cell floor adjusted if needed; a measured solve-time band.
- The verdict is written down as the hard input to M4's economy freeze and M6's authoring curve.

**Risks/notes:** A "homework" verdict is explicitly **allowed to shrink v1 scope** (lower ceiling, raise free-cell floor, fewer/easier boards) — it must never expand it. This protects the MLP timeline. Gating R1 behind nav/room/economy would defeat the point of front-loading it.

### M3 — Celebrate chain + interrupt invariant *(L)*
**Goal:** Build the sole post-clear orchestrator and the HARD interrupt invariant, so the reveal (M5) and every later L/XL beat route through one queue. This is its **own L milestone** because it is a genuine state-machine rework, not a re-home.

**In scope**
- Refactor `_play_zero` into `Celebrate.chain_level_clear(stars, coins, rewards)` with chain steps (board showcase → star pop → coin count-up → coin-fly → reward line → tap-to-continue) registered into the `CelebrationQueue` (≤1 modal).
- **Interrupt invariant (HARD, tested):** any tap fast-forwards all pending celebration/showcase tweens to end-state, safely completes the pending board mutation + `_rebuild_pieces`, returns control within one frame. Rework the binary `animating` flag so only the brief rules-mutating slide is guarded; showcase/celebration are interruptible.
- One refcounted time-scale (`time_dip`) owner; render **only earned stars** (chill guard) — missed stars not shown on the default screen.
- Celebrate calls Audio cues that **no-op when the file is absent** (audio wired in M9).
- **Decision gate (spec footnote 1):** evaluate the `_rebuild_pieces` node-capture dependency for the two-body merge press / undo slide-back. **If non-trivial, degrade to the single-result pop and flag** — do not let it balloon this milestone.

**Exit criteria (testable)**
- A board clear runs entirely through `chain_level_clear`; tapping at any point during the chain jumps to end-state within one frame with the board mutation safely committed.
- Overlapping L/XL beats never double-dip time-scale; default win screen shows only earned stars.
- The `_rebuild_pieces` decision is recorded (full two-body press, or degraded-to-pop + flagged).

**Risks/notes:** Sequenced after FX (M1), before the reveal (M5), so the reveal genuinely routes through real orchestration machinery (fixes the Draft-3 backward dependency). It does **not** depend on, and is not bundled with, the economy freeze.

### M4 — Core earn loop + EconConfig **freeze** *(M)*
**Goal:** A cleared board pays real, persistent Coins that fly to a banked wallet — and the economy numbers are frozen now that R1 has reported.

**In scope**
- Wire `EconConfig.job_payout` (35 + ★★/★★★ bonuses) through the M3 chain; coin-fly + count-up + banked-wallet via `FX.fly`/`FX.ticker`, fired after `Save.add_currency` commits.
- **Replay/first-clear correctness:** `first_clear_paid` + `best_stars` flags so coins can't be farmed into a fake reveal (full first clear; flat replay trickle; one-time star delta).
- **FREEZE EconConfig numbers** here, calibrated toward the owner's faster/instant-gratification pacing (first reveal ~session 4; fine-tune later). All numbers in the one file.
- **Debug grant/reset menu** (R4 mitigation) ships here — load-bearing so M5/M6 can build and tune the room/levels before the full content set exists.

**Exit criteria (testable)**
- Clearing a board grants the correct coins, banks them through Save, and animates the fly+count-up; re-clears pay only the flat trickle; beating a new star tier pays the one-time delta.
- **EconConfig numbers are frozen, and the freeze is timestamped after the recorded R1 verdict** (provisional-until-R1 status closed).
- Debug menu can grant/reset coins and job records for tuning.

**Risks/notes:** No districts/quests/audio here — strictly the faucet + wallet. The "renovate-to-advance" half of the double-door is dark until M7 (only "clear jobs" exists); acceptable for the single-room slice.

### M5 — Room rewrite + art pipeline + **first EARNED reveal (MLP TARGET)** *(L)*
**Goal:** Reach the single emotional target — spend *earned* coins on the room slot-by-slot and trigger the **Room Complete reveal feeling earned.** R6 (the real schedule critical path) is retired *inside* this milestone, art-pipeline-first.

**In scope**
- **Room rewrite (not a "generalization"):** replace the global-int two-PNG `messy→tidy` crossfade with the per-slot model: `bg_base` + N transparent overlay PNGs; `Save.rooms = {room_id:{unlocked, decor:{slot_id:item_id}, completion}}` + `Save.decor_owned`. One room (bedroom), **6 slots, `required_slots=4`, 0 variants.**
- **Art-pipeline-first:** generate the ~17 R6 bedroom overlays via the LLM pipeline and import them as the FIRST task, pricing real per-asset cost/consistency with maximum runway.
- Per-slot fade (~0.5s, reuse the frozen showcase sparkle rig + `furniture_place` thunk + `MED` haptic); warm-light overlay alpha ramps with `filled/required`; on the 4th required slot → the **XL Room Complete reveal** through `Celebrate` (slow pan, lights-on, gold confetti, `STRONG` haptic, Wren one-liner). The reveal ships **visual-only**; `room_complete.wav` is wired in M9.
- **Thin level slice (~8–12 levels, flat list)** authored here purely to *fund* the 4 slots on real earned coins — not the full curve. No districts/map yet.

**Exit criteria (testable)**
- Playing the thin slice earns enough coins to buy 4 slots and trigger the Room Complete reveal **end-to-end on real earned coins** (not a debug grant), from data that survives save/reload.
- The art pipeline is proven and the real asset count/cost is known; R6 retired.
- The reveal works silently (no missing-asset stall).

**Risks/notes:** The room rewrite + art pipeline are the two genuine XL-risk traps here; keeping bulk authoring out (M6) keeps this milestone shippable. **The reveal must not depend on Quests** — its only prerequisites are M4 (earn→spend) + M3 (Celebrate XL chain) + the decor data model + (later) the audio cue.

### M6 — Bulk content authoring (~30 levels) *(XL)*
**Goal:** Author the full v1 level set across the R1-validated curve, tuned against the now-frozen economy.

**In scope**
- ~30 hand-authored levels: 3×3 → the R1 ceiling, 1→3 families (the only families on disk), top tier 1→5, sparse walls, Wild toy only. Hand/construction par. No generator, no solver (R2).
- Par-tune and playtest against the live frozen economy so the 4 required slots complete in ~6 sessions, using the M4 debug menu.

**Exit criteria (testable)**
- ~30 levels exist on the validated curve with stable `id`s and tuned par; a fresh save can play the curve and reach the reveal within the worked ledger band.

**Risks/notes:** This is the true content critical path and is XL — isolating it (rather than burying ~30 levels inside the reveal milestone) keeps the MLP off the bulk-authoring path. Can run in parallel with M5's reveal wiring once M4 freezes numbers.

### M7 — Story spine + Jobs/Map nav + client lump *(L)*
**Goal:** Wrap the linear levels in the Districts→Clients→Jobs frame so the loop has a narrative rail and a real navigation topology.

**In scope**
- The Districts→Clients→Jobs structure: **3 districts = the 3 existing families** (Clothes→Books→Toys), one family debuting per district.
- The one nav topology (Home/Hub + bottom tabs + modal BOARD push), all swaps via `FX.go(SOFT_FADE)`.
- The **double-door** unlock (renovate-room OR clear-most-jobs — the can't-lose gate); the directed **+150 client lump** that auto-funds ~1 slot during a text-only client-thanks beat (Wren bust + one-line thank-yous; no per-client portraits).

**Exit criteria (testable)**
- A player navigates Hub→Jobs→board→back; completing a client fires the thank-you beat and the +150 lump visibly builds a slot; the double-door advances on either condition.

**Risks/notes:** Deferred past the reveal deliberately — the first reveal lives on a flat list and does not need the map.

### M8 — Quests (event bus + one carrot) *(M)*
**Goal:** Add the quest layers that drive the 3rd/4th job and the return habit — strictly narration over a working loop.

**In scope**
- `Quests.notify` at the 4 `main.gd` sites; **committed-only ticks** (undo-safe via committed board delta); one matcher predicate.
- Layer 1 session micro-chips (×3, one reroll); Layer 2 merged Daily bundle (3 quests + 7-day gift + streak flame, claimed together, **dims-never-dies**, 04:00 rollover); Layer 3 story-spine Wren lines (≤14 words, skippable); Layer 4 milestone counters accrue **silently** (no UI).
- **ONE CARROT:** `Quests.next_beat()` shows exactly one next-beat card on every win/quit (priority decor>quest>story>streak).

**Exit criteria (testable)**
- Ignoring all quest UI still completes quests by playing; exactly one next-beat card ever shows; undo never desyncs quest progress from coins; the streak number never decreases on screen.

**Risks/notes:** Sequenced strictly **after** the reveal (M5) and the map (M7). The reveal must never depend on this milestone.

### M9 — Audio wiring + remaining core juice *(M)*
**Goal:** Bring the cozy sonic identity online and finish the few core juice beats not yet wired — without ever having gated the loop on assets.

**In scope**
- Wire the owner-generated **3 music beds** (`music_menu/play/room.ogg`) + **~6 new SFX** (`item_slide`, `coin_earn`, `star_pop`, `quest_complete`, `unlock`, `undo`, `room_complete`) into `Audio`; per-screen 600ms crossfade; pitch via existing `clampf`; Music ON by default + first-run "sound on?" prompt.
- Wire `room_complete.wav` into the M5 reveal (was visual-only).
- Complete the handful of remaining **core**-tagged juice (any not folded into M3/M5): next-beat card breathe, SOFT_FADE everywhere, toasts, button spring.

**Exit criteria (testable)**
- Music + all new SFX play on-identity behind toggles; if any asset file is absent, the beat degrades to visual-only with no stall (the room reveal already shipped silent-capable in M5); core juice beats are present and interruptible; no `nice`/`lux` item is load-bearing.

**Risks/notes:** Owner asset generation is an explicit **parallel track** that must complete before this milestone's *exit*, not its *start*. Late assets never block the loop. `nice`/`lux` juice (combo ladder, streak ribbon, dissolve/iris/morph shaders, ambient life) is a **backlog, not a milestone** — cuttable wholesale.

### M10 — FTUE + staged unlocks + MSB + accessibility ship *(L)*
**Goal:** Onboard a brand-new player one verb at a time and validate the whole accumulated surface against a fresh save — this is an integration/QA milestone, not just coach marks.

**In scope**
- FTUE beats A–E (wordless, can't-fail, one new thing at a time) + staged `seen_`-flag unlocks (coin counter→C, decorate→D, quests/chips→E, daily bundle→session 2, daily job→after job 4, star goals→after job 6).
- **MSB enforcement:** Hub shows at most the Coin counter, ONE next-beat card, Take-a-Job CTA, one "⊕ N rewards" badge, settings gear; everything else one tap deeper; HUD elements render only when their flag flips.
- Settings + Calm Mode from first launch; colorblind redundancy (already in FX); big-text; lefty mirror; corruption-recovery player flow ("We restored your last save" / fresh-start apology gift). First-run zero-states.

**Exit criteria (testable)**
- A fresh save walks A→E learning one verb; HUD elements appear only as `seen_` flags flip; the Hub never exceeds the MSB cap; Calm Mode + accessibility toggles work from launch; corruption recovery + apology gift verified; the full surface re-validated against the 6-session ledger.

**Risks/notes:** Easy to under-size — it re-tests the entire stack on a brand-new save. Genuinely part of the MLP (a first-timer must learn the loop and reach the reveal).

### M11 — (cuttable) Cosmetic shop + boosters *(S)*
**Goal:** Close the remaining v1 economy sinks. Explicitly slip-able without touching the MLP.

**In scope:** flat coin-priced rotating cosmetic shop (**no gacha**); 2 **earned-only** boosters (Hint, Undo-burst; using one never forfeits a star); the single Tip-Jar ad **placement built but dark** (no monetization in v1).

**Exit criteria:** shop and boosters purchasable with earned coins; no IAP/ads active; booster runs silently skip the ★★★ best-record without loss messaging.

**Risks/notes:** None of this is needed to feel the earned reveal — it can slip to the very end or to a v1.x patch.

## 4. Explicitly deferred to v2+/later

**No monetization** — no IAP, no ads (Tip-Jar placement built dark, `gems_enabled=false`, no gem→coin, no Founder's Crate); helpers **earned-only** in v1 (special-items design built so monetization can switch on in v2+). **Business multipliers / Tidy Co. / all idle/offline income.** **Runtime solver/generator, offline reverse-construction baker, endless jobs, Expert track.** **6×7 ceiling** (only if R1 passes — a v2 follow). **Stars as spendable** (prestige + coin-bonus only in v1). **Milestone/trophy-wall UI** (counters accrue silently now). **Districts 4–5 (Plants/Kitchenware), more rooms, style variants, per-client portraits.** **AudioDirector promotion + lux audio** (pentatonic combo ladder, key-of-C constraint, bus ducking, density limiter, layered fanfare stems). **All lux juice** (dissolve/iris/morph shaders, ambient pet, tilt parallax, time-of-day, seasons, photo/admire mode, XL rank-up/milestone fanfares, combo pitch-ladder + streak ribbon — `nice`/`lux` is a backlog, not a milestone). **Cloud-save merge + analytics pipeline.** **Local re-engagement notifications** (in-app next-beat only). **Core Haptics plugin** (`vibrate_handheld` only). **Permanently cut (pillar/tone):** booster-forfeits-star, gacha Mystery Crate, and the Bomb/×2/Producer/Countdown toys (only Wild ships).

## 5. Definition of done for v1

A brand-new player, on a fresh save, learns the merge verb wordlessly, clears authored jobs to earn real banked Coins, spends them to decorate the bedroom slot-by-slot, and reaches the **Room Complete reveal feeling they earned it** — on frozen economy numbers validated by the R1 playtest, with corruption-safe save, all strings via `tr()`, Calm Mode from launch, and audio that degrades gracefully — with no v2/lux scope shipped.

---

*Plan synthesized from 3 independent drafts (8/12/6 milestones each), hardened against 22 problems raised by 3 adversarial reviewers (sequencing · scope discipline · solo-dev feasibility).*
