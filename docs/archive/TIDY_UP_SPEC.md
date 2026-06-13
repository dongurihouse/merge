# Tidy Up — Game Design Spec (Progression, Meta & Juice)

> **Status:** Owner-approval draft (v0.1), generated 2026-06-08 by a 19-agent design panel
> (12 designers → 5 adversarial reviewers → 2 synthesis leads; ~1.46M tokens).
> The merge verb and `board.gd` rules engine are **LOCKED and FROZEN** — nothing here touches them.

## Locked decisions (owner, 2026-06-08)

| Decision | Choice |
|---|---|
| **Meta frame** | Professional tidier → earn money → **fund & decorate your own home** (Gardenscapes-style solve→earn→renovate) |
| **Money sinks (all 4)** | Home decoration · Business upgrades · Unlock clients/locations · Cosmetics & earned boosters |
| **Quests (all 4 layers)** | Per-session micro-goals · Daily + streak · Job/story chain (spine) · Milestone/collection |
| **Difficulty** | Keep **can't-lose** core + **optional star goals** (move-par soft target → bonus stars/coins; never blocks) |

This document is the END-STATE design. **Milestones are defined separately, after approval.**
Features are tagged `[v1]` / `[v2]` / `[later]` inline so milestone-planning is mechanical.

## Open-question resolutions (owner review, 2026-06-08)

These override the original §6 answers where they differ:

1. **R1 playtest — APPROVED.** Validate relax-vs-homework on the larger boards *before* freezing economy numbers.
2. **Board ceiling — GO BIGGER.** Raise to **6×7, with headroom for larger "big job" boards.** Feasible because levels are hand-authored (the solver is only intractable as an *auto-checker*; a hand-built board is solvable by construction at any size). Keep the ~25% free-cell floor; R1 is the feel-gate. Bigger boards = longer solves ⇒ pay more coins/job to hold coins-per-session steady.
3. **Stars — prestige in v1, but spendable RESERVED for the future.** Future star-spending allowed *only on optional/bonus sinks* (cosmetics, a bonus decor track), **never gating the core solve→earn→renovate path** (that would break can't-lose). Save already stores star records.
4. **Idle income — CUT from v1** (business upgrades → v2). Confirmed.
5. **Milestones — counters accrue from v1 launch (silent); Trophy/Collections UI → v2.** Deferring the UI loses no progress; players get full retroactive credit when it ships.
6. **Audio — owner generates from prompts.** See `AUDIO_PROMPTS.md` (3 music beds + 7 new SFX cues, cozy identity). Wiring is an audio milestone.
7. **Content hierarchy (defines "District"):** `TOWN → DISTRICT → CLIENT → JOB (board)`, with **YOUR HOME (Rooms → Decor Slots)** as a parallel reward track funded by Coins. **District** = themed neighborhood/biome + a signature item family that debuts there + a band of the difficulty curve + several Clients + (usually) a new wordless toy; completing a district unlocks the next (the macro spine). **Client** = a household hiring you for a run of ~3–6 jobs + a narrative beat + a directed coin lump funding a chunk of your home. **Job** = one board. Town is the top container (nothing above it needed). v1 ships the **first 3 districts = the 3 existing families (Clothes→Books→Toys), one family debuting per district**; Plants/Kitchenware = districts 4–5 in a content update (~10 new assets each). Your home grows room-by-room (bedroom first).
8. **Difficulty & monetization stance:** late/bigger boards SHOULD be somewhat hard (more possibility space) — but **hard is a means, not the goal**: it creates organic desire for **special items (helpers)**, which are the **primary monetization lever**. Reconciled with the pillars: in a can't-lose game, helpers sell *convenience/speed, NOT victory* (so not pay-to-win); every board stays solvable free (unlimited undo/restart). **HARD LINE: difficulty must be *engaging*, never *engineered frustration* to force purchases.** Helpers stay zero-learning — intuitive one-tap conveniences (**Wild, Hint, Sweep, Shuffle, +Space**), NOT new board rules (that's why Bomb/Countdown remain cut). Helpers are EARNED (quests/dailies/district rewards) AND purchasable. This upgrades the panel's conservative "cosmetics + 1 ad" model: **special items become a core monetized category.** RESOLVED (owner): **v1 ships with NO monetization turned on** — no IAP, no ads. Helpers are **EARNED-only** in v1; the special-items design is still built so monetization can switch on in v2+ (prove the game free first).
9. **Operational answers (owner, 2026-06-08):** Coin pacing → **faster / instant gratification** (first room reveal ~session 4; fine-tune later). **Music ON** by default at first launch (with a first-run "sound on?" prompt). **Settings reachable from first launch** (accessibility). **Local notifications deferred** (in-app next-beat only for v1). Naming **"Jobs"** + **"Wren the owl"** narrator kept (fine-tune later).
10. **Internationalization — set up EARLY (owner priority):** route **all** user-facing strings through Godot's `tr()` + translation tables from the Foundations milestone; **no hardcoded or concatenated display strings** (e.g. the status line must be a `tr()` template with placeholders, not glued-together fragments — word order varies by language). **Font-coverage flag:** the cozy bitmap atlas has basic Latin + symbols only — accented Latin (most European languages) and non-Latin scripts are **not** in it. Plan: i18n architecture + string externalization now, **English at launch**, then per added locale either extend the atlas with the needed accented glyphs or fall back to a system font for that language. Also: locale-aware number formatting; RTL on the horizon.

## ⚠️ CORE MECHANIC — REVISED (owner, 2026-06-08, after playtest)

**Supersedes the original "adjacency + sliding" core.** Playtesters found the slide-through-empty-cells / blocked-path puzzle unintuitive ("people want to click, not solve a puzzle"). **NEW CORE: drag any two matching items from ANYWHERE on the board → they merge** up the tidy ladder. No sliding, no routing, no spatial puzzle.

**Consequences:** `board.gd`'s sliding/reachability/solver engine largely **retires** (the merge becomes a trivial rule); **Risk R1 (relax-vs-homework) and R2 (intractable solver) DISSOLVE**; level authoring/generation gets easy (any board with even counts per type is always clearable). The swipe-primary + drag hybrid input is replaced by simple drag-any-to-any. **Unchanged:** all meta (home/districts/clients/jobs), economy, quests, juice, progression, can't-lose, zero-learning, and the M1 Save foundation.

**Texture now comes from intuitive FRICTION MECHANICS** (visually obvious · chill · theme-fit · never a routing puzzle). Full menu + backlog in `FRICTION_MECHANICS.md`. **v1 ships THREE** (one per time-scale):
- **Locked Drawer / Toy-Box** (*adjacent-merge* trigger) — always-on pop-juice texture (the owner's seed).
- **Job Ticket** — session purpose; *is* the clients/jobs meta object (welds the board to the story spine).
- **Fill the Shelf** — a counted put-away destination; previews the decoration meta.

**Locked sub-decisions:** lock language = **adjacent-merge**; **NO living-home inflow in v1** (Conveyor deferred); **board-clear is ALWAYS the only win** — Ticket/Shelf/Floor goals are optional gravy (keeps can't-lose airtight). **Backlog for later districts:** Buttoned-Hamper (any-merge lock variant), Dust Cover, Spilled Pile, Tangle, Clear-the-Floor, Tidy Conveyor, Big Toys.

**Ripple:** this reshapes §3.C (Levels & Difficulty) and the input model; the milestone plan gains a **core-rework** step (drag-any-to-any + the 3 friction mechanics) that the playable loop builds on, and **R1's playtest reframes** from "is the puzzle relaxing?" to "is the simple core + friction satisfying, not mindless?".

---

# Tidy Up — Progression & Meta Expansion: End-State Design Spec

*Owner-approval draft. Engine: Godot 4.6.2, GDScript, portrait 1080×1920. Solo dev, LLM-generated art. The merge verb and `board.gd` rules engine are LOCKED and FROZEN — nothing here touches them.*

---

## 0. How to read this document (read this first)

The reviewers were unanimous on one thing: the draft was **seven parallel specs that re-derived the same primitives in conflicting ways** (five haptic helpers, four coin-fly effects, four save formats, contradictory coin numbers). This document fixes that by establishing **single ownership** up front. Two artifacts make this one game instead of seven:

1. **§3.0 Shared Primitives Ownership Table** — exactly one owner per shared concern. Every feature *calls* the owner; nothing re-implements.
2. **§3.E Screen Navigation Graph** — one topology every screen plugs into.

Three hard invariants override every other instinct in this doc:

- **MSB — Meta Surface Budget** (§3.D): a stated cap on how much meta is on screen at once. The relaxed audience must never open the app to a wall of tabs.
- **ONE CARROT** (§3.C): across all goal layers, the player is shown exactly one "next thing" at a time.
- **ECONCONFIG IS LAW** (§3.A): one file owns every coin number. No feature states its own numbers; all numbers below are canonical and derived from one anchor.

And one gating experiment precedes the lock (§6, Risk R1): **validate that the larger boards feel relaxing, not like homework**, before economy pacing is frozen.

---

## 1. Vision & the one-sentence fantasy

**You are a freelance professional tidier who tidies strangers' homes to slowly fund and decorate the dream home of your own.**

Every job is a board you clear; clearing pays Coins; Coins turn one bare room of *your* home, one cozy object at a time, into a place that glows. The core verb stays 2048-familiar on purpose — the moat is **feel + content + payoff**, not mechanical novelty. The single emotional product of v1 is **your first room reveal, earned**: everything else exists to get the player there feeling like they did it themselves.

---

## 2. The Core Loop

### 2.1 The macro loop (solve → earn → renovate → unlock → next)

```
        ┌──────────────────────────────────────────────────────────┐
        │                                                          │
        ▼                                                          │
   ACCEPT a JOB ──▶ SOLVE the board ──▶ "All tidy!" + PAYOUT ──▶ EARN Coins
   (1-tap card)     (can't-lose,         (one big exhale;          (fly to wallet,
                     unlimited undo)      stars = bonus)            count-up)
                                                                     │
                                                                     ▼
   NEXT JOB ◀── unlocks ◀── ROOM ZONE FILLS ◀── SPEND Coins on one decor SLOT
   (the spine        (room % rises;        (optional, opt-in;
    waits for you)    on 100% → REVEAL)     directed by story beats)
```

The loop is gated by a **double door** (preserves can't-lose): the next District opens when you **renovate the room it funds OR clear most of its jobs — whichever comes first.** A pure solver and a pure decorator both always advance; neither is ever walled by Coins or Stars.

### 2.2 The session loop (the 3–5 min heartbeat)

A session = **3–5 job loops + one spend/claim beat**, ending on a previewed carrot.

```
APP OPEN → (roll 3 session micro-goals) → JOB LOOP × 3-5 →
   each JOB LOOP: Accept(1 tap) → Solve → All-tidy payout card → quest ticks →
   [optional spend beat: "Place it" / "Claim", ≤2 taps] →
NEXT-BEAT PREVIEW CARD ("1 job to the new rug") → "Next job" or quietly exit.
```

**Session-budget rule:** never queue a *required* action chain longer than 2 taps after a win. Coins auto-bank, decoration is opt-in, quests auto-track. The player can close the app on any payout card and lose nothing.

---

## 3. Systems — integrated and reconciled

### 3.0 — Shared Primitives Ownership Table (the de-duplication law)

> This table resolves the reviewers' #1 blocker. Each primitive has **exactly one owner**. Every other system **consumes** the owner's API and must NOT define its own. Build the owners first.

| Primitive | Sole Owner | Public API (what everyone else calls) |
|---|---|---|
| **Persistence / save** | `Save` autoload | `Save.coins`, `Save.spend(n,reason)→bool`, `Save.record_job(...)`, `Save.flush()`, etc. (§3.F) |
| **Persistent FX layer** (shake, screen transitions, toasts, the layer that survives `change_scene_to_file`) | `FX` autoload (`FXLayer`, CanvasLayer 128) | `FX.go(scene,style)`, `FX.toast(...)`, `FX.shake(tier)` |
| **Tweens / easing / durations** | `FX` | `FX.appear/settle/fade/breathe`, `FX.DUR.*` |
| **Particles + global ceiling** | `FX` | `FX.burst(center,color,amt_tier)` (caps: ≤6 emitters, ≤120 particles, auto-downgrade) |
| **Flash / color-feedback vocab** | `FX` | `FX.flash(node, GOOD/GOLD/COOL/NUDGE/SOFT_NO)` |
| **Haptics** (ONE table, see below) | `FX` | `FX.haptic(LIGHT/SOFT/MED/STRONG)` |
| **Number ticker / count-up** | `FX` | `FX.ticker(label, from, to)` |
| **Coin-fly-to-wallet** | `FX` | `FX.coin_fly(origin, amount, target)` |
| **Beat grammar (S/M/L/XL) + post-clear chain + CelebrationQueue** | `Celebrate` (static helper over FX) | `Celebrate.beat(size,...)`, `Celebrate.chain_level_clear(stars,coins,rewards)`, `Celebrate.queue(callable)` |
| **Audio: buses, SFX pool, music beds, pitch** | `Audio` (static; promoted to `AudioDirector` only when music ships) | `Audio.play(name,db,pitch)`, `Audio.music(bed)` |
| **The "one carrot" computation** | `Quests` (static over Save) | `Quests.next_beat() → {label, icon, progress}` |
| **Economy numbers** | `EconConfig` (static, pure funcs) | `EconConfig.job_payout(...)`, `.task_cost(...)`, etc. |

**Canonical haptic table (the ONE that wins — reconciling the five conflicting versions):**

| Weight | ms | Used for |
|---|---|---|
| `LIGHT` | 10 | pickup, button press, tab switch, every ~5th ticker step |
| `SOFT` | 16 | normal merge, slide-stop, ticker landing |
| `MED` | 24 | top-tier merge, quest-complete, decor settle |
| `STRONG` | 40 | showcase + board-clear + room reveal |

iOS uses `Input.vibrate_handheld(ms)` for v1 (coarse, behind a settings toggle). Graded Core Haptics plugin is **deferred** (§4). All haptics gated by `Save.settings.haptics`.

**Autoload budget for v1: exactly THREE autoloads** — `Save`, `FX`, and `Audio` (Audio stays a static singleton; it's listed as an autoload-tier owner for clarity). `Celebrate`, `Quests`, `Economy`, `Meta` are **preload-static helpers** over `Save`/`FX`, matching the existing `Audio`/`Progress`/`Palette` convention. This honors the codebase's zero-autoload-until-now discipline.

---

### 3.A — Economy & Currencies

#### Currencies (v1 = ONE)

| Currency | v1? | Role |
|---|---|---|
| **Coins** 🪙 | **YES — the only currency** | Everything: renovation, business multipliers (deferred), unlocks, cosmetics, boosters |
| **Stars** ⭐ | YES, but **prestige display only — NOT spendable** | 0–3 per job; a record + a coin-bonus multiplier. **Never a renovation ticket, never gates anything.** (Resolves the can't-lose pillar risk every reviewer flagged.) |
| **Gems** 💎 | **NO — ship dark** (`gems_enabled=false`) | Reserved field only; no IAP, no conversion in v1 |
| **Boosters** | YES, minimal (Hint, Undo-burst) | Pure convenience, coins-or-ad. **Using one NEVER forfeits a star** (resolves the pressure leak — booster runs simply don't update the ★★★ *best* record, silently, with no loss messaging) |

#### EconConfig — the single source of truth (all numbers below are canonical)

Every facet cites these; none invents its own. Reconciles the 30-vs-40 base and 120-vs-320 anchor conflicts.

**The anchor:** a 5-min chill session = ~3–4 jobs + quest turn-ins → **~160 Coins / active session** (the locked midpoint between the two draft drafts).

**Faucet (Coins in):**

| Source | Coins | Cadence |
|---|---|---|
| Job first-clear | **35** | once per job |
| ★★ bonus (`drags ≤ par+2`) | +15 | once per job |
| ★★★ bonus (`drags ≤ par`) | +25 | once per job |
| Client-complete (finish a client's job run) | **+150**, *directed* (see below) | per client |
| Daily Job | 80 | 1/day |
| Session micro-goal (×3) | 15–30 each | per sitting |
| Daily bundle (3 quests + gift, merged surface) | 40–90 total | 1/day |
| Replay clear (flat trickle) | 5 × tier | soft cap 100/day |
| Replay — newly-beaten star tier | one-time star delta only | — |
| Rewarded "Tip Jar" ad | flat **20** | cap **3/day** (ONE ad placement in v1) |

> **Replay rule reconciled (resolves the delta-vs-flat conflict):** first clear pays full; re-clears pay the flat trickle up to 100/day; beating a *new* star tier additionally pays the one-time star delta. Wired via `Save`'s `first_clear_paid` + `best_stars` flags.

> **Directed story lumps (resolves "spine cannibalizes renovation"):** the +150 client-complete bonus does **not** drop into the free-coin pool. It auto-funds ~1 slot of the room that client unlocks, shown as the slot *building during the client-thanks beat*. The renovation payoff stays visible and the lump can't inflate free coins.

**Sinks (Coins out) — v1 priority order is RENOVATION FIRST:**

| Sink | v1? | Notes |
|---|---|---|
| (a) **Renovate your home** | **YES — the hero sink** | One room, 6 slots. Slot cost = `120 × 1.22^slot_index` → ~120…320 per slot. `required_slots = 4` (room reads "done" before all 6 are filled — protects art budget). ~4 required slots ≈ **~900 Coins ≈ ~6 sessions** to first reveal. |
| (b) **Business multipliers** | **DEFERRED to v2** (post-first-room) | No idle/Tip-Jar income in v1 (honors "No full idle"). v2 adds at most one *active-play* multiplier (Rates), unlocked only AFTER the first room reveal so it never competes for session-1 coins. |
| (c) **Unlock clients/districts** | YES (soft) | Double-door (renovate-room OR clear most jobs). No coin cost in v1 — completion-gated only, keeping the loop clean. |
| (d) **Cosmetics & boosters** | YES, minimal | Flat coin-priced rotating cosmetic shop (**NO gacha** — randomized pulls are tonally wrong for cozy; reviewers unanimous). Boosters coins-or-ad. |

**Spend-sink balance & pacing (the worked first-6-sessions ledger):** at ~160/session, the first room's 4 required slots (~900) complete around **session 6** — landing the hero reveal squarely on the D3–D7 retention window. Daily-guaranteed faucets (daily job 80 + daily bundle ~65 + 3 ads ×20 + replay cap 100 ≈ **305/day max**) stay below one room's cost, so the renovation beat always rewards *real* play, never pure ad-grinding. Business multipliers (the only compounding sink) are gone from v1, so the two early sinks never collide.

**EconConfig pure funcs (one file = the whole balance sheet):**
`job_payout(tier, {first, par_met, clean})`, `task_cost(slot_index)`, `location_unlocked(loc)`, `replay_payout(job, new_best_stars)`, `daily_faucet_cap()`.

---

### 3.B — Quests (the four layers, reconciled to interlock)

One event bus, one persistence owner (`Save`), one carrot rule. **Guiding constraint: a player who ignores all quest UI completes every quest by just playing.** Quests narrate progress; they never assign work, never block, never expire harmfully.

**The event bus (the spine):** add `Quests.notify(event, data)` at four existing `main.gd` call sites (slide / merge / showcase / clear). `Quests` walks active objectives, increments matches, emits `objective_advanced` and `quest_completed`. **One matcher predicate** covers all layers (no per-quest code):
`{ event, count, filter:{tier_gte, fam, stars_gte, par_max, no_undo} }`.

**Undo-awareness (resolves the edge case):** `notify` fires only on **committed** outcomes. Board-clear is past the undo horizon. Merge/showcase ticks that get undone emit a compensating decrement, OR (simpler, chosen for v1) quest progress is computed from the *committed* board delta on clear, not per-merge — so undo can never desync quest progress from coins.

| Layer | v1? | What it is | How it interlocks |
|---|---|---|---|
| **1. Session micro-goals (×3)** | **YES** | Thin chip row on the HUD — the only quest layer visible during play. "Merge 12", "Make a showcase", "Clear in par". 1–3 boards each. 15–30 coins. One free reroll/session. | Per-sitting dopamine; reason to do the 3rd/4th job |
| **2. Daily bundle (merged)** | **YES** | ONE "Today" surface = 3 daily quests + the 7-day login gift + the streak flame, all claimed together. (Reviewers: merge to cut clock-count & card-stacking.) | The return habit |
| **3. Job / story spine** | **YES** | The ONLY ordered layer. Client → run of jobs → warm 1-line thank-you → directed coin lump → unlocks a room zone + next client. | The narrative rail; introduces families/districts wordlessly |
| **4. Milestones / collections** | **Counters accrue silently in v1; trophy-wall UI DEFERRED to v2** | Furniture sets, lifetime counters. | Long-arc pull; revealed later |

**Streak — ONE reconciled model (resolves the three conflicting versions):** the flame **dims but the number never decreases**. A missed day dims the flame visually; the streak count and any earned ladder rewards are never reduced. One free "rest" per week. No number ever goes down on screen. (Quests-halve / Retention-rewind / Save-reset-to-1 are all replaced by this.)

**ONE CARROT rule (the load-bearing cohesion mechanism):** every win screen and every quit shows exactly **one** next-beat card. `Quests.next_beat()` picks the single closest unfinished thing across all layers (priority: decor-within-1-job > quest-within-1-job > story-within-2-jobs > streak reminder). The player never sees four progress bars.

---

### 3.C — Levels & Difficulty

**v1 ships HAND-AUTHORED levels only. No runtime generator, no on-device solver.** (Empirically validated: `board.gd`'s BFS is intractable above ~10 cells — a trivially-solvable 5×5 took 7.6s to confirm. The "is_solvable is a cheap assertion" claim is false; `is_solvable` *is* the expensive search.)

**Size progression (gentle, one axis every ~3–5 levels; chill ceiling pending §6 R1 validation):**

| Axis | Start | v1 ceiling |
|---|---|---|
| Grid | 3×3 | **5×6 (30)** for the main track — *lowered from 6×7* pending the relax-vs-work playtest (R1). 6×7 only if R1 passes. |
| Fill density | ~25% | ~50% |
| Families on board | 1 | **3** (the only families that exist on disk) |
| Top tier | 1 | 5 |
| Walls | 0 | sparse (~10%) |

**Free-cell floor (chill guard):** every main-track board keeps ≥ `max(2, round(0.25 × pieces))` free cells — always room to route.

**Par (resolves the intractable-solver blocker):** **NO solver-optimal par.** Par for authored levels is **hand-typed** (as today) OR, for any future baked board, **derived from construction length** (the count of inverse moves used to build it = a known-achievable solve length, a valid par upper bound). The §3 "Challenge Score" drops the `log2(reachable_states)` term entirely in favor of the cheap heuristic (piece count, families, size, walls) — no BFS ever runs.

**Optional star goals (strictly bonus, never a gate):**

| Stars | Condition | Reward |
|---|---|---|
| ★ | cleared (always achievable) | base coins |
| ★★ | `drags ≤ par+2` | +15 coins |
| ★★★ | `drags ≤ par` (with generous slack so good-not-perfect players can reach it) | +25 coins + sparkle |

> **Chill guard on stars (resolves the catharsis report-card leak):** the default All-tidy screen celebrates **only earned stars** — missing/dim slots are NOT rendered unless the player opts into a "mastery" view or is replaying for the chase. Par/clean feedback lives on a quiet secondary line, never with loss framing, never red.

**Toy drip (resolves the zero-learning blocker):** new content is driven by **new families + new districts/art**, NOT new mechanics. Of the proposed toys, **only Wild (matches any family) ships** — it adds no temporal/spatial rule to learn. **Cut from v1 (and from the cozy main track permanently): Bomb, ×2, Producer, Countdown** — each is a new *rule* (Countdown imports time-pressure, a flat Pillar-3 violation). Crate may return later only as a purely cosmetic "wrapped gift" that any adjacent merge opens with no required count and no routing consequence.

**Daily Job:** a **curated rotation** of authored boards (reshuffled/mirrored/recolored for freshness) — NOT live generation. "Endless" jobs are a v2 feature gated on a working offline reverse-construction baker.

**Stable level IDs (prerequisite step 0):** add a string `id` field to every level in `levels.gd` NOW (e.g. `"bedroom_01"`); `main.gd` keeps using the index internally but records persist by `id`. Migration maps the 6 existing indexed levels to ids so testers keep records.

---

### 3.D — Meta / Home & Narrative

**The fiction (low-reading):** You're a freelance tidier. **Wren**, a warm owl dispatcher (fits the codebase's cozy-bird naming), texts you jobs in a 1–2 line chat strip (≤14 words, always skippable, never a blocking modal, lines never repeat). You tidy clients' homes, get paid, and renovate your own.

**v1 scope (drastically cut per art-budget reality — ~17 assets, not ~77):**
- **ONE room** (the existing bedroom), generalized from the single `messy→tidy` crossfade to a **per-slot decor model**: `bg_base` + N transparent overlay PNGs, each faded in over ~0.5s with a `FX.burst` sparkle (reuse the showcase rig) + `furniture_place` thunk + `MED` haptic.
- **6 slots, ZERO style variants, `required_slots=4`** so the room reads "done" before every overlay exists.
- **Room "lights up"**: one warm-light overlay whose alpha ramps with `filled/required`. On `required` reached → the **Room Complete reveal** (the v1 hero beat): slow pan, lights on, gold confetti, `room_complete_chime`, Wren: "It's really coming together!", `STRONG` haptic.
- **Narrative = Wren (one reusable bust) + text-only one-line client thank-yous.** No per-client portraits in v1.

**Districts/clients/biomes map:** the Districts→Clients→Jobs structure is the **v2+ frame**. v1 ships **3 districts mapping to the 3 existing families** (Clothes/Books/Toys) — reconciling palette.gd's 3 families and the "3 on board" cap. Plants/Kitchenware (fam 4/5) and their districts are **deferred** (each needs ~10 new tier assets).

**Decor data model (ONE shape — resolves the triple-ownership conflict):** `Save.rooms = { room_id: { unlocked, decor:{slot_id: item_id}, completion } }` + `Save.decor_owned`. The slot→item map (not a flat list) is canonical so future style-variants are representable. Meta, Quests-sets, and the renovation UI all read this one shape.

**Story spine = the gating ledger:**
```
clear Job → Coins → fill home Slot → 4 slots → Room renovated
   ▲                                               │
   └── next Client ◀── clear most jobs OR ──── unlock next District ── debuts new family
```

**Deferred lux (none load-bearing):** ambient pet, tilt parallax, time-of-day grade, seasons, photo/admire mode, world-map travel theater, recurring-client portrait roster, board re-skins. All cut from v1.

#### THE META SURFACE BUDGET (MSB) — a Pillar-3 invariant

> Resolves the "Homescapes economy in a cozy costume" major. Stated as a hard cap, not a per-system note.

**The persistent Home/Hub shows at most, simultaneously:**
1. the **Coin counter**,
2. **ONE** next-beat card,
3. the **"Take a Job ▶"** CTA,
4. a single decomposable **"⊕ N rewards waiting"** badge,
5. a settings gear.

**Everything else lives one tap deeper.** A new player's mental model for the first week is exactly: **tidy → coins → a thing for my room.** Staged unlocks (§3.G) enforce this — HUD elements don't render until their `seen_` flag flips.

---

### 3.E — Screen Navigation Graph (ONE topology)

> Resolves the "four different navigation idioms" minor. Locked model:

```
                    ┌─────────────┐
                    │  HOME / HUB  │  ← persistent base (your room)
                    │  + bottom    │     MSB applies here
                    │   tab bar    │
                    └──────┬───────┘
        ┌──────────┬───────┼────────┬───────────┐
        ▼          ▼       ▼        ▼           ▼
     [Home]    [Jobs/Map] [Shop]  [Today]    (gear)
     your      pick a job  flat   daily      Settings
     room      → pushes    coin   bundle
     +         BOARD modal shop   (quests+
     Renovate                     gift+streak)
     drawer
                    │
                    ▼  (job pin tapped)
              ┌───────────┐
              │   BOARD    │ ← modal push; on clear →
              │  (a job)   │   Celebrate.chain_level_clear →
              └───────────┘   payout card → next-beat → back to Hub/Jobs
```

All scene swaps go through **`FX.go(scene, style)`** (the one transition helper) — `SOFT_FADE` default, never a hard cut. v1 ships `SOFT_FADE` only; iris-wipe and shared-element morphs are deferred lux.

---

### 3.F — Save / Progress Architecture (the ONE persistence layer)

> Resolves the four-conflicting-save-formats blocker. **`Save` autoload, single versioned JSON, is THE persistence layer.** Every other system reads/writes through the `Save.*` facade — no system defines its own ConfigFile sections or its own autoload. The old `progress.gd` becomes a read-only shim immediately (can't double-write), then is deleted.

**Why JSON via `FileAccess` (not ConfigFile, not .tres):** human-readable for debugging, nests cleanly, language-neutral for a future cloud seam, and a corrupt/old file degrades to "fields missing" not "class load failed." Caveat handled: JSON numbers deserialize as float — the facade **coerces on read** (`int(data.coins)`).

**Files (all `user://`):** `save.json` (live), `save.bak` (last-good), `save.tmp` (atomic scratch).

**Atomic write + backup:** serialize → write `.tmp` → read back & verify parse + checksum → `rename(save.json→.bak)` then `rename(.tmp→save.json)` (rename is atomic on the local volume). Load tries `save.json`, then `save.bak`, then fresh-start. **Write cadence:** debounced 2s, plus forced on `NOTIFICATION_APPLICATION_PAUSED` / `WM_CLOSE_REQUEST` (critical on iOS) and explicitly after every reward grant.

**Versioning:** top-level `schema_version` (start at **2**; legacy `progress.cfg` = v1). `migrate_1_to_2`: read the old `cleared` int, set `stats.boards_cleared`, **seed coins ONCE** via `coins = cleared × 35` guarded by a `migrated_v2` flag, log a `currency_change{reason:"migration_seed"}` for audit. (Resolves the inconsistent-seed bug: ONE owner, ONE formula, ONE guard.) Defensive deep-merge over a `DEFAULT_SAVE` template means most additive changes need no migration code.

**Save schema (canonical, single source — every other system mirrors this):**
```jsonc
{
  "schema_version": 2, "migrated_v2": true,
  "rev": 0, "device_id": "<uuid>",          // reserved cloud seam (no cloud code in v1)
  "created_at": 0, "updated_at": 0, "crc": "<hash>",
  "currencies": { "coins": 0, "gems": 0, "gems_enabled": false },
  "boosters": { "hint": 0, "undo": 0 },
  "jobs": { "<job_id>": { "best_stars": 0, "best_drags": 0, "completed": false,
                          "plays": 0, "first_clear_paid": false } },
  "rooms": { "<room_id>": { "unlocked": true, "decor": { "<slot_id>": "<item_id>" },
                            "completion": 0.0 } },
  "decor_owned": { "<item_id>": true },
  "clients_unlocked": [ "<client_id>" ],
  "story": { "current_job_id": "", "jobs_completed": [], "seen_lines": [] },
  "quests": { "session": [ /*3 objectives*/ ],
              "daily": { "day_key": 0, "set": [ /*3*/ ], "gift_step": 0, "claimed": false },
              "milestones": { "<m_id>": { "progress": 0, "claimed": false } } },  // accrue, no UI v1
  "streak": { "count": 0, "best": 0, "last_day": 0, "rest_used_week": false },
  "settings": { "music": true, "sfx": true, "haptics": true, "reduce_motion": false,
                "colorblind": false, "big_text": false, "lefty": false, "notifs": false, "lang": "en" },
  "stats": { "boards_cleared": 0, "showcases": 0, "coins_earned_lifetime": 0,
             "sessions": 0, "undos": 0 },
  "flags": { "seen_coin_counter": false, "seen_decorate": false, "seen_quests": false,
             "seen_daily": false, "seen_star_goals": false, "onboarded": false }
}
```

**Settings = ONE owner, ONE key set (resolves the 4× toggle conflict):** all settings live in `save.json` under `settings`. ONE Settings screen (reachable via the gear, **available from first launch** for accessibility) owns the canonical keys with the defaults above, read once at boot and OR-ed with the OS reduce-motion flag. A single **"Calm Mode"** preset flips motion down / haptics off / no time-scale / no shake / gentle audio / optional-star UI hidden.

**Daily rollover (ONE rule):** fixed **04:00 local** `day_key = int((now - 4h)/86400)`. Times stored as UTC unix seconds; clock-jumped-backward is clamped (never grant), never locks the player out.

**Corruption player-flow (resolves the trust gap):** on bak-restore, surface "We restored your last save." On full fresh-start, a gentle non-blocking toast + a **one-time apology Coin gift** (fairness-positive). The room never shows a half-broken state — it renders from whatever `rooms` data survived.

**Deferred:** cloud-save merge (keep only the reserved `device_id`/`rev`/`updated_at` fields), analytics NDJSON pipeline. Local atomic save only for v1.

---

### 3.G — Retention & FTUE

**Celebration ownership (resolves the board-clear sequencing bug):** `Celebrate` is the **sole orchestrator** of the post-clear moment. `main.gd`'s `_play_zero` refactors to a single `Celebrate.chain_level_clear(stars, coins, rewards)` call. Board-Merge's showcase, the coin count-up, star fills, audio swell, and quest/economy event emits all **register as steps into the CelebrationQueue** (≤1 modal at a time) rather than tweening independently. One **time-scale owner** (refcount, mirroring the audio duck-owner) ensures overlapping L/XL beats never double-dip.

**Interrupt invariant (HARD, tested — resolves the `animating`-flag contradiction):** *any tap fast-forwards all pending celebration/showcase tweens to end-state, safely completes the pending board mutation + `_rebuild_pieces`, and returns control within one frame.* The existing `animating` flag is reworked so only the brief rules-mutating slide is guarded; showcase/celebration are interruptible. The relaxer is never trapped in confetti.

**FTUE beat sheet (wordless, can't-fail, one new thing at a time — the first 4 jobs):**

| Beat | Job | Teaches | Surface | Unlocks |
|---|---|---|---|---|
| A. Merge | L1 (1 move) | the verb | glow on the pair; coach "Flick them together" | first merge |
| B. Slide + clear | L2 (1 move) | slide→clear→win | reachable highlights; "All tidy!" | first clear |
| C. First earn | (B's payout) | clearing = money | coins fly into the **coin counter, animating in for the first time** (owned by `FX`, first-run enhanced) | first payout |
| D. First decoration | (Hub) | money buys home | auto-route to Bedroom; ONE affordable item glows "Place it" (priced at ~1 session of earn so it lands reliably) | first decor placed |
| E. First quest | (Hub) | the spine exists | quest banner + session-goal chips slide in | first quest seen |

After beat E (~3 min) the player has seen the entire loop having learned **one verb**.

**Staged system unlocks (MSB enforcement):** HUD elements literally don't render until their `seen_` flag flips. Coin counter → beat C. Decorate → beat D. Quests+chips → beat E. Daily bundle → session 2. Daily Job → after job 4. Star goals → after job 6 (framed as bonus). Business multipliers (v2) → after first room reveal.

**Return hooks (NO energy):** Daily Gift ladder (dims-never-dies streak), Daily Job (curated), Daily bundle, the story spine (waits, never walls). The Hub shows ONE decomposable "⊕ N rewards waiting" badge.

**First-run zero-states (resolves the missing empty-states):** empty wallet (shows "0", no fly), Jobs map with 1 district / 0 done, "never decorated" home = the existing messy bedroom (which IS the empty state). Charming empty states (sleeping cat for "all caught up") are nice-tier.

**Deferred:** local re-engagement notifications (needs a native shim, easiest thing to get guilt-baity) — v1 ships only the in-app next-beat preview.

**Accessibility:** Settings available from launch; Calm Mode preset; colorblind ring redundancy = **green merge ring is solid, blue reachable ring is dashed** (shape, not just hue) — owned by `FX`; big-text toggle (font system already scales); left-handed HUD mirror.

---

## 4. SCOPE TABLE

> Every notable feature tagged. **[v1] = the minimum lovable game. [v2] = fast-follow. [later] = horizon.** Honors the reviewers' cuts.

### The MINIMUM LOVABLE v1 (the spine — build these, ship when they're great)
The whole product is: **per-move + ZERO juice (already half-built) · ~30 hand-authored levels (no generator) · ONE Coin currency · ONE growing room with per-slot decor → a first room reveal · the coin-fly / count-up / next-beat-card loop · the 3 owners (Save, FX, Audio) + the 4 static helpers · FTUE beats A–E.** The single emotional target: **the player reaches their first room reveal feeling earned.**

| Area | [v1] | [v2] | [later] |
|---|---|---|---|
| **Owners/infra** | `Save` autoload (atomic JSON, migration) · `FX` autoload (shake/transition/toast/ticker/coin-fly/haptic/particle-ceiling/flash) · `Audio` static · `Celebrate`/`Quests`/`Economy`/`Meta` static helpers · stable level `id`s · `EconConfig` | `AudioDirector` promotion (music beds) | cloud-save merge · analytics pipeline |
| **Currency** | Coins only · Stars as prestige+coin-bonus (not spendable) · Gems dark | — | Gems + IAP · gem→coin |
| **Levels** | ~30 authored · hand/construction par · 5×6 ceiling (pending R1) · Wild toy only | 6×7 (if R1 passes) · offline reverse-construction baker · endless jobs · Expert track | richer toys (cosmetic Crate) |
| **Quests** | Session micro-chips · Daily bundle (merged) · Story spine · milestone counters (silent) | Milestone/trophy-wall UI · daily-quest tab | seasons/ribbon |
| **Economy sinks** | Renovation (hero) · completion-gated unlocks · flat cosmetic shop · 2 boosters | 1 active Rates multiplier (post-room) | more business lines |
| **Meta/Home** | 1 room, 6 slots, 4 required, 0 variants · room reveal · Wren bust + text clients · 3 districts=3 families | more rooms · style variants · client portraits · districts 4-5 (Plants/Kitchenware) | full city map · biomes |
| **Juice** | All **core**-tagged: tiered merge pop · two-body press¹ · showcase lift+bloom+rising motes · post-clear chain · star pop · coin fly+count-up · slot fill+reveal · room reveal · next-beat card · SOFT_FADE transitions · toasts · button spring · ticker · invalid soft-no | combo (if playtests want it) · iris-wipe · first-run variants per beat | shared-element morphs · dissolve/shine shaders · XL fanfares |
| **Audio** | 3 music loops (sourced from a pack) · ~6 new one-shot SFX (slide, coin, star, quest-done, unlock, undo) · pitch via existing `clampf` param · `vibrate_handheld` haptics behind toggle | more SFX · screen ducking | pentatonic combo ladder · key-of-C · density limiter · Core Haptics plugin |
| **Retention/FTUE** | Beats A–E · staged unlocks · MSB · in-app next-beat · Daily Gift/Job/bundle · Settings+Calm Mode from launch · corruption recovery flow | charming empty states · streak landmark beats | local notifications |
| **Monetization** | ONE rewarded "Tip Jar" ad (20 coins, cap 3/day) | — | rewarded-ad chest · Remove-Ads · Founder's Crate |
| **CUT entirely** (pillar/tone) | booster-forfeits-star · gacha Mystery Crate · idle/Tip-Jar income · Bomb/×2/Producer/Countdown toys | | |

¹ *Two-body merge press & undo slide-back depend on a `_rebuild_pieces` sequencing fix (capture both node refs before rebuild). If the fix is non-trivial, these degrade to the single-result pop — flag at build time.*

---

## 5. Risks & mitigations

| # | Risk | Mitigation |
|---|---|---|
| **R1** | **Core fun unproven at larger boards.** The memory file + 5 reviewers flagged it: marketed to relaxers but plays like a cerebral 15-puzzle. All economy/pacing numbers assume 45–120s "relaxing" solves never measured. | **GATING EXPERIMENT before any number locks:** playtest 5×6 boards at ~50% density for relax-vs-work feel. If it reads as homework, lower the ceiling (5×6→5×5) or raise the free-cell floor. No amount of juice makes homework feel like unwinding. This precedes the spec lock. |
| R2 | On-device solver is intractable (benchmarked: trivial 5×5 = 7.6s). | No generator/solver on device or at build time for v1. Authored levels + construction/hand par only. (§3.C) |
| R3 | Meta surface overwhelms the relaxed audience. | MSB invariant (§3.D) + staged unlocks + one-carrot + Calm Mode. Hard cap, not per-system notes. |
| R4 | Economy mis-tuned (solo dev, no telemetry). | All numbers in `EconConfig` (one file) + a debug grant/reset menu. Worked 6-session ledger (§3.A). KPI bands to watch post-launch: D1/D7, sessions/day, coins-earned-vs-spent, % faucet from ads, room-completion-time. |
| R5 | Save corruption = catastrophic for a progression game. | Atomic `.tmp`+rename + `.bak` + crc + additive idempotent migrations + forced flush on iOS pause + apology gift on loss. (§3.F) |
| R6 | Art budget is the real critical path (~17 v1 assets vs ~77 as drafted). | One room, 4 required slots, 0 variants, Wren-only narrative, reuse the showcase sparkle rig. ~17 assets fits one quarter. |
| R7 | Audio is a brand-new asset class (no pipeline; 8 placeholder WAVs). | Decide sourcing (pack vs commission) before any "lux" audio. v1 = 3 loops + 6 one-shots from a royalty-free pack. Define which celebration beats may ship silent (none of the core beats may — they degrade to visual-only gracefully but the room reveal/showcase get sound). |
| R8 | Tween-orphan trap (hit twice already). | Every looping/breathing tween bound to its node via `node.create_tween()` + `is_instance_valid` guard, never `self`. Owned/enforced in `FX`. |
| R9 | iOS safe-area/notch on new full-screen surfaces. | `FX` owns a safe-area spec (top notch + bottom indicator) every surface respects; shake offset is a CanvasLayer offset (never reparents the scene, never breaks `PRESET_FULL_RECT`). |
| R10 | Cozy tone drifting toward casino. | Scrub "slot-machine / pre-commit" language; chest/anticipation reserved for genuine milestones (1 gentle wiggle default); no gacha; warm palette; reduce-motion respected at boot. |

---

## 6. Open Questions for the owner

1. **R1 is the big one — approve the gating playtest?** Should we validate relax-vs-work on 5×6 boards *before* locking economy pacing? (Strong recommend: yes.) And confirm the v1 board ceiling: 5×6 (safer) vs 6×7 (the original ask).
2. **Coin anchor:** confirm **~160 Coins/session → first room reveal at ~session 6**. Too slow (want session 4) or too fast (want weekly)?
3. **Stars:** confirm Stars are **pure prestige + coin bonus, never spendable** (kills the only can't-lose gate risk). Agree to drop the renovation ticket entirely?
4. **Business multipliers:** confirm idle/Tip-Jar income is **cut** ("No full idle"), and the only "grow my business" mechanic in v2 is one active-play Rates multiplier unlocked after the first room?
5. **Audio sourcing:** royalty-free pack, commission, or generate? This gates the entire audio tier and is the biggest non-art unknown.
6. **Districts vs families:** OK to ship **3 districts = the 3 existing families** in v1 and defer Plants/Kitchenware (each ~10 new tier assets) to v2?
7. **Music default at first launch:** ON (cozy intent) or OFF (mobile-in-bed players often muted)? Recommend a one-tap "sound on?" on first run.
8. **Settings/notifications:** confirm Settings is available from first launch (accessibility), and local notifications are **deferred** (in-app next-beat only for v1)?
9. **Naming:** "Jobs" vs "Gigs" vs "Requests" for the spine; and is "Wren the owl dispatcher" the right warm framing (building a beloved local business, not gig-economy melancholy)?

---

# Appendix A — Exhaustive Juice Catalog

# Tidy Up — Consolidated JUICE CATALOG (End-State Spec)

> **Scope:** This is the exhaustive "spec of all the juices" for the END STATE. It dedupes the raw item list into nine categories, each rendered as a buildable table. A **Shared Primitives Ownership** map and **Global Standards** section precede/follow the tables so the same effect is never implemented twice. Every effect cites the real `main.gd` helpers where they exist (`_burst`, `_flash`, `_pop`, `_shake`, `stt_anim`, `_commit`, `_add_ring`, `_refresh_movability`, `_play_zero`, `Audio.play(name, db, pitch)`).
>
> **Priority key:** `core` = ships first, the loop feels dead without it · `nice` = strong polish, ship when core is solid · `lux` = top-tier feel, droppable wholesale with zero loop breakage.

---

## 0. Shared Primitives Ownership (read first)

The single most important table in this document. Every juice item below **calls** these owners — it never re-implements them. This is what makes one game instead of nine.

| Primitive | Sole Owner | Public API (call this, don't redefine) | Notes |
|---|---|---|---|
| **Haptics** | `FX` | `FX.haptic(weight)` — `LIGHT/SOFT/MED/STRONG/SUCCESS` | One ms table (§Global). `vibrate_handheld` for v1; Core-Haptics shim behind same API later. Gated by `Settings.haptics`. |
| **Screen shake** | `FX` | `FX.shake(trauma)` trauma 0–0.30, decays trauma² | Single trauma accumulator. Lives on persistent `FXLayer` CanvasLayer (PRESET_FULL_RECT, safe-area aware). |
| **Particle bursts** | `FX` | `FX.burst(center, color, parent, amount)` (= existing `_burst`) | One pooled emitter set. Global particle ceiling enforced here. |
| **Radial flash / bloom** | `FX` | `FX.flash(pos, color, scale, peak_a)` (= existing `_flash`) | Additive `FX_GLOW` sprite. |
| **Pop / squash** | `FX` | `FX.pop(node, to)` (= existing `_pop`), `FX.appear()`, `FX.settle()` | The canonical scale-bounce vocabulary. |
| **Coin / icon fly-to-target** | `FX` | `FX.fly(from, to, kind, count)` — gold/mint/peach | ONE coin animation. Pooled, capped 60 sprites. All "coins fly to wallet" callers route here. |
| **Number ticker** | `FX` | `FX.ticker(label, from, to, dur)` | One count-up. Per-step tick SFX + landing pop built in. |
| **Toasts** | `FX` | `FX.toast(icon, text, dest)` | One queue, max 3 stacked, non-blocking. |
| **Scene transitions** | `FX` | `FX.go(scene, style)` — `FADE/IRIS/CURTAIN/MORPH` | One veil-through-`BG_DEEP`. Shared-element handoff lives here. |
| **Beat-size grammar (S/M/L/XL)** | `Flow` | `Flow.beat(size, pos, color)` reads one `BeatSpec` table | Selects duration, particle budget, SFX tier, haptic, blocking, time-scale dip. The escalation ladder. |
| **Post-clear celebration chain** | `Flow` | `Flow.chain_level_clear(result)` | SOLE orchestrator of the all-tidy moment. `_play_zero` refactors into this. Board/Reward/Audio/Quest register STEPS into it. |
| **Celebration queue (≤1 modal)** | `Flow` | `Flow.enqueue(modal)` | Serializes L/XL payoffs with 0.3–0.5s breaths. |
| **Time-scale savor dip** | `Flow` | `Flow.time_dip(0.85/0.7, dur)` refcounted | One owner so overlapping celebrations never double-dip. Real-time tweens set `ignore_time_scale`. |
| **Audio buses / ducking / pitch ladder** | `Audio` | `Audio.play()`, `Audio.duck(db, dur)` refcounted, `Audio.combo_step()` | Music in C; one duck refcount. |
| **Combo state** | `Audio` (state) → `FX`/`Flow` (visual) | one `_combo` int, one `_combo_timer`, **one 1.5s window** | Single state machine feeds both pitch ladder and the visual ribbon. Resets on undo/restart/load. |
| **Persistence** | `Save` | `Save.coins`, `Save.add_currency()`, `Save.record_job()`, etc. | Single versioned JSON. No facet defines its own ConfigFile section. |
| **Settings (canonical keys)** | `Settings` | `reduce_motion, haptics, music_vol, sfx_vol, colorblind, big_text` | Read once at boot, OR-ed with OS reduce-motion. One "Calm Mode" preset. |

---

## 1. Board & Merge

The moment-to-moment heart. This is the cheapest, highest-ROI juice — mostly tuning/extending existing `main.gd` hooks.

| Effect | Trigger | What happens | Priority | Godot note |
|---|---|---|---|---|
| **Pickup pop** | Press on a movable piece | Scale→1.14 (`TRANS_BACK`/`EASE_OUT`, 0.09s), `z_index=20`, `item_pickup` SFX −6dB, `FX.haptic(LIGHT)` | core | Existing `_pop` extended; set z so it floats over neighbours. |
| **Lift shadow** | While a piece is held/following | Faint soft dark ellipse (alpha 0.18) drawn under piece to read as lifted off the rug | nice | Child `TextureRect` of the held piece; one shared blurred-dot texture. |
| **Finger-follow lag + tilt** | Dragging a held piece | Position lerps ~0.04s behind pointer; tilts toward velocity (clamp ±7°) for felt weight | nice | `lerp` in `_process` while `held`; `rotation = clampf(vel.x * k, ...)`. |
| **Movability dim** | Any board state change | Pieces with no legal moves dim to alpha 0.38 | core | Already in `_refresh_movability`. |
| **Merge-ring telegraph** | A piece is selected/held | GREEN merge rings pulse warm/fast (0.45s); BLUE move rings pulse slow/dim (0.7s) so merge dominates | core | `_add_ring` with node-bound looping tween (orphan trap). Colorblind: green=solid ring, blue=dashed. |
| **Ring hover-confirm** | Held piece hovers a green merge ring | Ring brightens to alpha 1.0 and scales 1.06 — "yes, here" | nice | Tween the specific ring node on hover-enter/exit. |
| **Target lean-in** | Held piece hovers a valid match | Matching target piece leans 8px toward the incoming piece | lux | Tween target offset; revert on hover-out. |
| **Reachability cool pulse** | Piece selected (reachable cells shown) | COOL-color soft pulse on rings, no scale — "you can do this" | core | Same ring system, no-scale variant. |
| **Slide wind-up** | A slide/flick begins | 0.03s squash (0.92) against travel axis before launch | core | Pre-tween before `_commit` move tween. |
| **Slide motion trail** | A piece slides across cells | 3–4 fading ghost `TextureRect` copies along the path, each →alpha 0 over 0.18s | nice | Pooled ghost sprites; skip under reduce-motion. |
| **Slide micro-overshoot** | Slide reaches destination | Last 12px eases with `TRANS_BACK` into the slot | nice | Tail segment of the `_commit` slide (`0.10 + 0.028*dist`). |
| **Slot receive-squash** | Reposition lands in empty pocket | Pocket squashes 0.94→1.0 (0.06s) + 4-mote dust puff + `item_drop` SFX + `FX.haptic(LIGHT)` | core | `FX.burst(...,4)`; `FX.pop` on the tile node. |
| **Two-body merge press** | Two pieces merge on adjacency | Source + target each squash ~0.92 toward contact point (0.05s) before result emerges | core | ⚠ Needs both node refs ALIVE — run **before** `_rebuild_pieces` (sequencing fix). |
| **Tiered merge pop** | A merge resolves | Result pops by tier (1.10..1.30) + tier-scaled `FX.burst`, color, SFX (`merge_soft` <T3 / `merge_success` ≥T3), pitch +0.04/tier, `FX.haptic` by tier | core | Single `_juice_for_tier` data table drives all four channels. |
| **Tier-up cross-fade morph** | Merge produces higher tier | Old texture fades out 0.10s while new fades in + pop + 1-frame additive white bloom (no hard swap) | core | Two stacked `TextureRect`s cross-tweening alpha. |
| **Tier ring ripple** | Merge to tier ≥3 | Expanding hollow border-circle, scale 1→2 / alpha 1→0 over 0.3s | nice | One pooled ring sprite from cell center. |
| **Combo pitch ramp + ring** | Successive merges within combo window | Each merge bumps SFX pitch via `Audio.combo_step()` (cap +0.18) + one extra particle ring | nice | Reads the ONE shared `_combo` state (§0). |
| **Tidy streak ribbon** | Combo count ≥3 | Warm "Tidy streak ×N" label floats up near board (encouraging, not scoring) | nice | Ship/cut flag — relaxed-pillar risk; default ON, soft. |
| **Showcase lift + dissolve** | Two top-tier pieces merge (put away) | Both lift+squash (scale 1.3, rise 14px) then dissolve via noise-threshold shader (lux) or scale-fade+spin (fallback) | core | Fallback path is core; shader is lux. |
| **Showcase gold bloom** | Showcase merge | `FX.flash` gold radial ×2.2 at peak alpha 0.5 (cozy, not blinding) | core | Reuse `_flash`. |
| **Showcase rising motes** | Showcase merge | 34 gold+white particles RISE (negative gravity) like clutter floating home; `tidy_poof` SFX + `FX.haptic(STRONG)` | core | `FX.burst` variant with negative gravity. |
| **Room-bound streak** | Showcase merge | A bright mote streaks from cell toward screen-top, linking put-away to room-restoration meta | nice | `FX.fly(cell, screen_top, mint, 1)`. |
| **Put-away dissolve shader** | Showcase merge (lux path) | 12-line `dissolve.gdshader` erodes texture by noise-threshold ramp 0→1 over 0.25s | lux | Behind lux flag; fallback covers it. |
| **Pickup-on-stuck shake** | Press a piece with no legal moves | Gentle horizontal spring-shake + `invalid_soft` SFX (never a buzzer) + `FX.haptic(SOFT)` ×2 | core | Existing head-shake; never red. |
| **Invalid rubber-band** | Flick toward a blocked direction | Piece leans 10px that way then springs back (`TRANS_ELASTIC`) + `invalid_soft` + `FX.haptic(LIGHT)` | nice | Spring tween; no failure framing. |
| **Snap-back home** | Held piece released on nothing | Springs home (`TRANS_QUAD`, 0.13s) + scale→1.0, no penalty | core | Already built. |
| **Undo slide-back** | Undo pressed | Pieces reverse-animate to prior positions (0.12s) + desaturate flash + soft tap; combo/quest counters un-count | nice | ⚠ Same node-capture dependency as two-body press. Quest progress: notify on committed-only. |
| **Restart scatter-resettle** | Restart pressed | Pieces quick scatter-and-resettle (0.2s) into initial layout | nice | Tween from current → initial cells. |
| **Near-clear warm scrim** | ≤3 pieces remain | Background dim lerps 0.62→0.50 so cozy room peeks through — "almost tidy" | nice | Tween BG modulate. |
| **Final-pair heartbeat** | Exactly one matching pair remains | Last two pieces pulse a stronger heartbeat + extra-bright green ring | lux | Stronger pulse on the two node-bound tweens. |
| **Idle glow-pulse** | Few pieces, board at rest | Remaining pieces breathe a gentle low-amplitude glow | lux | Node-bound looping `TRANS_SINE`. |
| **Board idle wave** | No input on board 4s | Movable pieces do a staggered (0.08·i) one-cycle breathe wave, then rest | nice | One-shot per-node tween; cancels on input. |
| **Toy-debut spotlight** | First appearance of a new family/art on its intro level | One-time pulse/glow ring draws the eye to the new cell (wordless), then fades. No text. | core | Reuse ring; fired once per content via `seen_` flag. |

---

## 2. Slide & Input Feel

Routing is the verb; this is its tactile signature. (Merge-specific motion lives in §1; this is the input/feedback layer.)

| Effect | Trigger | What happens | Priority | Godot note |
|---|---|---|---|---|
| **Button press depress** | Any button pointer-down | Scale→0.94 (INSTANT, `EASE_OUT`) + `FX.haptic(LIGHT)` + `button_tap` SFX | core | Shared button base scene. |
| **Button release spring** | Button click released | Spring back to 1.0 via `FX.appear()` with 1.06 overshoot | core | — |
| **Soft-no invalid feedback** | Illegal tap/drag/swipe | ±9px head-shake + `SOFT_NO` desaturate dim + `invalid_soft` SFX. **Never red.** | core | Existing shake; the universal "no." |
| **Slide whoosh (distance-graded)** | Piece slides rook-style to a cell | `item_slide`, pitch +0.02/cell, volume scales with distance; `FX.haptic(LIGHT)` on stop | core | Reads `dist` already in `_commit`. |
| **Drop / reposition felt** | Release on a blue reachable cell (no merge) | `item_drop` −3dB + soft felt accent (lux) + `FX.haptic(LIGHT)` | core | — |
| **Nudge attention wiggle** | Tutorial-free "tap here" hint moment | NUDGE peach breathe + single wiggle on the target | nice | One-shot; FTUE only. |
| **Skip / fast-forward (board)** | Tap during showcase / any board anim | Fast-forwards all pending tweens to end-state, returns control within one frame | core | **HARD INVARIANT.** Rework the `animating` flag: rules-mutating slide stays briefly guarded; showcase/celebration are interruptible. |
| **Coach-mark arrow** | Each FTUE beat | Soft rounded arrow + ≤4-word label fades in pointing at target, bobs, pop-dismiss with sparkle the instant the action happens | core | FTUE-owned; reuses ring/breathe. |

---

## 3. Transitions & Screen Flow

No hard cuts, anywhere. All routed through `FX.go()`.

| Effect | Trigger | What happens | Priority | Godot note |
|---|---|---|---|---|
| **Soft-fade transition** | Any scene change (default) | Cream/`BG_DEEP` veil fades to opaque over `PAGE`, swap at apex, fade out (0.22s) | core | `FX.go(scene, FADE)`. The v1 default for everything. |
| **Scene cross-fade hero rise** | Menu/Map/Board/Room swap | Incoming hero element rises in as veil clears | core | Shared `FX.go` step. |
| **Level intro client-card sweep-in** | A job/level opens | Client card slides up (`TRANS_BACK` 0.35s) with client+job+star-goal; pieces cascade in (0.025s stagger, per-row `item_drop`); input locks ~0.8s until settled | core | `Flow` sequences card→cascade→unlock. |
| **Board piece cascade-in ripple** | Board builds at level start | Each piece scales 0→1 in reading order with settling overshoot — "falling into place" | core | Staggered `FX.pop`. |
| **Size-up reveal** | First level of a larger board size | Tray unfolds/settles as the new pocket grid builds — "bigger job," no popup | nice | One-shot tray expand tween. |
| **Curtain transition** | Entering a job/level | Soft top-down gradient curtain — "starting work" feel | nice | `FX.go(scene, CURTAIN)`. |
| **Cozy iris wipe** | Tap a button opening a major screen | Radial smoothstep iris blooms from the tapped point; falls back to soft-fade | lux | Shader; `FX.go(scene, IRIS, from_pos)`. |
| **Shared-element coin morph** | Leaving board for map/hub | Coin counter duplicate flies old→new position across the swap | lux | `FX.go(scene, MORPH)` with element handoff. |
| **Shared-element thumbnail grow** | Selecting a job on the map | Job thumbnail morphs and grows into the level header | lux | MORPH handoff. |
| **Tab content slide-crossfade** | Switching hub tabs (Home/Jobs/Shop/Quests) | Content slides ±40px in delta direction + crossfade over `BASE` | core | The hub navigation idiom. |
| **Tab ink-bar slide** | Tab selection changes | Underline bar `FX.settle()`s x to new tab; tab icon pops to 1.15 | nice | — |
| **Panel/dialog pop-in** | Any modal/panel opens | `FX.appear()` scale from 0.92 + veil fade behind | core | — |
| **Panel dismiss** | Closing a panel | `FX.settle()` to 0.96 + fade out; veil fades | core | — |
| **Travel route draw** | Player selects a new job | Dotted `Line2D` draws point-by-point from current pin → target; scooter icon path-follows; camera pans; ~0.8–1.2s, skippable | nice | `Curve2D` + `PathFollow2D`. |
| **Arrival ta-da** | Travel anim reaches target pin | Soft chord + target pin bounce | nice | — |
| **New location reveal** | Business/progress unlocks a new area | Fog/cloud `FX_GLOW` overlay dissolves; region desaturated→full-color crossfade; pins fade up staggered (~1.5s); `FX.haptic(STRONG)` | nice | Map-screen sequence. |

---

## 4. Celebrations — the S/M/L/XL grammar

`Flow` owns this. Every celebration **classifies into a beat size** and pulls duration/particles/SFX/haptic/blocking/time-dip from ONE `BeatSpec` table. This guarantees proportional, consistent feel and is the single best defense against reward-vomit.

### 4a. The grammar (BeatSpec table)

| Size | Used for | Duration | Particles | Time-dip | Haptic | Blocking? |
|---|---|---|---|---|---|---|
| **S** | quest tick, coin increment, bar notch, tab badge | ≤0.2s | ≤6 | none | LIGHT | no |
| **M** | quest complete, star award, unlock toast, decor settle, map stamp | ~0.4s | ≤24 | none | MED | no |
| **L** | board clear, room reveal, chest open | ~0.8s | ≤60 | 0.85 / ≤0.4s | SUCCESS | brief, skippable |
| **XL** | room complete, rank-up, milestone/collection, streak landmark | ~1.4s | ≤120 | 0.7 / ≤0.4s | SUCCESS | modal, skippable |

### 4b. Celebration effects

| Effect | Trigger | What happens | Priority | Godot note |
|---|---|---|---|---|
| **All-tidy impact beat** | `board.is_cleared()` | `Flow.time_dip(0.85, 0.25s)`, soft white `FX.flash`, `merge_success`+whoomph, MED haptic, central 40-gold `FX.burst`, empty tray breathes | core | **Step 1 of `Flow.chain_level_clear`** — `_play_zero` refactors into this. |
| **All-tidy veil + title drop** | t=0.30s after impact | Dark veil→0.88, `FX_GLOW` bloom, "All tidy!" drops with `TRANS_BACK` overshoot, `level_complete` SFX, top confetti fountain | core | Chain step 2. |
| **Star-award sequence** | t=0.9s post-clear | Stars pop one-by-one 0.18s apart (`stt_anim`), each with `FX.burst`, ascending ding (1.0/1.12/1.26), escalating haptic. **Missed stars are NOT rendered on the default screen** (no report-card feel) | core | Chain step 3. Mastery view opt-in only. |
| **Coin count-up** | t≈1.6s post-clear | `FX.ticker` 0→total ≤1.2s ease-out; every ~3rd increment fires S tick + jitter; final value gets M gold pop + cha-chime | core | Chain step 4; reuses `FX.ticker`. |
| **Coins fly-to-wallet** | During coin count-up | `FX.fly(star_row, coin_pill, gold, 5–8)`, 0.04s stagger, `TRANS_BACK`; each arrival bumps pill 1.0→1.15→1.0 | nice | ONE coin animation (§0). |
| **Reward-line shimmer** | t≈2.4s post-clear | "✨ a new piece for your bedroom" slides in with mint shimmer sweep | core | Chain step 5. |
| **Tap-to-continue pulse** | Chain settles | Looping alpha pulse on prompt (node-bound), invites dismissal without rushing | core | — |
| **Skip / fast-forward (chain)** | Tap during any L/XL chain | Fast-forwards all pending tweens to end-state | core | HARD INVARIANT (mirrors §2 board skip). |
| **Celebration queue serialization** | Multiple L/XL payoffs from one action | `Flow.enqueue` serializes modals (≤1 on screen) with 0.3–0.5s breaths — crescendo, not noise | core | The anti-overwhelm spine. |
| **Empty-tray breathe** | Board cleared, no pieces | Now-empty tray soft scale-breathe — "done & at rest" | lux | Node-bound. |
| **Radial bloom flash** | Every M+ beat impact | Additive `FX_GLOW` scales 0→1.4 and fades, tinted to beat color | core | `FX.flash`. |
| **Confetti fountain preset** | L/XL celebrations | Slow-fall mixed warm confetti from screen-top, gravity 180, lifetime 1.6, gentle spin (pooled `GPUParticles2D`) | core | One pooled preset. |
| **Sweep ribbon preset** | coin-fly, room-trace, shimmer lines | Directed ribbon of dots A→B | nice | Shared with `FX.fly`. |
| **Return-to-map node stamp** | Map loads after a clear | Just-cleared node stamps a checkmark + 3-star arc (M beat) | nice | — |
| **Quest-complete toast** | Any quest completes | `FX.toast` slides from top (`TRANS_BACK` 0.3s), holds 1.6s, exits; icon pop + 12-gold burst + soft ding + LIGHT haptic; stacks max 3 | core | `FX.toast`. |
| **Micro-quest progress tick** | Incremental session-goal progress | S tick: tiny mint pop on quest chip + soft tick + 2px chip jitter | nice | `Flow.beat(S)`. |
| **Chest / reward open** | Player opens an earned chest | 3 escalating shakes + rising creak → 0.2s pause → lid pops, gold bloom + confetti, contents fly out staggered with ascending dings; SUCCESS haptic | core | L beat. (Cozy default = gentler shake.) |
| **Chest anticipation pause** | Just before chest burst | 0.2s held beat after the shake build — the silence that makes the open land | nice | — |
| **Rank/level-up fanfare** | Business/tidier rank increases | XL: banner sweep, odometer numeral roll, slow rotating light-rays, fanfare, follow-on unlock card | nice (defer to v2) | XL; rare. |
| **Milestone/collection fanfare** | Collection set / long-arc goal completes | XL full-screen: set items `stt_anim`-pop in sequence, banner, 120-particle load, grandest fanfare; rare by design | nice (defer to v2) | XL. |
| **Daily streak tick** | Daily streak continues | M toast with flame/calendar icon ticking up ("🔥 4-day streak") + warm pop | nice | — |
| **Streak landmark fanfare** | Streak hits 7 or 30 | Escalates to XL: dedicated banner + bonus-coin count-up | lux | — |
| **Set-complete showcase** | Last item of a furniture SET owned | Full-screen soft golden wash, set items glow in sequence, badge lights with sparkle ring; reuse showcase/tidy-poof SFX | lux | — |
| **Par-beat flourish** | Final drag clears at/under par (hits ★★★) | Par number in HUD flashes gold + quick scale-pulse the instant ★★★ lands, before results — mastery acknowledged mid-clear | nice | Quiet; no loss framing if missed. |

---

## 5. Rewards & Economy

All numeric/coin/star feedback. **Consumes `FX.fly` / `FX.ticker`** — defines no coin animation of its own.

| Effect | Trigger | What happens | Priority | Godot note |
|---|---|---|---|---|
| **Coin payout fly-out** | Board clear, payout card | 8–14 coin sprites arc from board center → coin counter, staggered ~40ms, each landing with pitch-stepped tick + counter punch (1.0→1.15→1.0); final coin brighter chime | core | `FX.fly(board, counter, gold, n)`. If counter not on board screen, fly to the payout card's coin line, then to wallet after transition. |
| **Coin counter first-reveal** | Very first payout (`seen_.coin_counter` false) | Counter slides down from top with soft pop + one-time gleam sweep; never animates this hard again | core | One-time `seen_` flag. |
| **Animated count-up + tick** | Any persisted number changes (coins/xp/level) | Eased roll (`TRANS_QUART`/`EASE_OUT`), coin_tick per ~80ms pitch 1.0→1.25, widget pop on final frame | core | `FX.ticker`. |
| **Wallet count-up (banked)** | Any persisted currency increase | HUD balance rolls digit-by-digit with soft tick — persistence reads as "banked" | core | Fired after `Save.add_currency` commits. |
| **Fake coin spin** | Coin sprite alive during shower | Loop `scale.x` 1.0→0.1→1.0 to read as spinning gold (no extra art) | nice | In the `FX.fly` sprite. |
| **+N floater** | Coin/XP/bonus award at a world pos | Pooled label rises 40px while fading over 0.7s (`TRANS_QUAD`) + jitter; gold=coin, mint=XP, peach=bonus | core | Pooled label. |
| **Ticker per-step tick** | Each whole number during a roll | Low-vol rising-pitch tick + LIGHT haptic every ~5 steps | nice | Inside `FX.ticker`. |
| **Ticker landing pop** | Ticker reaches final value | Label pop + GOLD flash; adjacent coin icon one breathe pulse | core | — |
| **Ticker milestone burst** | Ticker crosses a renovation price threshold | PUFF gold burst at label + MED haptic | nice | — |
| **Star fill sweep / stamp-in** | Per earned star at results | Outline pops (`stt_anim`), gold fill sweeps 0→1 via shader `fill_amount` over 0.25s with ascending `star_fill` chime; ring-flash + 6 GOLD sparkles; 3rd star = brighter flourish | core | Shader fill or 2-sprite fallback. |
| **Unearned-star silence** | Star not earned | NO render on default screen; quiet secondary "par" line, never loss-framed | core | (Reconciled: don't foreground the miss.) |
| **Stars-to-coins handoff** | After last star fills | One coin streams from each earned star → wallet | nice | `FX.fly`. Stars = pure prestige + coin bonus, NOT a spendable ticket (v1). |
| **Eased bar fill + leading shimmer** | XP/progress/room bar advances | Fill tweens `TRANS_CUBIC`/`EASE_OUT` 0.6s with additive glint (`fx_sparkle`) riding the fill head | core | Shared `fill_bar`. |
| **Bar milestone tick** | Fill crosses a notch | Notch flashes gold + `tick_pop` | nice | — |
| **Bar level-up / overfill** | XP bar hits 100% | White flash, empty whoosh, level pop+increment, `levelup_chime`, carry-over refills | core | — |
| **Next-beat preview card** | End of any reveal/win/quit screen | Single card: the closest carrot across ALL layers ("Cozy Kitchen: 2 jobs to go") with a tiny preview bar; gently breathes (1.0↔1.04, 1.1s) + one notch fill click + peach puff. **One carrot, never four bars.** When no next beat: graceful fallback ("Daily job tomorrow" / "Replay for stars") | core | The load-bearing retention rule. |
| **Unlock reveal flip** | New client/biome/family/room-piece unlocked | Veil dim + `Flow.time_dip(0.9, 150ms)`; face-down card flies in, held beat, tap to flip (`scale.x` 1→0→1 art swap), GOLD `FX.burst(40)` + bloom, `unlock_fanfare`, art scales with `TRANS_ELASTIC`, name fades, NEW ribbon pops | core | L beat. |
| **Spot transformation build (renovation)** | Buying a renovation task in home hub | Hammer/sparkle puff, old art layer wipes/dissolves to furnished layer, warm chime, room ambiance brightens a notch; coin counter spends-DOWN with reverse-fly | core | Shared overlay-fade reveal. |
| **Passive income popup** | (deferred to v2) | — | defer | Cut for v1 ("No full idle"). |
| **Income-rate change preview** | (deferred with business panel) | — | defer | — |
| **Welcome-back idle pile** | (deferred to v2) | — | defer | — |
| **Daily Gift / calendar claim stamp** | Claiming today's daily reward | Tile flips to checkmark with stamp thunk, reward flies to wallet, today's tile bounce; 7-day ramp advances one lit cell | core | The v1 "welcome back" beat. |
| **Streak flame grow / relight** | Daily streak increments (incl. recovering a dimmed miss) | Flame brightens one step + `flame_grow` whoosh + warm ember `FX.burst`; on recovery it relights from dim, never resets to zero | core | One streak model: flame dims, NUMBER never decreases. |
| **Streak dim (no death)** | Player misses a day | Flame desaturates + shrinks ~20% but never extinguishes; no harsh color, no loss SFX | nice | — |
| **Room-piece placement pop** | Spending money to place decor | Item drops with `TRANS_BACK` settle, dust `FX.burst`, soft `place_thunk`, room-completion bar fills | core | Shared `fill_bar`. |
| **Room complete jackpot** | Room-completion bar hits 100% | Hand off to XL: glow bloom, fanfare, room lights up, next-room preview card | lux | `Flow.chain` XL. |
| **Quest-complete pop + coin pip** | Quest hits its goal | Chip flips to ✓, confetti tick, glowing +N coin pip arcs (`TRANS_BACK`) into counter (scale-pop + tick-up); if completes the daily set, streak flame grows | core | `FX.fly` + `FX.toast`. |
| **Micro-chip fill + checkmark** | Per-session micro-goal hits target | Chip progress sweeps to 100%, flashes mint, stamps ✓, slides out; replacement slides in | core | — |
| **Job card DONE stamp** | A Job completes on the Jobs board | Rubber-stamp "DONE" rotates-in with a thunk + slight shake; card desaturates, collapses onto completed pile | nice | M beat. |
| **Client-thanks beat** | Final level of a Job-spine cleared | Client portrait slides up with 1–2 warm lines, gold coin lump bursts (`FX.burst` 40+), "NEW: <zone> unlocked" banner wipes in → next-beat card. **Lump auto-funds ~1 slot of the unlocked zone** (visible slot building) so the narrative faucet feeds renovation rather than diluting it | core | Directed payout. |
| **Edge glints on jackpot** | Jackpot-tier reward fires | Brief screen-edge gold glint sprites sweep inward to frame the moment | lux | — |
| **Wallet counter idle shine** | Ambient, wallet HUD visible | Periodic subtle shimmer sweep across coin counter | lux | Low-frequency loop. |
| **Crate pull / Mystery Crate** | (deferred / reconsidered) | — | defer | Cut gacha for v1; flat coin-priced rotating shop instead. |
| **Achievement badge ignite** | Lifetime counter crosses a milestone tier | Badge fades grey→full-color + ring-sparkle + soft chime (Trophy page, or deferred toast if mid-flow) | lux (defer to v2) | Counters accrue silently in v1. |

---

## 6. Meta / Home & Ambient

The renovation payoff — the product's emotional core. v1 = ONE room (existing bedroom), ~5–6 slots, `required_slots < total` so it reads "done" early.

| Effect | Trigger | What happens | Priority | Godot note |
|---|---|---|---|---|
| **Decor drop-in** | Return to room after buying decor (`pending_reveal`) | Item drops from ~90px above anchor, `modulate.a` 0→1, scale 0.6→1.08 over 0.25s (`TRANS_CUBIC` `EASE_IN`) | core | Reads `Save.rooms[room].decor`. |
| **Furniture settle squash** | Decor drop reaches anchor | scale 1.08→1.0 (`TRANS_BACK`) + scale.y dip to 0.94; sideways dust-puff `FX.burst(14)` | core | — |
| **Furniture place thunk** | Decor settles | `item_drop` pitched ~0.85 + `merge_soft`; `FX.haptic(MED)` | core | — |
| **Slot fill-in reveal** | Buy/place a home decoration slot | Decor PNG fades+scales in (0.5s `TRANS_BACK`) + `fx_sparkle` burst + warm "settle" chime; the empty-fixture ghost dissolves | core | Shared overlay-fade reveal rig (= showcase). |
| **Ghost slot outline** | Room shows an empty/affordable slot | Faint dashed `fx_glow` outline tinted `SLOT_WALL` at anchor, optional floating +1 preview | nice | — |
| **Lamp glow-up** | A lamp decor is revealed | One-shot additive `fx_glow` fades 0→0.6→0.45 over ~0.6s; `lamp_on` SFX | core | — |
| **Lamp breathe loop** | Owned lamp at rest, screen visible | Additive glow a 0.45↔0.6 over 3.0s `TRANS_SINE`, bound to lamp node | nice | Node-bound (orphan trap). |
| **Warmth retint** | Any decor revealed / `room_pct` rises | Global warmth lerps up over 0.6s, retinting color-grade warmer + opens audio low-pass | core | Whole-room `modulate` + `Audio` filter. |
| **Room lighting warm-up** | A lighting renovation specifically | Whole-room modulate lerps to warm (1.05,1.02,0.98) over 0.6s — room literally brightens | nice | — |
| **Room cozier ribbon** | After a decor reveal settles | "Room x% cozier" ribbon slides up from bottom, holds 1.2s, exits | nice | `FX.toast` variant. |
| **Room restoration bar fill** | During room reveal | "Bedroom — now N% restored" bar fills with S tick-stream + gold shimmer (reads `Save` completion) | core | Shared `fill_bar`. |
| **Room before→after reveal** | A renovation/decor unlock purchased/earned | Show "before" 0.5s → XL impact (time-dip 0.7/0.4s, whoomph+riser, long haptic) → new decor drops/fades with mint+gold sweep tracing onto it + bloom + `tidy_poof` | core | `Flow.chain` XL. The single highest-retention beat — protect it. |
| **Room lights-on reveal** | Final required slot of a room filled | Camera gentle push-in, warm-light overlay 0→1, chandelier/lamp bloom, big sparkle sweep L→R, Wren texts a one-liner. The ONE big "home" exhale — reserved, not per-slot | core | XL; mirrors the ZERO exhale rule. |
| **Room Complete ceremony** | All decor slots filled | Slow camera pan, all ambient loops start together, warm bloom sweep L→R, gold confetti `FX.burst`, framed "Complete!" plate slides in, `level_complete` SFX, STRONG haptic | core | XL. |
| **Light shaft + dust motes** | Room with ≥1 decor, screen visible | Faint diagonal `fx_glow` shaft + slow `GPUParticles2D` (~8 motes, lifetime 6); opacity scales with warmth | nice | Pauses when screen hidden. |
| **Wren text-bubble pop** | Job intro/outro, room reveals | Chat bubble springs in from side with soft pop + tiny owl-blink on portrait; auto-advances or taps. Quiet, never blocking; mutable | nice | Single reusable Wren bust (v1). |
| **Map pin bob** | Pin available/unsolved | Gentle vertical bob + soft pulse ring (reuse landing-ring) | core | Node-bound. |
| **Completion stamp** | Job/level completed on map | Wax stamp thunks down scale 1.4→1.0 (`TRANS_BACK`), rotation jitter ±4°, ink `FX.burst`, `stamp`/`tidy_poof` SFX, MED haptic | core | — |
| **Map token travel** | Unlocking next client/district | Tidier token walks/hops one node further with dotted-trail draw-on + soft footstep tick; new district card slides up | nice | (= Travel route draw, §3.) |
| **Client thank-you / gift unwrap** | Job/client completion | Client avatar thumbs-up/heart pop on pin; completing all of a client's jobs → wrapped-gift icon bounces on the card, ribbon unties, gifted decor sparkles out and flies toward Home tab (pulses a dot) | nice | v1 clients = text-only one-liners. |
| **Business upgrade stamp** | (deferred with business panel) | — | defer | Tidy Co. deferred to post-first-room. |
| **Money counter count-up / spend-down** | Coin flight lands / spend confirmed | Numeric roll-up (rising ticks); spend rolls DOWN with softer tick | core | `FX.ticker` both directions. |
| **Ambient pet** | Room ≥70% decorated, every 20–40s | Cat wanders in, curls on rug, blinks, leaves; pauses when screen hidden | lux | Persist `pet_unlocked`; defer to v2. |
| **Pet purr tap** | Tap the ambient pet | `cat_purr` SFX + heart particle + LIGHT haptic | lux | — |
| **Decor depth parallax** | Device tilt / slow idle drift on room screen | Foreground decor shifts ±6px vs background; capped, slow | lux | Accelerometer; reduce-motion off. |
| **Time-of-day grade** | `tod` advances (per session/jobs) | Full-screen warm→noon→golden→night color-grade shifts slowly; night boosts lamp glow, lowers ambient SFX | lux | — |
| **Seasonal accent** | Real-month change | Swappable accent layer (snow/leaf motes) reusing dust-mote emitter | lux | — |
| **Admire / photo mode** | Tap Admire on a finished room | Free pan/zoom, UI hidden, optional stat stickers, render-to-Image screenshot + share | lux | — |
| **Fast-forward on tap (meta)** | Tap during any meta animation | Tween jumps to final state (`custom_step`/set final values); does not cancel | core | HARD INVARIANT. |

---

## 7. UI Micro-interactions

The connective polish on every screen. All breathe/shimmer is gated by reduce-motion.

| Effect | Trigger | What happens | Priority | Godot note |
|---|---|---|---|---|
| **Primary CTA breathing** | A primary/ACCENT button idle + actionable (Play, Claim) | Slow breathe scale 1.0↔1.03 on LUX loop; pauses while pressed | nice | Node-bound. |
| **Disabled→enabled wake** | Button becomes affordable/available | One NUDGE peach flash + breathe starts | nice | — |
| **Number ticker roll-up** | Coins/stars/XP value changes | Eased count-up (`TRANS_QUART`) 0.3–1.2s, longer for bigger gains | core | `FX.ticker`. |
| **Toast slide-in / hold / exit** | Quest/unlock/streak/autosave | Pill slides from top safe-area with overshoot + icon; holds (LUX + 0.05s/char); slides up & fades; next in queue advances | core | `FX.toast`. |
| **Toast stack nudge** | New toast while others showing (max 3) | Existing toasts `FX.settle()` upward to make room | nice | — |
| **Toast tap-to-jump** | Tap a toast with a destination | `FX.go(dest, MORPH)` into that screen | lux | — |
| **Tab badge breathe + ticker** | Unclaimed-count badge changes | Tiny breathe dot + ticker on the number | nice | — |
| **Logo idle breathing** | Title/menu idle | Logo breathe scale 1.0↔1.02 over LUX×1.4 | nice | — |
| **Coin icon idle wobble** | Hub idle, coin counter visible | Coin icon slow rotate-wobble ±3° on LUX | lux | — |
| **First-launch play nudge** | First run / empty home | Soft NUDGE arrow breathing toward Play | nice | FTUE. |
| **Empty quests state** | No quests remaining today | Sleeping-cat illustration + "All caught up ☀" with gentle breathe | nice | Charming empty state. |
| **System first-reveal card** | Any staged system unlocks first time (decorate/quests/daily/star goals) | Reuses showcase bridge: card scales in with system icon, one line of flavor, confetti puff, single "OK"; fires once per system via `seen_` flag | nice | Staged-unlock owner = FTUE. |
| **Locked shop shimmer** | Viewing a locked shop section | Dimmed silhouettes + COOL shimmer sweep shader | lux | — |
| **Collection ghost breathe** | Viewing collection with empty slots | Ghosted slots breathe faintly to invite completion | lux | — |
| **Rewards-waiting super-badge** | Menu open with ≥1 unclaimed reward | "⊕ N" badge bounces in on Play (overshoot); tapping fans the individual reward chips outward in a quick stagger | nice | The ONE decomposable "rewards waiting" affordance (meta surface budget). |
| **Piece-to-collection fly** | A top-tier piece is "put away"/collected | Ghost of piece flies to collection book icon, which pops | lux | `FX.fly`. |
| **Reduce-motion compliance** | "Reduce motion" ON | All shake→0, overshoot halved, idle-breathe + shimmer disabled (instant crossfades) | core | One global gate (§Global). |

---

## 8. Audio

`Audio` owns buses, the duck refcount, the pitch ladder, and combo audio state. v1 = 3 music loops + ~6 new one-shots; lux pentatonic/key-of-C constraint deferred.

| Effect | Trigger | What happens | Priority | Godot note |
|---|---|---|---|---|
| **Pickup tick** | Press pops a piece out | `item_pickup` −6dB + LIGHT haptic | core | — |
| **Slide whoosh (distance-graded)** | Piece slides to a landing cell | `item_slide`, pitch +0.02/cell, volume scales with distance; LIGHT haptic on stop | core | Reads `dist` from `_commit`. |
| **Drop / reposition felt** | Release on blue reachable cell (no merge) | `item_drop` −3dB + soft felt accent (lux) + LIGHT haptic | core | — |
| **Merge tone tier 1–2** | T1/T2 same-family merge | `merge_soft` at pentatonic base pitch for tier + combo step; LIGHT haptic | core | — |
| **Merge tone tier 3–4** | Higher-tier merge | `merge_success` up an octave + shimmer tail (lux); MED haptic | core | — |
| **Combo pitch ladder** | Consecutive merges within combo window | Each merge steps up the scale (rising phrase), caps +9 steps; combo ≥4 bumps one rigid haptic | nice | ONE shared `_combo`/timer, **1.5s window** (§0). Ship/cut flag. |
| **Density limiter chorus** | >6 same-tier merge voices within 120ms (chain auto-merges) | Collapse to one voice with ±5-cent detune chorus instead of machine-gun | nice (defer) | — |
| **Showcase chime** | Two TOP-tier pieces merge | `tidy_poof` + `showcase_chime` + breath accent; resolves to tonic; SUCCESS haptic; ducks music −6dB for tail | core | `Audio.duck` refcount. |
| **Board-clear swell** | Board perfectly empty | `level_complete` + `clear_swell` pad resolving to tonic chord; celebration haptic (3 rising taps + ~700ms soft rumble); music ducks then returns | core | — |
| **Coin earn arpeggio** | Coins awarded after a job | `coin_soft` arpeggio length maps to coin count; selection-haptic ripple (1 per ~5 coins, cap 6) | core | — |
| **Coin spend warm tone** | Buying decor/upgrade/unlock | `coin_spend` descending warm tone | core | — |
| **Star award pops** | 1/2/3 stars granted | `star_pop` per star, pitch +step/star, 120ms apart; one LIGHT haptic/star | core | — |
| **Quest progress / complete** | Quest advances / completes | `quest_tick` soft tick (sound-off parity) → `quest_done` small fanfare + sparkle (lux); SUCCESS haptic; ducks music | core | — |
| **Unlock reveal** | New room/decor/client/biome unlocked | `unlock_reveal` rising pad + reveal whoosh (lux); MED-then-LIGHT haptic | core | — |
| **Streak climb** | Daily streak increments | `streak_up` pitch climbs with streak count (caps day 7); MED haptic | nice | — |
| **Invalid felt-thud** | Illegal move / no-moves nudge | `invalid_soft` low-passed −3dB (never a buzzer); soft warning double-haptic | core | — |
| **Undo swish** | Undo pressed | `ui_undo` soft reverse-swish | nice | — |
| **UI button tap** | Any primary button | `button_tap` −2dB + selection haptic | core | — |
| **UI toggle/slider tick** | Settings toggle/slider detent | `ui_toggle` soft tick + selection haptic | nice | — |
| **Per-screen music bed** | Entering Menu/Board/Home | 600ms equal-power crossfade to that screen's loop (`mus_menu`/`mus_play`/`mus_home`); board music in C so merges consonate | core | Defer key-of-C constraint to lux; ship crossfade. |
| **Ambient room bed** | On gameplay/home screens | Low-volume `amb_room`/`amb_home` loop (clock tick, birds); home ambient grows livelier with tidiness | nice | — |
| **Tidiness-evolving ambient** | Home restoration progresses | Ambient bed layers more life (instruments/birds) as room fills | lux | — |
| **Background fade** | App backgrounded / resumed | Master → −80dB over 250ms (out) / fades back (in) | core | `NOTIFICATION_APPLICATION_PAUSED`. |
| **Stinger ducking pocket** | Any big stinger (showcase/clear/quest/unlock) | Music ducks −6dB for stinger tail (~900ms) then tweens back so the moment breathes | core | One `Audio.duck` refcount (no early-restore). |
| **Pitch-randomized SFX** | Any repeated celebration sound | ±2-semitone random pitch on dings/pops so rapid repeats don't fatigue | nice | Uses existing `pitch` param. |
| **Layered fanfare stems** | L/XL beats | 2–3 `AudioStreamPlayer`s (riser+body+sparkle tail) started together; beat size selects mix | nice (defer) | — |
| **Reduced-intensity parity** | Reduce-motion ON | Drop highest sparkle SFX accent layer; celebration haptic → single MED tap | core | — |

---

## 9. Haptics

ONE helper, ONE weight vocabulary, ONE ms table, ONE settings gate. Owned by `FX`. (Detailed table in §Global Standards.)

| Effect | Trigger | What happens | Priority | Godot note |
|---|---|---|---|---|
| **Haptic vocabulary** | Each beat / interaction | `FX.haptic(weight)` → `LIGHT/SOFT/MED/STRONG/SUCCESS` via `Input.vibrate_handheld`, mobile-guarded, settings-gated | core | v1 = `vibrate_handheld`; Core-Haptics shim behind same API later. |
| **Selection ripple** | Repeated small grants (coins, steps) | One LIGHT tick per N events, capped (e.g. 1/5 coins, cap 6) so it never machine-guns | core | Counter inside the calling loop. |
| **Success pattern** | L/XL payoff peaks | `SUCCESS` = 2×20ms with a gap | core | — |
| **Reduced parity** | Reduce-motion / low-power ON | All haptics downshift to a single MED tap or off | core | OR-ed with OS flag at boot. |

---

## 10. Idle / Ambient Life

The "the game is alive even when you're not touching it" layer. Almost entirely `nice`/`lux` — droppable, but it's a big part of the cozy moat.

| Effect | Trigger | What happens | Priority | Godot note |
|---|---|---|---|---|
| **Board idle wave** | No board input 4s | Movable pieces staggered one-cycle breathe wave, then rest | nice | (Cross-ref §1.) |
| **Idle glow-pulse** | Few pieces, board at rest | Remaining pieces breathe a gentle glow | lux | (Cross-ref §1.) |
| **Logo idle breathing** | Title idle | Logo breathe 1.0↔1.02 | nice | (Cross-ref §7.) |
| **Coin icon idle wobble** | Hub idle | Coin icon rotate-wobble ±3° | lux | (Cross-ref §7.) |
| **Wallet counter idle shine** | Wallet visible | Periodic shimmer sweep across counter | lux | (Cross-ref §5.) |
| **Lamp breathe loop** | Owned lamp at rest | Glow a 0.45↔0.6 over 3.0s | nice | (Cross-ref §6.) |
| **Light shaft + dust motes** | Room with ≥1 decor visible | Diagonal `fx_glow` shaft + ~8 slow motes; opacity scales with warmth | nice | Pause when screen hidden. |
| **Ambient pet** | Room ≥70% decorated | Cat wanders/curls/blinks/leaves every 20–40s | lux | Pause when screen hidden; defer v2. |
| **Decor depth parallax** | Tilt / idle drift | Foreground ±6px vs background | lux | Reduce-motion off. |
| **Time-of-day grade** | `tod` advances | Slow color-grade warm→night | lux | — |
| **Seasonal accent** | Real-month change | Snow/leaf mote layer | lux | — |
| **CTA / logo breathe & badge breathe** | Idle actionable elements | Slow scale breathe / breathe dot on unclaimed badges | nice | (Cross-ref §7.) |
| **Collection / shop ghost breathe** | Viewing empty/locked slots | Faint breathe to invite completion | lux | (Cross-ref §7.) |

> **Idle-life invariant:** every looping idle effect uses a **node-bound** tween (`node.create_tween().set_loops()`), never `self`, to avoid the verified "Infinite loop detected" orphan trap when the node is freed. Every idle loop **pauses when its screen is hidden** (`VisibilityNotifier`/`is_visible_in_tree`) to protect battery.

---

## Global Standards

### Easing / tween conventions
- **Vocabulary:** `FX.appear()` (overshoot-in, `TRANS_BACK` to 1.06→1.0), `FX.settle()` (gentle-out, `TRANS_QUAD`/`EASE_OUT` to target), `FX.pop()` (squash-bounce). Use these names everywhere; no ad-hoc tweens for the standard motions.
- **Default curves:** UI/scale = `TRANS_BACK` in, `TRANS_QUAD` out · counters/bars = `TRANS_QUART`/`TRANS_CUBIC` `EASE_OUT` · invalid spring = `TRANS_ELASTIC` · slides = the existing `_commit` `0.10 + 0.028*dist` with a `TRANS_BACK` 12px tail.
- **Orphan trap (verified):** looping tweens MUST be `node.create_tween().set_loops()`, never `self`-bound, or a freed node throws "Infinite loop detected." Every breathe/pulse/idle loop obeys this.

### Duration scale (one ladder)
`INSTANT 0.06s` · `SNAP 0.09s` · `BASE 0.18s` · `PAGE 0.22s` · `LUX 0.6s` (idle loops) · beat durations from the BeatSpec table (S ≤0.2 / M ~0.4 / L ~0.8 / XL ~1.4). Counters scale 0.3–1.2s with gain size.

### Screen-shake budget & rules
- Single trauma accumulator on `FX`. `shake = trauma²`. **Hard cap trauma ≤ 0.30** (cozy, never violent).
- Shake is **opt-in per event** and reserved for L/XL impacts (clear, room-reveal, chest, big stamp). Merges/slides never shake. Invalid never shakes (it head-shakes the piece instead).
- Shake offsets the `FXLayer` root, which must remain `PRESET_FULL_RECT` and respect safe-area so it never reveals letterbox edges.

### Particle budget
- One pooled emitter set behind `FX.burst`. **Per-event ceilings: S ≤6 · M ≤24 · L ≤60 · XL ≤120.** Global concurrent particle ceiling enforced in `FX` (drop-oldest if exceeded). Reduce-motion = ×0.4 and confetti off.

### Flash / color feedback language (non-color-redundant)
- **Gold** = reward/coins/mastery · **Mint** = new/unlocked/quest-good (`Palette.GOOD`) · **Peach** = warmth/nudge/attention · **White (1-frame)** = tier-up bloom only · **Cool blue** = reachable/move.
- **Invalid is NEVER red** — it is a kind head-shake + desaturate + `invalid_soft`.
- **Colorblind redundancy (load-bearing):** the green merge-ring vs blue move-ring distinction also carries a SHAPE difference — **green = solid ring, blue = dashed ring**. Celebration semantics never rely on hue alone (gold reward = coin glyph, mint new = NEW ribbon, etc.).

### Time-scale rules
- One refcounted `Flow.time_dip` owner so overlapping L/XL celebrations never double-dip or restore early. Dips: L=0.85, XL=0.7, each ≤0.4s, tween-restored.
- Any tween that must stay real-time during a dip sets `set_ignore_time_scale(true)` (transitions, audio-synced tweens).

### Audio rules
- Music in C; merges drawn from a pentatonic set so they consonate (key-of-C constraint is lux — v1 ships the crossfade + pitch param only).
- One refcounted `Audio.duck` (−6dB, ~900ms tails) so concurrent stingers never early-restore the music.
- ±2-semitone random pitch on repeated dings/pops. 600ms equal-power crossfades between screen beds.

### Haptic ms table (the ONE table)
| Weight | ms / pattern | Used for |
|---|---|---|
| `LIGHT` | 10ms | pickup, button, slide-stop, per-step tick |
| `SOFT` | 15ms | invalid nudge (×2 soft), hover-confirm |
| `MED` | 25ms | T3–4 merge, decor thunk, stamp, unlock |
| `STRONG` | 40ms | showcase, new-location reveal |
| `SUCCESS` | 2×20ms + gap | L/XL payoff peaks (clear, room complete, chest) |

`vibrate_handheld` for v1, behind `FX.haptic()`; gated by `Settings.haptics`; OR-ed with OS reduce-motion/low-power at boot. Graded Core-Haptics shim slots behind the same API later.

### Performance guardrails (mobile / iPhone portrait 1080×1920)
- Pool everything reusable: coin sprites (cap 60), ghost trails, confetti, dust, rings, floaters, toasts. No per-event `instantiate` in hot paths.
- Idle loops pause when their screen is hidden. Background → master −80dB; pause non-essential `_process`.
- Shaders (dissolve, iris, shimmer) are lux-flagged; every shader has a non-shader fallback (scale-fade+spin for dissolve, soft-fade for iris) so low-end and shader-compile stalls never block the loop.
- `GPUParticles2D` presets pre-warmed; avoid spawning >1 XL particle load per frame (the celebration queue serializes anyway).
- Safe-area handling for every full-screen surface (board, map, home, hub tabs, quest tray, toasts, FXLayer): respect top notch + bottom home-indicator.

### Reduced-motion / accessibility parity (one switch)
- ONE canonical `Settings` source, read once at boot, **OR-ed with OS reduce-motion**. A single **"Calm Mode"** preset toggles the lot: shake→0, overshoot halved, idle-breathe + shimmer + parallax + time-dips OFF, confetti OFF, glows fade (not bloom), particles ×0.4, haptics→single MED or off, top sparkle SFX layer dropped, optional-star miss UI hidden.
- **Pure-solver parity:** every spectacle is opt-out-able and nothing in the celebration path ever *blocks* — any tap fast-forwards to end-state within one frame (HARD INVARIANT across board, chain, and meta animations).
- Colorblind shape-redundancy (above) is on whenever `Settings.colorblind` is set; the green/blue ring tell never depends on hue.

---

## Core Juice — the non-negotiable minimum that makes it feel alive

If only this ships, the game already *feels* like Tidy Up. Everything else is escalation on top.

1. **Pickup pop + lift + snap-back home** — the piece is a physical object you hold.
2. **Distance-graded slide** (wind-up squash → overshoot settle → whoosh + LIGHT haptic) — routing has weight and reward.
3. **Slot receive-squash** (pocket squash + dust + drop SFX) — every landing is satisfying.
4. **Merge-ring telegraph** (green solid = merge / blue dashed = move, merge dominates) — the verb is legible and colorblind-safe.
5. **Tiered merge pop + tier-up cross-fade morph** (`_juice_for_tier` drives pop/particles/SFX/pitch/haptic) — fusion reads as fusion, escalating by tier.
6. **Showcase "put away"** (lift + dissolve fallback + gold bloom + rising motes + `tidy_poof` + STRONG haptic) — the top-tier payoff.
7. **Soft-no invalid** (kind head-shake + desaturate + `invalid_soft`, never red) — the can't-lose pillar made tactile.
8. **All-tidy chain** via `Flow.chain_level_clear` (impact dip → veil + title drop → star sequence → coin count-up → reward line → tap-to-continue), **skippable to end-state on any tap.**
9. **Coin payout fly-out + wallet count-up** (`FX.fly` + `FX.ticker`) — earning is visible and banked.
10. **First decor reveal** (drop-in → settle squash → place thunk → warmth retint → restoration bar fill) — the "fund my home" emotional hook lands.
11. **Next-beat preview card** — the one-carrot rule; the reason to come back.
12. **Scene soft-fade transitions + button press/release** — no hard cuts, every tap answers.
13. **The S/M/L/XL beat grammar + reduce-motion parity + ≤0.30 shake cap** — the discipline that keeps all of the above proportional, cozy, and accessible.

These 13 are the spine. The `nice` tier makes it polished; the `lux` tier makes it a showpiece — and per the Shared Primitives map, none of them re-implement each other.

---

## Appendix — how this spec was produced

- **Design fan-out (12):** 6 juice domains (board-merge feel, flow/celebrations, reward/economy juice, meta/home juice, UI micro-interactions, audio/haptics) + 6 systems (economy/progression, quests, levels/difficulty, meta/narrative/home, save/progress architecture, retention/FTUE).
- **Adversarial review (5):** cohesion & fun, scope & feasibility, retention & economy, chill & zero-learning integrity, completeness critic. **54 problems raised** and folded into the synthesis above.
- **Synthesis (2):** lead designer (this spec) + juice lead (the catalog).
- Raw juice items collected before dedupe: **225**.

### Reviewer-flagged items to defer past v1
- The cosmetic gacha 'Mystery Crate' (Economy §3d) — randomized pulls are tonally off for a cozy can't-lose game and add a whole reveal/dupe/refund subsystem. Ship a flat coin-priced rotating cosmetic shop instead; defer or kill the gacha.
- Business-upgrade idle income / Tip Jar (Economy §4b) — the 'idle' beat fights the 'solve to earn' core, the memory note literally says 'No full idle,' and it competes with renovation for early coins. Cut idle for v1; keep the 'growing my business' fantasy as simple coin-cost earning multipliers unlocked AFTER the first room.
- All XL/lux juice: dissolve shaders, cozy iris wipe, shared-element morphs, ambient pet, depth parallax, time-of-day, seasons, photo/admire mode, milestone-collection fanfare, layered fanfare stems. These are correctly tagged lux and can be dropped wholesale without touching the loop. v1 needs the core/nice tier only.
- The second/third currencies (Gems, Stars-as-ticket, Lumen) — every facet already says defer Gems and keep Stars as prestige; make v1 single-currency (coins only) and Stars a pure display record, NOT a spendable renovation ticket. The Stars-as-ticket idea is the one thing that risks the can't-lose pillar; cut the spend.
- Procedural level generation + offline solver pipeline (Level-System §2b) — PIVOT_PLAN already says the solver work is ~80% unnecessary. v1 ships the ~40-60 authored spine levels + a CURATED daily rotation (Retention flags this too). Defer the generator entirely.
- Three of the four quest layers' UI surfaces for v1 launch: ship the per-session micro-chips + the job/story spine (the two that carry the loop) and the daily-gift/streak (the return hook). Defer the milestone/collection trophy wall and the full daily-quest TAB until after the core loop is proven — the 'one carrot' rule means a player won't miss layers they can't see yet.
- Local re-engagement notifications (Retention §7) — needs a native iOS shim, is the easiest thing to get tonally wrong (guilt-bait), and is pure retention optimization that adds nothing to whether the loop is fun. Defer to post-v1; ship only the in-app next-beat preview.
- Cloud-save seam, analytics ndjson pipeline (Save facet) — keep the reserved fields (device_id/rev/updated_at) per the seam design so it's not a migration later, but build zero cloud/analytics code for v1. Local atomic save only.
- CUT the procedural level generator entirely from v1. Ship hand-authored levels only (the existing levels.gd shape, ~30-40 authored boards). Par stays hand-typed or derived from construction length. No reachable_state_count, no solver par, no Daily generation — Daily = curated rotation of authored boards. This removes the single biggest engineering risk (the intractable BFS) and the PIVOT_PLAN already blessed this.
- CUT to ONE room (existing bedroom) with ~5-6 fixed decor slots, NO style variants, required_slots < total. Defer Living Room/Kitchen/Garden/Studio, all variant choices, and the whole biome/District ladder. Removes ~60 of ~77 Meta art assets.
- CUT the recurring-client cast + portraits. v1 narrative = Wren (one reusable bust) + text-only one-line client thank-yous. Defer the 18-client roster and per-client portrait art.
- CUT the second currency (Gems/tickets) and ship gems_enabled=false — also cut Stars-as-spendable-ticket; make Stars pure prestige display in v1 (avoids the can't-lose gate-feel risk and one whole spend path). Renovation costs Coins only.
- CUT idle/offline income and the Tip-Jar business line (contradicts 'No full idle'). v1 'welcome back' = Daily Gift only. Keep at most ONE business upgrade line (Rates) if any, or defer the whole Tidy Co. panel to v2.
- CUT the lux audio layer wholesale for v1: no pentatonic combo ladder, no key-of-C consonance constraint, no bus-ducking, no density limiter, no layered fanfare stems, no Core Haptics plugin. v1 = 3 music loops + ~6 new one-shot SFX + Input.vibrate_handheld behind a toggle.
- CUT all ambient/atmospheric lux from Meta/Home: the cat, tilt parallax, time-of-day grade, seasonal accents, Admire/Photo mode. These are correctly lux-tagged; none are load-bearing for the solve->earn->renovate emotional beat.
- CUT shared-element morph transitions, cozy iris-wipe shader, and dissolve/shine shaders from v1 (keep behind a lux flag). v1 transitions = the SOFT_FADE veil only. Scale-fade+spin is a fine showcase fallback vs a real dissolve shader.
- CUT the milestone/collection/trophy layer and the long-arc achievement counters from the Quest system v1. v1 quests = the 3 session micro-goals (HUD chip row) + 3 daily + the authored job/story spine. Three layers, not four.
- CUT the cosmetic gacha 'Mystery Crate', rewarded-ad chests, and the rank/level-up XL fanfare from v1. The chest/reveal juice is real work; v1 reward surface = coin-fly + count-up + star-pop + the next-beat preview card (all cheap extensions of the existing _play_zero).
- Gems / second currency / all IAP — ship gems_enabled=false as the draft already proposes, but go further: cut the gem→coin conversion, premium decor variants, and Founder's Crate from v1 entirely. A clean coin-only fairness launch removes a whole balance-and-pricing surface and lets the core loop prove itself first.
- Business-upgrade panel ('Tidy Co.') and ALL idle income — defer to post-launch. It's the most balance-fragile system (Tip Jar curve bug, flywheel-onboarding contradiction, competes with renovation for early coins) and the LEAST necessary for the core solve→earn→renovate loop. Cutting it removes the entire idle-income retention-curve risk and one of the two colliding early sinks. Re-introduce once the renovation cadence is tuned against real data.
- Two of the four quest layers — keep session micro-goals + one merged 'Today' daily bundle; defer the milestone/collection trophy layer's UI (counters accrue silently). This directly resolves the notification-fatigue risk and the draft's own open question.
- Cosmetic gacha 'Mystery Crate' — defer. It's the infinite-sink for maxed players, which is a problem you don't HAVE at launch (not enough content to max out). Ship it when the late-game saturation it solves actually exists; v1's sink is renovation + biome unlocks, which is plenty.
- Procedural/daily-puzzle generation as a coin faucet — the memory + PIVOT_PLAN note the solver work is ~80% unnecessary and there's no generator yet. For v1 make the Daily Job a curated rotation of authored boards (Retention facet already proposes this as the fallback). Cuts the offline-solver pipeline AND keeps the daily faucet predictable for balancing.
- Rewarded-ad caps beyond a single placement — ship ONE rewarded placement (the 'tip jar' double-or-flat) at a low cap (≤3/day) for v1 rather than three (tip jar + booster refill + bonus crate pull). Fewer ad surfaces = simpler faucet to balance and a cleaner fairness story.
- Star-as-spendable-ticket — for v1, make Stars PURE prestige (record only, not consumed by renovation tasks) and fund renovation with coins alone (the Economy facet's own open question floats this). This eliminates the entire Star-supply-vs-demand-becomes-a-soft-gate risk and keeps the can't-lose pillar unambiguous. Re-add the ticket mechanic later only if the coin-only loop feels too frictionless.
- Cut Bomb, ×2 token, Producer, and Countdown-gift toys from v1 (and ideally permanently from the main track) — they are new rules / time-pressure, violating zero-learning and relaxed. Keep only Wild, and re-base the content drip on new families + biomes/art.
- Ship Gems fully dark (gems_enabled=false, no IAP) for v1 — already proposed by Economy; lock it in to keep the fairness story obvious and the currency count at one.
- Make renovation COINS-ONLY for v1; demote Stars to pure prestige + a coin-bonus multiplier. Cut Stars-as-spendable-ticket entirely.
- Defer Business upgrades / 'Tidy Co.' (all four lines incl. idle Tip Jar) until after the first location is complete, and cut idle/passive income for v1 pending the 'no full idle' owner confirmation.
- Defer milestone/collection sets and lifetime achievements (the Trophy wall) past v1 — they add persisted surface and a screen without serving the core tidy→earn→decorate loop early.
- Cut the booster-forfeits-star mechanic entirely (not just defer) — it's a pillar violation regardless of timeline.
- Cut the daily-quest-set chest as a SEPARATE surface from the daily gift ladder for v1 — merge into one daily reward surface to reduce card-stacking and clock count (Retention's own open question).
- Defer the cosmetic gacha 'Mystery Crate' past v1 — a 250-coin pull with dupe-refunds is casino-adjacent surface that isn't needed to prove the cozy loop.
- Defer XL fanfares (rank-up odometer, milestone 3-stem fanfare, light-rays) and the rewarded-ad chest cadence — keep v1 celebrations at S/M/L only so the grammar stays gentle and the audio-asset burden (a brand-new asset class per memory) stays small.
- Defer accelerometer/tilt parallax, ambient pet, photo/Admire mode, seasonal accents, time-of-day grade (all already lux/nice) — none serve the core payoff and several risk motion-discomfort.
- Cut districts 4-5 (Plants/Kitchenware) and ship v1 with the 3 existing families/3 districts mapping to the art that already exists — defer the 2 new families' ~10 tier assets + their districts to a content milestone.
- Cut all lux-tier ambient/world theater for v1: ambient pet, decor parallax/tilt, time-of-day color grade, seasonal accents, world-map travel route-draw, and photo/admire mode. Keep the per-slot decor drop+settle morph and the Room Complete beat — that's the proven retention core.
- Defer the second currency (Gems) and ALL IAP to post-v1 (ship gems_enabled=false), per the spec's own demote-second-currency decision — removes the entire monetization-surface gap from v1 scope.
- Cut the combo/streak ribbon and combo pitch-ladder for v1 (both sections flag it as a relaxed-pillar risk and an open question) — ship quiet single-merge feedback; add combo later only if playtests want it.
- Defer the cloud-save seam entirely (keep only the reserved device_id/rev/updated_at fields) and the analytics NDJSON pipeline — local atomic save + bak is enough for v1.
- Cut local re-engagement notifications from v1 (Retention's own open question doubts the native shim budget); ship only the in-app next-beat preview card. Add notifications in a later milestone with the same next-beat copy.
- Defer the Expert/Tricky-jobs track and the runtime procedural generator; v1 ships the authored spine + a curated daily-job rotation (Retention's own fallback) — avoids the offline-solver-bake pipeline entirely for launch.
- Cut the iOS Core Haptics plugin for v1; ship vibrate_handheld-only with the coarse light/medium/heavy mapping (all 4 sections accept this as the likely v1 fallback) — add graded Core Haptics later.
- Defer dissolve/iris/shine shaders (all lux-gated already) — ship the scale-fade+spin fallbacks so v1 runs on low-end with zero shader-compile risk.
- Cut business-upgrade idle income (Tip Jar / offline accrual) from v1 — the memory note says 'No full idle,' and it adds clock-edge + persistence surface; ship the other 3 business lines (Rates/Tool Bench/Reputation) which are pure active-play sinks.
