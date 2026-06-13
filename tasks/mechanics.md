# Mechanics & Systems — task log

The rules and loops: merging, generators, quests, progression, economy logic, gates, win/lose.
Format + rules: `../TASKS.md` (index) → `~/.claude/docs/engineer.md` §"The task log".

---

### T7 — V1: locked-generator preview · 2026-06-12 · mechanics · done (V2/V3 open)
- **Asked:** (order V) "no new generator being offered … for a long time."
- **Problem:** edge brambles demand lines whose generators arrive many chapters later, with no signal → reads as impossible.
- **Type:** new
- **LLM-reliability:** high (deterministic content + render + asserts).
- **Human-in-loop:** none (V2 sim gap → owner retunes arrival numbers later).
- **Verification:** grove 237 (+3 asserts); `genpreview` capture (silhouette + "after 16 spots").
- **Iterations:** 1
- **Result:** commit b65e141. *(Open: V2 sim gap measurement, V3 click-tool floater proof.)*
