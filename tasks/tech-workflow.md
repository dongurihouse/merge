# Tech & Tooling + Workflow & Process — task log

Engine/code infra, dev tools (the placement editor), tests, performance, save/build · AND the
meta layer: roles, the task log, the queue, conventions. Format + rules: `../TASKS.md` (index)
→ `~/.claude/docs/engineer.md` §"The task log".

---

### T1 — Human placement editor (drag-to-place, all scenes) · 2026-06-12 · tooling · done
- **Asked:** "create tools so i can place them, do this for all scenes with item placement"
- **Problem:** placing items on art by guessing 0–1 fractions is unreliable; the owner needs to place by hand and have it persist.
- **Type:** new
- **LLM-reliability:** low for the *placements* (perceptual — the whole point is to remove the guess); high for the *tool* (Layout override layer + drag input = deterministic code).
- **Human-in-loop:** required for the placements (owner drags); tool build solo.
- **Verification:** layout_tests 21 green (round-trip, id-keyed, clamp); in-engine drag captures.
- **Iterations:** 1
- **Result:** scripts/layout.gd + home.gd place mode + data/placements.json; commit cb5cbd7.

### T2 — Production vs DEBUG mode · 2026-06-12 · tooling · done
- **Asked:** "we should have a production and debug mode … adjust placement and save"; then "move that to a param, not a hard coded var."
- **Problem:** the editor needs a clean gate so production never shows it.
- **Type:** follow-up (T1)
- **LLM-reliability:** high (deterministic gating).
- **Human-in-loop:** none.
- **Verification:** plain launch clean; `-- debug` / `TU_DEBUG=1` shows editor; off in headless/quiet.
- **Iterations:** 2 (flag → launch param, per owner correction)
- **Result:** scripts/debug.gd; commit cb5cbd7.

### T4 — "the meadow can't be moved" · 2026-06-12 · tooling · done
- **Asked:** the meadow building won't drag in place mode.
- **Problem:** NOT the drag logic — a headless probe moved all 5 zones; the top-left Lv chip (STOP, above the map) ate presses on the top-edge zone.
- **Type:** follow-up (T1)
- **LLM-reliability:** med — needed a probe to separate logic from input routing ("it should drag" was wrong).
- **Human-in-loop:** none.
- **Verification:** probe (all zones MOVED=true) + capture (HUD hidden in place mode → corners clear).
- **Iterations:** 1 (after the probe)
- **Result:** hide HUD/chrome in place mode; commit cb5cbd7.

### T5 — Place items in locked zones (debug) · 2026-06-12 · tooling · done
- **Asked:** "for debug mode i need to be able to place items in zones i did not unlock."
- **Problem:** tap-to-enter gated on `zone_unlocked`; furniture rendered only for owned spots.
- **Type:** follow-up (T1)
- **LLM-reliability:** high.
- **Human-in-loop:** none.
- **Verification:** capture of a locked-zone interior in debug (enters + shows sprites/pins).
- **Iterations:** 1
- **Result:** commit cb5cbd7.

### T12 — Merge Director + Builder → one Engineer · 2026-06-12 · workflow · done
- **Asked:** "assume both director and builder roles, combine the global md files and just call it engineer."
- **Problem:** the two-role split was unnecessary overhead; the owner wants one role.
- **Type:** new (process)
- **LLM-reliability:** high (doc/config edit).
- **Human-in-loop:** none.
- **Verification:** `~/.claude/docs/engineer.md` + `/engineer` exist; old workflow-roles/builder/director removed; CLAUDE.md + project memory reconciled.
- **Iterations:** 1
- **Result:** global ~/.claude config (not a project commit).

### T13 — The task log + per-category split · 2026-06-12 · workflow · done
- **Asked:** keep a historical task log (asked/problem/regression-or-new/LLM-reliability/ask-for-help/result; "any other fields?"); then "different tasks list, by task type … since we are not using a db, this helps once the list gets larger."
- **Problem:** no historical, reliability-aware record → low-reliability mistakes (T9, T10) recur unflagged; a single flat list won't scale.
- **Type:** new (process)
- **LLM-reliability:** high (design + doc).
- **Human-in-loop:** recommended — owner picked the taxonomy (leaner 6) and approved added fields (T#/date/area/status, Verification, Iterations).
- **Verification:** format in engineer.md; `tasks/` split into 6 category files; `TASKS.md` index; T1–T13 migrated.
- **Iterations:** 1
- **Result:** TASKS.md (index) + tasks/*.md + engineer.md + /engineer; commit deab120 (flat) → this split.

### T16 — Bare skeleton: cut the old engine + archive all art/audio · 2026-06-14 · tooling/workflow · open
- **Asked:** "remove all cosmetics today, leave the bare bone of the game … so I can see the features, how/when things unlock, make the economy make sense, and tune it COMPLETELY separately from the meat … multiple games out of this engine with different clothes." Refined: move all art to a **gitignored `/archive`**, remove the **old Tidy-Up game incl. its engine**, keep unlock-map + coin-sinks as bare **placeholders** (just prove they exist + the user flow), to enable separating data from skin next.
- **Problem:** the repo was a TWO-game codebase (old Tidy-Up reach-zero puzzle + the live Grove) sharing infra, cosmetics in the view. Reusable engine ⇒ separate engine↔skin; the bare skeleton is step 1. Audit (3 workflows): the merge model is already cosmetic-free, art already falls back to placeholders, 24 feature flags — ~75% separated. Coins sink only into cosmetics (dead currency) — flagged for the economy pass.
- **Type:** new (architecture/cleanup)
- **LLM-reliability:** **high** for the CUT (dependency-graph **verified against code**: old game is a sealed 15-file subsystem, ZERO live references; one sever point = `home.gd` Classic button) and the ARCHIVE (filesystem move + the existing ResourceLoader fallbacks). **low** for "does the wireframe READ well / is the flow legible" — owner's eye.
- **Human-in-loop:** **recommended** — owner approved the destructive kill-list pre-execution; owner eyeballs the wireframe.
- **Verification:** _(Stage 1 cut: boot probe Home+Grove OK · grove_tests 302 / layout_tests 21 / save_tests 25 green. Stage 2 archive: boot OK on placeholders; wireframe capture pending.)_
- **Iterations:** _(open)_
- **Result:** _(open — branch `feat/bare-skeleton`. Parked follow-ups: scrub orphaned `save.gd` accessors (record_job/buy_decor/job-room-client) + `palette.FAMILIES`; formalize the data↔skin seam (3 cracks); the coin economy fix.)_
