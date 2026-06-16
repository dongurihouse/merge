# Content & Balance + Art & Assets — task log

Levels/items/quest data, placement, difficulty/economy tuning · and the asset pipeline.

_Cleared for a fresh start (2026-06-14). New entries below; see docs/TASKS.md for the format._

### T20 — Grove content roster: v1 home-grove lines + generators (data)   ·   2026-06-15   ·   content-art   ·   done
- **Asked:**          "do Grove content, park pacing, calibration, art in backlog, update backlog."
- **Problem:**        with the §6/§7 engine shipped (T17–T19), `grove_data.gd` still held the **placeholder** roster (16 stand-in generators `satchel`/`z1a`…, code-drawn lines). The real per-map content — the `grove_spec §2` line/generator/name/lineage map — was unauthored. (Scope is DATA only; the ~192 sprites are parked art.)
- **Type:**           follow-up (of T17–T19; the "content" half of the per-zone-generators backlog item).
- **LLM-reliability:** high for the structure (counts/lineage/codes are spec-pinned + headless-verifiable); the line/generator NAMES are transcribed from the `grove_spec §2` concrete table (not invented), so low subjectivity. Easily renamed.
- **Human-in-loop:**  none — the spec's v1 roster table is authoritative; names are trivially adjustable.

  **Scope (in):** rewrite `grove_data.gd` `LINES` (4 → **24** themed lines, codes 1–8/10–25, skip 9) + `GENERATORS` (placeholder 16 → the **12** v1 generators) to the `grove_spec §2` table — 5 maps (Farmhouse · Barn · Pond · Orchard · Meadow), 2 lines/generator, the hand-in lineage on the (2,1)/(6,5)/(4,5) chains, `seed_satchel` (Wildflower+Berry) the un-handed-in anchor at (4,3). Update the live-roster tests (mechanics_tests board-model block, grove_tests gate/12c/12b/6c-d) to the new ids/cells. Map-1 bases kept (`flower`/`berry`/`mushroom`/`honey`) so any existing sprites resolve; 5–25 render code-drawn.
  **Scope (parked):** the ~192 item + 12 generator sprites (§16 LLM art — ⚠️ large); the **anchor's cold-load persistence** (satchel live + askable past map 1 — persists in live play via hand-in, but `seed_gens`/`lines_for_zone` don't include it on a cold load); the §7 **pacing sign-off** + §3 `LEVEL_STARS` recalibration (own backlog items). Maps 6–15 (post-launch).
- **Verification:**   **DONE.** `make test` **439/439** (mechanics 40 · quest 32 · grove 291 · save 26 · layout 21 · layering 29), `make smoke` OK, `grove_sim` PASS on the real roster. Generator structure confirmed: 12 gens, per-map 2·2·2·3·3, 24 lines, the hand-in lineage round-trips; the gate→hand-in flow installs `hen_coop` from `pantry_crock` while the anchor `seed_satchel` stays.
- **Iterations:**     1 redo — first authored a 16-gen/32-line roster off the *stale* backlog; the owner had revised `grove_spec §2` to the 15-map arc (v1 = 12/24), so re-transcribed to the spec's concrete table + re-pointed the tests.
- **Result:**         **DONE, 2026-06-15.** The grove runs on its real v1 names (Wildflower, Berry, … Glowcap, Firefly) across the 5 home-grove maps; placeholder ids retired. Art + the anchor cold-load persistence + the economy-feel calls are parked (`docs/BACKLOG.md`). Committed with the §7 work.

### T36 — Grove v1 art: generate + hook up the home-grove sprites & scenes   ·   2026-06-15   ·   art   ·   open
- **Asked:**          "figure out how to generate the arts for grove and get it hooked up" + a 5-point plan (understand all requirements; test a new base prompt for board/map/major items; generate all remaining items; 3×3-grid the smaller items and cut them out; high-contrast background for holed items).
- **Problem:**        the parked "Grove v1 art" backlog tail — v1 home-grove content (T20) renders **code-drawn**; the real Direction-F (`grove_spec §9`) art + hook-up was never built. Owner **expanded scope** (this session): regenerate **ALL** fresh (disown the 2026-06-14 flower/berry/mushroom/honey pass) = **192 item sprites + 12 generators + 1 board backdrop + 5 map scenes (§16 scene pipeline)** (the anchor cold-load follow-up the backlog bundled here **shipped separately as T30** — dropped from T36; verify-only). **Channel changed:** an external **artist** generates (returns **finished transparent sprites**); the Engineer authors prompts, then processes (split/trim) + hooks up + verifies. Runbook: `docs/design/grove_art_pipeline.md`.
- **Type:**           follow-up (of T20; the parked `BACKLOG.md` "Grove v1 art" item).
- **LLM-reliability:** **LOW** — perceptual/aesthetic + external. The `§9` **share-gate is an explicit launch gate** ("would a player screenshot this"); style consistency across 200+ assets and tier-readability are Dev-eye calls, and generation is an outside channel. *(The mechanical half — split/trim/import, path wiring, the §16 round-trip diff — is high-reliability + self-verifiable.)*
- **Human-in-loop:**  **REQUIRED** — the Dev routes generation to the artist and **owns the share-gate sign-off**; cadence is batch-with-checkpoints. Sibling low-reliability art tasks (parked): the parents' de-transformation ladder, giver busts, the map scenes.
- **Verification:**   _(open — closed at done: per-sprite alpha/dims checks, §16 map round-trip diff, `make shot-grove`/`shot-map`, `make test` green, per-line/per-map montages for the Dev's share-gate sign-off)._
- **Iterations:**     _(open)_
- **Result:**         _(open — P0 prompt-lock in progress: board-backdrop prompt is the first handoff to the artist)._
