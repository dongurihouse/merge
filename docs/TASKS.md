# TASKS — engineer task log (index)

The task log is split **by category** into `tasks/*.md` (append-only history, one entry per
Dev-facing task). One file per category so each list stays small as the total grows — we don't
use a DB, so this is how the log scales. Read the relevant file before similar work: it's the
reliability track record.

## Categories (leaner 6 — owner pick 2026-06-12)

| File | Holds |
|---|---|
| [`tasks/mechanics.md`](tasks/mechanics.md) | **Mechanics & Systems** — rules, loops, merging, generators, quests, progression, economy logic, gates |
| [`tasks/interaction.md`](tasks/interaction.md) | **Player Interaction** — input/controls the PLAYER uses: drag/tap/gestures, drop targets (dev-tool input → Tech) |
| [`tasks/ux-feel.md`](tasks/ux-feel.md) | **UX & Interface + Game Feel** — HUD/menus/chips/layout/readability/onboarding · and the alive layer: animation, FX, audio, juice |
| [`tasks/content-art.md`](tasks/content-art.md) | **Content & Balance + Art** — levels/items/quest data, placement, difficulty/economy tuning · and the asset pipeline: generation, cutout/punch, import |
| [`tasks/tech-workflow.md`](tasks/tech-workflow.md) | **Tech & Tooling + Workflow** — engine/code infra, dev tools (placement editor), tests, perf, save/build · and process: roles, this log, the queue, conventions |
| [`tasks/triage.md`](tasks/triage.md) | **Triage / Not sure** — uncategorized; re-file once the real category is clear (don't let it linger) |

## Entry format (full spec: `~/.claude/docs/engineer.md` §"The task log")

Top six fields opened **at pickup** (the LLM-reliability call shapes how it's worked + whether to
pull the Dev in); last three closed **at done**.

```
### T<N> — <title>   ·   <YYYY-MM-DD>   ·   <area>   ·   <status>
- **Asked:**           the Dev's request, their words
- **Problem:**         the real underlying problem once diagnosed (often ≠ the ask)
- **Type:**            new | regression (of T<n>/<commit>) | follow-up
- **LLM-reliability:** high | med | low — deterministic & self-verifiable, or perceptual/aesthetic/external?
- **Human-in-loop:**   none | recommended | required — what only the Dev can judge; sibling low-reliability tasks
- **Verification:**    how it was ACTUALLY proven (test / composite-over-colour / measured rect / Dev eyeball) — never "looks fine"
- **Iterations:**      passes taken; did the Dev catch a miss? — grounds the reliability rating
- **Result:**          outcome + evidence (commit/file); or BLOCKED / HANDED-OFF
```

- **T# numbering is global across categories** (T1, T2, … — never reused), so a task is unique
  no matter which file it lands in; the number tells you roughly when it happened.
- **`LLM-reliability: low` is a trigger, not a label** — build a check (composite, measure, a
  test) or hand the call to the Dev; never ship a low-reliability task on a screenshot.
- Highest task number so far: **T47** (T47 = **Shop tails** — the "i" opens a real item-detail sheet (no buy) · claimable red dots folded onto the shared `Look.badge` + the "i" onto `rim_overlay` · cleaner-icon prompts authored (`docs/design/shop_icon_prompts.md`, Dev-channel — generation pending), `tasks/ux-feel.md`, **done pending merge** on `worktree-shop-tails`). T46 = **Shop storefront UX pass** — de-grey cards + green buy pills · hero icon-on-plate · bolder banners · red dots + real daily-rotation countdown · IAP cluster-scaling + Popular/Best-value · red close · decorative "i", `tasks/ux-feel.md`, **done — merged to `main` `70c6574` 2026-06-17**). T42–T45 = the **2nd Open—economy batch** (2026-06-15), `tasks/mechanics.md`: T45 = monetization entry-point wiring (2×-collect / piggy-vault button / daily-login popup) — done + verified on `t45-integration`, **NOT merged** (held behind active §16 map work in the primary tree); T44 = piggy vault + forgiving login calendar; T43 = live-IAP ladder + rewarded ads + out-of-water offer; T42 = home-hub yield + upgrade-levels (keystone Part A). T39–T41 = the **1st Open—economy batch** (2026-06-15), all `tasks/mechanics.md`, done: T41 = bag capacity 6→18 slot model + drag-back retrieve; T40 = Shop item-shortcuts + cosmetics + rotating offers; T39 = selling per-map coin bands + drag-only verb. T38 = map-model tails — the `zone`→`map` vocabulary sweep across §6/§7 code+tests+sim + orphaned `furn_fh_*` sprite cleanup, `tasks/tech-workflow.md`, done [the (b) §16 map-art + owner placement parked, art-lane]; T37 = seed-123 strand fix — open the L1 board frontier, `tasks/mechanics.md`, done pending owner feel sign-off; T36 = Grove v1 art — generate + hook up the home-grove sprites & scenes, `tasks/content-art.md`, **open**; T35 = batch-merge of the 15-branch Tier-2 + T26–T34 worktree fleet into `main` + the giver-bob integration fix, `tasks/tech-workflow.md`, done; T26–T33 = the parallel worktree fleet (features registry, spec reconciles, FTUE spotlight, featured quests, anchor lines, calm-breathe, emoji-floaters, FTUE burst suppression, six Tier-2 UX-feel items); T34 = §13 HUD-law spec reconcile, renumbered from a colliding "T25"; T25 = generator burst-upgrade — on-board buy pill + the cap-decouple/re-price of the §6 coin sink, `tasks/mechanics.md`, done; T24 = level-gated obstacle cells, done; T23 = burst-pop + the burst-upgrade coin sink, `tasks/mechanics.md`, done; T22 = home-hub yield + upgrade-levels save schema (Part A · A1), `tasks/mechanics.md`; T21 = map model — one image = one map + map-select + home-hub shortcut, `tasks/mechanics.md`; T20 = grove content roster — v1 lines + generators, `tasks/content-art.md`, done; T19 = §7 generated quests + cutover, done; T18 = retire evolve-merge + the generator-grant hand-in; T17 = per-zone generator engine mechanic — T17–T19, T21–T23 in `tasks/mechanics.md`). *(T21/T22/T23 began as three parallel "T21" threads; map-model is the entrenched T21, hub-yield→T22, burst-pop→T23.)*
- ⚠️ Ledger gap: the **progression rework** (one stars-driven Level, commit `2940b0f`) and the **data/skin split** (T16, referenced in `content.gd`) shipped without entries here — the logs were cleared 2026-06-14 and these weren't backfilled. Backfill or confirm numbering on the next reconcile.
- ⚠️ Ledger gap (2026-06-15 batch): **T28–T33** (FTUE spotlight · featured-quest surface · anchor-line askability · calm-breathe · emoji-floaters · FTUE burst-suppress) and the **six Tier-2 UX-feel tasks** (idle-hint openable · giver-bob payable · full-board dim-gen · map fog-veil · spot ghost-preview · gate-unveil pointer) shipped code in the T35 batch but the original parallel agents wrote **no `tasks/` entries**. The **T35** entry + the merge commits are the collective record; per-task subjective fields (Asked/Iterations) are unrecoverable, so not fabricated. Backfill factual stubs if the track record needs them.
