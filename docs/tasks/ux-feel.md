# UX & Interface + Game Feel & Juice — task log

Readability & layout (HUD, menus, chips, navigation) · and the alive layer: animation, FX, audio, juice.

_Cleared for a fresh start (2026-06-14). New entries below; see docs/TASKS.md for the format._

### T27 — reconcile §12 juice verb table to real call names   ·   2026-06-15   ·   ux   ·   done
- **Asked:** §12 names the juice verbs "called by name," but the engine implements the motions under different names: `wiggle`→`FX.wobble`, `floater`→`FX.floating_text`, `press`→`skin.add_press_juice` (not FX), `hop`/`ambient_bob` in `ambient.gd`. The motions all exist; only the named-verb surface deviates. Reconcile the §12 table to the actual call names (or rename in code).
- **Problem:** Pure spec↔code drift (Tier-3) — the SHIPPED CODE is the reality. The §12 vocabulary table and its intro ("Implemented once in `FX` / `Look` and called by name") were stale: five of ten rows named a verb that no longer matches the callable, and `ambient_bob` named a callable that never existed (the bob is inlined in the ambient wander path). Renaming code would touch many call sites for zero behavior gain, so the fix is to reconcile the doc to the code.
- **Type:** follow-up (doc reconciliation; no behavior change)
- **LLM-reliability:** high — deterministic: every verb maps to a grep-confirmed `static func`/`func` signature in `fx.gd`/`skin.gd`/`ambient.gd` (or, for the bob, to the inlined `Tune.BOB_AMP * sin(...)` line). Self-verifiable by grep; no perceptual judgement.
- **Human-in-loop:** none — mechanical doc↔code reconciliation; no design call.
- **Verification:** each §12 verb now names a grep-confirmed callable in `fx.gd`/`skin.gd`/`ambient.gd` (signatures quoted below); the inlined bob is noted as such rather than as a fake callable; no code changed. Drift fixed: `press`→`Look.add_press_juice` (skin.gd:216), `wiggle`→`FX.wobble` (fx.gd:31), `floater`→`FX.floating_text` (fx.gd:67), `hop`→`Ambient.hop` (ambient.gd:111, callable but not in FX), `ambient_bob`→inlined in `_character_pos` (ambient.gd:69). Already-correct rows kept: `FX.pop_in` (:112), `FX.scatter_in` (:122), `FX.fly_to_wallet` (:154), `FX.tick` (:136), `FX.breathe`/`FX.breathe_once` (:60/:100). Calm-mode prose ("disables `breathe`") left intact — `FX.breathe` exists. Doc-only: `make test` not run (no code touched; a fresh worktree would force a slow asset reimport).
- **Iterations:** 1 — single section-scoped edit to the §12 intro + table; no Dev miss.
- **Result:** done — commit on `feat/t27-spec-juice-verbs` (see merge-back; HEAD at write was `d69cce8`). Files: `docs/design/merge_spec.md` (§12 intro + table), `docs/tasks/ux-feel.md` (this entry). No `.gd` changed. Note for the Dev: line 416 (§13 Shop prose) still says "→ wiggle"; left untouched to keep this edit §12-scoped — park a one-liner if that prose should also track `FX.wobble`.
