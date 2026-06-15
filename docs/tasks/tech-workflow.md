# Tech & Tooling + Workflow & Process — task log

Engine/code infra, dev tools, tests, perf, save/build · and process: roles, this log, conventions.

_Cleared for a fresh start (2026-06-14). New entries below; see docs/TASKS.md for the format._

### T26 — flag registry index (docs/FEATURES.md) + fix stale features.gd header   ·   2026-06-15   ·   workflow   ·   done
- **Asked:**           §11 wants a flag registry — `FEATURES.md` is absent and flags lack the Lives-in / Eval the spec calls for; `features.gd:2` points at a `FEATURES.md` that doesn't exist; the core non-flaggable set (`gate_pause`, `spot_level_gates`) isn't indexed.
- **Problem:**         Tier-3 spec↔code drift. The §11 registry index never existed as a file, so the header pointer was stale (find-clean) and there was no single place listing every flag's read-site + verdict. No behavior was wrong — only the index/doc was missing.
- **Type:**            follow-up (closes a §11 documentation gap; no flag behavior touched)
- **LLM-reliability:** high for **Lives-in** — each read-site is grep-verifiable (`Features.on("<id>")` → enclosing func), and the FLAGS set was diffed against the doc (24 = 24, exact). **But Eval is owner-subjective** (keep/improve/cut) and was STUBBED, not derived — an LLM cannot make that call.
- **Human-in-loop:**   recommended — the per-flag keep/improve/cut **Eval** verdicts are stubbed `keep — default ON, owner review pending` (truthful: all 24 ship ON, none reviewed for cut) and need an owner sweep. No sibling tasks of this kind yet.
- **Verification:**    every `FLAGS` entry indexed in `docs/FEATURES.md` with a grep'd Lives-in (FLAGS dict vs doc rows diffed → exact 24/24 match, no flag missing/extra); the core list (`gate_pause` → `content.gd:active_giver_count()`; `spot_level_gates` → `content.gd:cell_min_level()` + `board_model.gd:openable_brambles()`) indexed in its own section; `features.gd:2` header now points at `docs/FEATURES.md`; the only code touch is that comment (cannot change behavior — no `make test` run, fresh-worktree reimport avoided per the §11 doc-only scope). Note: `gen_preview`'s read-site is currently PARKED/disabled (T17, `board.gd:1148`) — recorded as such, the flag is held.
- **Iterations:**      1 — grep'd read-sites, derived Lives-in per flag, diffed the set, wrote the registry + fixed the header. Dev miss: N/A (not yet reviewed).
- **Result:**          done — `33938ea`. New `docs/FEATURES.md` (registry: 5 group tables + core section); `engine/scripts/core/features.gd` L2 header repointed (comment only); this entry. Owner Eval sweep parked.
