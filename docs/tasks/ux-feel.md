# UX & Interface + Game Feel & Juice — task log

Readability & layout (HUD, menus, chips, navigation) · and the alive layer: animation, FX, audio, juice.

_Cleared for a fresh start (2026-06-14). New entries below; see docs/TASKS.md for the format._

### T25 — reconcile §13 HUD law to the shipped bottom-bar Shop   ·   2026-06-15   ·   ux   ·   done
- **Asked:**          "HUD law drift — Shop moved out of the top-right bar (decision). §13 says the top bar is 'wallet + Shop' top-right; the code deliberately moved the Shop to the bottom bar. Decide: update §13 to the shipped decision (recommended), or move Shop back."
- **Problem:**        Spec↔code drift (Tier-3): the spec's §13 HUD law still claimed a top-right "wallet + Shop", but the owner relocated the Shop to the bottom chrome on 2026-06-13. The shipped code is the reality; the spec was stale.
- **Type:**           follow-up (spec reconcile to owner's 2026-06-13 Shop-relocation decision)
- **LLM-reliability:** high — deterministic doc-vs-code reconcile; the shipped layout is fully readable in source and the edit is verified by quoting it (no perceptual/aesthetic call).
- **Human-in-loop:**  none — the owner already decided (2026-06-13) to move the Shop to the bottom bar; this only makes the spec follow. No design call remains.
- **Verification:**   quoted `hud.gd:69-70` (top cluster = currencies only; Home rides its left) + the board bottom-left `[◀ Home][🛒]` (`board.gd:231-276`) and the map bottom-right Shop beside the gear (`map.gd:802-834`); §13 HUD law now matches the shipped UI; no code changed.
- **Iterations:**     1 pass; Dev caught a miss: N.
- **Result:**         done — §13 "HUD law" clause in `docs/design/merge_spec.md` rewritten to the bottom-bar reality on branch `feat/t25-spec-hud-law` (the dispatcher merges by branch). No `.gd` behavior touched; Shop NOT moved back.
