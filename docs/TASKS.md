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
- Highest task number so far: **T16**.  (T14 farmhouse-alive parked on its branch; T15 wayside-clickable merged.)
