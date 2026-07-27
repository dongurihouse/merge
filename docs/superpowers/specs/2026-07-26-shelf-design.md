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
- Title (the shipped in-card treatment): returning → *"See you soon"* · done forever →
  *"All done here"* (shipped key).
- Body, names/levels/coins interpolated (`farewell.*` keys in `strings.json`; coin clause
  only when payout > 0):
  - returning: *"The Woolens will be back at Level 51, for Spices — %d coins for the
    leftovers."*
  - done forever: *"The Glow-mushrooms' story is complete — %d coins join your purse."*
- FX on close: `tidy_poof` + coin `reward_arrival` (the `board.gd:3981` pattern).
- Mock: `games/grove/assets/_concepts/screens/farewell_card_v1_1080x1920.png`.

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
- Entry point: a small **Almanac** chip at the right end of the info tray's EMPTY state, hint
  text kept; hidden while a selection is shown — board-side, no new nav chrome. Build it with
  the shipped action button, `Kit.action_button("almanac", …)`, by adding `"almanac"` to
  `ACTION_ROLES` + `ACTION_GLYPHS` (`ui_kit.gd:59-70`) pointing at the shipped
  `ui/nav/glyphs/glyph_almanac.png`. Gate: the `discovery_ladder` feature, same as its
  siblings.
- Strings `almanac.*`. No new save keys, no actions, no economy paths.
- Mocks: `games/grove/assets/_concepts/screens/almanac_v1_1080x1920.png` (the L51 snapshot) ·
  `almanac_infobar_v1_1080x1920.png` (the entry chip).

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

## Implementation directions (for the implementing agent)

**Workspace.** Branch `feat/line-farewells` from latest `main` in a NEW worktree outside the
repo: `git worktree add /Users/xup/dh/merge-wt-farewells -b feat/line-farewells` (in-repo
worktrees get wiped by other agents). Seed the import cache before the first run:
`rsync -a --delete /Users/xup/dh/merge/.godot/ /Users/xup/dh/merge-wt-farewells/.godot/`.
**Do not merge to main and do not remove the worktree** — implementation ends with the branch
committed in place; code review happens in the worktree.

**Assets: generate NOTHING.** Never invoke image generation, `make intake`, `codex`, or any
art tooling; never hand-draw, composite, or download a substitute. The one new sprite this
feature needs is **already on `main`**:
`games/grove/assets/ui/nav/glyphs/glyph_almanac.png` (512² transparent, matching the shipped
`action_button_glyphs_v2` family) — wire it, don't remake it. Everything else reuses shipped
art: piece art via `PieceView.make_piece`, the dialog frame / slot cells / locked well via
the kit, coins and FX as they are. If any texture is missing in your worktree, use the
nearest shipped sibling as a placeholder, note it in the hand-off, and move on. The three
approved mocks in `games/grove/assets/_concepts/screens/` (`farewell_card_v1_…`,
`almanac_v1_…`, `almanac_infobar_v1_…`) are layout references only — never ship their pixels.

**Order** — each step lands with its tests green (`make test-fast`, a few seconds) before the
next. Run every test and capture in the FOREGROUND:

1. `content.gd` §6: `line_needed_at_zone` + `next_need` (Build 1), plus the arc-table battery
   in `engine/tests/mechanics_tests.gd` beside the existing window/cadence rows. Levels
   derived (`G.zone_unlock_level(z)`), never literal.
2. `save.gd`: `gen_kept` / `retired` default-on-read accessors (Build 5). No
   `SCHEMA_VERSION` bump; follow the deep-merge idiom (`save.gd:98`).
3. `board_actions.gd`: `farewells_due` + `sweep_line` (Build 2) and the `gen_kept` restore in
   `produce_due_generators`; tests in `games/grove/tests/grove_board_actions_tests.gd` beside
   the retirement cases. Keep the caps-lock clock assertion ("SWEEP NEVER ADVANCES THE
   CLOCK").
4. `engine/scripts/ui/farewell_card.gd` (Build 3) + `farewell.*` strings; delete
   `retire_offer.gd`.
5. `board.gd`: the two seams (Build 4) and every deletion in Build 6.
6. `engine/scripts/ui/almanac.gd` + the info-tray chip (Build 7).
7. Evidence: retarget the shot modes (below), full `make test` green, and a hand-off summary
   listing suites run and capture paths.

**Repo rules that bite:**

- **`grove_shot.gd` breaks unless retargeted.** Its `retire` mode calls
  `scn._maybe_offer_retirement()` (`grove_shot.gd:214`) and `retiredone` calls
  `scn._retire_line("gen_1")` (`:227`) — both deleted by Build 6. Repoint them at the
  farewell card and its post-sweep board, add a `farewell` mode for the returning variant
  (a Woolens sweep) and an `almanac` mode, and keep the tool's authoritative `modes` list
  (`:34-40`) in step. **Look at every capture** — a stale mode that renders a plain board
  still exits 0.
- New `.gd` files: run `make import` before committing so `.uid` sidecars exist, or the
  regenerated untracked `.uid` aborts the later merge.
- `ui/` never imports `scenes/` (`layering_tests`) — `almanac.gd` and `farewell_card.gd` take
  every read and action as an injected Callable, like `bag_overlay.gd`.
- Every `Strings.t("literal")` must resolve (`strings_tests`); retiring `retire.*` means
  retiring its test pins too.
- Engine code never references `games/` directly; no new `Color("#…")` hex literals
  (`palette_ssot_tests`), no bare `z_index` integer literals (`layering_tests`).
- Don't reformat `test_base` output — the runner parses the `"  PASS"` lines and the footer.
- Payouts use `Save.add_coins`, never `G.earn_coins` — retirement/sweep coins are spendable
  only.
- Don't touch any Rush file (`explore*.gd`) or the Rush's own rules.
- `modal_dismiss_tests` pins real call sites; register the card's overlay name there if it
  gates dismissal.

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
