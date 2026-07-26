# Line farewells — sweep spec (progression step 1, rev 4)

**Date:** 2026-07-26 · **Status:** rev 4, for Dev review. Step 1 of
`2026-07-26-progression-systems-design.md` §8. No Comeback state, no storage: a line nothing
asks for gets one farewell + sweep; returns are the shipped `due_gen` birth-on-tap. A
read-only **Almanac** modal shows every line's status (producing · away · complete).

Levels always derive from the cadence (`G.zone_unlock_level(z)`) — never pin literals
(idiom: `grove_board_actions_tests.gd:249`).

## Model

Zone lines only (`ZONES`, `grove_data.gd:112`; treats/coins/drops exempt).
`closure(z) = ∪ expand(w)` over `w ∈ zone_window_lines(z)`; `expand` = the
`_add_needed_line` recursion (`content.gd:241`). A line is **needed**
(`line ∈ closure(current zone)`) or **done for now**. No stored line state — board presence
is the edge memory, so evaluation is idempotent.

## Build

**1 · Predicates — `content.gd` §6**

- `line_needed_at_zone(line, z) -> bool`
- `next_need(line, level) -> {}` or `{level, for_line}` — first `z' >` current zone with
  `line ∈ closure(z')`; `for_line` = first window line whose expansion contains it. Card
  wording only.

**2 · Sweep — `board_actions.gd`** (pure statics, `retire_line`'s shape;
`retire_preview`/`retire_line` are subsumed)

- `farewells_due(board, level) -> [{line, next_need}]` — not-needed lines with board
  presence (items or generators).
- `sweep_line(board, line) -> {pieces, coins, gens}`:
  - board stock sold at `G.sell_reward`, coins via `Save.add_coins` — never the clock;
  - every board generator copy removed; tier > 1 or boost > 0 is written to `gen_kept`
    first;
  - the bag is untouched — stock and stashed generator copies (a stashed copy is in
    `due_gen`'s owned set, `quests.gd:56`, so a returning era deploys it; the bag is the
    hoard path).
- `produce_due_generators` (`board_actions.gd:69`): on birth, read + erase `gen_kept[gid]`
  and restore tier/boost.

**3 · Farewell card — `engine/scripts/ui/farewell_card.gd`** (replaces `retire_offer.gd`;
same skeleton, `retire_offer.gd:55-106`: `Overlay.modal` + `Kit.dialog_frame` + tier-1 piece
art + one body line + one CTA; keep the `min_h` floor)

- One variant, one **OK** button; veil-tap and ✕ do the same. The sweep runs on close.
- Body, names/levels/coins interpolated (`farewell.*` keys in `strings.json`; coin clause
  only when payout > 0):
  - returning: *"The Woolens will be back at Level 51, for Spices — %d coins for the
    leftovers."*
  - done forever: *"The Glow-mushrooms' story is complete — %d coins join your purse."*
- FX on close: `tidy_poof` + coin `reward_arrival` (the `board.gd:3981` pattern).

**4 · Seams — `board.gd`** (cards chain one at a time)

- after the level-up ceremony closes (consumer at `board.gd:3795-3806`), and after
  `_refill_quests()` has culled the old zone's stands;
- on board entry, deferred (the `board.gd:392` seam). Presence-based evaluation makes this
  the whole old-save migration; legacy `retire_declined` is ignored.

**5 · Save — grove blob, default-on-read, no schema bump**

- `gen_kept: {gen_id: [tier, boost]}`
- `retired: {str(line): true}` — written on a done-forever farewell; the Collection's feed,
  unread for now.

**6 · Delete**

`retire_offer.gd` · `_maybe_offer_retirement` + `retire_declined` writes
(`board.gd:3938-3964`) · the info-bar retire branch (`board.gd:2224-2240`, `:2493-2500`;
item sell and redundant-gen sale stay) · `retire_preview`/`retire_line`.
`gen_retirable`/`retirable_gens` stay (tests pin them).

**7 · Almanac — `engine/scripts/ui/almanac.gd`** (read-only; the away- and retired-lines
view — swept lines have no board presence, so `ladder.gd`/`gen_lines.gd` can't reach them)

- Same face as its siblings: the shared workbench "tiers" dialog (twig border, banner, ✕,
  slot-cell grid) and the same self-contained shape — coordinator (`board.gd`) owns the
  data, `Almanac.open(host, {entries, on_line})` just renders (`gen_lines.gd:1-14` is the
  template).
- 12 cells, zone order; entry `{line, seen, code, state, back_level, for_line}` — coordinator
  derives `seen`/lowest-seen `code` from the `seen` ledger, `state` from
  `line_needed_at_zone` / `next_need`.
- Cell render: unseen → locked "?" well, no tap · seen → lowest-seen piece · needed-now →
  the gold marked ring (`gen_lines`' `in_pool` ring) · away → sub-caption *"Back at L51"* ·
  done-forever → sub-caption *"Complete"*.
- Tap a seen cell → `Ladder.open` (existing); its banner appends the status (*"Wild Berries
  · back at L69, for Tea Cups"*).
- Entry point: a small **Almanac** button in the info tray's EMPTY state, hidden while a
  selection is shown — board-side, no new nav chrome. Gate: the `discovery_ladder` feature,
  same as its siblings.
- Strings `almanac.*`. No new save keys, no actions, no economy paths.

## Invariants (test assertions)

- SWEEP NEVER ADVANCES THE CLOCK.
- Sweep touches the board only, at most once per gap (no presence → no re-fire).
- Generator tier/boost round-trip `gen_kept` exactly.
- `due_gen` reaches every ingredient generator of every future window (no strand).
- Home board only; Rush untouched.

## Tests

- `grove_board_actions_tests`: predicates across the arc table (derived levels, one row per
  zone); L65 fixture — three farewells due, board-only sweep, coins spendable-only,
  `gen_kept` written; keepsake round-trip through `produce_due_generators`; Winter Berries
  farewells at z7's level; L33/L55/L69 payout cases.
- `grove_explore_tests`: entry chains the due cards; level-up seam fires after the cull;
  migration idempotent on re-entry; legacy `retire_declined` ignored.
- Almanac: entries builder across arc levels (state per line at the zone boundaries —
  derived); UI structure in the `grove_ui_workbench_tests` idiom (12 cells, ring on
  needed-now, captions on away/complete, unseen locked, no tap on unseen); the empty-tray
  button toggles with selection (`grove_explore_tests`).
- Update existing pins: retirement wiring tests, `strings_tests` (`retire.*` →
  `farewell.*`), `modal_dismiss_tests` if the card registers a new overlay name.
- `grove_shot MODE=farewell` and `MODE=almanac` for the visual checks.
- `make test-fast` per change; `make test` before handoff. No `grove_sim` re-pass (parent
  §8); its invariants stay green.

Out of scope: mastery (step 2), the Collection archive (favorite-as-décor etc. — the
Almanac's Complete cells are its seam), any storage/hoard UI, sell-band tuning.

## Appendix · Per-line timeline (shipped cadence `[1,15,29,33,38,42,46,51,55,60,65,69]`)

| Line | Needed | Away (returns by itself) | Done forever |
|---|---|---|---|
| 1 Glow-mushrooms | L1–32 | — | **L33** |
| 2 Wild Berries | L15–64, L69+ | L65–68 → L69, for Tea Cups | never |
| 3 Snow & Ice | L29–50, L60+ | L51–59 → L60, for Corals | never |
| 4 Woolens | L33–45, L51–64, L69+ | L46–50 → L51, for Spices · L65–68 → L69, for Tea Cups | never |
| 5 Winter Berries *(special)* | L38–50 | — | **L51** |
| 6 Desert Fruits | L42–54 | — | **L55** |
| 7 Sand Sculptures | L46+ | — | never |
| 8 Spices *(special)* | L51–64, L69+ | L65–68 → L69, for Tea Cups | never |
| 16 Shells | L55–68 | — | **L69** |
| 17 Corals *(special)* | L60+ | — | never |
| 18 Koi | L65+ | — | never |
| 19 Tea Cups *(special)* | L69+ | — | never |

Farewell events: L33 Glow-mushrooms · L46 Woolens · L51 Snow & Ice + Winter Berries · L55
Desert Fruits · L65 Wild Berries + Woolens + Spices · L69 Shells. Post-arc
`closure(z11) = {2,3,4,7,8,17,18,19}`; specials farewell stock-only (no generator).
