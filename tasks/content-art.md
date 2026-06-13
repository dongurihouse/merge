# Content & Balance + Art & Assets — task log

The stuff & numbers (levels/chapters, item & quest data, placement, difficulty/economy tuning)
· AND the asset pipeline (sprite generation, processing/cutout/punch, import, integration).
Format + rules: `../TASKS.md` (index) → `~/.claude/docs/engineer.md` §"The task log".

---

### T8 — AE1: punch enclosed holes in furniture sprites · 2026-06-12 · art · done
- **Asked:** (placement session) "cut out the blank spots within the items so they are transparent."
- **Problem:** enclosed white inside furn sprites (chair slats, wheel spokes) never punched.
- **Type:** new
- **LLM-reliability:** med — punch is deterministic; verifying needs in-engine/composite, not a screenshot.
- **Human-in-loop:** none (POV misfits → AE2 owner contact sheet).
- **Verification:** in-engine view of fh_chair/fh_wheel (gaps clear, wood intact); per-file px counts.
- **Iterations:** 1
- **Result:** commit a8a7ecb (fh+bn committed; pond/orchard/meadow punched but left for the artist wave).

### T9 — Fence white background · 2026-06-12 · art · done (3 passes — CAUTIONARY)
- **Asked:** "the white background is not being cut out" → "inside of the fence is still white, why haven't you checked that in the first place?" → "smaller white areas … between the flowers."
- **Problem:** fence_grove.png shipped an opaque-white background — edges, then the enclosed rail openings, then small gaps between the daisies.
- **Type:** new, then two regressions of my own incomplete fixes.
- **LLM-reliability:** **LOW** — transparency is invisible in a screenshot; I claimed it fixed twice on a capture where white and transparent look identical.
- **Human-in-loop:** none once I switched to composite-over-colour; the owner caught both early misses.
- **Verification:** composite over magenta — opaque-white px **41366 → (edge) → (region≥600) → 0**. The screenshot was the trap; the composite was the truth.
- **Iterations:** **3 (owner caught 2)** — the canonical "verify transparency by compositing, never eyeball" lesson.
- **Result:** tools/cutout_bg.gd (edge → region-size cut) + grove.gd; commits 57ab3e7 / d01149b / 1a22ad3.
