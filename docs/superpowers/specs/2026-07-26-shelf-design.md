# The Shelf — comeback lines (progression step 1)

**Date:** 2026-07-26
**Status:** draft for Dev review. Expands §2 of `2026-07-26-progression-systems-design.md`
(rollout step 1 of its §8). Companions: that doc · `docs/design/picturebook_lines_recipes.md` ·
`engine/scripts/core/content.gd` §6 (the shipped window + retirement).

Every level quoted below is today's **derived** cadence — `[1, 15, 29, 33, 38, 42, 46, 51, 55,
60, 65, 69]`, pinned in `engine/tests/tuning_tests.gd:72` — and moves whenever `SCENE_END_LEVEL`
is retuned. Implementation artifacts (code, tests, strings with numbers) must always derive via
`G.zone_unlock_level(z)`, never pin literals; `grove_board_actions_tests.gd:249-256` is the idiom.
Three shipped prose comments still quote the pre-2026-07-26 cadence ("L11/L22/L33") — see §15.

## 1 · The problem

When a line's zone rolls out of the 3-zone active window, nothing happens to its stuff. The
generator fades (`board.gd:1597`, "it can still pop — free while faded"), its pieces grey out
(`board.gd:1623`), and everything sits on the board until the line's next craft era — or forever:

- **Board pollution is the default.** The only automated sweep that exists is the retirement
  offer, which fires exactly three times per playthrough (`gen_1` at L33, `gen_6` at L55,
  `gen_16` at L69). Every other idle stretch — Woolens' L46–50 gap, Snow & Ice's L51–59 gap, the
  three-line exodus at L65 — leaves dead generators and unusable mid-tier stock occupying cells
  of a 63-cell board.
- **One line strands with no exit at all.** Retirement is generator-scoped
  (`G.gen_retirable`, `content.gd:412`, guards on `ZONE_BASE_LINES`), but **Winter Berries
  (line 5) is a crafted special with no generator and appears in no recipe** — it is dead the
  moment its window closes at L51, yet no offer ever fires and its stock greys out permanently.
  The board/bag can only shed it through the per-piece sell button.
- **Nothing narrates the arc.** A line's story just stops: no goodbye, no promise of return. The
  player can't tell "resting until the Spices era" apart from "junk".
- **Nothing observes the transition.** There are no signals anywhere in `engine/scripts/`
  (no autoloads, no `signal` declarations); every "is this needed?" read is a stateless derived
  predicate. The Shelf introduces the repo's first persisted per-line state, so the spec must
  name its seams exactly.

## 2 · The three states, formally

Per **zone line** (the 12 lines of `ZONES`, `grove_data.gd:112` — treats 71–75, coins and
special drops are exempt from all of this). Let `expand(w)` be the recursive ingredient closure
of line `w` (the shipped `_add_needed_line` recursion, `content.gd:241`), and

```
closure(z) = ∪ { expand(w) : w ∈ zone_window_lines(z) }
```

| State | Predicate (all derived, level-keyed) | Where its stuff lives |
|---|---|---|
| **Active** | `line ∈ closure(current zone)` | board (+ bag as the player likes) |
| **Comeback** | not Active, and `∃ z' > current zone: line ∈ closure(z')` | the Shelf |
| **Done** | `∀ z' ≥ current zone: line ∉ closure(z')` | the Shelf, with a Retire button, until the player clears it |

New pure reads in `content.gd` §6, beside their ancestors:

- `line_needed_at_zone(line, z) -> bool` — `line ∈ closure(z)`. (`needed_gens`,
  `content.gd:403`, is its generator-keyed projection.)
- `line_retirable(line, level) -> bool` — the Done predicate: the **line-scoped
  generalization of `gen_retirable`**, same finite scan ("one probe per remaining zone covers
  every future level", `content.gd:418`), minus the base-line guard. `gen_retirable` keeps its
  signature and callers and delegates to it. This is what closes the Winter Berries hole: line
  5 is `line_retirable` from L51 even though no `gen_5` exists.
- `next_need(line, level) -> Dictionary` — scan zones after the current one; first `z'` with
  `line ∈ closure(z')` returns `{level: zone_unlock_level(z'), for_line: w}` where `w` is the
  first window line (window order) whose expansion contains `line`. Empty dict when Done.
  Powers every promise string.

Granularity decision: the state is a function of the **zone**, not of the live fence.
`quests.refill` keeps all three window lines represented on an 8-stand fence, so an ingredient
line is effectively needed for the whole of its borrower's window span; keying the state to
individual live asks would flicker a line Comeback↔Active many times inside one zone (a card
and a sweep each time). The parent doc's "the last live ask that borrowed it resolving" is
honored as an *ordering* rule instead: the transition is evaluated only after the post-level-up
quest cull (`quests.gd:152`, the only code that already reacts to window exit) has removed the
borrower's stands, so a sweep can never race a live ask. "Craft era" in the parent = the
borrower's window span, and each era end is one clean transition.

## 3 · The arc, concretely

What the shipped roster produces (the spec's worked example and the test fixture — asserted
symbolically, per the derived-levels rule):

| Level (zone) | Event | Card |
|---|---|---|
| L33 (z3) | Glow-mushrooms Done | retirement (shipped event, re-homed card) |
| L46 (z6) | **Woolens → Shelf — the first sweep** | *"The Woolens will be back at Level 51, for Spices."* |
| L51 (z7) | Woolens return (Spices era) · Snow & Ice → Shelf · **Winter Berries Done (new event)** | *"…back at Level 60, for Corals."* · retirement |
| L55 (z8) | Desert Fruits Done | retirement |
| L60 (z9) | Snow & Ice returns (Corals era) | — |
| L65 (z10) | **Wild Berries, Woolens, Spices → Shelf** (the 3-card roll) | each: *"…back at Level 69, for Tea Cups."* |
| L69 (z11) | all three return for the final window · Shells Done | retirement |

Post-arc (z11, frozen window): every zone line is either in `closure(z11)` =
{2, 3, 4, 7, 8, 17, 18, 19} — Active forever — or Done (1, 5, 6, 16). **No line is ever in
Comeback again**, so the Shelf drains to empty through normal pulls and retirements: it is the
arc's traffic system, not a permanent hoard (parent §2). The full per-line table is in the
appendix.

## 4 · Persisted state

Four new keys in the grove blob, all default-on-read, **no `SCHEMA_VERSION` bump** (the house
idiom — deep-merge over defaults, `save.gd:98`; `retire_declined` at `board.gd:3961` is the
per-line precedent):

| key | shape | meaning |
|---|---|---|
| `shelf` | `Array[int]` item codes | swept stock, exactly the `bag` idiom (`board.gd:150`) — aggregation into per-tier chips happens at render |
| `shelf_gens` | `Array` of `[id, tier, boost]` | swept generators, investment preserved (mirrors the `gen_bag ∥ gen_bag_tiers ∥ gen_bag_boost` lockstep discipline, `board_model.gd:17-25`, in one array of triples) |
| `shelf_parked` | `{ str(line): true }` | "this line's current gap has been processed" — the transition edge memory (§5) |
| `retired` | `{ str(line): true }` | written on retirement accept; the future Collection's ledger (`docs/BACKLOG.md:106`) |

Load joins `_load_state`'s accumulate-dirty pattern (`board.gd:824`): sanitize `shelf` like the
item bag (`_sanitize_saved_item_bag`, `board.gd:697` — drop invalid codes), sanitize
`shelf_gens` (known gen id, tier clamped), and extend `_purge_above_level_content`
(`board.gd:774`) to cover `shelf` as its fifth collection (drop codes whose line is
`G.line_gated_out`). Both sweeps and pulls end at `_after_board_change()` (`board.gd:1011`),
the mandatory post-mutation beat.

## 5 · The transition engine

One idempotent evaluation, pure in `board_actions.gd` (the `retire_line` template — statics
over `(board, bag, shelf…)`, scene passes state in and out):

```
sweep_due(board, bag, shelf_parked, level) -> Array of {line, kind, has_presence}
```

For each zone line: if Active → erase its `shelf_parked` mark (its gap is over). Otherwise, if
not parked → this is a transition: `kind` is `"retire"` when `line_retirable`, else
`"comeback"`; `has_presence` is whether the line has any generator or stock on board or in bag.
The scene turns transitions into a **farewell queue**: presence → show the card (§6), then
sweep on close and park; no presence → park silently (nothing to say goodbye to).

Evaluated at two seams, both calm:

1. **After the level-up ceremony closes** (`LevelPopup`'s collect callback, the consumer at
   `board.gd:3795-3806`), and explicitly after `_refill_quests()` has culled the old zone's
   stands — the sweep happens when the era visibly ends, chained behind a modal the player is
   already in. Queued cards chain one at a time (the L65 roll shows three).
2. **On board entry**, deferred — the same seam as the shipped retirement offer
   (`board.gd:392`, "a calm moment — board entry, never mid-gesture"). This is also the whole
   **migration story**: an existing save's first entry parks and sweeps every currently-idle
   line in one chained pass; a line already declined (`retire_declined`) sweeps silently, no
   card. No other migration is needed — the new keys default empty.

Levels only ever change on the home board (`G.earn_coins` is called from `deliver_quest`
alone, `board_actions.gd:33`), so these two seams are exhaustive. The Rush board keeps its own
rules and never touches any of this (parent §4 precedent).

## 6 · The farewell card

**One component, both variants** (parent §2): `engine/scripts/ui/farewell_card.gd`, absorbing
and deleting `retire_offer.gd` (which is already its ancestor — `Overlay.modal` +
`Kit.dialog_frame` + `PieceView.make_piece(line*100+1)` + one body label + one CTA,
`retire_offer.gd:55-106`; keep its `min_h` floor and boxed-`confirmed` dismiss pattern).

| | Comeback | Retirement |
|---|---|---|
| banner | *"See you soon"* | *"All done here"* (shipped key) |
| body (one line) | *"The Woolens will be back at Level 51, for Spices."* | *"The Glow-mushrooms' story is complete — %d coins join your purse."* |
| CTA | **OK** | **Retire** |
| veil-tap / ✕ | same as OK — the sweep is not a choice | decline: sweep to Shelf, remember `retire_declined` (§10) |

On close (any path), the sweep executes and the pieces fly (§7). Copy lives in
`strings.json` under a new `shelf.*` block plus a reworded one-line `retire.body`
(`strings_tests` scans every `Strings.t` literal, so keys land with their callers). Names and
levels are always interpolated — `G.LINES[line].name`, `next_need(...)`.

## 7 · The sweep

Pure static `sweep_line(board, bag, shelf, shelf_gens, line) -> outcome`, the value-neutral
sibling of `retire_line` (`board_actions.gd:141`):

- **Board stock** of the line → `shelf` (every non-coin item code, `board.take` per cell).
- **Bag stock** of the line → `shelf` — same scope as `retire_line`, and it frees paid bag
  slots (the bag is the pressure-relief valve, `board_actions.gd:117-119`; dead stock taxing
  it is exactly what that comment warns about). Flagged for confirmation, §16.
- **Every generator copy** (board cells and `gen_bag` entries alike, the `retire_line`
  traversal) → `shelf_gens` with tier and boost preserved.
- **No coins move, no clock moves, nothing is destroyed.** The sweep is storage, not a sale.

Stock the player later pulls back stays out until used or until the line's *next*
Active→Comeback edge — the sweep only ever fires on the transition (§5), which is also why
"parked" is per-gap, not per-piece.

FX: the shipped fly-to-well arc (`FX.reward_arrival`, target `bag_btn` — the exact
`_stash` call at `board.gd:3658`), one flight per piece, caller-staggered ~60 ms apart,
generator last, ~1 s total for a typical sweep; `fx_id: "sweep_to_shelf"` registered in
`REWARD_FX_IDS` (`fx.gd:25`) so the workbench can toggle it. Then the standard
`floating_text` one-liner.

## 8 · Return

**Generators come back by themselves — the shipped path, upgraded.** `Quests.due_gen`
(`quests.gd:71`) already walks the ingredient tree and births a missing generator on the next
generator tap (`board.gd:2973` → `produce_due_generators`, `board_actions.gd:69`).
`shelf_gens` stays **out** of `due_gen`'s owned set (board ∪ gen_bag, `quests.gd:56`), so the
need is still detected; `produce_due_generators` gains one step — **restore from `shelf_gens`
(tier + boost intact) before minting a fresh tier-1**. Board full falls back to `gen_bag`,
exactly like the shipped birth (`board_actions.gd:82`). No new player verb: the era opens, you
tap, the tool steps back off the Shelf.

**Stock is pull-based, and only stock.** In the Shelf surface (§9), tapping a tier chip places
one piece of that tier onto the first empty ground cell — the `_retrieve_from_bag` mechanics
(`board.gd:3678`: place, pop-in tween, `bag_out`, `_after_board_change`). Two deliberate
deviations from the bag's tap-to-retrieve:

- **The panel stays open** and the chip count decrements — pulling several pieces is the
  normal case. (The bag's unconditional `dismiss` after one tap, `bag_overlay.gd:159-162`,
  stays as-is for the bag.)
- **A full board refuses in place**: chip wobble + `invalid_soft`, panel still open — not the
  bag's silent close (the gotcha at `bag_overlay.gd:159`).

Pulls are free and unlimited. The Shelf never produces: no popping shelved lines, no passive
growth (the ripening shelf is explicitly superseded, parent §9) — **the Shelf stores and
labels, nothing more.**

## 9 · The Shelf surface

**Where:** inside the existing bag panel — **a Shelf section under the slot grid**, next to
the generators section that already rides the `extra` slot (`bag_overlay.gd:191`,
`Kit.bag_generators_section`, `ui_kit.gd:6227`). No new nav entry (parent §2), no new modal.

This deviates from the parent's "two-tab panel" on presentation only, for three reasons
(flagged §16): the codebase has **no tab scaffold anywhere** and the shop already tried tabs
and removed them for one scrolling sheet (`shop.gd:130-132`); the Shelf is **empty until L33
at the earliest** (a declined Glow-mushroom retirement) and typically until the first comeback
sweep at L46 — a permanent second tab is dead chrome for the first half of the arc, while a
section simply doesn't render until it has rows; and one sheet keeps bag ↔ shelf
drags/glances in one place.

**A shelf row** (a `ui_kit` builder, stateless, all data and actions injected via `cfg` — the
`bag_overlay` layering rule, `ui/` never imports `scenes/`):

- the line's tier-1 piece icon (`PieceView.make_piece` — works for specials, which have no
  generator art; reserves the spot where step 2's mastery trim will land),
- count-per-tier chips — a mini piece face + count, tap = pull one (§8),
- the one-line promise in small text — Comeback: *"Back at L51 · for Spices"*; a line whose
  era is running: *"Needed now · for Tea Cups"*; a Done line swaps the promise for a
  **Retire** button opening the farewell card (§10).

Rows sort by `next_need` level ascending, Done rows last. Section hidden when the Shelf is
empty. The bag well's `x/y` count label and capacity are untouched — shelf stock never
consumes bag slots. No badge on the well (the sweep FX flying into it is the teach; revisit
only if playtests miss it). The ui-workbench gains a fixture-driven twin of the section beside
its existing bag mirror (`ui_workbench_view.gd:705`), same as every other kit surface.

No FTUE dialog: the first card is one self-explaining line, and the sweep FX shows where
everything went.

## 10 · Retirement, re-homed

Semantics preserved, surface unified, one real change:

- **Trigger** stays board entry (`_maybe_offer_retirement`, `board.gd:3938`), now emitting the
  farewell card's retirement variant instead of `retire_offer.gd`. The offer set becomes
  line-scoped (`line_retirable` over lines with presence *or shelf stock*) — which is how
  Winter Berries finally gets its goodbye.
- **Accept** runs `retire_line` (`board_actions.gd:141`) extended with the Shelf as a third
  source: `retire_preview` ("THE ONE payout read", `board_actions.gd:125`) prices board + bag
  **+ shelf** stock; `retire_line` drains all three, removes `shelf_gens` entries, writes
  `retired[line]`, clears the row. Payout stays `Save.add_coins` — spendable only, never the
  clock (`board_actions.gd:188`).
- **Decline** now **sweeps to the Shelf** instead of leaving the line rotting on the board —
  the row keeps its Retire button forever, `retire_declined` still suppresses re-offers
  (`board.gd:3959`). This replaces the info-bar as the fallback: after a sweep there is no
  on-board generator to select, so the Shelf row *is* the manual path. The info-bar
  sell/retire button (`board.gd:2224-2240`) keeps working for the on-board window before any
  sweep, and for redundant generators, unchanged.
- **After retirement** the line simply has no presence anywhere; its `seen` ledger and
  `retired` mark wait for the Collection almanac (backlog, out of scope).

The shipped one-offer-per-entry throttle generalizes to "the farewell queue chains at calm
seams"; per-line the card still fires at most once per gap (parked) and a retirement offer at
most once ever (declined). It is an offer, not a nag.

## 11 · Laws (cross-cutting, asserted in tests)

- **The game is completable without ever opening the Shelf.** Crafts consume same-tier pieces
  poppable from re-birthed generators; shelf stock is a head start, never a requirement. (The
  no-strand guarantee: `due_gen` reaches every ingredient generator of every future window —
  asserted structurally per zone.)
- **The clock is quests only** — sweeps move no coins; pulls are free; retirement payouts stay
  spendable-only. (The caps-lock test lines: "SWEEP NEVER ADVANCES THE CLOCK", ditto retire.)
- **The sweep is value-neutral and lossless** — the piece multiset survives a sweep → full
  pull-back round trip, and generator tier/boost survive a sweep → restore round trip.
- **Only the Active→Comeback/Done edge sweeps.** Hand-pulled stock is never re-collected
  mid-gap.
- **Shelf stock never occupies bag slots** and never counts against bag capacity.
- **Weather/Rush untouched**; home board only.

## 12 · What does not change

- The window and cadence machinery (`active_lines`, `zone_window_lines`, `_build_cadence`) —
  the Shelf only *reads* them.
- `gen_retirable`'s signature and callers (it delegates to `line_retirable`).
- The quest cull ("a quest retires with its line", `quests.gd:145`) and fence composition.
- The bag: capacity, slot pricing, manual stash/retrieve, the generators section, drag-to-well.
- `due_gen`'s owned-set semantics and the anchor stranding guard (`quests.gd:72-77`).
- Sell pricing (`sell_reward`, `content.gd:1220`) and the sell-never-feeds-the-clock law.
- Save schema version (additive keys only).

## 13 · Testing

New focused suite **`games/grove/tests/grove_shelf_tests.gd`** on `grove_test_base.gd`, added
to `GROVE_TESTS` in the Makefile **and to the suite list line in `CLAUDE.md`** (it says to keep
them in step). All levels derived (`G.zone_unlock_level`), never literal:

- **Predicates:** `line_needed_at_zone` / `line_retirable` / `next_need` across the whole arc
  table of §3/appendix (the `mechanics_tests.gd:651` idiom — one asserted row per zone);
  `gen_retirable` unchanged for all 8 base gens; Winter Berries retirable from z7's level;
  specials' `next_need` names the right borrower (`for_line`).
- **Sweep:** builds the L65 fixture (open terrain, the three lines' gens + mixed-tier stock on
  board and bag) → `sweep_due` returns exactly the three transitions → `sweep_line` moves
  every piece and generator (tier/boost preserved), coins and clock untouched, board cells
  empty, bag slots freed.
- **Pull:** places to first empty cell; full-board refusal leaves shelf intact; the lossless
  round-trip law (§11).
- **Return:** `produce_due_generators` restores the shelved tier-2 generator (not a fresh
  tier-1); board-full restore lands in `gen_bag`.
- **Retirement:** preview and payout include shelf stock; accept drains all three sources and
  writes `retired`; decline sweeps and persists `retire_declined`; "RETIREMENT NEVER ADVANCES
  THE CLOCK" stays.
- **Save:** sanitizers drop invalid shelf codes / unknown gen ids; `_purge_above_level_content`
  covers `shelf`; defaults load empty on an old save (no schema bump); catch-up entry on a
  seeded mid-arc save parks + sweeps every idle line once, silently for declined ones.
- **Scene wiring** (in `grove_explore_tests`, where the shipped offer wiring lives): entry
  evaluation fires the chained cards; level-up seam evaluates after the refill cull.
- **UI** (in `grove_ui_workbench_tests`): shelf section structure — rows sorted, tier chips
  aggregate counts, Done row shows Retire, section absent when empty. Plus a `grove_shot`
  fixture mode (`MODE=shelf`) for the visual check via `make shot-grove`.
- `make test-fast` after every change; `make test` before handoff. No `grove_sim` re-pass
  required for this step (parent §8) — the sim's invariants must simply stay green.

Build order for the plan (each lands green): content predicates + tests → save keys +
sanitizers → pure sweep/pull/retire extensions + tests → scene seams + farewell card →
bag-panel section + workbench twin → FX polish + shot mode.

## 14 · Out of scope

- Mastery trims, meters, rings (step 2 — the row reserves the icon spot).
- The Collection almanac (backlog; `retired` + `seen` are its feed).
- Weather, combos, improvements (steps 3–5).
- Any Shelf-side production or growth (ripening superseded — parent §9).
- A bag-well badge; new nav chrome; tabs (unless §16.1 lands the other way).
- Rebalancing bag slot prices or sell bands.

## 15 · Corrections to the parent design (fold into its next rev)

- §1/§2 examples: retirement fires at **L33 / L55 / L69** on today's cadence (not L11/22/33 —
  that's the pre-re-spine cadence, also stale in `content.gd:397-399` and `retire_offer.gd:13`,
  chip already filed). The wildberries example should read *"back at **Level 69**, for **Tea
  Cups**"* — Wild Berries' only gap is L65–68; the first comeback line is actually **Woolens at
  L46** ("back at Level 51, for Spices").
- §2's Retired row cites `G.gen_retirable`; this spec generalizes to line-scoped
  `line_retirable` so Winter Berries (special, recipe-less) can retire — a fourth retirement
  event.
- The older picturebook §7 "library + deploy" model ("never retired, never sold",
  `2026-07-17-picturebook-scenes-design.md:121`) is superseded by the three-state model here +
  shipped retirement; noting it so the contradiction doesn't resurface.

## 16 · Open questions for Dev review

1. **Section vs. tabs.** This spec puts the Shelf as a section inside the bag panel (empty
   until L46, no tab scaffold exists, shop removed its tabs for one sheet). The parent says
   "two-tab panel". Confirm the section — or ask for tabs and step 1 grows a small tab atom
   styled per the guide ("only the selected tab gets the full action accent").
2. **Winter Berries retires (line-scoped Done).** A fourth retirement event, L51. Confirm.
3. **Declined retirement sweeps to the Shelf** (board un-pollutes even on "not now"; the Shelf
   row becomes the manual fallback since no on-board generator remains to select). Confirm.
4. **Sweep scope includes the line's bag stock** (frees paid slots; mirrors `retire_line`'s
   scope). Alternative: bag stock is player-placed and stays. Confirm the sweep.

---

## Appendix · Per-line timeline (shipped cadence)

Windows from the arc table (`mechanics_tests.gd:651-662`); "for" = `next_need().for_line`.

| Line | Active | Shelf gaps (Comeback) | Done |
|---|---|---|---|
| 1 Glow-mushrooms | L1–32 | — | **L33** |
| 2 Wild Berries | L15–64 (own window, then the Winter Berries and Spices eras), L69+ | **L65–68** → back L69 for Tea Cups | never |
| 3 Snow & Ice | L29–50, L60+ | **L51–59** → back L60 for Corals | never |
| 4 Woolens | L33–45, L51–64, L69+ | **L46–50** → L51 for Spices · **L65–68** → L69 for Tea Cups | never |
| 5 Winter Berries *(special)* | L38–50 | — | **L51** *(new — line-scoped)* |
| 6 Desert Fruits | L42–54 | — | **L55** |
| 7 Sand Sculptures | L46+ | — | never |
| 8 Spices *(special)* | L51–64, L69+ | **L65–68** → back L69 for Tea Cups | never |
| 16 Shells | L55–68 | — | **L69** |
| 17 Corals *(special)* | L60+ | — | never |
| 18 Koi | L65+ | — | never |
| 19 Tea Cups *(special)* | L69+ | — | never |

Sanity anchors: the five never-retiring generators (2, 3, 4, 7, 18) are exactly the ingredient
closure of the frozen final window `[17, 18, 19]`; specials hold Shelf **stock** only (no
generator to store); post-arc no line is ever Comeback again, so the Shelf self-empties.
