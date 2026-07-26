# Line farewells — the simple sweep (progression step 1, rev 2)

**Date:** 2026-07-26
**Status:** rev 2, draft for Dev review. Expands §2 of `2026-07-26-progression-systems-design.md`
(rollout step 1 of its §8). Companions: that doc · `docs/design/picturebook_lines_recipes.md` ·
`engine/scripts/core/content.gd` §6 (the shipped window + retirement).

**Rev 2 (Dev feedback, same day): the Comeback state and the Shelf storage surface are
dropped.** A line that nothing asks for is done for now — one farewell, stock sold, generator
cleared. Its later return needs no state: the merge lines *are* their own comebacks — the
shipped birth-on-tap (`Quests.due_gen`) already brings a generator back the moment a craft
asks for its line. Rev 1's per-line stock storage, tier chips, pull-back, parked map, and the
offer/decline apparatus are all deleted; what survives of "the Shelf" is the farewell card,
the sweep, and one invisible keepsake so bought generator tiers aren't lost.

Every level quoted below is today's **derived** cadence — `[1, 15, 29, 33, 38, 42, 46, 51, 55,
60, 65, 69]`, pinned in `engine/tests/tuning_tests.gd:72` — and moves whenever `SCENE_END_LEVEL`
is retuned. Implementation artifacts (code, tests, strings with numbers) must always derive via
`G.zone_unlock_level(z)`, never pin literals; `grove_board_actions_tests.gd:249-256` is the
idiom. (The stale "L11/L22/L33" prose comments are being fixed in a separate task.)

## 1 · The problem

When a line's zone rolls out of the 3-zone active window, nothing happens to its stuff. The
generator fades (`board.gd:1597`, "it can still pop — free while faded"), its pieces grey out
(`board.gd:1623`), and everything sits on the board until the line's next craft era — or
forever. The only automated cleanup is the shipped retirement offer, which fires exactly three
times per playthrough (`gen_1` at L33, `gen_6` at L55, `gen_16` at L69) and is
generator-scoped (`G.gen_retirable`, `content.gd:412`), so **Winter Berries — a crafted
special with no generator and in no recipe — strands forever** when its window closes at L51.
Idle stretches (Woolens L46–50, Snow & Ice L51–59, the three-line exodus at L65) leave dead
generators and unusable mid-tier stock occupying cells of a 63-cell board.

## 2 · The whole model: needed, or done for now

Per **zone line** (the 12 lines of `ZONES`, `grove_data.gd:112` — treats 71–75, coins and
special drops exempt). Let `expand(w)` be the recursive ingredient closure of line `w` (the
shipped `_add_needed_line` recursion, `content.gd:241`), and
`closure(z) = ∪ { expand(w) : w ∈ zone_window_lines(z) }`.

**A line is either needed now (`line ∈ closure(current zone)`) or it is done for now.** That
is the entire model. There is no Comeback state, no per-line state machine, and no persisted
state flag: whether a done line returns later is a fact about the content tables, and it only
affects one string on the farewell card. **Presence is the memory** — the farewell fires when
a line is not needed *and* still has stuff on the board; after the sweep there is no presence,
so the evaluation is naturally idempotent and needs no parked/declined bookkeeping.

New pure reads in `content.gd` §6, beside their ancestors:

- `line_needed_at_zone(line, z) -> bool` — `line ∈ closure(z)`. (`needed_gens`,
  `content.gd:403`, is its generator-keyed projection; `active_lines` the window read.)
- `next_need(line, level) -> Dictionary` — scan the zones after the current one (the
  `gen_retirable` scan, `content.gd:418`: finite, "one probe per remaining zone"); first `z'`
  with `line ∈ closure(z')` returns `{level: zone_unlock_level(z'), for_line: w}`, `w` being
  the first window line whose expansion contains `line`. Empty when the line is done forever.
  This exists **only to word the card**.

Granularity: the model is keyed to the **zone**, not the live fence — `quests.refill` keeps
all three window lines represented on an 8-stand fence, so an ingredient line is needed for
the whole of its borrower's window span. The farewell is evaluated only after the
post-level-up quest cull (`quests.gd:152`) has dropped the old zone's stands, so a sweep can
never race a live ask.

## 3 · The arc, concretely

| Level (zone) | Farewell cards | Card line (names/levels interpolated) |
|---|---|---|
| L33 (z3) | Glow-mushrooms | *"The Glow-mushrooms' story is complete — %d coins join your purse."* |
| L46 (z6) | Woolens | *"The Woolens will be back at Level 51, for Spices — %d coins for the leftovers."* |
| L51 (z7) | Snow & Ice · Winter Berries | back-at-L60-for-Corals · story-complete *(the stranding hole, closed)* |
| L55 (z8) | Desert Fruits | story complete |
| L65 (z10) | Wild Berries · Woolens · Spices | each: back at Level 69, for Tea Cups |
| L69 (z11) | Shells | story complete |

Between the cards, returns just happen: at L51 a Spices ask appears, the player taps any
generator, and Woolens steps back onto the board (§5) — no ceremony, the line coming back *is*
the comeback. Post-arc (frozen z11 window) every line is either needed forever
({2, 3, 4, 7, 8, 17, 18, 19}) or has said goodbye — nothing idles again. Full per-line table
in the appendix.

## 4 · The farewell: one card, one sweep

**The card** — `engine/scripts/ui/farewell_card.gd`, absorbing and deleting
`retire_offer.gd` (already its ancestor: `Overlay.modal` + `Kit.dialog_frame` +
`PieceView.make_piece(line*100+1)` + one body line + one CTA, `retire_offer.gd:55-106`; keep
the `min_h` floor). One variant, one button (**OK**); veil-tap and ✕ do the same thing —
there is no decision to make, so nothing to decline. The body is the one line from §3: the
promise wording when `next_need` is non-empty, the story-complete wording when it is; the
coin clause appears only when the payout is > 0.

**The sweep, on card close** — pure static in `board_actions.gd`, the direct simplification
of `retire_line` (`board_actions.gd:141`):

- **Board stock** of the line: sold at `G.sell_reward` per piece (the shipped "ONE payout
  read" pricing, `retire_preview`'s sources minus the bag), coins via `Save.add_coins` —
  **spendable only, never the clock** (`board_actions.gd:188`).
- **Every board generator copy** of the line: removed; if its tier > 1 or boost > 0, the
  investment is written to the keepsake map first (§5).
- **The bag is not touched** — stock *and* any player-stashed generator copy. It is the
  player's own space, and now also the one deliberate hoard mechanism: stash pieces you want
  to keep across an era at the price of the slots they occupy. (A bag-stashed generator is
  already in `due_gen`'s owned set, `quests.gd:56`, so a returning era deploys it from the
  bag instead of double-birthing — no strand. This inverts shipped `retire_line`, which
  sells bag stock — flagged §13.)

FX: coins fly to the wallet (`FX.reward_arrival`, the `_retire_line` pattern at
`board.gd:3981`) plus the `tidy_poof`; a typical sweep is one card + one coin flight, ~1 s.
No new FX id needed.

## 5 · Return — the shipped path, plus a keepsake

`Quests.due_gen` (`quests.gd:71`) already walks the ingredient tree and births any missing
generator on the next generator tap (`board.gd:2973` → `produce_due_generators`,
`board_actions.gd:69`; board-full falls to `gen_bag`, `board_actions.gd:82`). Unchanged.

One addition so the sweep never destroys bought progress: a grove-blob map
**`gen_kept: { gen_id: [tier, boost] }`**, written by the sweep, read-and-erased by
`produce_due_generators` when it births that id — the generator returns at the tier the
player paid for, not a fresh tier 1. No UI, no player verb. (`retire_declined` at
`board.gd:3961` is the precedent for a tiny per-gen grove key; default-on-read, **no
`SCHEMA_VERSION` bump**, per the `save.gd:98` merge idiom.)

The second new grove key is **`retired: { str(line): true }`**, written when a
done-*forever* line's farewell closes — the future Collection almanac's feed
(`docs/BACKLOG.md:106`). Nothing reads it yet.

`gen_kept` entries for gens that can never return (`next_need` empty) are simply never
written; `_purge_above_level_content` (`board.gd:774`) does not need to learn any new
collection — there is no stored stock anymore.

## 6 · Seams and migration

The evaluation (`farewells_due(board, level) -> Array of {line, next_need}` — not-needed
lines with board presence) runs at two calm seams, cards chained one at a time:

1. **After the level-up ceremony closes** (`LevelPopup`'s collect callback, the consumer at
   `board.gd:3795-3806`), explicitly after `_refill_quests()` has culled the old zone's
   stands — the goodbye lands when the era visibly ends.
2. **On board entry**, deferred — the shipped retirement-offer seam (`board.gd:392`, "a calm
   moment, never mid-gesture"). Because presence is the memory, this same seam **is the whole
   migration**: an old save's first entry farewells every currently-idle line once, and a
   re-entry finds nothing to do. The legacy `retire_declined` key is ignored and deleted from
   fresh writes (a previously-declined line simply gets its farewell like everyone else).

Levels change nowhere else — `G.earn_coins` is called only from `deliver_quest`
(`board_actions.gd:33`); the Rush board keeps its own rules and never touches any of this.

## 7 · What gets deleted

The simplification is mostly subtraction. Gone: `retire_offer.gd` (replaced by the smaller
`farewell_card.gd`) · `_maybe_offer_retirement` + the `retire_declined` ledger
(`board.gd:3938-3964`) · the info-bar retire route — `_on_trash_pressed`'s retirable branch
and the retire-preview sell label (`board.gd:2224-2240`, `:2493-2500`; a done line's
generator is swept before it can be selected, so the branch is unreachable; the item sell
button and the redundant-generator sale stay) · `retire_preview`/`retire_line`
(subsumed by the sweep statics) · rev 1 in its entirety (shelf arrays, tier chips,
pull-back, parked map, bag-panel section). `G.gen_retirable`/`retirable_gens` remain as
derivations (tests pin them; `next_need().is_empty()` is the same fact line-scoped).

## 8 · Laws (asserted in tests)

- **The game is completable without hoarding.** Crafts consume same-tier pieces poppable from
  re-birthed generators; swept stock is never needed again *for its own line's asks* — an
  ingredient era pops fresh. (The structural no-strand check: `due_gen` reaches every
  ingredient generator of every future window.)
- **The clock is quests only** — sweep payouts are `Save.add_coins`, never `earn_coins`
  ("SWEEP NEVER ADVANCES THE CLOCK", the `board_actions_tests:296` idiom).
- **Only the transition sweeps, and only the board.** The bag is never auto-touched; a line
  is swept at most once per gap (no presence → no re-fire).
- **Generator investment survives**: tier/boost round-trip through `gen_kept` exactly.
- **Weather/Rush untouched**; home board only.

## 9 · What does not change

- The window and cadence machinery (`active_lines`, `zone_window_lines`, `_build_cadence`) —
  read-only consumers here.
- `due_gen`'s owned-set semantics and the anchor stranding guard (`quests.gd:72-77`).
- The quest cull ("a quest retires with its line", `quests.gd:145`) and fence composition.
- The bag: capacity, pricing, stash/retrieve, generators section — no new UI in it at all.
- Sell pricing (`sell_reward`, `content.gd:1220`); selling never feeds the clock.
- Save schema version (two additive keys only).

## 10 · Testing

The feature is small enough to live in the existing suites — **no new suite, no Makefile /
`CLAUDE.md` change**:

- **`grove_board_actions_tests`** (where retirement's tests live today, `:243-305`):
  `line_needed_at_zone` / `next_need` across the arc table (derived levels, one row per
  zone); the L65 fixture — three farewells due, sweep sells board stock only (bag intact),
  coins spendable-only, `gen_kept` written; the keepsake round-trip via
  `produce_due_generators`; Winter Berries farewells at z7's level; the L33/L55/L69
  story-complete cases keep their payouts.
- **`grove_explore_tests`** (the shipped offer wiring lives here, `:69-112`): entry
  evaluation chains cards; level-up seam evaluates after the refill cull; migration — a
  seeded mid-arc save farewells idle lines once, idempotent on re-entry; `retire_declined`
  in an old save is ignored.
- **Existing pins to update**: the retirement-offer wiring tests and `strings_tests` keys
  (`retire.*` → `farewell.*`), `modal_dismiss_tests` if the card registers a new overlay
  name.
- A `grove_shot` fixture mode for the card (`MODE=farewell`) for the visual check.
- `make test-fast` after every change; `make test` before handoff. No `grove_sim` re-pass
  required for this step (parent §8); its invariants must simply stay green.

Build order for the plan: content predicates + tests → sweep statics + `gen_kept` + tests →
scene seams + card (delete `retire_offer.gd`) → deletions (§7) + test updates → shot mode.

## 11 · Out of scope

- Mastery (step 2), combos (3), improvements (4), weather (5).
- The Collection almanac (backlog; `retired` + `seen` are its feed).
- Any storage, growth, or per-line UI surface — rev 1's Shelf tab/section is dead, not
  deferred.
- Rebalancing sell bands or bag pricing.

## 12 · Corrections to the parent design (fold into its next rev)

- **§2 shrinks to this rev**: the three-state table, the Shelf tab/rows/pull-back, and the
  two-button card collapse into needed/done + one farewell card + the sweep. "Retirement"
  and "comeback" stop being different processes — one is the other with a different last
  line.
- Its example levels were stale (pre-re-spine cadence; corrected in the parent 2026-07-26):
  retirement fires at **L33 / L55 / L69**, the first farewell-with-return is **Woolens at
  L46** ("back at Level 51, for Spices"), and Wild Berries' only gap is **L65–68 → L69, for
  Tea Cups** (not "L22, for Spices").
- The older picturebook §7 "library + deploy, never retired, never sold"
  (`2026-07-17-picturebook-scenes-design.md:121`) is doubly superseded (by shipped
  retirement, and by this rev's universal sweep).

## 13 · Open questions for Dev review

1. **Bag stays untouched by the sweep** (it becomes the one deliberate hoard mechanism;
   inverts shipped `retire_line`, which sells bag stock of a retired line). Confirm — or
   the sweep sells bag stock too and the game has no hoard path.
2. **Every sweep pays coins** (returning lines included — one process, one pricing;
   payouts are small, 1–3 coins × tier by band). Confirm, or returning lines sweep
   value-silent.
3. **Keep the promise wording** ("back at Level 51, for Spices") on returning lines' cards
   — copy only, zero state. Confirm, or every card uses the story-complete line.

---

## Appendix · Per-line timeline (shipped cadence)

Windows from the arc table (`mechanics_tests.gd:651-662`); "for" = `next_need().for_line`.

| Line | Needed | Away (returns by itself) | Done forever |
|---|---|---|---|
| 1 Glow-mushrooms | L1–32 | — | **L33** |
| 2 Wild Berries | L15–64 (own window, then the Winter Berries and Spices eras), L69+ | L65–68 → L69, for Tea Cups | never |
| 3 Snow & Ice | L29–50, L60+ | L51–59 → L60, for Corals | never |
| 4 Woolens | L33–45, L51–64, L69+ | L46–50 → L51, for Spices · L65–68 → L69, for Tea Cups | never |
| 5 Winter Berries *(special)* | L38–50 | — | **L51** *(new — line-scoped farewell)* |
| 6 Desert Fruits | L42–54 | — | **L55** |
| 7 Sand Sculptures | L46+ | — | never |
| 8 Spices *(special)* | L51–64, L69+ | L65–68 → L69, for Tea Cups | never |
| 16 Shells | L55–68 | — | **L69** |
| 17 Corals *(special)* | L60+ | — | never |
| 18 Koi | L65+ | — | never |
| 19 Tea Cups *(special)* | L69+ | — | never |

Sanity anchors: the five never-retiring generators (2, 3, 4, 7, 18) are exactly the
ingredient closure of the frozen final window `[17, 18, 19]`; specials have no generator, so
their farewell is stock-only; post-arc no line ever idles again.
