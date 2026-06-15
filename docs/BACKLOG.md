# Backlog — parking lot

Deferred / discovered work, parked as one-liners with enough context to pick up cold. This is a
**parking lot, not a worklist**: the Dev decides what's pulled next; nothing here is "in progress."
On pickup, an item becomes a `T#` task in [`TASKS.md`](TASKS.md). Format + rules:
`~/.claude/docs/engineer.md`.

---

## Open

- **Progression on one level clock + the multi-axis unlock map (spec + code).** Owner call
  (2026-06-14): one **uncapped level** clock (ramp → flat **3,200 clicks/level past L50**), driven by
  stars earned. Unlock map: **level gates spots + board cells**; **generators gate by *zone*** (per-zone
  sets, merge-to-evolve, §6); **zones gate by *completion*** of the prior zone (§8). Stars stay the
  build **spend**. **Done in the spec:** progression rewritten + moved to **§3**; obstacle gating §4;
  generators per-zone §6; quest/star model §7; "chapter" swept; §3–§7 reordered + all refs fixed.
  **Remaining:** **§8 state zones unlock by *completion*** (it says "unlock in sequence" — make
  explicit; spots within a zone stay level-gated); set grove values (`LEVEL_STARS`, the per-zone
  generator/quest map); the **code rename** (`chapter`/`unlocks`/EXP/`LEVEL_XP` → level/stars); re-run
  the sim. *(Surfaced 2026-06-14 during the spec review.)*

- **Generated quests + calculated reward (spec + code + sim).** `merge_spec` §7 replaced the
  deterministic per-zone quest ramp with **generated** quests: asks drawn from the available
  generators' lines (weighted to the newest/highest-value gens), asks/tier scaling with **player level**; reward
  **calculated from expected clicks** → `stars = min(value, STAR_CAP)` (~1–3★, so level ∝ quest count)
  **+ coins** for the overflow. **Remaining:** retire grove §3's per-zone ramp table (keep as tuning
  ref) and set grove instances (generator weights, level→asks/tier distribution, `STAR_CAP`,
  click→value rate); add **guardrails** (every ask producible on the current board; an affordability
  floor) so RNG can't strand; replace the byte-for-byte affordability proof (**§3 pigeonhole**) with a
  **Monte-Carlo sim** (worst-case across seeds); and update **§10** — quests now add a **coin faucet**.
  Also: the fence **meters quest supply to the next-unlock cost** (empty fence = "go spend" signal) —
  the sim must confirm the metered supply always reaches the next unlock without deadlocking against a
  level gate. *(Surfaced 2026-06-14 during the §6 review.)*

- **Economy sim re-validation after the §4 faucet changes.** `docs/core/merge_spec.md` §4 raised the
  energy faucet — **level-up gift +20 → +50** and **free refills 3-lifetime → 1 per day** (a full
  refill ≈ 100💧/day). Run `tools/grove_sim.gd` (default + greedy) and confirm the §3 invariants
  still hold (§4): **a level's energy rewards stay < 30% of that level's energy cost** and **"sessions
  extend, never self-sustain."** A daily full refill is a large recurring grant that directly
  tensions the monetization-socket pillar — this is the check that says whether +50/daily-refill is
  shippable or needs dialing back. *(Surfaced 2026-06-14 during the §3 spec review.)*

- **Implement level-gated obstacle cells (code).** `docs/core/merge_spec.md` §4 reworked obstacle
  gating: outer board (ring 3+) is now **level-gated and granular** — each cell carries a
  `min_level`, unseals in waves as the player levels, then still opens on an adjacent merge. Today
  `openable_brambles` is **tier-only** (no `min_level`); this needs new code (a per-cell level gate)
  against the **gate map now drawn in `merge_spec` §4** (the default 7×9 board: **fully
  level-gated**, L2/L3 frontier radiating in a diamond out to **L12** at the corners; the outermost
  ring also keeps the bramble late-line tier) + **sim re-validation of the no-strand / pigeonhole
  guarantees** (they were proven against tier-gating; level-gating the frontier can re-strand it,
  and the L10–L12 corners must be reachable or intentionally tail). Open design sub-Q for pickup: does reaching
  `min_level` make the cell *merge-openable* (chosen, preserves adjacent-unlock) or *auto-open*?
  *(Surfaced 2026-06-14 during the §3 spec review.)*

- **Grove: build the per-zone generator/line sets (content + code).** `merge_spec` §6 makes generators
  **per zone**: z1 → 2 gens/4 lines · z2–3 → 3/6 · z4+ → 4/8 — a **16-generator / 32-line lifetime
  roster** for the 5 zones (~2–4 live at once). Unlock = **merge-to-evolve gate**: a zone's gate quest
  asks a **t8 of the previous zone's line**; then N quests across the zone each grant a generator that
  **upgrades a previous-zone one** (`old + grant → new`, old consumed, **old lines retire**) or is
  **granted outright** for a surplus generator when the zone adds one. ⚠️ **Large
  art/content** — 32 lines × 8 tiers ≈ **~256 item sprites** + 16 generators (LLM pipeline, §16). Needs:
  the grove's zone→generator→line map + names; the evolve-merge piece-count; per-zone **sell-value
  bands** (re-derive the 32× no-arbitrage per zone, §9); and the **authored** gate/milestone quests
  (§7). Replaces the old 3-generator grove set. *(Surfaced 2026-06-14 during the §6 review.)*

- **Implement the new bag capacity model (code).** `merge_spec` §5 redefines the bag: **starts at 6
  slots**, **+1 at a time bought with premium 💎**, **max 18** (12 expansions); shelving free, no
  timers, persisted. Current code/`grove_spec` had the old **"2 free, 3rd slot = 10💎"** model — the
  save blob's `bag` and the slot-buy path need updating, and the grove instance needs the per-slot
  premium price schedule (flat or escalating — a `grove_spec` number, not yet set). *(Surfaced
  2026-06-14 during the §3 spec review.)*

- **Grove: story / character arcs for the givers (content).** The givers (fox, hedgehog, owl, …) are
  anonymous. Add a **light narrative spine** — name them, give each a personality + a thread/arc that
  unfolds as zones restore (cozy, low-pressure; the genre's emotional-retention engine — Gossip Harbor
  / Merge Mansion lean on story hard). Engine supports it (Core §7: givers carry name / personality /
  dialogue / arc). *(Surfaced 2026-06-14 — director review.)*

- **Grove: instantiate the new engine systems (content + code).** Core added **events / live-ops**
  (§17), the **Collection** almanac for retired lines (§6), **Shop item-shortcuts + cosmetics** (§10),
  and **share-for-reward** (§17). Grove needs the instances: an **event calendar** + limited-line
  themes + reward sizes; the **Collection** UI + re-summon prices; **Shop stock** (which item
  shortcuts at what coin/premium price, the cosmetic catalogue); **share-reward sizes**; and the
  **analytics sink** wiring (§15, now launch). *(Surfaced 2026-06-14 — director review.)*
